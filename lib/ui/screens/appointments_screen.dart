import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../../core/app_theme.dart';
import '../../core/date_utils.dart';
import '../../appointments/availability_engine.dart';
import '../../appointments/ics_calendar_helper.dart';
import '../../appointments/ics_picker_helper.dart';
import '../../database/app_database.dart';
import '../../reports/web_downloader.dart';
import '../../settings/app_settings_manager.dart';
import '../providers.dart';
import 'person_detail_screen.dart';

class _CopyWizardRoutine {
  final String id;
  String title;
  int weekday;
  int hour;
  int minute;
  int durationMinutes;
  String frequency;
  int secondWeekday;
  bool isEnabled;
  bool isExpanded;
  final String? personId;
  final String? notes;

  _CopyWizardRoutine({
    required this.id,
    required this.title,
    required this.weekday,
    required this.hour,
    required this.minute,
    required this.durationMinutes,
    required this.frequency,
    required this.secondWeekday,
    required this.isEnabled,
    required this.isExpanded,
    this.personId,
    this.notes,
  });
}

class AppointmentsScreen extends ConsumerStatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  ConsumerState<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends ConsumerState<AppointmentsScreen> {
  DateTime _selectedDate = DateTime.now();
  String _viewMode = 'Mês'; // 'Mês', 'Semana', 'Dia', 'Lista'
  final ScrollController _timeScrollController = ScrollController();

  static bool isMinistryAppointment(AppointmentEntry appt) {
    final titleLower = appt.title.toLowerCase();
    final notesLower = (appt.locationNotes ?? '').toLowerCase();
    if (titleLower.contains('ausência') ||
        titleLower.contains('ausencia') ||
        titleLower.contains('folga') ||
        titleLower.contains('viagem') ||
        titleLower.contains('pessoal') ||
        titleLower.contains('[ausência]') ||
        titleLower.contains('[folga]') ||
        titleLower.contains('[viagem]') ||
        titleLower.contains('[pessoal]') ||
        titleLower.contains('[outro]') ||
        notesLower.contains('tipo:nao_ministerio')) {
      return false;
    }
    return true;
  }

  static Color _getAppointmentActivityColor(AppointmentEntry appt) {
    final titleLower = appt.title.toLowerCase();
    if (titleLower.contains('viagem')) return const Color(0xFF0D9488); // Teal
    if (titleLower.contains('ausência') || titleLower.contains('ausencia')) return const Color(0xFFD97706); // Amber
    if (titleLower.contains('folga')) return const Color(0xFF64748B); // Slate
    if (titleLower.contains('pessoal')) return const Color(0xFF9333EA); // Purple
    if (titleLower.contains('outro')) return const Color(0xFF475569); // Slate Grey
    if (titleLower.contains('estudo') || appt.studyId != null) return const Color(0xFF059669); // Emerald Green
    if (titleLower.contains('revisita')) return const Color(0xFFEA580C); // Orange
    return const Color(0xFF2563EB); // Royal Blue (Campo)
  }

