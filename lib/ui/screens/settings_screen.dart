import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../appointments/calendar_sync_coordinator.dart';
import '../../database/app_database.dart';
import '../../inbox/jw_email_service.dart';
import '../../sync/supabase_sync_service.dart';
import 'auth_splash_screen.dart';

import '../../core/app_theme.dart';
import '../../core/app_version.dart';
import '../../core/date_utils.dart';
import '../../core/demo_data.dart';
import '../../core/update_checker_service.dart';
import '../../core/i18n/app_locale_strings.dart';
import '../providers.dart';
import 'activities_screen.dart';
import 'trash_screen.dart';
import 'customize_features_screen.dart';
import 'connected_calendars_screen.dart';
import 'appointments_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  DateTime? _lastBackupAt;
  String? _googleAccountEmail;
  bool _isGoogleConnected = false;
  final TextEditingController _jwEmailCtrl = TextEditingController();
  final TextEditingController _jwPasswordCtrl = TextEditingController();
  final TextEditingController _jwHostCtrl = TextEditingController(text: 'mail.jw.org');
  final TextEditingController _jwPortCtrl = TextEditingController(text: '993');
  bool _isTestingJwEmail = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      ref.read(backupServiceProvider).performSilentBackupIfNeeded();
      await _loadGoogleStatus();
      await _loadJwEmailConfig();
    });
  }

  @override
  void dispose() {
    _jwEmailCtrl.dispose();
    _jwPasswordCtrl.dispose();
    _jwHostCtrl.dispose();
    _jwPortCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadGoogleStatus() async {
    try {
      final coordinator = ref.read(calendarSyncCoordinatorProvider);
      final isAuth = await coordinator.googleProvider.isAuthorized();
      final account = await coordinator.googleProvider.getConnectedAccountName();
      if (mounted) {
        setState(() {
          _isGoogleConnected = isAuth;
          _googleAccountEmail = account;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadJwEmailConfig() async {
    try {
      final db = ref.read(repositoryProvider).db;
      final email = await (db.select(db.appKvStore)..where((t) => t.key.equals('jw_imap_email'))).getSingleOrNull();
      final pass = await (db.select(db.appKvStore)..where((t) => t.key.equals('jw_imap_password'))).getSingleOrNull();
      final host = await (db.select(db.appKvStore)..where((t) => t.key.equals('jw_imap_host'))).getSingleOrNull();
      final port = await (db.select(db.appKvStore)..where((t) => t.key.equals('jw_imap_port'))).getSingleOrNull();

      if (mounted) {
        setState(() {
          if (email != null) _jwEmailCtrl.text = email.value;
          if (pass != null) _jwPasswordCtrl.text = pass.value;
          if (host != null && host.value.isNotEmpty) _jwHostCtrl.text = host.value;
          if (port != null && port.value.isNotEmpty) _jwPortCtrl.text = port.value;
        });
      }
    } catch (_) {}
  }

  // Modal para cadastro de Eventos Teocráticos e Datas Especiais
  void _showAddTheocraticEventDialog(BuildContext context) {
    String selectedType = 'Visita do Superintendente de Circuito';
    final titleController = TextEditingController();
    final locationController = TextEditingController();
    DateTime startDate = DateTime.now().add(const Duration(days: 7));
    TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
    DateTime endDate = startDate;
    TimeOfDay endTime = const TimeOfDay(hour: 16, minute: 30);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.event_available, color: Color(0xFF7C3AED)),
                SizedBox(width: 8),
                Expanded(child: Text('Cadastrar Evento Teocrático')),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cadastre datas especiais para inserção automática no calendário oficial e sincronização.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? const Color(0xFFCBD5E1)
                          : AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: selectedType,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de Evento Teocrático *',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Visita do Superintendente de Circuito',
                        child: Text('Visita do Superintendente de Circuito'),
                      ),
                      DropdownMenuItem(
                        value: 'Assembleia de Circuito',
                        child: Text('Assembleia de Circuito'),
                      ),
                      DropdownMenuItem(
                        value: 'Congresso Regional',
                        child: Text('Congresso Regional'),
                      ),
                      DropdownMenuItem(
                        value: 'Celebração da Morte de Cristo',
                        child: Text('Celebração da Morte de Cristo'),
                      ),
                      DropdownMenuItem(
                        value: 'Reunião Especial',
                        child: Text('Reunião Especial'),
                      ),
                      DropdownMenuItem(
                        value: 'Dia Especial de Testemunho',
                        child: Text('Dia Especial de Testemunho'),
                      ),
                      DropdownMenuItem(
                        value: 'Outro Evento Teocrático',
                        child: Text('Outro Evento Teocrático'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedType = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Tema / Título complementar (opcional)',
                      hintText: 'Ex: Seja Corajoso! ou Tema da Visita',
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Data e Horário de Início:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(
                            AppDateUtils.formatDate(startDate),
                            style: const TextStyle(fontSize: 12),
                          ),
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: startDate,
                              firstDate: DateTime.now().subtract(
                                const Duration(days: 30),
                              ),
                              lastDate: DateTime.now().add(
                                const Duration(days: 730),
                              ),
                            );
                            if (d != null) {
                              setDialogState(() {
                                startDate = d;
                                if (endDate.isBefore(d)) endDate = d;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.access_time, size: 16),
                          label: Text(
                            '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          onPressed: () async {
                            final t = await showTimePicker(
                              context: context,
                              initialTime: startTime,
                            );
                            if (t != null) setDialogState(() => startTime = t);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Data e Horário de Término:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(
                            AppDateUtils.formatDate(endDate),
                            style: const TextStyle(fontSize: 12),
                          ),
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: endDate,
                              firstDate: startDate,
                              lastDate: DateTime.now().add(
                                const Duration(days: 730),
                              ),
                            );
                            if (d != null) setDialogState(() => endDate = d);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.access_time, size: 16),
                          label: Text(
                            '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          onPressed: () async {
                            final t = await showTimePicker(
                              context: context,
                              initialTime: endTime,
                            );
                            if (t != null) setDialogState(() => endTime = t);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: locationController,
                    decoration: const InputDecoration(
                      labelText: 'Local / Salão / Anotações',
                      hintText: 'Ex: Salão de Assembleias, Salão do Reino, JW Stream...',
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
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final startDateTime = DateTime(
                    startDate.year,
                    startDate.month,
                    startDate.day,
                    startTime.hour,
                    startTime.minute,
                  );
                  final endDateTime = DateTime(
                    endDate.year,
                    endDate.month,
                    endDate.day,
                    endTime.hour,
                    endTime.minute,
                  );

                  int durationMins = endDateTime
                      .difference(startDateTime)
                      .inMinutes;
                  if (durationMins <= 0) durationMins = 120;

                  final extra = titleController.text.trim();
                  final fullTitle =
                      '[Evento Teocrático] $selectedType${extra.isNotEmpty ? ": $extra" : ""}';

                  final repo = ref.read(repositoryProvider);
                  await repo.createAppointment(
                    title: fullTitle,
                    startTime: startDateTime,
                    endTime: endDateTime,
                    durationMinutes: durationMins,
                    locationNotes: locationController.text.trim().isEmpty
                        ? null
                        : locationController.text.trim(),
                    status: 'confirmado',
                  );

                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Evento "$selectedType" inserido automaticamente no calendário oficial!',
                        ),
                      ),
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

  // Modal de Exportação de Backup
  void _showExportDialog(BuildContext context) {
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        final isDarkDialog = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          title: const Text('Exportar Backup Criptografado'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Defina uma senha forte. O arquivo será criptografado com AES-256 e só poderá ser restaurado com esta senha.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDarkDialog
                      ? const Color(0xFFCBD5E1)
                      : AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(
                  labelText: 'Senha de Criptografia',
                  hintText: 'Mínimo 6 caracteres',
                ),
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final password = passwordController.text.trim();
                if (password.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'A senha deve conter ao menos 6 caracteres.',
                      ),
                    ),
                  );
                  return;
                }

                final backupService = ref.read(backupServiceProvider);
                final encryptedData = await backupService.exportEncryptedBackup(
                  password,
                );

                setState(() {
                  _lastBackupAt = DateTime.now();
                });

                if (ctx.mounted) Navigator.pop(ctx);

                // Exibe diálogo com o código criptografado pronto para copiar/salvar
                if (context.mounted) {
                  showDialog(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Backup Gerado com Sucesso!'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Copie o texto criptografado abaixo e salve-o com segurança no aplicativo Arquivos, iCloud Drive ou em seu computador:',
                            style: TextStyle(fontSize: 13),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            constraints: const BoxConstraints(maxHeight: 120),
                            child: SingleChildScrollView(
                              child: SelectableText(
                                encryptedData,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.copy, size: 16),
                          label: const Text('Copiar Código do Backup'),
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: encryptedData),
                            );
                            Navigator.pop(c);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Backup copiado para a área de transferência!',
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                }
              },
              child: const Text('Exportar'),
            ),
          ],
        );
      },
    );
  }

  // Modal de Restauração com Prévia e Confirmação
  void _showRestoreDialog(BuildContext context) {
    final dataController = TextEditingController();
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restaurar Backup Criptografado'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: dataController,
                decoration: const InputDecoration(
                  labelText: 'Cole o código criptografado do backup',
                  hintText: '{"iv":"...","ciphertext":"..."}',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(
                  labelText: 'Senha utilizada na exportação',
                ),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final raw = dataController.text.trim();
              final pwd = passwordController.text.trim();

              if (raw.isEmpty || pwd.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Preencha os dados do backup e a senha.'),
                  ),
                );
                return;
              }

              final backupService = ref.read(backupServiceProvider);
              try {
                final preview = await backupService.previewBackup(
                  encryptedDataString: raw,
                  password: pwd,
                );

                if (ctx.mounted) Navigator.pop(ctx);

                // Exibe diálogo de Prévia de Restauração
                if (context.mounted) {
                  showDialog(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Pré-visualização da Restauração'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Registros verificados com integridade SHA-256:',
                          ),
                          const SizedBox(height: 8),
                          Text('• Novos contatos: ${preview.peopleToAdd}'),
                          Text(
                            '• Contatos a atualizar: ${preview.peopleToUpdate}',
                          ),
                          Text(
                            '• Contatos inalterados: ${preview.peopleUnchanged}',
                          ),
                          Text('• Visitas a importar: ${preview.visitsToAdd}'),
                          Text('• Estudos bíblicos: ${preview.studiesToAdd}'),
                          Text('• Sessões de estudo: ${preview.sessionsToAdd}'),
                          Text('• Compromissos: ${preview.appointmentsToAdd}'),
                          const SizedBox(height: 10),
                          const Text(
                            'A restauração é idempotente e NÃO criará contatos ou estudos duplicados.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.successGreen,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(c),
                          child: const Text('Cancelar'),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            await backupService.commitRestore(preview);
                            if (c.mounted) Navigator.pop(c);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Restauração concluída com sucesso!',
                                  ),
                                ),
                              );
                            }
                          },
                          child: const Text('Confirmar Restauração'),
                        ),
                      ],
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erro na validação do backup: $e')),
                  );
                }
              }
            },
            child: const Text('Analisar Backup'),
          ),
        ],
      ),
    );
  }

  // Modal de Inspeção da Fila de Sincronização
  void _showSyncQueueModal(BuildContext context) async {
    final repo = ref.read(repositoryProvider);
    final pendingOps = await repo.getPendingSyncOperations();

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.cloud_sync,
                  color: AppTheme.primaryBlue,
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Fila de Sincronização',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${pendingOps.length} operação(ões) aguardando sincronização com a nuvem:',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(ctx).brightness == Brightness.dark
                    ? const Color(0xFFCBD5E1)
                    : AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 12),
            if (pendingOps.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: AppTheme.successGreen,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Tudo sincronizado ou sem alterações pendentes.',
                      style: TextStyle(
                        color: Color(0xFF166534),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 250),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: pendingOps.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final op = pendingOps[index];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Chip(
                        label: Text(
                          op.operation.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        backgroundColor: op.operation == 'insert'
                            ? const Color(0xFFDCFCE7)
                            : op.operation == 'update'
                            ? const Color(0xFFFEF3C7)
                            : const Color(0xFFFEE2E2),
                      ),
                      title: Text(
                        '${op.entityType} (${op.entityId.substring(0, op.entityId.length > 8 ? 8 : op.entityId.length)}...)',
                      ),
                      subtitle: Text(
                        'Tentativas: ${op.attempts} • Criado em: ${AppDateUtils.formatDateTime(op.createdAt)}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allAppointments = ref.watch(appointmentsStreamProvider).value ?? [];
    final theocraticEvents =
        allAppointments
            .where(
              (a) =>
                  a.deletedAt == null &&
                  (a.title.startsWith('[Evento Teocrático]') ||
                      a.title.startsWith('[Evento]') ||
                      a.status == 'evento_teocratico'),
            )
            .toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));

    return Scaffold(
      appBar: AppBar(title: const Text('Configurações e Segurança')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Seção: Sincronização
          const Text(
            'Sincronização e Nuvem',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.sync, color: AppTheme.primaryBlue),
                  title: const Text('Estado da Sincronização'),
                  subtitle: const Text(
                    'Operando Local-First (Offline). Alterações gravadas localmente.',
                  ),
                  trailing: const Chip(
                    label: Text('Local-First', style: TextStyle(fontSize: 11)),
                    backgroundColor: Color(0xFFE0E7FF),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    bottom: 12,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.cloud_sync),
                      label: const Text('Verificar Fila de Sincronização'),
                      onPressed: () => _showSyncQueueModal(context),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.import_export, color: AppTheme.primaryBlue),
                  title: const Text('Importar / Exportar Calendário'),
                  subtitle: const Text('Arquivos .ics e URL de calendário.'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AppointmentsScreen(calendarToolsOnly: true),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.calendar_month,
                    color: AppTheme.primaryBlue,
                  ),
                  title: const Text('Calendários Conectados'),
                  subtitle: const Text(
                    'Google Agenda e Apple Calendário com sincronização bidirecional.',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ConnectedCalendarsScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.account_circle, color: Color(0xFF4285F4)),
                  title: const Text('Conta Google Conectada'),
                  subtitle: Text(_isGoogleConnected
                      ? 'Conectado como: ${_googleAccountEmail ?? "Conta ativa"}'
                      : 'Nenhuma conta Google conectada'),
                  trailing: _isGoogleConnected
                      ? Wrap(
                          spacing: 4,
                          children: [
                            TextButton(
                              onPressed: () async {
                                final coord = ref.read(calendarSyncCoordinatorProvider);
                                final ok = await coord.googleProvider.requestAuthorization();
                                if (ok) await _loadGoogleStatus();
                              },
                              child: const Text('Trocar'),
                            ),
                            IconButton(
                              icon: const Icon(Icons.link_off, color: Colors.redAccent),
                              tooltip: 'Desconectar Conta Google',
                              onPressed: () async {
                                final coord = ref.read(calendarSyncCoordinatorProvider);
                                await coord.googleProvider.disconnect();
                                await _loadGoogleStatus();
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Conta Google desconectada com sucesso.')),
                                );
                              },
                            ),
                          ],
                        )
                      : ElevatedButton.icon(
                          icon: const Icon(Icons.login, size: 16),
                          label: const Text('Conectar'),
                          onPressed: () async {
                            final coord = ref.read(calendarSyncCoordinatorProvider);
                            final ok = await coord.googleProvider.requestAuthorization();
                            if (ok) {
                              await _loadGoogleStatus();
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Conta Google conectada com sucesso!')),
                              );
                            }
                          },
                        ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Seção: E-mail Teocrático e JW Pub (IMAP)
          const Text(
            'E-mail Teocrático JW.org (JW Pub / IMAP)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildJwEmailConfigCard(isDark),

          const SizedBox(height: 20),

          // Seção: Backup Criptografado
          const Text(
            'Cópia de Segurança (Backup)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.shield_outlined,
                    color: AppTheme.accentTeal,
                  ),
                  title: const Text('Backup Criptografado (AES-256)'),
                  subtitle: const Text(
                    'Exportação manual protegida por senha com verificação de integridade.',
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    _lastBackupAt != null
                        ? 'Último backup nesta sessão: ${AppDateUtils.formatDateTime(_lastBackupAt!)}'
                        : 'Nenhum backup realizado nesta sessão',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? const Color(0xFFCBD5E1)
                          : AppTheme.textMuted,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.file_download, size: 18),
                          label: const Text('Exportar'),
                          onPressed: () => _showExportDialog(context),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.file_upload, size: 18),
                          label: const Text('Restaurar'),
                          onPressed: () => _showRestoreDialog(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Ideia 7: Backup Automático Silencioso
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.successGreen.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.cloud_done_outlined,
                              color: AppTheme.successGreen,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Backup Silencioso Automático',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                'Proteção diária em segundo plano',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.successGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Ativo (24h)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.successGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<DateTime?>(
                    future: ref
                        .read(backupServiceProvider)
                        .getLastSilentBackupDate(),
                    builder: (context, snapshot) {
                      final dt = snapshot.data;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              dt != null
                                  ? 'Último backup silencioso: ${AppDateUtils.formatDateTime(dt)}'
                                  : 'Primeiro backup diário pronto para execução.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? const Color(0xFFCBD5E1)
                                    : AppTheme.textMuted,
                              ),
                            ),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: const Icon(Icons.sync, size: 14),
                            label: const Text(
                              'Executar Agora',
                              style: TextStyle(fontSize: 11),
                            ),
                            onPressed: () async {
                              final backupSvc = ref.read(backupServiceProvider);
                              final success = await backupSvc
                                  .performSilentBackupIfNeeded(force: true);
                              setState(() {});
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      success
                                          ? 'Backup silencioso concluído com sucesso!'
                                          : 'Erro ao gerar backup silencioso.',
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
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Seção: Datas Especiais & Eventos Teocráticos
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Datas Especiais & Eventos Teocráticos',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Cadastrar'),
                onPressed: () => _showAddTheocraticEventDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ListTile(
                  leading: Icon(
                    Icons.event_available,
                    color: Color(0xFF7C3AED),
                  ),
                  title: Text('Eventos Oficiais e Visitas'),
                  subtitle: Text(
                    'Visita do Viajante, Assembleias, Congresso e Celebração integrados ao calendário oficial.',
                  ),
                ),
                if (theocraticEvents.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      bottom: 16,
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Nenhum evento teocrático cadastrado no momento.\nToque em "+ Cadastrar" para programar no calendário.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? const Color(0xFFCBD5E1)
                              : AppTheme.textMuted,
                        ),
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: theocraticEvents.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final event = theocraticEvents[index];
                      final displayTitle = event.title
                          .replaceFirst('[Evento Teocrático] ', '')
                          .replaceFirst('[Evento] ', '');
                      return ListTile(
                        dense: true,
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C3AED)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.calendar_month,
                            color: Color(0xFF7C3AED),
                            size: 18,
                          ),
                        ),
                        title: Text(
                          displayTitle,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Text(
                          '${AppDateUtils.formatDateTime(event.startTime)} • ${event.locationNotes ?? "Sem local definido"}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: AppTheme.alertRed,
                          ),
                          tooltip: 'Excluir evento',
                          onPressed: () async {
                            final repo = ref.read(repositoryProvider);
                            await repo.deleteAppointment(event.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Evento removido do calendário.',
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      );
                    },
                  ),
                Padding(
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    bottom: 12,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Cadastrar Novo Evento Teocrático'),
                      onPressed: () => _showAddTheocraticEventDialog(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Seção: Módulos Adicionais
          const Text(
            'Módulos e Recursos',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.dashboard_customize_outlined,
                    color: Color(0xFF7C3AED),
                  ),
                  title: const Text('Personalizar Aplicativo e Recursos'),
                  subtitle: const Text(
                    'Ative ou oculte módulos (Estudos, Agenda, Pesquisa, etc.) com preservação total de dados.',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CustomizeFeaturesScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.timer_outlined,
                    color: AppTheme.primaryBlue,
                  ),
                  title: const Text('Atividades e Metas de Serviço'),
                  subtitle: const Text(
                    'Registro de horas diárias, modalidades e metas anuais.',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ActivitiesScreen(),
                      ),
                    );
                  },
                ),

                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline,
                    color: AppTheme.alertRed,
                  ),
                  title: const Text('Lixeira e Registros Excluídos'),
                  subtitle: const Text(
                    'Recuperação de contatos, visitas e compromissos excluídos.',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TrashScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Seção: Experiência e Acessibilidade no Campo
          const Text(
            'Acessibilidade e Campo',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.wb_sunny_outlined,
                    color: AppTheme.alertAmber,
                  ),
                  title: const Text('Modo Sol Intenso & Alto Contraste'),
                  subtitle: const Text(
                    'Tipografia semibold, superfícies claras e bordas reforçadas para uso sob luz direta do sol no ministério.',
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.successGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Ativo',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.successGreen,
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.devices, color: AppTheme.primaryBlue),
                  title: Text('Responsividade Mobile & Tablet'),
                  subtitle: Text(
                    'Interface otimizada com área de toque mínima de 44x44px para iPhone XR e iPad 11.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Seção: Dados e Demonstração
          const Text(
            'Dados e Demonstração',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.science_outlined, color: Color(0xFF7C3AED)),
                      SizedBox(width: 8),
                      Text(
                        'Ambiente de Testes e Demonstração',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Gere contatos, visitas, estudos e compromissos fictícios para demonstrar o aplicativo ou zerar todos os dados locais.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? const Color(0xFFCBD5E1) : AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7C3AED),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        icon: const Icon(Icons.add_chart, size: 18),
                        label: const Text(
                          'Gerar Demonstração',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: () async {
                          final repo = ref.read(repositoryProvider);
                          await DemoDataGenerator.populateDemoData(repo);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Dados de demonstração gerados com sucesso!'),
                              ),
                            );
                          }
                        },
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFD97706),
                          side: const BorderSide(color: Color(0xFFD97706)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                        label: const Text(
                          'Remover Demonstração',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: () async {
                          final repo = ref.read(repositoryProvider);
                          final count = await DemoDataGenerator.clearDemoData(repo);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  count > 0
                                      ? 'Dados de demonstração removidos com sucesso!'
                                      : 'Nenhum dado de demonstração encontrado.',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.alertRed,
                          side: const BorderSide(color: AppTheme.alertRed),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        icon: const Icon(Icons.delete_forever_outlined, size: 18),
                        label: const Text(
                          'Zerar Banco Local',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Zerar Banco de Dados Local?'),
                              content: const Text(
                                'Esta ação apagará permanentemente todos os registros armazenados neste dispositivo.\n\nDeseja continuar?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancelar'),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.alertRed,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Zerar Banco'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            final repo = ref.read(repositoryProvider);
                            await repo.clearAllLocalData();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Banco de dados local zerado com sucesso!'),
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildSupabaseCard(context),
          const SizedBox(height: 16),
          _buildLanguageSelectorCard(context),
          const SizedBox(height: 16),
          _buildUpdateCheckerCard(context),
          const SizedBox(height: 24),

          Center(
            child: Column(
              children: [
                Text(
                  '${AppVersion.appName} • ${AppVersion.fullDisplayVersion} (Offline-First)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? const Color(0xFFCBD5E1)
                        : AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Lançamento: ${AppVersion.releaseDate} • Otimizado para iPhone, iPadOS, Android e Web',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? const Color(0xFFCBD5E1)
                        : AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSelectorCard(BuildContext context) {
    final currentLocale = ref.watch(appLocaleTypeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.language, color: AppTheme.primaryBlue),
                SizedBox(width: 8),
                Text(
                  'Idioma do Aplicativo (i18n)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Alterne entre os idiomas suportados com suporte offline completo.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? const Color(0xFFCBD5E1) : AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AppLocaleType.values.map((loc) {
                final isSelected = loc == currentLocale;
                return ChoiceChip(
                  label: Text('${loc.flagEmoji} ${loc.label}'),
                  selected: isSelected,
                  selectedColor: AppTheme.primaryBlue.withValues(alpha: 0.2),
                  onSelected: (val) {
                    if (val) {
                      ref.read(appLocaleTypeProvider.notifier).setLocale(loc);
                    }
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  bool _isCheckingUpdate = false;
  AppUpdateInfo? _checkedUpdateInfo;
  String? _updateError;

  Widget _buildUpdateCheckerCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.system_update_rounded, color: Color(0xFF2563EB)),
                SizedBox(width: 8),
                Text(
                  'Atualizações do Aplicativo',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Versão Atual: ${AppVersion.fullDisplayVersion} (${AppVersion.releaseDate})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              'Verifique novas versões no GitHub Releases ou catálogo LiveContainer.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? const Color(0xFFCBD5E1) : AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 12),
            if (_checkedUpdateInfo != null) ...[
              Builder(
                builder: (context) {
                  final status = _checkedUpdateInfo!.status;
                  final Color cardColor;
                  final IconData cardIcon;
                  final String cardTitle;

                  switch (status) {
                    case UpdateCheckStatus.updateAvailable:
                      cardColor = const Color(0xFF2563EB);
                      cardIcon = Icons.download_for_offline_rounded;
                      cardTitle = 'Nova Versão Disponível: v${_checkedUpdateInfo!.latestVersion}';
                      break;
                    case UpdateCheckStatus.upToDate:
                      cardColor = const Color(0xFF16A34A);
                      cardIcon = Icons.check_circle_rounded;
                      cardTitle = 'Você já está usando a versão mais recente!';
                      break;
                    case UpdateCheckStatus.sourceUnavailable:
                      cardColor = const Color(0xFFD97706);
                      cardIcon = Icons.cloud_off_rounded;
                      cardTitle = 'Fonte de atualização indisponível';
                      break;
                    case UpdateCheckStatus.checkFailed:
                      cardColor = const Color(0xFFDC2626);
                      cardIcon = Icons.error_outline_rounded;
                      cardTitle = 'Não foi possível verificar';
                      break;
                  }

                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cardColor.withValues(alpha: isDark ? 0.3 : 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: cardColor.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              cardIcon,
                              color: cardColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                cardTitle,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                        if (_checkedUpdateInfo!.hasUpdate) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Lançamento: ${_checkedUpdateInfo!.releaseDate} • ${_checkedUpdateInfo!.formattedSize}',
                            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _checkedUpdateInfo!.releaseNotes,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.install_mobile_rounded, size: 18),
                            label: const Text('Atualizar Agora'),
                            onPressed: () {
                              ref
                                  .read(updateCheckerServiceProvider)
                                  .launchUpdate(_checkedUpdateInfo!);
                            },
                          ),
                        ] else if (status != UpdateCheckStatus.upToDate) ...[
                          const SizedBox(height: 6),
                          Text(
                            _checkedUpdateInfo!.releaseNotes,
                            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
            if (_updateError != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _updateError!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
              const SizedBox(height: 10),
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: _isCheckingUpdate
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 18),
                label: Text(_isCheckingUpdate
                    ? 'Verificando atualizações...'
                    : 'Verificar Atualizações Agora'),
                onPressed: _isCheckingUpdate
                    ? null
                    : () async {
                        setState(() {
                          _isCheckingUpdate = true;
                          _updateError = null;
                        });
                        try {
                          final info = await ref
                              .read(updateCheckStateProvider.notifier)
                              .check(force: true);
                          if (mounted) {
                            setState(() {
                              _checkedUpdateInfo = info;
                            });
                          }
                        } catch (e) {
                          if (mounted) {
                            setState(() {
                              _updateError = 'Falha ao buscar atualizações: $e';
                            });
                          }
                        } finally {
                          if (mounted) {
                            setState(() {
                              _isCheckingUpdate = false;
                            });
                          }
                        }
                      },
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Nota técnica: No iOS/LiveContainer, as políticas de sandbox impedem a auto-substituição do binário em execução; tocar em atualizar abre diretamente a fonte oficial no LiveContainer.',
              style: TextStyle(
                fontSize: 10.5,
                color: isDark ? const Color(0xFF94A3B8) : AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupabaseCard(BuildContext context) {
    User? currentUser;
    try {
      currentUser = Supabase.instance.client.auth.currentUser;
    } catch (_) {
      currentUser = null;
    }
    final isConnected = currentUser != null;
    final userEmail = currentUser?.email ?? 'Nenhum usuário autenticado';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.cloud_sync, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Conta e Sincronização (Supabase)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  isConnected ? Icons.check_circle : Icons.error_outline,
                  color: isConnected ? Colors.green : Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  isConnected ? 'Status: Conectado' : 'Status: Não conectado',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isConnected ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('E-mail: $userEmail', style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      final result = await ref.read(supabaseSyncServiceProvider).sync();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(result.message)),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erro ao sincronizar: $e')),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.sync, size: 18),
                  label: const Text('Sincronizar Agora'),
                ),
                if (isConnected)
                  OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        await Supabase.instance.client.auth.signOut();
                        setState(() {});
                      } catch (_) {}
                    },
                    icon: const Icon(Icons.logout, color: Colors.red, size: 18),
                    label: const Text('Sair da Conta (Logout)', style: TextStyle(color: Colors.red)),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (authContext) => SupabaseAuthScreen(
                            onAuthenticated: () {
                              if (!mounted || !authContext.mounted) return;
                              Navigator.of(authContext).pop();
                              setState(() {});
                            },
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.login, size: 18),
                    label: const Text('Fazer Login'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJwEmailConfigCard(bool isDark) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.mark_email_unread_outlined, color: AppTheme.primaryBlue, size: 22),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sincronização e Retenção Permanente (IMAP)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Insira suas credenciais teocráticas para sincronizar mensagens e cartas do Hub/JW.org com retenção imune à purga de 90 dias.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? const Color(0xFFCBD5E1) : AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _jwEmailCtrl,
              decoration: const InputDecoration(
                labelText: 'E-mail Teocrático *',
                hintText: 'ex: usuario@jw.org ou usuario@jwpub.org',
                prefixIcon: Icon(Icons.email_outlined, size: 18),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _jwPasswordCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Senha ou Senha de Aplicativo *',
                prefixIcon: Icon(Icons.lock_outline, size: 18),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _jwHostCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Servidor IMAP',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: _jwPortCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Porta',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: _isTestingJwEmail
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_outlined, size: 18),
                    label: Text(_isTestingJwEmail ? 'Testando Conexão...' : 'Testar Conexão e Salvar'),
                    onPressed: _isTestingJwEmail
                        ? null
                        : () async {
                            final email = _jwEmailCtrl.text.trim();
                            final pass = _jwPasswordCtrl.text;
                            final host = _jwHostCtrl.text.trim().isNotEmpty ? _jwHostCtrl.text.trim() : 'mail.jw.org';
                            final port = int.tryParse(_jwPortCtrl.text.trim()) ?? 993;

                            if (email.isEmpty || pass.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Preencha o e-mail e a senha.')),
                              );
                              return;
                            }

                            setState(() => _isTestingJwEmail = true);
                            try {
                              final client = const JwImapClient();
                              await client.fetchRemoteEmails(
                                host: host,
                                port: port,
                                username: email,
                                password: pass,
                              );

                              final db = ref.read(repositoryProvider).db;
                              await db.into(db.appKvStore).insertOnConflictUpdate(
                                AppKvStoreCompanion.insert(
                                  key: 'jw_imap_email',
                                  value: email,
                                  updatedAt: Value(DateTime.now()),
                                ),
                              );
                              await db.into(db.appKvStore).insertOnConflictUpdate(
                                AppKvStoreCompanion.insert(
                                  key: 'jw_imap_password',
                                  value: pass,
                                  updatedAt: Value(DateTime.now()),
                                ),
                              );
                              await db.into(db.appKvStore).insertOnConflictUpdate(
                                AppKvStoreCompanion.insert(
                                  key: 'jw_imap_host',
                                  value: host,
                                  updatedAt: Value(DateTime.now()),
                                ),
                              );
                              await db.into(db.appKvStore).insertOnConflictUpdate(
                                AppKvStoreCompanion.insert(
                                  key: 'jw_imap_port',
                                  value: port.toString(),
                                  updatedAt: Value(DateTime.now()),
                                ),
                              );

                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Configurações de e-mail JW.org salvas com sucesso!')),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Erro ao salvar ou testar: $e')),
                                );
                              }
                            } finally {
                              if (mounted) setState(() => _isTestingJwEmail = false);
                            }
                          },
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Limpar'),
                  onPressed: () async {
                    final db = ref.read(repositoryProvider).db;
                    await (db.delete(db.appKvStore)..where((t) => t.key.equals('jw_imap_email'))).go();
                    await (db.delete(db.appKvStore)..where((t) => t.key.equals('jw_imap_password'))).go();
                    await (db.delete(db.appKvStore)..where((t) => t.key.equals('jw_imap_host'))).go();
                    await (db.delete(db.appKvStore)..where((t) => t.key.equals('jw_imap_port'))).go();
                    setState(() {
                      _jwEmailCtrl.clear();
                      _jwPasswordCtrl.clear();
                      _jwHostCtrl.text = 'mail.jw.org';
                      _jwPortCtrl.text = '993';
                    });
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Configurações removidas.')),
                      );
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

}
