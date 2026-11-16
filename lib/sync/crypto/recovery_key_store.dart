import 'dart:convert';

import 'package:crypto/crypto.dart' as digest;
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'recovery_crypto.dart';
import 'recovery_vault_verifier.dart';

/// Armazenamento local experimental. Não estabelece ou verifica um cofre no
/// servidor, não ativa sincronização e não altera chaves já existentes.
class RecoveryKeyStore {
  RecoveryKeyStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static Future<void> _tail = Future<void>.value();

  static Future<T> _serialized<T>(Future<T> Function() op) {
    final result = _tail.then((_) => op());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  static String _storageKey(String owner) {
    if (kIsWeb) throw UnsupportedError('Armazenamento de chave para a Web ainda não foi validado.');
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
    for (var i = 0; i < a.length; i++) { diff |= a[i] ^ b[i]; }
    return diff == 0;
  }

  Future<SecretKey?> load(String owner) => _serialized(() async {
    final value = await _storage.read(key: _storageKey(owner));
    return value == null ? null : SecretKey(_decode(value));
  });

  /// Valida a chave e a identidade de um cofre já conhecido antes de guardar a
  /// chave. O chamador precisa obter [expectedVaultId] por uma fonte confiável
  /// independente do servidor e deve rejeitar ausência/falha na leitura remota.
  /// Esta verificação isolada não habilita a sincronização nem detecta replay.
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

  /// Exige repetição integral da frase e recusa substituir outra chave local.
  /// A confirmação de que a frase pertence ao cofre remoto é tarefa separada e
  /// obrigatória antes de qualquer uso para sincronização.
  Future<void> install({
    required String owner,
    required String phrase,
    required String confirmation,
  }) => _serialized(() async {
    final storageKey = _storageKey(owner);
    final proposed = await (await RecoveryCrypto.keyFromPhrase(phrase)).extractBytes();
    final confirmed = await (await RecoveryCrypto.keyFromPhrase(confirmation)).extractBytes();
    if (!_equal(proposed, confirmed)) throw const FormatException('A confirmação da frase não confere.');
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
}
