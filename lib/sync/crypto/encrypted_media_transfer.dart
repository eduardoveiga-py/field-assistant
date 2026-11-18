import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../sync_privacy_policy.dart';
import 'encrypted_media.dart';

/// Adaptador de transferência criptografada de mídias para os 4 buckets do Supabase Storage
/// (`voice_notes`, `ticuna_audio`, `knowledge_vault`, `person_photos`) — FA-SEC-03.
///
/// Regras:
/// - Criptografa todos os blocos com AES-256-GCM antes de qualquer upload.
/// - Publica o manifesto autenticado apenas após todos os blocos serem gravados.
/// - Nunca envia nem aceita binários em texto claro quando [SyncPrivacyPolicy.unencryptedMediaAllowed] é false.
class EncryptedMediaTransfer {
  static const Set<String> supportedBuckets = {
    'voice_notes',
    'ticuna_audio',
    'knowledge_vault',
    'person_photos',
  };

  final SupabaseClient client;
  final String owner;
  final SecretKey key;

  EncryptedMediaTransfer({
    required this.client,
    required this.owner,
    required this.key,
  });

  static String _sanitizeMediaId(String mediaId) {
    final clean = mediaId.trim();
    if (clean.isEmpty ||
        clean.contains('/') ||
        clean.contains('\\') ||
        clean.contains('..') ||
        clean.contains('\x00')) {
      throw ArgumentError.value(
        mediaId,
        'mediaId',
        'Identificador de mídia inválido.',
      );
    }
    return clean;
  }

  void _checkBucketAndOwner(String bucket) {
    if (!supportedBuckets.contains(bucket)) {
      throw ArgumentError.value(bucket, 'bucket', 'Bucket não suportado.');
    }
    if (owner.isEmpty) {
      throw StateError(
        'Proprietário ausente para transferência de mídia E2EE.',
      );
    }
    if (SyncPrivacyPolicy.unencryptedMediaAllowed) {
      throw StateError('Política de privacidade exige mídia criptografada.');
    }
  }

  String _chunkPath(String safeMediaId, int index) =>
      '$owner/e2ee/$safeMediaId/chunk_$index.enc';

  String manifestPath(String mediaId) =>
      '$owner/e2ee/${_sanitizeMediaId(mediaId)}/manifest.enc';

  /// Criptografa [plaintextBytes] em blocos autenticados e publica o manifesto ao final.
  /// Retorna o caminho do manifesto cifrado no Storage.
  Future<String> uploadEncrypted({
    required String bucket,
    required String mediaId,
    required Uint8List plaintextBytes,
  }) async {
    _checkBucketAndOwner(bucket);
    final safeId = _sanitizeMediaId(mediaId);
    final uploadedChunks = <String>[];

    try {
      final manifest = await EncryptedMedia.encrypt(
        key: key,
        owner: owner,
        mediaId: '$bucket:$safeId',
        source: Stream<List<int>>.value(plaintextBytes),
        storeChunk: (index, envelope) async {
          final path = _chunkPath(safeId, index);
          final encoded = Uint8List.fromList(utf8.encode(jsonEncode(envelope)));
          await client.storage
              .from(bucket)
              .uploadBinary(
                path,
                encoded,
                fileOptions: const FileOptions(
                  contentType: 'application/octet-stream',
                  upsert: true,
                ),
              );
          uploadedChunks.add(path);
        },
      );

      final mPath = manifestPath(safeId);
      final encodedManifest = Uint8List.fromList(
        utf8.encode(jsonEncode(manifest)),
      );
      await client.storage
          .from(bucket)
          .uploadBinary(
            mPath,
            encodedManifest,
            fileOptions: const FileOptions(
              contentType: 'application/octet-stream',
              upsert: true,
            ),
          );
      return mPath;
    } catch (_) {
      // Remove blocos órfãos gravados antes da falha (melhor esforço).
      if (uploadedChunks.isNotEmpty) {
        try {
          await client.storage.from(bucket).remove(uploadedChunks);
        } catch (_) {}
      }
      rethrow;
    }
  }

  /// Baixa e autentica manifesto + todos os blocos antes de devolver os bytes decifrados.
  Future<Uint8List> downloadDecrypted({
    required String bucket,
    required String mediaId,
  }) async {
    _checkBucketAndOwner(bucket);
    final safeId = _sanitizeMediaId(mediaId);
    final rawManifest = await client.storage
        .from(bucket)
        .download(manifestPath(safeId));
    final decodedManifest = jsonDecode(utf8.decode(rawManifest));
    if (decodedManifest is! Map) {
      throw const FormatException('Manifesto criptografado de mídia inválido.');
    }

    final builder = BytesBuilder(copy: false);
    await for (final chunk in EncryptedMedia.decrypt(
      key: key,
      owner: owner,
      mediaId: '$bucket:$safeId',
      manifestEnvelope: Map<String, dynamic>.from(decodedManifest),
      fetchChunk: (index) async {
        final rawChunk = await client.storage
            .from(bucket)
            .download(_chunkPath(safeId, index));
        final decoded = jsonDecode(utf8.decode(rawChunk));
        if (decoded is! Map) {
          throw const FormatException('Bloco criptografado de mídia inválido.');
        }
        return Map<String, dynamic>.from(decoded);
      },
    )) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  /// Remove manifesto e eventuais blocos conhecidos no Storage (limpeza de órfãos/exclusão).
  Future<void> deleteEncrypted({
    required String bucket,
    required String mediaId,
    int maxChunkProbe = 16,
  }) async {
    _checkBucketAndOwner(bucket);
    final safeId = _sanitizeMediaId(mediaId);
    final targets = <String>[
      manifestPath(safeId),
      for (var i = 0; i < maxChunkProbe; i++) _chunkPath(safeId, i),
    ];
    await client.storage.from(bucket).remove(targets);
  }
}
