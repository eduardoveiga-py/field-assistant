import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/app_database.dart';
import '../../core/app_logger.dart';
import '../../ui/providers.dart' as global_providers;

/// Resultado do algoritmo de repetição espaçada SM-2
class Sm2ReviewResult {
  final int nextIntervalDays;
  final int newRepetitions;
  final double newEasinessFactor;

  const Sm2ReviewResult({
    required this.nextIntervalDays,
    required this.newRepetitions,
    required this.newEasinessFactor,
  });
}

/// Serviço de assistência linguística multilíngue e histórico de pesquisas
class MultilingualAssistantService {
  final AppDatabase _db;
  static const String searchHistoryKey = 'language_search_history_v1';
  static const int maxSearchHistoryItems = 15;

  MultilingualAssistantService(this._db);

  /// Algoritmo padrão SuperMemo-2 (SM-2) para cartões de vocabulário e frases.
  /// [quality]: 0 a 5 (0 = esquecimento total, 5 = resposta perfeita sem esforço).
  /// [repetitions]: número de repetições consecutivas com sucesso.
  /// [previousIntervalDays]: intervalo anterior em dias.
  /// [previousEasinessFactor]: fator de facilidade anterior (mínimo 1.3, padrão 2.5).
  static Sm2ReviewResult calculateSm2({
    required int quality,
    required int repetitions,
    required int previousIntervalDays,
    double previousEasinessFactor = 2.5,
  }) {
    final q = quality.clamp(0, 5);
    double ef = previousEasinessFactor + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02));
    if (ef < 1.3) ef = 1.3;

    int newReps;
    int nextInterval;

    if (q >= 3) {
      newReps = repetitions + 1;
      if (newReps == 1) {
        nextInterval = 1;
      } else if (newReps == 2) {
        nextInterval = 6;
      } else {
        final calc = (previousIntervalDays * ef).round();
        nextInterval = calc < 1 ? 1 : calc;
      }
    } else {
      newReps = 0;
      nextInterval = 1;
    }

    return Sm2ReviewResult(
      nextIntervalDays: nextInterval,
      newRepetitions: newReps,
      newEasinessFactor: ef,
    );
  }

  /// Recupera o histórico de termos pesquisados recentemente
  Future<List<String>> getSearchHistory() async {
    try {
      final row = await (_db.select(_db.appKvStore)
            ..where((t) => t.key.equals(searchHistoryKey)))
          .getSingleOrNull();
      if (row == null || row.value.isEmpty) return [];
      final decoded = jsonDecode(row.value) as List<dynamic>;
      return decoded.map((e) => e.toString()).toList();
    } catch (e) {
      AppLogger.warning('Erro ao carregar histórico de buscas linguísticas: $e');
      return [];
    }
  }

  /// Registra um novo termo no histórico de buscas
  Future<void> addSearchTerm(String term) async {
    final clean = term.trim();
    if (clean.isEmpty) return;

    try {
      final current = await getSearchHistory();
      final updated = [clean, ...current.where((t) => t.toLowerCase() != clean.toLowerCase())];
      if (updated.length > maxSearchHistoryItems) {
        updated.removeRange(maxSearchHistoryItems, updated.length);
      }

      await _db.into(_db.appKvStore).insertOnConflictUpdate(
        AppKvStoreCompanion.insert(
          key: searchHistoryKey,
          value: jsonEncode(updated),
        ),
      );
    } catch (e) {
      AppLogger.warning('Erro ao salvar termo no histórico: $e');
    }
  }

  /// Limpa todo o histórico de pesquisas
  Future<void> clearSearchHistory() async {
    try {
      await (_db.delete(_db.appKvStore)
            ..where((t) => t.key.equals(searchHistoryKey)))
          .go();
    } catch (e, st) {
      AppLogger.warning('Falha ao limpar histórico de pesquisas linguísticas', e, st);
    }
  }
}

/// Provider do serviço de assistência linguística
final multilingualAssistantServiceProvider =
    Provider<MultilingualAssistantService>((ref) {
  final db = ref.watch(global_providers.databaseProvider);
  return MultilingualAssistantService(db);
});
