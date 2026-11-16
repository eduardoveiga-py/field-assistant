import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

import 'recovery_crypto.dart';

/// Marcador experimental para conferir se uma chave abre um cofre existente.
/// Não cria nem consulta o servidor e não estabelece confiança na existência,
/// versão ou autenticidade da origem do cofre. Um servidor malicioso pode
/// suprimir ou substituir um cofre; descoberta segura exige estado confiável.
class RecoveryVaultVerifier {
  RecoveryVaultVerifier._();

  static const _kind = 'recovery-vault-verifier-v1';
  static const _marker = 'field-assistant/recovery-vault/v1';
  static final _idPattern = RegExp(r'^[0-9a-f]{32}$');

  static Future<SecretKey> _verifierKey(SecretKey root) =>
      Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
        secretKey: root,
        nonce: utf8.encode('field-assistant/vault-verifier-key/v1'),
      );

  /// É responsabilidade do protocolo superior instalar o marcador com uma
  /// operação atômica de criação exclusiva, nunca sobrescrever um existente.
  static Future<Map<String, Object>> create({
    required SecretKey root,
    required String owner,
  }) async {
    if (owner.isEmpty) throw ArgumentError('Conta inválida.');
    final random = Random.secure();
    final id = List.generate(16, (_) => random.nextInt(256))
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    final envelope = await RecoveryCrypto.seal(
      key: await _verifierKey(root),
      owner: owner,
      kind: _kind,
      id: id,
      plaintext: utf8.encode(jsonEncode([_marker, id])),
    );
    return {'version': 1, 'vaultId': id, 'envelope': envelope};
  }

  /// Lança em chave incorreta, alteração ou formato incompatível. O id
  /// retornado deve ser comparado com identidade previamente confiável quando
  /// disponível; sucesso isolado não comprova que o servidor não omitiu dados.
  static Future<String> verify({
    required SecretKey root,
    required String owner,
    required Map<String, dynamic> marker,
  }) async {
    if (owner.isEmpty || marker.length != 3 || marker['version'] != 1 ||
        marker['vaultId'] is! String || marker['envelope'] is! Map) {
      throw const FormatException('Marcador do cofre inválido.');
    }
    final id = marker['vaultId'] as String;
    if (!_idPattern.hasMatch(id)) throw const FormatException('Identidade do cofre inválida.');
    final plaintext = await RecoveryCrypto.open(
      key: await _verifierKey(root),
      owner: owner,
      kind: _kind,
      id: id,
      envelope: Map<String, dynamic>.from(marker['envelope'] as Map),
    );
    if (utf8.decode(plaintext) != jsonEncode([_marker, id])) {
      throw const FormatException('Marcador do cofre inválido.');
    }
    return id;
  }
}
