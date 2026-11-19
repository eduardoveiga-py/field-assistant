import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ministerio_pessoal/sync/crypto/encrypted_media.dart';
import 'package:ministerio_pessoal/sync/crypto/immutable_encrypted_media.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Auth extends GoTrueClient {
  String? userId = 'owner';
  @override
  User? get currentUser => userId == null ? null : User(
    id: userId!, appMetadata: const {}, userMetadata: const {},
    aud: 'authenticated', createdAt: '2026-01-01T00:00:00Z',
  );
}

class _Client extends SupabaseClient {
  final _Auth fakeAuth;
  _Client(this.fakeAuth, http.Client client)
      : super('https://mock.supabase.co', 'anon', httpClient: client);
  @override
  GoTrueClient get auth => fakeAuth;
}

// Storage's binary upload can be a raw request or a multipart form.
Uint8List _body(http.Request request) {
  final contentType = request.headers['content-type'] ?? '';
  final match = RegExp(r'boundary=([^\s;]+)').firstMatch(contentType);
  if (match == null) return request.bodyBytes;
  final text = utf8.decode(request.bodyBytes);
  for (final part in text.split('--${match.group(1)}')) {
    final split = part.indexOf('\r\n\r\n');
    if (split < 0 || !part.substring(0, split).contains('filename=')) continue;
    var body = part.substring(split + 4);
    if (body.endsWith('\r\n')) body = body.substring(0, body.length - 2);
    return Uint8List.fromList(utf8.encode(body));
  }
  throw StateError('Missing multipart file');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Auth auth;
  late _Client client;
  late ImmutableEncryptedMedia media;
  late Map<String, Uint8List> objects;
  late List<String> requests;
  bool failChunk = false;
  bool changeAccount = false;
  bool corruptDownload = false;

  setUp(() async {
    auth = _Auth();
    objects = {};
    requests = [];
    failChunk = false;
    changeAccount = false;
    corruptDownload = false;
    final httpClient = MockClient((request) async {
      final path = request.url.path;
      requests.add('${request.method} $path');
      if (request.method == 'POST') {
        expect(request.headers['x-upsert'] ?? 'false', 'false');
        if (failChunk && path.contains('chunk_')) {
          return http.Response('{"message":"upload failed"}', 500, headers: {'content-type': 'application/json'});
        }
        if (objects.containsKey(path)) {
          return http.Response('{"message":"duplicate"}', 409, headers: {'content-type': 'application/json'});
        }
        objects[path] = _body(request);
        if (changeAccount) auth.userId = 'other';
        return http.Response(jsonEncode({'Key': path}), 200, headers: {'content-type': 'application/json'});
      }
      if (request.method == 'GET' && objects.containsKey(path)) {
        return http.Response.bytes(corruptDownload ? utf8.encode('[]') : objects[path]!, 200);
      }
      return http.Response('{"message":"not found"}', 404, headers: {'content-type': 'application/json'});
    });
    client = _Client(auth, httpClient);
    media = ImmutableEncryptedMedia(client: client, owner: 'owner', key: await AesGcm.with256bits().newSecretKey());
  });
  tearDown(() async => client.dispose());

  test('strict reference serialization and limits', () {
    final ref = ImmutableMediaReference(versionId: 'a' * 32, sizeBytes: 12, sha256: 'b' * 64);
    expect(ImmutableMediaReference.fromJson(ref.toJson()).toJson(), ref.toJson());
    for (final value in [
      <String, dynamic>{},
      {'format': 1, 'versionId': 'a' * 32, 'sizeBytes': 12, 'sha256': 'b' * 64},
      {'format': 2, 'versionId': '../bad', 'sizeBytes': 12, 'sha256': 'b' * 64},
      {'format': 2, 'versionId': 'a' * 32, 'sizeBytes': -1, 'sha256': 'b' * 64},
      {'format': 2, 'versionId': 'a' * 32, 'sizeBytes': EncryptedMedia.chunkSize * EncryptedMedia.maxChunks + 1, 'sha256': 'b' * 64},
      {'format': 2, 'versionId': 'a' * 32, 'sizeBytes': 12, 'sha256': 'bad'},
      {'format': 2, 'versionId': 'a' * 32, 'sizeBytes': 12.0, 'sha256': 'b' * 64},
      {...ref.toJson(), 'extra': true},
    ]) {
      expect(() => ImmutableMediaReference.fromJson(value), throwsFormatException);
    }
  });

  test('stages and verifies empty and multi-chunk data without mutable objects', () async {
    for (final data in [Uint8List(0), Uint8List.fromList(List.generate(EncryptedMedia.chunkSize + 5, (i) => i % 251))]) {
      final ref = await media.stage(bucket: 'voice_notes', mediaId: 'sample', plaintextBytes: data);
      expect(await media.download(bucket: 'voice_notes', mediaId: 'sample', reference: ref), data);
      final badHash = ImmutableMediaReference(versionId: ref.versionId, sizeBytes: ref.sizeBytes, sha256: '0' * 64);
      await expectLater(media.download(bucket: 'voice_notes', mediaId: 'sample', reference: badHash), throwsFormatException);
      if (data.isNotEmpty) {
        final short = ImmutableMediaReference(versionId: ref.versionId, sizeBytes: 0, sha256: ref.sha256);
        await expectLater(media.download(bucket: 'voice_notes', mediaId: 'sample', reference: short), throwsFormatException);
      }
    }
    expect(requests.any((request) => request.startsWith('DELETE ')), isFalse);
    expect(objects.keys.every((path) => path.contains('/v2_')), isTrue);
  });

  test('invalid context and unauthenticated session make no storage request', () async {
    await expectLater(media.stage(bucket: 'wrong', mediaId: 'valid', plaintextBytes: Uint8List(0)), throwsArgumentError);
    await expectLater(media.stage(bucket: 'voice_notes', mediaId: '../escape', plaintextBytes: Uint8List(0)), throwsArgumentError);
    auth.userId = 'other';
    await expectLater(media.stage(bucket: 'voice_notes', mediaId: 'valid', plaintextBytes: Uint8List(0)), throwsStateError);
    expect(requests, isEmpty);
  });

  test('failed upload and account switch cannot yield a reference or delete data', () async {
    failChunk = true;
    await expectLater(media.stage(bucket: 'voice_notes', mediaId: 'sample', plaintextBytes: Uint8List.fromList([1])), throwsA(anything));
    expect(objects, isEmpty);
    failChunk = false;
    changeAccount = true;
    await expectLater(media.stage(bucket: 'voice_notes', mediaId: 'sample', plaintextBytes: Uint8List.fromList([1])), throwsStateError);
    expect(objects.keys.any((path) => path.endsWith('manifest.enc')), isFalse);
    expect(requests.any((request) => request.startsWith('DELETE ')), isFalse);
  });

  test('malformed manifest cannot be returned as plaintext', () async {
    final ref = await media.stage(bucket: 'voice_notes', mediaId: 'sample', plaintextBytes: Uint8List.fromList([1]));
    corruptDownload = true;
    await expectLater(media.download(bucket: 'voice_notes', mediaId: 'sample', reference: ref), throwsFormatException);
  });
}
