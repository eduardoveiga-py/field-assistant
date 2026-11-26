import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:eas_client/eas_client.dart' as eas;

import '../widgets/email_remote_image.dart';

import '../../ticuna/ticuna_providers.dart';

import '../../inbox/exchange_service.dart';
import '../../inbox/email_account_model.dart';
import '../../inbox/email_contacts_manager.dart';
import '../../inbox/email_sync_coordinator.dart';
import '../../inbox/gmail_oauth_service.dart';
import '../../inbox/microsoft_oauth_service.dart';
import '../../inbox/oauth_token_store.dart';
import '../../appointments/calendar_sync_coordinator.dart';
import '../../core/app_logger.dart';
import '../../database/app_database.dart';
import '../../inbox/jw_email_service.dart';
import '../../sync/media_bytes.dart';
import '../../sync/supabase_config.dart';
import '../../sync/supabase_sync_service.dart';
import '../../sync/sync_owner_guard.dart';
import '../widgets/app_inline_image_view.dart';
import '../widgets/managed_text_controllers.dart';
import '../widgets/markdown_preview_text.dart';
import '../widgets/pin_auth_dialog.dart';
import '../widgets/e2ee_setup_dialog.dart';
import '../widgets/rich_formatted_editing_controller.dart';
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
import '../widgets/settings/backup_and_pin_dialogs.dart';
import '../widgets/settings/offline_library_dialog.dart';
import '../widgets/settings/sync_queue_management_sheet.dart';
import '../../bible/nwt_bible_service.dart';
import '../../publications/imported_publications_service.dart';

export '../widgets/settings/sync_queue_management_sheet.dart'
    show SyncQueueManagementSheet;

