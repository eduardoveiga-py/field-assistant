import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/date_utils.dart';
import '../../database/app_database.dart';

/// Card da Linha do Tempo Espiritual do Estudante com registro e exibição de datas exatas de cada marco.
class SpiritualTimelineCard extends StatelessWidget {
  final PersonEntry person;
  final BibleStudyEntry study;
  final List<StudySessionEntry> sessions;
  final bool isDark;

  const SpiritualTimelineCard({
    super.key,
    required this.person,
    required this.study,
    this.sessions = const [],
    required this.isDark,
  });

  DateTime? _getMilestoneDate(int targetLesson) {
    final matches = sessions
        .where((s) => s.status == 'realizada' && (s.lessonCovered ?? 0) >= targetLesson)
        .toList()
      ..sort((a, b) => a.dateTimeField.compareTo(b.dateTimeField));
    if (matches.isNotEmpty) return matches.first.dateTimeField;
    if ((study.currentLesson ?? 1) >= targetLesson) {
      return study.lastSessionAt ?? study.startedAt;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> completedGoals = [];
    if (person.contactRestrictions != null &&
        person.contactRestrictions!.isNotEmpty) {
      try {
        final decoded = jsonDecode(person.contactRestrictions!);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map &&
                item['isCompleted'] == true &&
                item['title'] != null) {
              completedGoals.add(Map<String, dynamic>.from(item));
            }
          }
        }
      } catch (_) {}
    }

    final currentLesson = study.currentLesson ?? 1;

    final dateLesson3 = _getMilestoneDate(3);
    final dateLesson4 = _getMilestoneDate(4);
    final dateLesson12 = _getMilestoneDate(12);
    final dateLesson33 = _getMilestoneDate(33);
    final dateLesson47 = _getMilestoneDate(47);
    final dateLesson60 = _getMilestoneDate(60);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.timeline,
                    color: Color(0xFFD97706),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Linha do Tempo Espiritual do Estudante',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 14),

            TimelineStep(
              icon: Icons.person_add_outlined,
              iconColor: AppTheme.primaryBlue,
              title: 'Primeiro Contato Registrado',
              date: AppDateUtils.formatDate(person.createdAt),
              subtitle: 'Início das conversas no ministério de campo',
              isCompleted: true,
            ),

            TimelineStep(
              icon: Icons.menu_book,
              iconColor: currentLesson >= 1 ? const Color(0xFF0284C7) : Colors.grey,
              title: 'Brochura Inicial (Lições 01 a 03)',
              date: currentLesson >= 3
                  ? (dateLesson3 != null
                      ? 'Concluída em ${AppDateUtils.formatDate(dateLesson3)}'
                      : 'Concluída')
                  : (currentLesson >= 1
                      ? 'Em andamento (Lição $currentLesson)'
                      : 'Início'),
              subtitle:
                  'Brochura "Seja Feliz para Sempre!": 3 lições introdutórias da Bíblia',
              isCompleted: currentLesson >= 3,
            ),

            TimelineStep(
              icon: Icons.handshake_outlined,
              iconColor: currentLesson >= 4
                  ? AppTheme.successGreen
                  : (currentLesson == 3 ? AppTheme.alertAmber : Colors.grey),
              title: 'Aceitou Continuar com o Livro Completo',
              date: currentLesson >= 4
                  ? (dateLesson4 != null
                      ? 'Recebeu o livro em ${AppDateUtils.formatDate(dateLesson4)}'
                      : 'Recebeu o livro (Lição 4+)')
                  : (currentLesson == 3 ? 'Consideração da Lição 3' : 'Pendente'),
              subtitle: currentLesson >= 4
                  ? 'Estudante aceitou o curso completo e recebeu o livro "Seja Feliz para Sempre!"'
                  : 'No final da lição 3: Consideração sobre continuar no livro a partir da Lição 4',
              isCompleted: currentLesson >= 4,
            ),

            TimelineStep(
              icon: Icons.auto_stories,
              iconColor: const Color(0xFF7C3AED),
              title: 'Curso Completo no Livro',
              date: currentLesson >= 4 ? 'Em andamento' : 'Aguardando Lição 4',
              subtitle: 'Publicação: Livro "Seja Feliz para Sempre!" (60 lições)',
              isCompleted: currentLesson >= 4,
            ),

            TimelineStep(
              icon: Icons.military_tech_outlined,
              iconColor: currentLesson >= 12 ? AppTheme.successGreen : Colors.grey,
              title: 'Marco 1: Conclusão da Seção 1 (Lições 01 a 12)',
              date: currentLesson >= 12
                  ? (dateLesson12 != null
                      ? 'Concluída em ${AppDateUtils.formatDate(dateLesson12)}'
                      : 'Concluída')
                  : 'Em andamento',
              subtitle: 'Fundamentos da Bíblia e aproximação de Deus',
              isCompleted: currentLesson >= 12,
            ),

            TimelineStep(
              icon: Icons.verified_outlined,
              iconColor: currentLesson >= 33 ? AppTheme.successGreen : Colors.grey,
              title: 'Marco 2: Conclusão da Seção 2 (Lições 13 a 33)',
              date: currentLesson >= 33
                  ? (dateLesson33 != null
                      ? 'Concluída em ${AppDateUtils.formatDate(dateLesson33)}'
                      : 'Concluída')
                  : (currentLesson >= 12 ? 'Em andamento' : 'Pendente'),
              subtitle: 'O Reino de Deus e a vida de Jesus Cristo',
              isCompleted: currentLesson >= 33,
            ),

            TimelineStep(
              icon: Icons.shield_outlined,
              iconColor: currentLesson >= 47 ? AppTheme.successGreen : Colors.grey,
              title: 'Marco 3: Conclusão da Seção 3 (Lições 34 a 47)',
              date: currentLesson >= 47
                  ? (dateLesson47 != null
                      ? 'Concluída em ${AppDateUtils.formatDate(dateLesson47)}'
                      : 'Concluída')
                  : (currentLesson >= 33 ? 'Em andamento' : 'Pendente'),
              subtitle:
                  'Aplicação das leis divinas, conduta moral e dedicação a Deus',
              isCompleted: currentLesson >= 47,
            ),

            TimelineStep(
              icon: Icons.flag_outlined,
              iconColor: currentLesson >= 60 ? AppTheme.successGreen : Colors.grey,
              title: 'Marco 4: Conclusão da Seção 4 (Lições 48 a 60)',
              date: currentLesson >= 60
                  ? (dateLesson60 != null
                      ? 'Concluída em ${AppDateUtils.formatDate(dateLesson60)}'
                      : 'Concluída')
                  : (currentLesson >= 47 ? 'Em andamento' : 'Pendente'),
              subtitle:
                  'Amizades, congregação, perseverança e amizade eterna com Jeová',
              isCompleted: currentLesson >= 60,
            ),

            if (completedGoals.isNotEmpty)
              for (final goal in completedGoals)
                TimelineStep(
                  icon: Icons.check_circle,
                  iconColor: AppTheme.successGreen,
                  title: 'Alvo Espiritual Cumprido',
                  date: () {
                    final dateRaw = goal['completedAt'] ?? goal['achievedAt'];
                    if (dateRaw != null) {
                      final parsed = DateTime.tryParse(dateRaw.toString());
                      if (parsed != null) {
                        return AppDateUtils.formatDate(parsed);
                      }
                    }
                    return 'Alcançado';
                  }(),
                  subtitle: (goal['title'] ?? '').toString(),
                  isCompleted: true,
                ),

            TimelineStep(
              icon: Icons.workspace_premium,
              iconColor: currentLesson >= 60 ? AppTheme.successGreen : Colors.grey,
              title: 'Alvo Final: Conclusão do Livro "Seja Feliz Para Sempre!"',
              date: currentLesson >= 60 ? '🎉 Livro Concluído!' : 'Alvo Final',
              subtitle:
                  'Preparo espiritual completo para continuar crescendo na fé',
              isCompleted: currentLesson >= 60,
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }
}

/// Componente visual do nó da linha do tempo.
class TimelineStep extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String date;
  final String subtitle;
  final bool isCompleted;
  final bool isLast;

  const TimelineStep({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.date,
    required this.subtitle,
    this.isCompleted = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? iconColor.withValues(alpha: 0.15)
                      : Colors.grey.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isCompleted ? iconColor : Colors.grey.shade400,
                    width: 2,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: isCompleted ? iconColor : Colors.grey.shade500,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isCompleted
                        ? iconColor.withValues(alpha: 0.4)
                        : Colors.grey.shade300,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isCompleted ? null : AppTheme.textMuted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        date,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isCompleted ? iconColor : AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mini-card de métricas com ícone e rótulo.
class MetricSmallCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String? subtitle;

  const MetricSmallCard({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: color.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
