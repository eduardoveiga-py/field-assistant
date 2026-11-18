import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/sync/crypto/encrypted_record.dart';
import 'package:ministerio_pessoal/sync/crypto/encrypted_record_checkpoint.dart';
import 'package:ministerio_pessoal/sync/crypto/encrypted_record_sync.dart';
import 'package:ministerio_pessoal/sync/crypto/recovery_crypto.dart';

class MemoryTransport implements EncryptedRecordTransport {
  EncryptedRemoteRecord? record;
  @override
  Future<EncryptedRemoteRecord?> fetch(String route) async => record;
  @override
  Future<EncryptedWriteResult> compareAndSwap({
    required String route,
    required int expectedRevision,
    required Map<String, dynamic> envelope,
  }) async => throw UnimplementedError();
}

void main() {
  test(
    'checkpoint e dados locais são atômicos, idempotentes e rejeitam replay',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final key = await RecoveryCrypto.keyFromPhrase(
        RecoveryCrypto.createPhrase(),
      );
      final transport = MemoryTransport();
      final sync = EncryptedRecordSync(
        owner: 'owner',
        key: key,
        transport: transport,
      );
      final checkpoint = EncryptedRecordCheckpoint(db: db, sync: sync);
      Future<EncryptedRemoteRecord> sealed(int revision, String value) async {
        final result = await EncryptedRecord.seal(
          key: key,
          owner: 'owner',
          entityType: 'people',
          entityId: 'p',
          revision: revision,
          data: {'id': 'p', 'name': value},
        );
        return EncryptedRemoteRecord(
          route: result['route'] as String,
          revision: revision,
          envelope: Map<String, dynamic>.from(result['envelope'] as Map),
        );
      }

      Future<void> apply(
        Map<String, dynamic> data,
        int revision, {
        bool fail = false,
      }) async {
        await db
            .into(db.appKvStore)
            .insertOnConflictUpdate(
              AppKvStoreCompanion.insert(
                key: 'applied',
                value: '${data['name']}:$revision',
              ),
            );
        if (fail) throw StateError('falha na aplicação');
      }

      Future<bool> pull({bool fail = false}) => checkpoint.pullAndApply(
        entityType: 'people',
        entityId: 'p',
        apply: (data, revision) => apply(data, revision, fail: fail),
      );
      Future<String?> applied() async => (await (db.select(
        db.appKvStore,
      )..where((t) => t.key.equals('applied'))).getSingleOrNull())?.value;

      final first = await sealed(1, 'primeiro');
      transport.record = first;
      await expectLater(pull(fail: true), throwsStateError);
      expect(await db.select(db.appKvStore).get(), isEmpty);
      expect(await pull(), isTrue);
      expect(await applied(), 'primeiro:1');
      expect(await pull(), isFalse);

      transport.record = await sealed(1, 'diferente');
      await expectLater(pull(), throwsStateError);
      transport.record = await sealed(2, 'segundo');
      await expectLater(pull(fail: true), throwsStateError);
      expect(await applied(), 'primeiro:1');
      transport.record = first;
      expect(await pull(), isFalse);
      transport.record = await sealed(2, 'segundo');
      expect(await pull(), isTrue);
      expect(await applied(), 'segundo:2');
      transport.record = first;
      await expectLater(pull(), throwsStateError);
      transport.record = null;
      await expectLater(pull(), throwsStateError);
      expect(await applied(), 'segundo:2');
    },
  );
}
