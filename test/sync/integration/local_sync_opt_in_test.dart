import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/sync/crypto/e2ee_service.dart';
import 'package:ministerio_pessoal/sync/crypto/recovery_crypto.dart';
import 'package:ministerio_pessoal/sync/crypto/recovery_key_store.dart';
import 'package:ministerio_pessoal/sync/supabase_sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final enabled = Platform.environment['FA_RUN_LOCAL_SUPABASE_E2E'] == '1';
  if (enabled) HttpOverrides.global = null;

  test(
    'managed local debug opt-in sends synthetic outbox without override',
    () async {
      const url = 'http://127.0.0.1:54321';
      final key = Platform.environment['FA_LOCAL_SUPABASE_ANON_KEY'];
      if (key == null || key.isEmpty) throw StateError('Local key missing');
      FlutterSecureStorage.setMockInitialValues({});
      RecoveryKeyStore.resetForTesting();
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final repo = AppRepository(db);
      SupabaseSyncService? sync;
      try {
        await SupabaseSyncService.configureAndInitialize(
          url: url,
          anonKey: key,
          authOptionsForTesting: const FlutterAuthClientOptions(
            authFlowType: AuthFlowType.implicit,
            localStorage: EmptyLocalStorage(),
            detectSessionInUri: false,
          ),
        );
        expect(SupabaseSyncService.localTestSyncActive, isTrue);
        final client = Supabase.instance.client;
        final result = await client.auth.signUp(
          email: 'fa-optin-${DateTime.now().microsecondsSinceEpoch}@example.com',
          password: 'synthetic-local-password-2026',
        );
        expect(result.session, isNotNull);
        final owner = result.user!.id;
        final e2ee = E2eeService(db: db);
        await e2ee.setupVaultWithPhrase(owner, RecoveryCrypto.createPhrase());
        sync = SupabaseSyncService(
          db: db,
          repository: repo,
          e2eeServiceOverride: e2ee,
        );
        const name = 'Fictional local opt in person';
        await repo.createPerson(name: name);
        final pushed = await sync.processQueue();
        expect(pushed.failureCount, 0, reason: pushed.errors.join('; '));
        expect(pushed.successCount, greaterThanOrEqualTo(1));
        final records = await client.from('encrypted_records').select('envelope');
        expect(records, isNotEmpty);
        expect(jsonEncode(records), isNot(contains(name)));
        await expectLater(
          SupabaseSyncService.configureAndInitialize(url: url, anonKey: key),
          throwsStateError,
        );
        await expectLater(
          SupabaseSyncService.clearRuntimeConfig(),
          throwsStateError,
        );
      } finally {
        sync?.dispose();
        await db.close();
        // This singleton belongs exclusively to the isolated test process.
        if (SupabaseSyncService.isInitialized) await Supabase.instance.dispose();
        await SupabaseSyncService.clearRuntimeConfig();
      }
    },
    skip: !enabled,
  );
}
