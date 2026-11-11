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

  /// Conjunto canônico de nomes de colunas/propriedades de data/hora do aplicativo.
  static const Set<String> dateFieldKeys = {
    'createdAt', 'created_at',
    'updatedAt', 'updated_at',
    'deletedAt', 'deleted_at',
    'date', 'dateTime', 'dateTimeField', 'date_time', 'date_time_field',
    'firstContactAt', 'first_contact_at',
    'lastContactAt', 'last_contact_at',
    'nextActionAt', 'next_action_at',
    'suggestedReturnDate', 'suggested_return_date',
    'startedAt', 'started_at',
    'lastSessionAt', 'last_session_at',
    'nextPlannedAt', 'next_planned_at',
    'startTime', 'start_time',
    'endTime', 'end_time',
    'lastAttemptAt', 'last_attempt_at',
    'lastModifiedExternal', 'last_modified_external',
    'lastSyncedAt', 'last_synced_at',
    'capturedAt', 'captured_at',
    'processedAt', 'processed_at',
    'startDate', 'start_date',
    'targetDate', 'target_date',
    'completedAt', 'completed_at',
    'dueDate', 'due_date',
    'scheduledAt', 'scheduled_at',
    'answeredAt', 'answered_at',
    'lastReviewedAt', 'last_reviewed_at',
  };

  /// Normaliza todos os campos de data conhecidos de um mapa (ex: `entry.toJson()`)
  /// para strings ISO-8601 UTC, evitando inteiros epoch em JSONs enviados ao Supabase.
  static Map<String, dynamic> normalizeMapDates(Map<String, dynamic> input) {
    final result = Map<String, dynamic>.from(input);
    for (final key in result.keys.toList()) {
      final val = result[key];
      if (val == null || !dateFieldKeys.contains(key)) continue;
      if (val is String && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(val.trim())) {
        continue;
      }
      final iso = toIso8601String(val);
      if (iso != null) {
        result[key] = iso;
      }
    }
    return result;
  }
}
