/// Estado resultante da avaliação do cronômetro auto-corretivo (R5)
class AutoCorrectiveTimerState {
  final bool shouldShowWarning;
  final Duration elapsedDuration;
  final String warningReason; // 'long_running', 'reopened_inactive', 'normal'
  final Duration suggestedAdjustment;
  final String userFriendlyMessage;

  const AutoCorrectiveTimerState({
    required this.shouldShowWarning,
    required this.elapsedDuration,
    required this.warningReason,
    required this.suggestedAdjustment,
    required this.userFriendlyMessage,
  });

  String get elapsedFormatted {
    final h = elapsedDuration.inHours;
    final m = elapsedDuration.inMinutes.remainder(60);
    return '${h}h${m.toString().padLeft(2, '0')}m';
  }

  String get suggestedFormatted {
    final h = suggestedAdjustment.inHours;
    final m = suggestedAdjustment.inMinutes.remainder(60);
    return '${h}h${m.toString().padLeft(2, '0')}m';
  }
}

/// Lógica pura para verificação de esquecimento de cronômetro ligado (R5)
class AutoCorrectiveTimerLogic {
  /// Limite padrão contínuo antes de emitir alerta (4 horas)
  static const Duration longRunningThreshold = Duration(hours: 4);

  /// Limite de inatividade para detectar app reaberto após esquecimento
  static const Duration inactiveHeartbeatGap = Duration(hours: 2);

  /// Duração padrão sugerida para saídas normais de ministério (2 horas)
  static const Duration defaultSuggestedSession = Duration(hours: 2);

  static AutoCorrectiveTimerState evaluate({
    required bool isRunning,
    required DateTime startedAt,
    required Duration accumulatedDuration,
    DateTime? lastHeartbeat,
    DateTime? nowOverride,
    Duration threshold = longRunningThreshold,
  }) {
    if (!isRunning) {
      return AutoCorrectiveTimerState(
        shouldShowWarning: false,
        elapsedDuration: accumulatedDuration,
        warningReason: 'normal',
        suggestedAdjustment: accumulatedDuration,
        userFriendlyMessage: '',
      );
    }

    final now = nowOverride ?? DateTime.now();
    final currentSessionDuration = now.difference(startedAt);
    final totalElapsed = accumulatedDuration + (currentSessionDuration.isNegative ? Duration.zero : currentSessionDuration);

    // Caso 1: Reabertura após longo período de inatividade
    if (lastHeartbeat != null && now.difference(lastHeartbeat) >= inactiveHeartbeatGap) {
      final hbDiff = lastHeartbeat.difference(startedAt);
      final activePortion = accumulatedDuration + (hbDiff.isNegative ? Duration.zero : hbDiff);
      final suggested = activePortion.inMinutes > 15 ? activePortion : defaultSuggestedSession;

      final h = totalElapsed.inHours;
      final m = totalElapsed.inMinutes.remainder(60);

      return AutoCorrectiveTimerState(
        shouldShowWarning: true,
        elapsedDuration: totalElapsed,
        warningReason: 'reopened_inactive',
        suggestedAdjustment: suggested,
        userFriendlyMessage:
            'O cronômetro continuou em execução (${h}h${m.toString().padLeft(2, '0')}m). Você esqueceu ligado após retornar do campo?',
      );
    }

    // Caso 2: Cronômetro rodando continuamente além do limite configurado (>= 4 horas)
    if (totalElapsed >= threshold) {
      final h = totalElapsed.inHours;
      final m = totalElapsed.inMinutes.remainder(60);

      return AutoCorrectiveTimerState(
        shouldShowWarning: true,
        elapsedDuration: totalElapsed,
        warningReason: 'long_running',
        suggestedAdjustment: defaultSuggestedSession,
        userFriendlyMessage:
            'O cronômetro está rodando há ${h}h${m.toString().padLeft(2, '0')}m. Deseja ajustar para o tempo real de campo?',
      );
    }

    return AutoCorrectiveTimerState(
      shouldShowWarning: false,
      elapsedDuration: totalElapsed,
      warningReason: 'normal',
      suggestedAdjustment: totalElapsed,
      userFriendlyMessage: '',
    );
  }
}
