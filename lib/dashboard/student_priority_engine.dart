import 'dart:convert';
import 'dart:math';
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../publications/lff_book_catalog.dart';

/// Item de Prioridade e Progresso de Estudante
class StudentPriorityItem {
  final BibleStudyEntry study;
  final PersonEntry person;
  final double internalScore;
  final double progressPercentage;
  final double lessonsPerWeekVelocity;
  final String velocityLabel;
  final int completedGoalsCount;
  final int successfulSessionsCount;
  final int failedSessionsCount;
  final int manualOrderIndex;

  const StudentPriorityItem({
    required this.study,
    required this.person,
    required this.internalScore,
    required this.progressPercentage,
    required this.lessonsPerWeekVelocity,
    required this.velocityLabel,
    required this.completedGoalsCount,
    required this.successfulSessionsCount,
    required this.failedSessionsCount,
    this.manualOrderIndex = 0,
  });

  PersonEntry get primaryPerson => person;
  double get progressPercent => progressPercentage;
  String get frequency => study.frequency;
  int? get daysSinceLastSession => study.lastSessionAt != null ? DateTime.now().difference(study.lastSessionAt!).inDays : null;
  int get spiritualGoalsMetCount => completedGoalsCount;
  int get manualRank => manualOrderIndex + 1;

  String get priorityTier {
    if (internalScore >= 200.0) return 'Muito Alta';
    if (internalScore >= 120.0) return 'Alta';
    if (internalScore >= 60.0) return 'Média';
    return 'Atenção';
  }

  StudentPriorityItem copyWith({int? manualOrderIndex}) {
    return StudentPriorityItem(
      study: study,
      person: person,
      internalScore: internalScore,
      progressPercentage: progressPercentage,
      lessonsPerWeekVelocity: lessonsPerWeekVelocity,
      velocityLabel: velocityLabel,
      completedGoalsCount: completedGoalsCount,
      successfulSessionsCount: successfulSessionsCount,
      failedSessionsCount: failedSessionsCount,
      manualOrderIndex: manualOrderIndex ?? this.manualOrderIndex,
    );
  }
}

/// Motor Inteligente de Prioridade e Interesse Espiritual
class StudentPriorityEngine {
  static Future<void> _ensureTable(AppDatabase db) async {
    try {
      await db.customStatement('''
        CREATE TABLE IF NOT EXISTS student_manual_order (
          study_id TEXT PRIMARY KEY,
          manual_index INTEGER NOT NULL
        );
      ''');
    } catch (_) {}
  }

