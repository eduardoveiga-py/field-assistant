import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../appointments/schedule_release_coordinator.dart';
import '../../core/app_theme.dart';
import '../../core/date_utils.dart';
import '../../database/app_database.dart';
import '../providers.dart';

/// Modal de confirmação abrangente para Exclusão de Pessoa (Lixeira ou Definitiva)
class PersonDeletionDialog extends ConsumerStatefulWidget {
  final PersonEntry person;
  final bool isAlreadyInTrash;

  const PersonDeletionDialog({
    super.key,
    required this.person,
    this.isAlreadyInTrash = false,
  });

  /// Método utilitário para exibir o diálogo
  static Future<bool?> show(
    BuildContext context, {
    required PersonEntry person,
    bool isAlreadyInTrash = false,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PersonDeletionDialog(
        person: person,
        isAlreadyInTrash: isAlreadyInTrash,
      ),
    );
  }

  @override
  ConsumerState<PersonDeletionDialog> createState() =>
      _PersonDeletionDialogState();
}

class _PersonDeletionDialogState extends ConsumerState<PersonDeletionDialog> {
  late Future<PersonRelationshipsSummary> _summaryFuture;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    final coordinator = ref.read(scheduleReleaseCoordinatorProvider);
    _summaryFuture = coordinator.getPersonRelationshipsSummary(
      widget.person.id,
    );
  }

  Future<void> _handleSoftDelete(
    BuildContext context,
    PersonRelationshipsSummary summary,
  ) async {
    setState(() => _isProcessing = true);
    try {
      final coordinator = ref.read(scheduleReleaseCoordinatorProvider);
      final repo = ref.read(repositoryProvider);

      // 1. Libera compromissos futuros vinculados
      if (summary.futureAppointments.isNotEmpty) {
        await coordinator.releaseAppointments(
          appointments: summary.futureAppointments,
          reason: 'Pessoa enviada para a lixeira: ${widget.person.name}',
        );
      }

      // 2. Soft-delete da pessoa
      await repo.deletePerson(widget.person.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '"${widget.person.name}" movido para a Lixeira. '
              '${summary.futureAppointments.isNotEmpty ? "${summary.futureAppointments.length} horário(s) liberado(s) na agenda." : ""}',
            ),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.alertRed,
            content: Text('Falha ao mover para lixeira: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handlePermanentDelete(
    BuildContext context,
    PersonRelationshipsSummary summary,
  ) async {
    setState(() => _isProcessing = true);
    try {
      final coordinator = ref.read(scheduleReleaseCoordinatorProvider);
      final result = await coordinator
          .permanentlyDeletePersonWithScheduleRelease(
            personId: widget.person.id,
          );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.alertRed,
            content: Text('Falha na exclusão definitiva: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppTheme.alertRed,
            size: 28,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.isAlreadyInTrash
                  ? 'Exclusão Definitiva'
                  : 'Excluir Contato',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: FutureBuilder<PersonRelationshipsSummary>(
          future: _summaryFuture,
          builder: (context, snapshot) {
            if (_isProcessing) {
              return const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Processando exclusão e liberando horários...'),
                ],
              );
            }

            if (!snapshot.hasData) {
              return const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Analisando registros vinculados...'),
                ],
              );
            }

            final s = snapshot.data!;
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 14,
                      ),
                      children: [
                        const TextSpan(text: 'Você está prestes a excluir '),
                        TextSpan(
                          text: s.personName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const TextSpan(
                          text: '. Veja abaixo o impacto exato sobre os dados vinculados:',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 1. Compromissos futuros e liberação da agenda
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: s.hasFutureAppointments
                          ? AppTheme.primaryBlue.withValues(alpha: 0.08)
                          : (isDark
                                ? const Color(0xFF1E293B)
                                : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: s.hasFutureAppointments
                            ? AppTheme.primaryBlue.withValues(alpha: 0.4)
                            : Colors.transparent,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.event_available,
                              size: 18,
                              color: s.hasFutureAppointments
                                  ? AppTheme.primaryBlue
                                  : AppTheme.textMuted,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Agenda: ${s.futureAppointments.length} compromisso(s) futuro(s)',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (s.hasFutureAppointments) ...[
                          const Text(
                            'Os seguintes horários serão cancelados e liberados na sua agenda ativa:',
                            style: TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 6),
                          ...s.futureAppointments.map(
                            (a) => Padding(
                              padding: const EdgeInsets.only(
                                left: 8,
                                bottom: 4,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '• ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      '${a.title} — ${AppDateUtils.formatDateTime(a.startTime)} às ${AppDateUtils.formatTime(a.endTime)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Os lembretes locais programados para esses compromissos serão removidos.',
                            style: TextStyle(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ] else
                          const Text(
                            'Nenhum compromisso futuro agendado. A agenda não sofrerá alterações.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 2. Histórico e Relatórios
                  _buildDetailRow(
                    icon: Icons.history,
                    title: 'Histórico de Atendimentos',
                    subtitle:
                        '${s.visitsCount} visita(s) e ${s.pastAppointmentsCount} compromisso(s) passado(s).',
                  ),

                  // 3. Estudos Bíblicos
                  if (s.hasExclusiveStudies || s.hasSharedStudies) ...[
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      icon: Icons.menu_book,
                      title: 'Estudos Bíblicos',
                      subtitle: [
                        if (s.hasExclusiveStudies)
                          '${s.exclusiveStudies.length} estudo(s) exclusivo(s) que será(ão) encerrado(s)/removido(s).',
                        if (s.hasSharedStudies) ...[
                          '${s.sharedStudies.length} estudo(s) com outros participantes: o estudo e os compromissos dos outros participantes SERÃO PRESERVADOS.',
                          ...s.sharedStudies.map((st) {
                            final others =
                                s.sharedStudyOtherParticipants[st.id] ?? [];
                            return '• "${st.title}" (continua com: ${others.join(", ")})';
                          }),
                        ],
                      ].join('\n'),
                    ),
                  ],

                  // 4. Contato telefônico avulso de origem (se houver)
                  if (s.hasLinkedPhoneContact) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.accentTeal.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.accentTeal.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.contact_phone,
                            size: 18,
                            color: AppTheme.accentTeal,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                                children: [
                                  const TextSpan(
                                    text: 'Contato telefônico avulso: ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextSpan(
                                    text:
                                        'Este registro foi gerado a partir de "${s.linkedPhoneContactName}". Trata-se de um registro distinto; o contato telefônico NÃO será apagado e permanecerá na lista de Contatos Telefônicos.',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // 5. Outros anexos
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    icon: Icons.folder_open,
                    title: 'Outros Registros Vinculados',
                    subtitle:
                        '${s.photosCount} foto(s), ${s.publicationsCount} publicação(ões), ${s.voiceNotesCount} nota(s) de áudio, ${s.familyTiesCount} vínculo(s) familiar(es). Tarefas e notas da Base de Conhecimento serão desvinculadas sem perda do conteúdo.',
                  ),

                  const SizedBox(height: 14),
                  // Aviso de irreversibilidade
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.alertRed.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.alertRed.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: AppTheme.alertRed,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'A exclusão definitiva é irreversível no banco de dados deste dispositivo. Cópias de segurança prévias, arquivos externos exportados e calendários em outros aparelhos exigem tratamento próprio.',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.alertRed,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        if (!widget.isAlreadyInTrash)
          OutlinedButton(
            onPressed: _isProcessing
                ? null
                : () async {
                    final summary = await _summaryFuture;
                    if (context.mounted) {
                      await _handleSoftDelete(context, summary);
                    }
                  },
            child: const Text('Mover para Lixeira'),
          ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.alertRed,
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.delete_forever, size: 18),
          label: const Text('Excluir Definitivamente'),
          onPressed: _isProcessing
              ? null
              : () async {
                  final summary = await _summaryFuture;
                  if (context.mounted) {
                    await _handlePermanentDelete(context, summary);
                  }
                },
        ),
      ],
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppTheme.textMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
