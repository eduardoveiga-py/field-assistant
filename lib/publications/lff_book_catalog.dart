/// Representação de uma Lição do livro "Seja Feliz para Sempre!"
class LffLessonInfo {
  final int number;
  final String title;
  final int section;
  final List<String> pointTitles;
  final String? somePeopleSay;
  final String? summary;
  final List<String> reviewQuestions;
  final String? tryThis;

  const LffLessonInfo({
    required this.number,
    required this.title,
    required this.section,
    required this.pointTitles,
    this.somePeopleSay,
    this.summary,
    this.reviewQuestions = const [],
    this.tryThis,
  });

  int get totalPoints => pointTitles.length;

  String get displayName => 'Lição $number: $title';
}

/// Seção ou Bloco do livro
class LffSectionInfo {
  final int sectionNumber;
  final String title;
  final int startLesson;
  final int endLesson;
  final String reviewTitle;

  const LffSectionInfo({
    required this.sectionNumber,
    required this.title,
    required this.startLesson,
    required this.endLesson,
    required this.reviewTitle,
  });
}

/// Nota explicativa / Seção Entenda Melhor
class LffEndnoteInfo {
  final int number;
  final String title;

  const LffEndnoteInfo({
    required this.number,
    required this.title,
  });
}

/// Catálogo Oficial Exato do Livro "Seja Feliz Para Sempre!"
/// Sincronizado e extraído com precisão do jw.org
class LffBookCatalog {
  static const int totalLessons = 60;

  static const List<LffSectionInfo> sections = [
    LffSectionInfo(
      sectionNumber: 1,
      title: 'Parte 1: Conheça a Deus e a Bíblia',
      startLesson: 1,
      endLesson: 12,
      reviewTitle: 'Parte 1: Revisão (Lições 01 a 12)',
    ),
    LffSectionInfo(
      sectionNumber: 2,
      title: 'Parte 2: Conheça a Jeová, a Jesus e o propósito deles',
      startLesson: 13,
      endLesson: 33,
      reviewTitle: 'Parte 2: Revisão (Lições 13 a 33)',
    ),
    LffSectionInfo(
      sectionNumber: 3,
      title: 'Parte 3: Viva de um modo que agrade a Deus',
      startLesson: 34,
      endLesson: 47,
      reviewTitle: 'Parte 3: Revisão (Lições 34 a 47)',
    ),
    LffSectionInfo(
      sectionNumber: 4,
      title: 'Parte 4: Continue a fortalecer sua amizade com Jeová',
      startLesson: 48,
      endLesson: 60,
      reviewTitle: 'Parte 4: Revisão (Lições 48 a 60)',
    ),
  ];

  static const List<LffEndnoteInfo> endnotes = [
    LffEndnoteInfo(number: 1, title: 'O nome de Deus nas Escrituras Hebraicas e Gregas'),
    LffEndnoteInfo(number: 2, title: 'O que a Bíblia diz sobre a Trindade?'),
    LffEndnoteInfo(number: 3, title: 'Datas bíblicas e o ano de 1914'),
    LffEndnoteInfo(number: 4, title: 'Quem são o arcanjo Miguel e Abadom?'),
    LffEndnoteInfo(number: 5, title: 'Questões médicas envolvendo o sangue'),
    LffEndnoteInfo(number: 6, title: 'O que a Bíblia diz sobre neutralidade cristã'),
    LffEndnoteInfo(number: 7, title: 'Assuntos comerciais e legais entre cristãos'),
  ];

