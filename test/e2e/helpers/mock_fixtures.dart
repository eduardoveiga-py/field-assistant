import 'dart:convert';
import 'dart:typed_data';

/// Conjunto canônico de dados de teste (fixtures) reutilizáveis para a suíte E2E.
///
/// Fornece:
/// - Coordenadas geográficas reais (Santo Antônio do Içá vs São Paulo).
/// - Bytes de tiles offline (PNGs válidos, 1x1 PNG, assinaturas de marca d'água Carto/OSM).
/// - Bytes de áudio reais codificados (RIFF/WAVE PCM) vs simulações fictícias zeradas.
/// - Respostas brutas dos protocolos IMAP e SMTP (sucesso e falha autêntica).
/// - Payloads de sincronização Supabase totalmente hidratados e respostas RPC `sync_upsert`.
class MockFixtures {
  // ===========================================================================
  // 1. Coordenadas Geográficas
  // ===========================================================================

  /// Latitude canônica de Santo Antônio do Içá, AM (centro do território de cobertura).
  static const double santoAntonioDoIcaLat = -3.1022;

  /// Longitude canônica de Santo Antônio do Içá, AM.
  static const double santoAntonioDoIcaLng = -67.9397;

  /// Latitude do centro de São Paulo (legado a ser rejeitado).
  static const double saoPauloLat = -23.550520;

  /// Longitude do centro de São Paulo (legado a ser rejeitado).
  static const double saoPauloLng = -46.633308;

  /// Retorna o mapa de coordenadas para Santo Antônio do Içá.
  static Map<String, double> santoAntonioCoordinates() => {
    'latitude': santoAntonioDoIcaLat,
    'longitude': santoAntonioDoIcaLng,
  };

  /// Retorna o mapa de coordenadas para São Paulo.
  static Map<String, double> saoPauloCoordinates() => {
    'latitude': saoPauloLat,
    'longitude': saoPauloLng,
  };

  // ===========================================================================
  // 2. Offline Tile Bytes & Watermark Signatures
  // ===========================================================================

  /// Imagem PNG 1x1 transparente genuína com cabeçalho PNG, chunks IHDR, IDAT e IEND.
  static final Uint8List onePixelPngBytes = Uint8List.fromList(<int>[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
    0x00, 0x00, 0x00, 0x0D, // IHDR chunk length (13 bytes)
    0x49, 0x48, 0x44, 0x52, // "IHDR"
    0x00, 0x00, 0x00, 0x01, // width = 1
    0x00, 0x00, 0x00, 0x01, // height = 1
    0x08, 0x06, 0x00, 0x00, 0x00, // 8-bit RGBA
    0x1F, 0x15, 0xC4, 0x89, // IHDR CRC
    0x00, 0x00, 0x00, 0x0A, // IDAT chunk length (10 bytes)
    0x49, 0x44, 0x41, 0x54, // "IDAT"
    0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01,
    0x0D, 0x0A, 0x2D, 0xB4, // IDAT CRC
    0x00, 0x00, 0x00, 0x00, // IEND chunk length (0 bytes)
    0x49, 0x45, 0x4E, 0x44, // "IEND"
    0xAE, 0x42, 0x60, 0x82, // IEND CRC
  ]);

  /// Gera um buffer de tile PNG válido com cabeçalho padrão PNG e tamanho configurável.
  static Uint8List validPngTile({int size = 1024}) {
    if (size <= onePixelPngBytes.length) return onePixelPngBytes;
    final bytes = Uint8List(size);
    bytes.setRange(
      0,
      8,
      const <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
    );
    for (int i = 8; i < size; i++) {
      bytes[i] = (i * 37) % 256;
    }
    return bytes;
  }

  /// Tamanho exato da marca d'água Carto Light (2049 bytes).
  static Uint8List cartoLightWatermark() => Uint8List(2049);

  /// Tamanho exato da marca d'água Carto Dark (2513 bytes).
  static Uint8List cartoDarkWatermark() => Uint8List(2513);

  /// Tamanho exato do tile de bloqueio de política OSM (6725 bytes).
  static Uint8List osmBlockedTile() => Uint8List(6725);

  /// Texto exato retornado quando a política OSM bloqueia a requisição HTTP.
  static Uint8List osmHtmlBlock() => Uint8List.fromList(
    utf8.encode('Access blocked due to tile usage policy osm.wiki/Blocked'),
  );

  /// Tile vazio (0 bytes).
  static Uint8List emptyTile() => Uint8List(0);

  /// Cabeçalho sintético de banco de dados SQLite 3 (para arquivos .mbtiles).
  static Uint8List minimalMbtilesDatabaseBytes() {
    final header = utf8.encode('SQLite format 3\x00');
    final bytes = Uint8List(512);
    bytes.setRange(0, header.length, header);
    return bytes;
  }

