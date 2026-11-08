/// Modelos e metadados para suporte multilíngue e assistente linguístico no ministério.
/// Suporta línguas indígenas (Ticuna, Guajajara, Yanomami) e idiomas de comparação (Português, Espanhol).
library;

/// Metadados de um idioma registrado no sistema
class LanguageMetadata {
  final String code; // Código ISO ou canônico (tca, por, spa, gub, yan)
  final String name; // Nome em português
  final String nativeName; // Autodenominação nativa
  final String symbol; // Emoji ou ícone representativo
  final bool isIndigenous; // Idioma indígena originário
  final bool isFlagship; // Língua de referência principal (Ticuna)
  final bool hasDiacritics; // Requer barra de caracteres especiais
  final List<String> diacritics; // Caracteres e diacríticos especiais
  final String description; // Contexto regional e demográfico

  const LanguageMetadata({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.symbol,
    this.isIndigenous = false,
    this.isFlagship = false,
    this.hasDiacritics = false,
    this.diacritics = const [],
    required this.description,
  });
  bool get isIndigenousFlagship => isIndigenous && isFlagship;
}

/// Registro extensível de idiomas do Assistente Teocrático
class LanguageRegistry {
  LanguageRegistry._();

  static const LanguageMetadata ticuna = LanguageMetadata(
    code: 'tca',
    name: 'Ticuna',
    nativeName: 'Magüta / Tikuna',
    symbol: '🏹',
    isIndigenous: true,
    isFlagship: true,
    hasDiacritics: true,
    diacritics: ['ã', 'ẽ', 'ĩ', 'õ', 'ũ', 'ü', 'ü̃', 'á', 'é', 'í', 'ó', 'ú'],
    description: 'Maior povo indígena da Amazônia brasileira e fronteira Peru-Colômbia (Alto Solimões).',
  );

  static const LanguageMetadata portugues = LanguageMetadata(
    code: 'por',
    name: 'Português',
    nativeName: 'Português',
    symbol: '🇧🇷',
    isIndigenous: false,
    isFlagship: false,
    hasDiacritics: false,
    description: 'Língua de trabalho e base ministerial no Brasil.',
  );

  static const LanguageMetadata espanol = LanguageMetadata(
    code: 'spa',
    name: 'Español',
    nativeName: 'Español',
    symbol: '🇪🇸',
    isIndigenous: false,
    isFlagship: false,
    hasDiacritics: false,
    description: 'Usado na fronteira tríplice (Tabatinga, Letícia e Santa Rosa).',
  );

  static const LanguageMetadata guajajara = LanguageMetadata(
    code: 'gub',
    name: 'Guajajara',
    nativeName: 'Tenetehara / Ze\'egete',
    symbol: '🌿',
    isIndigenous: true,
    isFlagship: false,
    hasDiacritics: true,
    diacritics: ['à', 'è', 'ì', 'ò', 'ù', 'ỹ', '\''],
    description: 'Tronco Tupi-Guarani falado no Maranhão e regiões adjacentes.',
  );

  static const LanguageMetadata yanomami = LanguageMetadata(
    code: 'yan',
    name: 'Yanomami',
    nativeName: 'Yanomamõ',
    symbol: '🌳',
    isIndigenous: true,
    isFlagship: false,
    hasDiacritics: true,
    diacritics: ['ë', 'ɨ', 'th', 'rh'],
    description: 'Família Yanomami falada em Roraima e no Amazonas.',
  );

  /// Lista de idiomas ativos e suportados
  static const List<LanguageMetadata> allLanguages = [
    ticuna,
    portugues,
    espanol,
    guajajara,
    yanomami,
  ];

  static List<LanguageMetadata> get allSupportedLanguages => allLanguages;

  static LanguageMetadata fromCode(String code) {
    for (final lang in allLanguages) {
      if (lang.code == code) return lang;
    }
    return ticuna;
  }

  static LanguageMetadata? findByCode(String code) {
    for (final lang in allLanguages) {
      if (lang.code == code) return lang;
    }
    return null;
  }
}

/// 6 Momentos-Chave do Ministério de Campo
enum MinistryMoment {
  greeting('1. Saudação Inicial', 'Cumprimento cordial respeitando a cultura local', '🤝'),
  bibleReading('2. Leitura Bíblica', 'Apresentação e leitura de texto confortador', '📖'),
  returnQuestion('3. Pergunta para Revisita', 'Pergunta reflexiva deixada para o retorno', '❓'),
  studyOffer('4. Oferta de Estudo', 'Convite caloroso para exame da Bíblia', '💡'),
  objections('5. Lidando com Objeções', 'Resposta respeitosa e calma a objeções comuns', '🛡️'),
  parting('6. Despedida Cordial', 'Agradecimento e encerramento afetuoso', '👋');

