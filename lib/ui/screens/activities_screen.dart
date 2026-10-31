import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_theme.dart';
import '../../core/date_utils.dart';
import '../providers.dart';
import '../widgets/pioneer_pace_card.dart';
import '../../activities/auto_corrective_timer_logic.dart';
import '../widgets/auto_corrective_timer_dialog.dart';

class ActivitiesScreen extends ConsumerStatefulWidget {
  const ActivitiesScreen({super.key});

  @override
  ConsumerState<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends ConsumerState<ActivitiesScreen> {
  String _selectedPeriod = 'Este Mês'; // 'Hoje', 'Esta Semana', 'Este Mês', 'Ano de Serviço'

  // Cronômetro de Campo com Detecção de Parada e Modo Carrinho (Ideia 2)
  Timer? _fieldTimer;
  int _timerSeconds = 0;
  bool _isTimerRunning = false;
  String _timerModality = 'campo'; // 'campo' ou 'testemunho_publico'
  int _lastInteractionSeconds = 0;
  bool _stoppedNoticeDismissed = false;

  @override
  void dispose() {
    _fieldTimer?.cancel();
    super.dispose();
  }

  void _toggleTimer() {
    setState(() {
      if (_isTimerRunning) {
        _fieldTimer?.cancel();
        _isTimerRunning = false;
      } else {
        _isTimerRunning = true;
        _lastInteractionSeconds = _timerSeconds;
        _stoppedNoticeDismissed = false;
        _fieldTimer = Timer.periodic(const Duration(seconds: 1), (t) {
          if (mounted) {
            setState(() {
              _timerSeconds++;
            });

            // Alerta de cronômetro ligado ininterruptamente (R5: > 4 horas)
            if (_timerSeconds >= 14400 && !_stoppedNoticeDismissed) {
              _stoppedNoticeDismissed = true;
              _checkAutoCorrectiveTimer();
            }
          }
        });
      }
    });
  }

  void _checkAutoCorrectiveTimer() {
    final state = AutoCorrectiveTimerLogic.evaluate(
      isRunning: _isTimerRunning,
      startedAt: DateTime.now().subtract(Duration(seconds: _timerSeconds)),
      accumulatedDuration: Duration.zero,
    );

    if (state.shouldShowWarning && mounted) {
      AutoCorrectiveTimerDialog.show(
        context,
        state: state,
        onApplyAdjustment: (newDuration) {
          setState(() {
            _timerSeconds = newDuration.inSeconds;
          });
        },
        onKeepCurrent: () {
          setState(() {
            _stoppedNoticeDismissed = true;
          });
        },
        onDiscard: _resetTimer,
      );
    }
  }

  void _resetTimer() {
    setState(() {
      _fieldTimer?.cancel();
      _isTimerRunning = false;
      _timerSeconds = 0;
      _stoppedNoticeDismissed = false;
    });
  }

  bool get _detectPotentialStop {
    // Se o cronômetro está rodando há mais de 45 minutos ininterruptos, detecta eventual parada ou intervalo
    if (!_stoppedNoticeDismissed && _isTimerRunning && _timerSeconds >= 2700 && (_timerSeconds - _lastInteractionSeconds) >= 1800) {
      return true;
    }
    return false;
  }

  void _saveTimerActivity() {
    _showAddActivityModal(
      context,
      initialDurationSeconds: _timerSeconds,
      initialModality: _timerModality,
      onSavedCallback: () {
        _resetTimer();
      },
    );
  }

  DateTime get _now => DateTime.now();

  DateTimeRange get _currentRange {
    final now = _now;
    switch (_selectedPeriod) {
      case 'Hoje':
        final start = DateTime(now.year, now.month, now.day);
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
        return DateTimeRange(start: start, end: end);
      case 'Esta Semana':
        final monday = now.subtract(Duration(days: now.weekday - 1));
        final start = DateTime(monday.year, monday.month, monday.day);
        final end = start.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
        return DateTimeRange(start: start, end: end);
      case 'Ano de Serviço':
        // Ano de serviço de Testemunhas de Jeová: 1 de Setembro do ano anterior a 31 de Agosto do ano corrente
        final serviceYearStart = now.month >= 9 ? DateTime(now.year, 9, 1) : DateTime(now.year - 1, 9, 1);
        final serviceYearEnd = DateTime(serviceYearStart.year + 1, 8, 31, 23, 59, 59);
        return DateTimeRange(start: serviceYearStart, end: serviceYearEnd);
      case 'Este Mês':
      default:
        final start = DateTime(now.year, now.month, 1);
        final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        return DateTimeRange(start: start, end: end);
    }
  }

  void _showAddActivityModal(
    BuildContext context, {
    int? initialDurationSeconds,
    String? initialModality,
    VoidCallback? onSavedCallback,
  }) {
    DateTime selectedDate = DateTime.now();
    final initialSeconds = initialDurationSeconds ?? 3600;
    final initialH = initialSeconds ~/ 3600;
    final initialM = (initialSeconds % 3600) ~/ 60;

    final hoursController = TextEditingController(text: initialH.toString());
    final minutesController = TextEditingController(text: initialM.toString());
    final notesController = TextEditingController();
    String selectedModality = initialModality ?? 'campo';

    showDialog(

      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Registrar Atividade de Campo'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today, color: AppTheme.primaryBlue),
                  title: Text(AppDateUtils.formatDate(selectedDate)),
                  trailing: const Icon(Icons.edit_calendar),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                    );
                    if (picked != null) setDialogState(() => selectedDate = picked);
                  },
                ),
                const SizedBox(height: 8),
                const Text('Duração do Ministério:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: hoursController,
                        decoration: const InputDecoration(labelText: 'Horas', suffixText: 'h'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: minutesController,
                        decoration: const InputDecoration(labelText: 'Minutos', suffixText: 'min'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedModality,
                  decoration: const InputDecoration(labelText: 'Modalidade'),
                  items: const [
                    DropdownMenuItem(value: 'campo', child: Text('De Casa em Casa')),
                    DropdownMenuItem(value: 'testemunho_publico', child: Text('Testemunho Público / Carrinho')),
                    DropdownMenuItem(value: 'informal', child: Text('Testemunho Informal')),
                    DropdownMenuItem(value: 'carta_telefone', child: Text('Cartas e Telefone')),
                    DropdownMenuItem(value: 'outro', child: Text('Outra modalidade')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedModality = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Observações (opcional)',
                    hintText: 'Companheiro(a), publicações colocadas...',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                final h = int.tryParse(hoursController.text.trim()) ?? 0;
                final m = int.tryParse(minutesController.text.trim()) ?? 0;
                final totalSeconds = (h * 3600) + (m * 60);

                if (totalSeconds <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Informe ao menos 1 minuto de atividade.')),
                  );
                  return;
                }

                final repo = ref.read(repositoryProvider);
                await repo.createActivityRecord(
                  date: selectedDate,
                  durationSeconds: totalSeconds,
                  modality: selectedModality,
                  notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                );

                if (onSavedCallback != null) onSavedCallback();
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Atividade registrada com sucesso!')),
                  );
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatModality(String modality) {
    switch (modality) {
      case 'campo':
        return 'De Casa em Casa';
      case 'testemunho_publico':
        return 'Testemunho Público';
      case 'informal':
        return 'Informal';
      case 'carta_telefone':
        return 'Cartas / Telefone';
      default:
        return 'Outro';
    }
  }

  @override
  Widget build(BuildContext context) {
    final activitiesAsync = ref.watch(activitiesStreamProvider);
    final isSunMode = ref.watch(sunModeProvider);
    final range = _currentRange;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Atividades do Ministério'),
        actions: [
          IconButton(
            icon: Icon(
              isSunMode ? Icons.wb_sunny : Icons.wb_sunny_outlined,
              color: isSunMode ? Colors.amber : Colors.white,
            ),
            tooltip: isSunMode ? 'Desativar Modo Sol' : '☀️ Modo Sol Intenso (Alto Contraste)',
            onPressed: () {
              ref.read(sunModeProvider.notifier).state = !isSunMode;
            },
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nova Atividade'),
        onPressed: () => _showAddActivityModal(context),
      ),
      body: activitiesAsync.when(
        data: (allActivities) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final filteredActivities = allActivities.where((a) =>
              a.deletedAt == null &&
              a.date.isAfter(range.start.subtract(const Duration(seconds: 1))) &&
              a.date.isBefore(range.end.add(const Duration(seconds: 1)))).toList();

          final totalSecondsInPeriod = filteredActivities.fold<int>(0, (sum, a) => sum + a.durationSeconds);

          // Totais calculados sem arredondamento prematuro (Seção 7)
          final hours = totalSecondsInPeriod ~/ 3600;
          final minutes = (totalSecondsInPeriod % 3600) ~/ 60;

          return Column(
            children: [
              // Card do Cronômetro de Campo com Detecção de Parada e Modo Carrinho (Ideia 2)
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: isDark ? 0 : 2,
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _timerModality == 'testemunho_publico' ? Icons.storefront : Icons.timer,
                                color: _timerModality == 'testemunho_publico' ? const Color(0xFF7C3AED) : AppTheme.primaryBlue,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _timerModality == 'testemunho_publico' ? 'Modo Carrinho / Público' : 'Cronômetro de Campo',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: isDark ? Colors.white : AppTheme.textDark,
                                ),
                              ),
                            ],
                          ),
                          DropdownButton<String>(
                            value: _timerModality,
                            underline: const SizedBox.shrink(),
                            dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                            isDense: true,
                            items: const [
                              DropdownMenuItem(value: 'campo', child: Text('De Casa em Casa', style: TextStyle(fontSize: 12))),
                              DropdownMenuItem(value: 'testemunho_publico', child: Text('🛒 Modo Carrinho', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                              DropdownMenuItem(value: 'informal', child: Text('Informal', style: TextStyle(fontSize: 12))),
                              DropdownMenuItem(value: 'carta_telefone', child: Text('Cartas/Telefone', style: TextStyle(fontSize: 12))),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _timerModality = val);
                            },
                          ),
                        ],
                      ),
                      if (_detectPotentialStop) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFF59E0B)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.coffee, color: Color(0xFFB45309), size: 18),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Parada detectada: Você fez um intervalo ou encerrou o campo?',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF92400E), fontWeight: FontWeight.bold),
                                ),
                              ),
                              TextButton(
                                onPressed: () => setState(() => _stoppedNoticeDismissed = true),
                                child: const Text('Dispensar', style: TextStyle(fontSize: 11)),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        AppDateUtils.formatDuration(_timerSeconds),
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          color: _isTimerRunning ? AppTheme.primaryBlue : (isDark ? Colors.white : AppTheme.textDark),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isTimerRunning ? Colors.orange : AppTheme.primaryBlue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            ),
                            icon: Icon(_isTimerRunning ? Icons.pause : Icons.play_arrow, size: 18),
                            label: Text(_isTimerRunning ? 'Pausar' : (_timerSeconds > 0 ? 'Continuar' : 'Iniciar Campo'), style: const TextStyle(fontSize: 12)),
                            onPressed: _toggleTimer,
                          ),
                          if (_timerSeconds > 0) ...[
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.successGreen,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              ),
                              icon: const Icon(Icons.check, size: 16),
                              label: const Text('Salvar', style: TextStyle(fontSize: 12)),
                              onPressed: _saveTimerActivity,
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              icon: const Icon(Icons.refresh, size: 18),
                              tooltip: 'Zerar cronômetro',
                              onPressed: _resetTimer,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Calculadora de Ritmo Real de Campo do Pioneiro (R2)
              Builder(
                builder: (context) {
                  final now = DateTime.now();
                  final currentMonthStart = DateTime(now.year, now.month, 1);
                  final currentMonthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
                  final currentMonthActivities = allActivities.where((a) =>
                      a.deletedAt == null &&
                      a.date.isAfter(currentMonthStart.subtract(const Duration(seconds: 1))) &&
                      a.date.isBefore(currentMonthEnd.add(const Duration(seconds: 1)))).toList();
                  final currentMonthSeconds = currentMonthActivities.fold<int>(0, (sum, a) => sum + a.durationSeconds);
                  final currentMonthCompletedHours = currentMonthSeconds / 3600.0;

                  return PioneerPaceCard(
                    currentMonthCompletedHours: currentMonthCompletedHours,
                  );
                },
              ),

              // Barra de seleção de período
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['Hoje', 'Esta Semana', 'Este Mês', 'Ano de Serviço'].map((p) {
                      final isSelected = _selectedPeriod == p;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(p, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                          selected: isSelected,
                          selectedColor: AppTheme.primaryBlue.withValues(alpha: 0.15),
                          checkmarkColor: AppTheme.primaryBlue,
                          onSelected: (_) => setState(() => _selectedPeriod = p),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const Divider(height: 1),

              // Card de Resumo do Período
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Card(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  elevation: isDark ? 0 : 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total em $_selectedPeriod',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? const Color(0xFF94A3B8) : AppTheme.textMuted,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${hours}h ${minutes.toString().padLeft(2, '0')}m',
                              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                            ),
                            Text(
                              '${filteredActivities.length} registro(s) de atividade',
                              style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : AppTheme.textMuted),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.timer_outlined, size: 30, color: AppTheme.primaryBlue),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Lista de Registros
              Expanded(
                child: filteredActivities.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.history_toggle_off, size: 56, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text(
                                'Nenhuma atividade registrada para $_selectedPeriod.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: AppTheme.textMuted, fontSize: 15),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filteredActivities.length,
                        itemBuilder: (context, index) {
                          final act = filteredActivities[index];
                          final h = act.durationSeconds ~/ 3600;
                          final m = (act.durationSeconds % 3600) ~/ 60;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentTeal.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  h > 0 ? '${h}h ${m}m' : '${m}m',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accentTeal),
                                ),
                              ),
                              title: Text(_formatModality(act.modality), style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                '${AppDateUtils.formatDate(act.date)}${act.notes != null ? " • ${act.notes}" : ""}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
                                onPressed: () async {
                                  final repo = ref.read(repositoryProvider);
                                  await repo.deleteActivityRecord(act.id);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Atividade removida com sucesso.')),
                                    );
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erro: $err')),
      ),
    );
  }
}
