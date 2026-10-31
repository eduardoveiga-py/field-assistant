import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/activities/auto_corrective_timer_logic.dart';

void main() {
  group('AutoCorrectiveTimerLogic (R5 - Cronômetro Auto-Corretivo)', () {
    final baseStart = DateTime(2026, 10, 20, 8, 0); // 08:00

    test('Cronômetro não rodando não emite alerta de esquecimento', () {
      final state = AutoCorrectiveTimerLogic.evaluate(
        isRunning: false,
        startedAt: baseStart,
        accumulatedDuration: const Duration(hours: 5),
        nowOverride: baseStart.add(const Duration(hours: 5)),
      );

      expect(state.shouldShowWarning, isFalse);
      expect(state.warningReason, equals('normal'));
    });

    test('Cronômetro em execução há menos de 4 horas não emite alerta', () {
      final state = AutoCorrectiveTimerLogic.evaluate(
        isRunning: true,
        startedAt: baseStart,
        accumulatedDuration: Duration.zero,
        nowOverride: baseStart.add(const Duration(hours: 2, minutes: 30)),
      );

      expect(state.shouldShowWarning, isFalse);
      expect(state.elapsedDuration, equals(const Duration(hours: 2, minutes: 30)));
    });

    test('Cronômetro em execução há mais de 4 horas emite alerta de long_running', () {
      // 08:00 às 13:15 = 5h15m
      final state = AutoCorrectiveTimerLogic.evaluate(
        isRunning: true,
        startedAt: baseStart,
        accumulatedDuration: Duration.zero,
        nowOverride: baseStart.add(const Duration(hours: 5, minutes: 15)),
      );

      expect(state.shouldShowWarning, isTrue);
      expect(state.warningReason, equals('long_running'));
      expect(state.elapsedFormatted, equals('5h15m'));
      expect(state.suggestedAdjustment, equals(const Duration(hours: 2)));
      expect(state.userFriendlyMessage, contains('5h15m'));
      expect(state.userFriendlyMessage, contains('tempo real de campo'));
    });

    test('Detecção de reabertura após inatividade prolongada (reopened_inactive)', () {
      // Iniciou às 08:00, último heartbeat às 10:15 (2h15 de campo)
      // Reabriu às 15:30 (gap de mais de 5 horas sem heartbeat)
      final lastHb = baseStart.add(const Duration(hours: 2, minutes: 15));
      final reopenTime = baseStart.add(const Duration(hours: 7, minutes: 30));

      final state = AutoCorrectiveTimerLogic.evaluate(
        isRunning: true,
        startedAt: baseStart,
        accumulatedDuration: Duration.zero,
        lastHeartbeat: lastHb,
        nowOverride: reopenTime,
      );

      expect(state.shouldShowWarning, isTrue);
      expect(state.warningReason, equals('reopened_inactive'));
      expect(state.suggestedAdjustment, equals(const Duration(hours: 2, minutes: 15)));
      expect(state.userFriendlyMessage, contains('esqueceu ligado'));
    });

    test('Formatação precisa de horas e minutos em elapsedFormatted e suggestedFormatted', () {
      final state = AutoCorrectiveTimerLogic.evaluate(
        isRunning: true,
        startedAt: baseStart,
        accumulatedDuration: Duration.zero,
        nowOverride: baseStart.add(const Duration(hours: 4, minutes: 5)),
      );

      expect(state.elapsedFormatted, equals('4h05m'));
      expect(state.suggestedFormatted, equals('2h00m'));
    });
  });
}
