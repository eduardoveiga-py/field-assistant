import '../database/app_database.dart';

/// Helper de identificação e rotulagem de "Sementes Recentes" (R3)
///
/// Pessoas contatadas nos últimos 7 dias que ainda não receberam a primeira revisita.
class RecentSeedsHelper {
  /// Determina se o contato é uma Semente Recente (< 7 dias e sem revisita realizada)
  static bool isRecentSeed({
    required PersonEntry person,
    required List<VisitEntry> visits,
    DateTime? nowOverride,
  }) {
    if (person.deletedAt != null) return false;
    final status = person.status.toLowerCase();
    if (status == 'estudo' || status == 'arquivado' || status == 'encerrado') {
      return false;
    }

    final now = nowOverride ?? DateTime.now();
    final firstContactDate = person.firstContactAt;
    final diff = now.difference(firstContactDate);

    // Apenas contatos registrados nos últimos 7 dias (limite estrito de 7 dias)
    if (diff.isNegative || diff.inSeconds > 7 * 86400) {
      return false;
    }

    // Verifica se já teve ao menos uma revisita realizada após o primeiro contato
    final hasReturnVisit = visits.any((v) {
      if (v.personId != person.id || v.deletedAt != null) return false;
      final cType = v.contactType.toLowerCase();
      final res = v.result.toLowerCase();

      // Desconsidera tentativas em que a pessoa não foi encontrada
      if (res == 'nao_encontrado' ||
          res == 'cancelado' ||
          res == 'nao_atendeu' ||
          res == 'ninguem_atendeu' ||
          cType == 'tentativa_sem_contato') {
        return false;
      }

      // Se for revisita ou estudo com sucesso
      return cType == 'revisita' || cType == 'estudo';
    });

    return !hasReturnVisit;
  }

  /// Retorna o rótulo amigável humanizado para o badge do card (R3)
  /// Ex: "Plantada há 3 dias — Revisitar logo" ou "Plantada hoje — Revisitar logo"
  static String getFriendlyElapsedLabel({
    required DateTime firstContactAt,
    DateTime? nowOverride,
  }) {
    final now = nowOverride ?? DateTime.now();
    final diff = now.difference(firstContactAt);
    final diffDays = diff.inDays;

    if (diffDays <= 0) {
      return 'Plantada hoje — Revisitar logo';
    } else if (diffDays == 1) {
      return 'Plantada há 1 dia — Revisitar logo';
    } else if (diffDays < 7) {
      return 'Plantada há $diffDays dias — Revisitar logo';
    } else {
      return 'Plantada há 7 dias — Limite para revisita!';
    }
  }

  /// Retorna o texto humanizado com o tempo decorrido e contagem regressiva de atenção
  static String getElapsedText({
    required DateTime firstContactAt,
    DateTime? nowOverride,
  }) {
    final now = nowOverride ?? DateTime.now();
    final diffDays = now.difference(firstContactAt).inDays;

    if (diffDays <= 0) {
      return '🌱 Semente Recente (encontrada hoje • ideal revisitar em até 7 dias)';
    } else if (diffDays == 1) {
      return '🌱 Semente Recente (1º contato ontem • faltam 6 dias para retorno)';
    } else if (diffDays < 7) {
      final remaining = 7 - diffDays;
      return '🌱 Semente Recente (1º contato há $diffDays dias • faltam $remaining dias)';
    } else if (diffDays == 7) {
      return '⚠️ Semente Recente no Limite (1º contato há 7 dias • revisite hoje!)';
    } else {
      return '1º contato há $diffDays dias';
    }
  }

  /// Retorna etiqueta curta para badges em cards
  static String getBadgeLabel({
    required DateTime firstContactAt,
    DateTime? nowOverride,
  }) {
    final now = nowOverride ?? DateTime.now();
    final diffDays = now.difference(firstContactAt).inDays;

    if (diffDays <= 0) return '🌱 Recente (Hoje)';
    if (diffDays == 1) return '🌱 Recente (1d)';
    return '🌱 Recente (${diffDays}d)';
  }
}