part 'settings/settings_integration_cards.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  void _updateState(VoidCallback fn) => setState(fn);
  bool _isCheckingUpdate = false;
  AppUpdateInfo? _checkedUpdateInfo;
  String? _updateError;
  DateTime? _lastBackupAt;
  String? _googleAccountEmail;
  bool _isGoogleConnected = false;
  bool _hasPinConfigured = false;
  final TextEditingController _jwEmailCtrl = TextEditingController();
  final TextEditingController _jwPasswordCtrl = TextEditingController();
  final TextEditingController _jwHostCtrl = TextEditingController(
    text: 'mail.jw.org',
  );
  final TextEditingController _jwPortCtrl = TextEditingController(text: '993');
  final TextEditingController _jwSmtpHostCtrl = TextEditingController(
    text: 'mail.jw.org',
  );
  final TextEditingController _jwSmtpPortCtrl = TextEditingController(
    text: '587',
  );
  String _jwSmtpSecurity = 'starttls';
  bool _isTestingJwEmail = false;
  bool _isTestingExchange = false;
  final _exchangeEmailCtrl = TextEditingController();
  final _exchangePasswordCtrl = TextEditingController();
  final _exchangeHostCtrl = TextEditingController();
  late Future<DateTime?> _lastSilentBackupFuture;
  Future<bool>? _e2eeFuture;
  String? _lastEffectiveUserId;
  int _importedBiblesCount = 0;
  int _importedPublicationsCount = 0;

  Future<bool> _getE2eeFuture(String effectiveUserId) {
    if (_e2eeFuture == null || _lastEffectiveUserId != effectiveUserId) {
      _lastEffectiveUserId = effectiveUserId;
      _e2eeFuture = ref
          .read(e2eeServiceProvider)
          .isKeyInstalled(effectiveUserId);
    }
    return _e2eeFuture!;
  }

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
      await _loadOfflineLibraryCounts();
    });
  }

  Future<void> _loadOfflineLibraryCounts() async {
    try {
      final db = ref.read(databaseProvider);
      final bibles = await NwtBibleService.listTranslations(db);
      final pubs = await ImportedPublicationsService.listPublications(db);
      if (mounted) {
        setState(() {
          _importedBiblesCount = bibles.length;
          _importedPublicationsCount = pubs.length;
        });
      }
    } catch (e, st) {
      AppLogger.warning('Falha ao consultar biblioteca offline', e, st);
    }
  }

  Future<void> _openOfflineLibrary() async {
    final db = ref.read(databaseProvider);
    await showOfflineLibraryDialog(context, db: db);
    await _loadOfflineLibraryCounts();
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
        builder: (_) => ChangePinDialog(biometricAuth: bio),
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
    _exchangeEmailCtrl.dispose();
    _exchangePasswordCtrl.dispose();
    _exchangeHostCtrl.dispose();
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
      final account = await coordinator.googleProvider
          .getConnectedAccountName();
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
      final email = await (db.select(
        db.appKvStore,
      )..where((t) => t.key.equals('jw_imap_email'))).getSingleOrNull();
      const secureStorage = FlutterSecureStorage();
      String? pass = await secureStorage.read(key: 'jw_imap_password');

      // Migração automática retroativa: se a senha ainda estava em texto puro no SQLite,
      // migra com segurança para o Keychain/KeyStore e elimina do banco relacional
      if (pass == null || pass.isEmpty) {
        final legacyPass = await (db.select(
          db.appKvStore,
        )..where((t) => t.key.equals('jw_imap_password'))).getSingleOrNull();
        if (legacyPass != null && legacyPass.value.isNotEmpty) {
          pass = legacyPass.value;
          await secureStorage.write(key: 'jw_imap_password', value: pass);
          await (db.delete(
            db.appKvStore,
          )..where((t) => t.key.equals('jw_imap_password'))).go();
        }
      }

      final easEmail = await (db.select(
        db.appKvStore,
      )..where((t) => t.key.equals('jw_eas_email'))).getSingleOrNull();
      final easHost = await (db.select(
        db.appKvStore,
      )..where((t) => t.key.equals('jw_eas_host'))).getSingleOrNull();
      final easPassword = await secureStorage.read(key: 'jw_eas_password');
      final host = await (db.select(
        db.appKvStore,
      )..where((t) => t.key.equals('jw_imap_host'))).getSingleOrNull();
      final port = await (db.select(
        db.appKvStore,
      )..where((t) => t.key.equals('jw_imap_port'))).getSingleOrNull();
      final smtpHost = await (db.select(
        db.appKvStore,
      )..where((t) => t.key.equals('jw_smtp_host'))).getSingleOrNull();
      final smtpPort = await (db.select(
        db.appKvStore,
      )..where((t) => t.key.equals('jw_smtp_port'))).getSingleOrNull();
      final smtpSecurity = await (db.select(
        db.appKvStore,
      )..where((t) => t.key.equals('jw_smtp_security'))).getSingleOrNull();

      if (mounted) {
        setState(() {
          if (easEmail != null) _exchangeEmailCtrl.text = easEmail.value;
          if (easHost != null) _exchangeHostCtrl.text = easHost.value;
          if (easPassword != null) _exchangePasswordCtrl.text = easPassword;
          if (email != null) _jwEmailCtrl.text = email.value;
          if (pass != null) _jwPasswordCtrl.text = pass;
          if (host != null && host.value.isNotEmpty) {
            _jwHostCtrl.text = host.value;
          }
          if (port != null && port.value.isNotEmpty) {
            _jwPortCtrl.text = port.value;
          }
          if (smtpHost != null && smtpHost.value.isNotEmpty) {
            _jwSmtpHostCtrl.text = smtpHost.value;
          } else if (host != null && host.value.isNotEmpty) {
            _jwSmtpHostCtrl.text = host.value;
          }
          if (smtpPort != null && smtpPort.value.isNotEmpty) {
            _jwSmtpPortCtrl.text = smtpPort.value;
          }
          if (smtpSecurity != null &&
              (smtpSecurity.value == 'starttls' ||
                  smtpSecurity.value == 'ssl')) {
            _jwSmtpSecurity = smtpSecurity.value;
          }
        });
      }
    } catch (e, st) {
      AppLogger.warning(
        'Falha ao carregar configuração IMAP do JW Mail',
        e,
        st,
      );
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
                            child: Text(
                              'Visita do Superintendente de Circuito',
                            ),
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
                          if (val != null) {
                            setDialogState(() => selectedType = val);
                          }
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
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
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
                                if (t != null) {
                                  setDialogState(() => startTime = t);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Data e Horário de Término:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
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
                                if (d != null) {
                                  setDialogState(() => endDate = d);
                                }
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
                                if (t != null) {
                                  setDialogState(() => endTime = t);
                                }
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
      builder: (_) => ExportBackupDialog(
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
      builder: (_) =>
          RestoreBackupDialog(backupService: ref.read(backupServiceProvider)),
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
    final syncCounts =
        ref.watch(syncQueueCountsProvider).value ??
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
      appBar: AppBar(
        title: Semantics(
          header: true,
          child: const Text('Configurações e Segurança'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Seção: Sincronização
          Semantics(
            header: true,
            child: const Text(
              'Sincronização e Nuvem',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
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
                        : 'Dados locais; a sincronização com a nuvem está pausada.',
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
                    backgroundColor:
                        (syncCounts.conflict > 0 || syncCounts.failed > 0)
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
                        child: Semantics(
                          button: true,
                          container: true,
                          excludeSemantics: true,
                          label: 'Abrir gerenciamento da fila de sincronização',
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
                            label: Text(
                              'Reprocessar ${syncCounts.failed} Falha(s) Agora',
                            ),
                            onPressed: () async {
                              final repo = ref.read(repositoryProvider);
                              await repo.retryAllFailedOperations();
                              final res = await ref
                                  .read(supabaseSyncServiceProvider)
                                  .sync();
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
                  leading: const Icon(
                    Icons.import_export,
                    color: AppTheme.primaryBlue,
                  ),
                  title: const Text('Importar / Exportar Calendário'),
                  subtitle: const Text('Arquivos .ics e URL de calendário.'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const AppointmentsScreen(calendarToolsOnly: true),
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
                  leading: const Icon(
                    Icons.account_circle,
                    color: Color(0xFF4285F4),
                  ),
                  title: const Text('Conta Google Conectada'),
                  subtitle: Text(
                    _isGoogleConnected
                        ? 'Conectado como: ${_googleAccountEmail ?? "Conta ativa"}'
                        : 'Nenhuma conta Google conectada',
                  ),
                  trailing: _isGoogleConnected
                      ? Wrap(
                          spacing: 4,
                          children: [
                            TextButton(
                              onPressed: () async {
                                final coord = ref.read(
                                  calendarSyncCoordinatorProvider,
                                );
                                final ok = await coord.googleProvider
                                    .requestAuthorization();
                                if (ok) {
                                  await _loadGoogleStatus();
                                } else if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        coord.googleProvider.lastError ?? 'Não foi possível autenticar com a conta Google.',
                                      ),
                                    ),
                                  );
                                }
                              },
                              child: const Text('Trocar'),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.link_off,
                                color: Colors.redAccent,
                              ),
                              tooltip: 'Desconectar Conta Google',
                              onPressed: () async {
                                final coord = ref.read(
                                  calendarSyncCoordinatorProvider,
                                );
                                await coord.googleProvider.disconnect();
                                await _loadGoogleStatus();
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Conta Google desconectada com sucesso.',
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        )
                      : ElevatedButton.icon(
                          icon: const Icon(Icons.login, size: 16),
                          label: const Text('Conectar'),
                          onPressed: () async {
                            final coord = ref.read(
                              calendarSyncCoordinatorProvider,
                            );
                            final ok = await coord.googleProvider
                                .requestAuthorization();
                            if (ok) {
                              await _loadGoogleStatus();
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Conta Google conectada com sucesso!',
                                  ),
                                ),
                              );
                            } else if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    coord.googleProvider.lastError ?? 'Não foi possível conectar a conta Google.',
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

          // Seção: E-mail Teocrático, Multi-contas e Contatos
          const Text(
            'Contas de E-mail & Contatos (Multi-contas)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildMultiAccountsConfigCard(isDark),
          _buildEmailContactsRegistryCard(isDark),
          _buildJwEmailConfigCard(isDark),
          _buildExchangeConfigCard(),

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
                              Icons.sd_storage_outlined,
                              color: AppTheme.successGreen,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Backup Local Automático',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                'Cópia criptografada no dispositivo (não é nuvem)',
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
                                  _lastSilentBackupFuture = backupSvc
                                      .getLastSilentBackupDate();
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

          // Seção: Biblioteca Offline (Bíblias e Publicações EPUB)
          const Text(
            'Biblioteca Offline',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              key: const Key('btn_open_offline_library'),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.library_books_outlined,
                  color: AppTheme.primaryBlue,
                ),
              ),
              title: const Text('Bíblias e Publicações (.epub / .json)'),
              subtitle: Text(
                '$_importedBiblesCount Bíblia(s) • $_importedPublicationsCount publicação(ões) importada(s)\n'
                'Importe traduções em múltiplos idiomas para comparação e publicações para a lista de referências.',
              ),
              isThreeLine: true,
              trailing: const Icon(Icons.chevron_right),
              onTap: _openOfflineLibrary,
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
                color: _hasPinConfigured
                    ? AppTheme.successGreen
                    : AppTheme.alertAmber,
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
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Gere contatos, visitas, estudos e compromissos fictícios para demonstrar o aplicativo ou zerar todos os dados locais.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? const Color(0xFFCBD5E1)
                          : AppTheme.textMuted,
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
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
                                content: Text(
                                  'Dados de demonstração gerados com sucesso!',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFD97706),
                          side: const BorderSide(color: Color(0xFFD97706)),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                        label: const Text(
                          'Remover Demonstração',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: () async {
                          final repo = ref.read(repositoryProvider);
                          final count = await DemoDataGenerator.clearDemoData(
                            repo,
                          );
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        icon: const Icon(
                          Icons.delete_forever_outlined,
                          size: 18,
                        ),
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
                                'Esta ação apaga os registros e as configurações do banco local, inclusive alterações ainda não sincronizadas. A sincronização está pausada: os dados da nuvem não serão restaurados automaticamente. Verifique um backup antes de continuar. Arquivos de mídia, backups, credenciais e dados na nuvem não serão apagados.\n\nDeseja continuar?',
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
                            final db = ref.read(databaseProvider);
                            await db
                                .into(db.appKvStore)
                                .insertOnConflictUpdate(
                                  AppKvStoreCompanion.insert(
                                    key: 'ticuna_skip_initial_seed',
                                    value: 'true',
                                    updatedAt: Value(DateTime.now()),
                                  ),
                                );
                            await ref
                                .read(ticunaAudioServiceProvider)
                                .clearAllAudioFiles();
                            ref
                                .read(ticunaRepositoryProvider)
                                .clearStreamsOnReset();
                            ref.invalidate(ticunaRepositoryProvider);
                            ref.invalidate(ticunaWordsStreamProvider);
                            ref.invalidate(ticunaPhrasesStreamProvider);
                            ref.invalidate(ticunaTagsStreamProvider);
                            ref.invalidate(languagesStreamProvider);
                            ref.invalidate(activeLanguageProvider);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Banco de dados local zerado com sucesso!',
                                  ),
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
}
