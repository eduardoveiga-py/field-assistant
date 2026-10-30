class PublicationInfo {
  final String id;
  final String code; // Ex: lff
  final String title;
  final String type; // 'livro', 'brochura'
  final int totalLessons;
  final Map<String, LanguageAvailability> languages;

  const PublicationInfo({
    required this.id,
    required this.code,
    required this.title,
    required this.type,
    required this.totalLessons,
    required this.languages,
  });
}

class LanguageAvailability {
  final String languageCode; // pt, tca, bzs
  final String languageName;
  final String wtlocale; // Código oficial JW (T = Português, TCA = Ticuna, BZS = Libras)
  final bool isVerified;
  final bool isSignLanguage;
  final String? officialWebUrl;

  const LanguageAvailability({
    required this.languageCode,
    required this.languageName,
    required this.wtlocale,
    required this.isVerified,
    this.isSignLanguage = false,
    this.officialWebUrl,
  });
}

class PublicationCatalog {
  static const PublicationInfo bookLff = PublicationInfo(
    id: 'lff-book',
    code: 'lff',
    title: 'Livro: Seja Feliz para Sempre!',
    type: 'livro',
    totalLessons: 60,
    languages: {
      'pt': LanguageAvailability(
        languageCode: 'pt',
        languageName: 'Português',
        wtlocale: 'T',
        isVerified: true,
        officialWebUrl: 'https://www.jw.org/pt/biblioteca/livros/seja-feliz-para-sempre/',
      ),
      'tca': LanguageAvailability(
        languageCode: 'tca',
        languageName: 'Ticuna',
        wtlocale: 'TCA',
        isVerified: true,
        officialWebUrl: 'https://www.jw.org/tca/biblioteca/livros/',
      ),
      'bzs': LanguageAvailability(
        languageCode: 'bzs',
        languageName: 'Língua Brasileira de Sinais (Libras)',
        wtlocale: 'BZS',
        isVerified: true,
        isSignLanguage: true,
        officialWebUrl: 'https://www.jw.org/bzs/biblioteca/livros/seja-feliz-para-sempre/',
      ),
    },
  );

  static const PublicationInfo brochureLff = PublicationInfo(
    id: 'lff-brochure',
    code: 'lffi',
    title: 'Brochura: Seja Feliz para Sempre!',
    type: 'brochura',
    totalLessons: 3,
    languages: {
      'pt': LanguageAvailability(
        languageCode: 'pt',
        languageName: 'Português',
        wtlocale: 'T',
        isVerified: true,
        officialWebUrl: 'https://www.jw.org/pt/biblioteca/livros/licoes-biblicas-introducao/',
      ),
      'tca': LanguageAvailability(
        languageCode: 'tca',
        languageName: 'Ticuna',
        wtlocale: 'TCA',
        isVerified: true,
        officialWebUrl: 'https://www.jw.org/tca/biblioteca/livros/',
      ),
      'bzs': LanguageAvailability(
        languageCode: 'bzs',
        languageName: 'Língua Brasileira de Sinais (Libras)',
        wtlocale: 'BZS',
        isVerified: true,
        isSignLanguage: true,
        officialWebUrl: 'https://www.jw.org/bzs/biblioteca/livros/',
      ),
    },
  );

  static const PublicationInfo brochureListenToGod = PublicationInfo(
    id: 'll-brochure',
    code: 'll',
    title: 'Brochura: Escute a Deus e Viva para Sempre',
    type: 'brochura',
    totalLessons: 14,
    languages: {
      'pt': LanguageAvailability(
        languageCode: 'pt',
        languageName: 'Português',
        wtlocale: 'T',
        isVerified: true,
        officialWebUrl: 'https://www.jw.org/pt/biblioteca/livros/escute-a-deus/',
      ),
      'tca': LanguageAvailability(
        languageCode: 'tca',
        languageName: 'Ticuna',
        wtlocale: 'TCA',
        isVerified: true,
        officialWebUrl: 'https://www.jw.org/tca/biblioteca/livros/',
      ),
      'bzs': LanguageAvailability(
        languageCode: 'bzs',
        languageName: 'Língua Brasileira de Sinais (Libras)',
        wtlocale: 'BZS',
        isVerified: true,
        isSignLanguage: true,
        officialWebUrl: 'https://www.jw.org/bzs/biblioteca/livros/',
      ),
    },
  );

  static List<PublicationInfo> get allPublications => [bookLff, brochureLff, brochureListenToGod];

  static PublicationInfo? getById(String id) {
    if (id == 'lff-book' || id == 'lff') return bookLff;
    if (id == 'lff-brochure' || id == 'lffi') return brochureLff;
    if (id == 'll-brochure' || id == 'll') return brochureListenToGod;
    return null;
  }
}