  static const List<LffLessonInfo> lessons = [
    // === Parte 1: Conheça a Deus e a Bíblia (Lições 1 a 12) ===
    LffLessonInfo(
      number: 1,
      title: 'Como a Bíblia pode ajudar você?',
      section: 1,
      pointTitles: [
        '1. A Bíblia pode nos guiar',
        '2. A Bíblia pode responder às nossas perguntas',
        '3. A leitura da Bíblia pode ser agradável',
      ],
      summary: 'A Bíblia nos dá conselhos práticos para o dia a dia, responde a perguntas importantes e nos dá esperança e consolo.',
      reviewQuestions: [
        'Que tipo de conselhos encontramos na Bíblia?',
        'Quais são algumas perguntas que a Bíblia responde?',
        'O que você gostaria de aprender na Bíblia?',
      ],
      tryThis: 'Leia a primeira parte do programa de leitura da Bíblia desta lição.',
    ),
    LffLessonInfo(
      number: 2,
      title: 'A Bíblia nos dá esperança',
      section: 1,
      pointTitles: [
        '1. A Bíblia promete que teremos um futuro maravilhoso',
        '2. A esperança da Bíblia pode fazer a diferença na nossa vida hoje',
        '3. A esperança da Bíblia nos dá forças para perseverar',
      ],
      summary: 'A Bíblia promete que teremos um futuro maravilhoso. Essa esperança nos ajuda a lidar com os problemas hoje.',
      reviewQuestions: [
        'Que promessas da Bíblia para o futuro você mais gostou?',
        'Como a esperança da Bíblia pode ajudar você hoje?',
      ],
      tryThis: 'Leia os textos bíblicos citados nesta lição e pense em como eles se aplicam a você.',
    ),
    LffLessonInfo(
      number: 3,
      title: 'Será que você pode acreditar na Bíblia?',
      section: 1,
      pointTitles: [
        '1. A Bíblia está de acordo com a ciência',
        '2. A Bíblia relata acontecimentos históricos com exatidão',
        '3. As profecias da Bíblia sempre se cumprem',
      ],
      summary: 'A ciência, a história e as profecias cumpridas provam que podemos confiar na Bíblia.',
      reviewQuestions: [
        'A Bíblia é um livro de mitos ou relata a verdade?',
        'Quais são alguns exemplos de harmonia entre a Bíblia e a ciência?',
        'Você acha que pode confiar na Bíblia?',
      ],
      tryThis: 'No final desta lição 3: Avaliar a aceitação do estudante para continuar o estudo com o livro completo a partir da Lição 4.',
    ),
    LffLessonInfo(
      number: 4,
      title: 'Quem é Deus?',
      section: 1,
      pointTitles: [
        '1. Qual é o nome de Deus?',
        '2. O que a Bíblia diz sobre Jeová?',
        '3. Deus tem muitos títulos, mas apenas um nome',
        '4. Jeová quer que você conheça e use o nome dele',
        '5. Jeová quer que você se aproxime dele como amigo',
        '6. Jeová é uma Pessoa real que tem sentimentos',
      ],
      somePeopleSay: 'Deus é um só. Então, não faz diferença o jeito que você chama a ele.',
      summary: 'Jeová é o nome do único Deus verdadeiro. Ele quer que a gente se aproxime mais dele conhecendo e usando o seu nome.',
      reviewQuestions: [
        'Por que Jeová é diferente de todos os outros deuses?',
        'Por que é importante usar o nome de Deus?',
        'O que prova que Jeová quer que você se aproxime mais dele?',
      ],
      tryThis: 'Quando falar sobre Deus, use o nome dele, Jeová.',
    ),
    LffLessonInfo(
      number: 5,
      title: 'A Bíblia é a mensagem de Deus para nós',
      section: 1,
      pointTitles: [
        '1. Por que podemos dizer que a Bíblia é única?',
        '2. O que a Bíblia diz sobre o futuro?',
        '3. Por que podemos confiar na Bíblia?',
        '4. Homens escreveram a Bíblia, mas Deus é o Autor',
        '5. A Bíblia sofreu muitos ataques, mas sobreviveu',
        '6. Um livro traduzido para pessoas de todas as nações e línguas',
      ],
      somePeopleSay: 'A Bíblia foi escrita por homens. Por isso, não dá para confiar nela.',
      summary: 'A Bíblia é a Palavra inspirada de Deus. Ele cuidou para que ela chegasse até nós sem alterações no seu conteúdo essencial.',
      reviewQuestions: [
        'O que significa dizer que a Bíblia é inspirada por Deus?',
        'O que mais impressiona você sobre a preservação da Bíblia?',
        'Por que podemos confiar plenamente nas suas profecias?',
      ],
      tryThis: 'Crie o hábito de ler um trecho da Bíblia todos os dias.',
    ),
    LffLessonInfo(
      number: 6,
      title: 'Como a vida começou?',
      section: 1,
      pointTitles: [
        '1. Como é que o Universo começou?',
        '2. Por que Deus criou a Terra?',
        '3. O que mostra que a vida foi criada?',
        '4. O projeto inteligente e a complexidade da natureza',
        '5. O relato bíblico de Gênesis e a verdadeira ciência',
        '6. Por que é razoável e lógico acreditar num Criador',
      ],
      somePeopleSay: 'A vida começou por acaso através da evolução biológica.',
      summary: 'Jeová criou o Universo e toda a vida na Terra com amor, sabedoria e um objetivo claro para a humanidade.',
      reviewQuestions: [
        'O que a Bíblia ensina sobre o início do Universo?',
        'Por que o acaso cego não explica o projeto da vida?',
        'O que faz os humanos serem únicos aos olhos de Deus?',
      ],
      tryThis: 'Observe uma criação de Deus nesta semana e reflita sobre o que ela ensina sobre Ele.',
    ),
    LffLessonInfo(
      number: 7,
      title: 'Conheça mais a Jeová',
      section: 1,
      pointTitles: [
        '1. Que qualidades atraem as pessoas a Jeová?',
        '2. O amor de Deus por você',
        '3. Será que Jeová entende quando sofremos?',
        '4. Como podemos alegrar o coração de Jeová?',
        '5. A justiça perfeita, o poder e a sabedoria divina',
        '6. Jeová é uma Pessoa real que se importa com você individualmente',
      ],
      somePeopleSay: 'Deus é uma força impessoal presente em todo lugar, sem sentimentos.',
      summary: 'Jeová tem sentimentos reais e quatro qualidades principais: amor, sabedoria, justiça e poder. O amor é a sua qualidade dominante.',
      reviewQuestions: [
        'Quais são as quatro qualidades principais de Jeová?',
        'Como sabemos que Jeová se importa quando sofremos?',
        'De que maneiras podemos alegrar o coração de Jeová?',
      ],
      tryThis: 'Escolha uma qualidade de Jeová e pense em como imitá-la no seu dia a dia.',
    ),
    LffLessonInfo(
      number: 8,
      title: 'Você pode ser amigo de Jeová',
      section: 1,
      pointTitles: [
        '1. O melhor amigo que alguém pode ter',
        '2. O que Jeová faz pelos amigos dele?',
        '3. O que Jeová espera dos amigos dele?',
        '4. O exemplo de Abraão como amigo leal de Deus',
        '5. Como conversar com Deus e escutá-lo na Bíblia',
        '6. A alegria e a paz de ter Deus como protetor e guia',
      ],
      somePeopleSay: 'Humanos imperfeitos jamais poderiam ser amigos íntimos do Soberano do Universo.',
      summary: 'Jeová convida você para se aproximar dele. Ele cuida dos seus amigos e abençoa ricamente os que o amam com lealdade.',
      reviewQuestions: [
        'O que torna Jeová o melhor amigo que você pode ter?',
        'O que Jeová pede dos amigos dele?',
        'Como você pode fortalecer sua amizade com Deus?',
      ],
      tryThis: 'Fale com Jeová em oração sobre suas alegrias e preocupações diárias.',
    ),
    LffLessonInfo(
      number: 9,
      title: 'A oração fortalece sua amizade com Deus',
      section: 1,
      pointTitles: [
        '1. Para quem devemos orar, e sobre o quê?',
        '2. Como devemos orar com sinceridade?',
        '3. Como Deus responde nossas orações?',
        '4. O que significa orar exclusivamente em nome de Jesus',
        '5. Como a oração regular traz paz mental e espiritual',
        '6. Confiança plena de que Jeová ouve o clamor dos que o buscam',
      ],
      somePeopleSay: 'Orar não adianta nada, é apenas uma ilusão ou ritual religioso.',
      summary: 'A oração sincera a Jeová em nome de Jesus é ouvida por Deus. Ele responde provendo força, sabedoria, paz e auxílio prático.',
      reviewQuestions: [
        'A quem devemos dirigir nossas orações e por meio de quem?',
        'Que assuntos podemos incluir nas orações?',
        'De que maneiras Jeová responde às nossas orações?',
      ],
      tryThis: 'Reserve momentos regulares ao longo do dia para orar a Jeová de coração.',
    ),
    LffLessonInfo(
      number: 10,
      title: 'Como as reuniões das Testemunhas de Jeová podem ajudar você?',
      section: 1,
      pointTitles: [
        '1. Qual o principal objetivo das reuniões das Testemunhas de Jeová?',
        '2. O que você vai aprender nas nossas reuniões?',
        '3. Por que vai ser bom você conhecer outras pessoas nas reuniões?',
        '4. Como as reuniões são realizadas no Salão do Reino',
        '5. Um ambiente fraterno e acolhedor, sem cobranças ou coletas de dízimo',
        '6. O encorajamento mútuo e a união fraterna para perseverar',
      ],
      somePeopleSay: 'Não é preciso se reunir com outros para adorar a Deus com sinceridade.',
      summary: 'Nas reuniões aprendemos sobre a Bíblia, louvamos a Deus e recebemos encorajamento de pessoas que amam a Jeová.',
      reviewQuestions: [
        'O que acontece nas reuniões realizadas no Salão do Reino?',
        'Como as reuniões ajudam você no dia a dia?',
        'Por que o ambiente do Salão do Reino é diferente?',
      ],
      tryThis: 'Assista a uma reunião no Salão do Reino presencialmente ou por videoconferência.',
    ),
    LffLessonInfo(
      number: 11,
      title: 'Como você pode aproveitar ao máximo a leitura da Bíblia?',
      section: 1,
      pointTitles: [
        '1. Por que é importante ler a Bíblia regularmente?',
        '2. Como você pode aproveitar ao máximo sua leitura da Bíblia?',
        '3. Como você pode encontrar tempo para ler a Bíblia?',
        '4. A importância de meditar no que você lê e aplicar na prática',
        '5. Ferramentas de pesquisa bíblica e recursos visuais úteis',
        '6. Como transformar a leitura da Bíblia em um momento prazeroso',
      ],
      somePeopleSay: 'A Bíblia é um livro antigo e difícil demais para as pessoas comuns entenderem.',
      summary: 'Ler a Bíblia todos os dias, meditar no seu conteúdo e aplicar seus conselhos traz felicidade verdadeira e sabedoria prática.',
      reviewQuestions: [
        'Como criar o hábito de ler a Bíblia diariamente?',
        'O que significa meditar na leitura bíblica?',
        'Como ferramentas de pesquisa ajudam a aprofundar seu conhecimento?',
      ],
      tryThis: 'Estabeleça um horário fixo no seu dia para ler alguns capítulos da Bíblia.',
    ),
    LffLessonInfo(
      number: 12,
      title: 'O que vai ajudar você a continuar estudando a Bíblia?',
      section: 1,
      pointTitles: [
        '1. Por que estudar a Bíblia é tão importante?',
        '2. Por que é importante dar valor ao que a Bíblia ensina?',
        '3. Como Jeová pode ajudar você a continuar seu estudo?',
        '4. Como superar a falta de tempo e o cansaço da rotina',
        '5. Como manter a calma diante de críticas ou oposição de amigos e familiares',
        '6. A certeza de que o estudo bíblico trará bênçãos eternas',
      ],
      somePeopleSay: 'Estudar a Bíblia toma muito tempo e não traz benefícios práticos para a vida moderna.',
      summary: 'Estudar a Bíblia é o melhor investimento que você pode fazer. Com a ajuda de Jeová, você vencerá qualquer desafio ou obstáculo.',
      reviewQuestions: [
        'Por que vale a pena perseverar no estudo da Bíblia?',
        'Como você pode lidar com oposição de pessoas próximas?',
        'Como Jeová promete ajudar os que buscam a verdade?',
      ],
      tryThis: 'Trate o horário do seu estudo bíblico semanal como um compromisso sagrado.',
    ),
    // === Parte 2: Conheça a Jeová, a Jesus e o propósito deles (Lições 13 a 33) ===
    LffLessonInfo(
      number: 13,
      title: 'Como as religiões falsas afastam as pessoas de Deus?',
      section: 2,
      pointTitles: [
        '1. O que a religião falsa ensina sobre Deus?',
        '2. O que a religião falsa faz e que frutos produz?',
        '3. Jeová vai acabar com a religião falsa',
        '4. O envolvimento da religião em guerras e disputas políticas',
        '5. A exploração financeira e o comércio das coisas sagradas',
        '6. O convite amoroso de Deus para sair da religião falsa sem demora',
      ],
      somePeopleSay: 'Todas as religiões são caminhos diferentes que levam ao mesmo Deus.',
      summary: 'A religião falsa desonra a Deus com ensinos mentirosos e conduta hipócrita. Deus vai eliminá-la para libertar as pessoas sinceras.',
      reviewQuestions: [
        'Que mentiras sobre Deus a religião falsa costuma ensinar?',
        'Como as ações da religião falsa contradizem os mandamentos de Jesus?',
        'O que a Bíblia aconselha você a fazer em relação à religião falsa?',
      ],
      tryThis: 'Pesquise o que a Bíblia diz em Apocalipse 18:4 sobre sair de \'Babilônia, a Grande\'.',
    ),
    LffLessonInfo(
      number: 14,
      title: 'O que temos que fazer para Deus aceitar nossa adoração?',
      section: 2,
      pointTitles: [
        '1. Será que todas as formas de adoração agradam a Deus?',
        '2. O que a Bíblia diz sobre o uso de imagens na adoração?',
        '3. Apenas a adoração baseada na verdade da Bíblia agrada a Deus',
        '4. Como a adoração verdadeira nos ajuda hoje',
        '5. Adorar a Deus \'com espírito e verdade\'',
        '6. A alegria de adorar a Jeová em união com outros cristãos verdadeiros',
      ],
      somePeopleSay: 'Usar imagens, santos ou ídolos nos ajuda a nos aproximar mais de Deus.',
      summary: 'Para agradar a Deus, nossa adoração deve ser pura, sem ídolos ou imagens, baseada exclusivamente nas verdades da Palavra de Deus.',
      reviewQuestions: [
        'Qual é o ponto de vista bíblico sobre venerar imagens religiosas?',
        'O que significa adorar a Deus \'com espírito e verdade\'?',
        'Que bênçãos recebemos quando nossa adoração agrada a Deus?',
      ],
      tryThis: 'Livre-se de qualquer objeto religioso ou imagem que desrespeite a lei de Deus.',
    ),
    LffLessonInfo(
      number: 15,
      title: 'Quem é Jesus?',
      section: 2,
      pointTitles: [
        '1. A vida de Jesus antes de vir à Terra',
        '2. Quem é o Messias prometido nas Escrituras?',
        '3. Jesus é o Filho de Deus, não o Deus Todo-Poderoso',
        '4. O papel de Jesus como o primogênito de toda a criação',
        '5. Por que Jesus foi chamado de \'o Verbo\' ou \'a Palavra\'',
        '6. Como seguir o exemplo perfeito e a liderança de Jesus Cristo',
      ],
      somePeopleSay: 'Jesus é o próprio Deus Todo-Poderoso, parte de uma Trindade.',
      summary: 'Jesus é o Filho primogênito de Jeová, o Messias enviado à Terra para ensinar a verdade e dar a vida pela humanidade.',
      reviewQuestions: [
        'Onde Jesus estava antes de nascer como humano na Terra?',
        'O que a Bíblia diz sobre o relacionamento entre Jesus e Jeová?',
        'Por que Jesus é a pessoa mais importante depois de Deus?',
      ],
      tryThis: 'Leia os primeiros capítulos do Evangelho de Mateus ou Lucas para conhecer Jesus.',
    ),
    LffLessonInfo(
      number: 16,
      title: 'O que Jesus fez quando esteve na Terra?',
      section: 2,
      pointTitles: [
        '1. Jesus deu o exemplo perfeito em sua conduta',
        '2. Os milagres de Jesus mostraram o que ele fará no futuro',
        '3. O que a morte sacrificial de Jesus realizou',
        '4. O tema central da pregação de Jesus: o Reino de Deus',
        '5. A compaixão de Jesus pelos pobres, doentes e rejeitados',
        '6. A integridade inabalável de Jesus até a morte na estaca',
      ],
      somePeopleSay: 'Jesus veio à Terra apenas para ser um grande mestre moral e filósofo.',
      summary: 'Jesus pregou as boas novas do Reino, curou multidões como amostra do futuro Paraíso e deu a sua vida perfeita em resgate por nós.',
      reviewQuestions: [
        'Qual era a mensagem principal que Jesus pregava?',
        'O que os milagres de Jesus comprovam sobre o poder do Reino de Deus?',
        'Por que a morte de Jesus foi necessária?',
      ],
      tryThis: 'Medite em como os milagres de Jesus mostram o alívio que o Reino trará em breve.',
    ),
    LffLessonInfo(
      number: 17,
      title: 'Que tipo de pessoa é Jesus?',
      section: 2,
      pointTitles: [
        '1. Em que sentido Jesus é a imagem exata de seu Pai, Jeová?',
        '2. Como Jesus tratava todas as pessoas com respeito e carinho?',
        '3. Como você pode imitar as qualidades de Jesus no dia a dia?',
        '4. A profunda humildade, mansidão e paciência de Cristo',
        '5. A coragem inabalável de Jesus em defender a verdade e a justiça',
        '6. O amor altruísta que levou Jesus a dar sua vida pelos outros',
      ],
      somePeopleSay: 'Jesus era severo, distante e inacessível às pessoas comuns.',
      summary: 'Jesus é amoroso, acolhedor, humilde e corajoso. Ao conhecermos a personalidade de Jesus, passamos a conhecer melhor a Jeová.',
      reviewQuestions: [
        'Por que as pessoas, incluindo crianças, se sentiam tão à vontade com Jesus?',
        'Como Jesus demonstrou verdadeira humildade com seus discípulos?',
        'De que maneiras você pode agir como Jesus na sua rotina?',
      ],
      tryThis: 'Pratique um ato de bondade despretensioso esta semana, imitando a Jesus.',
    ),
    LffLessonInfo(
      number: 18,
      title: 'Como saber quem são os cristãos verdadeiros?',
      section: 2,
      pointTitles: [
        '1. O que é um cristão segundo os ensinamentos da Bíblia?',
        '2. Os cristãos verdadeiros seguem fielmente a Palavra de Deus',
        '3. Os cristãos verdadeiros mostram amor autêntico uns pelos outros',
        '4. Eles não fazem parte do mundo nem se envolvem na política',
        '5. Eles pregam ativamente as boas novas do Reino de Deus',
        '6. Eles santificam e divulgam o nome de Deus perante o mundo',
      ],
      somePeopleSay: 'Qualquer pessoa que aceite Jesus no coração é automaticamente um cristão verdadeiro.',
      summary: 'Os cristãos verdadeiros são identificados por seu amor altruísta sem divisões, por basearem suas crenças na Bíblia e por pregarem o Reino.',
      reviewQuestions: [
        'Que sinal indispensável Jesus deu para reconhecer seus discípulos?',
        'Qual é a atitude dos cristãos verdadeiros em relação à política e às guerras?',
        'Como os verdadeiros cristãos tratam o nome de Deus?',
      ],
      tryThis: 'Compare as características bíblicas dos cristãos com o que você vê no mundo religioso.',
    ),
    LffLessonInfo(
      number: 19,
      title: 'Será que as Testemunhas de Jeová são cristãos de verdade?',
      section: 2,
      pointTitles: [
        '1. As Testemunhas de Jeová baseiam todas as suas crenças na Bíblia',
        '2. Por que adotamos e divulgamos com zelo o nome Testemunhas de Jeová?',
        '3. Como as Testemunhas de Jeová imitam o amor fraternal de Cristo?',
        '4. A história moderna e o resgate das verdades bíblicas originais',
        '5. Uma irmandade mundial unida sem preconceitos de raça ou nacionalidade',
        '6. Ação voluntária e amor na prática em momentos de crise e calamidade',
      ],
      somePeopleSay: 'As Testemunhas de Jeová são uma seita perigosa que segue ensinamentos de homens.',
      summary: 'As Testemunhas de Jeová baseiam todas as suas doutrinas na Bíblia, levam com honra o nome de Deus e formam uma família mundial unida pelo amor.',
      reviewQuestions: [
        'De onde vêm todas as crenças das Testemunhas de Jeová?',
        'Por que o nome bíblico de Jeová é tão valorizado por nós?',
        'Como a nossa união mundial comprova o poder do amor cristão?',
      ],
      tryThis: 'Acesse o site jw.org e explore a seção \'Quem Somos\' para conhecer nossa história.',
    ),
    LffLessonInfo(
      number: 20,
      title: 'Como a congregação está organizada?',
      section: 2,
      pointTitles: [
        '1. Quem é o único Líder e Cabeça da congregação cristã?',
        '2. Quem são os anciãos e qual é o seu papel amoroso de pastoreio?',
        '3. Quem são os servos ministeriais e como eles apoiam a congregação?',
        '4. Como a congregação se mantém por meio de donativos voluntários',
        '5. Como o Corpo Governante orienta as congregações no mundo inteiro',
        '6. A ordem, a paz e o espírito fraterno nos arranjos da congregação',
      ],
      somePeopleSay: 'A congregação cristã tem clérigos assalariados com títulos honoríficos sobre o povo.',
      summary: 'Jesus lidera a congregação através do espírito santo. Os anciãos e servos ministeriais trabalham voluntariamente como servos humildes do rebanho.',
      reviewQuestions: [
        'Quem lidera a congregação cristã?',
        'Como os anciãos cuidam das necessidades espirituais dos publicadores?',
        'Por que as reuniões e a obra não exigem dízimos ou coletas obrigatórias?',
      ],
      tryThis: 'Converse com um dos anciãos da congregação e agradeça pelo seu serviço amoroso.',
    ),
    LffLessonInfo(
      number: 21,
      title: 'Como as boas novas são pregadas?',
      section: 2,
      pointTitles: [
        '1. Que ordem direta e urgente Jesus deu a todos os seus seguidores?',
        '2. Como a pregação de casa em casa é realizada no mundo moderno',
        '3. Por que o trabalho de pregação é tão urgente nos dias atuais?',
        '4. Outras modalidades: pregação em locais públicos, no comércio e informal',
        '5. O uso de traduções bíblicas, publicações e mídias eletrônicas',
        '6. O grandioso privilégio de sermos cooperadores de Jeová no campo',
      ],
      somePeopleSay: 'A pregação cristã deve ficar restrita aos templos e não incomodar as pessoas.',
      summary: 'Jesus profetizou que as boas novas do Reino seriam pregadas no mundo inteiro. Cumprimos essa profecia alcançando as pessoas onde quer que estejam.',
      reviewQuestions: [
        'Por que pregamos de casa em casa como faziam os primeiros cristãos?',
        'O que torna a mensagem das boas novas uma mensagem salvadora?',
        'Como você se beneficia da obra de pregação mundial?',
      ],
      tryThis: 'Acompanhe uma saída de campo com as Testemunhas de Jeová para observar a pregação.',
    ),
    LffLessonInfo(
      number: 22,
      title: 'Como você pode falar das boas novas para outros?',
      section: 2,
      pointTitles: [
        '1. Como começar a conversar sobre a Bíblia com familiares e amigos?',
        '2. Como vencer o medo, a timidez e o receio de ser rejeitado?',
        '3. Por que vale a pena partilhar a esperança bíblica com o próximo?',
        '4. Compartilhar as boas novas com tato, respeito, empatia e amor',
        '5. O que responder com mansidão quando outros discordarem de você',
        '6. Os passos para se qualificar como publicador não batizado',
      ],
      somePeopleSay: 'Apenas pessoas formadas em teologia têm autorização para falar sobre a Bíblia.',
      summary: 'Falar da Bíblia a amigos e familiares é natural quando amamos a verdade. Jeová dá coragem e serenidade para testemunharmos com sabedoria.',
      reviewQuestions: [
        'Com quem você gostaria de conversar sobre o que está aprendendo?',
        'Como a oração pode ajudar você a superar o medo da pregação?',
        'O que é um publicador não batizado das boas novas?',
      ],
      tryThis: 'Pense em alguém querido e compartilhe um texto bíblico encorajador esta semana.',
    ),
    LffLessonInfo(
      number: 23,
      title: 'Batismo — Um alvo que vale a pena ter!',
      section: 2,
      pointTitles: [
        '1. O que o batismo cristão em água realmente significa?',
        '2. O que a pessoa precisa fazer antes de tomar a decisão do batismo?',
        '3. Por que o batismo é um passo indispensável e abençoado?',
        '4. A dedicação pessoal a Jeová feita de coração em oração particular',
        '5. O exemplo do batismo de Jesus no rio Jordão por imersão completa',
        '6. O início de uma vida plena com a perspectiva de servir a Deus para sempre',
      ],
      somePeopleSay: 'O batismo pode ser feito aspergindo água em bebês sem consentimento ou fé.',
      summary: 'O batismo bíblico é por imersão total em água de pessoas que já aprenderam a verdade, têm fé sólida e dedicaram sua vida a Jeová.',
      reviewQuestions: [
        'Qual é a diferença entre dedicação e batismo?',
        'Por que o batismo em água deve ser realizado por imersão completa?',
        'Que bênçãos resultam de se dedicar e ser batizado?',
      ],
      tryThis: 'Ore a Jeová agradecendo pelo privilégio de poder conhecê-lo e ter o alvo do batismo.',
    ),
    LffLessonInfo(
      number: 24,
      title: 'Quem são os anjos e o que eles fazem?',
      section: 2,
      pointTitles: [
        '1. Quem são os anjos e quando eles foram criados por Deus?',
        '2. Qual é o papel maravilhoso dos santos anjos na Terra hoje?',
        '3. Quem são os demônios e como começou a sua rebelião contra Deus?',
        '4. Como os anjos fiéis apoiam e guiam invisivelmente a obra de pregação',
        '5. As artimanhas perigosas do espiritismo, adivinhação e ocultismo',
        '6. Como obter a proteção invencível de Jeová contra as forças espirituais más',
      ],
      somePeopleSay: 'Pessoas boas se transformam em anjos no céu depois que morrem.',
      summary: 'Os anjos foram criados por Deus muito antes da Terra. Os anjos fiéis apoiam o povo de Deus, enquanto os demônios tentam desviar a humanidade.',
      reviewQuestions: [
        'Como os anjos cooperam na pregação das boas novas?',
        'Por que devemos rejeitar qualquer contato com o espiritismo?',
        'Como Jeová protege os seus servos leais dos espíritos maus?',
      ],
      tryThis: 'Livre-se de amuletos, livros ou objetos associados ao ocultismo ou espiritismo.',
    ),
    LffLessonInfo(
      number: 25,
      title: 'Qual é o objetivo de Deus para nós?',
      section: 2,
      pointTitles: [
        '1. Que vida maravilhosa Jeová planejou para os seres humanos na Terra?',
        '2. O que aconteceu no jardim do Éden que interrompeu essa bênção?',
        '3. Por que temos absoluta certeza de que o propósito de Deus não mudou?',
        '4. A promessa sagrada da transformação de toda a Terra em um paraíso',
        '5. A oportunidade de viver para sempre com saúde perfeita e felicidade real',
        '6. Como ter uma vida significativa e alegre mesmo diante do mundo atual',
      ],
      somePeopleSay: 'Deus criou a Terra apenas como um teste temporário para depois levar as pessoas ao céu.',
      summary: 'Jeová criou a Terra para ser o lar eterno e perfeito da humanidade. O plano de Deus jamais falha e em breve se cumprirá plenamente.',
      reviewQuestions: [
        'Qual era o propósito original de Deus para o homem no Éden?',
        'O que nos dá a certeza de que a Terra se tornará um paraíso?',
        'Como a esperança do propósito divino dá sentido à sua vida hoje?',
      ],
      tryThis: 'Leia o Salmo 37:11, 29 e imagine como será a vida no novo mundo de Deus.',
    ),
    LffLessonInfo(
      number: 26,
      title: 'Por que a maldade e o sofrimento existem?',
      section: 2,
      pointTitles: [
        '1. Será que Deus é o causador do sofrimento humano?',
        '2. O que a rebelião de Satanás no jardim do Éden causou à humanidade?',
        '3. Por que Jeová tem permitido a maldade e o sofrimento até agora?',
        '4. A grande questão moral sobre o direito soberano de Deus governar',
        '5. A prova de que os governos humanos são incapazes de resolver os problemas',
        '6. O consolo inabalável de saber que Jeová vai desfazer todo o sofrimento',
      ],
      somePeopleSay: 'Deus é o responsável por todas as tragédias para nos ensinar lições difíceis.',
      summary: 'Deus jamais causa o sofrimento. Satanás e as más escolhas humanas trouxeram a dor ao mundo, mas Jeová em breve eliminará todo sofrimento.',
      reviewQuestions: [
        'Quem é o verdadeiro governante perverso deste mundo atual?',
        'Por que Deus permitiu tanto tempo para resolver a questão da soberania?',
        'Como Jeová vai compensar toda a tristeza e dor do passado?',
      ],
      tryThis: 'Quando passar por uma provação, lembre-se de que Jeová nunca é a causa do seu sofrimento.',
    ),
    LffLessonInfo(
      number: 27,
      title: 'Como a morte de Jesus pode nos salvar?',
      section: 2,
      pointTitles: [
        '1. Por que os seres humanos envelhecem, adoecem e morrem?',
        '2. O resgate — o maior presente de amor imerecido de Deus',
        '3. O que a morte de Jesus realizou em benefício da humanidade',
        '4. O sacrifício perfeito de Jesus correspondente ao que Adão perdeu',
        '5. A libertação definitiva da condenação do pecado herdado',
        '6. A perspectiva real e garantida da vida eterna graças ao resgate',
      ],
      somePeopleSay: 'A morte de Jesus foi um acidente trágico ou uma derrota perante os líderes romanos.',
      summary: 'A morte sacrificial de Jesus na estaca pagou o preço do resgate, cancelando a condenação do pecado herdado de Adão e garantindo a vida eterna.',
      reviewQuestions: [
        'Por que todos os descendentes de Adão nascem imperfeitos e morrem?',
        'O que significa a palavra bíblica \'resgate\'?',
        'Como o resgate demonstra o imenso amor de Deus e de Jesus por você?',
      ],
      tryThis: 'Agradeça a Jeová em oração pelo presente inestimável do sacrifício de Jesus.',
    ),
    LffLessonInfo(
      number: 28,
      title: 'Como mostrar gratidão pelo que Jeová e Jesus fizeram por você',
      section: 2,
      pointTitles: [
        '1. De que maneiras práticas podemos expressar verdadeira gratidão?',
        '2. A importância sagrada da Refeição Noturna do Senhor (Celebração)',
        '3. O que o pão não fermentado e o vinho representam na Celebração',
        '4. Viver em harmonia com a fé na mensagem redentora de Jesus Cristo',
        '5. A presença indispensável todos os anos na Celebração da Morte de Cristo',
        '6. Dedicar tempo, energia e talentos a serviço do Reino de Deus',
      ],
      somePeopleSay: 'Basta ter fé interior silenciosa, não sendo necessária nenhuma ação ou presença comemorativa.',
      summary: 'Demonstramos gratidão pelo resgate obedecendo aos ensinamentos de Jesus, divulgando as boas novas e assistindo à Celebração da Morte de Cristo.',
      reviewQuestions: [
        'Qual foi a única cerimônia que Jesus ordenou expressamente aos seus seguidores?',
        'O que os emblemas da Celebração (pão e vinho) simbolizam?',
        'Como a sua vida diária pode expressar apreço pelo resgate?',
      ],
      tryThis: 'Marque no calendário a data da próxima Celebração da Morte de Cristo e convide amigos.',
    ),
    LffLessonInfo(
      number: 29,
      title: 'O que acontece quando a pessoa morre?',
      section: 2,
      pointTitles: [
        '1. Para onde vai uma pessoa quando a vida dela chega ao fim?',
        '2. A Bíblia compara a morte a um estado de sono profundo e inconsciente',
        '3. A verdade libertadora sobre a morte nos liberta de rituais e medos infundados',
        '4. A prova bíblica irrefutável de que a alma morre e não sobrevive ao corpo',
        '5. Por que a mentira do inferno de fogo é uma blasfêmia contra o amor de Deus',
        '6. A paz mental de saber que os mortos não sofrem nem podem nos prejudicar',
      ],
      somePeopleSay: 'A pessoa possui uma alma imortal que vai para o céu, para o purgatório ou para o inferno.',
      summary: 'Os mortos estão totalmente inconscientes e não sentem dor nem sofrimento. A esperança real para eles é a ressurreição no Paraíso.',
      reviewQuestions: [
        'Qual é a condição dos mortos de acordo com Eclesiastes 9:5, 10?',
        'Por que a doutrina do tormento eterno difama o caráter de Deus?',
        'Como a verdade sobre a morte traz consolo e alívio emocional?',
      ],
      tryThis: 'Leia o relato bíblico sobre a morte e o sono de Lázaro em João 11:11-14.',
    ),
    LffLessonInfo(
      number: 30,
      title: 'As pessoas que você ama podem voltar a viver!',
      section: 2,
      pointTitles: [
        '1. O que Jeová sente sobre a perspectiva de ressuscitar os mortos?',
        '2. Quem será ressuscitado para a vida e onde eles viverão?',
        '3. Como a esperança da ressurreição consola e dá forças nos momentos de luto',
        '4. As ressurreições do passado registradas na Bíblia como prova real',
        '5. O reencontro alegre e emocionante de famílias no novo mundo',
        '6. A vitória gloriosa sobre o último inimigo da humanidade: a morte',
      ],
      somePeopleSay: 'Quem morreu jamais voltará a viver, a morte é o fim definitivo de tudo.',
      summary: 'Jeová tem grande saudade dos que adormeceram na morte e vai ressuscitá-los por meio de Jesus para viverem eternamente na Terra paradisíaca.',
      reviewQuestions: [
        'Que sentimentos Jeová nutre em relação aos que já faleceram?',
        'Quem voltará na \'ressurreição tanto de justos como de injustos\'?',
        'Como a promessa da ressurreição alivia a dor da perda de um ente querido?',
      ],
      tryThis: 'Pense nas pessoas que você quer rever no Paraíso e imagine esse reencontro.',
    ),
    LffLessonInfo(
      number: 31,
      title: 'O que é o Reino de Deus?',
      section: 2,
      pointTitles: [
        '1. O que é o Reino de Deus mencionado na oração do Pai-Nosso?',
        '2. Quem é o Rei coroado desse Reino e onde fica sua sede de governo?',
        '3. Quem vai governar no céu ao lado do Senhor Jesus Cristo?',
        '4. Por que o Reino celestial é infinitamente superior aos governos humanos',
        '5. O número bíblico de 144 mil governantes comprados da Terra',
        '6. As bênçãos magníficas e a justiça que os súditos terrestres usufruirão',
      ],
      somePeopleSay: 'O Reino de Deus é apenas um sentimento bom de paz no coração de cada pessoa.',
      summary: 'O Reino de Deus é um governo real no céu chefiado por Jesus e 144 mil co-governantes. Ele substituirá todos os governos terrestres corruptos.',
      reviewQuestions: [
        'O que pedimos a Deus quando oramos \'venha o teu Reino\'?',
        'Quem governa com Cristo no céu e que privilégio eles receberam?',
        'Por que podemos confiar plenamente na justiça do governo do Reino?',
      ],
      tryThis: 'Pesquise o que a profecia de Daniel 2:44 diz sobre o futuro de todos os reinos humanos.',
    ),
    LffLessonInfo(
      number: 32,
      title: 'O Reino de Deus já está governando!',
      section: 2,
      pointTitles: [
        '1. O que a cronologia bíblica profética indica sobre o marcante ano de 1914?',
        '2. O que tem acontecido na Terra desde o início do governo celestial?',
        '3. O que a atuação vitoriosa do Reino de Deus significa para você hoje?',
        '4. A profecia dos \'sete tempos\' no livro de Daniel cumprida com exatidão',
        '5. A expulsão humilhante de Satanás do céu para a vizinhança da Terra',
        '6. Os sinais claros dos últimos dias comprovando que o fim deste sistema está próximo',
      ],
      somePeopleSay: 'O Reino de Deus ainda não começou a reinar em lugar nenhum.',
      summary: 'Jesus foi coroado Rei no céu em 1914. A expulsão de Satanás e o cumprimento do sinal dos últimos dias provam que o Reino já governa.',
      reviewQuestions: [
        'O que aconteceu nos céus no ano de 1914?',
        'Por que as condições da Terra pioraram tanto desde o início do século 20?',
        'Que atitude devemos tomar ao ver os sinais dos últimos dias se cumprindo?',
      ],
      tryThis: 'Examine Mateus 24 e veja como os acontecimentos atuais cumprem as palavras de Jesus.',
    ),
    LffLessonInfo(
      number: 33,
      title: 'O que o Reino de Deus vai fazer?',
      section: 2,
      pointTitles: [
        '1. Como o Reino de Deus vai acabar com a maldade e a opressão?',
        '2. Como o Reino de Deus vai satisfazer plenamente todas as nossas necessidades?',
        '3. O que o Reino de Deus vai realizar ao longo de todo o futuro?',
        '4. A batalha do Armagedom: a guerra justa de Deus para limpar a Terra',
        '5. Saúde perfeita, moradia digna, fartura de alimento e segurança absoluta',
        '6. O glorioso Reinado de Mil Anos restaurando a perfeição e o Éden global',
      ],
      somePeopleSay: 'O Armagedom é o fim do planeta Terra e a aniquilação cósmica do Universo.',
      summary: 'O Reino de Deus eliminará toda a maldade no Armagedom, preservará a Terra e os justos, e restaurará a saúde e a vida eterna para sempre.',
      reviewQuestions: [
        'O que acontecerá com as pessoas más e os governos no Armagedom?',
        'Que bênçãos materiais e espirituais o Reino trará para a Terra?',
        'Como você se imagina vivendo sob o governo pacífico do Reino de Deus?',
      ],
      tryThis: 'Leia Apocalipse 21:3, 4 e reflita sobre o fim definitivo das lágrimas e do sofrimento.',
    ),
    // === Parte 3: Viva de um modo que agrade a Deus (Lições 34 a 47) ===
    LffLessonInfo(
      number: 34,
      title: 'Como podemos mostrar nosso amor por Jeová?',
      section: 3,
      pointTitles: [
        '1. Como podemos demonstrar de coração que amamos a Jeová?',
        '2. Como a nossa obediência afeta os sentimentos de Jeová?',
        '3. Uma questão fundamental que tem tudo a ver com você pessoalmente',
        '4. O desafio levantado por Satanás a respeito da lealdade humana no caso de Jó',
        '5. As leis e conselhos divinos foram criados exclusivamente para a nossa proteção',
        '6. A alegria incomparável de honrar a Deus e fazer o coração dele se alegrar',
      ],
      somePeopleSay: 'Deus não se importa com as nossas atitudes diárias, desde que não façamos grandes maldades.',
      summary: 'Mostramos amor genuíno por Jeová quando guardamos os seus mandamentos e provamos, por nossa lealdade diária, que Satanás é um mentiroso.',
      reviewQuestions: [
        'Por que a obediência voluntária é a maior prova de amor que podemos dar a Deus?',
        'Que acusação Satanás fez contra Jó e contra cada um de nós?',
        'Como as leis de Jeová nos protegem dos perigos do mundo?',
      ],
      tryThis: 'Leia Provérbios 27:11 e pense em como as suas decisões de hoje podem alegrar a Jeová.',
    ),
    LffLessonInfo(
      number: 35,
      title: 'Como podemos tomar boas decisões?',
      section: 3,
      pointTitles: [
        '1. Procure saber com antecedência todos os fatos relevantes',
        '2. Leve sempre em consideração primordial o que Jeová pensa',
        '3. Analise cuidadosamente as opções e suas consequências futuras',
        '4. Tome uma boa decisão com base na oração e em princípios bíblicos',
        '5. A distinção prática entre leis expressas e princípios bíblicos flexíveis',
        '6. Como treinar e educar a consciência pessoal pela Palavra inspirada',
      ],
      somePeopleSay: 'Podemos decidir qualquer assunto simplesmente seguindo a intuição do coração.',
      summary: 'Tomamos decisões sábias quando pesquisamos a Bíblia, oramos a Jeová e aplicamos princípios divinos que educam a nossa consciência cristã.',
      reviewQuestions: [
        'Qual é a diferença fundamental entre uma lei bíblica e um princípio bíblico?',
        'Como você pode descobrir o que agrada a Jeová em assuntos sem uma lei direta?',
        'Por que é perigoso tomar decisões importantes sem pesquisar os fatos?',
      ],
      tryThis: 'Antes de tomar uma decisão importante nesta semana, ore e consulte textos bíblicos.',
    ),
    LffLessonInfo(
      number: 36,
      title: 'Sempre seja honesto',
      section: 3,
      pointTitles: [
        '1. Por que devemos ser rigorosamente honestos em tudo o que fazemos?',
        '2. Como ser uma pessoa honesta em todas as circunstâncias da vida?',
        '3. Evite as armadilhas e as consequências amargas da desonestidade',
        '4. A honestidade sincera agrada profundamente a Jeová',
        '5. Honestidade no trabalho, nos negócios, nas finanças e nos impostos',
        '6. A tranquilidade e a dignidade de manter uma consciência limpa e limpa reputação',
      ],
      somePeopleSay: 'Pequenas mentiras e desonestidades são normais e necessárias para sobreviver no mundo moderno.',
      summary: 'A honestidade em palavras e ações reflete a santidade de Jeová, protege nossa paz mental e dá excelente testemunho da verdade.',
      reviewQuestions: [
        'Em que situações do cotidiano a nossa honestidade é colocada à prova?',
        'Por que Jeová abomina a mentira, a trapaça e a fraude?',
        'Que benefícios reais a pessoa honesta desfruta na família e na sociedade?',
      ],
      tryThis: 'Seja transparente e pontual em todos os seus compromissos e declarações esta semana.',
    ),
    LffLessonInfo(
      number: 37,
      title: 'O que a Bíblia diz sobre trabalho e dinheiro?',
      section: 3,
      pointTitles: [
        '1. Tenha um ponto de vista equilibrado, digno e responsável sobre o trabalho',
        '2. Tenha um ponto de vista equilibrado sobre o dinheiro e os bens materiais',
        '3. Como evitar a ansiedade excessiva e o estresse sobre o sustento diário',
        '4. O valor e a paz mental de viver satisfeito com o sustento e o abrigo',
        '5. A armadilha perigosa do materialismo e a corrida desenfreada por riquezas',
        '6. A promessa fiel de que Deus jamais desamparará os que buscam primeiro o Reino',
      ],
      somePeopleSay: 'O sucesso de uma pessoa é medido unicamente pela quantidade de dinheiro e posses que acumula.',
      summary: 'O trabalho diligente é recompensador, mas o amor ao dinheiro corrompe o coração. O contentamento com o necessário traz liberdade e alegria.',
      reviewQuestions: [
        'Qual é a atitude equilibrada que o cristão deve manter em relação ao emprego?',
        'Por que o amor ao dinheiro é chamado na Bíblia de raiz de todo tipo de males?',
        'Como a promessa de Jesus em Mateus 6:33 elimina as preocupações exageradas?',
      ],
      tryThis: 'Avalie seus hábitos de consumo e veja onde você pode simplificar sua rotina financeira.',
    ),
    LffLessonInfo(
      number: 38,
      title: 'Dê valor ao presente da vida',
      section: 3,
      pointTitles: [
        '1. Por que a vida é um presente sagrado e incomparável de Jeová?',
        '2. O que Jeová pensa sobre tirar a própria vida ou o suicídio?',
        '3. O que a Bíblia revela sobre a sacralidade da vida de um bebê no ventre (aborto)',
        '4. Como cuidar bem da saúde e da segurança demonstra apreço pela vida',
        '5. Rejeitar qualquer forma de violência, crueldade, ódio e esportes arriscados',
        '6. A responsabilidade de proteger a vida e a integridade de terceiros',
      ],
      somePeopleSay: 'O corpo é meu e eu tenho o direito absoluto de fazer com a minha vida o que bem entender.',
      summary: 'A vida pertence a Jeová, o Criador. Devemos valorizá-la cuidando da saúde, evitando a violência e protegendo os vulneráveis e os nascituros.',
      reviewQuestions: [
        'Por que o respeito à vida nos impede de apoiar o aborto ou a violência?',
        'Como a manutenção da segurança em casa e no trabalho honra o Criador?',
        'De que maneiras práticas podemos demonstrar apreço pelo dom da vida?',
      ],
      tryThis: 'Faça uma checagem de segurança em sua residência ou veículo para evitar acidentes.',
    ),
    LffLessonInfo(
      number: 39,
      title: 'O ponto de vista de Deus sobre o sangue',
      section: 3,
      pointTitles: [
        '1. Por que o sangue é considerado sagrado e exclusivo aos olhos de Jeová?',
        '2. O que a lei divina dada a Noé e reiterada aos cristãos envolve?',
        '3. Como encarar tratamentos médicos modernos e cirurgias sem sangue',
        '4. Decisões de consciência pessoal envolvendo frações de sangue e técnicas médicas',
        '5. A ordem expressa de \'abster-se de sangue\' em Atos 15:28, 29',
        '6. A excelência e segurança dos tratamentos alternativos à transfusão alogênica',
      ],
      somePeopleSay: 'A proibição bíblica do sangue se referia apenas a comer sangue no passado, não à medicina.',
      summary: 'O sangue representa a própria vida aos olhos de Deus. Os cristãos respeitam a ordem de se abster de sangue na alimentação e na medicina.',
      reviewQuestions: [
        'O que o sangue representa nas Escrituras Sagradas?',
        'Por que a ordem de \'abster-se de sangue\' se aplica a transfusões médicas?',
        'Que excelentes tratamentos sem sangue estão disponíveis hoje para os pacientes?',
      ],
      tryThis: 'Preencha ou revise sua Diretiva Médica Antecipada sobre tratamentos de saúde.',
    ),
    LffLessonInfo(
      number: 40,
      title: 'Como podemos ser limpos aos olhos de Deus?',
      section: 3,
      pointTitles: [
        '1. Como podemos cultivar a limpeza em sentido físico e na nossa apresentação?',
        '2. Que hábitos prejudiciais poderiam nos tornar impuros e desonrar a Deus?',
        '3. A limpeza moral: a luta vitoriosa contra pensamentos e desejos impuros',
        '4. A limpeza espiritual: afastar-se totalmente de práticas e costumes religiosos falsos',
        '5. Manter a dignidade, o asseio e a ordem no lar e no Salão do Reino',
        '6. Como vencer vícios como o fumo, as drogas e o álcool com o poder de Deus',
      ],
      somePeopleSay: 'Deus só se preocupa com a espiritualidade interior, o aspecto físico e os hábitos não importam.',
      summary: 'Jeová é santo e nos ensina que a limpeza física, mental, moral e espiritual é necessária para refletir a sua pureza e dignidade.',
      reviewQuestions: [
        'Por que a santidade de Jeová exige que o seu povo seja limpo em todos os sentidos?',
        'Que substâncias e práticas impuras o cristão deve rejeitar de pronto?',
        'Como podemos manter nossos pensamentos puros num mundo imoral?',
      ],
      tryThis: 'Se estiver lutando contra um hábito impuro, ore fervorosamente a Jeová pedindo forças.',
    ),
    LffLessonInfo(
      number: 41,
      title: 'O que a Bíblia diz sobre sexo?',
      section: 3,
      pointTitles: [
        '1. Qual é o ponto de vista amoroso de Jeová ao criar a intimidade sexual?',
        '2. O que a Bíblia classifica com o termo imoralidade sexual (porneía)?',
        '3. Os benefícios incomparáveis de obedecer às normas divinas sobre a moralidade',
        '4. O relacionamento íntimo como bênção exclusiva entre marido e mulher casados',
        '5. Os perigos destrutivos da pornografia e de conversas de cunho sensual',
        '6. Como guardar o coração e fugir das ciladas da imoralidade no dia a dia',
      ],
      somePeopleSay: 'As normas bíblicas sobre sexo são antiquadas e reprimem a liberdade individual.',
      summary: 'O sexo é um presente maravilhoso de Jeová destinado exclusivamente ao casamento. A pureza moral nos protege de dores emocionais e doenças.',
      reviewQuestions: [
        'Para quem Deus reservou com exclusividade o presente da intimidade sexual?',
        'Por que a pornografia e a fornicação são tão prejudiciais ao ser humano?',
        'Como a obediência às normas morais de Deus protege a família e o coração?',
      ],
      tryThis: 'Proteja seus olhos e pensamentos, recusando conteúdos de apelo imoral na internet.',
    ),
    LffLessonInfo(
      number: 42,
      title: 'O que a Bíblia diz sobre se casar e ficar solteiro?',
      section: 3,
      pointTitles: [
        '1. Quais são as excelentes oportunidades e bênçãos de permanecer solteiro?',
        '2. O ponto de vista bíblico e sagrado de Deus sobre a instituição do casamento',
        '3. A importância de escolher com sabedoria e oração a pessoa com quem vai se casar',
        '4. O conselho inspirado de casar-se \'somente no Senhor\' para preservar a fé',
        '5. O casamento como um compromisso sagrado, indissolúvel e para toda a vida',
        '6. Como cultivar um namoro cristão casto, digno e com o objetivo sério do casamento',
      ],
      somePeopleSay: 'O casamento é apenas um contrato social que pode ser desfeito sempre que a paixão esfriar.',
      summary: 'A solteirice e o casamento são dádivas que podem glorificar a Deus. Quem decide se casar deve buscar alguém que ame a Jeová e honrar seu pacto.',
      reviewQuestions: [
        'Como a pessoa solteira pode usar sua liberdade para avançar no ministério?',
        'Por que a Bíblia aconselha a casar-se exclusivamente com outro cristão dedicado?',
        'Qual é a única base bíblica que permite o divórcio e o novo casamento?',
      ],
      tryThis: 'Se for solteiro, use seu tempo para aprofundar sua amizade com Jeová e desenvolver qualidades.',
    ),
    LffLessonInfo(
      number: 43,
      title: 'O que a Bíblia diz sobre as bebidas alcoólicas?',
      section: 3,
      pointTitles: [
        '1. O ponto de vista equilibrado das Escrituras Sagradas sobre o consumo de álcool',
        '2. O que Deus condena expressamente: a embriaguez, a perda de controle e excessos',
        '3. A sabedoria prática e o discernimento para decidir quando é melhor se abster',
        '4. Situações em que o cristão decide prudentemente não ingerir bebidas alcoólicas',
        '5. O cuidado de não tropeçar nem ferir a consciência de outros irmãos',
        '6. A moderação, a temperança e o domínio próprio em qualquer confraternização',
      ],
      somePeopleSay: 'Beber até perder os sentidos é uma diversão inofensiva e aceitável socialmente.',
      summary: 'A Bíblia permite o consumo moderado de álcool para quem tem idade legal, mas proíbe terminantemente a bebedeira e os excessos descontrolados.',
      reviewQuestions: [
        'O que a Bíblia ensina sobre o consumo moderado de bebidas alcoólicas?',
        'Que perigos graves a embriaguez traz para a saúde, a família e a espiritualidade?',
        'Por que é prudente evitar o álcool se isso puder escandalizar a consciência de outros?',
      ],
      tryThis: 'Se você consome bebidas alcoólicas, estabeleça limites claros para nunca exagerar.',
    ),
    LffLessonInfo(
      number: 44,
      title: 'Será que todos os feriados agradam a Deus?',
      section: 3,
      pointTitles: [
        '1. A origem histórica e pagã de muitas celebrações e festividades populares',
        '2. O que realmente agrada a Jeová em matéria de adoração e costumes',
        '3. Como tomar decisões conscientes e explicar suas posições a outros com respeito',
        '4. Feriados ligados ao espiritismo, idolatria, culto aos mortos ou nacionalismo',
        '5. A verdadeira alegria de dar presentes e festejar em família em qualquer ocasião',
        '6. Como manter a paz e o respeito no lar quando familiares comemoram datas mundanas',
      ],
      somePeopleSay: 'Não tem problema participar de qualquer feriado, contanto que nossa intenção seja boa.',
      summary: 'Deus rejeita celebrações que tenham raízes na religião falsa, superstição ou exaltação nacional. Devemos agradar a Deus em toda a nossa conduta.',
      reviewQuestions: [
        'Como você pode descobrir se uma festa ou feriado agrada ou desagrada a Deus?',
        'Por que comemorações como o Natal, a Páscoa ou o Ano Novo desonram a verdade bíblica?',
        'Como explicar a familiares por que você não comemora certas datas sem ser rude?',
      ],
      tryThis: 'Pesquise a origem de uma festividade popular e veja como os fatos se comparam com a Bíblia.',
    ),
    LffLessonInfo(
      number: 45,
      title: 'O que significa ser neutro?',
      section: 3,
      pointTitles: [
        '1. O exemplo supremo de Jesus Cristo sobre a neutralidade diante do mundo',
        '2. A postura respeitosa e submissa perante os governos e autoridades superiores',
        '3. A regra inegociável: \'Temos de obedecer a Deus como governante em vez de a homens\'',
        '4. Manter-se totalmente separado de divisões partidárias, eleições e guerras',
        '5. Pagar honestamente os impostos e prestar a honra devida às autoridades cívicas',
        '6. A lealdade incondicional e exclusiva ao governo do Reino celestial de Deus',
      ],
      somePeopleSay: 'Os cristãos devem se candidatar à política e lutar nas guerras para melhorar a sociedade.',
      summary: 'Os seguidores de Jesus não fazem parte do mundo. Mantemos estrita neutralidade política e militar, ao mesmo tempo em que somos cidadãos exemplares.',
      reviewQuestions: [
        'Por que Jesus recusou se tornar rei ou se envolver nas rivalidades políticas de sua época?',
        'Como cumprir as leis dos governos humanos sem violar a lei suprema de Deus?',
        'Por que a neutralidade protege a união fraterna dos cristãos em todas as nações?',
      ],
      tryThis: 'Ore pedindo sabedoria para permanecer leal ao Reino de Deus diante de pressões patrióticas.',
    ),
    LffLessonInfo(
      number: 46,
      title: 'Por que se dedicar a Jeová e ser batizado?',
      section: 3,
      pointTitles: [
        '1. O que é a oração solene e íntima de dedicação exclusiva a Jeová Deus?',
        '2. O que motiva no coração uma pessoa a tomar essa nobre e vital decisão?',
        '3. O exemplo de Jesus ao se apresentar para cumprir a vontade do Pai no batismo',
        '4. Como superar o medo infundado de falhar e confiar plenamente no amparo divino',
        '5. O valor inestimável de pertencer para sempre ao Soberano do Universo',
        '6. O batismo em água como a declaração pública de uma decisão já selada em oração',
      ],
      somePeopleSay: 'Dedicar a vida a Deus tira a liberdade pessoal e coloca um peso insuportável sobre o cristão.',
      summary: 'A dedicação a Jeová é motivada pelo amor ardente a Ele. Longe de tirar a liberdade, pertencer a Deus traz a verdadeira dignidade e bênçãos eternas.',
      reviewQuestions: [
        'O que significa orar a Jeová e dedicar a sua vida exclusivamente a Ele?',
        'Por que o amor a Deus vence qualquer receio de cometer erros no futuro?',
        'Como o exemplo de Jesus no batismo inspira você a dar esse passo com coragem?',
      ],
      tryThis: 'Pense nos motivos pelos quais você ama a Jeová e fale sobre isso em sua oração diária.',
    ),
    LffLessonInfo(
      number: 47,
      title: 'Você está pronto para ser batizado?',
      section: 3,
      pointTitles: [
        '1. O conhecimento bíblico exato e a aplicação prática da verdade na rotina diária',
        '2. A importância de ter uma fé genuína demonstrada por obras, arrependimento e conversão',
        '3. A conversa amorosa e edificante com os anciãos da congregação sobre os requisitos',
        '4. O ajuste voluntário e alegre da conduta pessoal às normas morais das Escrituras',
        '5. O significado solene e inesquecível do dia da imersão pública em água',
        '6. O ponto de partida abençoado de uma carreira eterna a serviço do Deus vivo',
      ],
      somePeopleSay: 'Apenas pessoas espiritualmente perfeitas e que nunca cometem falhas podem ser batizadas.',
      summary: 'Estar pronto para o batismo não significa ser perfeito, mas amar a Jeová de todo o coração, viver de acordo com a Bíblia e desejar servi-lo com alegria.',
      reviewQuestions: [
        'Que mudanças na vida mostram que a pessoa se arrependeu e se converteu a Deus?',
        'Qual é o objetivo das conversas dos anciãos com quem deseja ser batizado?',
        'Por que o batismo é considerado um novo recomeço na vida espiritual?',
      ],
      tryThis: 'Converse abertamente com seu instrutor da Bíblia sobre o seu progresso rumo ao batismo.',
    ),
    // === Parte 4: Continue a fortalecer sua amizade com Jeová (Lições 48 a 60) ===
    LffLessonInfo(
      number: 48,
      title: 'Escolha bem os amigos',
      section: 4,
      pointTitles: [
        '1. O que a Bíblia ensina sobre a influência determinante das más companhias?',
        '2. Como as pessoas com quem convivemos moldam a nossa maneira de pensar e agir',
        '3. Onde e como encontrar verdadeiros amigos que amam a Jeová na congregação',
        '4. O perigo oculto das amizades virtuais e com pessoas que desrespeitam a verdade',
        '5. Construir amizades profundas, duradouras e edificantes na família espiritual',
        '6. Como ser você mesmo um amigo leal, discreto e consolador nos momentos de aflição',
      ],
      somePeopleSay: 'Não há perigo em manter amizades íntimas com quem não serve a Deus, se tivermos personalidade forte.',
      summary: 'As más companhias estragam os bons hábitos. Escolher amigos achegados a Jeová fortalece a nossa integridade e nos protege de desvios morais.',
      reviewQuestions: [
        'Que conselho inspirado o texto de 1 Coríntios 15:33 dá sobre as companhias?',
        'Como saber se alguém é realmente uma boa amizade para você?',
        'De que maneiras você pode cultivar laços de afeto mais fortes com os irmãos?',
      ],
      tryThis: 'Tome a iniciativa de conversar com irmãos maduros e de diferentes idades na reunião.',
    ),
    LffLessonInfo(
      number: 49,
      title: 'Como ter uma família feliz? — Parte 1',
      section: 4,
      pointTitles: [
        '1. O papel amoroso, paciente e protetor do marido como chefe de família',
        '2. O papel sábio, respeitoso e cooperador da esposa edificando o lar',
        '3. A importância fundamental de trabalhar juntos em equipe para resolver problemas',
        '4. O exemplo supremo de amor abnegado que Jesus Cristo deu no trato com a congregação',
        '5. O respeito mútuo, a fidelidade inegociável e o carinho constante no casamento',
        '6. O poder indispensável do perdão sincero para manter a paz conjugal ao longo dos anos',
      ],
      somePeopleSay: 'O casamento moderno não precisa de papéis definidos e o divórcio resolve qualquer atrito.',
      summary: 'O casamento é bem-sucedido quando marido e esposa seguem as orientações bíblicas, agindo com amor abnegado, respeito profundo e perdão diário.',
      reviewQuestions: [
        'O que a Bíblia ensina sobre a responsabilidade do marido de amar e cuidar da esposa?',
        'Como a esposa sábia demonstra respeito genuíno pela liderança do marido?',
        'Por que o perdão rápido é vital para a saúde emocional do casal?',
      ],
      tryThis: 'Elogie seu cônjuge e expresse gratidão por algo bom que ele ou ela fez hoje.',
    ),
    LffLessonInfo(
      number: 50,
      title: 'Como ter uma família feliz? — Parte 2',
      section: 4,
      pointTitles: [
        '1. A responsabilidade sagrada dos pais de instruir e orientar os filhos com amor',
        '2. A importância da obediência, respeito e consideração dos filhos para com os pais',
        '3. O valor insubstituível da Adoração em Família semanal com criatividade e diálogo',
        '4. Disciplinar com paciência e consistência, evitando a ira, a humilhação ou violência',
        '5. Proteger os filhos contra perigos morais, más companhias e armadilhas da internet',
        '6. Criar um ambiente doméstico caloroso onde reinem o amor, a confiança e a segurança',
      ],
      somePeopleSay: 'Educar os filhos é dever exclusivo das escolas e a disciplina firme prejudica a liberdade.',
      summary: 'Os pais receberam de Jeová o privilégio de guiar o coração dos filhos. Filhos que honram os pais trazem imensa alegria ao lar e agradam a Deus.',
      reviewQuestions: [
        'Como os pais podem ensinar os filhos sobre Jeová de modo prático e diário?',
        'Por que a disciplina dada com amor e calma é benéfica para o desenvolvimento dos filhos?',
        'Que bênçãos resultam de manter uma Adoração em Família regular todas as semanas?',
      ],
      tryThis: 'Programe um momento agradável de Adoração em Família adaptado à idade dos seus familiares.',
    ),
    LffLessonInfo(
      number: 51,
      title: 'Como agradar a Jeová pelo modo como falamos?',
      section: 4,
      pointTitles: [
        '1. O poder imenso que as palavras têm para curar, edificar ou ferir as pessoas',
        '2. O tipo de linguagem reprovada por Deus: palavrões, calúnias, fofocas e gritaria',
        '3. Como usar a língua diariamente para consolar, incentivar e animar os outros',
        '4. O cuidado redobrado com o que falamos ou repassamos em conversas e redes sociais',
        '5. Falar com calma, serenidade e tato mesmo quando formos ofendidos ou provocados',
        '6. Usar a fala para louvar o nome de Jeová na oração e na proclamação da verdade',
      ],
      somePeopleSay: 'Falar palavrões e compartilhar fofocas inofensivas não prejudica ninguém na prática.',
      summary: 'A nossa maneira de falar reflete o que temos no coração. Usar palavras bondosas e edificantes alegra a Jeová e fortalece a paz na família e na congregação.',
      reviewQuestions: [
        'Que tipos de linguagem o cristão deve eliminar completamente de seu vocabulário?',
        'Como podemos usar a nossa língua para curar feridas e levantar os desanimados?',
        'O que pode nos ajudar a controlar o que dizemos em momentos de irritação?',
      ],
      tryThis: 'Pense antes de falar e faça um elogio sincero a alguém que esteja precisando de apoio.',
    ),
    LffLessonInfo(
      number: 52,
      title: 'Por que é importante pensar na nossa roupa e aparência?',
      section: 4,
      pointTitles: [
        '1. Como o nosso modo de vestir e arrumar reflete o respeito que sentimos por Deus',
        '2. Os princípios bíblicos eternos de modéstia, bom senso, limpeza e decência no vestuário',
        '3. Como a nossa aparência nas reuniões e na pregação dá bom testemunho de Jeová',
        '4. Como o nosso modo de vestir pode edificar ou fazer tropeçar a consciência dos irmãos',
        '5. Evitar estilos provocantes, desleixados ou que imitem a rebeldia moral do mundo',
        '6. A dignidade, a elegância equilibrada e o bom critério em todas as ocasiões',
      ],
      somePeopleSay: 'Cada um tem o direito de se vestir como quiser, sem se importar com a opinião de ninguém.',
      summary: 'Nossa aparência física comunica quem nós somos. Vestir-se com modéstia, bom gosto e decência glorifica a Deus e atrai as pessoas para a verdade.',
      reviewQuestions: [
        'Que princípios bíblicos devem nortear a nossa escolha de roupas e aparência pessoal?',
        'Por que devemos nos preocupar com o impacto visual da nossa roupa sobre os outros?',
        'Como a nossa apresentação no ministério e nas reuniões honra a Jeová?',
      ],
      tryThis: 'Revise seu guarda-roupa à luz dos princípios bíblicos de modéstia e decência cristã.',
    ),
    LffLessonInfo(
      number: 53,
      title: 'Como escolher bem as diversões?',
      section: 4,
      pointTitles: [
        '1. Que diversões são verdadeiramente saudáveis e revigoram a mente e o corpo?',
        '2. O que Jeová aprova e o que Ele abomina expressamente em matéria de lazer',
        '3. Como o entretenimento consome nosso tempo e afeta os nossos sentimentos íntimos',
        '4. Rejeitar sem hesitação filmes, músicas e jogos com violência, sexo imoral ou ocultismo',
        '5. O princípio bíblico de \'odiar o que é mau\' na seleção de conteúdos e mídias',
        '6. Desfrutar de momentos felizes de lazer sadio com a família e a irmandade cristã',
      ],
      somePeopleSay: 'Assistir a cenas de violência ou imoralidade em filmes é apenas ficção e não influencia ninguém.',
      summary: 'A recreação é um presente sadio, mas o entretenimento que enaltece coisas que Deus condena corrompe a espiritualidade. Escolha lazer que edifique.',
      reviewQuestions: [
        'Que tipo de diversão o servo fiel de Deus deve rejeitar de pronto?',
        'Como ter certeza de que o tempo dedicado ao lazer não prejudica a adoração espiritual?',
        'Que opções saudáveis e alegres de recreação podemos desfrutar com amigos?',
      ],
      tryThis: 'Antes de assistir a um filme ou jogar um game, verifique se ele respeita as normas de Deus.',
    ),
    LffLessonInfo(
      number: 54,
      title: 'O que “o escravo fiel e prudente” faz?',
      section: 4,
      pointTitles: [
        '1. Quem é o \'escravo fiel e prudente\' designado pelo Senhor Jesus Cristo?',
        '2. De que maneiras maravilhosas o escravo cuida do alimento espiritual de cada um de nós?',
        '3. Como você pode demonstrar de coração que apoia a organização visível de Jeová?',
        '4. O cumprimento histórico e moderno da profecia registrada em Mateus 24:45-47',
        '5. A coordenação mundial das publicações bíblicas, traduções e pregação global',
        '6. A bênção de confiar e cooperar com a liderança amorosa provida para a nossa salvação',
      ],
      somePeopleSay: 'Jesus não deixou nenhuma liderança organizada na Terra, cada um segue a Bíblia por conta própria.',
      summary: 'Jesus escolheu o escravo fiel e prudente para fornecer o alimento bíblico no tempo certo e coordenar a pregação mundial do Reino de Deus.',
      reviewQuestions: [
        'Como identificamos hoje o escravo fiel e prudente mencionado por Jesus?',
        'Que alimento e orientações espirituais recebemos por meio desse canal?',
        'Como podemos colaborar ativamente com as decisões e orientações teocráticas?',
      ],
      tryThis: 'Acompanhe as atualizações e relatórios do Corpo Governante no site oficial jw.org.',
    ),
    LffLessonInfo(
      number: 55,
      title: 'Apoie a sua congregação',
      section: 4,
      pointTitles: [
        '1. Como você pode usar seus talentos, tempo e disposição para apoiar a congregação?',
        '2. De que maneira prática todos podem colaborar na limpeza e manutenção do Salão do Reino?',
        '3. Como o arranjo de donativos voluntários apoia com transparência a obra local e mundial',
        '4. A importância de apoiar lealmente os anciãos e servos ministeriais designados',
        '5. Ajudar os idosos, os doentes e as famílias monoparentais da congregação',
        '6. Dar com alegria e generosidade, sem constrangimento, obrigações ou cobranças de dízimo',
      ],
      somePeopleSay: 'Apoiar uma organização religiosa significa ser explorado financeiramente por líderes.',
      summary: 'Apoiamos a congregação oferecendo nosso tempo, participando nas reuniões e contribuindo voluntariamente para o avanço das boas novas em toda a Terra.',
      reviewQuestions: [
        'De que maneiras práticas você pode ajudar no cuidado do Salão do Reino?',
        'Como o arranjo de donativos voluntários sem dízimos funciona na organização?',
        'Por que cooperar com os superintendentes locais fortalece a congregação?',
      ],
      tryThis: 'Ofereça-se para colaborar na limpeza do Salão do Reino na próxima designação do seu grupo.',
    ),
    LffLessonInfo(
      number: 56,
      title: 'Faça sua parte para manter a união',
      section: 4,
      pointTitles: [
        '1. O valor imensurável da união fraterna entre o povo de Deus em todo o mundo',
        '2. O que a Bíblia ensina sobre perdoar livremente as imperfeições e falhas dos irmãos',
        '3. Que passos amorosos e bíblicos dar se surgir um desentendimento pessoal sério',
        '4. As instruções de Jesus em Mateus 18 para resolver conflitos interpessoais em particular',
        '5. Vencer o ressentimento, o orgulho ferido e a mágoa antes que causem divisões',
        '6. Promover ativamente a paz e cultivar o vínculo perfeito de amor na congregação',
      ],
      somePeopleSay: 'Se alguém me ofender na congregação, tenho o direito de cortar relações e guardar mágoa.',
      summary: 'A união do povo de Deus é mantida pelo perdão mútuo. Quando surgem desentendimentos, aplicamos os conselhos de Jesus para restabelecer a paz imediatamente.',
      reviewQuestions: [
        'Como Jeová nos trata quando perdoamos os erros dos nossos irmãos?',
        'Que passos práticos Jesus deu para resolver desentendimentos particulares?',
        'O que você pode fazer para promover um ambiente de harmonia e fraternidade?',
      ],
      tryThis: 'Se tiver algum mal-entendido com alguém, tome a iniciativa de conversar em particular com amor.',
    ),
    LffLessonInfo(
      number: 57,
      title: 'E se você cometer um pecado grave?',
      section: 4,
      pointTitles: [
        '1. O que a Bíblia define como um pecado grave e como Jeová encara essa situação?',
        '2. O que a pessoa deve fazer de imediato caso tropece num erro espiritual sério?',
        '3. Como os anciãos agem como pastores amorosos para curar e restaurar o pecador',
        '4. O perigo mortal de tentar ocultar erros e endurecer o coração na mentira',
        '5. A disciplina amorosa provida por Deus como demonstração de misericórdia e justiça',
        '6. A certeza consoladora de que Jeová perdoa amplamente quem se arrepende com sinceridade',
      ],
      somePeopleSay: 'Se alguém cometer um pecado grave, Deus o rejeita para sempre e não há perdão.',
      summary: 'Jeová é misericordioso e deseja o arrependimento do errante. Procurar a ajuda amorosa dos anciãos é o caminho para recuperar a paz com Deus.',
      reviewQuestions: [
        'Por que tentar encobrir um erro grave só piora a situação do cristão?',
        'Como os anciãos usam a Bíblia e a oração para ajudar quem cometeu um pecado?',
        'O que nos dá a garantia inabalável de que Jeová é perdoador e misericordioso?',
      ],
      tryThis: 'Leia o Salmo 32 e sinta o alívio que a confissão honesta traz ao coração arrependido.',
    ),
    LffLessonInfo(
      number: 58,
      title: 'Continue leal a Jeová',
      section: 4,
      pointTitles: [
        '1. O que significa manter a lealdade inabalável a Jeová em toda e qualquer circunstância?',
        '2. Como agir com sabedoria, amor e firmeza caso alguém próximo abandone a verdade?',
        '3. Por que devemos rejeitar com determinação a apostasia e as mentiras dos opositores?',
        '4. O valor da integridade pessoal quando a nossa fé e fidelidade são testadas',
        '5. Como a oração constante e o estudo da Bíblia blindam o coração leal contra dúvidas',
        '6. A promessa maravilhosa de Deus: \'Com quem é leal, tu ages com lealdade\'',
      ],
      somePeopleSay: 'Não faz mal ler matérias ou assistir a vídeos de pessoas que abandonaram a verdade para zombar dela.',
      summary: 'Ser leal a Jeová exige colocar o amor a Ele acima de tudo e rejeitar a influência enganosa de opositores e apóstatas que tentam destruir a nossa fé.',
      reviewQuestions: [
        'Que situações podem colocar à prova a nossa lealdade a Jeová?',
        'Por que o cristão sábio evita qualquer contato com idéias apóstatas?',
        'Como a lealdade a Deus nos ajuda a tomar decisões acertadas em momentos de crise?',
      ],
      tryThis: 'Ore pedindo a Jeová forças para manter seu coração sempre leal e firme na verdade.',
    ),
    LffLessonInfo(
      number: 59,
      title: 'Enfrente perseguição com coragem!',
      section: 4,
      pointTitles: [
        '1. Por que os verdadeiros discípulos de Cristo sabem que enfrentarão perseguição?',
        '2. Como podemos fortalecer a nossa fé com antecedência para não temer os homens?',
        '3. O consolo revigorante de saber que Jeová nos dará o \'poder além do normal\'',
        '4. O exemplo inspirador dos profetas antigos, dos apóstolos e dos irmãos modernos',
        '5. Como manter a integridade alegre mesmo sob zombarias, proscrição, processos ou prisões',
        '6. A vitória gloriosa e a recompensa eterna garantidas aos que perseveram até o fim',
      ],
      somePeopleSay: 'Se os cristãos sofrerem perseguição, é sinal de que Deus os desaprovou ou abandonou.',
      summary: 'A oposição e a perseguição são provas normais da nossa fé no mundo de Satanás. Com a coragem que Jeová dá, podemos nos manter firmes e vitoriosos.',
      reviewQuestions: [
        'Por que os servos de Jeová enfrentam perseguição em tantos países?',
        'O que você pode fazer hoje para blindar a sua coragem perante futuras provações?',
        'Que garantia Jesus deu aos que sofrem por amor à justiça?',
      ],
      tryThis: 'Leia experiências encorajadoras de publicadores que mantiveram a fé diante da oposição no jw.org.',
    ),
    LffLessonInfo(
      number: 60,
      title: 'Continue a fortalecer sua amizade com Jeová',
      section: 4,
      pointTitles: [
        '1. Que excelentes hábitos espirituais você deve manter e cultivar para sempre?',
        '2. Que novos alvos teocráticos você pode traçar na congregação e no ministério?',
        '3. Como você pode ajudar outras pessoas sinceras a também se tornarem amigas de Deus?',
        '4. Manter sempre vivo o fervor e o primeiro amor pelas verdades sagradas da Bíblia',
        '5. Expandir o serviço sagrado: pioneiro auxiliar, pioneiro regular ou onde há necessidade',
        '6. A perspectiva radiante de desfrutar de uma vida verdadeiramente feliz para sempre com Jeová!',
      ],
      somePeopleSay: 'Depois de terminar o estudo do livro, a pessoa já aprendeu tudo o que precisava e pode relaxar.',
      summary: 'Concluir o livro é apenas o começo de uma caminhada eterna. Manter o estudo, a oração e o zelo no ministério garante uma vida plena e feliz para sempre com Jeová.',
      reviewQuestions: [
        'Que rotina espiritual você pretende manter após a conclusão deste curso bíblico?',
        'Que alvos teocráticos você gostaria de alcançar no próximo ano?',
        'O que significa para você a promessa de desfrutar de uma vida feliz para sempre?',
      ],
      tryThis: 'Faça uma lista de 2 ou 3 alvos espirituais que você vai começar a colocar em prática já este mês.',
    ),
  ];

