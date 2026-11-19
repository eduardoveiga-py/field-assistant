import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/sync/supabase_sync_service.dart';
import 'package:ministerio_pessoal/sync/sync_privacy_policy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bloqueio preserva fila e dados e não faz requisições', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = AppRepository(db);
    var requests = 0;
    final httpClient = MockClient((request) async {
      requests++;
      return http.Response(jsonEncode([]), 200);
    });
    final sync = SupabaseSyncService(
      db: db,
      repository: repo,
      clientOverride: SupabaseClient(
        'https://mock.supabase.co',
        'key',
        httpClient: httpClient,
      ),
    );
    addTearDown(() async {
      sync.dispose();
      await db.close();
    });

    final person = await repo.createPerson(name: 'Dado privado');
    final before = await db.select(db.syncQueue).get();
    expect(before, isNotEmpty);
    final results = [
      await sync.sync(),
      await sync.processQueue(),
      await sync.fetchRemoteChanges(),
    ];
    for (final result in results) {
      expect(result.success, isFalse);
      expect(result.message, contains('pausada'));
    }
    expect(await sync.retryPendingMediaDownloads(), 0);
    expect(await sync.deleteTicunaAudio('word'), isFalse);
    expect(await sync.deleteVoiceNoteAudio('note'), isFalse);
    expect(await sync.resolveConflictAcceptRemote(before.first.id), isFalse);
    expect(await db.select(db.syncQueue).get(), before);
    expect((await repo.getPersonById(person.id))!.name, 'Dado privado');
    expect(requests, 0);
    expect(SyncPrivacyPolicy.unencryptedMediaAllowed, isFalse);
    expect(SyncPrivacyPolicy.mediaProtocolVerified, isFalse);
    expect(SyncPrivacyPolicy.isCloudSyncEnabled, isFalse);
    expect(SyncPrivacyPolicy.canRunRemoteSync(), isFalse);
  });
}
