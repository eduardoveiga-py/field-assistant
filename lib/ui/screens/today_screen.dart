import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_logger.dart';
import '../../core/app_theme.dart';
import '../../core/date_utils.dart';
import '../../contacts/person_hand_off_helper.dart';
import '../../sync/supabase_sync_service.dart';
import '../../sync/sync_privacy_policy.dart';
import '../widgets/e2ee_setup_dialog.dart';
import '../../territory/geocoding_service.dart';
import '../../territory/sector_manager.dart';
import '../providers.dart';
import '../widgets/add_person_dialog.dart';
import '../widgets/managed_text_controllers.dart';
import '../widgets/map_location_picker_dialog.dart';
import '../widgets/rich_formatted_editing_controller.dart';
import '../widgets/rich_markdown_toolbar.dart';
import 'activities_screen.dart';
import 'contacts_map_screen.dart';
import 'person_detail_screen.dart';
import 'sector_detail_screen.dart';
import '../../core/feature_registry.dart';
import '../../core/update_checker_service.dart';
import 'settings_screen.dart';
import 'global_search_screen.dart';
import 'next_actions_screen.dart';
import 'inbox_screen.dart';
import '../widgets/schedule_conflict_resolution_banner.dart';
import 'tasks_screen.dart';
import 'knowledge_base_screen.dart';
import '../widgets/quick_capture_sheet.dart';

class TodayScreen extends ConsumerWidget {
  final Function(int)? onTabChange;
  final Function(AppFeature)? onFeatureNavigate;

  const TodayScreen({super.key, this.onTabChange, this.onFeatureNavigate});

  User? _getCurrentSupabaseUser() {
    if (!SupabaseSyncService.isInitialized) return null;
    try {
      return Supabase.instance.client.auth.currentUser;
    } catch (e, st) {
      AppLogger.debug(
        'Supabase não inicializado ao consultar usuário na Home: $e',
        st,
      );
      return null;
    }
  }

  void _navigateTo(AppFeature feature) {
    if (onFeatureNavigate != null) {
      onFeatureNavigate!(feature);
    } else if (onTabChange != null) {
      onTabChange!(_featureToLegacyIndex(feature));
    }
  }

  static int _featureToLegacyIndex(AppFeature feature) {
    switch (feature) {
      case AppFeature.today:
        return 0;
      case AppFeature.people:
        return 1;
      case AppFeature.phones:
        return 2;
      case AppFeature.agenda:
        return 3;
      case AppFeature.studies:
        return 4;
      case AppFeature.dashboard:
        return 5;
      case AppFeature.experiences:
        return 6;
      case AppFeature.notesResearch:
        return 7;
      case AppFeature.ticuna:
        return 9;
      case AppFeature.territoryMaps:
        return 1;
      case AppFeature.inbox:
      case AppFeature.tasksProjects:
      case AppFeature.knowledge:
      case AppFeature.pictureBank:
      case AppFeature.officialDocuments:
        return 0;
    }
  }