  static LffLessonInfo? getLesson(int number) {
    if (number < 1 || number > lessons.length) return null;
    return lessons[number - 1];
  }

  static LffSectionInfo getSection(int lessonNumber) {
    if (lessonNumber <= 12) return sections[0];
    if (lessonNumber <= 33) return sections[1];
    if (lessonNumber <= 47) return sections[2];
    return sections[3];
  }

  static LffSectionInfo getSectionForLesson(int lessonNumber) => getSection(lessonNumber);

  /// Calcula o progresso percentual exato do livro (0.0% a 100.0%)
  static double calculateProgressPercentage({
    required int lesson,
    int? point,
  }) {
    if (lesson <= 0) return 0.0;
    if (lesson > totalLessons) return 100.0;

    final lessonWeight = 100.0 / totalLessons;
    final lessonInfo = getLesson(lesson);
    final maxPoints = lessonInfo?.totalPoints ?? (lesson <= 3 ? 3 : 6);
    final currentPointClamped = (point ?? 0).clamp(0, maxPoints);

    final baseProgress = (lesson - 1) * lessonWeight;
    final currentLessonProgress = (currentPointClamped / maxPoints) * lessonWeight;

    final percent = baseProgress + currentLessonProgress;
    return percent.clamp(0.0, 100.0);
  }

