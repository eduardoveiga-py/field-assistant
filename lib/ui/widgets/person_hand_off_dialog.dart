import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_theme.dart';
import '../../core/date_utils.dart';
import '../../database/app_database.dart';
import '../../ui/providers.dart';

class PersonHandOffHelper {
  /// Gera texto completo estruturado para passar a revisita para outro publicador ou pioneiro
  static String generateMessage({
    required PersonEntry person,
    VisitEntry? lastVisit,
    BibleStudyEntry? linkedStudy,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('📋 *DADOS DA REVISITA PARA ATENDIMENTO*');
    buffer.writeln('👤 *Nome:* ${person.name}');
    if (person.phone != null && person.phone!.trim().isNotEmpty) {
      buffer.writeln('📞 *Telefone:* ${person.phone}');
    }
    if (person.address != null && person.address!.trim().isNotEmpty) {
      buffer.writeln('📍 *Endereço:* ${person.address}');
    }
    if (person.latitude != null && person.longitude != null && (person.latitude != 0.0 || person.longitude != 0.0)) {
      buffer.writeln('🗺️ *Localização no Mapa:* https://www.google.com/maps/search/?api=1&query=${person.latitude},${person.longitude}');
    } else if (person.address != null && person.address!.trim().isNotEmpty) {
      buffer.writeln('🗺️ *Localização no Mapa:* https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(person.address!)}');
    }
    if (person.preferredSchedule != null && person.preferredSchedule!.trim().isNotEmpty) {
      buffer.writeln('🕒 *Melhor Horário Habitual:* ${person.preferredSchedule}');
    }
    buffer.writeln('🌱 *Situação:* ${person.status.toUpperCase()}');

    if (linkedStudy != null) {
      buffer.writeln('📖 *Estudo Bíblico:* ${linkedStudy.title} (Lição ${linkedStudy.currentLesson ?? "1"})');
    }

    if (lastVisit != null) {
      buffer.writeln('💬 *Último Assunto Considerado:* ${lastVisit.topicsDiscussed ?? lastVisit.scriptureOrPub ?? "Conversa inicial"}');
      if (lastVisit.nextStep != null && lastVisit.nextStep!.trim().isNotEmpty) {
        buffer.writeln('⏭️ *Próximo Passo Combinado:* ${lastVisit.nextStep}');
      }
    } else if (person.nextActionNote != null && person.nextActionNote!.trim().isNotEmpty) {
      buffer.writeln('⏭️ *Próximo Passo:* ${person.nextActionNote}');
    }

    if (person.generalNotes != null && person.generalNotes!.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(person.generalNotes!);
        if (decoded is List && decoded.isNotEmpty) {
          final noteTexts = decoded.map((n) => n['text'] ?? '').where((t) => t.isNotEmpty).join('; ');
          if (noteTexts.isNotEmpty) {
            buffer.writeln('📝 *Observações:* $noteTexts');
          }
        } else {
          buffer.writeln('📝 *Observações:* ${person.generalNotes}');
        }
      } catch (_) {
        buffer.writeln('📝 *Observações:* ${person.generalNotes}');
      }
    }

    buffer.writeln('\n_Repassado via App Território / Ministério Pessoal_');
    return buffer.toString();
  }

  /// Compartilha a mensagem diretamente para o WhatsApp
  static Future<void> shareViaWhatsApp(String message) async {
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Exibe o modal completo para preparar a mensagem e registrar o repasse da revisita
  static void showHandOffDialog({
    required BuildContext context,
    required WidgetRef ref,
    required PersonEntry person,
    VisitEntry? lastVisit,
    BibleStudyEntry? linkedStudy,
  }) {
    final message = generateMessage(person: person, lastVisit: lastVisit, linkedStudy: linkedStudy);
    final toPublisherController = TextEditingController();
    final notesController = TextEditingController();
    DateTime chosenDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.forward_to_inbox, color: AppTheme.accentTeal),
                SizedBox(width: 8),
                Expanded(child: Text('Passar Revisita', style: TextStyle(fontSize: 18))),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Esta mensagem contém todos os dados necessários (endereço, mapa, horário e anotações) para outro publicador assumir o contato:',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 10),

                  // Mensagem Gerada
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    constraints: const BoxConstraints(maxHeight: 150),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        message,
                        style: const TextStyle(fontSize: 12, height: 1.4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.copy, size: 16),
                          label: const Text('Copiar', style: TextStyle(fontSize: 12)),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: message));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Mensagem da revisita copiada!')),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                          icon: const Icon(Icons.chat, size: 16),
                          label: const Text('WhatsApp', style: TextStyle(fontSize: 12)),
                          onPressed: () => shareViaWhatsApp(message),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  const Text(
                    'Registrar Repasse (Marcar Revisita Passada):',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryBlue),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Ao confirmar, a revisita mudará para o status "Revisita passada". O registro é preservado mas não aparecerá mais na sua agenda nem nas estatísticas ativas.',
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: toPublisherController,
                    decoration: const InputDecoration(
                      labelText: 'Para quem passou a revisita? *',
                      hintText: 'Ex: Irmão Lucas / Pioneira Ana',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_month, size: 16),
                          label: Text('${chosenDate.day}/${chosenDate.month}/${chosenDate.year} às ${chosenDate.hour.toString().padLeft(2, "0")}:${chosenDate.minute.toString().padLeft(2, "0")}'),
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: chosenDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now().add(const Duration(days: 1)),
                            );
                            if (d != null && context.mounted) {
                              final t = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.fromDateTime(chosenDate),
                              );
                              if (t != null) {
                                setDialogState(() {
                                  chosenDate = DateTime(d.year, d.month, d.day, t.hour, t.minute);
                                });
                              }
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Observações do repasse (opcional)',
                      hintText: 'Ex: Passado por mensagem de WhatsApp com mapa',
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentTeal, foregroundColor: Colors.white),
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Confirmar Repasse'),
                onPressed: () async {
                  final publisher = toPublisherController.text.trim();
                  if (publisher.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Por favor, informe para quem passou a revisita.')),
                    );
                    return;
                  }

                  final repo = ref.read(repositoryProvider);
                  final dtFormatted = AppDateUtils.formatDateTimeWithAt(chosenDate);
                  final noteEntry = 'Revisita passada para $publisher em $dtFormatted.${notesController.text.trim().isNotEmpty ? " Obs: ${notesController.text.trim()}" : ""}';
                  final existingNotes = person.generalNotes ?? '';
                  final updatedNotes = existingNotes.isEmpty ? noteEntry : '$existingNotes\n$noteEntry';

                  // Guarda nota no histórico e atualiza status para 'revisita_passada'
                  await repo.updatePerson(person.copyWith(
                    status: 'revisita_passada',
                    nextActionNote: Value('Passada para $publisher ($dtFormatted)'),
                    nextActionAt: const Value(null),
                    generalNotes: Value(updatedNotes),
                  ));

                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Revisita de "${person.name}" marcada como passada para $publisher!')),
                    );
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  /// Reativa uma revisita que havia sido passada para outro publicador
  static Future<void> reactivatePerson({
    required BuildContext context,
    required WidgetRef ref,
    required PersonEntry person,
    String restoreStatus = 'revisita',
  }) async {
    final repo = ref.read(repositoryProvider);
    await repo.updatePerson(person.copyWith(
      status: restoreStatus,
      nextActionNote: const Value(null),
    ));

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Revisita de "${person.name}" reativada com sucesso! Voltou para as estatísticas e agenda.'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    }
  }
}