  void _showSyncStatusModal(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(repositoryProvider);
    final pendingOps = await repo.getPendingSyncOperations();
    final currentUser = _getCurrentSupabaseUser();
    final e2ee = ref.read(e2eeServiceProvider);
    final ownerId = currentUser?.id ?? 'local_user';
    final isE2eeReady = currentUser != null
        ? await e2ee.isKeyInstalled(ownerId)
        : false;
    final isWebPinLocked = currentUser != null && !isE2eeReady
        ? await e2ee.isWebPinLocked(ownerId)
        : false;
    final cloudSyncEnabled = SyncPrivacyPolicy.canRunRemoteSync();

    if (!context.mounted) return;

    final statusTitle = currentUser == null
        ? 'Modo Offline-First ativo. Seus dados estão preservados localmente.'
        : (!cloudSyncEnabled
              ? 'Conectado (${currentUser.email ?? "Usuário"}) — Sincronização em nuvem pausada nesta compilação.'
              : (isE2eeReady
                    ? 'Conectado ao Supabase: ${currentUser.email ?? "Usuário autenticado"}'
                    : (isWebPinLocked
                          ? 'Cofre E2EE bloqueado por PIN neste navegador (${currentUser.email ?? "Usuário"})'
                          : 'Chave E2EE pendente neste aparelho (${currentUser.email ?? "Usuário"})')));
    final statusSubtitle = currentUser == null
        ? 'Modo offline-first. Conecte sua conta e configure a chave E2EE para sincronizar na nuvem.'
        : (isE2eeReady
              ? 'Conta conectada com Criptografia de Ponta a Ponta (E2EE) desbloqueada neste dispositivo.'
              : (isWebPinLocked
                    ? 'Digite seu PIN de desbloqueio rápido para liberar a sincronização multi-dispositivos.'
                    : 'Restaure sua frase de 24 palavras para sincronizar notas, e-mails e registros entre dispositivos.'));
    final isFullyActive =
        currentUser != null && cloudSyncEnabled && isE2eeReady;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isFullyActive
                        ? Icons.verified_user_rounded
                        : (isWebPinLocked
                              ? Icons.lock_clock_outlined
                              : Icons.cloud_off),
                    color: isFullyActive
                        ? AppTheme.successGreen
                        : (currentUser != null
                              ? Colors.orange.shade700
                              : AppTheme.primaryBlue),
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Conta Supabase & Sincronização',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isFullyActive
                      ? AppTheme.successGreen.withValues(alpha: 0.12)
                      : (currentUser != null
                            ? Colors.amber.withValues(alpha: 0.12)
                            : const Color(0xFFEFF6FF)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isFullyActive
                        ? AppTheme.successGreen.withValues(alpha: 0.35)
                        : (currentUser != null
                              ? Colors.amber.withValues(alpha: 0.45)
                              : AppTheme.primaryBlue.withValues(alpha: 0.25)),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isFullyActive
                          ? Icons.verified_user_rounded
                          : (currentUser != null
                                ? Icons.shield_outlined
                                : Icons.check_circle),
                      color: isFullyActive
                          ? AppTheme.successGreen
                          : (currentUser != null
                                ? Colors.amber.shade900
                                : AppTheme.primaryBlue),
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            statusTitle,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isFullyActive
                                  ? AppTheme.successGreen
                                  : (currentUser != null
                                        ? Colors.amber.shade900
                                        : Colors.blue.shade900),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            statusSubtitle,
                            style: const TextStyle(fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text('• Operações na fila local pendentes: ${pendingOps.length}'),
              const SizedBox(height: 4),
              const Text('• Backend de destino: Supabase (PostgreSQL)'),
              const SizedBox(height: 4),
              Text(
                '• Última checagem: ${AppDateUtils.formatDateTime(DateTime.now())}',
              ),
              const SizedBox(height: 18),
              if (currentUser != null && !isE2eeReady) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: Icon(
                      isWebPinLocked ? Icons.lock_open : Icons.key_rounded,
                    ),
                    label: Text(
                      isWebPinLocked
                          ? 'Desbloquear Cofre E2EE (PIN)'
                          : 'Configurar / Restaurar Chave E2EE',
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      if (isWebPinLocked) {
                        await WebPinUnlockDialog.show(context, userId: ownerId);
                      } else {
                        await E2eeSetupDialog.show(context, userId: ownerId);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 10),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.sync),
                  label: const Text('Sincronizar Agora com o Supabase'),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final res = await ref
                        .read(supabaseSyncServiceProvider)
                        .sync();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(res.message)));
                    }
                  },
                ),
              ),
              if (currentUser != null) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.alertRed,
                      side: BorderSide(
                        color: AppTheme.alertRed.withValues(alpha: 0.5),
                      ),
                    ),
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Sair da Conta (Logout)'),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      try {
                        await Supabase.instance.client.auth.signOut();
                      } catch (e, st) {
                        AppLogger.warning(
                          'Falha ao encerrar sessão Supabase na tela Hoje',
                          e,
                          st,
                        );
                      }
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showManageSectorsModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => ManagedTextControllers(
        initialTexts: const ['', ''],
        builder: (ctx, ctrls) {
          final nameController = ctrls[0];
          final descController = ctrls[1];

          return Consumer(
            builder: (ctx, innerRef, _) {
              final sectors = innerRef.watch(sectorsStreamProvider).value ?? [];
              final mgr = innerRef.read(sectorManagerProvider);

              return SafeArea(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.85,
                  ),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      top: 20,
                      left: 16,
                      right: 16,
                      bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.holiday_village,
                                  color: AppTheme.accentTeal,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Gerenciar Bairros / Setores',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Adicionar Novo Bairro / Setor:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: nameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Nome do Bairro',
                                    hintText: 'Ex: Centro, São Francisco, Beira-Rio...',
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: descController,
                                  decoration: const InputDecoration(
                                    labelText: 'Descrição / Limites (opcional)',
                                    hintText: 'Ex: Da avenida até o rio',
                                  ),
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.add),
                                    label: const Text('Cadastrar Bairro'),
                                    onPressed: () async {
                                      final name = nameController.text.trim();
                                      if (name.isEmpty) return;
                                      await mgr.addSector(
                                        name,
                                        description: descController.text.trim(),
                                      );
                                      nameController.clear();
                                      descController.clear();
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Bairros Cadastrados no Território:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (sectors.isEmpty)
                          Text(
                            'Nenhum bairro cadastrado.',
                            style: TextStyle(
                              color: Theme.of(ctx).brightness == Brightness.dark
                                  ? const Color(0xFFCBD5E1)
                                  : AppTheme.textMuted,
                            ),
                          )
                        else
                          for (final s in sectors)
                            Card(
                              margin: const EdgeInsets.only(bottom: 6),
                              child: ListTile(
                                leading: const Icon(
                                  Icons.location_city,
                                  color: AppTheme.primaryBlue,
                                ),
                                title: Text(
                                  s.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  s.description?.isNotEmpty == true
                                      ? s.description!
                                      : 'Setor do território',
                                ),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: AppTheme.alertRed,
                                    size: 20,
                                  ),
                                  tooltip: 'Excluir setor',
                                  onPressed: () async {
                                    await mgr.deleteSector(s.id);
                                  },
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddForeignContactDialog(BuildContext context, WidgetRef ref) {
    bool sendViaWhatsApp = true;

    showDialog(
      context: context,
      builder: (dialogCtx) => ManagedTextControllers(
        initialTexts: const ['', '', '', '', '', '', '', ''],
        customFactories: [
          null,
          null,
          null,
          null,
          null,
          null,
          (text) => RichFormattedEditingController.fromMarkup(text),
          null,
        ],
        builder: (dialogCtx, ctrls) {
          final nameController = ctrls[0];
          final langController = ctrls[1];
          final phoneController = ctrls[2];
          final addressController = ctrls[3];
          final latController = ctrls[4];
          final lngController = ctrls[5];
          final notesController = ctrls[6];
          final scheduleController = ctrls[7];

          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              return AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.public, color: AppTheme.primaryBlue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '🌍 Novo Contato Estrangeiro',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nome da Pessoa *',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: langController,
                        decoration: const InputDecoration(
                          labelText: 'Idioma / Língua Falada *',
                          hintText: 'Ex: Espanhol, Inglês, Francês, Mandarim, Crioulo...',
                          prefixIcon: Icon(Icons.translate),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Telefone / WhatsApp',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: addressController,
                        decoration: const InputDecoration(
                          labelText: 'Endereço / Referência',
                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.accentTeal,
                                side: const BorderSide(
                                  color: AppTheme.accentTeal,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                              ),
                              icon: const Icon(Icons.map, size: 16),
                              label: const Text(
                                '🗺️ Pinar Localização',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onPressed: () async {
                                final initialLat = double.tryParse(
                                  latController.text.trim(),
                                );
                                final initialLng = double.tryParse(
                                  lngController.text.trim(),
                                );
                                final res =
                                    await showDialog<ReverseGeocodingResult>(
                                      context: context,
                                      builder: (_) => MapLocationPickerDialog(
                                        initialLat: initialLat,
                                        initialLng: initialLng,
                                        initialAddress: addressController.text
                                            .trim(),
                                      ),
                                    );
                                if (res != null) {
                                  setDialogState(() {
                                    latController.text = res.latitude
                                        .toStringAsFixed(6);
                                    lngController.text = res.longitude
                                        .toStringAsFixed(6);
                                    if (addressController.text.trim().isEmpty &&
                                        res.streetAndNumber.isNotEmpty) {
                                      addressController.text =
                                          res.formattedSummary;
                                    }
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      if (latController.text.isNotEmpty &&
                          lngController.text.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          '📍 GPS: ${latController.text}, ${lngController.text}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.accentTeal,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      TextField(
                        controller: scheduleController,
                        decoration: const InputDecoration(
                          labelText: 'Melhor Horário para Encontrar',
                          hintText: 'Ex: Sábado de manhã, Terça após 18h',
                          prefixIcon: Icon(Icons.access_time),
                        ),
                      ),
                      const SizedBox(height: 10),
                      RichMarkdownToolbar(
                        controller: notesController,
                        enableHighlightPalette: false,
                        enableImagePicker: false,
                        enableCrossReferences: true,
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: notesController,
                        decoration: const InputDecoration(
                          labelText: 'Observações / Publicação Deixada',
                          hintText: 'Ex: Ficou com folheto em espanhol, aceitou visita',
                          prefixIcon: Icon(Icons.note_alt_outlined),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Encaminhar para Irmão Responsável via WhatsApp',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        value: sendViaWhatsApp,
                        onChanged: (val) =>
                            setDialogState(() => sendViaWhatsApp = val ?? true),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: const Text('Cancelar'),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check),
                    label: const Text('Salvar Contato'),
                    onPressed: () async {
                      final name = nameController.text.trim();
                      if (name.isEmpty) return;
                      final lang = langController.text.trim();
                      final lat = double.tryParse(latController.text.trim());
                      final lng = double.tryParse(lngController.text.trim());

                      final additionalNotes =
                          RichFormattedEditingController.readMarkup(
                            notesController,
                          ).trim();
                      final repo = ref.read(repositoryProvider);
                      final person = await repo.createPerson(
                        name: name,
                        status: 'interessado',
                        phone: phoneController.text.trim().isEmpty
                            ? null
                            : phoneController.text.trim(),
                        address: addressController.text.trim().isEmpty
                            ? null
                            : addressController.text.trim(),
                        latitude: lat,
                        longitude: lng,
                        preferredSchedule:
                            scheduleController.text.trim().isEmpty
                            ? null
                            : scheduleController.text.trim(),
                        generalNotes: additionalNotes.isEmpty
                            ? (lang.isNotEmpty ? 'Idioma falado: $lang' : null)
                            : '$additionalNotes${lang.isNotEmpty ? "\nIdioma: $lang" : ""}',
                        tags: ['estrangeiro', if (lang.isNotEmpty) lang],
                      );

                      if (dialogCtx.mounted) Navigator.pop(dialogCtx);

                      if (sendViaWhatsApp) {
                        await PersonHandOffHelper.sendViaWhatsApp(
                          person: person,
                          language: lang.isNotEmpty ? lang : null,
                          additionalNotes: additionalNotes.isEmpty
                              ? null
                              : additionalNotes,
                        );
                      }

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Contato estrangeiro ($name) registrado com sucesso!',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ],
              );
            },
          );
        },
      ),
    );
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
    return (month >= 1 && month <= 12) ? months[month - 1] : '';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appointmentsAsync = ref.watch(appointmentsStreamProvider);
    final peopleAsync = ref.watch(peopleStreamProvider);
    final sectors = ref.watch(sectorsStreamProvider).value ?? [];
    final people = peopleAsync.value ?? [];
    final passedPersonIds = people
        .where((p) => p.status.toLowerCase() == 'revisita_passada')
        .map((p) => p.id)
        .toSet();
    final activities = ref.watch(activitiesStreamProvider).value ?? [];
    final studies = ref.watch(studiesStreamProvider).value ?? [];
    final sessions = ref.watch(studySessionsStreamProvider).value ?? [];
    final isSunMode = ref.watch(sunModeProvider);
    final supabaseUser = _getCurrentSupabaseUser();

    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    int totalMonthSeconds = 0;
    for (final act in activities) {
      if (act.deletedAt != null) continue;
      if (act.date.isAfter(monthStart.subtract(const Duration(seconds: 1))) &&
          act.date.isBefore(monthEnd.add(const Duration(seconds: 1)))) {
        totalMonthSeconds += act.durationSeconds;
      }
    }
    final monthHours = totalMonthSeconds / 3600.0;
    const int hourGoal = 50;
    final progressFraction = (monthHours / hourGoal).clamp(0.0, 1.0);
    final hoursFormatted = AppDateUtils.formatDuration(totalMonthSeconds);

    final monthHeldSessions = sessions
        .where(
          (s) =>
              s.deletedAt == null &&
              s.status.toLowerCase() == 'realizada' &&
              s.dateTimeField.isAfter(
                monthStart.subtract(const Duration(seconds: 1)),
              ) &&
              s.dateTimeField.isBefore(
                monthEnd.add(const Duration(seconds: 1)),
              ),
        )
        .toList();

    final activeStudiesCount = studies.where((s) {
      if (s.deletedAt != null) return false;
      final hadSessionThisMonth =
          monthHeldSessions.any((sess) => sess.studyId == s.id) ||
          (s.lastSessionAt != null &&
              !s.lastSessionAt!.isBefore(monthStart) &&
              !s.lastSessionAt!.isAfter(monthEnd));
      if (hadSessionThisMonth) return true;
      if (s.startedAt.isAfter(monthEnd)) return false;
      return s.status == 'ativo';
    }).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          MediaQuery.sizeOf(context).width < 600
              ? 'Hoje'
              : 'Hoje no Ministério',
        ),
        actions: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.search, size: 20),
            tooltip: 'Busca Global Unificada',
            onPressed: () {
              showSearch(
                context: context,
                delegate: GlobalSearchDelegate(ref: ref),
              );
            },
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(
              isSunMode ? Icons.wb_sunny : Icons.wb_sunny_outlined,
              size: 20,
              color: isSunMode
                  ? Colors.amber
                  : (isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B)),
            ),
            tooltip: isSunMode
                ? 'Desativar Modo Sol'
                : '☀️ Modo Sol Intenso (Alto Contraste)',
            onPressed: () {
              ref.read(sunModeProvider.notifier).state = !isSunMode;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    !isSunMode
                        ? '☀️ Modo Sol Intenso e Alto Contraste ativado!'
                        : 'Modo normal restaurado.',
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
          Tooltip(
            message: supabaseUser != null
                ? 'Supabase Online'
                : 'Salvo Localmente',
            child: InkWell(
              onTap: () => _showSyncStatusModal(context, ref),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.07)
                        : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF10B981),
                      ),
                    ),
                    if (MediaQuery.sizeOf(context).width >= 600) ...[
                      const SizedBox(width: 6),
                      Text(
                        supabaseUser != null
                            ? 'Supabase Online'
                            : 'Salvo Localmente',
                        style: TextStyle(
                          color: isDark
                              ? const Color(0xFFCBD5E1)
                              : const Color(0xFF475569),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Consumer(
            builder: (ctx, ref, _) {
              final inboxEnabled = ref.watch(
                isFeatureEnabledProvider(AppFeature.inbox),
              );
              if (!inboxEnabled) return const SizedBox.shrink();
              final countAsync = ref.watch(unreadEmailsCountProvider);
              final count = countAsync.value ?? 0;
              return IconButton(
                key: const Key('btn_today_inbox_unread_badge'),
                visualDensity: VisualDensity.compact,
                icon: Badge(
                  isLabelVisible: count > 0,
                  backgroundColor: isDark
                      ? const Color(0xFF3B82F6)
                      : const Color(0xFF2563EB),
                  label: Text('$count'),
                  child: const Icon(Icons.all_inbox_rounded, size: 20),
                ),
                tooltip: count > 0
                    ? 'Inbox ($count ${count == 1 ? 'e-mail não lido' : 'e-mails não lidos'})'
                    : 'Inbox (nenhum e-mail não lido)',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const InboxScreen()),
                  );
                },
              );
            },
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.timer_outlined, size: 20),
            tooltip: 'Atividades e Metas',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ActivitiesScreen()),
              );
            },
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.settings_outlined, size: 20),
            tooltip: 'Ajustes e Backup',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Captura Rápida (Inbox)',
        backgroundColor: isDark
            ? const Color(0xFF3B82F6)
            : const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        elevation: 2,
        onPressed: () => QuickCaptureSheet.show(context),
        child: const Icon(Icons.add, size: 26),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ScheduleConflictResolutionBanner(),
            // Cabeçalho de saudação tipográfico limpo (sem caixa laranja)
            Builder(
              builder: (ctx) {
                final hour = now.hour;
                final String greetingTitle = hour < 12
                    ? 'Bom dia no ministério!'
                    : (hour < 18 ? 'Boa tarde de serviço!' : 'Boa noite!');
                final String greetingSubtitle = hour < 12
                    ? 'Que Jeová abençoe seu ministério nesta manhã.'
                    : (hour < 18
                          ? 'Renove suas forças para as revisitas da tarde.'
                          : 'Hora de revisar as conversas e bênçãos do dia.');

                final updateInfo = ref.watch(updateCheckStateProvider).value;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (updateInfo != null && updateInfo.hasUpdate)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color:
                              (isDark
                                      ? const Color(0xFF3B82F6)
                                      : const Color(0xFF2563EB))
                                  .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                (isDark
                                        ? const Color(0xFF3B82F6)
                                        : const Color(0xFF2563EB))
                                    .withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.system_update_rounded,
                              color: Color(0xFF2563EB),
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Atualização Disponível: v${updateInfo.latestVersion}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const Text(
                                    'Toque para instalar a nova versão.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                minimumSize: Size.zero,
                              ),
                              onPressed: () {
                                ref
                                    .read(updateCheckerServiceProvider)
                                    .launchUpdate(updateInfo);
                              },
                              child: const Text(
                                'Atualizar',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 560;
                        final dateWidget = Text(
                          '${AppDateUtils.formatDate(now)} • Foco do Dia',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                          ),
                        );

                        if (isWide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      greetingTitle,
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.5,
                                        color: isDark
                                            ? const Color(0xFFF8FAFC)
                                            : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      greetingSubtitle,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        color: isDark
                                            ? const Color(0xFF94A3B8)
                                            : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              dateWidget,
                            ],
                          );
                        } else {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                greetingTitle,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.4,
                                  color: isDark
                                      ? const Color(0xFFF8FAFC)
                                      : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                greetingSubtitle,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 6),
                              dateWidget,
                            ],
                          );
                        }
                      },
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),

            // Bloco "Progresso • Mês" sem caixas dentro de caixas
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Progresso • ${_getMonthName(now.month)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: isDark
                          ? const Color(0xFFF8FAFC)
                          : const Color(0xFF0F172A),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _navigateTo(AppFeature.dashboard),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Detalhes',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? const Color(0xFF3B82F6)
                                : const Color(0xFF2563EB),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: isDark
                              ? const Color(0xFF3B82F6)
                              : const Color(0xFF2563EB),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            LayoutBuilder(
              builder: (context, constraints) {
                final stackVertical = constraints.maxWidth < 320;

                Widget buildHoursCard() {
                  return InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ActivitiesScreen(),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF131A29) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.07)
                              : const Color(0xFFE2E8F0),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Horas Realizadas',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: isDark
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.timer_outlined,
                                size: 16,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            hoursFormatted,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                              color: isDark
                                  ? const Color(0xFFF8FAFC)
                                  : const Color(0xFF0F172A),
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progressFraction,
                              minHeight: 4,
                              backgroundColor: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : const Color(0xFFE2E8F0),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isDark
                                    ? const Color(0xFF3B82F6)
                                    : const Color(0xFF2563EB),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Meta: ${hourGoal}h (${(progressFraction * 100).toStringAsFixed(0)}%)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                Widget buildStudiesCard() {
                  return InkWell(
                    onTap: () => _navigateTo(AppFeature.studies),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF131A29) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.07)
                              : const Color(0xFFE2E8F0),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Estudos',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: isDark
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.school_outlined,
                                size: 16,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$activeStudiesCount',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                              color: isDark
                                  ? const Color(0xFFF8FAFC)
                                  : const Color(0xFF0F172A),
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.07)
                                    : const Color(0xFFE2E8F0),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              activeStudiesCount == 1
                                  ? '1 ativo no mês'
                                  : '$activeStudiesCount ativos no mês',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (stackVertical) {
                  return Column(
                    children: [
                      buildHoursCard(),
                      const SizedBox(height: 10),
                      buildStudiesCard(),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: buildHoursCard()),
                    const SizedBox(width: 10),
                    Expanded(child: buildStudiesCard()),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),

            // Chips de filtro sem emojis duplicados (apenas 1 ícone vetorial limpo)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildShortcutPill(
                    context,
                    ref,
                    'principais',
                    'Principais',
                    Icons.star_rounded,
                    isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildShortcutPill(
                    context,
                    ref,
                    'ministerio',
                    'Ministério',
                    Icons.menu_book_rounded,
                    isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildShortcutPill(
                    context,
                    ref,
                    'produtividade',
                    'Produtividade',
                    Icons.bolt_rounded,
                    isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildShortcutPill(
                    context,
                    ref,
                    'todos',
                    'Todos (13)',
                    Icons.grid_view_rounded,
                    isDark,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            _buildCompactShortcutsGrid(context, ref, isDark),
            const SizedBox(height: 20),

            // SEÇÃO: Bairros / Setores do Território
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Bairros / Setores do Território',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppTheme.textDark,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.settings, size: 16),
                  label: const Text(
                    'Gerenciar',
                    style: TextStyle(fontSize: 12),
                  ),
                  onPressed: () => _showManageSectorsModal(context, ref),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (sectors.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Nenhum bairro cadastrado.'),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Cadastrar Bairros'),
                        onPressed: () => _showManageSectorsModal(context, ref),
                      ),
                    ],
                  ),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: sectors.map((sector) {
                    final sectorLower = sector.name.toLowerCase().trim();
                    final count = people.where((p) {
                      if (p.deletedAt != null) return false;
                      final addr = (p.address ?? '').toLowerCase();
                      final tags = p.tags.toLowerCase();
                      final notes = (p.generalNotes ?? '').toLowerCase();
                      return addr.contains(sectorLower) ||
                          tags.contains(sectorLower) ||
                          notes.contains(sectorLower);
                    }).length;

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        avatar: const Icon(
                          Icons.holiday_village,
                          size: 16,
                          color: AppTheme.accentTeal,
                        ),
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              sector.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.accentTeal.withValues(
                                  alpha: 0.2,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$count',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.accentTeal,
                                ),
                              ),
                            ),
                          ],
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  SectorDetailScreen(sector: sector),
                            ),
                          );
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            const SizedBox(height: 24),

            // Seção: Próximos Compromissos de Hoje
            Text(
              'Próximos Compromissos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 8),
            appointmentsAsync.when(
              data: (appts) {
                final todayAppts = appts
                    .where(
                      (a) =>
                          (a.personId == null ||
                              !passedPersonIds.contains(a.personId)) &&
                          a.startTime.day == now.day &&
                          a.startTime.month == now.month &&
                          a.startTime.year == now.year &&
                          a.status != 'cancelado' &&
                          a.status != 'reagendado',
                    )
                    .toList();

                if (todayAppts.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.event_available,
                            color: Colors.grey.shade400,
                            size: 36,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Nenhum compromisso marcado para hoje. Toque em Agenda para agendar.',
                              style: TextStyle(
                                color: isDark
                                    ? const Color(0xFFCBD5E1)
                                    : AppTheme.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  children: todayAppts.map((a) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color:
                                (isDark
                                        ? const Color(0xFF60A5FA)
                                        : AppTheme.primaryBlue)
                                    .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            AppDateUtils.formatTime(a.startTime),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? const Color(0xFF93C5FD)
                                  : AppTheme.primaryBlue,
                            ),
                          ),
                        ),
                        title: Text(
                          a.title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Duração: ${a.durationMinutes} min • Status: ${a.status}',
                          style: const TextStyle(fontSize: 13),
                        ),
                        trailing: a.isProvisional
                            ? const Chip(
                                label: Text(
                                  'Provisório',
                                  style: TextStyle(fontSize: 11),
                                ),
                                backgroundColor: Color(0xFFFEF3C7),
                              )
                            : const Icon(Icons.chevron_right),
                        onTap: () {
                          if (a.personId != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    PersonDetailScreen(personId: a.personId!),
                              ),
                            );
                          } else {
                            _navigateTo(AppFeature.agenda);
                          }
                        },
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text('Erro ao carregar agenda: $err'),
            ),
            const SizedBox(height: 24),

            // Seção: Retornos e Ações Pendentes
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Ações e Revisitas Pendentes',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppTheme.textDark,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.tune, size: 16),
                  label: const Text('Ver Categorias'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NextActionsScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),

            peopleAsync.when(
              data: (people) {
                final pending = people
                    .where(
                      (p) =>
                          p.status.toLowerCase() != 'revisita_passada' &&
                          p.nextActionAt != null &&
                          p.nextActionAt!.isBefore(
                            now.add(const Duration(days: 1)),
                          ),
                    )
                    .toList();

                if (pending.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            color: AppTheme.successGreen,
                            size: 36,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Todas as revisitas e ações combinadas estão em dia!',
                              style: TextStyle(
                                color: isDark
                                    ? const Color(0xFFCBD5E1)
                                    : AppTheme.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  children: pending.map((p) {
                    final isOverdue = p.nextActionAt!.isBefore(now);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isOverdue
                              ? AppTheme.alertRed.withValues(alpha: 0.1)
                              : AppTheme.accentTeal.withValues(alpha: 0.1),
                          child: Icon(
                            isOverdue
                                ? Icons.warning_amber_rounded
                                : Icons.schedule,
                            color: isOverdue
                                ? AppTheme.alertRed
                                : AppTheme.accentTeal,
                          ),
                        ),
                        title: Text(
                          p.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${p.nextActionNote ?? "Sem anotação"} • Data: ${AppDateUtils.formatDate(p.nextActionAt)}',
                          style: TextStyle(
                            color: isOverdue
                                ? AppTheme.alertRed
                                : (isDark
                                      ? const Color(0xFFCBD5E1)
                                      : AppTheme.textMuted),
                            fontWeight: isOverdue
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  PersonDetailScreen(personId: p.id),
                            ),
                          );
                        },
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text('Erro ao carregar contatos: $err'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildShortcutPill(
    BuildContext context,
    WidgetRef ref,
    String key,
    String label,
    IconData icon,
    bool isDark,
  ) {
    final current = ref.watch(todayShortcutsCategoryProvider);
    final isSelected = current == key;
    final primary = isDark ? const Color(0xFF3B82F6) : const Color(0xFF2563EB);

    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 15,
        color: isSelected
            ? Colors.white
            : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
      ),
      label: Text(label),
      selected: isSelected,
      selectedColor: primary,
      backgroundColor: isDark ? const Color(0xFF131A29) : Colors.white,
      side: BorderSide(
        color: isSelected
            ? Colors.transparent
            : (isDark
                  ? Colors.white.withValues(alpha: 0.07)
                  : const Color(0xFFE2E8F0)),
        width: 1,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      labelStyle: TextStyle(
        color: isSelected
            ? Colors.white
            : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
        fontSize: 12.5,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
      ),
      onSelected: (_) {
        ref.read(todayShortcutsCategoryProvider.notifier).state = key;
      },
    );
  }

  Widget _buildCompactShortcutsGrid(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
  ) {
    final category = ref.watch(todayShortcutsCategoryProvider);
    final people = ref.watch(peopleStreamProvider).value ?? [];
    final revisitasCount = people
        .where(
          (p) => p.deletedAt == null && p.status.toLowerCase() == 'revisita',
        )
        .length;
    final activities = ref.watch(activitiesStreamProvider).value ?? [];
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    int totalMonthSeconds = 0;
    for (final act in activities) {
      if (act.deletedAt != null) continue;
      if (act.date.isAfter(monthStart.subtract(const Duration(seconds: 1))) &&
          act.date.isBefore(monthEnd.add(const Duration(seconds: 1)))) {
        totalMonthSeconds += act.durationSeconds;
      }
    }
    final hoursFormatted = AppDateUtils.formatDuration(totalMonthSeconds);
    final studies = ref.watch(studiesStreamProvider).value ?? [];
    final activeStudiesCount = studies
        .where((s) => s.deletedAt == null && s.status == 'ativo')
        .length;
    final inboxCount = ref.watch(unprocessedInboxCountProvider).value ?? 0;

    final btnNovaPessoa = _QuickActionButton(
      icon: Icons.person_add_outlined,
      label: 'Nova Pessoa',
      subtitle: 'Cadastrar contato',
      onTap: () => showAddPersonDialog(context, ref),
    );
    final btnRevisitas = _QuickActionButton(
      icon: Icons.repeat,
      label: 'Revisitas',
      subtitle: revisitasCount > 0 ? '$revisitasCount contatos' : 'Retornos',
      onTap: () {
        ref.read(peopleFilterProvider.notifier).state = 'Revisitas';
        _navigateTo(AppFeature.people);
      },
    );
    final btnEstudos = _QuickActionButton(
      icon: Icons.menu_book_outlined,
      label: 'Estudos',
      subtitle: activeStudiesCount > 0
          ? '$activeStudiesCount ativos'
          : 'Estudos bíblicos',
      onTap: () => _navigateTo(AppFeature.studies),
    );
    final btnAtividade = _QuickActionButton(
      icon: Icons.timer_outlined,
      label: 'Atividade',
      subtitle: totalMonthSeconds > 0 ? hoursFormatted : 'Registrar horas',
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ActivitiesScreen()),
        );
      },
    );
    final btnMapa = _QuickActionButton(
      icon: Icons.map_outlined,
      label: 'Mapa / Pinar',
      subtitle: 'Território offline',
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ContactsMapScreen()),
        );
      },
    );
    final btnInbox = _QuickActionButton(
      icon: Icons.all_inbox_rounded,
      label: 'Inbox',
      subtitle: inboxCount > 0 ? '$inboxCount pendentes' : 'Caixa de entrada',
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const InboxScreen()),
        );
      },
    );
    final btnTarefas = _QuickActionButton(
      icon: Icons.task_alt_rounded,
      label: 'Tarefas',
      subtitle: 'Metas e projetos',
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TasksScreen()),
        );
      },
    );
    final btnConhecimento = _QuickActionButton(
      icon: Icons.lightbulb_outline,
      label: 'Conhecimento',
      subtitle: 'Base de pesquisa',
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const KnowledgeBaseScreen()),
        );
      },
    );
    final btnTelefones = _QuickActionButton(
      icon: Icons.phone_outlined,
      label: 'Telefones',
      subtitle: 'Testemunho por fone',
      onTap: () => _navigateTo(AppFeature.phones),
    );
    final btnExperiencias = _QuickActionButton(
      icon: Icons.auto_stories_outlined,
      label: 'Experiências',
      subtitle: 'Relatos de campo',
      onTap: () => _navigateTo(AppFeature.experiences),
    );
    final btnAnotacoes = _QuickActionButton(
      icon: Icons.note_alt_outlined,
      label: 'Anotações',
      subtitle: 'Notas e pesquisas',
      onTap: () => _navigateTo(AppFeature.notesResearch),
    );
    final btnEstatisticas = _QuickActionButton(
      icon: Icons.analytics_outlined,
      label: 'Estatísticas',
      subtitle: 'Painel do ministério',
      onTap: () => _navigateTo(AppFeature.dashboard),
    );
    final btnEstrangeiro = _QuickActionButton(
      icon: Icons.language,
      label: 'Estrangeiro',
      subtitle: 'Outros idiomas',
      onTap: () => _showAddForeignContactDialog(context, ref),
    );

    final studiesEnabled = ref.watch(
      isFeatureEnabledProvider(AppFeature.studies),
    );
    final mapsEnabled = ref.watch(
      isFeatureEnabledProvider(AppFeature.territoryMaps),
    );
    final inboxEnabled = ref.watch(isFeatureEnabledProvider(AppFeature.inbox));
    final tasksEnabled = ref.watch(
      isFeatureEnabledProvider(AppFeature.tasksProjects),
    );
    final knowledgeEnabled = ref.watch(
      isFeatureEnabledProvider(AppFeature.knowledge),
    );
    final phonesEnabled = ref.watch(
      isFeatureEnabledProvider(AppFeature.phones),
    );
    final experiencesEnabled = ref.watch(
      isFeatureEnabledProvider(AppFeature.experiences),
    );
    final notesEnabled = ref.watch(
      isFeatureEnabledProvider(AppFeature.notesResearch),
    );
    final dashboardEnabled = ref.watch(
      isFeatureEnabledProvider(AppFeature.dashboard),
    );

    Widget buildGridRows(List<Widget> items) {
      if (items.isEmpty) return const SizedBox.shrink();
      final width = MediaQuery.sizeOf(context).width;
      final crossAxisCount = width >= 900 ? 4 : (width >= 600 ? 3 : 2);

      final rows = <Widget>[];
      for (var i = 0; i < items.length; i += crossAxisCount) {
        final slice = items.sublist(
          i,
          i + crossAxisCount > items.length ? items.length : i + crossAxisCount,
        );
        if (rows.isNotEmpty) rows.add(const SizedBox(height: 10));
        rows.add(
          Row(
            children: [
              for (var j = 0; j < slice.length; j++) ...[
                if (j > 0) const SizedBox(width: 10),
                Expanded(child: slice[j]),
              ],
              if (slice.length < crossAxisCount)
                for (var k = 0; k < crossAxisCount - slice.length; k++) ...[
                  const SizedBox(width: 10),
                  const Expanded(child: SizedBox.shrink()),
                ],
            ],
          ),
        );
      }
      return Column(children: rows);
    }

    if (category == 'ministerio') {
      return buildGridRows([
        btnNovaPessoa,
        btnRevisitas,
        if (studiesEnabled) btnEstudos,
        btnAtividade,
        if (mapsEnabled) btnMapa,
        btnEstrangeiro,
        if (phonesEnabled) btnTelefones,
        if (experiencesEnabled) btnExperiencias,
      ]);
    }

    if (category == 'produtividade') {
      return buildGridRows([
        if (inboxEnabled) btnInbox,
        if (tasksEnabled) btnTarefas,
        if (knowledgeEnabled) btnConhecimento,
        if (notesEnabled) btnAnotacoes,
      ]);
    }

    if (category == 'todos') {
      return buildGridRows([
        btnNovaPessoa,
        btnRevisitas,
        if (studiesEnabled) btnEstudos,
        btnAtividade,
        if (mapsEnabled) btnMapa,
        if (inboxEnabled) btnInbox,
        if (tasksEnabled) btnTarefas,
        if (knowledgeEnabled) btnConhecimento,
        if (phonesEnabled) btnTelefones,
        if (experiencesEnabled) btnExperiencias,
        if (notesEnabled) btnAnotacoes,
        if (dashboardEnabled) btnEstatisticas,
        btnEstrangeiro,
      ]);
    }

    // Padrão: 'principais'
    return buildGridRows([
      btnNovaPessoa,
      btnRevisitas,
      if (studiesEnabled) btnEstudos,
      if (mapsEnabled) btnMapa,
      if (inboxEnabled) btnInbox,
      if (tasksEnabled) btnTarefas,
      if (knowledgeEnabled) btnConhecimento,
      btnAtividade,
    ]);
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF131A29) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : const Color(0xFFE2E8F0);
    final iconBoxBg = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : const Color(0xFFF1F5F9);
    final iconColor = isDark
        ? const Color(0xFFF8FAFC)
        : const Color(0xFF0F172A);
    final titleColor = isDark
        ? const Color(0xFFF8FAFC)
        : const Color(0xFF0F172A);
    final subtitleColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBoxBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(child: Icon(icon, size: 20, color: iconColor)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: subtitleColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