  /// Carrega as ordens manuais salvas no banco
  static Future<Map<String, int>> loadManualOrder(AppDatabase db) async {
    await _ensureTable(db);
    try {
      final rows = await db.customSelect('SELECT study_id, manual_index FROM student_manual_order').get();
      final map = <String, int>{};
      for (final r in rows) {
        final sId = r.read<String>('study_id');
        final idx = r.read<int>('manual_index');
        map[sId] = idx;
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  /// Salva todas as ordens manuais permanentemente no SQLite
  static Future<void> saveAllManualOrders(AppDatabase db, Map<String, int> manualOrderMap) async {
    await _ensureTable(db);
    try {
      for (final entry in manualOrderMap.entries) {
        await db.customInsert(
          'INSERT OR REPLACE INTO student_manual_order (study_id, manual_index) VALUES (?, ?)',
          variables: [Variable.withString(entry.key), Variable.withInt(entry.value)],
        );
      }
    } catch (_) {}
  }

  /// Aplica a reordenação manual disparada pela ReorderableListView (onReorder legado)
  static void applyManualReorder({
    required List<StudentPriorityItem> items,
    required int oldIndex,
    required int newIndex,
    required Map<String, int> manualOrderMap,
    AppDatabase? db,
  }) {
    if (newIndex > oldIndex) newIndex -= 1;
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);
    for (int i = 0; i < items.length; i++) {
      manualOrderMap[items[i].study.id] = i;
    }
    if (db != null) {
      saveAllManualOrders(db, manualOrderMap);
    }
  }

  /// Aplica a reordenação manual pelo callback moderno onReorderItem
  static void applyManualReorderItem({
    required List<StudentPriorityItem> items,
    required int oldIndex,
    required int newIndex,
    required Map<String, int> manualOrderMap,
    AppDatabase? db,
  }) {
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);
    for (int i = 0; i < items.length; i++) {
      manualOrderMap[items[i].study.id] = i;
    }
    if (db != null) {
      saveAllManualOrders(db, manualOrderMap);
    }
  }


  /// Calcula os itens ordenados do mais interessado para o menos interessado
  static List<StudentPriorityItem> calculatePriorities({
    List<BibleStudyEntry>? studies,
    List<BibleStudyEntry>? activeStudies,
    required List<StudyParticipantEntry> participants,
    required List<PersonEntry> people,
    required List<StudySessionEntry> sessions,
    List<AppointmentEntry>? appointments,
    Map<String, int>? manualOrder,
    Map<String, int>? manualOrderMap,
    DateTime? nowOverride,
  }) {
    final effectiveStudies = activeStudies ?? studies ?? [];
    final effectiveManualOrder = manualOrder ?? manualOrderMap ?? const {};
    final now = nowOverride ?? DateTime.now();
    final personMap = {for (var p in people) p.id: p};
    final activeList = effectiveStudies.where((s) => s.status == 'ativo' && s.deletedAt == null).toList();

    final List<StudentPriorityItem> items = [];

    for (final study in activeList) {
      // Participante principal do estudo
      final studyParts = participants.where((p) => p.studyId == study.id && p.deletedAt == null).toList();
      final primaryPart = studyParts.where((p) => p.isPrimary).firstOrNull ?? studyParts.firstOrNull;
      final person = primaryPart != null ? personMap[primaryPart.personId] : null;

      if (person == null || person.deletedAt != null) continue;

      // Sessões deste estudo
      final studySessions = sessions.where((s) => s.studyId == study.id && s.deletedAt == null).toList()
        ..sort((a, b) => b.dateTimeField.compareTo(a.dateTimeField));

      int successful = 0;
      int failed = 0;
      for (final s in studySessions) {
        final st = s.status.toLowerCase();
        if (st == 'realizada') {
          successful++;
        } else if (st == 'cancelada' || st == 'nao_realizada') {
          failed++;
        }
      }

      // 1. Pontuação de Frequência Base
      // Opção 2x por semana pontua significativamente mais
      double score = 0.0;
      final freq = study.frequency.toLowerCase();
      final isTwiceAWeek = freq.contains('2') || freq.contains('duas') || freq == 'duas_vezes_semana';
      if (isTwiceAWeek) {
        score += 80.0; // Pontuação premium para estudantes que estudam 2x/semana
      } else if (freq == 'semanal') {
        score += 40.0;
      } else {
        score += 20.0;
      }

      // 2. Pontuação por Sessões Realizadas vs Falhas (Canceladas)
      score += (successful * 25.0);
      score -= (failed * 18.0);

      // Taxa de assiduidade
      final totalSessions = successful + failed;
      if (totalSessions > 0) {
        final successRate = successful / totalSessions;
        score += (successRate * 50.0);
      }

      // 3. Velocidade de Consumo de Matéria (Lições e pontos por semana)
      final studyAgeDays = max(1, now.difference(study.startedAt).inDays);
      final studyAgeWeeks = max(0.5, studyAgeDays / 7.0);

      final currentLesson = study.currentLesson ?? 1;
      final currentPoint = study.currentParagraph ?? 1;

      // Velocidade estimada em lições por semana
      final double lessonsPerWeekVelocity = (currentLesson - 1 + (currentPoint / 6.0)) / studyAgeWeeks;

      // Quem consome matéria mais rápido pontua mais (mesmo que esteja no início do livro!)
      if (lessonsPerWeekVelocity >= 1.5) {
        score += 100.0; // Velocidade excepcional
      } else if (lessonsPerWeekVelocity >= 1.0) {
        score += 70.0; // Ritmo ideal de 1 lição/semana
      } else if (lessonsPerWeekVelocity >= 0.5) {
        score += 40.0; // Ritmo moderado
      } else {
        score += 15.0; // Ritmo lento
      }

      // 4. Cumprimento de Metas Espirituais
      int completedGoals = 0;
      if (person.contactRestrictions != null && person.contactRestrictions!.isNotEmpty) {
        try {
          final decoded = jsonDecode(person.contactRestrictions!);
          if (decoded is List) {
            for (final t in decoded) {
              if (t is Map && t['isCompleted'] == true) {
                completedGoals++;
              }
            }
          }
        } catch (_) {}
      }
      // Metas cumpridas aumentam a pontuação
      score += (completedGoals * 35.0);

      // 5. Recência do último contato
      if (study.lastSessionAt != null) {
        final daysSinceLast = now.difference(study.lastSessionAt!).inDays;
        if (daysSinceLast <= 7) {
          score += 25.0;
        } else if (daysSinceLast > 21) {
          score -= 30.0; // Perda de ritmo / esfriamento
        }
      }

      // Rótulo descritivo de velocidade para a UI
      String velocityLabel;
      if (isTwiceAWeek) {
        velocityLabel = '2x por semana • Avanço intenso';
      } else if (lessonsPerWeekVelocity >= 1.2) {
        velocityLabel = 'Avanço rápido • Assiduidade alta';
      } else if (lessonsPerWeekVelocity >= 0.8) {
        velocityLabel = 'Ritmo constante (~1 lição/sem)';
      } else if (failed > successful) {
        velocityLabel = 'Atenção: Vários cancelamentos';
      } else {
        velocityLabel = 'Ritmo gradual de estudo';
      }

      final progress = LffBookCatalog.calculateProgressPercentage(
        lesson: currentLesson,
        point: currentPoint,
      );

      final manualIndex = effectiveManualOrder[study.id] ?? 999999;

      items.add(StudentPriorityItem(
        study: study,
        person: person,
        internalScore: score,
        progressPercentage: progress,
        lessonsPerWeekVelocity: lessonsPerWeekVelocity,
        velocityLabel: velocityLabel,
        completedGoalsCount: completedGoals,
        successfulSessionsCount: successful,
        failedSessionsCount: failed,
        manualOrderIndex: manualIndex,
      ));
    }

    // Se houver ordens manuais definidas pelo usuário, prioriza-as; caso contrário, ordena pelo score interno decrescente
    final hasManualOrders = effectiveManualOrder.isNotEmpty;
    if (hasManualOrders) {
      items.sort((a, b) {
        final cmp = a.manualOrderIndex.compareTo(b.manualOrderIndex);
        if (cmp != 0) return cmp;
        return b.internalScore.compareTo(a.internalScore);
      });
    } else {
      items.sort((a, b) => b.internalScore.compareTo(a.internalScore));
    }

    for (int i = 0; i < items.length; i++) {
      items[i] = items[i].copyWith(manualOrderIndex: i);
    }

    return items;
  }
}