  // ===========================================================================
  // 3. Audio Bytes (Válido Codificado vs Simulação Fictícia Zerada)
  // ===========================================================================

  /// Gera um arquivo de áudio RIFF/WAVE válido com cabeçalho PCM de 44 bytes
  /// e forma de onda real (não preenchido exclusivamente por zeros).
  static Uint8List validWavAudioBytes({
    int durationSeconds = 1,
    int sampleRate = 8000,
  }) {
    final int numSamples = sampleRate * durationSeconds;
    final int dataSize = numSamples * 2; // 16-bit mono = 2 bytes/sample
    final int fileSize = 36 + dataSize;

    final bytes = ByteData(44 + dataSize);
    // "RIFF"
    bytes.setUint8(0, 0x52);
    bytes.setUint8(1, 0x49);
    bytes.setUint8(2, 0x46);
    bytes.setUint8(3, 0x46);
    bytes.setUint32(4, fileSize, Endian.little);
    // "WAVE"
    bytes.setUint8(8, 0x57);
    bytes.setUint8(9, 0x41);
    bytes.setUint8(10, 0x56);
    bytes.setUint8(11, 0x45);
    // "fmt "
    bytes.setUint8(12, 0x66);
    bytes.setUint8(13, 0x6D);
    bytes.setUint8(14, 0x74);
    bytes.setUint8(15, 0x20);
    bytes.setUint32(16, 16, Endian.little); // Chunk size
    bytes.setUint16(20, 1, Endian.little); // PCM
    bytes.setUint16(22, 1, Endian.little); // Mono
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(28, sampleRate * 2, Endian.little); // Byte rate
    bytes.setUint16(32, 2, Endian.little); // Block align
    bytes.setUint16(34, 16, Endian.little); // Bits per sample
    // "data"
    bytes.setUint8(36, 0x64);
    bytes.setUint8(37, 0x61);
    bytes.setUint8(38, 0x74);
    bytes.setUint8(39, 0x61);
    bytes.setUint32(40, dataSize, Endian.little);

    // Forma de onda real (onda pseudo-senoidal com amplitude audível)
    for (int i = 0; i < numSamples; i++) {
      final sample = (16384 * ((i % 40 < 20) ? 1 : -1)).round();
      bytes.setInt16(44 + (i * 2), sample, Endian.little);
    }
    return bytes.buffer.asUint8List();
  }

  /// Áudio com comprimento zero (0 bytes).
  static Uint8List dummyZeroLengthAudio() => Uint8List(0);

  /// Áudio falso de 64 bytes de zeros (simulação legada de `TicunaAudioService`).
  static Uint8List dummy64ZeroAudio() => Uint8List(64);

  /// Áudio preenchido exclusivamente com zeros de tamanho arbitrário.
  static Uint8List dummyZerosAudio({int size = 128}) => Uint8List(size);

  // ===========================================================================
  // 4. Respostas dos Protocolos IMAP & SMTP (RFC 3501 & RFC 5321)
  // ===========================================================================

  static const String imapGreeting = '* OK IMAP4rev1 Service Ready\r\n';
  static const String imapCapability =
      '* CAPABILITY IMAP4rev1 AUTH=PLAIN IDLE\r\nA001 OK CAPABILITY completed\r\n';
  static const String imapAuthOk =
      'A002 OK [CAPABILITY IMAP4rev1] Logged in\r\n';
  static const String imapAuthFailed =
      'A002 NO [AUTHENTICATIONFAILED] Authentication failed\r\n';
  static const String imapEmptyInbox =
      '* 0 EXISTS\r\n* 0 RECENT\r\nA003 OK [READ-WRITE] SELECT completed\r\n';

  /// Retorna uma resposta RFC 3501 FETCH realista para uma única mensagem de e-mail.
  static String imapFetchSingleEmail({
    required int uid,
    required String subject,
    required String from,
    required String body,
    String date = 'Mon, 10 Nov 2026 12:00:00 -0400',
  }) {
    final bodyBytes = utf8.encode(body);
    return '* 1 FETCH (UID $uid RFC822.SIZE ${bodyBytes.length + 120} BODY[HEADER.FIELDS (Subject From Date)] {80}\r\n'
        'Subject: $subject\r\n'
        'From: $from\r\n'
        'Date: $date\r\n\r\n'
        'BODY[TEXT] {${bodyBytes.length}}\r\n'
        '$body)\r\nA004 OK FETCH completed\r\n';
  }

