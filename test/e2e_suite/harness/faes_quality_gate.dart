/// Dimensão oficial de avaliação do Field Assistant Engineering Standard (FAES §3).
class FaesDimension {
  final String key;
  final String name;
  final double weight;
  const FaesDimension(this.key, this.name, this.weight);
}

/// Veredito do Quality Gate FAES 10/10.
enum FaesGateVerdict { approved, notApproved, blocked }

/// Resultado estruturado da avaliação do FAES Quality Gate.
class FaesEvaluationResult {
  final double weightedScore;
  final FaesGateVerdict verdict;
  final bool isApproved;
  final List<String> violations;
  final Map<String, double> dimensionScores;

  const FaesEvaluationResult({
    required this.weightedScore,
    required this.verdict,
    required this.isApproved,
    required this.violations,
    required this.dimensionScores,
  });
}

/// Avaliador determinístico do FAES Quality Gate (§3).
class FaesQualityGateEvaluator {
  static const List<FaesDimension> dimensions = [
    FaesDimension('functional', 'Functional correctness & user journey', 0.15),
    FaesDimension('data_integrity', 'Data integrity, migrations & recoverability', 0.15),
    FaesDimension('security', 'Security, privacy & account isolation', 0.15),
    FaesDimension('offline_sync', 'Offline-first & synchronization correctness', 0.12),
    FaesDimension('architecture', 'Architecture & maintainability', 0.10),
    FaesDimension('ux_ios', 'UX, accessibility & iOS/iPadOS quality', 0.10),
    FaesDimension('tests', 'Automated tests & regression evidence', 0.10),
    FaesDimension('performance', 'Performance & resource efficiency', 0.05),
    FaesDimension('documentation', 'Documentation & operability', 0.04),
    FaesDimension('release_ci', 'Release/CI/CD & reproducibility', 0.04),
  ];

  static const double minimumDimensionScore = 9.0;
  static const double minimumWeightedScore = 9.70;

  static FaesEvaluationResult evaluate({
    required Map<String, double> scores,
    int unresolvedP0 = 0,
    int unresolvedP1 = 0,
    bool isBlocked = false,
  }) {
    if (isBlocked) {
      return FaesEvaluationResult(
        weightedScore: 0.0,
        verdict: FaesGateVerdict.blocked,
        isApproved: false,
        violations: const ['Ambiente ou dependência externa bloqueante ativa.'],
        dimensionScores: scores,
      );
    }

    final violations = <String>[];
    var weightedSum = 0.0;

    for (final dim in dimensions) {
      final score = scores[dim.key];
      if (score == null) {
        throw ArgumentError('Dimensão obrigatória ausente: ${dim.key}');
      }
      if (score < 0.0 || score > 10.0) {
        throw ArgumentError('Pontuação fora da faixa 0-10 para ${dim.key}: $score');
      }

      if (score < minimumDimensionScore) {
        violations.add(
          'Hard gate violado: dimensão "${dim.name}" com nota ${score.toStringAsFixed(2)} < $minimumDimensionScore',
        );
      }
      weightedSum += score * dim.weight;
    }

    // Arredondamento para 4 casas decimais para evitar imprecisões de ponto flutuante
    final finalScore = double.parse(weightedSum.toStringAsFixed(4));

    if (finalScore < minimumWeightedScore) {
      violations.add(
        'Hard gate violado: nota ponderada ${finalScore.toStringAsFixed(2)} < $minimumWeightedScore',
      );
    }

    if (unresolvedP0 > 0) {
      violations.add('Hard gate violado: $unresolvedP0 issue(s) P0 crítico(s) não resolvido(s).');
    }
    if (unresolvedP1 > 0) {
      violations.add('Hard gate violado: $unresolvedP1 issue(s) P1 de alta severidade não resolvido(s).');
    }

    final approved = violations.isEmpty;
    return FaesEvaluationResult(
      weightedScore: finalScore,
      verdict: approved ? FaesGateVerdict.approved : FaesGateVerdict.notApproved,
      isApproved: approved,
      violations: violations,
      dimensionScores: Map.unmodifiable(scores),
    );
  }
}
