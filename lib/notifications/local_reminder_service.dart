import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' as drift;

import '../core/app_logger.dart';
import '../database/app_database.dart';

/// Tipo de lembrete local do ministério
enum ReminderType {
  appointment('Compromisso da Agenda'),
  bibleStudy('Estudo Bíblico'),
  revisit('Revisita Programada'),
  task('Tarefa Ministerial');

  final String label;
  const ReminderType(this.label);
}

/// Representa um lembrete local programado no dispositivo
class ScheduledReminder {
  final String id;
  final String title;
  final String description;
  final DateTime scheduledFor;
  final ReminderType type;
  final String? relatedEntityId;
  final int leadTimeMinutes;
  final bool isTriggered;

  const ScheduledReminder({
    required this.id,
    required this.title,
    required this.description,
    required this.scheduledFor,
    required this.type,
    this.relatedEntityId,
    this.leadTimeMinutes = 15,
    this.isTriggered = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'scheduledFor': scheduledFor.toUtc().toIso8601String(),
    'type': type.name,
    'relatedEntityId': relatedEntityId,
    'leadTimeMinutes': leadTimeMinutes,
    'isTriggered': isTriggered,
  };

  factory ScheduledReminder.fromJson(Map<String, dynamic> json) {
    return ScheduledReminder(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      scheduledFor: DateTime.parse(json['scheduledFor'] as String).toUtc(),
      type: ReminderType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => ReminderType.appointment,
      ),
      relatedEntityId: json['relatedEntityId'] as String?,
      leadTimeMinutes: (json['leadTimeMinutes'] as num?)?.toInt() ?? 15,
      isTriggered: json['isTriggered'] as bool? ?? false,
    );
  }
}

/// Serviço de lembretes e notificações locais nativas do Field Assistant (FA-FUNC-01).
/// Totalmente offline-first, sem dependência de serviços externos e integrado ao Drift.
class LocalReminderService {
  final AppDatabase db;
  static const String kvPrefix = 'reminder_item_';
  static const String settingsKvKey = 'reminder_settings_config';

  final StreamController<ScheduledReminder> _reminderTriggeredController =
      StreamController<ScheduledReminder>.broadcast();

  Stream<ScheduledReminder> get onReminderTriggered =>
      _reminderTriggeredController.stream;

  LocalReminderService({required this.db});

  /// Programa um novo lembrete ministerial local no SQLite
  Future<void> scheduleReminder(ScheduledReminder reminder) async {
    final now = DateTime.now().toUtc();
    await db
        .into(db.appKvStore)
        .insertOnConflictUpdate(
          AppKvStoreCompanion.insert(
            key: '$kvPrefix${reminder.id}',
            value: jsonEncode(reminder.toJson()),
            updatedAt: drift.Value(now),
          ),
        );
    AppLogger.info(
      'Lembrete local programado: "${reminder.title}" para ${reminder.scheduledFor}',
    );
  }

  /// Retorna todos os lembretes cadastrados
  Future<List<ScheduledReminder>> getAllReminders() async {
    final rows = await (db.select(
      db.appKvStore,
    )..where((t) => t.key.like('$kvPrefix%'))).get();
    final result = <ScheduledReminder>[];
    for (final row in rows) {
      try {
        final decoded = jsonDecode(row.value) as Map<String, dynamic>;
        result.add(ScheduledReminder.fromJson(decoded));
      } catch (e) {
        AppLogger.warning('Falha ao decodificar lembrete ${row.key}: $e');
      }
    }
    result.sort((a, b) => a.scheduledFor.compareTo(b.scheduledFor));
    return result;
  }

  /// Verifica e dispara lembretes cujo horário de disparo (scheduledFor - leadTimeMinutes) já foi atingido
  Future<List<ScheduledReminder>> checkAndTriggerDueReminders({
    DateTime? currentTime,
  }) async {
    final now = (currentTime ?? DateTime.now()).toUtc();
    final all = await getAllReminders();
    final triggeredList = <ScheduledReminder>[];

    for (final reminder in all) {
      if (reminder.isTriggered) continue;

      final triggerTime = reminder.scheduledFor.subtract(
        Duration(minutes: reminder.leadTimeMinutes),
      );

      if (now.isAfter(triggerTime) || now.isAtSameMomentAs(triggerTime)) {
        // Marca como disparado
        final updated = ScheduledReminder(
          id: reminder.id,
          title: reminder.title,
          description: reminder.description,
          scheduledFor: reminder.scheduledFor,
          type: reminder.type,
          relatedEntityId: reminder.relatedEntityId,
          leadTimeMinutes: reminder.leadTimeMinutes,
          isTriggered: true,
        );

        await db
            .into(db.appKvStore)
            .insertOnConflictUpdate(
              AppKvStoreCompanion.insert(
                key: '$kvPrefix${reminder.id}',
                value: jsonEncode(updated.toJson()),
                updatedAt: drift.Value(now),
              ),
            );

        triggeredList.add(updated);
        _reminderTriggeredController.add(updated);
        AppLogger.info('Lembrete disparado: "${reminder.title}"');
      }
    }

    return triggeredList;
  }

  /// Cancela e remove um lembrete programado
  Future<void> cancelReminder(String reminderId) async {
    await (db.delete(
      db.appKvStore,
    )..where((t) => t.key.equals('$kvPrefix$reminderId'))).go();
    AppLogger.info('Lembrete local cancelado: $reminderId');
  }

  /// Sincroniza lembretes a partir de compromissos futuros da Agenda
  Future<int> syncRemindersFromAppointments() async {
    final now = DateTime.now().toUtc();
    final appointments =
        await (db.select(db.appointments)..where(
              (t) => t.deletedAt.isNull() & t.startTime.isBiggerThanValue(now),
            ))
            .get();

    int scheduledCount = 0;
    for (final appt in appointments) {
      if (appt.status == 'cancelado' || appt.status == 'nao_realizado') {
        continue;
      }
      final leadMinutes = appt.reminderMinutesBefore ?? 15;
      final reminderId = 'appt_${appt.id}';

      final reminder = ScheduledReminder(
        id: reminderId,
        title: appt.title,
        description: appt.locationNotes ?? 'Compromisso agendado no ministério',
        scheduledFor: appt.startTime.toUtc(),
        type: ReminderType.appointment,
        relatedEntityId: appt.id,
        leadTimeMinutes: leadMinutes,
      );

      await scheduleReminder(reminder);
      scheduledCount++;
    }

    return scheduledCount;
  }

  void dispose() {
    _reminderTriggeredController.close();
  }
}