  static const String smtpGreeting = '220 mail.example.org ESMTP Postfix\r\n';
  static const String smtpEhloOk =
      '250-mail.example.org\r\n250-PIPELINING\r\n250-AUTH PLAIN LOGIN\r\n250 8BITMIME\r\n';
  static const String smtpAuthOk = '235 2.7.0 Authentication successful\r\n';
  static const String smtpAuthFailed =
      '535 5.7.8 Error: authentication failed\r\n';
  static const String smtpMailOk = '250 2.1.0 Ok\r\n';
  static const String smtpRcptOk = '250 2.1.5 Ok\r\n';
  static const String smtpDataReady =
      '354 End data with <CR><LF>.<CR><LF>\r\n';
  static const String smtpDataSuccess = '250 2.0.0 Ok: queued as 4X8Z9\r\n';

  // ===========================================================================
  // 5. Payloads de Sincronização Supabase Totalmente Hidratados
  // ===========================================================================

  /// Payload completamente hidratado para a tabela `people`.
  static Map<String, dynamic> samplePersonPayload({
    String id = 'person_e2e_1',
    String name = 'Publicador Real Santo Antônio',
    double latitude = santoAntonioDoIcaLat,
    double longitude = santoAntonioDoIcaLng,
    String status = 'interessado',
    int revision = 1,
  }) => {
    'id': id,
    'name': name,
    'phone': '+5597984001122',
    'address': 'Rua do Porto, Centro',
    'latitude': latitude,
    'longitude': longitude,
    'first_contact_at': '2026-11-10T10:00:00.000Z',
    'status': status,
    'preferred_schedule': 'Tardes de sábado',
    'general_notes': 'Contato real ribeirinho',
    'contact_restrictions': null,
    'tags': '[]',
    'created_at': '2026-11-10T10:00:00.000Z',
    'updated_at': '2026-11-10T10:00:00.000Z',
    'deleted_at': null,
    'revision': revision,
  };

  /// Payload completamente hidratado para a tabela `visits`.
  static Map<String, dynamic> sampleVisitPayload({
    String id = 'visit_e2e_1',
    String personId = 'person_e2e_1',
    String contactType = 'revisita',
    String result = 'conversa_produtiva',
    int revision = 1,
  }) => {
    'id': id,
    'person_id': personId,
    'date_time_field': '2026-11-10T11:00:00.000Z',
    'contact_type': contactType,
    'result': result,
    'notes': 'Considerada a lição 01 da brochura',
    'topics_discussed': 'Esperança para o futuro',
    'scripture_or_pub': 'Salmo 37:11',
    'expressed_question': 'Como Deus vai acabar com o sofrimento?',
    'next_step': 'Voltar na próxima terça',
    'created_at': '2026-11-10T11:00:00.000Z',
    'updated_at': '2026-11-10T11:00:00.000Z',
    'deleted_at': null,
    'revision': revision,
  };

  /// Payload completamente hidratado para a tabela `bible_studies`.
  static Map<String, dynamic> sampleBibleStudyPayload({
    String id = 'study_e2e_1',
    String title = 'Estudo Bíblico Família Silva',
    String status = 'ativo',
    int revision = 1,
  }) => {
    'id': id,
    'title': title,
    'owner_id': 'local_user',
    'started_at': '2026-11-10T10:00:00.000Z',
    'status': status,
    'publication_id': 'lff-book',
    'current_lesson': 1,
    'current_paragraph': 1,
    'created_at': '2026-11-10T10:00:00.000Z',
    'updated_at': '2026-11-10T10:00:00.000Z',
    'deleted_at': null,
    'revision': revision,
  };

  /// Payload completamente hidratado para a tabela `study_participants`.
  static Map<String, dynamic> sampleStudyParticipantPayload({
    String id = 'participant_e2e_1',
    String studyId = 'study_e2e_1',
    String personId = 'person_e2e_1',
  }) => {
    'id': id,
    'study_id': studyId,
    'person_id': personId,
    'is_primary': true,
    'created_at': '2026-11-10T10:00:00.000Z',
    'updated_at': '2026-11-10T10:00:00.000Z',
    'deleted_at': null,
    'revision': 1,
  };

  /// Payload completamente hidratado para a tabela `study_sessions`.
  static Map<String, dynamic> sampleStudySessionPayload({
    String id = 'session_e2e_1',
    String studyId = 'study_e2e_1',
  }) => {
    'id': id,
    'study_id': studyId,
    'date_time_field': '2026-11-10T10:00:00.000Z',
    'publication_code': 'lff',
    'lesson_covered': 1,
    'paragraphs_covered': '1-5',
    'session_notes': 'Sessão inaugural do estudo',
    'status': 'realizada',
    'participant_ids': <String>[],
    'created_at': '2026-11-10T10:00:00.000Z',
    'updated_at': '2026-11-10T10:00:00.000Z',
    'deleted_at': null,
    'revision': 1,
  };

