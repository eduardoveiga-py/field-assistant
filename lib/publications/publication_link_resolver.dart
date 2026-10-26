import 'publication_catalog.dart';

enum LinkPrecision {
  directLesson,
  publicationOnly,
  referenceOnly,
}

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

    final lang = pub.languages[languageCode] ??
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
      final webUrl = lang.officialWebUrl ?? 'https://www.jw.org/bzs/biblioteca/livros/';
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
      // Exemplo de link canônico verificado: https://www.jw.org/finder?srcid=jwlshare&wtlocale=T&pub=lff&docid=1102021200 + lesson
      // URL web direta de acesso à lição em português:
      final lessonPad = lesson.toString().padLeft(2, '0');
      final lessonWebUrl = 'https://www.jw.org/pt/biblioteca/livros/seja-feliz-para-sempre/licao-$lessonPad/';
      final finderUrl = 'https://www.jw.org/finder?srcid=jwlshare&wtlocale=${lang.wtlocale}&pub=${pub.code}&lesson=$lesson';

      return ResolvedLink(
        url: finderUrl,
        fallbackUrl: lessonWebUrl,
        precision: LinkPrecision.directLesson,
        displayText: display.toString(),
        isSignLanguage: false,
        note: paragraph != null
            ? 'Abertura direta garantida até a Lição $lesson. A localização do parágrafo $paragraph deve ser conferida na página.'
            : 'Abre diretamente a Lição $lesson.',
        isDirectParagraphSupported: false, // Deep linking específico para número de parágrafo não é documentado oficialmente pela API pública
      );
    }

    if (pub.id == 'lff-brochure' && lesson != null && lesson >= 1 && lesson <= 3) {
      final finderUrl = 'https://www.jw.org/finder?srcid=jwlshare&wtlocale=${lang.wtlocale}&pub=${pub.code}&lesson=$lesson';
      return ResolvedLink(
        url: finderUrl,
        fallbackUrl: lang.officialWebUrl,
        precision: LinkPrecision.directLesson,
        displayText: display.toString(),
        isSignLanguage: false,
        note: 'Abre a Lição $lesson da brochura introdutória.',
        isDirectParagraphSupported: false,
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
