/// Metadados canônicos dos 66 livros da Bíblia (Tradução do Novo Mundo).
class NwtBibleBookInfo {
  final int number;
  final String namePt;
  final String nameEn;
  final String code;
  final int chapterCount;
  final List<String> aliases;

  const NwtBibleBookInfo({
    required this.number,
    required this.namePt,
    required this.nameEn,
    required this.code,
    required this.chapterCount,
    this.aliases = const [],
  });
}

/// Catálogo oficial dos 66 livros canônicos e utilitários de formatação.
class NwtBibleBooks {
  NwtBibleBooks._();

  static const List<NwtBibleBookInfo> all = [
    NwtBibleBookInfo(
      number: 1,
      namePt: 'Gênesis',
      nameEn: 'Genesis',
      code: 'GEN',
      chapterCount: 50,
      aliases: ['gen', 'gn', 'ge'],
    ),
    NwtBibleBookInfo(
      number: 2,
      namePt: 'Êxodo',
      nameEn: 'Exodus',
      code: 'EXO',
      chapterCount: 40,
      aliases: ['ex', 'exo', 'exod'],
    ),
    NwtBibleBookInfo(
      number: 3,
      namePt: 'Levítico',
      nameEn: 'Leviticus',
      code: 'LEV',
      chapterCount: 27,
      aliases: ['lv', 'lev'],
    ),
    NwtBibleBookInfo(
      number: 4,
      namePt: 'Números',
      nameEn: 'Numbers',
      code: 'NUM',
      chapterCount: 36,
      aliases: ['nm', 'num'],
    ),
    NwtBibleBookInfo(
      number: 5,
      namePt: 'Deuteronômio',
      nameEn: 'Deuteronomy',
      code: 'DEU',
      chapterCount: 34,
      aliases: ['dt', 'deu', 'deut'],
    ),
    NwtBibleBookInfo(
      number: 6,
      namePt: 'Josué',
      nameEn: 'Joshua',
      code: 'JOS',
      chapterCount: 24,
      aliases: ['js', 'jos', 'josh'],
    ),
    NwtBibleBookInfo(
      number: 7,
      namePt: 'Juízes',
      nameEn: 'Judges',
      code: 'JDG',
      chapterCount: 21,
      aliases: ['jz', 'jdg', 'judg'],
    ),
    NwtBibleBookInfo(
      number: 8,
      namePt: 'Rute',
      nameEn: 'Ruth',
      code: 'RUT',
      chapterCount: 4,
      aliases: ['rt', 'rut', 'ruth'],
    ),
    NwtBibleBookInfo(
      number: 9,
      namePt: '1 Samuel',
      nameEn: '1 Samuel',
      code: '1SA',
      chapterCount: 31,
      aliases: ['1sm', '1sa', '1sam'],
    ),
    NwtBibleBookInfo(
      number: 10,
      namePt: '2 Samuel',
      nameEn: '2 Samuel',
      code: '2SA',
      chapterCount: 24,
      aliases: ['2sm', '2sa', '2sam'],
    ),
    NwtBibleBookInfo(
      number: 11,
      namePt: '1 Reis',
      nameEn: '1 Kings',
      code: '1KI',
      chapterCount: 22,
      aliases: ['1rs', '1ki', '1kgs'],
    ),
    NwtBibleBookInfo(
      number: 12,
      namePt: '2 Reis',
      nameEn: '2 Kings',
      code: '2KI',
      chapterCount: 25,
      aliases: ['2rs', '2ki', '2kgs'],
    ),
    NwtBibleBookInfo(
      number: 13,
      namePt: '1 Crônicas',
      nameEn: '1 Chronicles',
      code: '1CH',
      chapterCount: 29,
      aliases: ['1cr', '1ch', '1chr'],
    ),
    NwtBibleBookInfo(
      number: 14,
      namePt: '2 Crônicas',
      nameEn: '2 Chronicles',
      code: '2CH',
      chapterCount: 36,
      aliases: ['2cr', '2ch', '2chr'],
    ),
    NwtBibleBookInfo(
      number: 15,
      namePt: 'Esdras',
      nameEn: 'Ezra',
      code: 'EZR',
      chapterCount: 10,
      aliases: ['ed', 'ezr', 'ezra'],
    ),
    NwtBibleBookInfo(
      number: 16,
      namePt: 'Neemias',
      nameEn: 'Nehemiah',
      code: 'NEH',
      chapterCount: 13,
      aliases: ['ne', 'neh'],
    ),
    NwtBibleBookInfo(
      number: 17,
      namePt: 'Ester',
      nameEn: 'Esther',
      code: 'EST',
      chapterCount: 10,
      aliases: ['et', 'est'],
    ),
    NwtBibleBookInfo(
      number: 18,
      namePt: 'Jó',
      nameEn: 'Job',
      code: 'JOB',
      chapterCount: 42,
      aliases: ['jo', 'job'],
    ),
    NwtBibleBookInfo(
      number: 19,
      namePt: 'Salmos',
      nameEn: 'Psalms',
      code: 'PSA',
      chapterCount: 150,
      aliases: ['sl', 'sal', 'salmo', 'ps', 'psa', 'psalm'],
    ),
    NwtBibleBookInfo(
      number: 20,
      namePt: 'Provérbios',
      nameEn: 'Proverbs',
      code: 'PRO',
      chapterCount: 31,
      aliases: ['pv', 'pro', 'prov'],
    ),
    NwtBibleBookInfo(
      number: 21,
      namePt: 'Eclesiastes',
      nameEn: 'Ecclesiastes',
      code: 'ECC',
      chapterCount: 12,
      aliases: ['ec', 'ecc', 'eccl'],
    ),
    NwtBibleBookInfo(
      number: 22,
      namePt: 'Cântico de Salomão',
      nameEn: 'Song of Solomon',
      code: 'SNG',
      chapterCount: 8,
      aliases: ['ct', 'sng', 'song', 'cantares'],
    ),
    NwtBibleBookInfo(
      number: 23,
      namePt: 'Isaías',
      nameEn: 'Isaiah',
      code: 'ISA',
      chapterCount: 66,
      aliases: ['is', 'isa'],
    ),
    NwtBibleBookInfo(
      number: 24,
      namePt: 'Jeremias',
      nameEn: 'Jeremiah',
      code: 'JER',
      chapterCount: 52,
      aliases: ['jr', 'jer'],
    ),
    NwtBibleBookInfo(
      number: 25,
      namePt: 'Lamentações',
      nameEn: 'Lamentations',
      code: 'LAM',
      chapterCount: 5,
      aliases: ['lm', 'lam'],
    ),
    NwtBibleBookInfo(
      number: 26,
      namePt: 'Ezequiel',
      nameEn: 'Ezekiel',
      code: 'EZK',
      chapterCount: 48,
      aliases: ['ez', 'ezk', 'ezek'],
    ),
    NwtBibleBookInfo(
      number: 27,
      namePt: 'Daniel',
      nameEn: 'Daniel',
      code: 'DAN',
      chapterCount: 12,
      aliases: ['dn', 'dan'],
    ),
    NwtBibleBookInfo(
      number: 28,
      namePt: 'Oseias',
      nameEn: 'Hosea',
      code: 'HOS',
      chapterCount: 14,
      aliases: ['os', 'hos'],
    ),
    NwtBibleBookInfo(
      number: 29,
      namePt: 'Joel',
      nameEn: 'Joel',
      code: 'JOL',
      chapterCount: 3,
      aliases: ['jl', 'jol', 'joel'],
    ),
    NwtBibleBookInfo(
      number: 30,
      namePt: 'Amós',
      nameEn: 'Amos',
      code: 'AMO',
      chapterCount: 9,
      aliases: ['am', 'amo', 'amos'],
    ),
    NwtBibleBookInfo(
      number: 31,
      namePt: 'Obadias',
      nameEn: 'Obadiah',
      code: 'OBA',
      chapterCount: 1,
      aliases: ['ob', 'oba', 'obad'],
    ),
    NwtBibleBookInfo(
      number: 32,
      namePt: 'Jonas',
      nameEn: 'Jonah',
      code: 'JON',
      chapterCount: 4,
      aliases: ['jn', 'jon', 'jonah'],
    ),
    NwtBibleBookInfo(
      number: 33,
      namePt: 'Miqueias',
      nameEn: 'Micah',
      code: 'MIC',
      chapterCount: 7,
      aliases: ['mq', 'mic'],
    ),
    NwtBibleBookInfo(
      number: 34,
      namePt: 'Naum',
      nameEn: 'Nahum',
      code: 'NAM',
      chapterCount: 3,
      aliases: ['na', 'nam', 'nah'],
    ),
    NwtBibleBookInfo(
      number: 35,
      namePt: 'Habacuque',
      nameEn: 'Habakkuk',
      code: 'HAB',
      chapterCount: 3,
      aliases: ['hc', 'hab'],
    ),
    NwtBibleBookInfo(
      number: 36,
      namePt: 'Sofonias',
      nameEn: 'Zephaniah',
      code: 'ZEP',
      chapterCount: 3,
      aliases: ['sf', 'zep', 'zeph'],
    ),
    NwtBibleBookInfo(
      number: 37,
      namePt: 'Ageu',
      nameEn: 'Haggai',
      code: 'HAG',
      chapterCount: 2,
      aliases: ['ag', 'hag'],
    ),
    NwtBibleBookInfo(
      number: 38,
      namePt: 'Zacarias',
      nameEn: 'Zechariah',
      code: 'ZEC',
      chapterCount: 14,
      aliases: ['zc', 'zec', 'zech'],
    ),
    NwtBibleBookInfo(
      number: 39,
      namePt: 'Malaquias',
      nameEn: 'Malachi',
      code: 'MAL',
      chapterCount: 4,
      aliases: ['ml', 'mal'],
    ),
    NwtBibleBookInfo(
      number: 40,
      namePt: 'Mateus',
      nameEn: 'Matthew',
      code: 'MAT',
      chapterCount: 28,
      aliases: ['mt', 'mat', 'matt'],
    ),
    NwtBibleBookInfo(
      number: 41,
      namePt: 'Marcos',
      nameEn: 'Mark',
      code: 'MRK',
      chapterCount: 16,
      aliases: ['mc', 'mrk', 'mark'],
    ),
    NwtBibleBookInfo(
      number: 42,
      namePt: 'Lucas',
      nameEn: 'Luke',
      code: 'LUK',
      chapterCount: 24,
      aliases: ['lc', 'luk', 'luke'],
    ),
    NwtBibleBookInfo(
      number: 43,
      namePt: 'João',
      nameEn: 'John',
      code: 'JHN',
      chapterCount: 21,
      aliases: ['joao', 'jhn', 'john', 'joh'],
    ),
    NwtBibleBookInfo(
      number: 44,
      namePt: 'Atos',
      nameEn: 'Acts',
      code: 'ACT',
      chapterCount: 28,
      aliases: ['at', 'act', 'acts'],
    ),
    NwtBibleBookInfo(
      number: 45,
      namePt: 'Romanos',
      nameEn: 'Romans',
      code: 'ROM',
      chapterCount: 16,
      aliases: ['rm', 'rom'],
    ),
    NwtBibleBookInfo(
      number: 46,
      namePt: '1 Coríntios',
      nameEn: '1 Corinthians',
      code: '1CO',
      chapterCount: 16,
      aliases: ['1co', '1cor'],
    ),
    NwtBibleBookInfo(
      number: 47,
      namePt: '2 Coríntios',
      nameEn: '2 Corinthians',
      code: '2CO',
      chapterCount: 13,
      aliases: ['2co', '2cor'],
    ),
    NwtBibleBookInfo(
      number: 48,
      namePt: 'Gálatas',
      nameEn: 'Galatians',
      code: 'GAL',
      chapterCount: 6,
      aliases: ['gl', 'gal'],
    ),
    NwtBibleBookInfo(
      number: 49,
      namePt: 'Efésios',
      nameEn: 'Ephesians',
      code: 'EPH',
      chapterCount: 6,
      aliases: ['ef', 'eph'],
    ),
    NwtBibleBookInfo(
      number: 50,
      namePt: 'Filipenses',
      nameEn: 'Philippians',
      code: 'PHP',
      chapterCount: 4,
      aliases: ['fp', 'php', 'phil'],
    ),
    NwtBibleBookInfo(
      number: 51,
      namePt: 'Colossenses',
      nameEn: 'Colossians',
      code: 'COL',
      chapterCount: 4,
      aliases: ['cl', 'col'],
    ),
    NwtBibleBookInfo(
      number: 52,
      namePt: '1 Tessalonicenses',
      nameEn: '1 Thessalonians',
      code: '1TH',
      chapterCount: 5,
      aliases: ['1ts', '1th', '1thess'],
    ),
    NwtBibleBookInfo(
      number: 53,
      namePt: '2 Tessalonicenses',
      nameEn: '2 Thessalonians',
      code: '2TH',
      chapterCount: 3,
      aliases: ['2ts', '2th', '2thess'],
    ),
    NwtBibleBookInfo(
      number: 54,
      namePt: '1 Timóteo',
      nameEn: '1 Timothy',
      code: '1TI',
      chapterCount: 6,
      aliases: ['1tm', '1ti', '1tim'],
    ),
    NwtBibleBookInfo(
      number: 55,
      namePt: '2 Timóteo',
      nameEn: '2 Timothy',
      code: '2TI',
      chapterCount: 4,
      aliases: ['2tm', '2ti', '2tim'],
    ),
    NwtBibleBookInfo(
      number: 56,
      namePt: 'Tito',
      nameEn: 'Titus',
      code: 'TIT',
      chapterCount: 3,
      aliases: ['tt', 'tit', 'titus'],
    ),
    NwtBibleBookInfo(
      number: 57,
      namePt: 'Filêmon',
      nameEn: 'Philemon',
      code: 'PHM',
      chapterCount: 1,
      aliases: ['fm', 'phm', 'philem'],
    ),
    NwtBibleBookInfo(
      number: 58,
      namePt: 'Hebreus',
      nameEn: 'Hebrews',
      code: 'HEB',
      chapterCount: 13,
      aliases: ['hb', 'heb'],
    ),
    NwtBibleBookInfo(
      number: 59,
      namePt: 'Tiago',
      nameEn: 'James',
      code: 'JAS',
      chapterCount: 5,
      aliases: ['tg', 'jas', 'james'],
    ),
    NwtBibleBookInfo(
      number: 60,
      namePt: '1 Pedro',
      nameEn: '1 Peter',
      code: '1PE',
      chapterCount: 5,
      aliases: ['1pe', '1pet'],
    ),
    NwtBibleBookInfo(
      number: 61,
      namePt: '2 Pedro',
      nameEn: '2 Peter',
      code: '2PE',
      chapterCount: 3,
      aliases: ['2pe', '2pet'],
    ),
    NwtBibleBookInfo(
      number: 62,
      namePt: '1 João',
      nameEn: '1 John',
      code: '1JN',
      chapterCount: 5,
      aliases: ['1jo', '1jn', '1john'],
    ),
    NwtBibleBookInfo(
      number: 63,
      namePt: '2 João',
      nameEn: '2 John',
      code: '2JN',
      chapterCount: 1,
      aliases: ['2jo', '2jn', '2john'],
    ),
    NwtBibleBookInfo(
      number: 64,
      namePt: '3 João',
      nameEn: '3 John',
      code: '3JN',
      chapterCount: 1,
      aliases: ['3jo', '3jn', '3john'],
    ),
    NwtBibleBookInfo(
      number: 65,
      namePt: 'Judas',
      nameEn: 'Jude',
      code: 'JUD',
      chapterCount: 1,
      aliases: ['jd', 'jud', 'jude'],
    ),
    NwtBibleBookInfo(
      number: 66,
      namePt: 'Apocalipse',
      nameEn: 'Revelation',
      code: 'REV',
      chapterCount: 22,
      aliases: ['ap', 'rev', 'revelacao'],
    ),
  ];

