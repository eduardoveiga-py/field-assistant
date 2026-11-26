import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Modo de desbloqueio da chave E2EE no navegador (Web PWA).
enum WebKeyUnlockMode { none, persistentBrowser, pinLocked, unlockedFromPin }

/// Exceção lançada quando a chave E2EE existe no navegador protegida por PIN rápido
/// e aguarda desbloqueio do usuário na sessão atual.
class WebPinLockedException implements Exception {
  final String message;

  const WebPinLockedException([
    this.message = 'Cofre E2EE protegido por PIN neste navegador. Digite seu PIN para desbloquear.',
  ]);

  @override
  String toString() => 'WebPinLockedException: $message';
}

/// Contrato multiplataforma para persistência cifrada da chave E2EE no navegador.
/// Nunca persiste a frase mnemônica de 24 palavras; armazena apenas a chave raiz derivada
/// encapsulada por `WebCrypto` não-extraível ou por envelope PBKDF2-HMAC-SHA256 com PIN rápido.
abstract class WebKeyPersistenceAdapter {
  Future<Uint8List?> readKey(String storageKey, String owner);

  Future<bool> hasStoredEntry(String storageKey);

  Future<bool> isPinLocked(String storageKey);

  Future<void> writePersistentKey(
    String storageKey,
    String owner,
    Uint8List keyBytes,
  );

  Future<void> writePinProtectedKey(
    String storageKey,
    String owner,
    Uint8List keyBytes,
    String pin,
  );

  Future<Uint8List> unlockWithPin(String storageKey, String owner, String pin);

  Future<void> copyEntry({
    required String fromStorageKey,
    required String fromOwner,
    required String toStorageKey,
    required String toOwner,
  });

  Future<void> deleteKey(String storageKey);
}

/// Empacotamento criptográfico da chave raiz E2EE com PIN/senha curta local no navegador
/// usando PBKDF2-HMAC-SHA256 (600.000 iterações por padrão OWASP) + AES-256-GCM autenticado por AAD.
class WebPinKeyWrapper {
  static const int defaultIterations = 600000;
  static const int minPinLength = 6;
  static const int _saltBytes = 16;

  final int iterations;

  const WebPinKeyWrapper({this.iterations = defaultIterations});

  static String validatePin(String pin) {
    final trimmed = pin.trim();
    if (trimmed.length < minPinLength) {
      throw const FormatException(
        'O PIN de desbloqueio na Web precisa ter pelo menos 6 caracteres.',
      );
    }
    return trimmed;
  }

  static List<int> _aad(String owner, String storageKey) => utf8.encode(
    jsonEncode(['field-assistant', 'web-pin-wrap', 1, owner, storageKey]),
  );

  static Uint8List _randomBytes(int length) {
    final rng = Random.secure();
    final out = Uint8List(length);
    for (var i = 0; i < length; i++) {
      out[i] = rng.nextInt(256);
    }
    return out;
  }

