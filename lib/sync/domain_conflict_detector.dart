import 'dart:convert';

import 'package:drift/drift.dart' as drift;

import '../database/app_database.dart';

/// Representa um conflito de domínio na Agenda detectado após pull:
/// dois compromissos ativos com UUIDs distintos sobrepostos no tempo.
class AppointmentDomainConflict {
  final String incomingAppointmentId;
  final String incomingTitle;
  final String conflictingAppointmentId;
  final String conflictingTitle;
  final DateTime overlapStart;
  final DateTime overlapEnd;
  final DateTime detectedAt;

  const AppointmentDomainConflict({
    required this.incomingAppointmentId,
    required this.incomingTitle,
    required this.conflictingAppointmentId,
    required this.conflictingTitle,
    required this.overlapStart,
    required this.overlapEnd,
    required this.detectedAt,
  });

  Map<String, dynamic> toJson() => {
    'incomingAppointmentId': incomingAppointmentId,
    'incomingTitle': incomingTitle,
    'conflictingAppointmentId': conflictingAppointmentId,
    'conflictingTitle': conflictingTitle,
    'overlapStart': overlapStart.toUtc().toIso8601String(),
    'overlapEnd': overlapEnd.toUtc().toIso8601String(),
    'detectedAt': detectedAt.toUtc().toIso8601String(),
  };

  factory AppointmentDomainConflict.fromJson(Map<String, dynamic> json) {
    return AppointmentDomainConflict(
      incomingAppointmentId: json['incomingAppointmentId'] as String,
      incomingTitle: json['incomingTitle'] as String? ?? '',
      conflictingAppointmentId: json['conflictingAppointmentId'] as String,
      conflictingTitle: json['conflictingTitle'] as String? ?? '',
      overlapStart: DateTime.parse(json['overlapStart'] as String).toUtc(),
      overlapEnd: DateTime.parse(json['overlapEnd'] as String).toUtc(),
      detectedAt: DateTime.parse(json['detectedAt'] as String).toUtc(),
    );
  }
}

/// Detector de conflitos de domínio na Agenda após sincronização (FA-SYNC-02).
/// Garante que dois compromissos ativos com UUIDs distintos e intervalos
/// sobrepostos jamais se sobrescrevam silenciosamente: ambos são preservados,
/// o registro sincronizado é marcado com `status = 'conflito'` e o conflito é
/// auditavelmente registrado em `app_kv_store`.
class AppointmentDomainConflictDetector {
  AppointmentDomainConflictDetector._();

  static const String kvKeyPrefix = 'domain_conflict_appointment_';

  static const Set<String> inactiveStatuses = {
    'cancelado',
    'nao_realizado',
    'reagendado',
  };

  /// Retorna `true` quando os intervalos `[aStart, aEnd)` e `[bStart, bEnd)` se
  /// sobrepõem estritamente. Intervalos apenas adjacentes (`aEnd == bStart`) não conflitam.
  static bool intervalsOverlap(
    DateTime aStart,
    DateTime aEnd,
    DateTime bStart,
    DateTime bEnd,
  ) {
    final aS = aStart.toUtc();
    final aE = aEnd.toUtc();
    final bS = bStart.toUtc();
    final bE = bEnd.toUtc();
    return aS.isBefore(bE) && bS.isBefore(aE);
  }

  /// Verifica se o compromisso recém-aplicado [appointmentId] sobrepõe algum outro
  /// compromisso local ativo com UUID distinto. Se houver sobreposição, sinaliza
  /// `status = 'conflito'` no compromisso recebido sem apagar nem sobrescrever o
  /// compromisso local preexistente, e persiste o detalhe do conflito em `app_kv_store`.
  static Future<List<AppointmentDomainConflict>> detectAndRecordOverlaps(
    AppDatabase db, {
    required String appointmentId,
    DateTime? now,
  }) async {
    final incoming = await (db.select(
      db.appointments,
    )..where((t) => t.id.equals(appointmentId))).getSingleOrNull();
    if (incoming == null || incoming.deletedAt != null) {
      return const [];
    }
    if (inactiveStatuses.contains(incoming.status.trim().toLowerCase())) {
      return const [];
    }

    final others =
        await (db.select(db.appointments)..where(
              (t) => t.deletedAt.isNull() & t.id.isNotValue(appointmentId),
            ))
            .get();

    final detectedAt = (now ?? DateTime.now()).toUtc();
    final conflicts = <AppointmentDomainConflict>[];

    for (final other in others) {
      if (inactiveStatuses.contains(other.status.trim().toLowerCase())) {
        continue;
      }
      if (intervalsOverlap(
        incoming.startTime,
        incoming.endTime,
        other.startTime,
        other.endTime,
      )) {
        final overlapStart =
            incoming.startTime.toUtc().isAfter(other.startTime.toUtc())
            ? incoming.startTime.toUtc()
            : other.startTime.toUtc();
        final overlapEnd =
            incoming.endTime.toUtc().isBefore(other.endTime.toUtc())
            ? incoming.endTime.toUtc()
            : other.endTime.toUtc();

        conflicts.add(
          AppointmentDomainConflict(
            incomingAppointmentId: incoming.id,
            incomingTitle: incoming.title,
            conflictingAppointmentId: other.id,
            conflictingTitle: other.title,
            overlapStart: overlapStart,
            overlapEnd: overlapEnd,
            detectedAt: detectedAt,
          ),
        );
      }
    }

    if (conflicts.isEmpty) {
      return const [];
    }

    await (db.update(db.appointments)..where((t) => t.id.equals(appointmentId)))
        .write(const AppointmentsCompanion(status: drift.Value('conflito')));

    await db
        .into(db.appKvStore)
        .insertOnConflictUpdate(
          AppKvStoreCompanion.insert(
            key: '$kvKeyPrefix$appointmentId',
            value: jsonEncode({
              'appointmentId': appointmentId,
              'detectedAt': detectedAt.toIso8601String(),
              'conflicts': conflicts.map((c) => c.toJson()).toList(),
            }),
            updatedAt: drift.Value(detectedAt),
          ),
        );

    return conflicts;
  }

  /// Lista todos os conflitos de domínio de agenda ativos registrados localmente.
  static Future<List<AppointmentDomainConflict>> getActiveConflicts(
    AppDatabase db,
  ) async {
    final rows = await (db.select(
      db.appKvStore,
    )..where((t) => t.key.like('$kvKeyPrefix%'))).get();

    final result = <AppointmentDomainConflict>[];
    for (final row in rows) {
      try {
        final decoded = jsonDecode(row.value) as Map<String, dynamic>;
        final list = (decoded['conflicts'] as List<dynamic>? ?? const []);
        for (final item in list) {
          if (item is Map) {
            result.add(
              AppointmentDomainConflict.fromJson(
                Map<String, dynamic>.from(item),
              ),
            );
          }
        }
      } catch (_) {}
    }
    return result;
  }

  /// Remove o registro de conflito de domínio após resolução consciente pelo usuário.
  static Future<void> clearConflict(
    AppDatabase db,
    String appointmentId,
  ) async {
    await (db.delete(
      db.appKvStore,
    )..where((t) => t.key.equals('$kvKeyPrefix$appointmentId'))).go();
  }
}
