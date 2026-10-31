import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../activities/auto_corrective_timer_logic.dart';

class AutoCorrectiveTimerDialog extends StatelessWidget {
  final AutoCorrectiveTimerState state;
  final ValueChanged<Duration> onApplyAdjustment;
  final VoidCallback onKeepCurrent;
  final VoidCallback onDiscard;

  const AutoCorrectiveTimerDialog({
    super.key,
    required this.state,
    required this.onApplyAdjustment,
    required this.onKeepCurrent,
    required this.onDiscard,
  });

  static Future<void> show(
    BuildContext context, {
    required AutoCorrectiveTimerState state,
    required ValueChanged<Duration> onApplyAdjustment,
    required VoidCallback onKeepCurrent,
    required VoidCallback onDiscard,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AutoCorrectiveTimerDialog(
        state: state,
        onApplyAdjustment: onApplyAdjustment,
        onKeepCurrent: onKeepCurrent,
        onDiscard: onDiscard,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.hourglass_top, color: Color(0xFFD97706), size: 24),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Aviso de Cronômetro Ligado',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
              state.userFriendlyMessage,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white : AppTheme.textDark,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text('Tempo Atual', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                      const SizedBox(height: 4),
                      Text(
                        state.elapsedFormatted,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange),
                      ),
                    ],
                  ),
                  Container(width: 1, height: 32, color: Colors.grey.shade300),
                  Column(
                    children: [
                      const Text('Sugerido', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                      const SizedBox(height: 4),
                      Text(
                        state.suggestedFormatted,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.greenAccent),
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
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            onDiscard();
          },
          child: const Text('Zerar', style: TextStyle(color: Colors.redAccent)),
        ),
        OutlinedButton(
          onPressed: () {
            Navigator.pop(context);
            onKeepCurrent();
          },
          child: const Text('Manter Atual'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
          onPressed: () {
            Navigator.pop(context);
            onApplyAdjustment(state.suggestedAdjustment);
          },
          child: Text('Ajustar p/ ${state.suggestedFormatted}'),
        ),
      ],
    );
  }
}
