import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_theme.dart';
import '../reports/web_downloader.dart';
import '../settings/app_settings_manager.dart';
import '../ui/providers.dart';
import 'ics_calendar_helper.dart';
import 'ics_picker_helper.dart';

/// Exibe o diálogo com o resultado da exportação .ics e atalho para copiar para a área de transferência
void showIcsExportResultDialog(BuildContext context, String icsData) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.check_circle, color: AppTheme.successGreen),
          SizedBox(width: 8),
          Expanded(child: Text('Arquivo .ics Gerado com Sucesso')),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            kIsWeb
                ? 'O download do arquivo de compromissos (.ics) foi iniciado no navegador.\n\n'
                      'Para importar no Google Agenda:\n'
                      '1. Acesse calendar.google.com no computador.\n'
                      '2. Clique em Configurações > Importar e exportar.\n'
                      '3. Selecione o arquivo baixado e confirme a importação.\n\n'
                      'Para Apple Calendar / iOS:\n'
                      'Abra o arquivo baixado ou adicione pelo app Calendário.'
                : 'O arquivo de compromissos (.ics) foi gerado e salvo nos documentos do aplicativo com sucesso.\n\n'
                      'Você pode copiar os dados abaixo para importar no Google Agenda, Apple Calendar, Outlook ou outro aplicativo:',
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.copy, size: 16),
            label: const Text(
              'Copiar Conteúdo iCal para a Área de Transferência',
              style: TextStyle(fontSize: 12),
            ),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: icsData));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('iCal copiado para a área de transferência!'),
                ),
              );
            },
          ),
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Entendido'),
        ),
      ],
    ),
  );
}

/// Diálogo para colar manualmente o conteúdo .ics / VCALENDAR
void showPasteIcsDialog(BuildContext context, WidgetRef ref) {
  final textController = TextEditingController();
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.content_paste, color: AppTheme.primaryBlue),
          SizedBox(width: 8),
          Expanded(child: Text('Colar Conteúdo .ics / iCal')),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cole abaixo o texto do arquivo .ics (do Google Agenda, Apple Calendar ou outro aplicativo):',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: textController,
              maxLines: 8,
              decoration: const InputDecoration(
                hintText: 'BEGIN:VCALENDAR\nVERSION:2.0\nBEGIN:VEVENT\n...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.file_download_done, size: 16),
          label: const Text('Importar'),
          onPressed: () async {
            final raw = textController.text.trim();
            if (raw.isEmpty || !raw.contains('BEGIN:VEVENT')) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Cole um conteúdo .ics válido contendo eventos VEVENT.',
                  ),
                ),
              );
              return;
            }
            final repo = ref.read(repositoryProvider);
            final res = await IcsCalendarHelper.importIcsEventsToRepository(
              repo: repo,
              rawIcs: raw,
            );
            if (ctx.mounted) Navigator.pop(ctx);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'iCal importado com sucesso! ${res.created} novo(s), ${res.updated} atualizado(s).',
                  ),
                ),
              );
            }
          },
        ),
      ],
    ),
  );
}

/// Importa conteúdo iCal diretamente da Área de Transferência
Future<void> pasteFromClipboard(BuildContext context, WidgetRef ref) async {
  final data = await Clipboard.getData(Clipboard.kTextPlain);
  final text = data?.text?.trim() ?? '';
  if (text.isEmpty || !text.contains('BEGIN:VEVENT')) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'A área de transferência não contém eventos iCal válidos (VEVENT).',
          ),
        ),
      );
    }
    return;
  }
  final repo = ref.read(repositoryProvider);
  final res = await IcsCalendarHelper.importIcsEventsToRepository(
    repo: repo,
    rawIcs: text,
  );
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Importado da área de transferência! ${res.created} novo(s), ${res.updated} atualizado(s).',
        ),
      ),
    );
  }
}