  final String title;
  final String description;
  final String iconEmoji;

  const MinistryMoment(this.title, this.description, this.iconEmoji);
}

/// Frase situacional completa para o ministério com suporte a múltiplos idiomas
class SituationalPhrase {
  final String id;
  final MinistryMoment moment;
  final String title;
  final String portuguese;
  final String ticuna;
  final String spanish;
  final String? guajajara;
  final String phonetics;
  final String culturalNotes;
  final String? bibleVerse;

  const SituationalPhrase({
    required this.id,
    required this.moment,
    required this.title,
    required this.portuguese,
    required this.ticuna,
    required this.spanish,
    this.guajajara,
    required this.phonetics,
    required this.culturalNotes,
    this.bibleVerse,
  });
}

/// Biblioteca canônica de frases situacionais do ministério de campo
class MinistryPhrasesCatalog {
  MinistryPhrasesCatalog._();

  static const List<SituationalPhrase> phrases = [
    // 1. Saudação Inicial
    SituationalPhrase(
      id: 'sp_greet_01',
      moment: MinistryMoment.greeting,
      title: 'Cumprimento de Bom Dia',
      portuguese: 'Bom dia! Como vai você e sua família?',
      ticuna: 'Ta-ẽ-mã! Nümá tá i yae?',
      spanish: '¡Buenos días! ¿Cómo está usted y su familia?',
      guajajara: 'Ko\'em me! Erekwehe kar?',
      phonetics: 'ta-ẽ-mã! nü-má tá i ya-e?',
      culturalNotes: 'Na cultura Ticuna, a saudação matutina demonstra profunda consideração pela paz familiar.',
    ),
    SituationalPhrase(
      id: 'sp_greet_02',
      moment: MinistryMoment.greeting,
      title: 'Apresentação do Motivo da Visita',
      portuguese: 'Vim compartilhar uma mensagem de esperança da Palavra de Deus.',
      ticuna: 'Tupana arü ore i duü̃cü̃ẽ tá naa tütütama.',
      spanish: 'Vengo a compartir un mensaje de esperanza de la Palabra de Dios.',
      phonetics: 'tu-pa-na a-rü o-re i du-ü̃-cü̃-ẽ...',
      culturalNotes: 'Tupana é o Criador respeitado por toda a comunidade.',
      bibleVerse: 'Romanos 15:4',
    ),

    // 2. Leitura de Texto Bíblico
    SituationalPhrase(
      id: 'sp_bible_01',
      moment: MinistryMoment.bibleReading,
      title: 'Convite para Leitura de Salmo 37:29',
      portuguese: 'Gostaria de ler com você o que Deus promete para o futuro da Terra.',
      ticuna: 'Kũ-yexma tá arü ore na Tupana ü̃guẽxẽ i na-yaxna.',
      spanish: 'Me gustaría leer con usted lo que Dios promete para el futuro de la Tierra.',
      phonetics: 'kũ-yex-ma tá a-rü o-re na tu-pa-na...',
      culturalNotes: 'Mostre o texto diretamente na Bíblia impressa ou no app JW Library.',
      bibleVerse: 'Salmo 37:29',
    ),
    SituationalPhrase(
      id: 'sp_bible_02',
      moment: MinistryMoment.bibleReading,
      title: 'Fim das Doenças e Sofrimento',
      portuguese: 'Deus promete enxugar toda lágrima e acabar com a dor e a morte.',
      ticuna: 'Tupana tá na yaxõgü ya guxü̃ma i ngexta tüü̃ i daxu arü.',
      spanish: 'Dios promete secar toda lágrima y terminar con el dolor y la muerte.',
      phonetics: 'tu-pa-na tá na ya-xõ-gü ya gu-xü̃-ma...',
      culturalNotes: 'Tema muito sensível em comunidades ribeirinhas que enfrentam escassez médica.',
      bibleVerse: 'Apocalipse 21:4',
    ),

    // 3. Pergunta para Revisita
    SituationalPhrase(
      id: 'sp_return_01',
      moment: MinistryMoment.returnQuestion,
      title: 'Pergunta Deixada para Próxima Conversa',
      portuguese: 'Por que Deus permite o sofrimento se Ele nos ama tanto?',
      ticuna: 'Ñuxpata Tupana tá na taexẽẽ i ngexta tüü̃ ngexkuma duü̃xü̃gü?',
      spanish: '¿Por qué permite Dios el sufrimiento si nos ama tanto?',
      phonetics: 'ñux-pa-ta tu-pa-na tá na ta-e-xẽ-ẽ...',
      culturalNotes: 'Deixar esta pergunta cria expectativa positiva para a revisita marcada.',
      bibleVerse: '1 João 5:19',
    ),
    SituationalPhrase(
      id: 'sp_return_02',
      moment: MinistryMoment.returnQuestion,
      title: 'Pergunta sobre a Oração',
      portuguese: 'Será que Deus realmente ouve todas as orações sinceras?',
      ticuna: 'Tupana tá i ü̃naxwa taarü i ore nümata?',
      spanish: '¿Realmente escucha Dios todas las oraciones sinceras?',
      phonetics: 'tu-pa-na tá i ü̃-nax-wa taa-rü...',
      culturalNotes: 'Assegure que podemos orar em qualquer língua, inclusive em Ticuna.',
      bibleVerse: 'Salmo 65:2',
    ),

    // 4. Oferta de Estudo Bíblico
    SituationalPhrase(
      id: 'sp_study_01',
      moment: MinistryMoment.studyOffer,
      title: 'Oferta do Curso Bíblico Gratuito',
      portuguese: 'Temos um curso interativo da Bíblia sem nenhum custo.',
      ticuna: 'Ta-yaxõ Tupana arü ore i ñuxtama i taxu i ta-ma.',
      spanish: 'Ofrecemos un curso interactivo de la Biblia completamente gratuito.',
      phonetics: 'ta-ya-xõ tu-pa-na a-rü o-re...',
      culturalNotes: 'Apresente a brochura "Seja Feliz Para Sempre!" mostrando as ilustrações ricas.',
      bibleVerse: 'Mateus 28:19, 20',
    ),

    // 5. Lidando com Objeções
    SituationalPhrase(
      id: 'sp_objection_01',
      moment: MinistryMoment.objections,
      title: 'Morador Ocupado no Momento',
      portuguese: 'Entendo perfeitamente que você está ocupado. Posso voltar outro dia?',
      ticuna: 'Ñaxna i nümá i ngexta taxu. Tá kuaxoxma i guma?',
      spanish: 'Entiendo perfectamente que está ocupado. ¿Puedo volver otro día?',
      phonetics: 'ñax-na i nü-má i ngex-ta ta-xu...',
      culturalNotes: 'Respeite imediatamente o tempo do morador. Jamais insista além do limite cordial.',
    ),
    SituationalPhrase(
      id: 'sp_objection_02',
      moment: MinistryMoment.objections,
      title: 'Morador já possui sua religião',
      portuguese: 'Respeitamos muito sua fé. Nossa visita é só para ler um texto bíblico curto.',
      ticuna: 'Taa-rü na duü̃ i kuaxü̃. Tupana ore tüü̃ na yaxõtü̃güma.',
      spanish: 'Respetamos mucho su religión. Solo queremos compartir un texto bíblico breve.',
      phonetics: 'taa-rü na du-ü̃ i kua-xü̃...',
      culturalNotes: 'Muitas comunidades têm tradições fortes; elogie a fé e sinceridade da pessoa.',
    ),

    // 6. Despedida Cordial
    SituationalPhrase(
      id: 'sp_parting_01',
      moment: MinistryMoment.parting,
      title: 'Agradecimento e Até Logo',
      portuguese: 'Muito obrigado pela sua atenção! Que Deus abençoe sua casa.',
      ticuna: 'Poxna! Tupana tá ku-taxõkütama i yae.',
      spanish: '¡Muchas gracias por su atención! Que Dios bendiga su hogar.',
      guajajara: 'Tupana nemonan kar!',
      phonetics: 'pox-na! tu-pa-na tá ku-ta-xõ-kü-ta-ma i ya-e.',
      culturalNotes: 'Poxna significa obrigado com gratidão sincera.',
    ),
    SituationalPhrase(
      id: 'sp_parting_02',
      moment: MinistryMoment.parting,
      title: 'Confirmação do Dia de Retorno',
      portuguese: 'Combinado então! No sábado pela manhã passo aqui novamente.',
      ticuna: 'Ta-yaxõ tá xanama i na-xoxma tá nümá tá.',
      spanish: '¡Quedamos así! El sábado por la mañana volveré a visitarlo.',
      phonetics: 'ta-ya-xõ tá xa-na-ma...',
      culturalNotes: 'Anote imediatamente o compromisso na agenda do app para evitar esquecimentos.',
    ),
  ];

  static List<SituationalPhrase> byMoment(MinistryMoment moment) {
    return phrases.where((p) => p.moment == moment).toList();
  }

  static List<SituationalPhrase> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return phrases;
    return phrases.where((p) {
      return p.title.toLowerCase().contains(q) ||
          p.portuguese.toLowerCase().contains(q) ||
          p.ticuna.toLowerCase().contains(q) ||
          p.spanish.toLowerCase().contains(q) ||
          (p.guajajara != null && p.guajajara!.toLowerCase().contains(q)) ||
          p.culturalNotes.toLowerCase().contains(q) ||
          (p.bibleVerse != null && p.bibleVerse!.toLowerCase().contains(q));
    }).toList();
  }
}
