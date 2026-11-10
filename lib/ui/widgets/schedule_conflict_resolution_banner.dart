import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../appointments/availability_engine.dart';
import '../../core/app_theme.dart';
import '../providers.dart';
import 'adaptive_ministry_sheet.dart';

/// Notifier para rastrear pares de conflitos dispensados pelo usuário nesta sessão
class DismissedConflictNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{};

  void dismiss(String key) {
    state = {...state, key};
  }

  void reset() {
    state = <String>{};
  }
}

final dismissedConflictsProvider =
    NotifierProvider<DismissedConflictNotifier, Set<String>>(
  DismissedConflictNotifier.new,
);

/// Banner visual de aviso e resolução de conflitos de agendamento pós-sincronização
class ScheduleConflictResolutionBanner extends ConsumerWidget {
  const ScheduleConflictResolutionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allConflicts = ref.watch(activeAppointmentConflictsProvider);
    final dismissed = ref.watch(dismissedConflictsProvider);

    final visibleConflicts = allConflicts
        .where((c) => !dismissed.contains(c.conflictKey))
        .toList();

    if (visibleConflicts.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final firstPair = visibleConflicts.first;
    final totalCount = visibleConflicts.length;

    final dateFmt = DateFormat('dd/MM', 'pt_BR').format(firstPair.collisionDate);
    final timeFmt = DateFormat('HH:mm').format(firstPair.appointmentA.startTime);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF451A03) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFF59E0B),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFD97706),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      totalCount == 1
                          ? 'Conflito de Horário Detectado'
                          : '$totalCount Conflitos de Horário',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$dateFmt às $timeFmt',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${firstPair.appointmentA.title} e ${firstPair.appointmentB.title} no mesmo horário.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFFF3F4F6) : const Color(0xFF78350F),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () => _openConflictResolutionModal(context, ref, visibleConflicts),
            child: const Text('Resolver', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            visualDensity: VisualDensity.compact,
            tooltip: 'Dispensar aviso',
            color: isDark ? Colors.white60 : Colors.black54,
            onPressed: () {
              for (final pair in visibleConflicts) {
                ref.read(dismissedConflictsProvider.notifier).dismiss(pair.conflictKey);
              }
            },
          ),
        ],
      ),
    );
  }

  static void _openConflictResolutionModal(
    BuildContext context,
    WidgetRef ref,
    List<AppointmentConflictPair> conflictPairs,
  ) {
    showAdaptiveMinistrySheet(
      context: context,
      title: 'Resolver Conflitos de Horário',
      titleLeading: const Icon(Icons.alt_route_rounded, color: Color(0xFFD97706)),
      builder: (ctx, scroll) {
        return _ConflictResolutionSheetContent(conflictPairs: conflictPairs);
      },
    );
  }
}

class _ConflictResolutionSheetContent extends ConsumerStatefulWidget {
  final List<AppointmentConflictPair> conflictPairs;

  const _ConflictResolutionSheetContent({required this.conflictPairs});

  @override
  ConsumerState<_ConflictResolutionSheetContent> createState() =>
      _ConflictResolutionSheetContentState();
}

class _ConflictResolutionSheetContentState
    extends ConsumerState<_ConflictResolutionSheetContent> {
  @override
  Widget build(BuildContext context) {
    final allAppointments = ref.watch(appointmentsStreamProvider).value ?? [];
    final activeConflicts = AvailabilityEngine.findActiveConflicts(allAppointments);
    final repo = ref.read(repositoryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (activeConflicts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline, size: 56, color: Colors.green),
            const SizedBox(height: 16),
            const Text(
              'Todos os conflitos foram resolvidos!',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Concluir'),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: activeConflicts.length,
      separatorBuilder: (_, _) => const Divider(height: 24),
      itemBuilder: (context, index) {
        final pair = activeConflicts[index];
        final a = pair.appointmentA;
        final b = pair.appointmentB;

        final timeFmtA = '${DateFormat('HH:mm').format(a.startTime)} - ${DateFormat('HH:mm').format(a.endTime)}';
        final timeFmtB = '${DateFormat('HH:mm').format(b.startTime)} - ${DateFormat('HH:mm').format(b.endTime)}';
        final dateStr = DateFormat('EEEE, dd/MM/yyyy', 'pt_BR').format(pair.collisionDate);

        // Calcula horários alternativos livres no mesmo dia para o compromisso B
        final durationB = b.endTime.difference(b.startTime).inMinutes;
        final availB = AvailabilityEngine.checkAvailability(
          startTime: b.startTime,
          durationMinutes: durationB > 0 ? durationB : 45,
          existingAppointments: allAppointments,
          excludeAppointmentId: b.id,
        );
        final alternativeSlots = availB.suggestedAlternativeSlots;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.event_busy_rounded, color: Color(0xFFD97706), size: 20),
                const SizedBox(width: 8),
                Text(
                  dateStr,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Card Compromisso A
            _buildAppointmentTile(
              context: context,
              label: 'Compromisso 1',
              title: a.title,
              time: timeFmtA,
              type: a.studyId != null ? 'Estudo Bíblico' : 'Compromisso',
              isDark: isDark,
              color: AppTheme.primaryBlue,
            ),
            const SizedBox(height: 8),

            // Card Compromisso B
            _buildAppointmentTile(
              context: context,
              label: 'Compromisso 2 (Sobreposto)',
              title: b.title,
              time: timeFmtB,
              type: b.studyId != null ? 'Estudo Bíblico' : 'Compromisso',
              isDark: isDark,
              color: const Color(0xFFD97706),
            ),
            const SizedBox(height: 12),

            // Ações de Resolução
            if (alternativeSlots.isNotEmpty) ...[
              Text(
                'Mover "${b.title}" para horário vago (Plano B):',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: alternativeSlots.map((slot) {
                  final slotStr = DateFormat('HH:mm').format(slot);
                  return ActionChip(
                    avatar: const Icon(Icons.update_rounded, size: 16),
                    label: Text('Mover p/ $slotStr'),
                    onPressed: () async {
                      final newDuration = b.endTime.difference(b.startTime);
                      final updated = b.copyWith(
                        startTime: slot,
                        endTime: slot.add(newDuration),
                      );
                      await repo.updateAppointment(updated);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Reagendado para as $slotStr com sucesso!')),
                        );
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
            ],

            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.people_outline, size: 16),
                label: const Text('Manter Ambos (Visita Conjunta)'),
                onPressed: () {
                  ref.read(dismissedConflictsProvider.notifier).dismiss(pair.conflictKey);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Conflito dispensado para esta sessão.')),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAppointmentTile({
    required BuildContext context,
    required String label,
    required String title,
    required String time,
    required String type,
    required bool isDark,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: color,
            child: const Icon(Icons.person, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$label • $type',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              time,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
