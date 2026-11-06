import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_theme.dart';
import '../../core/date_utils.dart';
import '../../core/demo_data.dart';
import '../../contacts/person_hand_off_helper.dart';
import '../../sync/supabase_sync_service.dart';
import '../../territory/geocoding_service.dart';
import '../../territory/sector_manager.dart';
import '../providers.dart';
import '../widgets/map_location_picker_dialog.dart';
import 'activities_screen.dart';
import 'contacts_map_screen.dart';
import 'person_detail_screen.dart';
import 'sector_detail_screen.dart';
import '../../core/feature_registry.dart';
import 'settings_screen.dart';
import 'global_search_screen.dart';
import 'next_actions_screen.dart';

class TodayScreen extends ConsumerWidget {
  final Function(int)? onTabChange;
  final Function(AppFeature)? onFeatureNavigate;

  const TodayScreen({super.key, this.onTabChange, this.onFeatureNavigate});

  User? _getCurrentSupabaseUser() {
    try {
      return Supabase.instance.client.auth.currentUser;
    } catch (_) {
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
      case AppFeature.territoryMaps:
        return 1;
    }
  }

  void _showSyncStatusModal(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(repositoryProvider);
    final pendingOps = await repo.getPendingSyncOperations();
    final currentUser = _getCurrentSupabaseUser();

    if (!context.mounted) return;

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
                    currentUser != null ? Icons.cloud_done : Icons.cloud_sync,
                    color: currentUser != null
                        ? AppTheme.successGreen
                        : AppTheme.primaryBlue,
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
                  color: currentUser != null
                      ? AppTheme.successGreen.withValues(alpha: 0.12)
                      : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: currentUser != null
                        ? AppTheme.successGreen.withValues(alpha: 0.35)
                        : AppTheme.primaryBlue.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      currentUser != null
                          ? Icons.verified_user_rounded
                          : Icons.check_circle,
                      color: currentUser != null
                          ? AppTheme.successGreen
                          : AppTheme.primaryBlue,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentUser != null
                                ? 'Conectado ao Supabase: ${currentUser.email ?? "Usuário autenticado"}'
                                : 'Modo Offline-First ativo. Seus dados estão preservados localmente.',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: currentUser != null
                                  ? AppTheme.successGreen
                                  : Colors.blue.shade900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            currentUser != null
                                ? 'Sincronização automática em nuvem ativa + banco local SQLite/Wasm.'
                                : 'Faça login para sincronizar seus dados na nuvem.',
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
                      } catch (_) {}
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
    final nameController = TextEditingController();
    final descController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Consumer(
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
                                hintText: 'Ex: Betânia, Lago Grande, Cidade...',
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
      ),
    );
  }

  void _showAddForeignContactDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final langController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    final latController = TextEditingController();
    final lngController = TextEditingController();
    final notesController = TextEditingController();
    final scheduleController = TextEditingController();
    bool sendViaWhatsApp = true;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.public, color: AppTheme.primaryBlue),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '🌍 Novo Contato Estrangeiro',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                      hintText:
                          'Ex: Espanhol, Inglês, Francês, Mandarim, Crioulo...',
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
                            side: const BorderSide(color: AppTheme.accentTeal),
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
                                  addressController.text = res.formattedSummary;
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
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Observações / Publicação Deixada',
                      hintText:
                          'Ex: Ficou com folheto em espanhol, aceitou visita',
                      prefixIcon: Icon(Icons.note_alt_outlined),
                    ),
                    maxLines: 2,
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
                    preferredSchedule: scheduleController.text.trim().isEmpty
                        ? null
                        : scheduleController.text.trim(),
                    generalNotes: notesController.text.trim().isEmpty
                        ? (lang.isNotEmpty ? 'Idioma falado: $lang' : null)
                        : '${notesController.text.trim()}${lang.isNotEmpty ? "\nIdioma: $lang" : ""}',
                    tags: ['estrangeiro', if (lang.isNotEmpty) lang],
                  );

                  if (dialogCtx.mounted) Navigator.pop(dialogCtx);

                  if (sendViaWhatsApp) {
                    await PersonHandOffHelper.sendViaWhatsApp(
                      person: person,
                      language: lang.isNotEmpty ? lang : null,
                      additionalNotes: notesController.text.trim().isEmpty
                          ? null
                          : notesController.text.trim(),
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
        title: const Text('Hoje no Ministério'),
        actions: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.search),
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
              color: isSunMode ? Colors.amber : Colors.white,
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
          InkWell(
            onTap: () => _showSyncStatusModal(context, ref),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: supabaseUser != null
                    ? AppTheme.successGreen.withValues(alpha: 0.22)
                    : Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: supabaseUser != null
                      ? AppTheme.successGreen.withValues(alpha: 0.55)
                      : Colors.white.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    supabaseUser != null
                        ? Icons.cloud_done_rounded
                        : Icons.offline_pin,
                    size: 14,
                    color: supabaseUser != null
                        ? const Color(0xFF4ADE80)
                        : Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    supabaseUser != null
                        ? 'Supabase Online'
                        : 'Salvo Localmente',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.timer_outlined),
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
            icon: const Icon(Icons.settings_outlined),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${AppDateUtils.formatDate(now)} • Foco do Dia',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? const Color(0xFFCBD5E1)
                          : AppTheme.textMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (supabaseUser?.email != null)
                  Text(
                    supabaseUser!.email!,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : AppTheme.textMuted,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Card de Progresso com efeito Glassmorphism
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? [
                              const Color(0xFF1E293B).withValues(alpha: 0.78),
                              const Color(0xFF0F172A).withValues(alpha: 0.65),
                            ]
                          : [
                              Colors.white.withValues(alpha: 0.92),
                              const Color(0xFFF8FAFC).withValues(alpha: 0.85),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryBlue.withValues(
                                      alpha: 0.15,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.analytics_outlined,
                                    color: AppTheme.primaryBlue,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Progresso • ${_getMonthName(now.month)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.white
                                          : AppTheme.textDark,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => _navigateTo(AppFeature.dashboard),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Detalhes',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.primaryBlue,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    size: 16,
                                    color: AppTheme.primaryBlue,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ActivitiesScreen(),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.04)
                                      : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.1)
                                        : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Horas Realizadas',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDark
                                                  ? const Color(0xFFCBD5E1)
                                                  : AppTheme.textMuted,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(
                                          Icons.timer_outlined,
                                          size: 14,
                                          color: AppTheme.primaryBlue,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      hoursFormatted,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryBlue,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: progressFraction,
                                        minHeight: 6,
                                        backgroundColor: isDark
                                            ? const Color(0xFF334155)
                                            : Colors.blue.shade100,
                                        valueColor:
                                            const AlwaysStoppedAnimation<Color>(
                                              AppTheme.primaryBlue,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Meta: ${hourGoal}h (${(progressFraction * 100).toStringAsFixed(0)}%)',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isDark
                                            ? const Color(0xFF94A3B8)
                                            : AppTheme.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: InkWell(
                              onTap: () => _navigateTo(AppFeature.studies),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.04)
                                      : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.1)
                                        : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Estudos',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDark
                                                  ? const Color(0xFFCBD5E1)
                                                  : AppTheme.textMuted,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(
                                          Icons.school_outlined,
                                          size: 14,
                                          color: Color(0xFF7C3AED),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$activeStudiesCount',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF7C3AED),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF7C3AED)
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        activeStudiesCount == 1
                                            ? '1 ativo no mês'
                                            : '$activeStudiesCount ativos no mês',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF7C3AED),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Atalhos rápidos com transparência (Glassmorphism) e imagens temáticas no topo
            Row(
              children: [
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.person_add_alt_1,
                    label: 'Nova Pessoa',
                    themeType: _CardArtworkTheme.newPerson,
                    color: isDark
                        ? const Color(0xFF60A5FA)
                        : AppTheme.primaryBlue,
                    onTap: () => _navigateTo(AppFeature.people),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.repeat,
                    label: 'Revisitas',
                    themeType: _CardArtworkTheme.returnVisits,
                    color: AppTheme.accentTeal,
                    onTap: () => _navigateTo(AppFeature.people),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.menu_book,
                    label: 'Estudos',
                    themeType: _CardArtworkTheme.bibleStudies,
                    color: const Color(0xFFA78BFA),
                    onTap: () => _navigateTo(AppFeature.studies),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.timer,
                    label: 'Atividade',
                    themeType: _CardArtworkTheme.activityTimer,
                    color: const Color(0xFF34D399),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ActivitiesScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.phone_forwarded,
                    label: 'Telefones',
                    themeType: _CardArtworkTheme.phones,
                    color: const Color(0xFF38BDF8),
                    onTap: () => _navigateTo(AppFeature.phones),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.auto_stories,
                    label: 'Experiências',
                    themeType: _CardArtworkTheme.experiences,
                    color: const Color(0xFFFBBF24),
                    onTap: () => _navigateTo(AppFeature.experiences),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.note_alt_outlined,
                    label: 'Anotações',
                    themeType: _CardArtworkTheme.notes,
                    color: const Color(0xFF94A3B8),
                    onTap: () => _navigateTo(AppFeature.notesResearch),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.analytics,
                    label: 'Estatísticas',
                    themeType: _CardArtworkTheme.statistics,
                    color: const Color(0xFF818CF8),
                    onTap: () => _navigateTo(AppFeature.dashboard),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.map_outlined,
                    label: '🗺️ Mapa / Pinar',
                    themeType: _CardArtworkTheme.territoryMap,
                    color: const Color(0xFF2DD4BF),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ContactsMapScreen(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.public,
                    label: '🌍 Estrangeiro',
                    themeType: _CardArtworkTheme.foreignContact,
                    color: const Color(0xFF60A5FA),
                    onTap: () => _showAddForeignContactDialog(context, ref),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

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

            // Card informativo de Demonstração Isolada
            Card(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.science,
                          color: isDark
                              ? const Color(0xFF60A5FA)
                              : AppTheme.primaryBlue,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Modo de Demonstração Disponível',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? const Color(0xFF93C5FD)
                                  : AppTheme.primaryBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Você pode popular o sistema com dados demonstrativos fictícios para testar sem conectar ao Supabase.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? const Color(0xFFCBD5E1)
                            : AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add_to_photos, size: 18),
                      label: const Text('Carregar Dados de Demonstração'),
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _CardArtworkTheme {
  newPerson,
  returnVisits,
  bibleStudies,
  activityTimer,
  phones,
  experiences,
  notes,
  statistics,
  territoryMap,
  foreignContact,
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final _CardArtworkTheme themeType;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.themeType = _CardArtworkTheme.newPerson,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            splashColor: color.withValues(alpha: 0.2),
            highlightColor: color.withValues(alpha: 0.1),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    color.withValues(alpha: isDark ? 0.18 : 0.14),
                    isDark
                        ? const Color(0xFF0F172A).withValues(alpha: 0.72)
                        : Colors.white.withValues(alpha: 0.88),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: color.withValues(alpha: isDark ? 0.38 : 0.32),
                  width: 1.1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: isDark ? 0.12 : 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Imagem / Ilustração transparente no topo de cada card baseada na função
                  SizedBox(
                    height: 54,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CustomPaint(
                          painter: _CardHeaderIllustrationPainter(
                            color: color,
                            themeType: themeType,
                          ),
                        ),
                        // Gradiente translúcido suavizando a base da imagem do topo
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                color.withValues(alpha: 0.06),
                                (isDark
                                        ? const Color(0xFF0F172A)
                                        : Colors.white)
                                    .withValues(alpha: 0.55),
                              ],
                            ),
                          ),
                        ),
                        // Ícone principal centralizado com halo translúcido
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color.withValues(alpha: 0.18),
                              border: Border.all(
                                color: color.withValues(alpha: 0.45),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.28),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                            child: Icon(icon, color: color, size: 22),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 6, 6, 12),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                        letterSpacing: 0.2,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardHeaderIllustrationPainter extends CustomPainter {
  final Color color;
  final _CardArtworkTheme themeType;

  _CardHeaderIllustrationPainter({
    required this.color,
    required this.themeType,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final softFill = Paint()
      ..color = color.withValues(alpha: 0.14)
      ..style = PaintingStyle.fill;

    final accentStroke = Paint()
      ..color = color.withValues(alpha: 0.26)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final faintStroke = Paint()
      ..color = color.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Brilho atmosférico superior
    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.2),
      size.height * 0.65,
      softFill,
    );
    canvas.drawCircle(
      Offset(size.width * 0.18, size.height * 0.85),
      size.height * 0.45,
      Paint()..color = color.withValues(alpha: 0.08),
    );

    switch (themeType) {
      case _CardArtworkTheme.newPerson:
        // Silhuetas de pessoas e arcos de conexão
        canvas.drawCircle(
          Offset(size.width * 0.22, size.height * 0.36),
          7,
          accentStroke,
        );
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(size.width * 0.22, size.height * 0.78),
            width: 26,
            height: 20,
          ),
          3.14,
          3.14,
          false,
          accentStroke,
        );
        canvas.drawCircle(
          Offset(size.width * 0.78, size.height * 0.32),
          9,
          faintStroke,
        );
        canvas.drawCircle(
          Offset(size.width * 0.78, size.height * 0.32),
          16,
          faintStroke,
        );
        break;

      case _CardArtworkTheme.returnVisits:
        // Trilha curva e casas estilizadas no horizonte
        final path = Path()
          ..moveTo(size.width * 0.08, size.height * 0.75)
          ..quadraticBezierTo(
            size.width * 0.35,
            size.height * 0.15,
            size.width * 0.92,
            size.height * 0.65,
          );
        canvas.drawPath(path, accentStroke);
        final house = Path()
          ..moveTo(size.width * 0.74, size.height * 0.38)
          ..lineTo(size.width * 0.82, size.height * 0.20)
          ..lineTo(size.width * 0.90, size.height * 0.38)
          ..close();
        canvas.drawPath(house, softFill);
        canvas.drawPath(house, accentStroke);
        break;

      case _CardArtworkTheme.bibleStudies:
        // Páginas de livro abertas e raios de luz no topo
        final bookLeft = Path()
          ..moveTo(size.width * 0.25, size.height * 0.70)
          ..quadraticBezierTo(
            size.width * 0.15,
            size.height * 0.45,
            size.width * 0.12,
            size.height * 0.25,
          )
          ..lineTo(size.width * 0.25, size.height * 0.32)
          ..close();
        canvas.drawPath(bookLeft, softFill);
        canvas.drawPath(bookLeft, accentStroke);
        for (var i = 0; i < 4; i++) {
          final x = size.width * (0.68 + i * 0.07);
          canvas.drawLine(
            Offset(x, size.height * 0.15),
            Offset(x - 6, size.height * 0.75),
            faintStroke,
          );
        }
        break;

      case _CardArtworkTheme.activityTimer:
        // Arcos concêntricos de relógio/cronômetro e marcações
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(size.width * 0.22, size.height * 0.5),
            width: 34,
            height: 34,
          ),
          -1.5,
          4.2,
          false,
          accentStroke,
        );
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(size.width * 0.80, size.height * 0.45),
            width: 42,
            height: 42,
          ),
          0.5,
          3.5,
          false,
          faintStroke,
        );
        break;

      case _CardArtworkTheme.phones:
        // Ondas de rádio / sinal telefônico
        for (var r = 10.0; r <= 28.0; r += 8.0) {
          canvas.drawArc(
            Rect.fromCircle(
              center: Offset(size.width * 0.20, size.height * 0.65),
              radius: r,
            ),
            -1.4,
            1.3,
            false,
            accentStroke,
          );
          canvas.drawArc(
            Rect.fromCircle(
              center: Offset(size.width * 0.80, size.height * 0.65),
              radius: r,
            ),
            -3.0,
            1.3,
            false,
            faintStroke,
          );
        }
        break;

      case _CardArtworkTheme.experiences:
        // Estrelas/brilhos de inspiração e ondas suaves
        void drawStar(Offset c, double r) {
          canvas.drawLine(
            Offset(c.dx - r, c.dy),
            Offset(c.dx + r, c.dy),
            accentStroke,
          );
          canvas.drawLine(
            Offset(c.dx, c.dy - r),
            Offset(c.dx, c.dy + r),
            accentStroke,
          );
        }
        drawStar(Offset(size.width * 0.20, size.height * 0.35), 6);
        drawStar(Offset(size.width * 0.78, size.height * 0.28), 8);
        drawStar(Offset(size.width * 0.86, size.height * 0.62), 5);
        break;

      case _CardArtworkTheme.notes:
        // Linhas de caderno / folhas em camadas no topo
        for (var i = 1; i <= 3; i++) {
          final y = size.height * (0.22 * i);
          canvas.drawLine(
            Offset(size.width * 0.10, y),
            Offset(size.width * 0.34, y),
            accentStroke,
          );
          canvas.drawLine(
            Offset(size.width * 0.66, y),
            Offset(size.width * 0.90, y),
            faintStroke,
          );
        }
        break;

      case _CardArtworkTheme.statistics:
        // Gráfico de barras e linha de tendência ascendente
        final bars = [0.35, 0.55, 0.45, 0.75];
        for (var i = 0; i < bars.length; i++) {
          final barHeight = size.height * bars[i];
          final left = size.width * (0.10 + i * 0.06);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(left, size.height - barHeight, 5, barHeight),
              const Radius.circular(2),
            ),
            softFill,
          );
        }
        final trend = Path()
          ..moveTo(size.width * 0.65, size.height * 0.75)
          ..lineTo(size.width * 0.74, size.height * 0.48)
          ..lineTo(size.width * 0.82, size.height * 0.56)
          ..lineTo(size.width * 0.92, size.height * 0.22);
        canvas.drawPath(trend, accentStroke);
        break;

      case _CardArtworkTheme.territoryMap:
        // Grade cartográfica e rota pontilhada
        canvas.drawLine(
          Offset(size.width * 0.12, 0),
          Offset(size.width * 0.28, size.height),
          faintStroke,
        );
        canvas.drawLine(
          Offset(size.width * 0.72, 0),
          Offset(size.width * 0.88, size.height),
          faintStroke,
        );
        canvas.drawLine(
          Offset(0, size.height * 0.35),
          Offset(size.width, size.height * 0.45),
          faintStroke,
        );
        canvas.drawCircle(
          Offset(size.width * 0.22, size.height * 0.42),
          5,
          accentStroke,
        );
        break;

      case _CardArtworkTheme.foreignContact:
        // Globo com meridianos e paralelos
        final globeCenter = Offset(size.width * 0.20, size.height * 0.48);
        canvas.drawCircle(globeCenter, 16, accentStroke);
        canvas.drawOval(
          Rect.fromCenter(center: globeCenter, width: 16, height: 32),
          faintStroke,
        );
        canvas.drawLine(
          Offset(globeCenter.dx - 16, globeCenter.dy),
          Offset(globeCenter.dx + 16, globeCenter.dy),
          faintStroke,
        );
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _CardHeaderIllustrationPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.themeType != themeType;
  }
}
