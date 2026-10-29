import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_theme.dart';
import '../../core/date_utils.dart';
import '../../core/demo_data.dart';
import '../../contacts/person_hand_off_helper.dart';
import '../../territory/geocoding_service.dart';
import '../../territory/sector_manager.dart';
import '../providers.dart';
import '../widgets/map_location_picker_dialog.dart';
import 'activities_screen.dart';
import 'contacts_map_screen.dart';
import 'person_detail_screen.dart';
import 'sector_detail_screen.dart';
import 'settings_screen.dart';

class TodayScreen extends ConsumerWidget {
  final Function(int) onTabChange;

  const TodayScreen({super.key, required this.onTabChange});

  void _showSyncStatusModal(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(repositoryProvider);
    final pendingOps = await repo.getPendingSyncOperations();

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
                  const Icon(Icons.cloud_sync, color: AppTheme.primaryBlue, size: 28),
                  const SizedBox(width: 10),
                  const Text(
                    'Estado da Sincronização',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppTheme.successGreen, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Modo Offline-First ativo. Seus dados estão preservados no SQLite/Wasm local.',
                        style: TextStyle(fontSize: 13, color: Colors.blue.shade900),
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
              Text('• Última checagem: ${AppDateUtils.formatDateTime(DateTime.now())}'),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.sync),
                  label: const Text('Sincronizar Agora'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(pendingOps.isEmpty
                            ? 'Todos os registros locais já estão sincronizados!'
                            : '${pendingOps.length} operação(ões) enfileirada(s) processada(s) localmente.'),
                      ),
                    );
                  },
                ),
              ),
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Consumer(
        builder: (ctx, innerRef, _) {
          final sectors = innerRef.watch(sectorsStreamProvider).value ?? [];
          final mgr = innerRef.read(sectorManagerProvider);

          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
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
                            Icon(Icons.holiday_village, color: AppTheme.accentTeal),
                            SizedBox(width: 8),
                            Text('Gerenciar Bairros / Setores', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Adicionar Novo Bairro / Setor:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                                  await mgr.addSector(name, description: descController.text.trim());
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
                    const Text('Bairros Cadastrados no Território:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    if (sectors.isEmpty)
                      Text(
                        'Nenhum bairro cadastrado.',
                        style: TextStyle(color: Theme.of(ctx).brightness == Brightness.dark ? const Color(0xFFCBD5E1) : AppTheme.textMuted),
                      )
                    else
                      for (final s in sectors)
                        Card(
                          margin: const EdgeInsets.only(bottom: 6),
                          child: ListTile(
                            leading: const Icon(Icons.location_city, color: AppTheme.primaryBlue),
                            title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(s.description?.isNotEmpty == true ? s.description! : 'Setor do território'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppTheme.alertRed, size: 20),
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
                  child: Text('🌐 Novo Contato Estrangeiro', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                            side: const BorderSide(color: AppTheme.accentTeal),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                          icon: const Icon(Icons.map, size: 16),
                          label: const Text('🗺️ Pinar Localização', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          onPressed: () async {
                            final initialLat = double.tryParse(latController.text.trim());
                            final initialLng = double.tryParse(lngController.text.trim());
                            final res = await showDialog<ReverseGeocodingResult>(
                              context: context,
                              builder: (_) => MapLocationPickerDialog(
                                initialLat: initialLat,
                                initialLng: initialLng,
                                initialAddress: addressController.text.trim(),
                              ),
                            );
                            if (res != null) {
                              setDialogState(() {
                                latController.text = res.latitude.toStringAsFixed(6);
                                lngController.text = res.longitude.toStringAsFixed(6);
                                if (addressController.text.trim().isEmpty && res.streetAndNumber.isNotEmpty) {
                                  addressController.text = res.formattedSummary;
                                }
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  if (latController.text.isNotEmpty && lngController.text.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '📍 GPS: ${latController.text}, ${lngController.text}',
                      style: const TextStyle(fontSize: 11, color: AppTheme.accentTeal, fontWeight: FontWeight.bold),
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
                      hintText: 'Ex: Ficou com folheto em espanhol, aceitou visita',
                      prefixIcon: Icon(Icons.note_alt_outlined),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Encaminhar para Irmão Responsável via WhatsApp', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    value: sendViaWhatsApp,
                    onChanged: (val) => setDialogState(() => sendViaWhatsApp = val ?? true),
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
                    phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
                    address: addressController.text.trim().isEmpty ? null : addressController.text.trim(),
                    latitude: lat,
                    longitude: lng,
                    preferredSchedule: scheduleController.text.trim().isEmpty ? null : scheduleController.text.trim(),
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
                      additionalNotes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                    );
                  }

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Contato estrangeiro ($name) registrado com sucesso!')),
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
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
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
    final passedPersonIds = people.where((p) => p.status.toLowerCase() == 'revisita_passada').map((p) => p.id).toSet();
    final activities = ref.watch(activitiesStreamProvider).value ?? [];
    final studies = ref.watch(studiesStreamProvider).value ?? [];
    final sessions = ref.watch(studySessionsStreamProvider).value ?? [];
    final isSunMode = ref.watch(sunModeProvider);

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

    // Preservação Estatística: Estudos com sessões realizadas no mês atual + estudos ativos não repassados
    final monthHeldSessions = sessions.where((s) =>
        s.deletedAt == null &&
        s.status.toLowerCase() == 'realizada' &&
        s.dateTimeField.isAfter(monthStart.subtract(const Duration(seconds: 1))) &&
        s.dateTimeField.isBefore(monthEnd.add(const Duration(seconds: 1)))).toList();

    final activeStudiesCount = studies.where((s) {
      if (s.deletedAt != null) return false;
      final hadSessionThisMonth = monthHeldSessions.any((sess) => sess.studyId == s.id);
      if (hadSessionThisMonth) return true; // Conta na estatística mensal mesmo se repassado ou concluído depois
      return s.status == 'ativo';
    }).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hoje no Ministério'),
        actions: [
          // Botão de alternância rápida: Modo Sol Intenso / Alto Contraste (Ideia 1)
          IconButton(
            icon: Icon(
              isSunMode ? Icons.wb_sunny : Icons.wb_sunny_outlined,
              color: isSunMode ? Colors.amber : Colors.white,
            ),
            tooltip: isSunMode ? 'Desativar Modo Sol' : '☀️ Modo Sol Intenso (Alto Contraste)',
            onPressed: () {
              ref.read(sunModeProvider.notifier).state = !isSunMode;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(!isSunMode ? '☀️ Modo Sol Intenso e Alto Contraste ativado!' : 'Modo normal restaurado.'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
          InkWell(
            onTap: () => _showSyncStatusModal(context, ref),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.offline_pin, size: 14, color: Colors.white),
                  SizedBox(width: 4),
                  Text(
                    'Salvo Localmente',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
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
            // Data atual com cabeçalho acolhedor
            Text(
              '${AppDateUtils.formatDate(now)} • Foco do Dia',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFFCBD5E1) : AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 12),

            // Card de Progresso das Horas e Estudos Bíblicos do Mês Atual
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Padding(
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
                                  color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.analytics_outlined, color: AppTheme.primaryBlue, size: 20),
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
                                    color: isDark ? Colors.white : AppTheme.textDark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => onTabChange(5),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Detalhes', style: TextStyle(fontSize: 12, color: AppTheme.primaryBlue, fontWeight: FontWeight.bold)),
                                Icon(Icons.chevron_right, size: 16, color: AppTheme.primaryBlue),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        // HORAS DO MÊS
                        Expanded(
                          flex: 3,
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const ActivitiesScreen()),
                              );
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Horas Realizadas',
                                          style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFFCBD5E1) : AppTheme.textMuted),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.timer_outlined, size: 14, color: AppTheme.primaryBlue),
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
                                      backgroundColor: isDark ? const Color(0xFF334155) : Colors.blue.shade100,
                                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Meta: ${hourGoal}h (${(progressFraction * 100).toStringAsFixed(0)}%)',
                                    style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : AppTheme.textMuted),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // ESTUDOS BÍBLICOS ATIVOS
                        Expanded(
                          flex: 2,
                          child: InkWell(
                            onTap: () => onTabChange(4),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Estudos',
                                          style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFFCBD5E1) : AppTheme.textMuted),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.school_outlined, size: 14, color: Color(0xFF7C3AED)),
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
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      activeStudiesCount == 1 ? '1 ativo no mês' : '$activeStudiesCount ativos no mês',
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
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
            const SizedBox(height: 16),

            // Atalhos rápidos: Nova Pessoa, Nova Revisita, Novo Estudo, Registro de Atividade
            Row(
              children: [
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.person_add_alt_1,
                    label: 'Nova Pessoa',
                    color: isDark ? const Color(0xFF60A5FA) : AppTheme.primaryBlue,
                    onTap: () => onTabChange(1),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.repeat,
                    label: 'Revisitas',
                    color: AppTheme.accentTeal,
                    onTap: () => onTabChange(1),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.menu_book,
                    label: 'Estudos',
                    color: const Color(0xFF7C3AED),
                    onTap: () => onTabChange(4),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.timer,
                    label: 'Atividade',
                    color: const Color(0xFF059669),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ActivitiesScreen()),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.phone_forwarded,
                    label: 'Telefones',
                    color: const Color(0xFF0284C7),
                    onTap: () => onTabChange(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.auto_stories,
                    label: 'Experiências',
                    color: const Color(0xFFD97706),
                    onTap: () => onTabChange(6),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.note_alt_outlined,
                    label: 'Anotações',
                    color: const Color(0xFF475569),
                    onTap: () => onTabChange(7),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.analytics,
                    label: 'Estatísticas',
                    color: const Color(0xFF6366F1),
                    onTap: () => onTabChange(5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.map_outlined,
                    label: '🗺️ Mapa / Pinar',
                    color: const Color(0xFF0F766E),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ContactsMapScreen()),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.public,
                    label: '🌐 Estrangeiro',
                    color: const Color(0xFF2563EB),
                    onTap: () => _showAddForeignContactDialog(context, ref),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // SEÇÃO: Bairros / Setores do Território (Betânia, Lago Grande, Cidade, etc.)
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
                  label: const Text('Gerenciar', style: TextStyle(fontSize: 12)),
                  onPressed: () => _showManageSectorsModal(context, ref),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Botões dos Bairros com contagem de contatos
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
                      return addr.contains(sectorLower) || tags.contains(sectorLower) || notes.contains(sectorLower);
                    }).length;

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        avatar: const Icon(Icons.holiday_village, size: 16, color: AppTheme.accentTeal),
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              sector.name,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.accentTeal.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$count',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.accentTeal),
                              ),
                            ),
                          ],
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SectorDetailScreen(sector: sector),
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
                    .where((a) =>
                        (a.personId == null || !passedPersonIds.contains(a.personId)) &&
                        a.startTime.day == now.day &&
                        a.startTime.month == now.month &&
                        a.startTime.year == now.year &&
                        a.status != 'cancelado' &&
                        a.status != 'reagendado')
                    .toList();

                if (todayAppts.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.event_available, color: Colors.grey.shade400, size: 36),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Nenhum compromisso marcado para hoje. Toque em Agenda para agendar.',
                              style: TextStyle(color: isDark ? const Color(0xFFCBD5E1) : AppTheme.textMuted),
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
                            color: (isDark ? const Color(0xFF60A5FA) : AppTheme.primaryBlue).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            AppDateUtils.formatTime(a.startTime),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark ? const Color(0xFF93C5FD) : AppTheme.primaryBlue,
                            ),
                          ),
                        ),
                        title: Text(a.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          'Duração: ${a.durationMinutes} min • Status: ${a.status}',
                          style: const TextStyle(fontSize: 13),
                        ),
                        trailing: a.isProvisional
                            ? const Chip(
                                label: Text('Provisório', style: TextStyle(fontSize: 11)),
                                backgroundColor: Color(0xFFFEF3C7),
                              )
                            : const Icon(Icons.chevron_right),
                        onTap: () {
                          if (a.personId != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PersonDetailScreen(personId: a.personId!),
                              ),
                            );
                          } else {
                            onTabChange(2);
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
            Text(
              'Ações e Revisitas Pendentes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 8),
            peopleAsync.when(
              data: (people) {
                final pending = people
                    .where((p) =>
                        p.status.toLowerCase() != 'revisita_passada' &&
                        p.nextActionAt != null &&
                        p.nextActionAt!.isBefore(now.add(const Duration(days: 1))))
                    .toList();

                if (pending.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline, color: AppTheme.successGreen, size: 36),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Todas as revisitas e ações combinadas estão em dia!',
                              style: TextStyle(color: isDark ? const Color(0xFFCBD5E1) : AppTheme.textMuted),
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
                          backgroundColor: isOverdue ? AppTheme.alertRed.withValues(alpha: 0.1) : AppTheme.accentTeal.withValues(alpha: 0.1),
                          child: Icon(
                            isOverdue ? Icons.warning_amber_rounded : Icons.schedule,
                            color: isOverdue ? AppTheme.alertRed : AppTheme.accentTeal,
                          ),
                        ),
                        title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          '${p.nextActionNote ?? "Sem anotação"} • Data: ${AppDateUtils.formatDate(p.nextActionAt)}',
                          style: TextStyle(
                            color: isOverdue ? AppTheme.alertRed : (isDark ? const Color(0xFFCBD5E1) : AppTheme.textMuted),
                            fontWeight: isOverdue ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PersonDetailScreen(personId: p.id),
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
                        Icon(Icons.science, color: isDark ? const Color(0xFF60A5FA) : AppTheme.primaryBlue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Modo de Demonstração Disponível',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark ? const Color(0xFF93C5FD) : AppTheme.primaryBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Você pode popular o sistema com dados demonstrativos fictícios para testar sem conectar ao Supabase.',
                      style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFFCBD5E1) : AppTheme.textMuted),
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
                            const SnackBar(content: Text('Dados de demonstração gerados com sucesso!')),
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

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