  static Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'realizado':
        return AppTheme.successGreen;
      case 'cancelado':
        return AppTheme.alertRed;
      case 'nao_realizado':
        return AppTheme.alertAmber;
      case 'reagendado':
        return const Color(0xFF8B5CF6);
      default:
        return AppTheme.primaryBlue;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentTime();
      _checkAutoSyncCalendar();
    });
  }

  Future<({int created, int updated})?> _syncFromWebcalUrl(String rawUrl, {bool silent = false}) async {
    var cleanUrl = rawUrl.trim().replaceAll(RegExp(r'^["\x27]|["\x27]$'), '');
    if (cleanUrl.startsWith('webcal://') || cleanUrl.startsWith('webcals://')) {
      cleanUrl = cleanUrl.replaceFirst(RegExp(r'^webcals?://'), 'https://');
    }
    String? icsBody;
    try {
      final uri = Uri.parse(cleanUrl);
      final resp = await http.get(uri).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200 && resp.body.contains('BEGIN:VCALENDAR')) {
        icsBody = resp.body;
      }
    } catch (e) {
      if (kIsWeb) {
        // Tenta proxies CORS alternativos
        final proxies = [
          'https://api.allorigins.win/raw?url=${Uri.encodeComponent(cleanUrl)}',
          'https://corsproxy.io/?${Uri.encodeComponent(cleanUrl)}',
          'https://api.codetabs.com/v1/proxy?quest=${Uri.encodeComponent(cleanUrl)}',
        ];
        for (final p in proxies) {
          try {
            final pResp = await http.get(Uri.parse(p)).timeout(const Duration(seconds: 10));
            if (pResp.statusCode == 200 && pResp.body.contains('BEGIN:VCALENDAR')) {
              icsBody = pResp.body;
              break;
            }
          } catch (_) {}
        }
        if (icsBody == null) {
          // Tenta allorigins formato JSON
          try {
            final jsonUri = Uri.parse('https://api.allorigins.win/get?url=${Uri.encodeComponent(cleanUrl)}');
            final jsonResp = await http.get(jsonUri).timeout(const Duration(seconds: 10));
            if (jsonResp.statusCode == 200) {
              final map = jsonDecode(jsonResp.body);
              if (map is Map && map['contents'] is String) {
                final contents = map['contents'] as String;
                if (contents.contains('BEGIN:VCALENDAR')) {
                  icsBody = contents;
                }
              }
            }
          } catch (_) {}
        }
      }
      if (icsBody == null && !silent) {
        throw Exception(
          'O navegador bloqueou a requisição direta por CORS.\n\n'
          'Por favor, clique no botão "Baixar no Navegador" para baixar o arquivo .ics e depois use "Selecionar Arquivo .ics" ou "Colar Texto .ics" para importar instantaneamente.'
        );
      }
    }

    if (icsBody != null) {
      final res = await _importIcsContent(icsBody);
      await ref.read(appSettingsManagerProvider).setString('saved_calendar_url', cleanUrl);
      return res;
    }
    return null;
  }

  Future<void> _checkAutoSyncCalendar() async {
    try {
      final settings = ref.read(appSettingsManagerProvider);
      final savedUrl = await settings.getString('saved_calendar_url');
      if (savedUrl != null && savedUrl.trim().isNotEmpty) {
        await _syncFromWebcalUrl(savedUrl.trim(), silent: true);
      }
    } catch (_) {
      // Auto-sync silencioso em segundo plano
    }
  }

  void _scrollToCurrentTime() {
    if (_timeScrollController.hasClients) {
      final now = DateTime.now();
      final currentHour = now.hour.clamp(7, 22);
      final offset = (currentHour - 7) * 60.0;
      _timeScrollController.animateTo(
        offset.clamp(0.0, _timeScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  String _getMonthName(int month) {
    const months = [
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro',
    ];
    return months[month - 1];
  }

  Future<void> _exportToGoogleCalendar(AppointmentEntry appt) async {
    String formatCalDate(DateTime dt) {
      final u = dt.toUtc();
      return '${u.year.toString().padLeft(4, "0")}'
          '${u.month.toString().padLeft(2, "0")}'
          '${u.day.toString().padLeft(2, "0")}T'
          '${u.hour.toString().padLeft(2, "0")}'
          '${u.minute.toString().padLeft(2, "0")}00Z';
    }

    final start = formatCalDate(appt.startTime);
    final end = formatCalDate(appt.endTime);
    final text = Uri.encodeComponent(appt.title);
    final details = Uri.encodeComponent(appt.locationNotes ?? 'Agendado pelo App Ministério Pessoal');

    final url = 'https://calendar.google.com/calendar/render?action=TEMPLATE&text=$text&dates=$start/$end&details=$details';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _generateIcsFile(List<AppointmentEntry> appts) {
    final buffer = StringBuffer();
    buffer.writeln('BEGIN:VCALENDAR');
    buffer.writeln('VERSION:2.0');
    buffer.writeln('PRODID:-//Ministerio Pessoal//Agenda//PT-BR');
    buffer.writeln('CALSCALE:GREGORIAN');
    buffer.writeln('METHOD:PUBLISH');

    String fmt(DateTime dt) {
      final u = dt.toUtc();
      return '${u.year.toString().padLeft(4, "0")}'
          '${u.month.toString().padLeft(2, "0")}'
          '${u.day.toString().padLeft(2, "0")}T'
          '${u.hour.toString().padLeft(2, "0")}'
          '${u.minute.toString().padLeft(2, "0")}'
          '${u.second.toString().padLeft(2, "0")}Z';
    }

    for (final a in appts) {
      if (a.deletedAt != null || a.status == 'cancelado') continue;
      buffer.writeln('BEGIN:VEVENT');
      buffer.writeln('UID:${a.id}@ministeriopessoal.app');
      buffer.writeln('DTSTAMP:${fmt(a.updatedAt)}');
      buffer.writeln('DTSTART:${fmt(a.startTime)}');
      buffer.writeln('DTEND:${fmt(a.endTime)}');
      buffer.writeln('SUMMARY:${a.title.replaceAll("\n", " ")}');
      if (a.locationNotes != null && a.locationNotes!.isNotEmpty) {
        buffer.writeln('LOCATION:${a.locationNotes!.replaceAll("\n", " ")}');
        buffer.writeln('DESCRIPTION:${a.locationNotes!.replaceAll("\n", "\\n")}');
      }
      buffer.writeln('STATUS:${a.status == "realizado" ? "CONFIRMED" : "TENTATIVE"}');
      buffer.writeln('END:VEVENT');
    }

    buffer.writeln('END:VCALENDAR');
    return buffer.toString();
  }

  Future<({int created, int updated})> _importIcsContent(String raw) async {
    int createdCount = 0;
    int updatedCount = 0;
    final repo = ref.read(repositoryProvider);
    final existingAppts = await repo.db.select(repo.db.appointments).get();
    final events = IcsCalendarHelper.parseIcsEvents(raw);

    for (final ev in events) {
      AppointmentEntry? existing;
      if (ev.apptId != null) {
        existing = existingAppts.where((a) => a.id == ev.apptId).firstOrNull;
      }
      existing ??= existingAppts.where((a) {
        final sameTitle = a.title.trim().toLowerCase() == ev.summary.trim().toLowerCase();
        final timeDiff = a.startTime.difference(ev.startTime).inMinutes.abs();
        return sameTitle && timeDiff < 5;
      }).firstOrNull;

      if (existing != null) {
        await repo.updateAppointment(
          existing.copyWith(
            title: ev.summary,
            startTime: ev.startTime,
            endTime: ev.endTime,
            durationMinutes: ev.durationMinutes,
            status: ev.status,
            locationNotes: Value(ev.location ?? existing.locationNotes),
          ),
        );
        updatedCount++;
      } else {
        await repo.createAppointment(
          id: ev.apptId,
          title: ev.summary,
          startTime: ev.startTime,
          endTime: ev.endTime,
          durationMinutes: ev.durationMinutes,
          status: ev.status,
          locationNotes: ev.location,
        );
        createdCount++;
      }
    }
    return (created: createdCount, updated: updatedCount);
  }

  void _showIcsExportResultDialog(BuildContext context, String icsData) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppTheme.successGreen),
            SizedBox(width: 8),
            Text('Arquivo .ics Gerado com Sucesso'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'O download do arquivo "ministerio_pessoal_agenda.ics" foi iniciado.\n\n'
              'Para importar no Google Agenda:\n'
              '1. Acesse calendar.google.com no computador.\n'
              '2. Clique em Configurações > Importar e exportar.\n'
              '3. Selecione o arquivo baixado e confirme a importação.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copiar Conteúdo iCal para a Área de Transferência'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: icsData));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('iCal copiado para a área de transferência!')),
                );
              },
            ),
          ],
        ),
        actions: [
          ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido')),
        ],
      ),
    );
  }

  void _showPasteIcsDialog(BuildContext context) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.content_paste, color: AppTheme.primaryBlue),
            SizedBox(width: 8),
            Text('Colar Conteúdo .ics / iCal'),
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton.icon(
            icon: const Icon(Icons.file_download_done, size: 16),
            label: const Text('Importar'),
            onPressed: () async {
              final raw = textController.text.trim();
              if (raw.isEmpty || !raw.contains('BEGIN:VEVENT')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Conteúdo iCal inválido ou sem eventos (VEVENT).')),
                );
                return;
              }
              final res = await _importIcsContent(raw);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Importação concluída! ${res.created} novo(s), ${res.updated} atualizado(s).')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pasteFromClipboard(BuildContext context) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty || !text.contains('BEGIN:VEVENT')) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A área de transferência não contém eventos iCal válidos (VEVENT).')),
        );
      }
      return;
    }
    final res = await _importIcsContent(text);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Importado da área de transferência! ${res.created} novo(s), ${res.updated} atualizado(s).')),
      );
    }
  }

  void _showOfficialCalendarSyncModal(BuildContext context, List<AppointmentEntry> allAppts) {
    final googleUrlController = TextEditingController();
    ref.read(appSettingsManagerProvider).getString('saved_calendar_url').then((val) {
      if (val != null && val.isNotEmpty && googleUrlController.text.isEmpty) {
        googleUrlController.text = val;
      }
    });
    bool isSyncingGoogle = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
                        const Row(
                          children: [
                            Icon(Icons.sync_alt, color: AppTheme.primaryBlue, size: 24),
                            SizedBox(width: 8),
                            Text('Sincronização de Calendários', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Integração oficial bidirecional com Google Agenda e Apple Calendar (iPhone/iPad).',
                      style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 16),

                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
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
                                    color: const Color(0xFF4285F4).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.calendar_month, color: Color(0xFF4285F4), size: 22),
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Google Agenda (Google Calendar)',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                      Text(
                                        'calendar.google.com',
                                        style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
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
                                  icon: const Icon(Icons.open_in_browser, size: 16),
                                  label: const Text('Abrir Google Agenda no Navegador', style: TextStyle(fontSize: 12)),
                                  onPressed: () async {
                                    final uri = Uri.parse('https://calendar.google.com');
                                    if (await canLaunchUrl(uri)) {
                                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                                    }
                                  },
                                ),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1E40AF),
                                    foregroundColor: Colors.white,
                                  ),
                                  icon: const Icon(Icons.file_download, size: 16),
                                  label: const Text('Exportar todos para Google Agenda (.ics)', style: TextStyle(fontSize: 12)),
                                  onPressed: () {
                                    final icsData = _generateIcsFile(allAppts);
                                    FileDownloader.download('ministerio_pessoal_agenda.ics', icsData);
                                    _showIcsExportResultDialog(context, icsData);
                                  },
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            const Text(
                              'Importar / Puxar do Google Agenda:',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E40AF)),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                              ),
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Instruções passo a passo:',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
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
                                  border: Border.all(color: Colors.amber.shade700),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.info_outline, size: 16, color: Colors.amber.shade800),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        'Dica Web: No navegador, use "Selecionar Arquivo .ics" ou "Baixar no Navegador" para importar com 1 clique sem restrições de CORS.',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
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
                                labelText: 'Endereço iCal / Webcal do Google Agenda',
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
                                  label: const Text('Selecionar Arquivo .ics', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  onPressed: () async {
                                    final picked = await IcsPickerHelper.pickIcsFile();
                                    if (picked != null && picked.isNotEmpty) {
                                      final res = await _importIcsContent(picked);
                                      if (ctx.mounted) Navigator.pop(ctx);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Google Agenda importado com sucesso! ${res.created} novo(s), ${res.updated} atualizado(s).')),
                                        );
                                      }
                                    }
                                  },
                                ),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.download, size: 16),
                                  label: const Text('Baixar no Navegador', style: TextStyle(fontSize: 12)),
                                  onPressed: () async {
                                    final rawUrl = googleUrlController.text.trim();
                                    if (rawUrl.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Cole a URL do Google Agenda acima para baixar no navegador.')),
                                      );
                                      return;
                                    }
                                    var cleanUrl = rawUrl;
                                    if (cleanUrl.startsWith('webcal://')) {
                                      cleanUrl = cleanUrl.replaceFirst('webcal://', 'https://');
                                    }
                                    final uri = Uri.parse(cleanUrl);
                                    if (await canLaunchUrl(uri)) {
                                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                                    }
                                  },
                                ),
                                OutlinedButton.icon(
                                  icon: isSyncingGoogle
                                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                      : const Icon(Icons.sync, size: 16),
                                  label: Text(isSyncingGoogle ? 'Sincronizando...' : 'Sincronizar via Webcal', style: const TextStyle(fontSize: 12)),
                                  onPressed: isSyncingGoogle
                                      ? null
                                      : () async {
                                          final rawUrl = googleUrlController.text.trim();
                                          if (rawUrl.isEmpty) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Informe uma URL de calendário válida.')),
                                            );
                                            return;
                                          }
                                          setSheetState(() => isSyncingGoogle = true);
                                          try {
                                            final res = await _syncFromWebcalUrl(rawUrl);
                                            if (res != null) {
                                              if (ctx.mounted) Navigator.pop(ctx);
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('Google Agenda sincronizado com sucesso! ${res.created} novo(s), ${res.updated} atualizado(s).')),
                                                );
                                              }
                                            } else {
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('Não foi possível obter calendário válido via Webcal.')),
                                                );
                                              }
                                            }
                                          } catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('Erro na sincronização: $e')),
                                              );
                                            }
                                          } finally {
                                            if (ctx.mounted) {
                                              setSheetState(() => isSyncingGoogle = false);
                                            }
                                          }
                                        },
                                ),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.content_paste, size: 16),
                                  label: const Text('Colar Texto .ics', style: TextStyle(fontSize: 12)),
                                  onPressed: () => _showPasteIcsDialog(context),
                                ),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.paste, size: 16),
                                  label: const Text('Colar da Área de Transferência', style: TextStyle(fontSize: 12)),
                                  onPressed: () => _pasteFromClipboard(context),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
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
                                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.apple, color: Color(0xFF10B981), size: 22),
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Apple Calendar / iCloud (iPhone / iPad)',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                      Text(
                                        'Calendário nativo iOS / iPadOS',
                                        style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF047857),
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.file_download, size: 16),
                              label: const Text('Exportar para Apple Calendar (.ics)', style: TextStyle(fontSize: 12)),
                              onPressed: () {
                                final icsData = _generateIcsFile(allAppts);
                                FileDownloader.download('ministerio_pessoal_agenda_apple.ics', icsData);
                                _showIcsExportResultDialog(context, icsData);
                              },
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

  void _showNewAppointmentModal(BuildContext context, {DateTime? initialDateTime}) {
    final titleController = TextEditingController();
    DateTime chosenDate = initialDateTime ?? _selectedDate;
    TimeOfDay chosenTime = initialDateTime != null
        ? TimeOfDay(hour: initialDateTime.hour, minute: initialDateTime.minute)
        : const TimeOfDay(hour: 14, minute: 0);
    int durationMinutes = 30;
    String? selectedPersonId;
    String appointmentCategory = 'Revisita';
    final locationController = TextEditingController();
    String recurrence = 'Único';
    int recurrenceCount = 8;
    bool respectAvailability = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final start = DateTime(chosenDate.year, chosenDate.month, chosenDate.day, chosenTime.hour, chosenTime.minute);
          final existingAppts = ref.read(appointmentsStreamProvider).value ?? [];
          final availability = AvailabilityEngine.checkAvailability(
            startTime: start,
            durationMinutes: durationMinutes,
            existingAppointments: existingAppts,
          );

          final people = ref.read(peopleStreamProvider).value ?? [];

          final occurrences = <DateTime>[start];
          if (recurrence != 'Único') {
            for (int i = 1; i < recurrenceCount; i++) {
              if (recurrence == 'Semanal' || recurrence == 'Toda semana') {
                occurrences.add(start.add(Duration(days: i * 7)));
              } else if (recurrence == 'Quinzenal' || recurrence == 'A cada 15 dias') {
                occurrences.add(start.add(Duration(days: i * 14)));
              } else if (recurrence == '2x por semana') {
                final daysOffset = (i ~/ 2) * 7 + (i % 2 == 1 ? 3 : 0);
                occurrences.add(start.add(Duration(days: daysOffset)));
              } else if (recurrence == 'Mensal') {
                final targetMonth = start.month + i;
                final yearOffset = (targetMonth - 1) ~/ 12;
                final month = ((targetMonth - 1) % 12) + 1;
                final year = start.year + yearOffset;
                final daysInMonth = DateTime(year, month + 1, 0).day;
                final day = start.day.clamp(1, daysInMonth);
                occurrences.add(DateTime(year, month, day, start.hour, start.minute));
              } else if (recurrence == 'A cada 2 meses') {
                final targetMonth = start.month + (i * 2);
                final yearOffset = (targetMonth - 1) ~/ 12;
                final month = ((targetMonth - 1) % 12) + 1;
                final year = start.year + yearOffset;
                final daysInMonth = DateTime(year, month + 1, 0).day;
                final day = start.day.clamp(1, daysInMonth);
                occurrences.add(DateTime(year, month, day, start.hour, start.minute));
              }
            }
          }

          int recurrenceConflicts = 0;
          if (recurrence != 'Único') {
            for (final occ in occurrences) {
              if (AvailabilityEngine.hasCollision(
                start: occ,
                end: occ.add(Duration(minutes: durationMinutes)),
                existingAppointments: existingAppts,
              )) {
                recurrenceConflicts++;
              }
            }
          }

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.event, color: AppTheme.primaryBlue),
                SizedBox(width: 8),
                Text('Novo Compromisso'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: appointmentCategory,
                    decoration: const InputDecoration(labelText: 'Tipo de Compromisso'),
                    items: const [
                      DropdownMenuItem(value: 'Serviço de Campo', child: Text('🚶 Saída de Campo / Testemunho')),
                      DropdownMenuItem(value: 'Revisita', child: Text('🔄 Revisita')),
                      DropdownMenuItem(value: 'Estudo Bíblico', child: Text('📖 Estudo Bíblico')),
                      DropdownMenuItem(value: 'Reunião', child: Text('🏛️ Reunião Congregacional')),
                      DropdownMenuItem(value: 'Viagem', child: Text('✈️ Viagem (Bloqueio de Agenda)')),
                      DropdownMenuItem(value: 'Folga', child: Text('🏖️ Folga / Descanso (Bloqueio de Agenda)')),
                      DropdownMenuItem(value: 'Ausência', child: Text('🚫 Ausência / Indisponível')),
                      DropdownMenuItem(value: 'Pessoal', child: Text('👤 Pessoal (Médico, Família, Trabalho)')),
                      DropdownMenuItem(value: 'Outro', child: Text('📌 Outro Compromisso')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          appointmentCategory = val;
                          if (titleController.text.isEmpty) {
                            if (val == 'Pessoal') titleController.text = 'Compromisso Pessoal';
                            if (val == 'Reunião') titleController.text = 'Reunião Congregacional';
                            if (val == 'Serviço de Campo') titleController.text = 'Saída de Campo';
                            if (val == 'Viagem') titleController.text = 'Viagem';
                            if (val == 'Folga') titleController.text = 'Folga';
                            if (val == 'Ausência') titleController.text = 'Ausência';
                          }
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'Título do compromisso *',
                      hintText: appointmentCategory == 'Pessoal' ? 'Ex: Consulta médica ou Banco' : 'Ex: Revisita ou Estudo Bíblico',
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  if (people.isNotEmpty) ...[
                    DropdownButtonFormField<String?>(
                      initialValue: selectedPersonId,
                      decoration: const InputDecoration(
                        labelText: 'Contato Cadastrado (opcional)',
                        prefixIcon: Icon(Icons.person_outline, size: 20),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('Nenhum vínculo')),
                        ...people.map((p) => DropdownMenuItem<String?>(value: p.id, child: Text(p.name))),
                      ],
                      onChanged: (val) {
                        setDialogState(() {
                          selectedPersonId = val;
                          if (val != null) {
                            final p = people.firstWhere((element) => element.id == val);
                            if (titleController.text.isEmpty || titleController.text == 'Revisita' || titleController.text == 'Estudo Bíblico') {
                              titleController.text = '${appointmentCategory == "Estudo Bíblico" ? "Estudo" : "Revisita"}: ${p.name}';
                            }
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.date_range, size: 16),
                        label: Text(AppDateUtils.formatDate(chosenDate)),
                        onPressed: () async {
                          final p = await showDatePicker(
                            context: context,
                            initialDate: chosenDate,
                            firstDate: DateTime.now().subtract(const Duration(days: 30)),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (p != null) setDialogState(() => chosenDate = p);
                        },
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.access_time, size: 16),
                        label: Text('${chosenTime.hour.toString().padLeft(2, '0')}:${chosenTime.minute.toString().padLeft(2, '0')}'),
                        onPressed: () async {
                          final t = await showTimePicker(
                            context: context,
                            initialTime: chosenTime,
                          );
                          if (t != null) setDialogState(() => chosenTime = t);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: durationMinutes,
                    decoration: const InputDecoration(labelText: 'Duração estimada'),
                    items: const [
                      DropdownMenuItem(value: 15, child: Text('15 min (Rápida)')),
                      DropdownMenuItem(value: 30, child: Text('30 min (Padrão)')),
                      DropdownMenuItem(value: 45, child: Text('45 min')),
                      DropdownMenuItem(value: 60, child: Text('60 min (1 hora)')),
                      DropdownMenuItem(value: 90, child: Text('90 min (1h 30m)')),
                      DropdownMenuItem(value: 120, child: Text('120 min (2 horas)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => durationMinutes = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: recurrence,
                    decoration: const InputDecoration(labelText: 'Repetição / Recorrência'),
                    items: const [
                      DropdownMenuItem(value: 'Único', child: Text('Apenas esta data (Único)')),
                      DropdownMenuItem(value: '2x por semana', child: Text('2x por semana')),
                      DropdownMenuItem(value: 'Semanal', child: Text('Semanal (Toda semana)')),
                      DropdownMenuItem(value: 'Quinzenal', child: Text('Quinzenal (A cada 15 dias)')),
                      DropdownMenuItem(value: 'Mensal', child: Text('Mensal (a cada mês)')),
                      DropdownMenuItem(value: 'A cada 2 meses', child: Text('A cada 2 meses (Bimestral)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => recurrence = val);
                    },
                  ),
                  if (recurrence != 'Único') ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: recurrenceCount,
                      decoration: const InputDecoration(labelText: 'Quantidade de ocorrências'),
                      items: const [
                        DropdownMenuItem(value: 4, child: Text('4 ocorrências')),
                        DropdownMenuItem(value: 8, child: Text('8 ocorrências')),
                        DropdownMenuItem(value: 12, child: Text('12 ocorrências')),
                        DropdownMenuItem(value: 16, child: Text('16 ocorrências')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => recurrenceCount = val);
                      },
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Respeitar disponibilidade da agenda', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Pula automaticamente horários conflitantes via AvailabilityEngine', style: TextStyle(fontSize: 11)),
                      value: respectAvailability,
                      onChanged: (val) => setDialogState(() => respectAvailability = val),
                    ),
                  ],
                  const SizedBox(height: 10),
                  TextField(
                    controller: locationController,
                    decoration: const InputDecoration(
                      labelText: 'Local ou observação',
                      hintText: 'Ex: Salão do Reino / Casa do estudante / Pessoal',
                    ),
                  ),
                  const SizedBox(height: 14),

                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (recurrence == 'Único' ? availability.isAvailable : recurrenceConflicts == 0)
                          ? AppTheme.successGreen.withValues(alpha: 0.1)
                          : AppTheme.alertAmber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: (recurrence == 'Único' ? availability.isAvailable : recurrenceConflicts == 0)
                            ? AppTheme.successGreen
                            : AppTheme.alertAmber,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              (recurrence == 'Único' ? availability.isAvailable : recurrenceConflicts == 0)
                                  ? Icons.check_circle
                                  : Icons.warning_amber,
                              color: (recurrence == 'Único' ? availability.isAvailable : recurrenceConflicts == 0)
                                  ? AppTheme.successGreen
                                  : AppTheme.alertAmber,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                recurrence == 'Único'
                                    ? availability.message
                                    : recurrenceConflicts == 0
                                        ? 'Todas as ${occurrences.length} datas estão 100% livres!'
                                        : 'Atenção: $recurrenceConflicts de ${occurrences.length} datas possuem sobreposição!',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: (recurrence == 'Único' ? availability.isAvailable : recurrenceConflicts == 0)
                                      ? AppTheme.successGreen
                                      : const Color(0xFF92400E),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (recurrence == 'Único' && !availability.isAvailable && availability.suggestedAlternativeSlots.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          const Text('Sugestões livres:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          Wrap(
                            spacing: 6,
                            children: availability.suggestedAlternativeSlots.map((s) {
                              return ActionChip(
                                label: Text(AppDateUtils.formatTime(s)),
                                onPressed: () {
                                  setDialogState(() {
                                    chosenDate = s;
                                    chosenTime = TimeOfDay.fromDateTime(s);
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () async {
                  final title = titleController.text.trim();
                  if (title.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Informe o título do compromisso.')),
                    );
                    return;
                  }

                  final repo = ref.read(repositoryProvider);
                  int createdCount = 0;
                  int skippedCount = 0;
                  final runningAppts = List<AppointmentEntry>.from(existingAppts);

                  for (final occ in occurrences) {
                    final occEnd = occ.add(Duration(minutes: durationMinutes));
                    final hasConflict = AvailabilityEngine.hasCollision(
                      start: occ,
                      end: occEnd,
                      existingAppointments: runningAppts,
                    );

                    if (hasConflict && respectAvailability && occurrences.length > 1) {
                      skippedCount++;
                      continue;
                    }

                    final newEntry = await repo.createAppointment(
                      personId: selectedPersonId,
                      title: title,
                      startTime: occ,
                      endTime: occEnd,
                      durationMinutes: durationMinutes,
                      status: 'confirmado',
                      locationNotes: locationController.text.trim().isEmpty ? null : locationController.text.trim(),
                    );
                    runningAppts.add(newEntry);
                    createdCount++;
                  }

                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    final message = occurrences.length == 1
                        ? 'Compromisso agendado no calendário com sucesso!'
                        : '$createdCount compromisso(s) recorrente(s) agendado(s)!${skippedCount > 0 ? " ($skippedCount pulado(s) por conflito)" : ""}';
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(message)),
                    );
                  }
                },
                child: const Text('Salvar no Calendário'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAppointmentActions(BuildContext context, AppointmentEntry appt) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.85,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: _getStatusColor(appt.status).withValues(alpha: 0.15),
                      child: Icon(Icons.event, color: _getStatusColor(appt.status)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(appt.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text(
                            '${AppDateUtils.formatDateTime(appt.startTime)} - ${AppDateUtils.formatTime(appt.endTime)} (${appt.durationMinutes} min)',
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const Divider(height: 24),
                ListTile(
                  leading: const Icon(Icons.sync_alt, color: AppTheme.primaryBlue),
                  title: const Text('Reagendar (Preservar Histórico)'),
                  subtitle: const Text('Move para nova data mantendo rastreabilidade'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showRescheduleModal(context, appt);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.check_circle_outline, color: AppTheme.successGreen),
                  title: const Text('Marcar como Realizado'),
                  onTap: () async {
                    final repo = ref.read(repositoryProvider);
                    await repo.updateAppointment(appt.copyWith(status: 'realizado'));
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                ),
                if (appt.personId != null)
                  ListTile(
                    leading: const Icon(Icons.person_outline, color: AppTheme.accentTeal),
                    title: const Text('Abrir Cadastro da Pessoa'),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PersonDetailScreen(personId: appt.personId!),
                        ),
                      );
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.calendar_month, color: Color(0xFF1E40AF)),
                  title: const Text('Adicionar ao Google Agenda'),
                  subtitle: const Text('Abre o Google Agenda no navegador com dados preenchidos'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _exportToGoogleCalendar(appt);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: AppTheme.alertRed),
                  title: const Text('Excluir Compromisso', style: TextStyle(color: AppTheme.alertRed)),
                  onTap: () async {
                    final repo = ref.read(repositoryProvider);
                    await repo.deleteAppointment(appt.id);
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Compromisso movido para a lixeira.')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRescheduleModal(BuildContext context, AppointmentEntry appt) {
    DateTime chosenDate = appt.startTime.add(const Duration(days: 7));
    TimeOfDay chosenTime = TimeOfDay.fromDateTime(appt.startTime);
    int durationMinutes = appt.durationMinutes;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final start = DateTime(chosenDate.year, chosenDate.month, chosenDate.day, chosenTime.hour, chosenTime.minute);
          final existingAppts = ref.read(appointmentsStreamProvider).value ?? [];
          final availability = AvailabilityEngine.checkAvailability(
            startTime: start,
            durationMinutes: durationMinutes,
            existingAppointments: existingAppts,
            excludeAppointmentId: appt.id,
          );

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.sync_alt, color: AppTheme.primaryBlue),
                SizedBox(width: 8),
                Text('Reagendar Compromisso'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(appt.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 6),
                  Text(
                    'Anterior: ${AppDateUtils.formatDateTime(appt.startTime)}',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.date_range, size: 16),
                        label: Text(AppDateUtils.formatDate(chosenDate)),
                        onPressed: () async {
                          final p = await showDatePicker(
                            context: context,
                            initialDate: chosenDate,
                            firstDate: DateTime.now().subtract(const Duration(days: 30)),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (p != null) setDialogState(() => chosenDate = p);
                        },
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.access_time, size: 16),
                        label: Text('${chosenTime.hour.toString().padLeft(2, '0')}:${chosenTime.minute.toString().padLeft(2, '0')}'),
                        onPressed: () async {
                          final t = await showTimePicker(
                            context: context,
                            initialTime: chosenTime,
                          );
                          if (t != null) setDialogState(() => chosenTime = t);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: availability.isAvailable ? AppTheme.successGreen.withValues(alpha: 0.1) : AppTheme.alertAmber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: availability.isAvailable ? AppTheme.successGreen : AppTheme.alertAmber,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              availability.isAvailable ? Icons.check_circle : Icons.warning_amber,
                              color: availability.isAvailable ? AppTheme.successGreen : AppTheme.alertAmber,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                availability.message,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: availability.isAvailable ? AppTheme.successGreen : const Color(0xFF92400E),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () async {
                  final repo = ref.read(repositoryProvider);
                  await repo.rescheduleAppointment(
                    oldAppointment: appt,
                    newStartTime: start,
                    newEndTime: start.add(Duration(minutes: durationMinutes)),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Compromisso reagendado com sucesso! Histórico preservado.')),
                    );
                  }
                },
                child: const Text('Confirmar Reagendamento'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showMonthlyScheduleCopyWizard(BuildContext context, List<AppointmentEntry> allAppts) {
    int sourceYear = _selectedDate.year;
    int sourceMonth = _selectedDate.month;
    int targetYear = sourceMonth == 12 ? sourceYear + 1 : sourceYear;
    int targetMonth = sourceMonth == 12 ? 1 : sourceMonth + 1;

    final sourceAppts = allAppts.where((a) =>
        a.deletedAt == null &&
        a.status != 'cancelado' &&
        a.startTime.year == sourceYear &&
        a.startTime.month == sourceMonth).toList();

    // Cria lista inicial mutável de rotinas identificadas no mês de origem
    final List<_CopyWizardRoutine> wizardRoutines = [];
    final seen = <String>{};
    for (final a in sourceAppts) {
      final key = '${a.title}_${a.startTime.weekday}_${a.startTime.hour}_${a.startTime.minute}';
      if (!seen.contains(key)) {
        seen.add(key);
        wizardRoutines.add(_CopyWizardRoutine(
          id: key,
          title: a.title,
          weekday: a.startTime.weekday,
          hour: a.startTime.hour,
          minute: a.startTime.minute,
          durationMinutes: a.durationMinutes,
          frequency: 'semanal',
          secondWeekday: (a.startTime.weekday + 3) % 7 == 0 ? 7 : (a.startTime.weekday + 3) % 7,
          isEnabled: true,
          isExpanded: false,
          personId: a.personId,
          notes: a.locationNotes,
        ));
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setWizardState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final targetExistingAppts = allAppts.where((a) =>
              a.deletedAt == null &&
              a.status != 'cancelado' &&
              a.startTime.year == targetYear &&
              a.startTime.month == targetMonth).toList();

          final daysInTargetMonth = DateTime(targetYear, targetMonth + 1, 0).day;

          // Função de cálculo de datas conforme a frequência selecionada
          List<DateTime> calculateRoutineDates(_CopyWizardRoutine r) {
            final primaryMatches = <DateTime>[];
            final secondMatches = <DateTime>[];

            for (int day = 1; day <= daysInTargetMonth; day++) {
              final candidate = DateTime(targetYear, targetMonth, day, r.hour, r.minute);
              if (candidate.weekday == r.weekday) {
                primaryMatches.add(candidate);
              } else if (r.frequency == '2x_semana' && candidate.weekday == r.secondWeekday) {
                secondMatches.add(candidate);
              }
            }

            if (r.frequency == 'semanal') {
              return primaryMatches;
            } else if (r.frequency == 'quinzenal_1_3') {
              final res = <DateTime>[];
              for (int i = 0; i < primaryMatches.length; i++) {
                if (i % 2 == 0) res.add(primaryMatches[i]);
              }
              return res;
            } else if (r.frequency == 'quinzenal_2_4') {
              final res = <DateTime>[];
              for (int i = 0; i < primaryMatches.length; i++) {
                if (i % 2 == 1) res.add(primaryMatches[i]);
              }
              return res;
            } else if (r.frequency == 'mensal') {
              return primaryMatches.isNotEmpty ? [primaryMatches.first] : [];
            } else if (r.frequency == '2x_semana') {
              final combined = [...primaryMatches, ...secondMatches]..sort();
              return combined;
            }
            return primaryMatches;
          }

          int totalPendingToCreate = 0;
          for (final r in wizardRoutines.where((r) => r.isEnabled)) {
            final dates = calculateRoutineDates(r);
            for (final dt in dates) {
              final hasDuplicate = targetExistingAppts.any((existing) {
                final sameTitle = existing.title.trim().toLowerCase() == r.title.trim().toLowerCase();
                final timeDiff = existing.startTime.difference(dt).inMinutes.abs();
                return sameTitle && timeDiff < 15;
              });
              if (!hasDuplicate) totalPendingToCreate++;
            }
          }

          const weekdayLabels = ['Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo'];

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.copy_all_rounded, color: AppTheme.primaryBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Assistente: Replicar Programação',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppTheme.textDark),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 620,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Replica com segurança as rotinas do ministério, revisitas e estudos de um mês para o outro. '
                      'Você pode confirmar, editar frequência, dia, hora ou remover cada atividade antes de agendar.',
                      style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : AppTheme.textMuted),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Origem:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                                Text(
                                  '${_getMonthName(sourceMonth)} $sourceYear',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.arrow_forward, size: 18, color: AppTheme.primaryBlue),
                        ),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Destino:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.accentTeal)),
                                Text(
                                  '${_getMonthName(targetMonth)} $targetYear',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Rotinas Identificadas no Mês (${wizardRoutines.length}):',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          '${wizardRoutines.where((r) => r.isEnabled).length} ativa(s)',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (wizardRoutines.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Text(
                            'Nenhuma rotina ou compromisso ativo encontrado no mês de origem.',
                            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                          ),
                        ),
                      )
                    else
                      ...wizardRoutines.map((r) {
                        final targetDates = calculateRoutineDates(r);
                        int alreadyExistsCount = 0;
                        int freeCount = 0;
                        for (final dt in targetDates) {
                          final hasDuplicate = targetExistingAppts.any((existing) {
                            final sameTitle = existing.title.trim().toLowerCase() == r.title.trim().toLowerCase();
                            final timeDiff = existing.startTime.difference(dt).inMinutes.abs();
                            return sameTitle && timeDiff < 15;
                          });
                          if (hasDuplicate) {
                            alreadyExistsCount++;
                          } else {
                            freeCount++;
                          }
                        }

                        final weekdayName = weekdayLabels[r.weekday - 1];
                        final timeStr = '${r.hour.toString().padLeft(2, '0')}:${r.minute.toString().padLeft(2, '0')}';
                        final freqLabel = r.frequency == 'semanal'
                            ? 'Semanal'
                            : r.frequency == 'quinzenal_1_3'
                                ? 'Quinzenal (1ª e 3ª semana)'
                                : r.frequency == 'quinzenal_2_4'
                                    ? 'Quinzenal (2ª e 4ª semana)'
                                    : r.frequency == 'mensal'
                                        ? 'Mensal (1x)'
                                        : '2x por semana ($weekdayName e ${weekdayLabels[r.secondWeekday - 1]})';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: !r.isEnabled
                                  ? Colors.grey.withValues(alpha: 0.3)
                                  : r.isExpanded
                                      ? AppTheme.primaryBlue
                                      : (freeCount > 0
                                          ? (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))
                                          : AppTheme.alertAmber.withValues(alpha: 0.5)),
                              width: r.isExpanded ? 1.5 : 1.0,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Cabeçalho da rotina
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: r.isEnabled,
                                      activeColor: AppTheme.primaryBlue,
                                      onChanged: (val) {
                                        setWizardState(() {
                                          r.isEnabled = val ?? false;
                                        });
                                      },
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Icon(
                                        r.title.toLowerCase().contains('estudo')
                                            ? Icons.menu_book
                                            : r.title.toLowerCase().contains('revisita')
                                                ? Icons.repeat
                                                : Icons.directions_walk,
                                        size: 18,
                                        color: r.isEnabled ? AppTheme.primaryBlue : Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            r.title,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              decoration: r.isEnabled ? null : TextDecoration.lineThrough,
                                              color: r.isEnabled ? null : Colors.grey,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '$weekdayName às $timeStr (${r.durationMinutes} min) • $freqLabel',
                                            style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : AppTheme.textMuted),
                                          ),
                                          const SizedBox(height: 4),
                                          Wrap(
                                            spacing: 6,
                                            children: [
                                              if (freeCount > 0 && r.isEnabled)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.successGreen.withValues(alpha: 0.15),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    '✅ $freeCount data(s) a criar',
                                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.successGreen),
                                                  ),
                                                ),
                                              if (alreadyExistsCount > 0 && r.isEnabled)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.alertAmber.withValues(alpha: 0.15),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    '⚠️ $alreadyExistsCount data(s) já existente(s)',
                                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.alertAmber),
                                                  ),
                                                ),
                                              if (!r.isEnabled)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey.withValues(alpha: 0.15),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: const Text(
                                                    'Desmarcado para este mês',
                                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(r.isExpanded ? Icons.expand_less : Icons.tune, size: 18),
                                      tooltip: r.isExpanded ? 'Fechar detalhes' : 'Alterar dia, hora, frequência...',
                                      color: r.isExpanded ? AppTheme.primaryBlue : AppTheme.textMuted,
                                      onPressed: () {
                                        setWizardState(() {
                                          r.isExpanded = !r.isExpanded;
                                        });
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.alertRed),
                                      tooltip: 'Excluir esta rotina',
                                      onPressed: () {
                                        setWizardState(() {
                                          wizardRoutines.remove(r);
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),

                              // Painel expansível de customização detalhada
                              if (r.isExpanded) ...[
                                const Divider(height: 1),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Personalizar Programação para o Mês de Destino:',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: DropdownButtonFormField<int>(
                                              initialValue: r.weekday,
                                              decoration: const InputDecoration(labelText: 'Dia da Semana', isDense: true),
                                              items: List.generate(7, (i) {
                                                return DropdownMenuItem(value: i + 1, child: Text(weekdayLabels[i], style: const TextStyle(fontSize: 12)));
                                              }),
                                              onChanged: (val) {
                                                if (val != null) {
                                                  setWizardState(() => r.weekday = val);
                                                }
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: InkWell(
                                              onTap: () async {
                                                final picked = await showTimePicker(
                                                  context: context,
                                                  initialTime: TimeOfDay(hour: r.hour, minute: r.minute),
                                                );
                                                if (picked != null) {
                                                  setWizardState(() {
                                                    r.hour = picked.hour;
                                                    r.minute = picked.minute;
                                                  });
                                                }
                                              },
                                              child: InputDecorator(
                                                decoration: const InputDecoration(labelText: 'Horário', isDense: true),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Text(timeStr, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                                    const Icon(Icons.access_time, size: 16, color: AppTheme.primaryBlue),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            flex: 3,
                                            child: DropdownButtonFormField<String>(
                                              initialValue: r.frequency,
                                              decoration: const InputDecoration(labelText: 'Frequência do Estudo/Revisita', isDense: true),
                                              items: const [
                                                DropdownMenuItem(value: 'semanal', child: Text('Semanal (Toda semana)', style: TextStyle(fontSize: 12))),
                                                DropdownMenuItem(value: 'quinzenal_1_3', child: Text('Quinzenal (1ª e 3ª semana)', style: TextStyle(fontSize: 12))),
                                                DropdownMenuItem(value: 'quinzenal_2_4', child: Text('Quinzenal (2ª e 4ª semana)', style: TextStyle(fontSize: 12))),
                                                DropdownMenuItem(value: 'mensal', child: Text('Mensal (1ª ocorrência)', style: TextStyle(fontSize: 12))),
                                                DropdownMenuItem(value: '2x_semana', child: Text('2x por semana', style: TextStyle(fontSize: 12))),
                                              ],
                                              onChanged: (val) {
                                                if (val != null) {
                                                  setWizardState(() => r.frequency = val);
                                                }
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            flex: 2,
                                            child: DropdownButtonFormField<int>(
                                              initialValue: r.durationMinutes,
                                              decoration: const InputDecoration(labelText: 'Duração', isDense: true),
                                              items: const [
                                                DropdownMenuItem(value: 15, child: Text('15 min', style: TextStyle(fontSize: 12))),
                                                DropdownMenuItem(value: 20, child: Text('20 min', style: TextStyle(fontSize: 12))),
                                                DropdownMenuItem(value: 30, child: Text('30 min', style: TextStyle(fontSize: 12))),
                                                DropdownMenuItem(value: 45, child: Text('45 min', style: TextStyle(fontSize: 12))),
                                                DropdownMenuItem(value: 60, child: Text('60 min', style: TextStyle(fontSize: 12))),
                                                DropdownMenuItem(value: 90, child: Text('90 min', style: TextStyle(fontSize: 12))),
                                                DropdownMenuItem(value: 120, child: Text('120 min', style: TextStyle(fontSize: 12))),
                                              ],
                                              onChanged: (val) {
                                                if (val != null) {
                                                  setWizardState(() => r.durationMinutes = val);
                                                }
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (r.frequency == '2x_semana') ...[
                                        const SizedBox(height: 8),
                                        DropdownButtonFormField<int>(
                                          initialValue: r.secondWeekday,
                                          decoration: const InputDecoration(labelText: 'Segundo Dia da Semana (para 2x/semana)', isDense: true),
                                          items: List.generate(7, (i) {
                                            return DropdownMenuItem(value: i + 1, child: Text(weekdayLabels[i], style: const TextStyle(fontSize: 12)));
                                          }),
                                          onChanged: (val) {
                                            if (val != null) {
                                              setWizardState(() => r.secondWeekday = val);
                                            }
                                          },
                                        ),
                                      ],
                                      const SizedBox(height: 8),
                                      Text(
                                        'Datas calculadas para ${_getMonthName(targetMonth)}: '
                                        '${targetDates.map((d) => "${d.day.toString().padLeft(2, "0")}/${d.month.toString().padLeft(2, "0")}").join(", ")}',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.check, size: 16),
                label: Text('Replicar e Agendar ($totalPendingToCreate novos)'),
                onPressed: totalPendingToCreate == 0 && wizardRoutines.every((r) => !r.isEnabled)
                    ? null
                    : () async {
                        final repo = ref.read(repositoryProvider);
                        int totalCreated = 0;
                        int totalSkipped = 0;

                        for (final r in wizardRoutines.where((r) => r.isEnabled)) {
                          final dates = calculateRoutineDates(r);
                          for (final targetDt in dates) {
                            final hasDuplicate = targetExistingAppts.any((existing) {
                              final sameTitle = existing.title.trim().toLowerCase() == r.title.trim().toLowerCase();
                              final timeDiff = existing.startTime.difference(targetDt).inMinutes.abs();
                              return sameTitle && timeDiff < 15;
                            });

                            if (hasDuplicate) {
                              totalSkipped++;
                              continue;
                            }

                            await repo.createAppointment(
                              personId: r.personId,
                              title: r.title,
                              startTime: targetDt,
                              endTime: targetDt.add(Duration(minutes: r.durationMinutes)),
                              durationMinutes: r.durationMinutes,
                              status: 'confirmado',
                              locationNotes: r.notes,
                            );
                            totalCreated++;
                          }
                        }

                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                totalCreated > 0
                                    ? 'Programação replicada com sucesso! $totalCreated compromisso(s) criado(s) em ${_getMonthName(targetMonth)}.'
                                    : 'Nenhum novo compromisso criado ($totalSkipped já agendados).',
                              ),
                            ),
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

  void _showFieldMinistryScheduleModal(BuildContext context) {
    DateTime chosenDate = _selectedDate;
    TimeOfDay chosenTime = const TimeOfDay(hour: 9, minute: 0);
    int durationMinutes = 120; // 2 horas padrão
    String modality = 'De Casa em Casa';
    final locationController = TextEditingController();
    String recurrence = 'Toda semana';
    int recurrenceCount = 8;
    bool respectAvailability = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final start = DateTime(chosenDate.year, chosenDate.month, chosenDate.day, chosenTime.hour, chosenTime.minute);
          final existingAppts = ref.read(appointmentsStreamProvider).value ?? [];
          final availability = AvailabilityEngine.checkAvailability(
            startTime: start,
            durationMinutes: durationMinutes,
            existingAppointments: existingAppts,
          );

          final occurrences = <DateTime>[start];
          if (recurrence != 'Único') {
            for (int i = 1; i < recurrenceCount; i++) {
              if (recurrence == 'Toda semana') {
                occurrences.add(start.add(Duration(days: i * 7)));
              } else if (recurrence == 'A cada 15 dias') {
                occurrences.add(start.add(Duration(days: i * 14)));
              } else if (recurrence == 'Mensal') {
                final targetMonth = start.month + i;
                final yearOffset = (targetMonth - 1) ~/ 12;
                final month = ((targetMonth - 1) % 12) + 1;
                final year = start.year + yearOffset;
                final daysInMonth = DateTime(year, month + 1, 0).day;
                final day = start.day.clamp(1, daysInMonth);
                occurrences.add(DateTime(year, month, day, start.hour, start.minute));
              }
            }
          }

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.alarm_add, color: AppTheme.primaryBlue),
                SizedBox(width: 8),
                Text('Programar Serviço de Campo'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: modality,
                    decoration: const InputDecoration(labelText: 'Modalidade de Testemunho'),
                    items: const [
                      DropdownMenuItem(value: 'De Casa em Casa', child: Text('🏠 De Casa em Casa')),
                      DropdownMenuItem(value: 'Testemunho Público (Carrinho)', child: Text('🛒 Testemunho Público (Carrinho)')),
                      DropdownMenuItem(value: 'Testemunho Informal', child: Text('💬 Testemunho Informal')),
                      DropdownMenuItem(value: 'Cartas e Telefone', child: Text('✉️ Cartas e Telefone')),
                      DropdownMenuItem(value: 'Outro', child: Text('📌 Outro')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => modality = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.date_range, size: 16),
                        label: Text(AppDateUtils.formatDate(chosenDate)),
                        onPressed: () async {
                          final p = await showDatePicker(
                            context: context,
                            initialDate: chosenDate,
                            firstDate: DateTime.now().subtract(const Duration(days: 30)),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (p != null) setDialogState(() => chosenDate = p);
                        },
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.access_time, size: 16),
                        label: Text('${chosenTime.hour.toString().padLeft(2, '0')}:${chosenTime.minute.toString().padLeft(2, '0')}'),
                        onPressed: () async {
                          final t = await showTimePicker(
                            context: context,
                            initialTime: chosenTime,
                          );
                          if (t != null) setDialogState(() => chosenTime = t);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: durationMinutes,
                    decoration: const InputDecoration(labelText: 'Duração Prevista'),
                    items: const [
                      DropdownMenuItem(value: 60, child: Text('1 hora (60 min)')),
                      DropdownMenuItem(value: 90, child: Text('1h 30m (90 min)')),
                      DropdownMenuItem(value: 120, child: Text('2 horas (120 min)')),
                      DropdownMenuItem(value: 150, child: Text('2h 30m (150 min)')),
                      DropdownMenuItem(value: 180, child: Text('3 horas (180 min)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => durationMinutes = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: recurrence,
                    decoration: const InputDecoration(labelText: 'Repetição / Recorrência'),
                    items: const [
                      DropdownMenuItem(value: 'Único', child: Text('Apenas esta data (Único)')),
                      DropdownMenuItem(value: 'Toda semana', child: Text('Toda semana (Semanal)')),
                      DropdownMenuItem(value: 'A cada 15 dias', child: Text('A cada 15 dias (Quinzenal)')),
                      DropdownMenuItem(value: 'Mensal', child: Text('Mensal (a cada 4 semanas)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => recurrence = val);
                    },
                  ),
                  if (recurrence != 'Único') ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: recurrenceCount,
                      decoration: const InputDecoration(labelText: 'Quantidade de ocorrências'),
                      items: const [
                        DropdownMenuItem(value: 4, child: Text('4 semanas (1 mês)')),
                        DropdownMenuItem(value: 8, child: Text('8 semanas (2 meses)')),
                        DropdownMenuItem(value: 12, child: Text('12 semanas (3 meses)')),
                        DropdownMenuItem(value: 16, child: Text('16 semanas (4 meses)')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => recurrenceCount = val);
                      },
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Respeitar disponibilidade da agenda', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Pula automaticamente horários conflitantes via AvailabilityEngine', style: TextStyle(fontSize: 11)),
                      value: respectAvailability,
                      onChanged: (val) => setDialogState(() => respectAvailability = val),
                    ),
                  ],
                  const SizedBox(height: 10),
                  TextField(
                    controller: locationController,
                    decoration: const InputDecoration(
                      labelText: 'Ponto de Encontro / Território',
                      hintText: 'Ex: Salão do Reino / Praça Central / Setor 03',
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: availability.isAvailable ? AppTheme.successGreen.withValues(alpha: 0.1) : AppTheme.alertAmber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: availability.isAvailable ? AppTheme.successGreen : AppTheme.alertAmber,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          availability.isAvailable ? Icons.check_circle : Icons.warning_amber,
                          color: availability.isAvailable ? AppTheme.successGreen : AppTheme.alertAmber,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            availability.message,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: availability.isAvailable ? AppTheme.successGreen : const Color(0xFF92400E),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () async {
                  final repo = ref.read(repositoryProvider);
                  int createdCount = 0;
                  int skippedCount = 0;
                  final runningAppts = List<AppointmentEntry>.from(existingAppts);

                  for (final occ in occurrences) {
                    final occEnd = occ.add(Duration(minutes: durationMinutes));
                    final hasConflict = AvailabilityEngine.hasCollision(
                      start: occ,
                      end: occEnd,
                      existingAppointments: runningAppts,
                    );

                    if (hasConflict && respectAvailability && occurrences.length > 1) {
                      skippedCount++;
                      continue;
                    }

                    final newEntry = await repo.createAppointment(
                      title: 'Saída de Campo ($modality)',
                      startTime: occ,
                      endTime: occEnd,
                      durationMinutes: durationMinutes,
                      status: 'confirmado',
                      locationNotes: locationController.text.trim().isEmpty ? null : locationController.text.trim(),
                    );
                    runningAppts.add(newEntry);
                    createdCount++;
                  }

                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    final message = occurrences.length == 1
                        ? 'Saída de campo programada com sucesso!'
                        : '$createdCount saídas de campo programadas!${skippedCount > 0 ? " ($skippedCount puladas por conflito)" : ""}';
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(message)),
                    );
                  }
                },
                child: const Text('Programar Saída'),
              ),
            ],
          );
        },
      ),
    );
  }

  // 1. Visão de Calendário Mensal Google Calendar Style
  Widget _buildMonthCalendarView(List<AppointmentEntry> allAppts) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final year = _selectedDate.year;
    final month = _selectedDate.month;
    final firstDayOfMonth = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final startingWeekday = firstDayOfMonth.weekday % 7; // 0 = Domingo, 1 = Segunda...

    final Map<int, List<AppointmentEntry>> apptsByDay = {};
    for (final a in allAppts) {
      if (a.deletedAt == null && a.startTime.year == year && a.startTime.month == month) {
        apptsByDay.putIfAbsent(a.startTime.day, () => []).add(a);
      }
    }

    final selectedDayAppts = apptsByDay[_selectedDate.day] ?? [];

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabeçalho dos dias da semana
              Container(
                color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    const Expanded(child: Center(child: Text('DOM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.alertRed)))),
                    Expanded(child: Center(child: Text('SEG', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? const Color(0xFFCBD5E1) : AppTheme.textMuted)))),
                    Expanded(child: Center(child: Text('TER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? const Color(0xFFCBD5E1) : AppTheme.textMuted)))),
                    Expanded(child: Center(child: Text('QUA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? const Color(0xFFCBD5E1) : AppTheme.textMuted)))),
                    Expanded(child: Center(child: Text('QUI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? const Color(0xFFCBD5E1) : AppTheme.textMuted)))),
                    Expanded(child: Center(child: Text('SEX', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? const Color(0xFFCBD5E1) : AppTheme.textMuted)))),
                    Expanded(child: Center(child: Text('SÁB', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? const Color(0xFF93C5FD) : AppTheme.primaryBlue)))),
                  ],
                ),
              ),

              // Grade 7 colunas Google Calendar Style
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisExtent: 72,
                  crossAxisSpacing: 3,
                  mainAxisSpacing: 3,
                ),
                itemCount: 42,
                itemBuilder: (context, index) {
                  final dayNumber = index - startingWeekday + 1;
                  final isCurrentMonth = dayNumber >= 1 && dayNumber <= daysInMonth;

                  if (!isCurrentMonth) {
                    return const SizedBox.shrink();
                  }

                  final cellDate = DateTime(year, month, dayNumber);
                  final isSelected = cellDate.day == _selectedDate.day && cellDate.month == _selectedDate.month && cellDate.year == _selectedDate.year;
                  final isToday = cellDate.day == DateTime.now().day && cellDate.month == DateTime.now().month && cellDate.year == DateTime.now().year;
                  final dayAppts = apptsByDay[dayNumber] ?? [];

                  return InkWell(
                    onTap: () {
                      setState(() => _selectedDate = cellDate);
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDark ? const Color(0xFF3B82F6).withValues(alpha: 0.25) : AppTheme.primaryBlue.withValues(alpha: 0.12))
                            : (isDark ? const Color(0xFF1E293B) : Colors.white),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSelected
                              ? (isDark ? const Color(0xFF60A5FA) : AppTheme.primaryBlue)
                              : isToday
                                  ? AppTheme.accentTeal
                                  : (isDark ? const Color(0xFF334155) : Colors.grey.shade200),
                          width: isSelected || isToday ? 2.0 : 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: isToday
                                    ? BoxDecoration(color: isDark ? const Color(0xFF3B82F6) : AppTheme.primaryBlue, borderRadius: BorderRadius.circular(8))
                                    : null,
                                child: Text(
                                  '$dayNumber',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.w600,
                                    color: isToday
                                        ? Colors.white
                                        : (index % 7 == 0 ? AppTheme.alertRed : (isDark ? Colors.white : AppTheme.textDark)),
                                  ),
                                ),
                              ),
                              if (dayAppts.length > 2)
                                Text(
                                  '+${dayAppts.length - 2}',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          for (final a in dayAppts.take(2)) ...[
                            Builder(
                              builder: (context) {
                                final color = _getAppointmentActivityColor(a);
                                final timeStr = AppDateUtils.formatTime(a.startTime);
                                return Container(
                                  margin: const EdgeInsets.only(top: 2),
                                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: isDark ? 0.35 : 0.15),
                                    borderRadius: BorderRadius.circular(3),
                                    border: Border.all(color: color.withValues(alpha: 0.6), width: 0.6),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        timeStr,
                                        style: TextStyle(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? color.withValues(alpha: 0.95) : color,
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      Expanded(
                                        child: Text(
                                          a.title,
                                          style: TextStyle(
                                            fontSize: 8.5,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.white : AppTheme.textDark,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),

              const Divider(height: 1),

              // Painel Inferior: Lista de compromissos do dia selecionado
              Container(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Compromissos em ${AppDateUtils.formatDate(_selectedDate)}',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : AppTheme.textDark),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Novo', style: TextStyle(fontSize: 12)),
                          onPressed: () => _showNewAppointmentModal(context, initialDateTime: _selectedDate),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (selectedDayAppts.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey.shade200),
                        ),
                        child: const Center(
                          child: Text(
                            'Nenhum compromisso agendado para esta data.',
                            style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                          ),
                        ),
                      )
                    else
                      ...selectedDayAppts.map((appt) {
                        final isDone = appt.status == 'realizado';
                        final color = _getAppointmentActivityColor(appt);

                        return Card(
                          elevation: 1,
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
                            ),
                          ),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: isDark ? 0.25 : 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: color.withValues(alpha: 0.5)),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    AppDateUtils.formatTime(appt.startTime),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: color,
                                    ),
                                  ),
                                  Text(
                                    '${appt.durationMinutes}m',
                                    style: TextStyle(fontSize: 9, color: isDark ? const Color(0xFFCBD5E1) : AppTheme.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            title: Text(
                              appt.title,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                decoration: isDone ? TextDecoration.lineThrough : null,
                              ),
                            ),
                            subtitle: Text(
                              appt.locationNotes ?? 'Status: ${appt.status}',
                              style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : AppTheme.textMuted),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.more_vert, size: 20),
                              onPressed: () => _showAppointmentActions(context, appt),
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 2. Visão de Calendário Semanal
  Widget _buildWeekCalendarView(List<AppointmentEntry> allAppts) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final monday = _selectedDate.subtract(Duration(days: (_selectedDate.weekday - 1) % 7));
    final weekDays = List.generate(7, (i) => monday.add(Duration(days: i)));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
      itemCount: 7,
      itemBuilder: (context, index) {
        final day = weekDays[index];
        final isToday = day.day == DateTime.now().day && day.month == DateTime.now().month && day.year == DateTime.now().year;
        final dayAppts = allAppts.where((a) =>
            a.deletedAt == null &&
            a.startTime.year == day.year &&
            a.startTime.month == day.month &&
            a.startTime.day == day.day).toList()..sort((a, b) => a.startTime.compareTo(b.startTime));

        const weekdayNames = ['Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo'];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isToday ? AppTheme.accentTeal : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              width: isToday ? 2.0 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isToday
                      ? (isDark ? const Color(0xFF3B82F6).withValues(alpha: 0.25) : AppTheme.primaryBlue.withValues(alpha: 0.1))
                      : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${weekdayNames[index]} • ${AppDateUtils.formatDate(day)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isToday ? AppTheme.primaryBlue : (isDark ? Colors.white : AppTheme.textDark),
                      ),
                    ),
                    Text(
                      '${dayAppts.length} compromisso(s)',
                      style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              if (dayAppts.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Nenhum compromisso', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                )
              else
                ...dayAppts.map((appt) {
                  final color = _getAppointmentActivityColor(appt);
                  return ListTile(
                    dense: true,
                    leading: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: isDark ? 0.3 : 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        AppDateUtils.formatTime(appt.startTime),
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: color),
                      ),
                    ),
                    title: Text(appt.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    subtitle: appt.locationNotes != null ? Text(appt.locationNotes!, style: const TextStyle(fontSize: 11)) : null,
                    trailing: IconButton(
                      icon: const Icon(Icons.more_vert, size: 18),
                      onPressed: () => _showAppointmentActions(context, appt),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  // 3. Visão de Calendário Diário por Hora
  Widget _buildDayHourlyGridView(List<AppointmentEntry> allAppts) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dayAppts = allAppts.where((a) =>
        a.deletedAt == null &&
        a.startTime.year == _selectedDate.year &&
        a.startTime.month == _selectedDate.month &&
        a.startTime.day == _selectedDate.day).toList();

    return SingleChildScrollView(
      controller: _timeScrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            children: List.generate(16, (i) {
              final hour = 7 + i; // 07:00 às 22:00
              final hourStart = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, hour, 0);
              final hourEnd = hourStart.add(const Duration(hours: 1));

              final inThisHour = dayAppts.where((a) =>
                  a.startTime.isBefore(hourEnd) && a.endTime.isAfter(hourStart)).toList();

              return Container(
                height: 60,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 50,
                      child: Text(
                        '${hour.toString().padLeft(2, '0')}:00',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF94A3B8) : AppTheme.textMuted),
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: inThisHour.isEmpty
                          ? InkWell(
                              onTap: () {
                                _showNewAppointmentModal(
                                  context,
                                  initialDateTime: DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, hour, 0),
                                );
                              },
                              child: const SizedBox.expand(),
                            )
                          : ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: inThisHour.length,
                              itemBuilder: (ctx, idx) {
                                final appt = inThisHour[idx];
                                final color = _getAppointmentActivityColor(appt);
                                return InkWell(
                                  onTap: () => _showAppointmentActions(context, appt),
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: isDark ? 0.35 : 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: color.withValues(alpha: 0.6)),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${AppDateUtils.formatTime(appt.startTime)} ${appt.title}',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white : color),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  // 4. Visão em Lista Linear
  Widget _buildListView(List<AppointmentEntry> allAppts) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeAppts = allAppts.where((a) => a.deletedAt == null && a.status != 'cancelado').toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    if (activeAppts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.event_note, size: 56, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              const Text(
                'Nenhum compromisso cadastrado na agenda.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textMuted, fontSize: 15),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
      itemCount: activeAppts.length,
      itemBuilder: (context, index) {
        final appt = activeAppts[index];
        final isDone = appt.status == 'realizado';
        final color = _getAppointmentActivityColor(appt);

        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.3 : 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: color.withValues(alpha: 0.5)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    AppDateUtils.formatTime(appt.startTime),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: color,
                    ),
                  ),
                  Text(
                    '${appt.durationMinutes}m',
                    style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            title: Text(
              appt.title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                decoration: isDone ? TextDecoration.lineThrough : null,
              ),
            ),
            subtitle: Text(
              '${AppDateUtils.formatDate(appt.startTime)} • ${appt.locationNotes ?? appt.status}',
              style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : AppTheme.textMuted),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.more_vert, size: 20),
              onPressed: () => _showAppointmentActions(context, appt),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appointmentsAsync = ref.watch(appointmentsStreamProvider);
    final activitiesAsync = ref.watch(activitiesStreamProvider);
    final peopleAsync = ref.watch(peopleStreamProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final passedPersonIds = (peopleAsync.value ?? []).where((p) => p.status == 'revisita_passada').map((p) => p.id).toSet();
    final allAppts = (appointmentsAsync.value ?? []).where((a) => a.personId == null || !passedPersonIds.contains(a.personId)).toList();
    final allActivities = activitiesAsync.value ?? [];

    final monthActivities = allActivities.where((a) =>
        a.deletedAt == null &&
        a.date.year == _selectedDate.year &&
        a.date.month == _selectedDate.month).toList();
    final actualHours = monthActivities.fold(0.0, (acc, a) => acc + (a.durationSeconds / 3600.0));

    final monthAppts = allAppts.where((a) =>
        a.deletedAt == null &&
        a.status != 'cancelado' &&
        a.startTime.year == _selectedDate.year &&
        a.startTime.month == _selectedDate.month).toList();
    final scheduledHours = monthAppts.where(isMinistryAppointment).fold(0.0, (acc, a) => acc + (a.durationMinutes / 60.0));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda do Ministério'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: MediaQuery.of(context).size.width < 500
                ? IconButton(
                    icon: const Icon(Icons.sync_alt),
                    tooltip: 'Sincronizar Calendários (Google / iCloud / .ics)',
                    onPressed: () => _showOfficialCalendarSyncModal(context, allAppts),
                  )
                : FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    ),
                    icon: const Icon(Icons.sync_alt, size: 16),
                    label: const Text('Sincronizar Calendários', style: TextStyle(fontSize: 12)),
                    onPressed: () => _showOfficialCalendarSyncModal(context, allAppts),
                  ),
          ),
          IconButton(
            icon: const Icon(Icons.today),
            tooltip: 'Hoje',
            onPressed: () {
              setState(() => _selectedDate = DateTime.now());
              _scrollToCurrentTime();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_novo_compromisso',
        backgroundColor: isDark ? const Color(0xFF3B82F6) : AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Novo Compromisso'),
        onPressed: () => _showNewAppointmentModal(context),
      ),
      body: Column(
        children: [
          // Banner Elegante de Sincronização de Calendários
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.sync, size: 16, color: AppTheme.primaryBlue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Sincronizar com Google Agenda & Apple (.ics)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFF93C5FD) : AppTheme.primaryBlue,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      icon: const Icon(Icons.sync_alt, size: 14),
                      label: const Text('Configurar / Importar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: () => _showOfficialCalendarSyncModal(context, allAppts),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 1),

          // Barra de controles de visualização (Mês, Semana, Dia, Lista)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 460;
                    final navRow = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            setState(() {
                              if (_viewMode == 'Mês') {
                                _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1, _selectedDate.day.clamp(1, 28));
                              } else if (_viewMode == 'Semana') {
                                _selectedDate = _selectedDate.subtract(const Duration(days: 7));
                              } else {
                                _selectedDate = _selectedDate.subtract(const Duration(days: 1));
                              }
                            });
                          },
                        ),
                        Text(
                          _viewMode == 'Mês'
                              ? '${_getMonthName(_selectedDate.month)} ${_selectedDate.year}'
                              : AppDateUtils.formatDate(_selectedDate),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isDark ? Colors.white : AppTheme.textDark,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            setState(() {
                              if (_viewMode == 'Mês') {
                                _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1, _selectedDate.day.clamp(1, 28));
                              } else if (_viewMode == 'Semana') {
                                _selectedDate = _selectedDate.add(const Duration(days: 7));
                              } else {
                                _selectedDate = _selectedDate.add(const Duration(days: 1));
                              }
                            });
                          },
                        ),
                      ],
                    );

                    final segButton = SegmentedButton<String>(
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      segments: const [
                        ButtonSegment(value: 'Mês', label: Text('Mês', style: TextStyle(fontSize: 12))),
                        ButtonSegment(value: 'Semana', label: Text('Semana', style: TextStyle(fontSize: 12))),
                        ButtonSegment(value: 'Dia', label: Text('Dia', style: TextStyle(fontSize: 12))),
                        ButtonSegment(value: 'Lista', label: Text('Lista', style: TextStyle(fontSize: 12))),
                      ],
                      selected: {_viewMode},
                      onSelectionChanged: (val) {
                        setState(() => _viewMode = val.first);
                        if (_viewMode == 'Dia') {
                          WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrentTime());
                        }
                      },
                    );

                    if (isNarrow) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              navRow,
                              IconButton(
                                icon: const Icon(Icons.today, size: 20),
                                tooltip: 'Hoje',
                                visualDensity: VisualDensity.compact,
                                onPressed: () {
                                  setState(() => _selectedDate = DateTime.now());
                                  _scrollToCurrentTime();
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          SizedBox(width: double.infinity, child: segButton),
                        ],
                      );
                    }

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        navRow,
                        segButton,
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          const Divider(height: 1),

          // Comparativo Horas Programadas vs Horas Efetivas Realizadas
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: Row(
                  children: [
                    const Icon(Icons.av_timer, size: 18, color: AppTheme.primaryBlue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Programado: ${scheduledHours.toStringAsFixed(1)}h  •  Efetivo: ${actualHours.toStringAsFixed(1)}h${scheduledHours > 0 ? " (${((actualHours / scheduledHours) * 100).toStringAsFixed(0)}% realizado)" : ""}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Wrap(
                      spacing: 6,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.copy_all_outlined, size: 15),
                          label: const Text('Copiar Programação', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          onPressed: () => _showMonthlyScheduleCopyWizard(context, allAppts),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.alarm_add, size: 15),
                          label: const Text('Programar Campo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          onPressed: () => _showFieldMinistryScheduleModal(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 1),

          // Área de visualização do calendário
          Expanded(
            child: appointmentsAsync.when(
              data: (appts) {
                final activeAppts = appts.where((a) => a.personId == null || !passedPersonIds.contains(a.personId)).toList();
                if (_viewMode == 'Mês') {
                  return _buildMonthCalendarView(activeAppts);
                } else if (_viewMode == 'Semana') {
                  return _buildWeekCalendarView(activeAppts);
                } else if (_viewMode == 'Dia') {
                  return _buildDayHourlyGridView(activeAppts);
                } else {
                  return _buildListView(activeAppts);
                }
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Erro: $err')),
            ),
          ),
        ],
      ),
    );
  }
}