  /// Payload completamente hidratado para a tabela `appointments`.
  static Map<String, dynamic> sampleAppointmentPayload({
    String id = 'appointment_e2e_1',
    String title = 'Revisita Sr. Raimundo',
    String status = 'planejado',
  }) => {
    'id': id,
    'title': title,
    'start_time': '2026-11-12T14:00:00.000Z',
    'end_time': '2026-11-12T14:30:00.000Z',
    'duration_minutes': 30,
    'status': status,
    'reminder_minutes_before': 30,
    'location_notes': 'Levar exemplar impresso',
    'is_provisional': false,
    'created_at': '2026-11-10T10:00:00.000Z',
    'updated_at': '2026-11-10T10:00:00.000Z',
    'deleted_at': null,
    'revision': 1,
  };

  /// Payload completamente hidratado para a tabela `activity_records`.
  static Map<String, dynamic> sampleActivityRecordPayload({
    String id = 'activity_e2e_1',
  }) => {
    'id': id,
    'date': '2026-11-10T00:00:00.000Z',
    'duration_seconds': 9000,
    'modality': 'campo',
    'notes': 'Trabalho de campo no setor ribeirinho',
    'created_at': '2026-11-10T10:00:00.000Z',
    'updated_at': '2026-11-10T10:00:00.000Z',
    'deleted_at': null,
    'revision': 1,
  };

  /// Retorna o payload padrão hidratado correspondente à tabela solicitada.
  static Map<String, dynamic> samplePayloadForTable(String table) {
    switch (table.toLowerCase()) {
      case 'people':
        return samplePersonPayload();
      case 'visits':
        return sampleVisitPayload();
      case 'bible_studies':
      case 'biblestudies':
        return sampleBibleStudyPayload();
      case 'study_participants':
      case 'studyparticipants':
        return sampleStudyParticipantPayload();
      case 'study_sessions':
      case 'studysessions':
        return sampleStudySessionPayload();
      case 'appointments':
        return sampleAppointmentPayload();
      case 'activity_records':
      case 'activityrecords':
        return sampleActivityRecordPayload();
      case 'voice_notes':
      case 'voicenotes':
        return {
          'id': 'vn_e2e_1',
          'person_id': 'person_e2e_1',
          'transcription': 'Revisita cordial combinando retorno na sexta-feira',
          'audio_duration_seconds': 12,
          'created_at': '2026-11-10T10:00:00.000Z',
          'updated_at': '2026-11-10T10:00:00.000Z',
          'deleted_at': null,
          'revision': 1,
        };
      case 'phone_contacts':
      case 'phonecontacts':
        return {
          'id': 'pc_e2e_1',
          'name': 'Contato Telefônico Real',
          'phone': '+5597991112233',
          'origin': 'Informal',
          'tags': <String>[],
          'created_at': '2026-11-10T10:00:00.000Z',
          'updated_at': '2026-11-10T10:00:00.000Z',
          'deleted_at': null,
          'revision': 1,
        };
      case 'territory_landmarks':
      case 'territorylandmarks':
        return {
          'id': 'tl_e2e_1',
          'name': 'Ponto de Apoio Comunitário',
          'category': 'referencia',
          'latitude': santoAntonioDoIcaLat,
          'longitude': santoAntonioDoIcaLng,
          'created_at': '2026-11-10T10:00:00.000Z',
          'updated_at': '2026-11-10T10:00:00.000Z',
          'deleted_at': null,
          'revision': 1,
        };
      default:
        return {
          'id': 'generic_e2e_1',
          'created_at': '2026-11-10T10:00:00.000Z',
          'updated_at': '2026-11-10T10:00:00.000Z',
          'deleted_at': null,
          'revision': 1,
        };
    }
  }

  // ===========================================================================
  // 6. Respostas da RPC `sync_upsert`
  // ===========================================================================

  /// Resposta de sucesso na execução da RPC `sync_upsert`.
  static Map<String, dynamic> rpcSyncUpsertSuccess({
    int count = 1,
    List<dynamic> errors = const [],
  }) => {
    'success': true,
    'processed_count': count,
    'errors': errors,
  };

  /// Resposta simulada de conflito otimista de revisão na RPC `sync_upsert`.
  static Map<String, dynamic> rpcSyncUpsertConflict({
    required String entity,
    required String id,
    int expectedRevision = 1,
    int currentRevision = 2,
  }) => {
    'code': '23505',
    'message':
        'Optimistic lock conflict on $entity ($id): client expected rev $expectedRevision, server has rev $currentRevision',
    'details': {
      'entity': entity,
      'id': id,
      'expected_revision': expectedRevision,
      'current_revision': currentRevision,
    },
  };

  /// Resposta de erro genérico na execução da RPC.
  static Map<String, dynamic> rpcSyncUpsertError({
    required String message,
    String code = '400',
  }) => {'code': code, 'message': message};
}