  /// Calcula automaticamente o próximo ponto e a próxima lição
  static ({int nextLesson, int nextPoint, String label}) getNextProgression({
    required int currentLesson,
    required int currentPoint,
  }) {
    final lessonInfo = getLesson(currentLesson);
    final maxPoints = lessonInfo?.totalPoints ?? (currentLesson <= 3 ? 3 : 6);

    if (currentPoint < maxPoints) {
      final nextP = currentPoint + 1;
      return (
        nextLesson: currentLesson,
        nextPoint: nextP,
        label: 'Lição $currentLesson, Ponto $nextP',
      );
    } else {
      if (currentLesson >= totalLessons) {
        return (
          nextLesson: totalLessons,
          nextPoint: maxPoints,
          label: '🎉 Livro Concluído! Parabéns pelo progresso!',
        );
      }

      final nextL = currentLesson + 1;
      const nextP = 1;

      String label;
      if (currentLesson == 12) {
        label = 'Próximo: Parte 1: Revisão (Lições 01 a 12) ou Lição 13';
      } else if (currentLesson == 33) {
        label = 'Próximo: Parte 2: Revisão (Lições 13 a 33) ou Lição 34';
      } else if (currentLesson == 47) {
        label = 'Próximo: Parte 3: Revisão (Lições 34 a 47) ou Lição 48';
      } else {
        label = 'Próxima Lição: Lição $nextL, Ponto $nextP';
      }

      return (
        nextLesson: nextL,
        nextPoint: nextP,
        label: label,
      );
    }
  }

