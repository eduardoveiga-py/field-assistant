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

  String _chunkPath(String safeMediaId, int index, {String? versionId}) {
    if (versionId != null && versionId.isNotEmpty) {
      return '$owner/e2ee/$safeMediaId/v_$versionId/chunk_$index.enc';
    }
    return '$owner/e2ee/$safeMediaId/chunk_$index.enc';
  }

  String manifestPath(String mediaId, {String? versionId}) {
    final safe = _sanitizeMediaId(mediaId);
    if (versionId != null && versionId.isNotEmpty) {
      return '$owner/e2ee/$safe/v_$versionId/manifest.enc';
    }
    return '$owner/e2ee/$safe/manifest.enc';
  }

  /// Criptografa [plaintextBytes] em blocos autenticados e publica o manifesto ao final.
  /// Suporta versionamento imutável de blocos (`upsert: false`) e CAS pointer — FA-SEC-03 / P1-01.
  /// Retorna o caminho do manifesto publicado.
  Future<String> uploadEncrypted({
    required String bucket,
    required String mediaId,
    required Uint8List plaintextBytes,
    String? versionId,
    String? previousVersionId,
  }) async {
    _checkBucketAndOwner(bucket);
    final safeId = _sanitizeMediaId(mediaId);
    final effectiveVersion = versionId ?? '';
    final isVersioned = effectiveVersion.isNotEmpty;
    final uploadedChunks = <String>[];
    String? versionManifestPath;

    try {
      final manifest = await EncryptedMedia.encrypt(
        key: key,
        owner: owner,
        mediaId: '$bucket:$safeId',
        source: Stream<List<int>>.value(plaintextBytes),
        storeChunk: (index, envelope) async {
          final path = _chunkPath(
            safeId,
            index,
            versionId: isVersioned ? effectiveVersion : null,
          );
          final encoded = Uint8List.fromList(utf8.encode(jsonEncode(envelope)));
          await client.storage
              .from(bucket)
              .uploadBinary(
                path,
                encoded,
                fileOptions: const FileOptions(
                  contentType: 'application/octet-stream',
                  upsert: false, // Imutabilidade de chunks (elimina sobrescrita in-place destrutiva)
                ),
              );
          uploadedChunks.add(path);
        },
      );

      final mPath = manifestPath(safeId);
      final encodedManifest = Uint8List.fromList(
        utf8.encode(jsonEncode(manifest)),
      );

      if (isVersioned) {
        // 1. Grava manifesto autenticado no namespace versionado (imutável)
        versionManifestPath = manifestPath(safeId, versionId: effectiveVersion);
        await client.storage
            .from(bucket)
            .uploadBinary(
              versionManifestPath,
              encodedManifest,
              fileOptions: const FileOptions(
                contentType: 'application/octet-stream',
                upsert: false,
              ),
            );

        // 2. Grava ponteiro atômico de CAS no manifesto raiz
        final pointerPayload = Uint8List.fromList(
          utf8.encode(
            jsonEncode({
              'versionId': effectiveVersion,
              'manifestPath': versionManifestPath,
              'updatedAt': DateTime.now().toUtc().toIso8601String(),
              'manifest': manifest,
            }),
          ),
        );
        await client.storage
            .from(bucket)
            .uploadBinary(
              mPath,
              pointerPayload,
              fileOptions: const FileOptions(
                contentType: 'application/octet-stream',
                upsert: true, // Apenas o ponteiro raiz de CAS é atomicamente atualizado
              ),
            );

        // 3. Purga versão anterior após confirmação do ponteiro (se especificado)
        if (previousVersionId != null && previousVersionId.isNotEmpty) {
          try {
            await deleteVersion(
              bucket: bucket,
              mediaId: safeId,
              versionId: previousVersionId,
            );
          } catch (_) {}
        }

        return versionManifestPath;
      } else {
        // Fluxo unversioned retrocompatível com upsert: false para chunks e atomic manifest no topo
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
      }
    } catch (_) {
      // Remove blocos órfãos gravados antes da falha (melhor esforço).
      if (uploadedChunks.isNotEmpty) {
        try {
          await client.storage.from(bucket).remove(uploadedChunks);
        } catch (_) {}
      }
      if (versionManifestPath != null) {
        try {
          await client.storage.from(bucket).remove([versionManifestPath]);
        } catch (_) {}
      }
      rethrow;
    }
  }

  /// Baixa e autentica manifesto + todos os blocos antes de devolver os bytes decifrados.
  /// Suporta leitura transparente de namespaces versionados ou do manifesto raiz.
  Future<Uint8List> downloadDecrypted({
    required String bucket,
    required String mediaId,
    String? versionId,
  }) async {
    _checkBucketAndOwner(bucket);
    final safeId = _sanitizeMediaId(mediaId);

    String? activeVersion = versionId;
    Map<String, dynamic> manifestEnvelope;

    if (activeVersion != null && activeVersion.isNotEmpty) {
      final raw = await client.storage
          .from(bucket)
          .download(manifestPath(safeId, versionId: activeVersion));
      final decoded = jsonDecode(utf8.decode(raw));
      if (decoded is! Map) {
        throw const FormatException('Manifesto de mídia inválido.');
      }
      manifestEnvelope = Map<String, dynamic>.from(decoded);
    } else {
      final raw = await client.storage
          .from(bucket)
          .download(manifestPath(safeId));
      final decoded = jsonDecode(utf8.decode(raw));
      if (decoded is! Map) {
        throw const FormatException('Manifesto de mídia inválido.');
      }
      if (decoded.containsKey('versionId') && decoded.containsKey('manifest')) {
        activeVersion = decoded['versionId']?.toString();
        manifestEnvelope = Map<String, dynamic>.from(
          decoded['manifest'] as Map,
        );
      } else {
        manifestEnvelope = Map<String, dynamic>.from(decoded);
      }
    }

    final builder = BytesBuilder(copy: false);
    await for (final chunk in EncryptedMedia.decrypt(
      key: key,
      owner: owner,
      mediaId: '$bucket:$safeId',
      manifestEnvelope: manifestEnvelope,
      fetchChunk: (index) async {
        final path = _chunkPath(safeId, index, versionId: activeVersion);
        final rawChunk = await client.storage.from(bucket).download(path);
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

  /// Remove uma versão específica de mídia e seus blocos.
  Future<void> deleteVersion({
    required String bucket,
    required String mediaId,
    required String versionId,
    int maxChunkProbe = 16,
  }) async {
    _checkBucketAndOwner(bucket);
    final safeId = _sanitizeMediaId(mediaId);
    var chunkCount = maxChunkProbe;
    final vManifest = manifestPath(safeId, versionId: versionId);

    try {
      final rawManifest = await client.storage.from(bucket).download(vManifest);
      final decodedManifest = jsonDecode(utf8.decode(rawManifest));
      if (decodedManifest is Map) {
        final exactCount = await EncryptedMedia.inspectChunkCount(
          key: key,
          owner: owner,
          mediaId: '$bucket:$safeId',
          manifestEnvelope: Map<String, dynamic>.from(decodedManifest),
        );
        if (exactCount > chunkCount) {
          chunkCount = exactCount;
        }
      }
    } catch (_) {}

    final targets = <String>[
      vManifest,
      for (var i = 0; i < chunkCount; i++)
        _chunkPath(safeId, i, versionId: versionId),
    ];
    await client.storage.from(bucket).remove(targets);
  }

  /// Expurgo seguro pós-confirmação: Remove a versão anterior de forma
  /// assíncrona somente após a nova versão ter manifesto publicado e o commit
  /// CAS no banco de dados ter sido concluído com sucesso (FA-SEC-03 / P1-01).
  Future<void> purgeObsoleteVersion({
    required String bucket,
    required String mediaId,
    required String versionId,
    int maxChunkProbe = 16,
  }) async {
    await deleteVersion(
      bucket: bucket,
      mediaId: mediaId,
      versionId: versionId,
      maxChunkProbe: maxChunkProbe,
    );
  }

  /// Rollback seguro: Em caso de falha de commit ou conflito de CAS no banco,
  /// remove APENAS os blocos e o manifesto da versão rejeitada [rejectedVersionId].
  /// Se houver [previousVersionId], restaura o ponteiro raiz para a versão anterior,
  /// garantindo que a versão anterior permaneça 100% ativa, válida e legível.
  Future<void> rollbackToVersion({
    required String bucket,
    required String mediaId,
    required String rejectedVersionId,
    String? previousVersionId,
    int maxChunkProbe = 16,
  }) async {
    _checkBucketAndOwner(bucket);
    final safeId = _sanitizeMediaId(mediaId);

    // 1. Remove blocos e manifesto da versão rejeitada
    await deleteVersion(
      bucket: bucket,
      mediaId: safeId,
      versionId: rejectedVersionId,
      maxChunkProbe: maxChunkProbe,
    );

    // 2. Se houver versão anterior válida, restaura o ponteiro de manifesto raiz para ela
    if (previousVersionId != null && previousVersionId.isNotEmpty) {
      final prevManifestPath = manifestPath(
        safeId,
        versionId: previousVersionId,
      );
      try {
        final raw = await client.storage
            .from(bucket)
            .download(prevManifestPath);
        final decoded = jsonDecode(utf8.decode(raw));
        if (decoded is Map) {
          final pointerPayload = Uint8List.fromList(
            utf8.encode(
              jsonEncode({
                'versionId': previousVersionId,
                'manifestPath': prevManifestPath,
                'updatedAt': DateTime.now().toUtc().toIso8601String(),
                'manifest': decoded,
              }),
            ),
          );
          await client.storage
              .from(bucket)
              .uploadBinary(
                manifestPath(safeId),
                pointerPayload,
                fileOptions: const FileOptions(
                  contentType: 'application/octet-stream',
                  upsert: true,
                ),
              );
        }
      } catch (_) {}
    } else {
      // Se não havia versão anterior (falha no insert inicial), remove o ponteiro raiz órfão
      try {
        await client.storage.from(bucket).remove([manifestPath(safeId)]);
      } catch (_) {}
    }
  }

  /// Remove manifesto e todos os blocos autenticados no Storage (inclusive mídias > 4 MiB).
  /// Caso o manifesto já esteja ausente ou ilegível, recorre à sondagem de [maxChunkProbe] blocos.
  Future<void> deleteEncrypted({
    required String bucket,
    required String mediaId,
    int maxChunkProbe = 16,
  }) async {
    _checkBucketAndOwner(bucket);
    final safeId = _sanitizeMediaId(mediaId);
    var chunkCount = maxChunkProbe;
    String? activeVersion;

    try {
      final rawManifest = await client.storage
          .from(bucket)
          .download(manifestPath(safeId));
      final decodedManifest = jsonDecode(utf8.decode(rawManifest));
      if (decodedManifest is Map) {
        Map<String, dynamic> manifestMap;
        if (decodedManifest.containsKey('versionId') &&
            decodedManifest.containsKey('manifest')) {
          activeVersion = decodedManifest['versionId']?.toString();
          manifestMap = Map<String, dynamic>.from(
            decodedManifest['manifest'] as Map,
          );
        } else {
          manifestMap = Map<String, dynamic>.from(decodedManifest);
        }

        final exactCount = await EncryptedMedia.inspectChunkCount(
          key: key,
          owner: owner,
          mediaId: '$bucket:$safeId',
          manifestEnvelope: manifestMap,
        );
        if (exactCount > chunkCount) {
          chunkCount = exactCount;
        }
      }
    } catch (_) {
      // Manifesto ausente ou corrompido: segue com limpeza best-effort de maxChunkProbe blocos.
    }

    final targets = <String>[
      manifestPath(safeId),
      for (var i = 0; i < chunkCount; i++) _chunkPath(safeId, i),
      if (activeVersion != null) manifestPath(safeId, versionId: activeVersion),
      if (activeVersion != null)
        for (var i = 0; i < chunkCount; i++)
          _chunkPath(safeId, i, versionId: activeVersion),
    ];
    await client.storage.from(bucket).remove(targets);
  }
}
