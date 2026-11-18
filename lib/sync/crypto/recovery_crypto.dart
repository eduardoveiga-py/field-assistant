import 'dart:convert';
import 'dart:typed_data';

import 'package:bip39_mnemonic/bip39_mnemonic.dart';
import 'package:cryptography/cryptography.dart';

/// Primitivas experimentais, ainda NÃO conectadas à sincronização ou à UI.
/// Não transmitem nem armazenam a frase, chave ou conteúdo por conta própria.
class RecoveryCrypto {
  RecoveryCrypto._();

  /// Vinte e quatro palavras BIP39 em português, criadas com Random.secure.
  static String createPhrase() => Mnemonic.generate(
    Language.portuguese,
    length: MnemonicLength.words24,
  ).sentence;

  /// Apenas frases de 24 palavras geradas no formato definido aqui são aceitas.
  /// Não recebe senha escolhida pelo usuário: usa 256 bits de entropia aleatória.
  static Future<SecretKey> keyFromPhrase(String phrase) async {
    final words = phrase.trim().split(RegExp(r'\s+'));
    if (words.length != 24) {
      throw const FormatException('Frase de recuperação inválida.');
    }
    try {
      final mnemonic = Mnemonic.fromWords(
        words: words,
        language: Language.portuguese,
      );
      if (mnemonic.entropy.length != 32) {
        throw const FormatException('Entropia inválida.');
      }
      // HKDF com domínio específico; a frase codifica uma chave aleatória, não
      // uma senha curta. Nunca substituir por texto escolhido pelo usuário.
      return await Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
        secretKey: SecretKey(mnemonic.entropy),
        nonce: utf8.encode('field-assistant/recovery-root/v1'),
      );
    } catch (_) {
      throw const FormatException('Frase de recuperação inválida.');
    }
  }

  static List<int> _context(String owner, String kind, String id) {
    if (owner.isEmpty || kind.isEmpty || id.isEmpty) {
      throw ArgumentError('Contexto de criptografia incompleto.');
    }
    return utf8.encode(jsonEncode(['field-assistant', 1, owner, kind, id]));
  }

  /// Envelope único AES-256-GCM, autenticado ao contexto externo esperado.
  /// Mídia grande precisa de protocolo próprio de blocos e manifesto autenticado.
  static Future<Map<String, Object>> seal({
    required SecretKey key,
    required String owner,
    required String kind,
    required String id,
    required List<int> plaintext,
  }) async {
    if (plaintext.length > 1024 * 1024) {
      throw ArgumentError('Bloco excede 1 MiB.');
    }
    final box = await AesGcm.with256bits().encrypt(
      plaintext,
      secretKey: key,
      aad: _context(owner, kind, id),
    );
    return {
      'v': 1,
      'algorithm': 'A256GCM',
      'nonce': base64Encode(box.nonce),
      'ciphertext': base64Encode(box.cipherText),
      'tag': base64Encode(box.mac.bytes),
    };
  }

  static Future<Uint8List> open({
    required SecretKey key,
    required String owner,
    required String kind,
    required String id,
    required Map<String, dynamic> envelope,
  }) async {
    if (envelope.length != 5 ||
        envelope['v'] != 1 ||
        envelope['algorithm'] != 'A256GCM' ||
        envelope['nonce'] is! String ||
        envelope['ciphertext'] is! String ||
        envelope['tag'] is! String ||
        (envelope['nonce'] as String).length != 16 ||
        (envelope['tag'] as String).length != 24 ||
        (envelope['ciphertext'] as String).length > 1398104) {
      throw const FormatException(
        'Envelope criptografado inválido ou não suportado.',
      );
    }
    final nonce = base64Decode(envelope['nonce'] as String);
    final ciphertext = base64Decode(envelope['ciphertext'] as String);
    final tag = base64Decode(envelope['tag'] as String);
    if (nonce.length != 12 ||
        tag.length != 16 ||
        ciphertext.length > 1024 * 1024) {
      throw const FormatException('Envelope criptografado inválido.');
    }
    final plaintext = await AesGcm.with256bits().decrypt(
      SecretBox(ciphertext, nonce: nonce, mac: Mac(tag)),
      secretKey: key,
      aad: _context(owner, kind, id),
    );
    return Uint8List.fromList(plaintext);
  }
}
