import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as digest;
import 'package:cryptography/cryptography.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'encrypted_media.dart';
import 'encrypted_media_transfer.dart';

/// A reference is authoritative only when read from an authenticated CAS record.
class ImmutableMediaReference {
  final String versionId;
  final int sizeBytes;
  final String sha256;

  ImmutableMediaReference({
    required this.versionId,
    required this.sizeBytes,
    required this.sha256,
  }) {
    if (!RegExp(r'^[0-9a-f]{32}$').hasMatch(versionId) ||
        sizeBytes < 0 ||
        sizeBytes > EncryptedMedia.chunkSize * EncryptedMedia.maxChunks ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(sha256)) {
      throw const FormatException('Referência imutável de mídia inválida.');
    }
  }

  Map<String, Object> toJson() => {
    'format': 2,
    'versionId': versionId,
    'sizeBytes': sizeBytes,
    'sha256': sha256,
  };

  factory ImmutableMediaReference.fromJson(Map<String, dynamic> json) {
    if (json.length != 4 ||
        json['format'] != 2 ||
        json['versionId'] is! String ||
        json['sizeBytes'] is! int ||
        json['sha256'] is! String) {
      throw const FormatException('Referência imutável de mídia inválida.');
    }
    return ImmutableMediaReference(
      versionId: json['versionId'] as String,
      sizeBytes: json['sizeBytes'] as int,
      sha256: json['sha256'] as String,
    );
  }
}

/// Experimental staging primitive. It never publishes a mutable pointer or
/// deletes blobs; callers must commit the reference in an encrypted CAS record.
class ImmutableEncryptedMedia {
  final SupabaseClient client;
  final String owner;
  final SecretKey key;

  ImmutableEncryptedMedia({
    required this.client,
    required this.owner,
    required this.key,
  });

  void _checkSession() {
    if (owner.isEmpty || client.auth.currentUser?.id != owner) {
      throw StateError('A conta autenticada não corresponde à mídia.');
    }
  }

  void _checkInput(String bucket, String mediaId) {
    if (!EncryptedMediaTransfer.supportedBuckets.contains(bucket)) {
      throw ArgumentError.value(bucket, 'bucket');
    }
    if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(mediaId)) {
      throw ArgumentError.value(mediaId, 'mediaId');
    }
  }

  String _path(String mediaId, String versionId, String object) =>
      '$owner/e2ee/$mediaId/v2_$versionId/$object';

  String _context(String bucket, String mediaId, String versionId) =>
      jsonEncode(['field-assistant-media-v2', bucket, mediaId, versionId]);

  static String _newVersionId() {
    final random = Random.secure();
    return List.generate(16, (_) => random.nextInt(256))
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  /// Writes a uniquely named version and verifies it by reading it back.
  /// A failure can leave encrypted orphan objects, never an active pointer.
  Future<ImmutableMediaReference> stage({
    required String bucket,
    required String mediaId,
    required Uint8List plaintextBytes,
  }) async {
    _checkSession();
    _checkInput(bucket, mediaId);
    if (plaintextBytes.length > EncryptedMedia.chunkSize * EncryptedMedia.maxChunks) {
      throw ArgumentError('Mídia excede o limite de blocos.');
    }
    final version = _newVersionId();
    final reference = ImmutableMediaReference(
      versionId: version,
      sizeBytes: plaintextBytes.length,
      sha256: digest.sha256.convert(plaintextBytes).toString(),
    );
    final manifest = await EncryptedMedia.encrypt(
      key: key,
      owner: owner,
      mediaId: _context(bucket, mediaId, version),
      source: Stream<List<int>>.value(plaintextBytes),
      storeChunk: (index, envelope) async {
        _checkSession();
        await client.storage.from(bucket).uploadBinary(
          _path(mediaId, version, 'chunk_$index.enc'),
          Uint8List.fromList(utf8.encode(jsonEncode(envelope))),
          fileOptions: const FileOptions(contentType: 'application/octet-stream', upsert: false),
        );
        _checkSession();
      },
    );
    _checkSession();
    await client.storage.from(bucket).uploadBinary(
      _path(mediaId, version, 'manifest.enc'),
      Uint8List.fromList(utf8.encode(jsonEncode(manifest))),
      fileOptions: const FileOptions(contentType: 'application/octet-stream', upsert: false),
    );
    _checkSession();
    // Never return a reference to an unreadable or partially uploaded version.
    await download(bucket: bucket, mediaId: mediaId, reference: reference);
    return reference;
  }

  /// Requires the reference from a verified encrypted record. No fallback to
  /// legacy mutable root manifests is allowed.
  Future<Uint8List> download({
    required String bucket,
    required String mediaId,
    required ImmutableMediaReference reference,
  }) async {
    _checkSession();
    _checkInput(bucket, mediaId);
    final version = reference.versionId;
    final raw = await client.storage.from(bucket).download(
      _path(mediaId, version, 'manifest.enc'),
    );
    _checkSession();
    final decoded = jsonDecode(utf8.decode(raw));
    if (decoded is! Map) throw const FormatException('Manifesto inválido.');
    final output = BytesBuilder(copy: false);
    var received = 0;
    await for (final bytes in EncryptedMedia.decrypt(
      key: key,
      owner: owner,
      mediaId: _context(bucket, mediaId, version),
      manifestEnvelope: Map<String, dynamic>.from(decoded),
      fetchChunk: (index) async {
        _checkSession();
        final chunk = await client.storage.from(bucket).download(
          _path(mediaId, version, 'chunk_$index.enc'),
        );
        _checkSession();
        final value = jsonDecode(utf8.decode(chunk));
        if (value is! Map) throw const FormatException('Bloco inválido.');
        return Map<String, dynamic>.from(value);
      },
    )) {
      received += bytes.length;
      if (received > reference.sizeBytes) {
        throw const FormatException('Mídia excede o tamanho autenticado.');
      }
      output.add(bytes);
    }
    final bytes = output.takeBytes();
    if (bytes.length != reference.sizeBytes ||
        digest.sha256.convert(bytes).toString() != reference.sha256) {
      throw const FormatException('Mídia difere da referência autenticada.');
    }
    _checkSession();
    return bytes;
  }
}
