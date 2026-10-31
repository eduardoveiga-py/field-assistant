/// Modelo estruturado do resultado do processamento da nota de voz.
class ParsedVoiceNote {
  /// Número da lição detectada (ex.: 18 para "lição 18" ou "lição dezoito")
  final int? lesson;

  /// Número do ponto ou parágrafo detectado (ex.: 3 para "ponto 3" ou "ponto três")
  final int? point;

  /// Pendência / ação futura identificada na fala
  final String? pendingDoubt;

  /// Gatilho empático pessoal / contexto de vida identificado
  final String? empathyNote;

  /// Nome do estudante ou morador identificado na fala (se mencionado)
  final String? studentName;

  /// Transcrição original completa
  final String rawText;

  const ParsedVoiceNote({
    this.lesson,
    this.point,
    this.pendingDoubt,
    this.empathyNote,
    this.studentName,
    required this.rawText,
  });

  /// Indica se pelo menos uma entidade estruturada foi extraída com sucesso
  bool get hasAnyExtraction =>
      lesson != null ||
      point != null ||
      (pendingDoubt != null && pendingDoubt!.trim().isNotEmpty) ||
      (empathyNote != null && empathyNote!.trim().isNotEmpty) ||
      (studentName != null && studentName!.trim().isNotEmpty);

  /// Formatação legível do progresso do estudo (ex.: "Lição 18, Ponto 3")
  String? get formattedProgress {
    if (lesson != null && point != null) {
      final padLesson = lesson.toString().padLeft(2, '0');
      return 'Lição $padLesson, Ponto $point';
    } else if (lesson != null) {
      final padLesson = lesson.toString().padLeft(2, '0');
      return 'Lição $padLesson';
    } else if (point != null) {
      return 'Ponto $point';
    }
    return null;
  }

