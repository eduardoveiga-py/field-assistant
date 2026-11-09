/// Utilitário universal para parsing seguro e resiliente de carimbos de data/hora (Timestamps).
/// Elimina inconsistências onde timestamps em milissegundos numéricos (ex: "1731112233000")
/// falham no DateTime.tryParse() tradicional e retornam nulo, causando sobrescrita incorreta de dados.
class SyncTimestamp {
  SyncTimestamp._();

  /// Interpreta com robustez inteiros (ms ou s), strings numéricas, ISO-8601 e instâncias DateTime.
  static DateTime? parse(dynamic value) {
    if (value == null) return null;

    if (value is DateTime) {
      return value.isUtc ? value : value.toUtc();
    }

    if (value is int) {
      // Se for maior que 10^11, é milissegundos da época (ex: 1731112233000)
      if (value > 100000000000) {
        return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
      }
      // Se for maior que 10^8, é segundos da época (ex: 1731112233)
      if (value > 100000000) {
        return DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: true);
      }
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
    }

    if (value is double) {
      return parse(value.toInt());
    }

    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;

      // Verifica se é uma sequência puramente numérica (timestamp epoch)
      final numVal = int.tryParse(trimmed);
      if (numVal != null && numVal > 100000000) {
        return parse(numVal);
      }

      // Tenta parser ISO-8601 padrão
      final parsedIso = DateTime.tryParse(trimmed);
      if (parsedIso != null) {
        return parsedIso.isUtc ? parsedIso : parsedIso.toUtc();
      }
    }

    return null;
  }

  /// Converte qualquer representação válida de data/hora em string canônica ISO-8601 UTC.
  static String? toIso8601String(dynamic value) {
    final dt = parse(value);
    return dt?.toIso8601String();
  }
}
