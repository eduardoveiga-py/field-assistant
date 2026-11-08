import 'publication_catalog.dart';

enum LinkPrecision { directLesson, publicationOnly, referenceOnly }

class ResolvedLink {
  final String? url;
  final String? fallbackUrl;
  final LinkPrecision precision;
  final String displayText;
  final bool isSignLanguage;
  final String? note;
  final bool isDirectParagraphSupported;

  const ResolvedLink({
    this.url,
    this.fallbackUrl,
    required this.precision,
    required this.displayText,
    this.isSignLanguage = false,
    this.note,
    this.isDirectParagraphSupported = false,
  });
}

class PublicationLinkResolver {
  /// Resolve a referência de estudo bíblico para links e instruções oficiais transparentes.
  static ResolvedLink resolve({
    required String publicationId,
    required String languageCode,
    int? lesson,
    int? paragraph,
    String? manualReference,
  }) {
    final pub = PublicationCatalog.getById(publicationId);
    if (pub == null) {
      return ResolvedLink(
        precision: LinkPrecision.referenceOnly,
        displayText: manualReference ?? 'Referência não catalogada',
        note: 'Publicação não reconhecida no catálogo oficial.',
      );
    }

    final lang =
        pub.languages[languageCode] ??
        pub.languages['pt'] ??
        pub.languages.values.first;

    final isLibras = lang.isSignLanguage;

    // Monta texto de referência amigável
    final StringBuffer display = StringBuffer(pub.title);
    if (lesson != null) {
      display.write(', Lição $lesson');
    }
    if (paragraph != null && !isLibras) {
      display.write(', § $paragraph');
    }
    if (manualReference != null && manualReference.isNotEmpty) {
      display.write(' ($manualReference)');
    }
    display.write(' [${lang.languageName}]');

    // Se for Libras (Língua de Sinais):
    // Não força parágrafos textuais, direciona para a seção/vídeo da publicação oficial
    if (isLibras) {
      final webUrl =
          lang.officialWebUrl ?? 'https://www.jw.org/bzs/biblioteca/livros/';
      return ResolvedLink(
        url: webUrl,
        fallbackUrl: webUrl,
        precision: LinkPrecision.publicationOnly,
        displayText: display.toString(),
        isSignLanguage: true,
        note: 'Em Libras, o conteúdo é distribuído em vídeos por lição. Não há divisão de parágrafos idêntica ao texto impresso.',
        isDirectParagraphSupported: false,
      );
    }

    // Para Português e outros idiomas textuais
    if (pub.id == 'lff-book' && lesson != null && lesson >= 1 && lesson <= 60) {
      // Formato oficial do buscador e compartilhamento JW para Lições do livro LFF
      // Exemplo de link canônico verificado: https://www.jw.org/finder?srcid=jwlshare&wtlocale=T&prefer=lang&pub=lff&lesson=1&docid=1102021201&par=3
      final docId = 1102021200 + lesson;
      final partNumber = lesson <= 12 ? 1 : lesson <= 33 ? 2 : lesson <= 47 ? 3 : 4;
      final lessonPad = lesson.toString().padLeft(2, '0');
      var lessonWebUrl =
          'https://www.jw.org/pt/biblioteca/livros/seja-feliz-para-sempre/parte-$partNumber/licao-$lessonPad/';
      var finderUrl =
          'https://www.jw.org/finder?srcid=jwlshare&wtlocale=${lang.wtlocale}&prefer=lang&pub=${pub.code}&lesson=$lesson&docid=$docId';

      if (paragraph != null && paragraph > 0) {
        finderUrl += '&par=$paragraph';
        lessonWebUrl += '#p$paragraph';
      }

      return ResolvedLink(
        url: finderUrl,
        fallbackUrl: lessonWebUrl,
        precision: LinkPrecision.directLesson,
        displayText: display.toString(),
        isSignLanguage: false,
        note: paragraph != null
            ? 'Abertura direta garantida na Lição $lesson, parágrafo $paragraph no JW Library.'
            : 'Abre diretamente a Lição $lesson no JW Library.',
        isDirectParagraphSupported: paragraph != null && paragraph > 0,
      );
    }

    if (pub.id == 'lff-brochure' &&
        lesson != null &&
        lesson >= 1 &&
        lesson <= 3) {
      final docId = 1102021200 + lesson;
      final lessonPad = lesson.toString().padLeft(2, '0');
      var lessonWebUrl =
          'https://www.jw.org/pt/biblioteca/livros/seja-feliz-para-sempre/parte-1/licao-$lessonPad/';
      var finderUrl =
          'https://www.jw.org/finder?srcid=jwlshare&wtlocale=${lang.wtlocale}&prefer=lang&pub=${pub.code}&lesson=$lesson&docid=$docId';
      if (paragraph != null && paragraph > 0) {
        finderUrl += '&par=$paragraph';
        lessonWebUrl += '#p$paragraph';
      }
      return ResolvedLink(
        url: finderUrl,
        fallbackUrl: lessonWebUrl,
        precision: LinkPrecision.directLesson,
        displayText: display.toString(),
        isSignLanguage: false,
        note: paragraph != null
            ? 'Abre a Lição $lesson, parágrafo $paragraph da brochura introdutória no JW Library.'
            : 'Abre a Lição $lesson da brochura introdutória no JW Library.',
        isDirectParagraphSupported: paragraph != null && paragraph > 0,
      );
    }

    // Fallback para a página inicial da publicação no idioma
    return ResolvedLink(
      url: lang.officialWebUrl,
      fallbackUrl: lang.officialWebUrl,
      precision: LinkPrecision.publicationOnly,
      displayText: display.toString(),
      isSignLanguage: false,
      note: 'Abre a página inicial da publicação no jw.org.',
      isDirectParagraphSupported: false,
    );
  }
}