  Future<SecretKey> _derivePinKey({
    required String pin,
    required List<int> salt,
    required int iterCount,
  }) async {
    final kdf = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterCount,
      bits: 256,
    );
    return kdf.deriveKey(secretKey: SecretKey(utf8.encode(pin)), nonce: salt);
  }

  Future<Map<String, Object>> wrap({
    required String owner,
    required String storageKey,
    required Uint8List keyBytes,
    required String pin,
  }) async {
    if (keyBytes.length != 32) {
      throw ArgumentError.value(
        keyBytes.length,
        'keyBytes',
        'A chave E2EE precisa ter 32 bytes.',
      );
    }
    final cleanPin = validatePin(pin);
    final salt = _randomBytes(_saltBytes);
    final derived = await _derivePinKey(
      pin: cleanPin,
      salt: salt,
      iterCount: iterations,
    );
    final box = await AesGcm.with256bits().encrypt(
      keyBytes,
      secretKey: derived,
      aad: _aad(owner, storageKey),
    );
    return {
      'v': 1,
      'mode': 'pin',
      'kdf': 'PBKDF2-SHA256',
      'iterations': iterations,
      'salt': base64Encode(salt),
      'nonce': base64Encode(box.nonce),
      'ciphertext': base64Encode(box.cipherText),
      'tag': base64Encode(box.mac.bytes),
    };
  }

  Future<Uint8List> unwrap({
    required String owner,
    required String storageKey,
    required Map<String, dynamic> envelope,
    required String pin,
  }) async {
    if (envelope['v'] != 1 ||
        envelope['mode'] != 'pin' ||
        envelope['kdf'] != 'PBKDF2-SHA256' ||
        envelope['iterations'] is! int ||
        envelope['salt'] is! String ||
        envelope['nonce'] is! String ||
        envelope['ciphertext'] is! String ||
        envelope['tag'] is! String) {
      throw const FormatException(
        'Envelope de PIN E2EE inválido ou corrompido.',
      );
    }
    final iterCount = envelope['iterations'] as int;
    if (iterCount < 1000) {
      throw const FormatException('Parâmetros PBKDF2 inválidos.');
    }
    final salt = base64Decode(envelope['salt'] as String);
    final nonce = base64Decode(envelope['nonce'] as String);
    final ciphertext = base64Decode(envelope['ciphertext'] as String);
    final tag = base64Decode(envelope['tag'] as String);
    if (salt.length != _saltBytes ||
        nonce.length != 12 ||
        ciphertext.length != 32 ||
        tag.length != 16) {
      throw const FormatException('Dados cifrados do cofre Web inválidos.');
    }

    final cleanPin = pin.trim();
    if (cleanPin.isEmpty) {
      throw const FormatException('Informe o PIN para desbloquear.');
    }

    final derived = await _derivePinKey(
      pin: cleanPin,
      salt: salt,
      iterCount: iterCount,
    );
    try {
      final plain = await AesGcm.with256bits().decrypt(
        SecretBox(ciphertext, nonce: nonce, mac: Mac(tag)),
        secretKey: derived,
        aad: _aad(owner, storageKey),
      );
      if (plain.length != 32) {
        throw const FormatException('Tamanho de chave restaurada inválido.');
      }
      return Uint8List.fromList(plain);
    } on SecretBoxAuthenticationError {
      throw const FormatException(
        'PIN incorreto para desbloquear o cofre E2EE.',
      );
    }
  }
}

/// Implementação em memória com empacotamento real AES-256-GCM para testes determinísticos
/// multiplataforma e ambientes sem WebCrypto/IndexedDB (ex.: Flutter test VM).
class MemoryWebKeyPersistenceAdapter implements WebKeyPersistenceAdapter {
  final WebPinKeyWrapper pinWrapper;
  final Map<String, Map<String, dynamic>> _entries = {};
  final SecretKey _deviceWrappingKey;

  MemoryWebKeyPersistenceAdapter({
    WebPinKeyWrapper? pinWrapper,
    SecretKey? deviceWrappingKey,
  }) : pinWrapper = pinWrapper ?? const WebPinKeyWrapper(),
       _deviceWrappingKey =
           deviceWrappingKey ?? SecretKey(_generateRandomKeyBytes());

  static Uint8List _generateRandomKeyBytes() {
    final rng = Random.secure();
    return Uint8List.fromList(List<int>.generate(32, (_) => rng.nextInt(256)));
  }

  static List<int> _deviceAad(String owner, String storageKey) => utf8.encode(
    jsonEncode(['field-assistant', 'web-keystore', 1, owner, storageKey]),
  );

  /// Injeta manualmente um registro corrompido para testes de regressão fail-closed.
  void injectCorruptEntryForTesting(
    String storageKey,
    Map<String, dynamic> raw,
  ) {
    _entries[storageKey] = Map<String, dynamic>.from(raw);
  }

