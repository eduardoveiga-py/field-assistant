import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' as drift;
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/notifications/local_reminder_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late LocalReminderService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = LocalReminderService(db: db);
  });

  tearDown(() async {
    service.dispose();
    await db.close();
  });

  group('LocalReminderService (FA-FUNC-01: Notificações & Lembretes Locais)', () {
    test(
      'agenda, lista e cancela lembretes com persistência no app_kv_store',
      () async {
        final futureTime = DateTime.utc(2026, 11, 20, 15, 0);
        final reminder = ScheduledReminder(
          id: 'rem_1',
          title: 'Revisita com Carlos',
          description: 'Levar revista sobre família',
          scheduledFor: futureTime,
          type: ReminderType.revisit,
          leadTimeMinutes: 30,
        );

        await service.scheduleReminder(reminder);

        final list = await service.getAllReminders();
        expect(list.length, equals(1));
        expect(list.first.id, equals('rem_1'));
        expect(list.first.title, equals('Revisita com Carlos'));
        expect(list.first.type, equals(ReminderType.revisit));
        expect(list.first.isTriggered, isFalse);

        await service.cancelReminder('rem_1');
        final emptyList = await service.getAllReminders();
        expect(emptyList, isEmpty);
      },
    );

    test('checkAndTriggerDueReminders dispara lembretes no horário correto com lead time', () async {
      final scheduledTime = DateTime.utc(2026, 11, 20, 10, 0);
      final reminder = ScheduledReminder(
        id: 'rem_study',
        title: 'Estudo Bíblico com Marcos',
        description: 'Capítulo 4 do manual',
        scheduledFor: scheduledTime,
        type: ReminderType.bibleStudy,
        leadTimeMinutes: 15, // Disparo esperado às 09:45
      );

      await service.scheduleReminder(reminder);

      // 09:30 UTC: ainda não atingiu o lead time (15 min antes) => não dispara
      final notYet = await service.checkAndTriggerDueReminders(
        currentTime: DateTime.utc(2026, 11, 20, 9, 30),
      );
      expect(notYet, isEmpty);

      // 09:45 UTC: exatamente 15 min antes => dispara!
      final triggered = await service.checkAndTriggerDueReminders(
        currentTime: DateTime.utc(2026, 11, 20, 9, 45),
      );
      expect(triggered.length, equals(1));
      expect(triggered.first.id, equals('rem_study'));
      expect(triggered.first.isTriggered, isTrue);

      // Verificação subsequente não dispara novamente (idempotência)
      final again = await service.checkAndTriggerDueReminders(
        currentTime: DateTime.utc(2026, 11, 20, 9, 50),
      );
      expect(again, isEmpty);
    });

    test('syncRemindersFromAppointments cria lembretes automáticos para compromissos futuros', () async {
      final now = DateTime.now().toUtc();
      final apptTime = now.add(const Duration(hours: 3));

      await db
          .into(db.appointments)
          .insert(
            AppointmentsCompanion.insert(
              id: 'appt_auto_1',
              title: 'Visita Pastoral',
              startTime: apptTime,
              endTime: apptTime.add(const Duration(hours: 1)),
              reminderMinutesBefore: const drift.Value(20),
              status: const drift.Value('agendado'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      final count = await service.syncRemindersFromAppointments();
      expect(count, equals(1));

      final reminders = await service.getAllReminders();
      expect(reminders.length, equals(1));
      expect(reminders.first.id, equals('appt_appt_auto_1'));
      expect(reminders.first.title, equals('Visita Pastoral'));
      expect(reminders.first.leadTimeMinutes, equals(20));
      expect(reminders.first.type, equals(ReminderType.appointment));
    });
  });
}
