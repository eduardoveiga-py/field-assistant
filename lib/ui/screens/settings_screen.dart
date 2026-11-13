import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../appointments/calendar_sync_coordinator.dart';
import '../../core/app_logger.dart';
import '../../core/biometric_auth_service.dart';
import '../../database/app_database.dart';
import '../../inbox/jw_email_service.dart';
import '../../settings/backup_service.dart';
import '../../sync/supabase_config.dart';
import '../../sync/supabase_sync_service.dart';
import '../widgets/managed_text_controllers.dart';
import '../widgets/pin_auth_dialog.dart';
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
  bool _hasPinConfigured = false;
  final TextEditingController _jwEmailCtrl = TextEditingController();
  final TextEditingController _jwPasswordCtrl = TextEditingController();
  final TextEditingController _jwHostCtrl = TextEditingController(text: 'mail.jw.org');
  final TextEditingController _jwPortCtrl = TextEditingController(text: '993');
  final TextEditingController _jwSmtpHostCtrl = TextEditingController(text: 'mail.jw.org');
  final TextEditingController _jwSmtpPortCtrl = TextEditingController(text: '587');
  String _jwSmtpSecurity = 'starttls';
  bool _isTestingJwEmail = false;
  late Future<DateTime?> _lastSilentBackupFuture;

  @override
  void initState() {
    super.initState();
    final backupSvc = ref.read(backupServiceProvider);
    _lastSilentBackupFuture = backupSvc.getLastSilentBackupDate();
    Future.microtask(() async {
      await backupSvc.performSilentBackupIfNeeded();
      if (mounted) {
        setState(() {
          _lastSilentBackupFuture = backupSvc.getLastSilentBackupDate();
        });
      }
      await _loadGoogleStatus();
      await _loadJwEmailConfig();
      await _loadPinStatus();
    });
  }

  Future<void> _loadPinStatus() async {
    try {
      final hasPin = await ref.read(biometricAuthServiceProvider).hasPin();
      if (mounted) {
        setState(() => _hasPinConfigured = hasPin);
      }
    } catch (e, st) {
      AppLogger.warning('Falha ao consultar status do PIN de segurança', e, st);
    }
  }

  Future<void> _openPinManagement() async {
    final bio = ref.read(biometricAuthServiceProvider);
    final hasPin = await bio.hasPin();
    if (!mounted) return;
    if (!hasPin) {
      final created = await PinSetupDialog.show(context, biometricAuth: bio);
      if (created && mounted) {
        await _loadPinStatus();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PIN de segurança cadastrado com sucesso.'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } else {
      final changed = await showDialog<bool>(
        context: context,
        builder: (_) => _ChangePinDialog(biometricAuth: bio),
      );
      if (changed == true && mounted) {
        await _loadPinStatus();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PIN de segurança atualizado com sucesso.'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _jwEmailCtrl.dispose();
    _jwPasswordCtrl.dispose();
    _jwHostCtrl.dispose();
    _jwPortCtrl.dispose();
    _jwSmtpHostCtrl.dispose();
    _jwSmtpPortCtrl.dispose();
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
    } catch (e, st) {
      AppLogger.warning('Falha ao consultar status do Google Calendar', e, st);
    }
  }

  Future<void> _loadJwEmailConfig() async {
    try {
      final db = ref.read(repositoryProvider).db;
      final email = await (db.select(db.appKvStore)..where((t) => t.key.equals('jw_imap_email'))).getSingleOrNull();
      const secureStorage = FlutterSecureStorage();
      String? pass = await secureStorage.read(key: 'jw_imap_password');

      // Migração automática retroativa: se a senha ainda estava em texto puro no SQLite,
      // migra com segurança para o Keychain/KeyStore e elimina do banco relacional
      if (pass == null || pass.isEmpty) {
        final legacyPass = await (db.select(db.appKvStore)..where((t) => t.key.equals('jw_imap_password'))).getSingleOrNull();
        if (legacyPass != null && legacyPass.value.isNotEmpty) {
          pass = legacyPass.value;
          await secureStorage.write(key: 'jw_imap_password', value: pass);
          await (db.delete(db.appKvStore)..where((t) => t.key.equals('jw_imap_password'))).go();
        }
      }

      final host = await (db.select(db.appKvStore)..where((t) => t.key.equals('jw_imap_host'))).getSingleOrNull();
      final port = await (db.select(db.appKvStore)..where((t) => t.key.equals('jw_imap_port'))).getSingleOrNull();
      final smtpHost = await (db.select(db.appKvStore)..where((t) => t.key.equals('jw_smtp_host'))).getSingleOrNull();
      final smtpPort = await (db.select(db.appKvStore)..where((t) => t.key.equals('jw_smtp_port'))).getSingleOrNull();
      final smtpSecurity = await (db.select(db.appKvStore)..where((t) => t.key.equals('jw_smtp_security'))).getSingleOrNull();

      if (mounted) {
        setState(() {
          if (email != null) _jwEmailCtrl.text = email.value;
          if (pass != null) _jwPasswordCtrl.text = pass;
          if (host != null && host.value.isNotEmpty) _jwHostCtrl.text = host.value;
          if (port != null && port.value.isNotEmpty) _jwPortCtrl.text = port.value;
          if (smtpHost != null && smtpHost.value.isNotEmpty) {
            _jwSmtpHostCtrl.text = smtpHost.value;
          } else if (host != null && host.value.isNotEmpty) {
            _jwSmtpHostCtrl.text = host.value;
          }
          if (smtpPort != null && smtpPort.value.isNotEmpty) {
            _jwSmtpPortCtrl.text = smtpPort.value;
          }
          if (smtpSecurity != null &&
              (smtpSecurity.value == 'starttls' || smtpSecurity.value == 'ssl')) {
            _jwSmtpSecurity = smtpSecurity.value;
          }
        });
      }
    } catch (e, st) {
      AppLogger.warning('Falha ao carregar configuração IMAP do JW Mail', e, st);
    }
  }

  // Modal para cadastro de Eventos Teocráticos e Datas Especiais
  void _showAddTheocraticEventDialog(BuildContext context) {
    String selectedType = 'Visita do Superintendente de Circuito';
    DateTime startDate = DateTime.now().add(const Duration(days: 7));
    TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
    DateTime endDate = startDate;
    TimeOfDay endTime = const TimeOfDay(hour: 16, minute: 30);

    showDialog(
      context: context,
      builder: (ctx) => ManagedTextControllers(
        initialTexts: const ['', ''],
        builder: (ctx, ctrls) {
          final titleController = ctrls[0];
          final locationController = ctrls[1];

          return StatefulBuilder(
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
      );
        },
      ),
    );
  }

  // Modal de Exportação de Backup
  void _showExportDialog(BuildContext context) {
    showDialog<String>(
      context: context,
      builder: (_) => _ExportBackupDialog(
        backupService: ref.read(backupServiceProvider),
        onExported: () {
          if (mounted) {
            setState(() {
              _lastBackupAt = DateTime.now();
            });
          }
        },
      ),
    );
  }

  // Modal de Restauração com Prévia e Confirmação
  void _showRestoreDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => _RestoreBackupDialog(
        backupService: ref.read(backupServiceProvider),
      ),
    );
  }

  // Modal Avançado de Gestão da Fila de Sincronização (Pendentes, Falhas e Conflitos - R3 / M13)
  void _showSyncQueueModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const SyncQueueManagementSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allAppointments = ref.watch(appointmentsStreamProvider).value ?? [];
    final syncCounts = ref.watch(syncQueueCountsProvider).value ??
        (pending: 0, failed: 0, conflict: 0);
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
                  leading: Icon(
                    syncCounts.conflict > 0
                        ? Icons.merge_type
                        : syncCounts.failed > 0
                        ? Icons.warning_amber_rounded
                        : Icons.sync,
                    color: syncCounts.conflict > 0 || syncCounts.failed > 0
                        ? AppTheme.alertRed
                        : AppTheme.primaryBlue,
                  ),
                  title: const Text('Estado da Sincronização'),
                  subtitle: Text(
                    syncCounts.conflict > 0
                        ? '${syncCounts.conflict} conflito(s) aguardando resolução e ${syncCounts.pending} pendente(s).'
                        : syncCounts.failed > 0
                        ? '${syncCounts.failed} operação(ões) em falha e ${syncCounts.pending} pendente(s).'
                        : syncCounts.pending > 0
                        ? '${syncCounts.pending} alteração(ões) salva(s) localmente aguardando envio.'
                        : 'Operando Local-First (Offline). Tudo sincronizado localmente.',
                  ),
                  trailing: Chip(
                    label: Text(
                      syncCounts.conflict > 0
                          ? '${syncCounts.conflict} Conflitos'
                          : syncCounts.failed > 0
                          ? '${syncCounts.failed} Falhas'
                          : 'Local-First',
                      style: const TextStyle(fontSize: 11),
                    ),
                    backgroundColor: (syncCounts.conflict > 0 || syncCounts.failed > 0)
                        ? const Color(0xFFFEE2E2)
                        : const Color(0xFFE0E7FF),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    bottom: 12,
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.cloud_sync),
                          label: Text(
                            (syncCounts.failed > 0 || syncCounts.conflict > 0)
                                ? 'Gerenciar Fila (${syncCounts.pending + syncCounts.failed + syncCounts.conflict})'
                                : 'Verificar Fila de Sincronização',
                          ),
                          onPressed: () => _showSyncQueueModal(context),
                        ),
                      ),
                      if (syncCounts.failed > 0)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.alertAmber,
                              foregroundColor: Colors.black87,
                            ),
                            icon: const Icon(Icons.refresh, size: 18),
                            label: Text('Reprocessar ${syncCounts.failed} Falha(s) Agora'),
                            onPressed: () async {
                              final repo = ref.read(repositoryProvider);
                              await repo.retryAllFailedOperations();
                              final res = await ref.read(supabaseSyncServiceProvider).sync();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(res.message)),
                                );
                              }
                            },
                          ),
                        ),
                    ],
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
                                if (ok) {
                                  await _loadGoogleStatus();
                                } else if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        coord.googleProvider.lastError ??
                                            'Não foi possível autenticar com a conta Google.',
                                      ),
                                    ),
                                  );
                                }
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
                            } else if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    coord.googleProvider.lastError ??
                                        'Não foi possível conectar a conta Google.',
                                  ),
                                ),
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
                    future: _lastSilentBackupFuture,
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
                              if (mounted) {
                                setState(() {
                                  _lastSilentBackupFuture =
                                      backupSvc.getLastSilentBackupDate();
                                });
                              }
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

          // Seção: Segurança e Acesso Restrito
          const Text(
            'Segurança e Acesso Restrito',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Icon(
                _hasPinConfigured ? Icons.lock : Icons.lock_open_outlined,
                color: _hasPinConfigured ? AppTheme.successGreen : AppTheme.alertAmber,
              ),
              title: const Text('PIN de Segurança do Aplicativo'),
              subtitle: Text(
                _hasPinConfigured
                    ? 'PIN ativo para proteger cartas restritas e Hub JW quando não houver biometria.'
                    : 'Nenhum PIN configurado. Configure um PIN obrigatório de fallback.',
              ),
              trailing: TextButton(
                onPressed: _openPinManagement,
                child: Text(_hasPinConfigured ? 'Alterar PIN' : 'Configurar'),
              ),
              onTap: _openPinManagement,
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
                                'Esta ação apaga os registros e as configurações do banco local, inclusive alterações ainda não sincronizadas. Arquivos de mídia, backups, credenciais e dados na nuvem não serão apagados. Dados da nuvem poderão voltar na próxima sincronização.\n\nDeseja continuar?',
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
    final isSupabaseReady = SupabaseSyncService.isInitialized;
    User? currentUser;
    if (isSupabaseReady) {
      try {
        currentUser = Supabase.instance.client.auth.currentUser;
      } catch (e, st) {
        AppLogger.warning('Falha ao obter sessão Supabase atual', e, st);
        currentUser = null;
      }
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
            if (!isSupabaseReady) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade700),
                ),
                child: Row(
                  children: [
                    Icon(Icons.cloud_off, color: Colors.amber.shade800, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Sincronização na nuvem indisponível: Supabase não configurado ou falhou ao inicializar. Operando apenas localmente.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  isConnected
                      ? Icons.check_circle
                      : (isSupabaseReady ? Icons.error_outline : Icons.cloud_off),
                  color: isConnected
                      ? Colors.green
                      : (isSupabaseReady ? Colors.orange : Colors.red),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  isConnected
                      ? 'Status: Conectado'
                      : (isSupabaseReady
                          ? 'Status: Não conectado'
                          : 'Status: Indisponível (offline)'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isConnected
                        ? Colors.green
                        : (isSupabaseReady ? Colors.orange : Colors.red),
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
                  onPressed: !isSupabaseReady
                      ? null
                      : () async {
                          try {
                            final result =
                                await ref.read(supabaseSyncServiceProvider).sync();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(result.message)),
                              );
                            }
                          } catch (e, st) {
                            AppLogger.error(
                                'Erro ao sincronizar via configurações', e, st);
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
                      } catch (e, st) {
                        AppLogger.warning('Falha ao fazer logout do Supabase', e, st);
                      }
                    },
                    icon: const Icon(Icons.logout, color: Colors.red, size: 18),
                    label: const Text('Sair da Conta (Logout)',
                        style: TextStyle(color: Colors.red)),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: !isSupabaseReady
                        ? null
                        : () {
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
                OutlinedButton.icon(
                  onPressed: () => _showRuntimeSupabaseConfigDialog(context),
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: Text(
                    isSupabaseReady
                        ? 'Configurar Servidor'
                        : 'Configurar Supabase (URL/Chave)',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRuntimeSupabaseConfigDialog(BuildContext context) async {
    final existingUrl = await SupabaseSyncService.getRuntimeUrl() ?? '';
    final hasRuntime = await SupabaseSyncService.hasRuntimeConfig();
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => ManagedTextControllers(
        initialTexts: [existingUrl, ''],
        builder: (ctx, ctrls) {
          final urlCtrl = ctrls[0];
          final keyCtrl = ctrls[1];
          bool isSaving = false;
          String? errorText;

          return StatefulBuilder(
            builder: (ctx, setDlgState) => AlertDialog(
              title: const Text('Configuração Runtime do Supabase'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      SupabaseConfig.isConfigured
                          ? 'Compilado com --dart-define. Definir URL/Chave aqui sobrescreve o servidor em runtime.'
                          : 'Informe a URL e a Chave Anon/Publishable do seu projeto Supabase para habilitar login e sincronização em nuvem sem recompilar o app.',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: urlCtrl,
                      enabled: !isSaving,
                      decoration: const InputDecoration(
                        labelText: 'Supabase URL *',
                        hintText: 'https://seu-projeto.supabase.co',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: keyCtrl,
                      enabled: !isSaving,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Supabase Anon / Publishable Key *',
                        hintText: hasRuntime
                            ? 'Informe para atualizar ou cole a chave...'
                            : 'sb_publishable_... ou eyJ...',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        errorText!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(ctx).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                if (hasRuntime)
                  TextButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            setDlgState(() => isSaving = true);
                            await SupabaseSyncService.clearRuntimeConfig();
                            await SupabaseSyncService.initialize();
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) {
                              setState(() {});
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Configuração runtime do Supabase removida.',
                                  ),
                                ),
                              );
                            }
                          },
                    child: const Text(
                      'Remover',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final validationError =
                              SupabaseSyncService.validateSupabaseCredentials(
                            urlCtrl.text,
                            keyCtrl.text,
                          );
                          if (validationError != null) {
                            setDlgState(() => errorText = validationError);
                            return;
                          }
                          setDlgState(() {
                            isSaving = true;
                            errorText = null;
                          });
                          try {
                            await SupabaseSyncService.configureAndInitialize(
                              url: urlCtrl.text,
                              anonKey: keyCtrl.text,
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) {
                              setState(() {});
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Supabase inicializado com sucesso em runtime!',
                                  ),
                                  backgroundColor: AppTheme.successGreen,
                                ),
                              );
                            }
                          } catch (e, st) {
                            AppLogger.warning(
                              'Falha ao inicializar Supabase em runtime',
                              e,
                              st,
                            );
                            if (ctx.mounted) {
                              setDlgState(() {
                                isSaving = false;
                                errorText = 'Falha ao inicializar Supabase: $e';
                              });
                            }
                          }
                        },
                  child: Text(isSaving ? 'Conectando...' : 'Salvar e Conectar'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _persistEmailAccountConfig({
    required AppDatabase db,
    required String email,
    required String pass,
    required String imapHost,
    required int imapPort,
    required String smtpHost,
    required int smtpPort,
    required String smtpSecurity,
  }) async {
    final now = Value(DateTime.now());
    await db.into(db.appKvStore).insertOnConflictUpdate(
      AppKvStoreCompanion.insert(key: 'jw_imap_email', value: email, updatedAt: now),
    );
    await const FlutterSecureStorage().write(key: 'jw_imap_password', value: pass);
    await (db.delete(db.appKvStore)..where((t) => t.key.equals('jw_imap_password'))).go();
    await db.into(db.appKvStore).insertOnConflictUpdate(
      AppKvStoreCompanion.insert(key: 'jw_imap_host', value: imapHost, updatedAt: now),
    );
    await db.into(db.appKvStore).insertOnConflictUpdate(
      AppKvStoreCompanion.insert(key: 'jw_imap_port', value: imapPort.toString(), updatedAt: now),
    );
    await db.into(db.appKvStore).insertOnConflictUpdate(
      AppKvStoreCompanion.insert(key: 'jw_smtp_host', value: smtpHost, updatedAt: now),
    );
    await db.into(db.appKvStore).insertOnConflictUpdate(
      AppKvStoreCompanion.insert(key: 'jw_smtp_port', value: smtpPort.toString(), updatedAt: now),
    );
    await db.into(db.appKvStore).insertOnConflictUpdate(
      AppKvStoreCompanion.insert(key: 'jw_smtp_security', value: smtpSecurity, updatedAt: now),
    );
  }

  Future<void> _testAndSaveJwEmail({bool includeImap = true}) async {
    final email = _jwEmailCtrl.text.trim();
    final pass = _jwPasswordCtrl.text;
    final imapHost = _jwHostCtrl.text.trim().isNotEmpty ? _jwHostCtrl.text.trim() : 'mail.jw.org';
    final imapPort = int.tryParse(_jwPortCtrl.text.trim()) ?? 993;
    final smtpHost = _jwSmtpHostCtrl.text.trim().isNotEmpty
        ? _jwSmtpHostCtrl.text.trim()
        : imapHost;
    final defaultSmtpPort = _jwSmtpSecurity == 'ssl' ? 465 : 587;
    final smtpPort = int.tryParse(_jwSmtpPortCtrl.text.trim()) ?? defaultSmtpPort;

    if (email.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha o e-mail e a senha antes de testar a conexão.')),
      );
      return;
    }

    setState(() => _isTestingJwEmail = true);
    try {
      if (includeImap) {
        const imapClient = JwImapClient();
        await imapClient.verifyConnection(
          host: imapHost,
          port: imapPort,
          username: email,
          password: pass,
        );
      }

      const smtpClient = JwSmtpClient();
      await smtpClient.verifyConnection(
        host: smtpHost,
        port: smtpPort,
        username: email,
        password: pass,
        securityMode: _jwSmtpSecurity,
      );

      final db = ref.read(repositoryProvider).db;
      await _persistEmailAccountConfig(
        db: db,
        email: email,
        pass: pass,
        imapHost: imapHost,
        imapPort: imapPort,
        smtpHost: smtpHost,
        smtpPort: smtpPort,
        smtpSecurity: _jwSmtpSecurity,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              includeImap
                  ? 'Conexões IMAP e SMTP verificadas com sucesso! Configurações salvas com segurança.'
                  : 'Conexão SMTP ($smtpHost:$smtpPort) verificada com sucesso! Configurações salvas.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Falha na verificação de e-mail: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isTestingJwEmail = false);
    }
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
                    'Sincronização e Envio de E-mail (IMAP / SMTP)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Use os servidores e portas IMAP e SMTP fornecidos pelo seu provedor. Exchange ActiveSync não é IMAP/SMTP; o teste não valida esse protocolo. O teste IMAP verifica acesso à INBOX sem baixar mensagens.',
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
                      labelText: 'Servidor IMAP (Entrada)',
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
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _jwSmtpHostCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Servidor SMTP (Saída)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: _jwSmtpPortCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Porta',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text('Segurança SMTP:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(width: 10),
                ChoiceChip(
                  label: const Text('STARTTLS (587)'),
                  selected: _jwSmtpSecurity == 'starttls',
                  onSelected: (_) {
                    setState(() {
                      _jwSmtpSecurity = 'starttls';
                      if (_jwSmtpPortCtrl.text.trim() == '465' || _jwSmtpPortCtrl.text.trim().isEmpty) {
                        _jwSmtpPortCtrl.text = '587';
                      }
                    });
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('SSL/TLS (465)'),
                  selected: _jwSmtpSecurity == 'ssl',
                  onSelected: (_) {
                    setState(() {
                      _jwSmtpSecurity = 'ssl';
                      if (_jwSmtpPortCtrl.text.trim() == '587' || _jwSmtpPortCtrl.text.trim().isEmpty) {
                        _jwSmtpPortCtrl.text = '465';
                      }
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  icon: _isTestingJwEmail
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_outlined, size: 18),
                  label: Text(_isTestingJwEmail ? 'Testando Conexão...' : 'Testar IMAP/SMTP e Salvar'),
                  onPressed: _isTestingJwEmail ? null : () => _testAndSaveJwEmail(includeImap: true),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: const Text('Testar Só SMTP'),
                  onPressed: _isTestingJwEmail ? null : () => _testAndSaveJwEmail(includeImap: false),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Limpar'),
                  onPressed: () async {
                    final db = ref.read(repositoryProvider).db;
                    await const FlutterSecureStorage().delete(key: 'jw_imap_password');
                    for (final k in const [
                      'jw_imap_email',
                      'jw_imap_password',
                      'jw_imap_host',
                      'jw_imap_port',
                      'jw_smtp_host',
                      'jw_smtp_port',
                      'jw_smtp_security',
                    ]) {
                      await (db.delete(db.appKvStore)..where((t) => t.key.equals(k))).go();
                    }
                    setState(() {
                      _jwEmailCtrl.clear();
                      _jwPasswordCtrl.clear();
                      _jwHostCtrl.text = 'mail.jw.org';
                      _jwPortCtrl.text = '993';
                      _jwSmtpHostCtrl.text = 'mail.jw.org';
                      _jwSmtpPortCtrl.text = '587';
                      _jwSmtpSecurity = 'starttls';
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

class _ChangePinDialog extends StatefulWidget {
  final BiometricAuthService biometricAuth;

  const _ChangePinDialog({required this.biometricAuth});

  @override
  State<_ChangePinDialog> createState() => _ChangePinDialogState();
}

class _ChangePinDialogState extends State<_ChangePinDialog> {
  final TextEditingController _currentCtrl = TextEditingController();
  final TextEditingController _newCtrl = TextEditingController();
  final TextEditingController _confirmCtrl = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final current = _currentCtrl.text.trim();
    final next = _newCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();
    if (next.length < 4 || next.length > 8) {
      setState(() => _error = 'O novo PIN deve ter entre 4 e 8 dígitos.');
      return;
    }
    if (next != confirm) {
      setState(() => _error = 'Os novos PINs não coincidem.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final ok = await widget.biometricAuth.changePin(
        currentPin: current,
        newPin: next,
      );
      if (!mounted) return;
      if (ok) {
        Navigator.pop(context, true);
      } else {
        setState(() {
          _error = 'PIN atual incorreto.';
          _saving = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Alterar PIN de Segurança'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _currentCtrl,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 8,
            decoration: const InputDecoration(
              labelText: 'PIN Atual',
              counterText: '',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _newCtrl,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 8,
            decoration: const InputDecoration(
              labelText: 'Novo PIN (4 a 8 dígitos)',
              counterText: '',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _confirmCtrl,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 8,
            decoration: const InputDecoration(
              labelText: 'Confirmar Novo PIN',
              counterText: '',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Salvar Novo PIN'),
        ),
      ],
    );
  }
}

class SyncQueueManagementSheet extends ConsumerStatefulWidget {
  const SyncQueueManagementSheet({super.key});

  @override
  ConsumerState<SyncQueueManagementSheet> createState() =>
      _SyncQueueManagementSheetState();
}

class _SyncQueueManagementSheetState
    extends ConsumerState<SyncQueueManagementSheet> {
  List<SyncQueueEntry> _items = const [];
  String _filter = 'all';
  bool _loading = true;
  bool _busy = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _loadQueue();
  }

  Future<void> _loadQueue() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final list =
          await ref.read(repositoryProvider).getUnresolvedSyncOperations();
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e, st) {
      AppLogger.error('Erro ao carregar fila de sincronização', e, st);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _statusMessage = 'Erro ao carregar fila: $e';
      });
    }
  }

  Future<void> _retryOne(SyncQueueEntry op) async {
    setState(() => _busy = true);
    try {
      final repo = ref.read(repositoryProvider);
      await repo.retrySyncOperation(op.id);
      if (SupabaseSyncService.isInitialized) {
        final res = await ref.read(supabaseSyncServiceProvider).sync();
        _statusMessage = res.message;
      } else {
        _statusMessage = 'Operação marcada como pendente para reenvio.';
      }
      await _loadQueue();
    } catch (e, st) {
      AppLogger.error('Erro ao reprocessar operação ${op.id}', e, st);
      if (mounted) {
        setState(() => _statusMessage = 'Falha ao reprocessar: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _retryAllFailed() async {
    setState(() => _busy = true);
    try {
      final repo = ref.read(repositoryProvider);
      final count = await repo.retryAllFailedOperations();
      if (SupabaseSyncService.isInitialized) {
        final res = await ref.read(supabaseSyncServiceProvider).sync();
        _statusMessage = '$count reativada(s). ${res.message}';
      } else {
        _statusMessage = '$count operação(ões) marcada(s) como pendente(s).';
      }
      await _loadQueue();
    } catch (e, st) {
      AppLogger.error('Erro ao reprocessar falhas em lote', e, st);
      if (mounted) {
        setState(() => _statusMessage = 'Falha ao reprocessar: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resolveKeepLocal(SyncQueueEntry op) async {
    setState(() => _busy = true);
    try {
      await ref.read(repositoryProvider).resolveSyncConflictKeepLocal(op.id);
      if (SupabaseSyncService.isInitialized) {
        final res = await ref.read(supabaseSyncServiceProvider).sync();
        _statusMessage = 'Versão local mantida. ${res.message}';
      } else {
        _statusMessage = 'Versão local selecionada e enfileirada para envio.';
      }
      await _loadQueue();
    } catch (e, st) {
      AppLogger.error('Erro ao resolver conflito mantendo local ${op.id}', e, st);
      if (mounted) {
        setState(() => _statusMessage = 'Erro ao resolver conflito: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resolveAcceptRemote(SyncQueueEntry op) async {
    setState(() => _busy = true);
    try {
      final ok = await ref
          .read(supabaseSyncServiceProvider)
          .resolveConflictAcceptRemote(op.id);
      _statusMessage = ok
          ? 'Versão remota aplicada localmente com sucesso.'
          : 'Não foi possível obter os dados remotos deste registro.';
      await _loadQueue();
    } catch (e, st) {
      AppLogger.error('Erro ao aceitar versão remota ${op.id}', e, st);
      if (mounted) {
        setState(() => _statusMessage = 'Erro ao aplicar versão remota: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<Map<String, String>> _extractConflictFields(SyncQueueEntry op) {
    final diffs = <Map<String, String>>[];
    try {
      final raw = jsonDecode(op.payload);
      if (raw is! Map<String, dynamic>) return diffs;
      final explicit = raw['_conflicts'];
      if (explicit is List) {
        for (final item in explicit) {
          if (item is Map) {
            diffs.add({
              'field': '${item['fieldName'] ?? item['field'] ?? 'campo'}',
              'local': '${item['local'] ?? item['localValue'] ?? ''}',
              'remote': '${item['remote'] ?? item['remoteValue'] ?? ''}',
            });
          }
        }
      }
      if (diffs.isEmpty && raw['_remote'] is Map) {
        final remote = Map<String, dynamic>.from(raw['_remote'] as Map);
        const ignored = {'_remote', '_conflicts', '_base', 'id', 'user_id', 'userId'};
        for (final key in remote.keys) {
          if (ignored.contains(key)) continue;
          final rVal = remote[key]?.toString() ?? '';
          final lVal = (raw[key] ?? '')?.toString() ?? '';
          if (lVal != rVal) {
            diffs.add({'field': key, 'local': lVal, 'remote': rVal});
          }
        }
      }
    } catch (e, st) {
      AppLogger.warning('Falha ao extrair diff de conflito de ${op.id}', e, st);
    }
    return diffs;
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _items.where((i) => i.status == 'pending' || i.status == 'in_progress').length;
    final failedCount = _items.where((i) => i.status == 'failed').length;
    final conflictCount = _items.where((i) => i.status == 'conflict').length;
    final filtered = _items.where((i) {
      if (_filter == 'all') return true;
      if (_filter == 'pending') return i.status == 'pending' || i.status == 'in_progress';
      return i.status == _filter;
    }).toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Fila de Sincronização (Sync Queue)',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Atualizar',
                    onPressed: _busy ? null : _loadQueue,
                  ),
                ],
              ),
              if (_statusMessage != null) ...[
                const SizedBox(height: 4),
                Text(
                  _statusMessage!,
                  style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ChoiceChip(
                    label: Text('Todos (${_items.length})'),
                    selected: _filter == 'all',
                    onSelected: (_) => setState(() => _filter = 'all'),
                  ),
                  ChoiceChip(
                    label: Text('Pendentes ($pendingCount)'),
                    selected: _filter == 'pending',
                    onSelected: (_) => setState(() => _filter = 'pending'),
                  ),
                  ChoiceChip(
                    label: Text('Falhas ($failedCount)'),
                    selected: _filter == 'failed',
                    onSelected: (_) => setState(() => _filter = 'failed'),
                  ),
                  ChoiceChip(
                    label: Text('Conflitos ($conflictCount)'),
                    selected: _filter == 'conflict',
                    onSelected: (_) => setState(() => _filter = 'conflict'),
                  ),
                ],
              ),
              if (failedCount > 0 || SupabaseSyncService.isInitialized) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (failedCount > 0)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.alertAmber,
                          foregroundColor: Colors.black87,
                        ),
                        onPressed: _busy ? null : _retryAllFailed,
                        icon: const Icon(Icons.replay, size: 16),
                        label: Text('Reprocessar $failedCount Falha(s)'),
                      ),
                    if (SupabaseSyncService.isInitialized && _items.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () async {
                                setState(() => _busy = true);
                                try {
                                  final res = await ref
                                      .read(supabaseSyncServiceProvider)
                                      .sync();
                                  _statusMessage = res.message;
                                  await _loadQueue();
                                } finally {
                                  if (mounted) setState(() => _busy = false);
                                }
                              },
                        icon: const Icon(Icons.sync, size: 16),
                        label: const Text('Sincronizar Agora'),
                      ),
                  ],
                ),
              ],
              const Divider(height: 16),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : filtered.isEmpty
                        ? const Center(
                            child: Text(
                              'Nenhum item pendente, com falha ou conflito neste filtro.',
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final op = filtered[index];
                              final isConflict = op.status == 'conflict';
                              final isFailed = op.status == 'failed';
                              final badgeColor = isConflict
                                  ? AppTheme.alertAmber
                                  : isFailed
                                      ? AppTheme.alertRed
                                      : AppTheme.primaryBlue;
                              final badgeLabel = isConflict
                                  ? 'CONFLITO'
                                  : isFailed
                                      ? 'FALHA'
                                      : 'PENDENTE';
                              final diffs = isConflict
                                  ? _extractConflictFields(op)
                                  : const <Map<String, String>>[];

                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: badgeColor.withValues(alpha: 0.16),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              badgeLabel,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: isConflict
                                                    ? Colors.orange.shade900
                                                    : badgeColor,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              '${op.entityType} • ${op.operation}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            'Tentativas: ${op.attempts}',
                                            style: const TextStyle(fontSize: 11),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'ID: ${op.entityId}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      if (op.lastError != null &&
                                          op.lastError!.trim().isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          op.lastError!,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isConflict
                                                ? Colors.orange.shade900
                                                : AppTheme.alertRed,
                                          ),
                                        ),
                                      ],
                                      if (diffs.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Campos divergentes:',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              for (final d in diffs.take(6))
                                                Padding(
                                                  padding: const EdgeInsets.only(
                                                    bottom: 2,
                                                  ),
                                                  child: Text(
                                                    '• ${d['field']}: Local="${d['local']}" vs Remoto="${d['remote']}"',
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        children: [
                                          if (isConflict) ...[
                                            ElevatedButton.icon(
                                              onPressed: _busy
                                                  ? null
                                                  : () => _resolveKeepLocal(op),
                                              icon: const Icon(
                                                Icons.upload,
                                                size: 16,
                                              ),
                                              label: const Text('Manter Local'),
                                            ),
                                            OutlinedButton.icon(
                                              onPressed: _busy
                                                  ? null
                                                  : () => _resolveAcceptRemote(op),
                                              icon: const Icon(
                                                Icons.download,
                                                size: 16,
                                              ),
                                              label: const Text('Aceitar Remoto'),
                                            ),
                                          ] else
                                            OutlinedButton.icon(
                                              onPressed: _busy
                                                  ? null
                                                  : () => _retryOne(op),
                                              icon: const Icon(
                                                Icons.refresh,
                                                size: 16,
                                              ),
                                              label: Text(
                                                isFailed
                                                    ? 'Reprocessar'
                                                    : 'Tentar Enviar Agora',
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ExportBackupDialog extends StatefulWidget {
  final BackupService backupService;
  final VoidCallback onExported;

  const _ExportBackupDialog({
    required this.backupService,
    required this.onExported,
  });

  @override
  State<_ExportBackupDialog> createState() => _ExportBackupDialogState();
}

class _ExportBackupDialogState extends State<_ExportBackupDialog> {
  final TextEditingController _passwordController = TextEditingController();
  bool _exporting = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _export() async {
    final password = _passwordController.text.trim();
    if (password.length < 6) {
      setState(() => _error = 'A senha deve conter ao menos 6 caracteres.');
      return;
    }

    setState(() {
      _exporting = true;
      _error = null;
    });

    try {
      final encryptedData = await widget.backupService.exportEncryptedBackup(
        password,
      );
      widget.onExported();
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);

      showDialog<void>(
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
                Clipboard.setData(ClipboardData(text: encryptedData));
                Navigator.pop(c);
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Backup copiado para a área de transferência!'),
                  ),
                );
              },
            ),
          ],
        ),
      );
    } catch (e, st) {
      AppLogger.error('Erro ao exportar backup criptografado', e, st);
      if (mounted) {
        setState(() {
          _exporting = false;
          _error = 'Erro ao exportar backup: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkDialog = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      title: const Text('Exportar Backup Criptografado'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Defina uma senha forte. O arquivo será criptografado com AES-256-GCM (PBKDF2 100k) e só poderá ser restaurado com esta senha.',
            style: TextStyle(
              fontSize: 13,
              color: isDarkDialog ? const Color(0xFFCBD5E1) : AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            decoration: const InputDecoration(
              labelText: 'Senha de Criptografia',
              hintText: 'Mínimo 6 caracteres',
            ),
            obscureText: true,
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _exporting ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _exporting ? null : _export,
          child: _exporting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Exportar'),
        ),
      ],
    );
  }
}

class _RestoreBackupDialog extends StatefulWidget {
  final BackupService backupService;

  const _RestoreBackupDialog({required this.backupService});

  @override
  State<_RestoreBackupDialog> createState() => _RestoreBackupDialogState();
}

class _RestoreBackupDialogState extends State<_RestoreBackupDialog> {
  final TextEditingController _dataController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _allowLegacyV1 = false;
  bool _showLegacyOption = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _dataController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    final raw = _dataController.text.trim();
    final pwd = _passwordController.text.trim();
    if (raw.isEmpty || pwd.isEmpty) {
      setState(() => _error = 'Preencha os dados do backup e a senha.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final preview = await widget.backupService.previewBackup(
        encryptedDataString: raw,
        password: pwd,
        allowLegacyV1: _allowLegacyV1,
      );

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);

      showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Pré-visualização da Restauração'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Registros verificados com integridade SHA-256:'),
                const SizedBox(height: 8),
                Text('• Novos contatos: ${preview.peopleToAdd}'),
                Text('• Contatos a atualizar: ${preview.peopleToUpdate}'),
                Text('• Contatos inalterados: ${preview.peopleUnchanged}'),
                Text('• Visitas a importar: ${preview.visitsToAdd}'),
                Text('• Estudos bíblicos: ${preview.studiesToAdd}'),
                Text('• Sessões de estudo: ${preview.sessionsToAdd}'),
                Text('• Compromissos: ${preview.appointmentsToAdd}'),
                Text('• Idiomas / Ticuna: ${preview.appLanguagesToAdd + preview.ticunaWordsToAdd + preview.ticunaPhrasesToAdd}'),
                Text('• Documentos de conhecimento: ${preview.knowledgeDocumentsToAdd}'),
                if (!preview.isIntegral) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Atenção: ${preview.corruptedAudioIds.length} áudio(s) e ${preview.corruptedDocumentIds.length} documento(s) falharam na verificação SHA-256 e não serão restaurados.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(c).colorScheme.error,
                    ),
                  ),
                ],
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
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                await widget.backupService.commitRestore(preview);
                if (c.mounted) Navigator.pop(c);
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Restauração concluída com sucesso!'),
                  ),
                );
              },
              child: const Text('Confirmar Restauração'),
            ),
          ],
        ),
      );
    } on LegacyBackupNotAllowedException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _showLegacyOption = true;
          _error = e.message;
        });
      }
    } catch (e, st) {
      AppLogger.warning('Erro na validação do backup', e, st);
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Erro na validação do backup: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Restaurar Backup Criptografado'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _dataController,
              decoration: const InputDecoration(
                labelText: 'Cole o código criptografado do backup',
                hintText: '{"iv":"...","ciphertext":"..."}',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Senha utilizada na exportação',
              ),
              obscureText: true,
            ),
            if (_showLegacyOption || _allowLegacyV1) ...[
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _allowLegacyV1,
                onChanged: (val) => setState(() => _allowLegacyV1 = val ?? false),
                title: const Text(
                  'Permitir backup legado (v1, criptografia antiga sem salt)',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _busy ? null : _analyze,
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Analisar Backup'),
        ),
      ],
    );
  }
}
