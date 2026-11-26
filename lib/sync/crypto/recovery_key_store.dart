import 'dart:convert';

import 'package:crypto/crypto.dart' as digest;
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'recovery_crypto.dart';
import 'recovery_vault_verifier.dart';
import 'web_key_persistence.dart';
import 'web_key_persistence_stub.dart'
    if (dart.library.js_interop) 'web_key_persistence_web.dart';

/// Armazenamento local seguro da chave de recuperação E2EE.
/// No nativo (iOS/Android/Windows), usa Keychain / Keystore / DPAPI via [FlutterSecureStorage].
/// Na Web (`kIsWeb`), utiliza cache em sessão combinado com persistência cifrada no IndexedDB
/// encapsulada via WebCrypto (`extractable: false`) ou protegida por PIN PBKDF2-SHA256.
/// Armazena exclusivamente a chave derivada (SecretKey), nunca a frase de 24 palavras.
class RecoveryKeyStore {
  static const IOSOptions defaultIosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
    synchronizable: false,
  );

  static const AndroidOptions defaultAndroidOptions = AndroidOptions(
    resetOnError: false,
  );

  RecoveryKeyStore({
    FlutterSecureStorage? storage,
    WebKeyPersistenceAdapter? webPersistence,
  }) : _storage =
           storage ??
           const FlutterSecureStorage(
             iOptions: defaultIosOptions,
             aOptions: defaultAndroidOptions,
           ),
       _injectedWebPersistence = webPersistence;

  final FlutterSecureStorage _storage;
  final WebKeyPersistenceAdapter? _injectedWebPersistence;
  static WebKeyPersistenceAdapter? _defaultPlatformWebPersistence;

  static Future<void> _tail = Future<void>.value();
  static final Map<String, String> _webMemoryKeys = {};

  bool get _useWebStore => kIsWeb || _injectedWebPersistence != null;

  WebKeyPersistenceAdapter get _webAdapter =>
      _injectedWebPersistence ??
      (_defaultPlatformWebPersistence ??= createPlatformWebKeyPersistence());

  @visibleForTesting
  static void resetForTesting() {
    _tail = Future<void>.value();
    _webMemoryKeys.clear();
    _defaultPlatformWebPersistence = null;
  }

  static Future<T> _serialized<T>(Future<T> Function() op) {
    final result = _tail.then((_) => op());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  @visibleForTesting
  static String storageKeyForTesting(String owner) => _storageKey(owner);

  static String _storageKey(String owner) {
    if (owner.isEmpty || owner.trim() != owner) {
      throw ArgumentError('Conta inválida.');
    }
    return 'e2ee_root_v1_${digest.sha256.convert(utf8.encode(owner))}';
  }

  static List<int> _decode(String value) {
    if (!value.startsWith('v1:')) {
      throw const FormatException('Chave local inválida.');
    }
    final raw = value.substring(3);
    if (raw.length != 44) throw const FormatException('Chave local inválida.');
    final bytes = base64Decode(raw);
    if (bytes.length != 32 || base64Encode(bytes) != raw) {
      throw const FormatException('Chave local inválida.');
    }
    return bytes;
  }

  static bool _equal(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  /// Indica o estado detalhado de desbloqueio da chave no navegador/dispositivo.
  Future<WebKeyUnlockMode> getWebUnlockState(String owner) =>
      _serialized(() async {
        final storageKey = _storageKey(owner);
        if (!_useWebStore) {
          final v = await _storage.read(key: storageKey);
          return v == null
              ? WebKeyUnlockMode.none
              : WebKeyUnlockMode.persistentBrowser;
        }
        final memVal = _webMemoryKeys[storageKey];
        if (memVal != null) {
          _decode(memVal);
          final isPin = await _webAdapter.isPinLocked(storageKey);
          return isPin
              ? WebKeyUnlockMode.unlockedFromPin
              : WebKeyUnlockMode.persistentBrowser;
        }
        if (await _webAdapter.isPinLocked(storageKey)) {
          return WebKeyUnlockMode.pinLocked;
        }
        final restored = await _webAdapter.readKey(storageKey, owner);
        if (restored != null) {
          _webMemoryKeys[storageKey] = 'v1:${base64Encode(restored)}';
          return WebKeyUnlockMode.persistentBrowser;
        }
        return WebKeyUnlockMode.none;
      });

  Future<bool> isWebPinLocked(String owner) async {
    if (!_useWebStore) return false;
    final state = await getWebUnlockState(owner);
    return state == WebKeyUnlockMode.pinLocked;
  }

  /// Carrega a chave E2EE para [owner]. Retorna `null` se não instalada ou aguardando PIN na Web.
  Future<SecretKey?> load(String owner) => _serialized(() async {
    final storageKey = _storageKey(owner);
    if (_useWebStore) {
      final memVal = _webMemoryKeys[storageKey];
      if (memVal != null) {
        return SecretKey(_decode(memVal));
      }
      try {
        final persisted = await _webAdapter.readKey(storageKey, owner);
        if (persisted == null) return null;
        if (persisted.length != 32) {
          throw const FormatException('Chave E2EE Web com tamanho inválido.');
        }
        _webMemoryKeys[storageKey] = 'v1:${base64Encode(persisted)}';
        return SecretKey(persisted);
      } on WebPinLockedException {
        return null;
      }
    }
    final value = await _storage.read(key: storageKey);
    return value == null ? null : SecretKey(_decode(value));
  });

  /// Desbloqueia uma chave protegida por PIN PBKDF2-HMAC-SHA256 no navegador.
  Future<SecretKey> unlockWithPin({
    required String owner,
    required String pin,
  }) => _serialized(() async {
    final storageKey = _storageKey(owner);
    if (!_useWebStore) {
      final existing = await _storage.read(key: storageKey);
      if (existing == null) {
        throw StateError('Nenhuma chave instalada para $owner.');
      }
      return SecretKey(_decode(existing));
    }
    final keyBytes = await _webAdapter.unlockWithPin(storageKey, owner, pin);
    if (keyBytes.length != 32) {
      throw const FormatException('Chave restaurada com tamanho inválido.');
    }
    _webMemoryKeys[storageKey] = 'v1:${base64Encode(keyBytes)}';
    return SecretKey(keyBytes);
  });

  /// Bloqueia apenas a sessão em RAM na Web, preservando o cofre protegido no IndexedDB.
  Future<void> lockWebSession(String owner) => _serialized(() async {
    if (!_useWebStore) return;
    _webMemoryKeys.remove(_storageKey(owner));
  });

  /// Copia a chave de recuperação entre contas (ex: local_user para usuário autenticado)
  Future<void> copyOwnerKey({
    required String fromOwner,
    required String toOwner,
  }) => _serialized(() async {
    if (fromOwner == toOwner) return;
    final fromKey = _storageKey(fromOwner);
    final toKey = _storageKey(toOwner);
    if (_useWebStore) {
      var mem = _webMemoryKeys[fromKey];
      if (mem == null) {
        try {
          final loaded = await _webAdapter.readKey(fromKey, fromOwner);
          if (loaded != null) {
            mem = 'v1:${base64Encode(loaded)}';
            _webMemoryKeys[fromKey] = mem;
          }
        } on WebPinLockedException {
          await _webAdapter.copyEntry(
            fromStorageKey: fromKey,
            fromOwner: fromOwner,
            toStorageKey: toKey,
            toOwner: toOwner,
          );
          return;
        }
      }
      if (mem != null) {
        final rawBytes = Uint8List.fromList(_decode(mem));
        _webMemoryKeys[toKey] = mem;
        await _webAdapter.writePersistentKey(toKey, toOwner, rawBytes);
      }
      return;
    }
    final k = await _storage.read(key: fromKey);
    if (k != null) {
      await _storage.write(key: toKey, value: k);
    }
  });

  /// Valida a chave e a identidade de um cofre já conhecido antes de guardar a chave.
  Future<void> restoreVerified({
    required String owner,
    required String phrase,
    required String confirmation,
    required Map<String, dynamic> marker,
    required String expectedVaultId,
    String? webUnlockPin,
  }) async {
    final key = await RecoveryCrypto.keyFromPhrase(phrase);
    final id = await RecoveryVaultVerifier.verify(
      root: key,
      owner: owner,
      marker: marker,
    );
    if (id != expectedVaultId) {
      throw StateError('Identidade do cofre não confere; chave não instalada.');
    }
    await install(
      owner: owner,
      phrase: phrase,
      confirmation: confirmation,
      webUnlockPin: webUnlockPin,
    );
  }

  /// Instala a chave derivada no armazenamento local seguro.
  /// Quando [webUnlockPin] é informado no modo Web, encapsula a chave no IndexedDB com
  /// PBKDF2-HMAC-SHA256 em vez de desbloqueio automático sem PIN.
  Future<void> install({
    required String owner,
    required String phrase,
    required String confirmation,
    String? webUnlockPin,
  }) => _serialized(() async {
    final storageKey = _storageKey(owner);
    final proposed = await (await RecoveryCrypto.keyFromPhrase(phrase))
        .extractBytes();
    final confirmed = await (await RecoveryCrypto.keyFromPhrase(confirmation))
        .extractBytes();
    if (!_equal(proposed, confirmed)) {
      throw const FormatException('A confirmação da frase não confere.');
    }

    if (_useWebStore) {
      final serialized = 'v1:${base64Encode(proposed)}';
      final currentMem = _webMemoryKeys[storageKey];
      if (currentMem != null) {
        if (!_equal(_decode(currentMem), proposed)) {
          throw StateError(
            'Já existe outra chave local para esta conta; ela não foi substituída.',
          );
        }
      } else {
        try {
          final existingPersisted = await _webAdapter.readKey(
            storageKey,
            owner,
          );
          if (existingPersisted != null &&
              !_equal(existingPersisted, proposed)) {
            throw StateError(
              'Já existe outra chave local para esta conta; ela não foi substituída.',
            );
          }
        } on WebPinLockedException {
          if (webUnlockPin != null && webUnlockPin.trim().isNotEmpty) {
            final unlocked = await _webAdapter.unlockWithPin(
              storageKey,
              owner,
              webUnlockPin,
            );
            if (!_equal(unlocked, proposed)) {
              throw StateError(
                'Já existe outra chave local protegida por PIN para esta conta.',
              );
            }
          } else {
            throw const WebPinLockedException();
          }
        }
      }

      final proposedBytes = Uint8List.fromList(proposed);
      if (webUnlockPin != null && webUnlockPin.trim().isNotEmpty) {
        await _webAdapter.writePinProtectedKey(
          storageKey,
          owner,
          proposedBytes,
          webUnlockPin,
        );
      } else {
        await _webAdapter.writePersistentKey(storageKey, owner, proposedBytes);
      }
      _webMemoryKeys[storageKey] = serialized;
      return;
    }

    final current = await _storage.read(key: storageKey);
    if (current != null) {
      if (!_equal(_decode(current), proposed)) {
        throw StateError(
          'Já existe outra chave local para esta conta; ela não foi substituída.',
        );
      }
      return;
    }
    final serialized = 'v1:${base64Encode(proposed)}';
    await _storage.write(key: storageKey, value: serialized);

    final stored = await _storage.read(key: storageKey);
    if (stored == null || !_equal(_decode(stored), proposed)) {
      throw StateError('Não foi possível confirmar a gravação da chave local.');
    }
  });

  /// Limpa as credenciais locais
  Future<void> clear(String owner) => _serialized(() async {
    final storageKey = _storageKey(owner);
    if (_useWebStore) {
      _webMemoryKeys.remove(storageKey);
      await _webAdapter.deleteKey(storageKey);
      return;
    }
    await _storage.delete(key: storageKey);
  });
}
