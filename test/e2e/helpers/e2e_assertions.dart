import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// =============================================================================
// Custom Matcher: isValidAudioBytes
// =============================================================================

/// Matcher que valida se o alvo representa bytes de áudio autênticos e válidos:
/// - O alvo deve ser [File], [List<int>] ou [Uint8List].
/// - Se for [File], deve existir fisicamente no disco.
/// - O tamanho dos bytes deve ser estritamente maior que 64 bytes.
/// - Os bytes não podem ser preenchidos exclusivamente por zeros (rejeita arquivos dummy).
Matcher isValidAudioBytes() => const _ValidAudioBytesMatcher();

class _ValidAudioBytesMatcher extends Matcher {
  const _ValidAudioBytesMatcher();

  @override
  bool matches(dynamic item, Map matchState) {
    List<int> bytes;
    if (item is File) {
      if (!item.existsSync()) {
        matchState['reason'] = 'Arquivo de áudio não existe: ${item.path}';
        return false;
      }
      bytes = item.readAsBytesSync();
    } else if (item is List<int>) {
      bytes = item;
    } else {
      matchState['reason'] =
          'O item não é uma instância de File nem de List<int> (tipo: ${item.runtimeType})';
      return false;
    }

    if (bytes.length <= 64) {
      matchState['reason'] =
          'Tamanho do buffer de áudio é de ${bytes.length} bytes (deve ser estritamente > 64 bytes)';
      return false;
    }

    final hasNonZero = bytes.any((b) => b != 0);
    if (!hasNonZero) {
      matchState['reason'] =
          'Arquivo de áudio preenchido exclusivamente com zeros (${bytes.length} bytes de valor 0). Arquivo simulado rejeitado.';
      return false;
    }

    final isRiffWave = bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x41 &&
        bytes[10] == 0x56 &&
        bytes[11] == 0x45;
    if (isRiffWave && !bytes.skip(44).any((b) => b != 0)) {
      matchState['reason'] =
          'Arquivo RIFF/WAVE contém cabeçalho, porém amostras PCM após os 44 bytes estão zeradas.';
      return false;
    }

    return true;
  }

  @override
  Description describe(Description description) => description.add(
    'bytes de áudio válidos (> 64 bytes, contendo forma de onda com bytes não zerados)',
  );

  @override
  Description describeMismatch(
    dynamic item,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) {
    final reason = matchState['reason'] as String? ?? 'áudio inválido';
    return mismatchDescription.add(reason);
  }
}

// =============================================================================
// Custom Matcher: isSantoAntonioDoIcaCoordinate
// =============================================================================

/// Matcher que valida se as coordenadas correspondem a Santo Antônio do Içá, AM
/// (latitude aproximada de -3.1022 e longitude aproximada de -67.9397) dentro da tolerância.
Matcher isSantoAntonioDoIcaCoordinate({double tolerance = 0.005}) =>
    _SantoAntonioCoordinateMatcher(tolerance);

class _SantoAntonioCoordinateMatcher extends Matcher {
  static const double targetLat = -3.1022;
  static const double targetLng = -67.9397;
  final double tolerance;

  const _SantoAntonioCoordinateMatcher(this.tolerance);

  @override
  bool matches(dynamic item, Map matchState) {
    final coords = _extractCoordinates(item);
    if (coords == null) {
      matchState['reason'] =
          'Não foi possível extrair coordenadas (latitude/longitude) do item: $item';
      return false;
    }

    final latDiff = (coords.lat - targetLat).abs();
    final lngDiff = (coords.lng - targetLng).abs();

    if (latDiff > tolerance || lngDiff > tolerance) {
      matchState['reason'] =
          'Coordenadas (${coords.lat}, ${coords.lng}) divergem de Santo Antônio do Içá ($targetLat, $targetLng) por mais que a tolerância de $tolerance graus (difLat=$latDiff, difLng=$lngDiff)';
      return false;
    }

    return true;
  }

  @override
  Description describe(Description description) => description.add(
    'coordenadas próximas a Santo Antônio do Içá ($targetLat, $targetLng com tolerância $tolerance)',
  );

  @override
  Description describeMismatch(
    dynamic item,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) {
    final reason = matchState['reason'] as String? ?? 'coordenadas divergentes';
    return mismatchDescription.add(reason);
  }
}

// =============================================================================
// Custom Matcher: isNotSaoPauloCoordinate
// =============================================================================

