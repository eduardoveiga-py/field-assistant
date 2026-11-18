import 'dart:convert';

import 'package:crypto/crypto.dart' as digest;
import 'package:cryptography/cryptography.dart';

import 'recovery_crypto.dart';

/// Protótipo de envelope de registro; ainda não escreve nem lê Supabase.
/// O servidor verá proprietário, identificador opaco, tamanho e revisão.
/// Autenticar a revisão não impede replay de uma versão antiga válida: o
/// protocolo de sincronização precisa de estado confiável e verificação CAS.
class EncryptedRecord {
  EncryptedRecord._();

  static const _kind = 'record-v1';
  static final _routePattern = RegExp(r'^[0-9a-f]{64}$');

  static void _validate(String owner, String route, int revision) {
    if (owner.isEmpty ||
        !_routePattern.hasMatch(route) ||
        revision < 1 ||
        revision > 9007199254740991) {
      throw const FormatException('Contexto de registro inválido.');
    }
  }

  /// Identificador estável e opaco por conta, tipo e ID, usando chave separada.
  static Future<String> route({
    required SecretKey key,
    required String owner,
    required String entityType,
    required String entityId,
  }) async {
    if (owner.isEmpty || entityType.isEmpty || entityId.isEmpty) {
      throw const FormatException('Identidade de registro inválida.');
    }
    final routingKey = await Hkdf(hmac: Hmac.sha256(), outputLength: 32)
        .deriveKey(
          secretKey: key,
          nonce: utf8.encode('field-assistant/record-routing/v1'),
        );
    final hmac = digest.Hmac(digest.sha256, await routingKey.extractBytes());
    return hmac
        .convert(utf8.encode(jsonEncode([owner, entityType, entityId])))
        .toString();
  }

  static Future<Map<String, Object>> seal({
    required SecretKey key,
    required String owner,
    required String entityType,
    required String entityId,
    required int revision,
    required Map<String, dynamic> data,
  }) async {
    if (data.containsKey('id') && data['id'] != entityId) {
      throw const FormatException('Identificador do conteúdo inconsistente.');
    }
    final opaqueId = await route(
      key: key,
      owner: owner,
      entityType: entityType,
      entityId: entityId,
    );
    _validate(owner, opaqueId, revision);
    final payload = utf8.encode(
      jsonEncode({
        'version': 1,
        'entityType': entityType,
        'entityId': entityId,
        'data': data,
      }),
    );
    final box = await RecoveryCrypto.seal(
      key: key,
      owner: owner,
      kind: _kind,
      id: jsonEncode([opaqueId, revision]),
      plaintext: payload,
    );
    return {'route': opaqueId, 'revision': revision, 'envelope': box};
  }

  static Future<Map<String, dynamic>> open({
    required SecretKey key,
    required String owner,
    required String routeId,
    required int revision,
    required Map<String, dynamic> envelope,
  }) async {
    _validate(owner, routeId, revision);
    final bytes = await RecoveryCrypto.open(
      key: key,
      owner: owner,
      kind: _kind,
      id: jsonEncode([routeId, revision]),
      envelope: envelope,
    );
    final payload = jsonDecode(utf8.decode(bytes));
    if (payload is! Map ||
        payload.length != 4 ||
        payload['version'] != 1 ||
        payload['entityType'] is! String ||
        payload['entityId'] is! String ||
        payload['data'] is! Map) {
      throw const FormatException('Registro cifrado inválido.');
    }
    final data = payload['data'] as Map;
    if (data.containsKey('id') && data['id'] != payload['entityId']) {
      throw const FormatException('Identificador do conteúdo inconsistente.');
    }
    final expected = await route(
      key: key,
      owner: owner,
      entityType: payload['entityType'] as String,
      entityId: payload['entityId'] as String,
    );
    if (expected != routeId) {
      throw const FormatException('Identidade de registro inconsistente.');
    }
    return Map<String, dynamic>.from(payload);
  }
}