/// Abre a folha modal de importação e exportação de arquivos .ics / iCalendar
void showIcsManagementModal(BuildContext context, WidgetRef ref) {
  final googleUrlController = TextEditingController();
  ref.read(appSettingsManagerProvider).getString('saved_calendar_url').then((
    val,
  ) {
    if (val != null && val.isNotEmpty && googleUrlController.text.isEmpty) {
      googleUrlController.text = val;
    }
  });
  bool isSyncingGoogle = false;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheetState) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              top: 20,
              left: 16,
              right: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.file_download_outlined,
                              color: Color(0xFF7C3AED),
                              size: 24,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Importar / Exportar Calendário (.ics)',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Gerenciamento via arquivo iCalendar (.ics) compatível com Google Agenda, Apple Calendar, Outlook e outros.',
                    style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 16),

                  // Card Google Agenda
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4285F4)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.calendar_month,
                                  color: Color(0xFF4285F4),
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Google Agenda (Google Calendar)',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    Text(
                                      'calendar.google.com',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                icon: const Icon(
                                  Icons.open_in_browser,
                                  size: 16,
                                ),
                                label: const Text(
                                  'Abrir Google Agenda no Navegador',
                                  style: TextStyle(fontSize: 12),
                                ),
                                onPressed: () async {
                                  final uri = Uri.parse(
                                    'https://calendar.google.com',
                                  );
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(
                                      uri,
                                      mode: LaunchMode.externalApplication,
                                    );
                                  }
                                },
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E40AF),
                                  foregroundColor: Colors.white,
                                ),
                                icon: const Icon(Icons.file_download, size: 16),
                                label: const Text(
                                  'Exportar todos para Google Agenda (.ics)',
                                  style: TextStyle(fontSize: 12),
                                ),
                                onPressed: () async {
                                  final repo = ref.read(repositoryProvider);
                                  final allAppts = await (repo.db.select(
                                    repo.db.appointments,
                                  )..where((t) => t.deletedAt.isNull())).get();
                                  final icsData =
                                      IcsCalendarHelper.generateIcsCalendar(
                                        allAppts,
                                      );
                                  FileDownloader.download(
                                    'ministerio_pessoal_agenda.ics',
                                    icsData,
                                  );
                                  if (context.mounted) {
                                    showIcsExportResultDialog(context, icsData);
                                  }
                                },
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          const Text(
                            'Importar / Puxar do Google Agenda:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xFF1E40AF),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF0F172A)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Instruções passo a passo:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '1. Abra o Google Agenda no navegador (calendar.google.com).\n'
                                  '2. Clique em Configurações > Configurações das minhas agendas > Selecione sua agenda.\n'
                                  '3. Role até "Integrar agenda" e copie o "Endereço secreto no formato iCal".\n'
                                  '4. Cole o link abaixo ou baixe o arquivo .ics e importe aqui.',
                                  style: TextStyle(fontSize: 11, height: 1.4),
                                ),
                              ],
                            ),
                          ),
                          if (kIsWeb) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.amber.shade700,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 16,
                                    color: Colors.amber.shade800,
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Dica Web: No navegador, use "Selecionar Arquivo .ics" ou "Colar da Área de Transferência" para importar com 1 clique sem restrições de CORS.',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          TextField(
                            controller: googleUrlController,
                            decoration: const InputDecoration(
                              labelText:
                                  'Endereço iCal / Webcal do Google Agenda',
                              hintText: 'https://calendar.google.com/calendar/ical/.../basic.ics',
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E40AF),
                                  foregroundColor: Colors.white,
                                ),
                                icon: const Icon(Icons.file_open, size: 16),
                                label: const Text(
                                  'Selecionar Arquivo .ics',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onPressed: () async {
                                  final picked =
                                      await IcsPickerHelper.pickIcsFile();
                                  if (picked != null && picked.isNotEmpty) {
                                    final repo = ref.read(repositoryProvider);
                                    final res =
                                        await IcsCalendarHelper.importIcsEventsToRepository(
                                          repo: repo,
                                          rawIcs: picked,
                                        );
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Calendário importado com sucesso! ${res.created} novo(s), ${res.updated} atualizado(s).',
                                          ),
                                        ),
                                      );
                                    }
                                  } else if (!kIsWeb) {
                                    if (context.mounted) {
                                      showPasteIcsDialog(context, ref);
                                    }
                                  }
                                },
                              ),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.download, size: 16),
                                label: const Text(
                                  'Baixar no Navegador',
                                  style: TextStyle(fontSize: 12),
                                ),
                                onPressed: () async {
                                  final rawUrl = googleUrlController.text
                                      .trim();
                                  if (rawUrl.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Cole a URL do Google Agenda acima para baixar no navegador.',
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  var cleanUrl = rawUrl;
                                  if (cleanUrl.startsWith('webcal://')) {
                                    cleanUrl = cleanUrl.replaceFirst(
                                      'webcal://',
                                      'https://',
                                    );
                                  }
                                  final uri = Uri.parse(cleanUrl);
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(
                                      uri,
                                      mode: LaunchMode.externalApplication,
                                    );
                                  }
                                },
                              ),
                              OutlinedButton.icon(
                                icon: isSyncingGoogle
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.sync, size: 16),
                                label: Text(
                                  isSyncingGoogle
                                      ? 'Sincronizando...'
                                      : 'Sincronizar via Webcal',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                onPressed: isSyncingGoogle
                                    ? null
                                    : () async {
                                        final rawUrl = googleUrlController.text
                                            .trim();
                                        if (rawUrl.isEmpty) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Informe uma URL de calendário válida.',
                                                  ),
                                                ),
                                              );
                                          return;
                                        }
                                        setSheetState(
                                          () => isSyncingGoogle = true,
                                        );
                                        try {
                                          final repo = ref.read(
                                            repositoryProvider,
                                          );
                                          final res =
                                              await IcsCalendarHelper.syncFromWebcalUrl(
                                                repo: repo,
                                                rawUrl: rawUrl,
                                              );
                                          if (res != null) {
                                            await ref
                                                .read(
                                                  appSettingsManagerProvider,
                                                )
                                                .setString(
                                                  'saved_calendar_url',
                                                  rawUrl,
                                                );
                                            if (ctx.mounted) {
                                              Navigator.pop(ctx);
                                            }
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Google Agenda sincronizado com sucesso! ${res.created} novo(s), ${res.updated} atualizado(s).',
                                                  ),
                                                ),
                                              );
                                            }
                                          } else {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Não foi possível obter calendário válido via Webcal.',
                                                      ),
                                                    ),
                                                  );
                                            }
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Erro na sincronização: $e',
                                                ),
                                              ),
                                            );
                                          }
                                        } finally {
                                          if (ctx.mounted) {
                                            setSheetState(
                                              () => isSyncingGoogle = false,
                                            );
                                          }
                                        }
                                      },
                              ),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.content_paste, size: 16),
                                label: const Text(
                                  'Colar Texto .ics',
                                  style: TextStyle(fontSize: 12),
                                ),
                                onPressed: () =>
                                    showPasteIcsDialog(context, ref),
                              ),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.paste, size: 16),
                                label: const Text(
                                  'Colar da Área de Transferência',
                                  style: TextStyle(fontSize: 12),
                                ),
                                onPressed: () =>
                                    pasteFromClipboard(context, ref),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Card Apple Calendar
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.apple,
                                  color: Color(0xFF10B981),
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Apple Calendar / iCloud (iPhone / iPad)',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    Text(
                                      'Calendário nativo iOS / iPadOS',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF047857),
                                  foregroundColor: Colors.white,
                                ),
                                icon: const Icon(Icons.file_download, size: 16),
                                label: const Text(
                                  'Exportar para Apple Calendar (.ics)',
                                  style: TextStyle(fontSize: 12),
                                ),
                                onPressed: () async {
                                  final repo = ref.read(repositoryProvider);
                                  final allAppts = await (repo.db.select(
                                    repo.db.appointments,
                                  )..where((t) => t.deletedAt.isNull())).get();
                                  final icsData =
                                      IcsCalendarHelper.generateIcsCalendar(
                                        allAppts,
                                      );
                                  FileDownloader.download(
                                    'ministerio_pessoal_agenda_apple.ics',
                                    icsData,
                                  );
                                  if (context.mounted) {
                                    showIcsExportResultDialog(context, icsData);
                                  }
                                },
                              ),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.paste, size: 16),
                                label: const Text(
                                  'Colar da Área de Transferência',
                                  style: TextStyle(fontSize: 12),
                                ),
                                onPressed: () =>
                                    pasteFromClipboard(context, ref),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