/// Matcher que valida que as coordenadas NÃO apontam para o fallback legado de São Paulo
/// (-23.550520, -46.633308).
Matcher isNotSaoPauloCoordinate({double tolerance = 0.05}) =>
    _NotSaoPauloCoordinateMatcher(tolerance);

class _NotSaoPauloCoordinateMatcher extends Matcher {
  static const double spLat = -23.550520;
  static const double spLng = -46.633308;
  final double tolerance;

  const _NotSaoPauloCoordinateMatcher(this.tolerance);

  @override
  bool matches(dynamic item, Map matchState) {
    final coords = _extractCoordinates(item);
    if (coords == null) {
      return true; // Se não possui coordenadas, não é o fallback de SP
    }

    final latDiff = (coords.lat - spLat).abs();
    final lngDiff = (coords.lng - spLng).abs();

    if (latDiff < tolerance && lngDiff < tolerance) {
      matchState['reason'] =
          'Coordenadas (${coords.lat}, ${coords.lng}) coincidem com o centro legado de São Paulo ($spLat, $spLng). Fallback fictício proibido!';
      return false;
    }

    return true;
  }

  @override
  Description describe(Description description) => description.add(
    'coordenadas que não apontam para o fallback de São Paulo ($spLat, $spLng)',
  );

  @override
  Description describeMismatch(
    dynamic item,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) {
    final reason =
        matchState['reason'] as String? ??
        'coordenada identificada como São Paulo';
    return mismatchDescription.add(reason);
  }
}

// =============================================================================
// Custom Matcher: containsNoTheocraticSeeds
// =============================================================================

/// Matcher que valida que um texto, Map, List ou JSON não contém nenhuma das sementes
/// ou placeholders fictícios (como "Padaria Central Betânia", "seed_hub_letter_01", etc.).
Matcher containsNoTheocraticSeeds() => const _NoTheocraticSeedsMatcher();

class _NoTheocraticSeedsMatcher extends Matcher {
  static const List<String> forbiddenSeeds = [
    'Padaria Central Betânia',
    'Padaria Betânia',
    'Posto de Saúde Lago Grande',
    'Escola Municipal Cidade',
    'seed_hub_letter_01',
    'seed_hub_form_02',
    'seed_email_03',
    'seed_email_04',
    'Arranjos_Comemoracao_2026.pdf',
    'Formulario_S21_Instrucoes.pdf',
    'Programa_Assembleia_Circuito.pdf',
    'filial.br@hub.jw.org',
    'corpo.anciaos@jw.org',
    'secretaria@hub.jw.org',
  ];

  const _NoTheocraticSeedsMatcher();

  @override
  bool matches(dynamic item, Map matchState) {
    final text = (item is String ? item : jsonEncode(item)).toLowerCase();

    for (final seed in forbiddenSeeds) {
      if (text.contains(seed.toLowerCase())) {
        matchState['found_seed'] = seed;
        return false;
      }
    }
    return true;
  }

  @override
  Description describe(Description description) => description.add(
    'conteúdo isento de sementes teocráticas ou placeholders simulados',
  );

  @override
  Description describeMismatch(
    dynamic item,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) {
    final found = matchState['found_seed'] as String? ?? 'semente não nomeada';
    return mismatchDescription.add('contém semente proibida: "$found"');
  }
}

// =============================================================================
// Custom Matcher: isFullyHydratedSyncPayload
// =============================================================================

/// Matcher que valida se o payload de sincronização de uma tabela possui todas
/// as colunas obrigatórias NOT NULL preenchidas e com valor não nulo.
Matcher isFullyHydratedSyncPayload(String table) =>
    _FullyHydratedSyncPayloadMatcher(table);

class _FullyHydratedSyncPayloadMatcher extends Matcher {
  final String table;

  const _FullyHydratedSyncPayloadMatcher(this.table);