  /// Retorna todas as opções de estudo (60 Lições, 4 Revisões de Seção e 7 Notas de Apêndice)
  static List<({String id, String title, String category, int totalPoints})> getAllStudyUnits() {
    final List<({String id, String title, String category, int totalPoints})> list = [];

    for (final l in lessons) {
      list.add((
        id: 'lesson_${l.number}',
        title: 'Lição ${l.number}: ${l.title}',
        category: 'Lições do Livro (Parte ${l.section})',
        totalPoints: l.totalPoints,
      ));
    }

    for (final s in sections) {
      list.add((
        id: 'review_${s.sectionNumber}',
        title: s.reviewTitle,
        category: 'Revisões de Seção',
        totalPoints: 4,
      ));
    }

    for (final e in endnotes) {
      list.add((
        id: 'endnote_${e.number}',
        title: 'Entenda Melhor ${e.number}: ${e.title}',
        category: 'Entenda Melhor (Apêndice)',
        totalPoints: 3,
      ));
    }

    return list;
  }
}

/// Catálogo Oficial da Brochura Introdutória "Seja Feliz para Sempre! — Comece a Aprender sobre a Bíblia"
class LffiBrochureCatalog {
  static const int totalLessons = 3;

  static const List<LffLessonInfo> lessons = [
    LffLessonInfo(
      number: 1,
      title: 'Como a Bíblia pode ajudar você?',
      section: 1,
      pointTitles: [
        '1. A Bíblia pode nos guiar',
        '2. A Bíblia pode responder às nossas perguntas',
        '3. A leitura da Bíblia pode ser agradável',
      ],
      summary: 'A Bíblia nos dá conselhos práticos para o dia a dia, responde a perguntas importantes e nos dá esperança e consolo.',
      reviewQuestions: [
        'Que tipo de conselhos encontramos na Bíblia?',
        'Quais são algumas perguntas que a Bíblia responde?',
        'O que você gostaria de aprender na Bíblia?',
      ],
      tryThis: 'Leia a primeira parte do programa de leitura da Bíblia desta lição.',
    ),
    LffLessonInfo(
      number: 2,
      title: 'A Bíblia nos dá esperança',
      section: 1,
      pointTitles: [
        '1. A Bíblia promete que teremos um futuro maravilhoso',
        '2. A esperança da Bíblia pode fazer a diferença na nossa vida hoje',
        '3. A esperança da Bíblia nos dá forças para perseverar',
      ],
      summary: 'A Bíblia promete que teremos um futuro maravilhoso. Essa esperança nos ajuda a lidar com os problemas hoje.',
      reviewQuestions: [
        'Que promessas da Bíblia para o futuro você mais gostou?',
        'Como a esperança da Bíblia pode ajudar você hoje?',
      ],
      tryThis: 'Leia os textos bíblicos citados nesta lição e pense em como eles se aplicam a você.',
    ),
    LffLessonInfo(
      number: 3,
      title: 'Será que você pode acreditar na Bíblia?',
      section: 1,
      pointTitles: [
        '1. A Bíblia está de acordo com a ciência',
        '2. A Bíblia relata acontecimentos históricos com exatidão',
        '3. As profecias da Bíblia se cumprem',
      ],
      summary: 'A ciência, a história e as profecias cumpridas provam que podemos confiar na Bíblia.',
      reviewQuestions: [
        'A Bíblia é um livro de mitos ou relata a verdade?',
        'Quais são alguns exemplos de harmonia entre a Bíblia e a ciência?',
        'Você acha que pode confiar na Bíblia?',
      ],
      tryThis: 'No final desta lição 3: Perguntar se o estudante aceita continuar com o livro completo a partir da Lição 4.',
    ),
  ];