  @override
  Future<bool> hasStoredEntry(String storageKey) async =>
      _entries.containsKey(storageKey);

  @override
  Future<bool> isPinLocked(String storageKey) async {
    final entry = _entries[storageKey];
    return entry != null && entry['mode'] == 'pin';
  }

  @override
  Future<Uint8List?> readKey(String storageKey, String owner) async {
    final entry = _entries[storageKey];
    if (entry == null) return null;
    final mode = entry['mode'];
    if (mode == 'pin') {
      throw const WebPinLockedException();
    }
    if (mode != 'persistent' ||
        entry['nonce'] is! String ||
        entry['ciphertext'] is! String ||
        entry['tag'] is! String) {
      throw const FormatException('Registro persistente Web corrompido.');
    }
    try {
      final nonce = base64Decode(entry['nonce'] as String);
      final cipherText = base64Decode(entry['ciphertext'] as String);
      final tag = base64Decode(entry['tag'] as String);
      final plain = await AesGcm.with256bits().decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(tag)),
        secretKey: _deviceWrappingKey,
        aad: _deviceAad(owner, storageKey),
      );
      if (plain.length != 32) {
        throw const FormatException(
          'Chave persistente Web com tamanho inválido.',
        );
      }
      return Uint8List.fromList(plain);
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Falha ao autenticar chave persistente Web.');
    }
  }

  @override
  Future<void> writePersistentKey(
    String storageKey,
    String owner,
    Uint8List keyBytes,
  ) async {
    if (keyBytes.length != 32) {
      throw ArgumentError.value(keyBytes.length, 'keyBytes', 'Esperado 32B.');
    }
    final box = await AesGcm.with256bits().encrypt(
      keyBytes,
      secretKey: _deviceWrappingKey,
      aad: _deviceAad(owner, storageKey),
    );
    _entries[storageKey] = {
      'mode': 'persistent',
      'nonce': base64Encode(box.nonce),
      'ciphertext': base64Encode(box.cipherText),
      'tag': base64Encode(box.mac.bytes),
    };
  }

  @override
  Future<void> writePinProtectedKey(
    String storageKey,
    String owner,
    Uint8List keyBytes,
    String pin,
  ) async {
    final envelope = await pinWrapper.wrap(
      owner: owner,
      storageKey: storageKey,
      keyBytes: keyBytes,
      pin: pin,
    );
    _entries[storageKey] = envelope;
  }

  @override
  Future<Uint8List> unlockWithPin(
    String storageKey,
    String owner,
    String pin,
  ) async {
    final entry = _entries[storageKey];
    if (entry == null) {
      throw StateError(
        'Nenhuma chave E2EE salva neste navegador para a conta.',
      );
    }
    if (entry['mode'] != 'pin') {
      final persistent = await readKey(storageKey, owner);
      if (persistent == null) {
        throw StateError('Nenhuma chave persistente encontrada.');
      }
      return persistent;
    }
    return pinWrapper.unwrap(
      owner: owner,
      storageKey: storageKey,
      envelope: entry,
      pin: pin,
    );
  }

  @override
  Future<void> copyEntry({
    required String fromStorageKey,
    required String fromOwner,
    required String toStorageKey,
    required String toOwner,
  }) async {
    final source = _entries[fromStorageKey];
    if (source == null) return;
    if (source['mode'] == 'persistent') {
      final raw = await readKey(fromStorageKey, fromOwner);
      if (raw != null) {
        await writePersistentKey(toStorageKey, toOwner, raw);
      }
    } else if (source['mode'] == 'pin') {
      // PIN envelope tem AAD vinculada ao owner/storageKey de origem; preserva referência apenas
      // quando o destino recebe a chave desbloqueada pelo fluxo autenticador.
      _entries[toStorageKey] = Map<String, dynamic>.from(source);
    }
  }

  @override
  Future<void> deleteKey(String storageKey) async {
    _entries.remove(storageKey);
  }
}