  static const Map<String, List<List<String>>> requiredColumnOptions = {
    'people': [
      ['id'],
      ['name'],
      ['first_contact_at', 'firstContactAt'],
      ['status'],
      ['created_at', 'createdAt'],
      ['updated_at', 'updatedAt'],
    ],
    'visits': [
      ['id'],
      ['person_id', 'personId'],
      ['date_time_field', 'dateTimeField'],
      ['contact_type', 'contactType'],
      ['result'],
      ['created_at', 'createdAt'],
      ['updated_at', 'updatedAt'],
    ],
    'bible_studies': [
      ['id'],
      ['title'],
      ['started_at', 'startedAt'],
      ['status'],
      ['publication_id', 'publicationId'],
      ['created_at', 'createdAt'],
      ['updated_at', 'updatedAt'],
    ],
    'study_participants': [
      ['id'],
      ['study_id', 'studyId'],
      ['person_id', 'personId'],
      ['created_at', 'createdAt'],
      ['updated_at', 'updatedAt'],
    ],
    'study_sessions': [
      ['id'],
      ['study_id', 'studyId'],
      ['date_time_field', 'dateTimeField'],
      ['status'],
      ['created_at', 'createdAt'],
      ['updated_at', 'updatedAt'],
    ],
    'appointments': [
      ['id'],
      ['title'],
      ['start_time', 'startTime'],
      ['end_time', 'endTime'],
      ['status'],
      ['created_at', 'createdAt'],
      ['updated_at', 'updatedAt'],
    ],
    'activity_records': [
      ['id'],
      ['date'],
      ['duration_seconds', 'durationSeconds'],
      ['modality'],
      ['created_at', 'createdAt'],
      ['updated_at', 'updatedAt'],
    ],
    'voice_notes': [
      ['id'],
      ['person_id', 'personId'],
      ['transcription'],
      ['created_at', 'createdAt'],
      ['updated_at', 'updatedAt'],
    ],
    'phone_contacts': [
      ['id'],
      ['name'],
      ['phone'],
      ['created_at', 'createdAt'],
      ['updated_at', 'updatedAt'],
    ],
    'territory_landmarks': [
      ['id'],
      ['name'],
      ['category'],
      ['created_at', 'createdAt'],
      ['updated_at', 'updatedAt'],
    ],
  };

  @override
  bool matches(dynamic item, Map matchState) {
    if (item is! Map) {
      matchState['reason'] =
          'O payload não é um Map (tipo: ${item.runtimeType})';
      return false;
    }

    final normalizedTable = _normalizeTableName(table);
    final columnsToCheck =
        requiredColumnOptions[normalizedTable] ??
        const [
          ['id'],
          ['created_at', 'createdAt'],
          ['updated_at', 'updatedAt'],
        ];

    for (final columnAliases in columnsToCheck) {
      bool found = false;
      for (final alias in columnAliases) {
        if (item.containsKey(alias) && item[alias] != null) {
          found = true;
          break;
        }
      }
      if (!found) {
        matchState['reason'] =
            'Coluna obrigatória ausente ou nula no payload de $table: ${columnAliases.join(" / ")}';
        return false;
      }
    }

    return true;
  }

  @override
  Description describe(Description description) => description.add(
    'payload totalmente hidratado com colunas obrigatórias NOT NULL para $table',
  );

  @override
  Description describeMismatch(
    dynamic item,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) {
    final reason = matchState['reason'] as String? ?? 'payload incompleto';
    return mismatchDescription.add(reason);
  }

  static String _normalizeTableName(String name) {
    final lower = name.toLowerCase();
    switch (lower) {
      case 'person':
      case 'people':
        return 'people';
      case 'visit':
      case 'visits':
        return 'visits';
      case 'biblestudies':
      case 'bible_studies':
        return 'bible_studies';
      case 'studyparticipants':
      case 'study_participants':
        return 'study_participants';
      case 'studysessions':
      case 'study_sessions':
        return 'study_sessions';
      case 'appointment':
      case 'appointments':
        return 'appointments';
      case 'activityrecord':
      case 'activityrecords':
      case 'activity_records':
        return 'activity_records';
      default:
        return lower;
    }
  }
}

// =============================================================================
// Funções Auxiliares Internas
// =============================================================================

({double lat, double lng})? _extractCoordinates(dynamic item) {
  if (item == null) return null;

  if (item is Map) {
    final lat =
        (item['latitude'] as num?)?.toDouble() ??
        (item['lat'] as num?)?.toDouble();
    final lng =
        (item['longitude'] as num?)?.toDouble() ??
        (item['lng'] as num?)?.toDouble();
    if (lat != null && lng != null) {
      return (lat: lat, lng: lng);
    }
  } else if (item is ({double latitude, double longitude})) {
    return (lat: item.latitude, lng: item.longitude);
  } else if (item is ({double lat, double lng})) {
    return (lat: item.lat, lng: item.lng);
  }

  return null;
}
