import 'dart:convert';

import 'package:crypto/crypto.dart' as digest;
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'recovery_crypto.dart';
import 'recovery_vault_verifier.dart';

/// Armazenamento local seguro da chave de recuperação E2EE.
/// Utiliza o serviço de credenciais nativo do sistema (Keychain / Keystore / DPAPI).
/// Armazena exclusivamente a chave derivada (SecretKey), nunca a frase em texto claro.
class RecoveryKeyStore {
  RecoveryKeyStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static Future<void> _tail = Future<void>.value();
  static final Map<String, String> _webMemoryKeys = {};

  @visibleForTesting
  static void resetForTesting() {
    _tail = Future<void>.value();
    _webMemoryKeys.clear();
  }

  static Future<T> _serialized<T>(Future<T> Function() op) {
    final result = _tail.then((_) => op());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  static String _storageKey(String owner) {
    if (owner.isEmpty || owner.trim() != owner) throw ArgumentError('Conta inválida.');
    return 'e2ee_root_v1_${digest.sha256.convert(utf8.encode(owner))}';
  }

  static List<int> _decode(String value) {
    if (!value.startsWith('v1:')) throw const FormatException('Chave local inválida.');
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

  Future<SecretKey?> load(String owner) => _serialized(() async {
    if (kIsWeb) {
      final keyVal = _webMemoryKeys[owner];
      return keyVal == null ? null : SecretKey(_decode(keyVal));
    }
    final value = await _storage.read(key: _storageKey(owner));
    return value == null ? null : SecretKey(_decode(value));
  });

  /// Copia a chave de recuperação entre contas (ex: local_user para usuário autenticado)
  Future<void> copyOwnerKey({required String fromOwner, required String toOwner}) => _serialized(() async {
    if (fromOwner == toOwner) return;
    if (kIsWeb) {
      final k = _webMemoryKeys[fromOwner];
      if (k != null) _webMemoryKeys[toOwner] = k;
      return;
    }
    final k = await _storage.read(key: _storageKey(fromOwner));
    if (k != null) {
      await _storage.write(key: _storageKey(toOwner), value: k);
    }
  });

  /// Valida a chave e a identidade de um cofre já conhecido antes de guardar a chave.
  Future<void> restoreVerified({
    required String owner,
    required String phrase,
    required String confirmation,
    required Map<String, dynamic> marker,
    required String expectedVaultId,
  }) async {
    final key = await RecoveryCrypto.keyFromPhrase(phrase);
    final id = await RecoveryVaultVerifier.verify(root: key, owner: owner, marker: marker);
    if (id != expectedVaultId) {
      throw StateError('Identidade do cofre não confere; chave não instalada.');
    }
    await install(owner: owner, phrase: phrase, confirmation: confirmation);
  }

  /// Instala a chave derivada no armazenamento local seguro.
  Future<void> install({
    required String owner,
    required String phrase,
    required String confirmation,
  }) => _serialized(() async {
    final storageKey = _storageKey(owner);
    final proposed = await (await RecoveryCrypto.keyFromPhrase(phrase)).extractBytes();
    final confirmed = await (await RecoveryCrypto.keyFromPhrase(confirmation)).extractBytes();
    if (!_equal(proposed, confirmed)) throw const FormatException('A confirmação da frase não confere.');

    if (kIsWeb) {
      final current = _webMemoryKeys[owner];
      if (current != null && !_equal(_decode(current), proposed)) {
        throw StateError('Já existe outra chave local para esta conta; ela não foi substituída.');
      }
      final serialized = 'v1:${base64Encode(proposed)}';
      _webMemoryKeys[owner] = serialized;
      return;
    }

    final current = await _storage.read(key: storageKey);
    if (current != null) {
      if (!_equal(_decode(current), proposed)) {
        throw StateError('Já existe outra chave local para esta conta; ela não foi substituída.');
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
    if (kIsWeb) {
      _webMemoryKeys.remove(owner);
      return;
    }
    await _storage.delete(key: _storageKey(owner));
  });
}
