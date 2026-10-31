import 'dart:math' as math;

/// Resultado do cálculo do ritmo de campo do pioneiro (R2)
class PioneerPaceResult {
  final double goalHours;
  final double completedHours;
  final double remainingHours;
  final int remainingOutings;
  final Duration idealPacePerOuting;
  final bool isGoalReached;
  final String formattedPaceText;

  const PioneerPaceResult({
    required this.goalHours,
    required this.completedHours,
    required this.remainingHours,
    required this.remainingOutings,
    required this.idealPacePerOuting,
    required this.isGoalReached,
    required this.formattedPaceText,
  });

  /// Formatação abreviada do ritmo ideal (ex: "2h15m", "3h36m")
  String get idealPaceFormatted {
    final h = idealPacePerOuting.inHours;
    final m = idealPacePerOuting.inMinutes.remainder(60);
    return '${h}h${m.toString().padLeft(2, '0')}m';
  }
}

/// Calculadora do Ritmo Real de Campo para Pioneiros e Publicadores
class PioneerPaceCalculator {
  /// Calcula o ritmo ideal de horas por saída restante no mês corrente
  ///
  /// [goalHours]: meta do mês (ex: 50.0 para pioneiro regular, 30.0 para auxiliar)
  /// [designatedWeekdays]: dias habituais da semana (1=Segunda ... 7=Domingo)
  /// [completedHours]: total de horas realizadas no mês até agora
  /// [currentDate]: data de referência (geralmente hoje)
  static PioneerPaceResult calculate({
    required double goalHours,
    required List<int> designatedWeekdays,
    required double completedHours,
    required DateTime currentDate,
  }) {
    final safeGoal = math.max(0.0, goalHours);
    final safeCompleted = math.max(0.0, completedHours);
    final bool isGoalReached = safeCompleted >= safeGoal && safeGoal > 0;
    final double remainingHours = isGoalReached ? 0.0 : math.max(0.0, safeGoal - safeCompleted);

    // Contagem de saídas programadas restantes no mês (do dia atual até o último dia do mês)
    const daysInMonth = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    int lastDayOfMonth = daysInMonth[currentDate.month];
    if (currentDate.month == 2) {
      final y = currentDate.year;
      if ((y % 4 == 0 && y % 100 != 0) || (y % 400 == 0)) {
        lastDayOfMonth = 29;
      }
    }

    int remainingOutings = 0;
    if (designatedWeekdays.isNotEmpty) {
      int currentWeekday = currentDate.weekday;
      for (int day = currentDate.day; day <= lastDayOfMonth; day++) {
        if (designatedWeekdays.contains(currentWeekday)) {
          remainingOutings++;
        }
        currentWeekday = (currentWeekday % 7) + 1;
      }
    }

    Duration idealPacePerOuting = Duration.zero;
    String formattedPaceText;

    if (isGoalReached) {
      formattedPaceText = 'Meta atingida! Parabéns pelo empenho no ministério.';
    } else if (remainingOutings == 0) {
      final totalMin = (remainingHours * 60).round();
      idealPacePerOuting = Duration(minutes: totalMin);
      final hoursPart = totalMin ~/ 60;
      final minPart = totalMin % 60;
      final hoursStr = remainingHours.truncateToDouble() == remainingHours
          ? remainingHours.toStringAsFixed(0)
          : remainingHours.toStringAsFixed(1);
      formattedPaceText = 'Faltam ${hoursStr}h em 0 saídas. Seu ritmo ideal é de ${hoursPart}h${minPart.toString().padLeft(2, '0')}m por saída';
    } else {
      final totalMin = ((remainingHours / remainingOutings) * 60).round();
      idealPacePerOuting = Duration(minutes: totalMin);
      final hoursPart = totalMin ~/ 60;
      final minPart = totalMin % 60;
      final hoursStr = remainingHours.truncateToDouble() == remainingHours
          ? remainingHours.toStringAsFixed(0)
          : remainingHours.toStringAsFixed(1);
      formattedPaceText = 'Faltam ${hoursStr}h em $remainingOutings saídas. Seu ritmo ideal é de ${hoursPart}h${minPart.toString().padLeft(2, '0')}m por saída';
    }

    return PioneerPaceResult(
      goalHours: safeGoal,
      completedHours: safeCompleted,
      remainingHours: remainingHours,
      remainingOutings: remainingOutings,
      idealPacePerOuting: idealPacePerOuting,
      isGoalReached: isGoalReached,
      formattedPaceText: formattedPaceText,
    );
  }
}