  static NwtBibleBookInfo? byNumber(int bookNumber) {
    if (bookNumber < 1 || bookNumber > all.length) return null;
    return all[bookNumber - 1];
  }

  /// Normaliza texto removendo acentos/pontuação para correspondência resiliente.
  static String normalizeName(String raw) {
    const accents = {
      'á': 'a',
      'à': 'a',
      'â': 'a',
      'ã': 'a',
      'é': 'e',
      'ê': 'e',
      'í': 'i',
      'ó': 'o',
      'ô': 'o',
      'õ': 'o',
      'ú': 'u',
      'ü': 'u',
      'ç': 'c',
    };
    final lower = raw.toLowerCase().trim();
    final buf = StringBuffer();
    for (final rune in lower.runes) {
      final ch = String.fromCharCode(rune);
      buf.write(accents[ch] ?? ch);
    }
    return buf
        .toString()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Tenta identificar o livro bíblico a partir de nome, código ou alias.
  static NwtBibleBookInfo? findByQuery(String raw) {
    final norm = normalizeName(raw);
    if (norm.isEmpty) return null;
    final compact = norm.replaceAll(' ', '');

    final asInt = int.tryParse(compact);
    if (asInt != null && asInt >= 1 && asInt <= 66) {
      return byNumber(asInt);
    }

    for (final book in all) {
      final pt = normalizeName(book.namePt);
      final en = normalizeName(book.nameEn);
      if (norm == pt ||
          norm == en ||
          compact == book.code.toLowerCase() ||
          book.aliases.contains(compact)) {
        return book;
      }
    }

    // Fallback por prefixo/contenção quando vem com título do capítulo (ex: "genesis capitulo 1" ou "salmo 23")
    for (final book in all) {
      final pt = normalizeName(book.namePt);
      final en = normalizeName(book.nameEn);
      if (norm.startsWith('$pt ') ||
          norm.startsWith('$en ') ||
          book.aliases.any((a) => norm.startsWith('$a '))) {
        return book;
      }
    }
    return null;
  }

  /// Formata o título humano (ex.: "João 3:16-17").
  static String formatReferenceLabel({
    required int bookNumber,
    required int chapter,
    String? verseSpec,
  }) {
    final book = byNumber(bookNumber);
    final bookName = book?.namePt ?? 'Livro $bookNumber';
    final cleanVerses = verseSpec?.trim() ?? '';
    if (cleanVerses.isEmpty) return '$bookName $chapter';
    return '$bookName $chapter:$cleanVerses';
  }

  /// Constrói URL canônica do jw.org / JW Library para abertura externa opcional.
  static String buildJwOrgFinderUrl({
    required int bookNumber,
    required int chapter,
    int? firstVerse,
    String wtlocale = 'T',
  }) {
    final bb = bookNumber.toString().padLeft(2, '0');
    final ccc = chapter.toString().padLeft(3, '0');
    final vvv = (firstVerse ?? 1).toString().padLeft(3, '0');
    return 'https://www.jw.org/finder?wtlocale=$wtlocale&prefer=lang&bible=$bb$ccc$vvv';
  }
}