  ParsedVoiceNote copyWith({
    int? lesson,
    int? point,
    String? pendingDoubt,
    String? empathyNote,
    String? studentName,
    String? rawText,
  }) {
    return ParsedVoiceNote(
      lesson: lesson ?? this.lesson,
      point: point ?? this.point,
      pendingDoubt: pendingDoubt ?? this.pendingDoubt,
      empathyNote: empathyNote ?? this.empathyNote,
      studentName: studentName ?? this.studentName,
      rawText: rawText ?? this.rawText,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ParsedVoiceNote &&
          runtimeType == other.runtimeType &&
          lesson == other.lesson &&
          point == other.point &&
          pendingDoubt == other.pendingDoubt &&
          empathyNote == other.empathyNote &&
          studentName == other.studentName &&
          rawText == other.rawText;

  @override
  int get hashCode =>
      lesson.hashCode ^
      point.hashCode ^
      pendingDoubt.hashCode ^
      empathyNote.hashCode ^
      studentName.hashCode ^
      rawText.hashCode;

  @override
  String toString() =>
      'ParsedVoiceNote(lesson: $lesson, point: $point, pendingDoubt: $pendingDoubt, '
      'empathyNote: $empathyNote, studentName: $studentName, rawText: $rawText)';
}

/// Motor determinístico offline em puro Dart para extração teocrática de notas de voz.
class VoiceNoteParser {
  static const Map<String, int> _numberWords = {
    'zero': 0,
    'um': 1,
    'uma': 1,
    'primeiro': 1,
    'primeira': 1,
    'dois': 2,
    'duas': 2,
    'segundo': 2,
    'segunda': 2,
    'tres': 3,
    'três': 3,
    'terceiro': 3,
    'terceira': 3,
    'quatro': 4,
    'quarto': 4,
    'quarta': 4,
    'cinco': 5,
    'quinto': 5,
    'quinta': 5,
    'seis': 6,
    'meia': 6,
    'sexto': 6,
    'sexta': 6,
    'sete': 7,
    'setimo': 7,
    'sétimo': 7,
    'setima': 7,
    'sétima': 7,
    'oito': 8,
    'oitavo': 8,
    'oitava': 8,
    'nove': 9,
    'nono': 9,
    'nona': 9,
    'dez': 10,
    'decimo': 10,
    'décimo': 10,
    'decima': 10,
    'décima': 10,
    'onze': 11,
    'decimo primeiro': 11,
    'décimo primeiro': 11,
    'decima primeira': 11,
    'décima primeira': 11,
    'doze': 12,
    'decimo segundo': 12,
    'décimo segundo': 12,
    'decima segunda': 12,
    'décima segunda': 12,
    'treze': 13,
    'decimo terceiro': 13,
    'décimo terceiro': 13,
    'decima terceira': 13,
    'décima terceira': 13,
    'catorze': 14,
    'quatorze': 14,
    'decimo quarto': 14,
    'décimo quarto': 14,
    'decima quarta': 14,
    'décima quarta': 14,
    'quinze': 15,
    'decimo quinto': 15,
    'décimo quinto': 15,
    'decima quinta': 15,
    'décima quinta': 15,
    'dezesseis': 16,
    'dezeseis': 16,
    'decimo sexto': 16,
    'décimo sexto': 16,
    'decima sexta': 16,
    'décima sexta': 16,
    'dezessete': 17,
    'dezesete': 17,
    'decimo setimo': 17,
    'décimo sétimo': 17,
    'decima setima': 17,
    'décima sétima': 17,
    'dezoito': 18,
    'decimo oitavo': 18,
    'décimo oitavo': 18,
    'decima oitava': 18,
    'décima oitava': 18,
    'dezenove': 19,
    'decimo nono': 19,
    'décimo nono': 19,
    'decima nona': 19,
    'décima nona': 19,
    'vinte': 20,
    'vigesimo': 20,
    'vigésimo': 20,
    'vigesima': 20,
    'vigésima': 20,
    'trinta': 30,
    'trigesimo': 30,
    'trigésimo': 30,
    'trigesima': 30,
    'trigésima': 30,
    'quarenta': 40,
    'quadragesimo': 40,
    'quadragésimo': 40,
    'quadragesima': 40,
    'quadragésima': 40,
    'cinquenta': 50,
    'cincoenta': 50,
    'quinquagesimo': 50,
    'quinquagésimo': 50,
    'quinquagesima': 50,
    'quinquagésima': 50,
    'sessenta': 60,
    'sexagesimo': 60,
    'sexagésimo': 60,
    'sexagesima': 60,
    'sexagésima': 60,
    'setenta': 70,
    'septuagesimo': 70,
    'septuagésimo': 70,
    'setuagesimo': 70,
    'setuagésimo': 70,
    'oitenta': 80,
    'octogesimo': 80,
    'octogésimo': 80,
    'noventa': 90,
    'nonagesimo': 90,
    'nonagésimo': 90,
    'cem': 100,
    'cento': 100,
    'centesimo': 100,
    'centésimo': 100,
  };

  static const List<String> _pendingTriggers = [
    'ficou pendente',
    'ficou de',
    'ficamos de',
    'pendencia',
    'pendência',
    'pendente',
    'mostrar video',
    'mostrar vídeo',
    'mostrar o video',
    'mostrar o vídeo',
    'passar video',
    'passar vídeo',
    'assistir video',
    'assistir vídeo',
    'assistir ao video',
    'assistir ao vídeo',
    'ver video',
    'ver vídeo',
    'ver o video',
    'ver o vídeo',
    'ler texto',
    'ler o texto',
    'ler a biblia',
    'ler a bíblia',
    'levar brochura',
    'levar publicacao',
    'levar publicação',
    'levar livro',
    'levar revista',
    'levar folheto',
    'responder a pergunta',
    'responder à pergunta',
    'responder pergunta',
    'responder duvida',
    'responder dúvida',
    'responder a duvida',
    'responder a dúvida',
    'proxima visita',
    'próxima visita',
    'proxima vez',
    'próxima vez',
    'proximo passo',
    'próximo passo',
    'combinamos de',
    'combinamos que',
    'combinado de',
    'mandar link',
    'enviar link',
    'proximo tema',
    'próximo tema',
    'proximo assunto',
    'próximo assunto',
  ];

  static const List<String> _empathyTriggers = [
    'trabalho',
    'turno',
    'emprego',
    'desemprego',
    'desempregado',
    'desempregada',
    'empresa',
    'familia',
    'família',
    'filho',
    'filha',
    'filhos',
    'filhas',
    'mae',
    'mãe',
    'pai',
    'pais',
    'esposa',
    'esposo',
    'marido',
    'irmao',
    'irmão',
    'irma',
    'irmã',
    'avo',
    'avô',
    'avó',
    'neto',
    'neta',
    'casamento',
    'divorcio',
    'divórcio',
    'cirurgia',
    'saude',
    'saúde',
    'medico',
    'médico',
    'hospital',
    'internado',
    'internada',
    'recuperacao',
    'recuperação',
    'doente',
    'doenca',
    'doença',
    'remedio',
    'remédio',
    'falecimento',
    'luto',
    'faleceu',
    'morreu',
    'viagem',
    'viajar',
    'viajando',
    'mudanca',
    'mudança',
    'mudou de casa',
    'preocupado',
    'preocupada',
    'preocupacao',
    'preocupação',
    'ansioso',
    'ansiosa',
    'ansiedade',
    'depressao',
    'depressão',
    'desanimado',
    'desanimada',
    'oracao',
    'oração',
    'aposentadoria',
    'consulta',
    'exame',
    'tratamento',
  ];

  static const Set<String> _nameStopWords = {
    'paramos', 'ficou', 'ficamos', 'comentou', 'falou', 'disse', 'mencionou',
    'ontem', 'hoje', 'amanha', 'amanhã', 'casa', 'rua', 'bairro', 'parte',
    'manha', 'manhã', 'tarde', 'noite', 'semana', 'livro', 'revista', 'folheto',
    'brochura', 'licao', 'lição', 'ponto', 'capitulo', 'capítulo', 'biblia',
    'bíblia', 'texto', 'video', 'vídeo', 'estudo', 'visita', 'revisita',
    'que', 'para', 'com', 'sem', 'foi', 'estava', 'sobre', 'na', 'no', 'da', 'do',
    'segunda', 'terça', 'terca', 'quarta', 'quinta', 'sexta', 'sabado', 'sábado', 'domingo',
  };

  /// Analisa um texto ditado ou transcrito e retorna a estrutura extraída determinística.
  static ParsedVoiceNote parse(String? rawText) {
    if (rawText == null || rawText.trim().isEmpty) {
      return const ParsedVoiceNote(rawText: '');
    }

    final text = rawText.trim();
    final studentName = _extractStudentName(text);
    final lesson = _extractLesson(text);
    final point = _extractPoint(text);
    final pendingDoubt = _extractPendingDoubt(text);
    final empathyNote = _extractEmpathyNote(text, pendingDoubt);

    return ParsedVoiceNote(
      lesson: lesson,
      point: point,
      pendingDoubt: pendingDoubt,
      empathyNote: empathyNote,
      studentName: studentName,
      rawText: text,
    );
  }

  /// Converte uma representação textual de número em inteiro (ex: "18", "dezoito", "vinte e um", "vigésimo primeiro").
  static int? parsePortugueseNumber(String raw) {
    var clean = raw.trim().toLowerCase();
    if (clean.isEmpty) return null;

    // Remove marcadores ordinais residuais (ex.: 18º, 3ª, 4°)
    clean = clean.replaceAll(RegExp(r'[ºª°\.]'), '').trim();

    final directDigits = int.tryParse(clean);
    if (directDigits != null) return directDigits;

    if (_numberWords.containsKey(clean)) {
      return _numberWords[clean];
    }

    // Dezenas compostas cardinais: "vinte e três", "trinta e cinco", "setenta e dois", etc.
    final compoundReg = RegExp(
      r'^(vinte|trinta|quarenta|cinquenta|cincoenta|sessenta|setenta|oitenta|noventa)\s+e\s+([a-zà-ú]+)$',
    );
    final match = compoundReg.firstMatch(clean);
    if (match != null) {
      final tensStr = match.group(1)!;
      final unitsStr = match.group(2)!;
      final tensVal = _numberWords[tensStr];
      final unitsVal = _numberWords[unitsStr];
      if (tensVal != null && unitsVal != null) {
        return tensVal + unitsVal;
      }
    }

    // Dezenas compostas ordinais: "vigésimo primeiro", "trigésima segunda", etc.
    final ordinalCompoundReg = RegExp(
      r'^(vig[ée]sim[oa]|trig[ée]sim[oa]|quadrag[ée]sim[oa]|quinquag[ée]sim[oa]|sexag[ée]sim[oa])\s+([a-zà-ú]+)$',
    );
    final ordMatch = ordinalCompoundReg.firstMatch(clean);
    if (ordMatch != null) {
      final tensStr = ordMatch.group(1)!;
      final unitsStr = ordMatch.group(2)!;
      final tensVal = _numberWords[tensStr];
      final unitsVal = _numberWords[unitsStr];
      if (tensVal != null && unitsVal != null) {
        return tensVal + unitsVal;
      }
    }

    return null;
  }

  static String? _cleanExtractedName(String? raw) {
    if (raw == null) return null;
    final words = raw.trim().split(RegExp(r'\s+'));
    if (words.isEmpty) return null;

    // Se a primeira palavra for stopword, descarta
    if (_nameStopWords.contains(words.first.toLowerCase())) {
      return null;
    }

    // Se a segunda palavra for stopword (ex: "Marcos paramos"), preserva apenas o primeiro nome
    if (words.length > 1 && _nameStopWords.contains(words[1].toLowerCase())) {
      return _capitalizeWords(words.first);
    }

    final cleanedWords = words.take(2).join(' ');
    return _capitalizeWords(cleanedWords);
  }

  static String? _extractStudentName(String text) {
    // 1. Procura "com o/a [Nome]" ou "com [Nome]"
    final comPattern = RegExp(
      r'(?:estudo|visita|conversa|revisita)?\s*\bcom\s+(?:o\s+|a\s+|o\s+irm[aã]o\s+|a\s+irm[aã]\s+|dona\s+|seu\s+)?([A-ZÀ-Úa-zà-ú]+(?:\s+[A-ZÀ-Úa-zà-ú]+)?)',
      caseSensitive: false,
    );
    final matchCom = comPattern.firstMatch(text);
    if (matchCom != null) {
      final name = _cleanExtractedName(matchCom.group(1));
      if (name != null) return name;
    }

    // 2. Procura "na casa do/da [Nome]"
    final casaPattern = RegExp(
      r'na\s+casa\s+d[oa]\s+(?:dona\s+|seu\s+)?([A-ZÀ-Úa-zà-ú]+(?:\s+[A-ZÀ-Úa-zà-ú]+)?)',
      caseSensitive: false,
    );
    final matchCasa = casaPattern.firstMatch(text);
    if (matchCasa != null) {
      final name = _cleanExtractedName(matchCasa.group(1));
      if (name != null) return name;
    }

    // 3. Procura "visita na dona [Nome]" ou "visita no seu [Nome]"
    final titlePattern = RegExp(
      r'(?:estudo|visita)\s+n[oa]\s+(?:dona|seu|irm[aã]|irm[aã]o)\s+([A-ZÀ-Úa-zà-ú]+(?:\s+[A-ZÀ-Úa-zà-ú]+)?)',
      caseSensitive: false,
    );
    final matchTitle = titlePattern.firstMatch(text);
    if (matchTitle != null) {
      final name = _cleanExtractedName(matchTitle.group(1));
      if (name != null) return name;
    }

    return null;
  }

  static int? _extractLesson(String text) {
    // 1. Ordem direta: "lição 18", "capítulo 7", "lição dezoito"
    final primaryDigitsPattern = RegExp(
      r'(?:li[cç][aã]o|cap[ií]tulo)\s*(?:n[º°.]\s*|n[uú]mero\s*)?(\d{1,3})',
      caseSensitive: false,
    );
    for (final m in primaryDigitsPattern.allMatches(text)) {
      final val = int.tryParse(m.group(1)!);
      if (val != null) return val;
    }

    final primaryWordPattern = RegExp(
      r'(?:li[cç][aã]o|cap[ií]tulo)\s*(?:n[º°.]\s*|n[uú]mero\s*)?([a-zà-ú]+(?:\s+e\s+[a-zà-ú]+|\s+[a-zà-ú]+)?)',
      caseSensitive: false,
    );
    for (final m in primaryWordPattern.allMatches(text)) {
      final word = m.group(1);
      if (word != null) {
        final parsed = parsePortugueseNumber(word);
        if (parsed != null) return parsed;
      }
    }

    // 2. Ordem inversa: "18ª lição", "18a lição", "dezoita lição", "décima oitava lição"
    final reverseDigitsPattern = RegExp(
      r'(\d{1,3})\s*(?:[ºª°a-z\.]*\s+)?(?:li[cç][aã]o|cap[ií]tulo)',
      caseSensitive: false,
    );
    for (final m in reverseDigitsPattern.allMatches(text)) {
      final val = int.tryParse(m.group(1)!);
      if (val != null) return val;
    }

    final reverseWordPattern = RegExp(
      r'([a-zà-ú]+(?:\s+e\s+[a-zà-ú]+|\s+[a-zà-ú]+)?)\s+(?:li[cç][aã]o|cap[ií]tulo)',
      caseSensitive: false,
    );
    for (final m in reverseWordPattern.allMatches(text)) {
      final word = m.group(1);
      if (word != null) {
        final parsed = parsePortugueseNumber(word);
        if (parsed != null) return parsed;
      }
    }

    // 3. Fallback para "estudo"
    final secondaryDigitsPattern = RegExp(
      r'\bestudo\b\s*(?:n[º°.]\s*|n[uú]mero\s*)?(\d{1,3})',
      caseSensitive: false,
    );
    for (final m in secondaryDigitsPattern.allMatches(text)) {
      final val = int.tryParse(m.group(1)!);
      if (val != null) return val;
    }

    final secondaryWordPattern = RegExp(
      r'\bestudo\b\s*(?:n[º°.]\s*|n[uú]mero\s*)?([a-zà-ú]+(?:\s+e\s+[a-zà-ú]+|\s+[a-zà-ú]+)?)',
      caseSensitive: false,
    );
    for (final m in secondaryWordPattern.allMatches(text)) {
      final word = m.group(1);
      if (word != null) {
        final parsed = parsePortugueseNumber(word);
        if (parsed != null) return parsed;
      }
    }

    return null;
  }

  static int? _extractPoint(String text) {
    // 1. Ordem direta: "ponto 3", "parágrafo 4", "ponto terceiro"
    final digitsPattern = RegExp(
      r'(?:ponto|par[aá]grafo|se[cç][aã]o)\s*(?:n[º°.]\s*|n[uú]mero\s*)?(\d{1,3})',
      caseSensitive: false,
    );
    for (final m in digitsPattern.allMatches(text)) {
      final val = int.tryParse(m.group(1)!);
      if (val != null) return val;
    }

    final wordPattern = RegExp(
      r'(?:ponto|par[aá]grafo|se[cç][aã]o)\s*(?:n[º°.]\s*|n[uú]mero\s*)?([a-zà-ú]+(?:\s+e\s+[a-zà-ú]+|\s+[a-zà-ú]+)?)',
      caseSensitive: false,
    );
    for (final m in wordPattern.allMatches(text)) {
      final word = m.group(1);
      if (word != null) {
        final parsed = parsePortugueseNumber(word);
        if (parsed != null) return parsed;
      }
    }

    // 2. Ordem inversa: "3º ponto", "4º parágrafo", "terceiro ponto"
    final reverseDigitsPattern = RegExp(
      r'(\d{1,3})\s*(?:[ºª°a-z\.]*\s+)?(?:ponto|par[aá]grafo|se[cç][aã]o)',
      caseSensitive: false,
    );
    for (final m in reverseDigitsPattern.allMatches(text)) {
      final val = int.tryParse(m.group(1)!);
      if (val != null) return val;
    }

    final reverseWordPattern = RegExp(
      r'([a-zà-ú]+(?:\s+e\s+[a-zà-ú]+|\s+[a-zà-ú]+)?)\s+(?:ponto|par[aá]grafo|se[cç][aã]o)',
      caseSensitive: false,
    );
    for (final m in reverseWordPattern.allMatches(text)) {
      final word = m.group(1);
      if (word != null) {
        final parsed = parsePortugueseNumber(word);
        if (parsed != null) return parsed;
      }
    }

    return null;
  }

  static String? _extractPendingDoubt(String text) {
    final clauses = _segmentClauses(text);

    for (final clause in clauses) {
      final lower = clause.toLowerCase();
      for (final trigger in _pendingTriggers) {
        if (lower.contains(trigger)) {
          // Se a oração contém gatilho de transição empática à frente, trunca antes dele
          final truncated = _truncateAtEmpathyTransition(clause);
          return _cleanSentence(truncated);
        }
      }
    }

    // Fallback: busca substring a partir de gatilho
    final lowerText = text.toLowerCase();
    for (final trigger in _pendingTriggers) {
      final idx = lowerText.indexOf(trigger);
      if (idx != -1) {
        final sub = text.substring(idx);
        final endIdx = sub.indexOf(RegExp(r'[,.;\n]'));
        final candidate = endIdx != -1 ? sub.substring(0, endIdx) : sub;
        final truncated = _truncateAtEmpathyTransition(candidate);
        return _cleanSentence(truncated);
      }
    }

    return null;
  }

  static String? _extractEmpathyNote(String text, String? alreadyUsedPending) {
    final clauses = _segmentClauses(text);
    final cleanPending = alreadyUsedPending?.toLowerCase().trim();

    for (final clause in clauses) {
      final cleanClause = clause.trim();
      if (cleanPending != null && cleanPending.contains(cleanClause.toLowerCase())) {
        continue;
      }

      final lower = cleanClause.toLowerCase();
      for (final trigger in _empathyTriggers) {
        if (_containsWord(lower, trigger)) {
          return _cleanSentence(cleanClause);
        }
      }
    }

    return null;
  }

  /// Segmenta o texto em orações considerando pontuação forte, vírgulas e conectivos
  /// de transição de pensamento típicos de ditado móvel sem pontuação.
  static List<String> _segmentClauses(String text) {
    // 1. Divide inicialmente por pontuação forte ou vírgulas
    final rawParts = text.split(RegExp(r'[\.\!\?\;\,\n]+'));
    final result = <String>[];

    final transitionPattern = RegExp(
      r'(?:\b(?:e|mas)\s+)?(?:ele|ela)\s+(?:comentou|falou|disse|mencionou|contou|pediu|est[aá]|vai|foi|teve|mudou|perdeu)\b|(?:\b(?:e|mas)\s+)?(?:ficou|ficamos|combinamos)\s+(?:de|pendente)\b',
      caseSensitive: false,
    );

    for (final part in rawParts) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;

      // Se o bloco contém transições internas de oração sem pontuação, segmenta nos limites
      final matches = transitionPattern.allMatches(trimmed).toList();
      if (matches.length > 1 || (matches.isNotEmpty && matches.first.start > 15)) {
        int lastIdx = 0;
        for (final m in matches) {
          if (m.start > lastIdx) {
            final sub = trimmed.substring(lastIdx, m.start).trim();
            if (sub.isNotEmpty) result.add(sub);
          }
          lastIdx = m.start;
        }
        if (lastIdx < trimmed.length) {
          final tail = trimmed.substring(lastIdx).trim();
          if (tail.isNotEmpty) result.add(tail);
        }
      } else {
        result.add(trimmed);
      }
    }

    return result;
  }

  static String _truncateAtEmpathyTransition(String text) {
    final pattern = RegExp(
      r'\s+(?:(?:\be|mas)\s+)?(?:ele|ela)\s+(?:comentou|falou|disse|mencionou|contou|pediu|est[aá]|vai|foi|teve|mudou|perdeu)\b',
      caseSensitive: false,
    );
    final match = pattern.firstMatch(text);
    if (match != null && match.start > 0) {
      return text.substring(0, match.start).trim();
    }
    return text;
  }

  static bool _containsWord(String text, String word) {
    final pattern = RegExp(r'\b' + RegExp.escape(word) + r'\b', caseSensitive: false);
    return pattern.hasMatch(text);
  }

  static String _cleanSentence(String s) {
    var result = s.trim();
    result = result.replaceAll(RegExp(r'^[\s\.,;:—\-]+|[\s\.,;:—\-]+$'), '');
    if (result.isNotEmpty) {
      result = result[0].toUpperCase() + result.substring(1);
    }
    return result;
  }

  static String _capitalizeWords(String str) {
    return str.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }
}
