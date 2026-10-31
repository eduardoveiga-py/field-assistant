import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_theme.dart';
import '../../dashboard/pioneer_pace_calculator.dart';
import '../../settings/app_settings_manager.dart';
import '../providers.dart';

class PioneerPaceCard extends ConsumerStatefulWidget {
  final double? currentMonthCompletedHours;
  final DateTime? currentDateOverride;

  const PioneerPaceCard({
    super.key,
    this.currentMonthCompletedHours,
    this.currentDateOverride,
  });

  @override
  ConsumerState<PioneerPaceCard> createState() => _PioneerPaceCardState();
}

class _PioneerPaceCardState extends ConsumerState<PioneerPaceCard> {
  double _goalHours = 50.0;
  List<int> _designatedWeekdays = [2, 4, 6]; // Terça, Quinta, Sábado como padrão intuitivo

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = ref.read(appSettingsManagerProvider);
    // Leitura com fallback entre a convenção de testes e a convenção de despacho
    final goalStr = await settings.getString('pioneer_goal_hours') ??
        await settings.getString('pioneer_monthly_goal_hours');
    final weekdaysStr = await settings.getString('pioneer_weekdays') ??
        await settings.getString('pioneer_designated_weekdays');

    if (mounted) {
      setState(() {
        if (goalStr != null && double.tryParse(goalStr) != null) {
          _goalHours = double.parse(goalStr);
        }
        if (weekdaysStr != null) {
          _designatedWeekdays = weekdaysStr.isEmpty
              ? <int>[]
              : weekdaysStr
                  .split(',')
                  .map((s) => int.tryParse(s.trim()))
                  .whereType<int>()
                  .toList();
        }
      });
    }
  }

  Future<void> _saveSettings(double goal, List<int> weekdays) async {
    final sortedDays = List<int>.from(weekdays)..sort();

    if (mounted) {
      setState(() {
        _goalHours = goal;
        _designatedWeekdays = sortedDays;
      });
    }

    final settings = ref.read(appSettingsManagerProvider);
    // Dual-write: persiste em ambas as chaves para interoperabilidade total
    await settings.setString('pioneer_goal_hours', goal.toString());
    await settings.setString('pioneer_monthly_goal_hours', goal.toString());
    await settings.setString('pioneer_weekdays', sortedDays.join(','));
    await settings.setString('pioneer_designated_weekdays', sortedDays.join(','));
  }

  Future<void> _showConfigDialog(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSunMode = ref.read(sunModeProvider);

    await showDialog(
      context: context,
      builder: (ctx) => _PioneerPaceConfigDialog(
        initialGoal: _goalHours,
        initialWeekdays: _designatedWeekdays,
        isDark: isDark,
        isSunMode: isSunMode,
        onSave: (goal, weekdays) => _saveSettings(goal, weekdays),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentDate = widget.currentDateOverride ?? DateTime.now();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSunMode = ref.watch(sunModeProvider);

    // Resolve as horas completadas no mês (injetadas ou calculadas via stream)
    double completedHours = widget.currentMonthCompletedHours ?? 0.0;
    if (widget.currentMonthCompletedHours == null) {
      final activitiesAsync = ref.watch(activitiesStreamProvider);
      final allActivities = activitiesAsync.value ?? [];
      final monthStart = DateTime(currentDate.year, currentDate.month, 1);
      final monthEnd = DateTime(currentDate.year, currentDate.month + 1, 0, 23, 59, 59);

      final monthActs = allActivities.where((a) =>
          a.deletedAt == null &&
          !a.date.isBefore(monthStart) &&
          !a.date.isAfter(monthEnd)).toList();
      final totalSeconds = monthActs.fold<int>(0, (sum, a) => sum + a.durationSeconds);
      completedHours = totalSeconds / 3600.0;
    }

    final paceResult = PioneerPaceCalculator.calculate(
      goalHours: _goalHours,
      designatedWeekdays: _designatedWeekdays,
      completedHours: completedHours,
      currentDate: currentDate,
    );

    final progressPercent = _goalHours > 0
        ? (completedHours / _goalHours).clamp(0.0, 1.0)
        : 0.0;

    final completedFormatted = completedHours == completedHours.roundToDouble()
        ? completedHours.toInt().toString()
        : completedHours.toStringAsFixed(1);
    final goalFormatted = _goalHours == _goalHours.roundToDouble()
        ? _goalHours.toInt().toString()
        : _goalHours.toStringAsFixed(1);

    // Cores adaptativas
    final cardBgColor = isSunMode
        ? Colors.white
        : (isDark ? const Color(0xFF1E293B) : Colors.white);

    final borderColor = isSunMode
        ? Colors.black
        : (paceResult.isGoalReached
            ? AppTheme.successGreen
            : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)));

    final borderWidth = isSunMode ? 2.0 : (paceResult.isGoalReached ? 1.5 : 1.0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: isSunMode || isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      paceResult.isGoalReached ? Icons.check_circle : Icons.speed,
                      color: isSunMode
                          ? Colors.black
                          : (paceResult.isGoalReached
                              ? AppTheme.successGreen
                              : (isDark ? const Color(0xFF60A5FA) : AppTheme.primaryBlue)),
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ritmo Real de Campo',
                        style: TextStyle(
                          color: isSunMode
                              ? Colors.black
                              : (isDark ? Colors.white : AppTheme.textDark),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.tune,
                  color: isSunMode
                      ? Colors.black
                      : (isDark ? const Color(0xFF94A3B8) : AppTheme.textMuted),
                  size: 20,
                ),
                tooltip: 'Configurar Meta e Dias de Campo',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: () => _showConfigDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progressPercent,
              minHeight: 8,
              backgroundColor: isSunMode
                  ? Colors.grey.shade300
                  : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              valueColor: AlwaysStoppedAnimation<Color>(
                isSunMode
                    ? Colors.black
                    : (paceResult.isGoalReached
                        ? AppTheme.successGreen
                        : (isDark ? const Color(0xFF3B82F6) : AppTheme.primaryBlue)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                'Feitas: ${completedFormatted}h de ${goalFormatted}h (${(progressPercent * 100).toInt()}%)',
                style: TextStyle(
                  color: isSunMode
                      ? Colors.black87
                      : (isDark ? const Color(0xFFCBD5E1) : AppTheme.textMuted),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${paceResult.remainingOutings} saída(s) restante(s)',
                style: TextStyle(
                  color: isSunMode
                      ? Colors.black
                      : (isDark ? const Color(0xFFCBD5E1) : AppTheme.textDark),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSunMode
                  ? Colors.white
                  : (paceResult.isGoalReached
                      ? AppTheme.successGreen.withValues(alpha: 0.12)
                      : (isDark
                          ? const Color(0xFF0F172A)
                          : AppTheme.primaryBlue.withValues(alpha: 0.08))),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSunMode
                    ? Colors.black
                    : (paceResult.isGoalReached
                        ? AppTheme.successGreen.withValues(alpha: 0.3)
                        : (isDark
                            ? const Color(0xFF334155)
                            : AppTheme.primaryBlue.withValues(alpha: 0.2))),
                width: isSunMode ? 2.0 : 1.0,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  paceResult.isGoalReached ? Icons.celebration : Icons.schedule,
                  color: isSunMode
                        ? Colors.black
                        : (paceResult.isGoalReached
                            ? AppTheme.successGreen
                            : (isDark ? const Color(0xFF60A5FA) : AppTheme.primaryBlue)),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    paceResult.formattedPaceText,
                    style: TextStyle(
                      color: isSunMode
                          ? Colors.black
                          : (paceResult.isGoalReached
                              ? AppTheme.successGreen
                              : (isDark ? Colors.white : AppTheme.textDark)),
                      fontSize: 13,
                      fontWeight: isSunMode ? FontWeight.w900 : FontWeight.bold,
                    ),
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

class _PioneerPaceConfigDialog extends StatefulWidget {
  final double initialGoal;
  final List<int> initialWeekdays;
  final bool isDark;
  final bool isSunMode;
  final Future<void> Function(double goal, List<int> weekdays) onSave;

  const _PioneerPaceConfigDialog({
    required this.initialGoal,
    required this.initialWeekdays,
    required this.isDark,
    required this.isSunMode,
    required this.onSave,
  });

  @override
  State<_PioneerPaceConfigDialog> createState() => _PioneerPaceConfigDialogState();
}

class _PioneerPaceConfigDialogState extends State<_PioneerPaceConfigDialog> {
  late double _tempGoal;
  late List<int> _tempWeekdays;
  late final TextEditingController _customController;

  static const _weekdayLabels = {
    1: 'Seg',
    2: 'Ter',
    3: 'Qua',
    4: 'Qui',
    5: 'Sex',
    6: 'Sáb',
    7: 'Dom',
  };

  @override
  void initState() {
    super.initState();
    _tempGoal = widget.initialGoal;
    _tempWeekdays = List<int>.from(widget.initialWeekdays);
    _customController = TextEditingController(
      text: _tempGoal == _tempGoal.roundToDouble()
          ? _tempGoal.toInt().toString()
          : _tempGoal.toStringAsFixed(1),
    );
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSunMode = widget.isSunMode;
    final isDark = widget.isDark;

    return AlertDialog(
      backgroundColor: isSunMode
          ? Colors.white
          : (isDark ? const Color(0xFF1E293B) : Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSunMode
              ? Colors.black
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: isSunMode ? 2.0 : 1.0,
        ),
      ),
      title: Row(
        children: [
          Icon(
            Icons.tune,
            color: isSunMode
                ? Colors.black
                : (isDark ? const Color(0xFF60A5FA) : AppTheme.primaryBlue),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Configurar Ritmo de Campo',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isSunMode
                    ? Colors.black
                    : (isDark ? Colors.white : AppTheme.textDark),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Meta Mensal de Horas:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isSunMode
                    ? Colors.black
                    : (isDark ? const Color(0xFFCBD5E1) : AppTheme.textDark),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [50.0, 30.0, 15.0].map((preset) {
                final isSel = _tempGoal == preset;
                final label = preset == 50.0
                    ? '50h (Regular)'
                    : (preset == 30.0 ? '30h (Auxiliar)' : '15h (Reduzida)');
                return ChoiceChip(
                  label: Text(label),
                  selected: isSel,
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  selectedColor: isSunMode
                      ? Colors.black
                      : (isDark ? const Color(0xFF3B82F6) : AppTheme.primaryBlue),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                    color: isSel
                        ? Colors.white
                        : (isSunMode
                            ? Colors.black
                            : (isDark ? const Color(0xFFCBD5E1) : AppTheme.textDark)),
                  ),
                  onSelected: (val) {
                    if (val) {
                      setState(() {
                        _tempGoal = preset;
                        _customController.text = preset.toInt().toString();
                      });
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _customController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(
                color: isSunMode
                    ? Colors.black
                    : (isDark ? Colors.white : AppTheme.textDark),
                fontSize: 14,
              ),
              decoration: InputDecoration(
                labelText: 'Horas personalizadas',
                suffixText: 'h',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: const OutlineInputBorder(),
                labelStyle: TextStyle(
                  color: isSunMode
                      ? Colors.black
                      : (isDark ? const Color(0xFF94A3B8) : AppTheme.textMuted),
                ),
              ),
              onChanged: (val) {
                final parsed = double.tryParse(val.replaceAll(',', '.'));
                if (parsed != null && parsed > 0) {
                  setState(() => _tempGoal = parsed);
                }
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Dias habituais de campo na semana:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isSunMode
                    ? Colors.black
                    : (isDark ? const Color(0xFFCBD5E1) : AppTheme.textDark),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [1, 2, 3, 4, 5, 6, 7].map((day) {
                final isSelected = _tempWeekdays.contains(day);
                return FilterChip(
                  label: Text(_weekdayLabels[day] ?? '$day'),
                  selected: isSelected,
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  selectedColor: isSunMode
                      ? Colors.black.withValues(alpha: 0.15)
                      : (isDark
                          ? const Color(0xFF3B82F6).withValues(alpha: 0.3)
                          : AppTheme.primaryBlue.withValues(alpha: 0.2)),
                  checkmarkColor: isSunMode
                      ? Colors.black
                      : (isDark ? const Color(0xFF60A5FA) : AppTheme.primaryBlue),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected
                        ? (isSunMode
                            ? Colors.black
                            : (isDark ? Colors.white : AppTheme.primaryBlue))
                        : (isSunMode
                            ? Colors.black87
                            : (isDark ? const Color(0xFFCBD5E1) : AppTheme.textMuted)),
                  ),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _tempWeekdays.add(day);
                        _tempWeekdays.sort();
                      } else {
                        _tempWeekdays.remove(day);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(
            minimumSize: const Size(48, 48),
          ),
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancelar',
            style: TextStyle(
              color: isSunMode
                  ? Colors.black
                  : (isDark ? const Color(0xFFCBD5E1) : AppTheme.textMuted),
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isSunMode
                ? Colors.black
                : (isDark ? const Color(0xFF3B82F6) : AppTheme.primaryBlue),
            foregroundColor: Colors.white,
            minimumSize: const Size(48, 48),
          ),
          onPressed: () async {
            FocusScope.of(context).unfocus();
            await widget.onSave(_tempGoal, _tempWeekdays);
            if (context.mounted) {
              Navigator.pop(context);
            }
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
