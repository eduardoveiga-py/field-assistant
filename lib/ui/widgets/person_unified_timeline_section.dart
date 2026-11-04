import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../core/date_utils.dart';
import '../../dashboard/counting_rules.dart';
import '../../database/app_database.dart';
import '../../voice_notes/voice_note_models.dart';
import '../../voice_notes/voice_notes_manager.dart';
import '../providers.dart';

/// Componente que agrega visitas, sessões, compromissos e áudios do contato em ordem cronológica reversa.
class PersonUnifiedTimelineSection extends ConsumerWidget {
  final PersonEntry person;
  final BibleStudyEntry? linkedStudy;
  final bool isStudiesEnabled;
  final bool isAgendaEnabled;

  const PersonUnifiedTimelineSection({
    super.key,
    required this.person,
    this.linkedStudy,
    required this.isStudiesEnabled,
    required this.isAgendaEnabled,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);
    final voiceNotesManager = ref.watch(voiceNotesManagerProvider);
    final appointments = isAgendaEnabled
        ? (ref.watch(appointmentsStreamProvider).value ?? [])
              .where((a) => a.personId == person.id && a.deletedAt == null)
              .toList()
        : <AppointmentEntry>[];

    return StreamBuilder<List<VisitEntry>>(
      stream: repo.watchVisitsForPerson(person.id),
      builder: (context, visitSnap) {
        final visits = visitSnap.data ?? [];

        return StreamBuilder<List<VoiceNoteItem>>(
          stream: voiceNotesManager.watchVoiceNotesForPerson(person.id),
          builder: (context, voiceSnap) {
            final voiceNotes = voiceSnap.data ?? [];

            final sessionsStream = (isStudiesEnabled && linkedStudy != null)
                ? repo.watchSessionsForStudy(linkedStudy!.id)
                : Stream.value(<StudySessionEntry>[]);

            return StreamBuilder<List<StudySessionEntry>>(
              stream: sessionsStream,
              builder: (context, sessionSnap) {
                final sessions = sessionSnap.data ?? [];

                // Agregar todos os eventos cronologicamente
                final items = <_UnifiedTimelineEvent>[];

                for (final v in visits) {
                  final isPhone =
                      v.contactType.toLowerCase().contains('telefon') ||
                      v.contactType.toLowerCase().contains('chamada') ||
                      v.contactType.toLowerCase().contains('ligação');
                  items.add(
                    _UnifiedTimelineEvent(
                      date: v.dateTimeField,
                      title:
                          v.topicsDiscussed ??
                          (isPhone
                              ? 'Contato Telefônico'
                              : 'Visita Presencial'),
                      subtitle: 'Resultado: ${v.result}',
                      notes: v.notes,
                      nextStep: v.nextStep,
                      tag: isPhone
                          ? 'Telefone / Chamada'
                          : (v.contactType == 'estudo' ? 'Estudo' : 'Visita'),
                      icon: isPhone
                          ? Icons.phone_in_talk
                          : Icons.chat_bubble_outline,
                      color: isPhone
                          ? const Color(0xFF0D9488)
                          : AppTheme.primaryBlue,
                      attendance: DashboardCalculator.parseVisitAttendance(v),
                    ),
                  );
                }

                for (final s in sessions) {
                  items.add(
                    _UnifiedTimelineEvent(
                      date: s.dateTimeField,
                      title:
                          'Sessão de Estudo Bíblico • Lição ${s.lessonCovered ?? 1}',
                      subtitle: s.paragraphsCovered != null
                          ? 'Parágrafos: ${s.paragraphsCovered} • Status: ${s.status}'
                          : 'Status: ${s.status}',
                      notes: s.sessionNotes,
                      nextStep: s.nextStep,
                      tag: 'Estudo Bíblico',
                      icon: Icons.school,
                      color: const Color(0xFF7C3AED),
                    ),
                  );
                }

                for (final a in appointments) {
                  items.add(
                    _UnifiedTimelineEvent(
                      date: a.startTime,
                      title: a.title,
                      subtitle: 'Compromisso agendado • Status: ${a.status}',
                      notes: a.locationNotes,
                      tag: 'Agenda',
                      icon: Icons.event,
                      color: const Color(0xFF2563EB),
                    ),
                  );
                }

                for (final vn in voiceNotes) {
                  items.add(
                    _UnifiedTimelineEvent(
                      date: vn.createdAt,
                      title:
                          'Nota de Áudio / Ditado (${vn.audioDurationSeconds}s)',
                      subtitle: 'Gravação de voz',
                      notes: vn.transcription,
                      tag: 'Nota de Voz',
                      icon: Icons.mic,
                      color: const Color(0xFF10B981),
                    ),
                  );
                }

                // Se não há sessões avulsas registradas, inclui os marcos históricos informados
                final study = linkedStudy;
                if (study != null) {
                  final hasStudyStart = items.any(
                    (i) => i.date == study.startedAt,
                  );
                  if (!hasStudyStart) {
                    items.add(
                      _UnifiedTimelineEvent(
                        date: study.startedAt,
                        title: 'Início do Estudo Bíblico: ${study.title}',
                        subtitle:
                            'Iniciado em ${AppDateUtils.formatDate(study.startedAt)} • Lição Atual: ${study.currentLesson ?? 1}',
                        tag: 'Marco Inicial',
                        icon: Icons.flag_outlined,
                        color: const Color(0xFF7C3AED),
                      ),
                    );
                  }
                  if (study.lastSessionAt != null) {
                    final hasLastSession = items.any(
                      (i) => i.date == study.lastSessionAt,
                    );
                    if (!hasLastSession) {
                      items.add(
                        _UnifiedTimelineEvent(
                          date: study.lastSessionAt!,
                          title:
                              'Última Sessão Informada • Lição ${study.currentLesson ?? 1}',
                          subtitle:
                              'Realizada em ${AppDateUtils.formatDate(study.lastSessionAt!)} (Histórico Prévio)',
                          tag: 'Estudo Bíblico',
                          icon: Icons.school_outlined,
                          color: const Color(0xFF7C3AED),
                        ),
                      );
                    }
                  }
                } else {
                  if (person.lastContactAt != null) {
                    final hasLastContact = items.any(
                      (i) => i.date == person.lastContactAt,
                    );
                    if (!hasLastContact) {
                      items.add(
                        _UnifiedTimelineEvent(
                          date: person.lastContactAt!,
                          title: 'Última Visita Informada',
                          subtitle:
                              'Realizada em ${AppDateUtils.formatDate(person.lastContactAt!)} (Histórico Prévio)',
                          tag: 'Visita',
                          icon: Icons.history,
                          color: AppTheme.accentTeal,
                        ),
                      );
                    }
                  }
                }

                items.sort((a, b) => b.date.compareTo(a.date));

                if (items.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Center(
                        child: Text(
                          'Nenhuma interação registrada ainda para ${person.name}.\nUtilize os botões acima para registrar conversas, notas ou compromissos.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppTheme.textMuted),
                        ),
                      ),
                    ),
                  );
                }

                return Column(
                  children: items.map((item) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: item.color.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Icon(
                                        item.icon,
                                        size: 16,
                                        color: item.color,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      AppDateUtils.formatDateTime(item.date),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: item.color,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    if (item.attendance != null &&
                                        item.attendance! > 0)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 6,
                                        ),
                                        child: Chip(
                                          avatar: const Icon(
                                            Icons.group,
                                            size: 14,
                                            color: AppTheme.primaryBlue,
                                          ),
                                          label: Text(
                                            '${item.attendance} ${item.attendance == 1 ? "ouvinte" : "ouvintes"}',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          padding: EdgeInsets.zero,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ),
                                    Chip(
                                      label: Text(
                                        item.tag,
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      padding: EdgeInsets.zero,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            if (item.subtitle != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                item.subtitle!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ],
                            if (item.notes != null &&
                                item.notes!.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                item.notes!,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                            if (item.nextStep != null &&
                                item.nextStep!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.arrow_forward,
                                      size: 14,
                                      color: AppTheme.primaryBlue,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Próximo passo: ${item.nextStep}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.primaryBlue,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _UnifiedTimelineEvent {
  final DateTime date;
  final String title;
  final String? subtitle;
  final String? notes;
  final String? nextStep;
  final String tag;
  final IconData icon;
  final Color color;
  final int? attendance;

  _UnifiedTimelineEvent({
    required this.date,
    required this.title,
    this.subtitle,
    this.notes,
    this.nextStep,
    required this.tag,
    required this.icon,
    required this.color,
    this.attendance,
  });
}