  static LffLessonInfo? getLesson(int number) {
    if (number < 1 || number > lessons.length) return null;
    return lessons[number - 1];
  }
}

/// Catálogo Oficial da Brochura "Escute a Deus e Viva para Sempre"
class ListenToGodCatalog {
  static const int totalLessons = 14;

  static const List<({int number, String title, int paragraphs})> lessons = [
    (number: 1, title: 'Como Deus fala com a gente?', paragraphs: 5),
    (number: 2, title: 'Quem é Deus?', paragraphs: 6),
    (number: 3, title: 'Como era a vida no começo?', paragraphs: 4),
    (number: 4, title: 'O que aconteceu quando Adão e Eva escutaram Satanás?', paragraphs: 5),
    (number: 5, title: 'Como as pessoas eram nos dias de Noé?', paragraphs: 4),
    (number: 6, title: 'O que você pode aprender do Dilúvio?', paragraphs: 5),
    (number: 7, title: 'Quem era Jesus?', paragraphs: 7),
    (number: 8, title: 'O que a morte de Jesus tem a ver com você?', paragraphs: 6),
    (number: 9, title: 'Quando a Terra vai se tornar um paraíso?', paragraphs: 6),
    (number: 10, title: 'Se você escutar a Deus, que bênçãos você vai ter?', paragraphs: 7),
    (number: 11, title: 'Será que Jeová nos escuta?', paragraphs: 4),
    (number: 12, title: 'Como sua família pode ser feliz?', paragraphs: 6),
    (number: 13, title: 'O que você precisa fazer para deixar Jeová feliz?', paragraphs: 5),
    (number: 14, title: 'Como você mostra que é fiel a Jeová?', paragraphs: 5),
  ];

  static ({int number, String title, int paragraphs})? getLesson(int number) {
    if (number < 1 || number > lessons.length) return null;
    return lessons[number - 1];
  }
}
