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
class LffBookCatalog {
  static const int totalLessons = 60;

  static const List<LffSectionInfo> sections = [
    LffSectionInfo(
      sectionNumber: 1,
      title: 'Seção 1: Como a Bíblia Pode Ajudar Você',
      startLesson: 1,
      endLesson: 12,
      reviewTitle: 'Revisão da Seção 1 (Lições 01 a 12)',
    ),
    LffSectionInfo(
      sectionNumber: 2,
      title: 'Seção 2: O Que a Bíblia Ensina Sobre o Futuro e a Família',
      startLesson: 13,
      endLesson: 33,
      reviewTitle: 'Revisão da Seção 2 (Lições 13 a 33)',
    ),
    LffSectionInfo(
      sectionNumber: 3,
      title: 'Seção 3: Conheça Melhor o Povo de Deus e Suas Leis',
      startLesson: 34,
      endLesson: 47,
      reviewTitle: 'Revisão da Seção 3 (Lições 34 a 47)',
    ),
    LffSectionInfo(
      sectionNumber: 4,
      title: 'Seção 4: Como Continuar Amigo de Jeová Para Sempre',
      startLesson: 48,
      endLesson: 60,
      reviewTitle: 'Revisão da Seção 4 (Lições 48 a 60)',
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
    LffLessonInfo(
      number: 1,
      title: 'Como a Bíblia pode ajudar você?',
      section: 1,
      pointTitles: [
        '1. A Bíblia pode responder às suas perguntas mais importantes',
        '2. A Bíblia pode ajudar você a lidar com os problemas do dia a dia',
        '3. A Bíblia nos dá uma esperança real para o futuro',
      ],
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
        '5. Jeová quer que você se aproxime mais dele',
        '6. Como conhecer melhor a Jeová',
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
        '1. Se homens escreveram a Bíblia, por que dizemos que ela é a Palavra de Deus?',
        '2. Para quem Deus fez a Bíblia?',
        '3. Como Jeová protegeu a Bíblia ao longo da história?',
        '4. A Bíblia diz claramente quem é o seu Autor',
        '5. A Bíblia sofreu muitos ataques, mas sobreviveu',
        '6. Um livro para pessoas de todas as nações e línguas',
      ],
    ),
    LffLessonInfo(
      number: 6,
      title: 'Como a vida começou?',
      section: 1,
      pointTitles: [
        '1. Como o Universo e a Terra começaram?',
        '2. Por que Deus criou a Terra?',
        '3. O que faz os humanos serem diferentes dos animais?',
        '4. O Universo e a Terra foram projetados de modo inteligente',
        '5. O relato de Gênesis sobre a criação é confiável',
        '6. É razoável e científico acreditar na criação',
      ],
    ),
    LffLessonInfo(
      number: 7,
      title: 'Conheça mais a Jeová',
      section: 1,
      pointTitles: [
        '1. Onde Jeová mora e como ele é?',
        '2. O que Jeová sente por cada um de nós?',
        '3. Quais são as quatro qualidades principais de Jeová?',
        '4. A sabedoria e o poder incomparáveis de Deus',
        '5. A justiça perfeita de Jeová em todas as suas ações',
        '6. O amor é a qualidade principal da personalidade de Jeová',
      ],
    ),
    LffLessonInfo(
      number: 8,
      title: 'Você pode ser amigo de Jeová',
      section: 1,
      pointTitles: [
        '1. Por que Jeová quer ter você como amigo?',
        '2. O que Jeová pede dos amigos dele?',
        '3. Quem pode ser considerado um amigo leal de Deus?',
        '4. Jeová convida você para se achegar a ele',
        '5. O que os amigos de Jeová fazem para agradá-lo',
        '6. O exemplo de fé de Abraão como amigo de Jeová',
      ],
    ),
    LffLessonInfo(
      number: 9,
      title: 'A oração fortalece sua amizade com Deus',
      section: 1,
      pointTitles: [
        '1. A quem devemos orar com sinceridade?',
        '2. O que significa orar em nome de Jesus?',
        '3. Podemos orar sobre qualquer assunto que esteja de acordo com a vontade de Deus',
        '4. Como a oração nos ajuda a manter a paz mental',
        '5. Como orar de um jeito que agrada a Jeová',
        '6. De que maneiras Deus responde às nossas orações',
      ],
    ),
    LffLessonInfo(
      number: 10,
      title: 'Como as reuniões das Testemunhas de Jeová podem ajudar você?',
      section: 1,
      pointTitles: [
        '1. Por que nos reunimos como congregação?',
        '2. O que acontece nas reuniões realizadas no Salão do Reino?',
        '3. Como você é acolhido e pode se beneficiar do ambiente fraterno?',
        '4. O que você vai ver e ouvir nas nossas reuniões',
        '5. O esforço sincero para assistir às reuniões vale a pena',
        '6. Como tirar o máximo proveito de cada consideração bíblica',
      ],
    ),
    LffLessonInfo(
      number: 11,
      title: 'Como você pode aproveitar ao máximo a leitura da Bíblia?',
      section: 1,
      pointTitles: [
        '1. Por que ler a Palavra de Deus todos os dias?',
        '2. Como podemos entender melhor as passagens difíceis?',
        '3. Como tornar a leitura da Bíblia agradável e recompensadora?',
        '4. Crie uma rotina prática para ler a Bíblia com frequência',
        '5. Medite e visualize o que você está lendo',
        '6. Ferramentas e pesquisas para aprofundar seu entendimento',
      ],
    ),
    LffLessonInfo(
      number: 12,
      title: 'O que vai ajudar você a continuar estudando a Bíblia?',
      section: 1,
      pointTitles: [
        '1. Por que o estudo bíblico é um investimento precioso?',
        '2. Como encontrar tempo em meio à correria do dia a dia?',
        '3. Como reagir com amor quando amigos ou parentes se opõem?',
        '4. Dê prioridade ao seu estudo da Palavra de Deus',
        '5. Como manter a calma e a convicção diante de oposição',
        '6. Confie na ajuda e nas bênçãos que Jeová promete',
      ],
    ),
    LffLessonInfo(
      number: 13,
      title: 'Como as religiões falsas afastam as pessoas de Deus?',
      section: 2,
      pointTitles: [
        '1. Por que existem tantas religiões diferentes se Deus é um só?',
        '2. O que a Bíblia ensina sobre as religiões falsas?',
        '3. Que mentiras as religiões falsas ensinam sobre o Criador?',
        '4. O envolvimento da religião falsa em guerras e na política',
        '5. Como a religião falsa explora as pessoas financeiramente',
        '6. Deus convida você a sair da religião falsa sem demora',
      ],
    ),
    LffLessonInfo(
      number: 14,
      title: 'O que temos que fazer para Deus aceitar nossa adoração?',
      section: 2,
      pointTitles: [
        '1. Que tipo de adoração agrada a Jeová?',
        '2. O que a Bíblia diz sobre o uso de imagens e santos?',
        '3. Como adorar a Deus \'com espírito e verdade\'?',
        '4. Adore somente a Jeová como o único Deus verdadeiro',
        '5. Por que as imagens e símbolos religiosos não têm valor para Deus',
        '6. A alegria de adorar a Deus em união com outros cristãos verdadeiros',
      ],
    ),
    LffLessonInfo(
      number: 15,
      title: 'Quem é Jesus?',
      section: 2,
      pointTitles: [
        '1. Jesus é o Filho primogênito de Deus',
        '2. Onde Jesus estava antes de vir para a Terra?',
        '3. Por que Jesus foi chamado de \'o Verbo\' ou \'a Palavra\'?',
        '4. Jesus não é o Deus Todo-Poderoso, mas sim submisso ao Pai',
        '5. O papel indispensável de Jesus no propósito de Deus',
        '6. Como seguir os passos de Jesus no nosso cotidiano',
      ],
    ),
    LffLessonInfo(
      number: 16,
      title: 'O que Jesus fez quando esteve na Terra?',
      section: 2,
      pointTitles: [
        '1. Por que Jesus veio à Terra e como foi o seu ministério?',
        '2. Qual era o tema principal da pregação de Jesus?',
        '3. O que os milagres de Jesus revelaram sobre a sua personalidade?',
        '4. Jesus ensinou a verdade pura sobre o Reino de Deus',
        '5. A compaixão e a cura de enfermos como antegosto do futuro',
        '6. Jesus deu a sua vida perfeita em resgate pela humanidade',
      ],
    ),
    LffLessonInfo(
      number: 17,
      title: 'Que tipo de pessoa é Jesus?',
      section: 2,
      pointTitles: [
        '1. Quais eram as principais qualidades de Jesus Cristo?',
        '2. Por que as pessoas, incluindo crianças, se sentiam à vontade perto dele?',
        '3. Como Jesus tratava as mulheres, os humildes e os excluídos?',
        '4. O amor abnegado e a compaixão de Jesus pelas multidões',
        '5. A humildade profunda e a paciência de Jesus com seus discípulos',
        '6. A coragem exemplar de Jesus em defender a verdade',
      ],
    ),
    LffLessonInfo(
      number: 18,
      title: 'Como saber quem são os cristãos verdadeiros?',
      section: 2,
      pointTitles: [
        '1. Todos os que dizem acreditar em Cristo são cristãos de verdade?',
        '2. Que sinal infalível Jesus deu para identificar seus discípulos?',
        '3. O que a Bíblia diz sobre \'lobos vestidos de ovelhas\'?',
        '4. Os cristãos verdadeiros demonstram amor altruísta entre si',
        '5. Eles baseiam todos os seus ensinamentos unicamente na Bíblia',
        '6. Eles pregam ativamente o Reino de Deus e não fazem parte do mundo',
      ],
    ),
    LffLessonInfo(
      number: 19,
      title: 'Será que as Testemunhas de Jeová são cristãos de verdade?',
      section: 2,
      pointTitles: [
        '1. Quem são as Testemunhas de Jeová e qual é a sua origem moderna?',
        '2. De onde vêm todas as crenças e doutrinas que elas ensinam?',
        '3. Por que elas usam com orgulho o nome bíblico de Jeová?',
        '4. A história dos Estudantes da Bíblia e o retorno às verdades originais',
        '5. Uma fraternidade mundial unida sem divisões raciais ou políticas',
        '6. Como as Testemunhas de Jeová praticam o amor em tempos de crise',
      ],
    ),
    LffLessonInfo(
      number: 20,
      title: 'Como a congregação está organizada?',
      section: 2,
      pointTitles: [
        '1. Quem é o verdadeiro Líder da congregação cristã?',
        '2. O que a Bíblia ensina sobre a designação de anciãos e servos ministeriais?',
        '3. Como a congregação local cuida espiritualmente dos publicadores?',
        '4. Jesus Cristo lidera a congregação por meio do espírito santo',
        '5. O trabalho amoroso e voluntário dos pastores espirituais',
        '6. Como o Corpo Governante orienta os cristãos no mundo inteiro',
      ],
    ),
    LffLessonInfo(
      number: 21,
      title: 'Como as boas novas são pregadas?',
      section: 2,
      pointTitles: [
        '1. Que profecia Jesus fez sobre a proclamação das boas novas?',
        '2. Por que a pregação de casa em casa continua sendo tão importante?',
        '3. Que outros métodos são usados para alcançar o maior número de pessoas?',
        '4. A organização mundial necessária para realizar essa grande obra',
        '5. O uso de tecnologia, traduções e publicações impressas no campo',
        '6. O privilégio ímpar de sermos \'colaboradores de Deus\' no ministério',
      ],
    ),
    LffLessonInfo(
      number: 22,
      title: 'Como você pode falar das boas novas para outros?',
      section: 2,
      pointTitles: [
        '1. Por que falar de Jeová a parentes e amigos traz tanta alegria?',
        '2. Como iniciar conversas espirituais de maneira natural e informal?',
        '3. O que fazer para falar da Bíblia com tato, respeito e sensibilidade?',
        '4. Compartilhe o que você está aprendendo com quem você ama',
        '5. Como vencer a timidez ou o receio do que os outros vão pensar',
        '6. Como se qualificar para pregar como publicador não batizado',
      ],
    ),
    LffLessonInfo(
      number: 23,
      title: 'Batismo — Um alvo que vale a pena ter!',
      section: 2,
      pointTitles: [
        '1. O que o batismo cristão em água realmente significa?',
        '2. Por que o batismo por imersão total é uma exigência de Jesus?',
        '3. Que passos práticos a pessoa deve dar antes de ser batizada?',
        '4. O exemplo do batismo de Jesus no rio Jordão',
        '5. A dedicação pessoal a Jeová feita de coração em oração',
        '6. O batismo como início de uma vida plena a serviço do Criador',
      ],
    ),
    LffLessonInfo(
      number: 24,
      title: 'Quem são os anjos, e o que eles fazem?',
      section: 2,
      pointTitles: [
        '1. Quando e como os anjos foram criados por Deus?',
        '2. Como os anjos fiéis apoiam o povo de Jeová e a pregação hoje?',
        '3. Quem é Satanás, o Diabo, e quem são os demônios?',
        '4. O papel dos santos anjos na execução da vontade de Deus',
        '5. Como os demônios enganam e desviam a humanidade',
        '6. Como se proteger contra o ocultismo, feitiçaria e espiritismo',
      ],
    ),
    LffLessonInfo(
      number: 25,
      title: 'Qual é o objetivo de Deus para nós?',
      section: 2,
      pointTitles: [
        '1. Para que propósito Deus criou os seres humanos na Terra?',
        '2. O que aconteceu no jardim do Éden que afetou toda a humanidade?',
        '3. Por que temos plena certeza de que o propósito de Deus não mudou?',
        '4. A vida perfeita e feliz que Adão e Eva desfrutavam no Éden',
        '5. As consequências do pecado e da perda da perfeição original',
        '6. A garantia absoluta de que a Terra será transformada num paraíso eterno',
      ],
    ),
    LffLessonInfo(
      number: 26,
      title: 'Por que a maldade e o sofrimento existem?',
      section: 2,
      pointTitles: [
        '1. Será que Deus é o responsável pelo sofrimento e tragédias do mundo?',
        '2. Que questão moral crucial Satanás levantou no jardim do Éden?',
        '3. Por que Jeová permitiu que o tempo passasse antes de intervir?',
        '4. As causas reais do sofrimento: Satanás, escolhas erradas e imprevistos',
        '5. A soberania de Jeová e o direito legítimo de Deus governar',
        '6. Como Jeová vai desfazer completamente todo o sofrimento e dor',
      ],
    ),
    LffLessonInfo(
      number: 27,
      title: 'Como a morte de Jesus pode nos salvar?',
      section: 2,
      pointTitles: [
        '1. Como o pecado e a morte foram transmitidos a todos os humanos?',
        '2. O que a Bíblia quer dizer com a palavra \'resgate\'?',
        '3. Como o sacrifício de Jesus corresponde perfeitamente ao que Adão perdeu?',
        '4. O resgate de Cristo como a maior demonstração do amor de Deus',
        '5. Como o resgate nos liberta da condenação do pecado herdado',
        '6. A esperança real de viver para sempre graças ao sacrifício de Jesus',
      ],
    ),
    LffLessonInfo(
      number: 28,
      title: 'Como mostrar gratidão pelo que Jeová e Jesus fizeram por você',
      section: 2,
      pointTitles: [
        '1. Como podemos demonstrar que valorizamos o sacrifício do resgate?',
        '2. O que é a Celebração da Morte de Cristo (Memorial ou Ceia do Senhor)?',
        '3. Quando e como essa data especial deve ser comemorada?',
        '4. Viver em harmonia com os ensinamentos e o exemplo de Jesus',
        '5. A importância de estar presente todos os anos na Celebração',
        '6. Demonstrar apreço diário por meio de palavras, ações e orações',
      ],
    ),
    LffLessonInfo(
      number: 29,
      title: 'O que acontece quando a pessoa morre?',
      section: 2,
      pointTitles: [
        '1. Para onde vamos quando a nossa vida termina?',
        '2. Será que a alma ou o espírito continua vivo após o falecimento?',
        '3. O que a Bíblia ensina sobre a condição inconsciente dos mortos?',
        '4. A verdade libertadora: os mortos não sofrem nem sabem de nada',
        '5. Por que a crença num inferno de fogo difama a bondade de Deus',
        '6. Como a verdade sobre a morte nos liberta de rituais e medos infundados',
      ],
    ),
    LffLessonInfo(
      number: 30,
      title: 'As pessoas que você ama podem voltar a viver!',
      section: 2,
      pointTitles: [
        '1. Que esperança maravilhosa a Bíblia oferece aos que perderam entes queridos?',
        '2. Que ressurreições registradas na Bíblia comprovam o poder de Deus?',
        '3. Quem será ressuscitado para viver aqui na Terra transformada em paraíso?',
        '4. O relato emocionante da ressurreição de Lázaro por Jesus',
        '5. O reencontro alegre de famílias e amigos no novo mundo',
        '6. Como a esperança da ressurreição consola e dá forças no luto',
      ],
    ),
    LffLessonInfo(
      number: 31,
      title: 'O que é o Reino de Deus?',
      section: 2,
      pointTitles: [
        '1. O que é o Reino de Deus mencionado na oração do Pai-Nosso?',
        '2. Onde fica localizado esse governo e quem é o Rei escolhido por Deus?',
        '3. Quem vai governar no céu ao lado de Jesus Cristo?',
        '4. Por que o Reino de Deus é infinitamente superior aos governos humanos',
        '5. O número limitado de 144.000 que reinarão com Cristo',
        '6. As bênçãos magníficas que os súditos terrestres do Reino vão usufruir',
      ],
    ),
    LffLessonInfo(
      number: 32,
      title: 'O Reino de Deus já está governando!',
      section: 2,
      pointTitles: [
        '1. Quando foi que o Reino de Deus começou a governar nos céus?',
        '2. O que a profecia bíblica dos \'tempos designados\' revela sobre o ano de 1914?',
        '3. Que acontecimento dramático ocorreu no céu após o Reino ser estabelecido?',
        '4. Por que as condições mundiais pioraram tanto a partir de 1914',
        '5. Os sinais profetizados por Jesus cumprindo-se com precisão na Terra',
        '6. A certeza consolidada de que estamos vivendo nos últimos dias deste sistema',
      ],
    ),
    LffLessonInfo(
      number: 33,
      title: 'O que o Reino de Deus vai fazer?',
      section: 2,
      pointTitles: [
        '1. O que vai acontecer com os governos corruptos e opressores da Terra?',
        '2. O que a Bíblia chama de Armagedom e por que não devemos temê-lo?',
        '3. Como o Reino de Deus vai restaurar a saúde perfeita e acabar com a velhice?',
        '4. A destruição total de toda injustiça, opressão e violência humana',
        '5. A restauração ecológica de todo o planeta num paraíso fértil e seguro',
        '6. Paz verdadeira, moradia digna, fartura de alimento e vida eterna para todos',
      ],
    ),
    LffLessonInfo(
      number: 34,
      title: 'Como podemos mostrar o nosso amor por Jeová?',
      section: 3,
      pointTitles: [
        '1. O que significa amar a Jeová com todo o nosso coração e alma?',
        '2. Por que a obediência aos mandamentos de Deus é a maior prova de amor?',
        '3. Como o amor leal nos protege contra ciladas e tentações do mundo?',
        '4. Conheça e valorize as leis justas que Deus nos dá para o nosso bem',
        '5. Como a alegria de servir a Deus supera qualquer dificuldade pessoal',
        '6. Expressar gratidão constante pela generosidade e paciência de Jeová',
      ],
    ),
    LffLessonInfo(
      number: 35,
      title: 'Como podemos tomar boas decisões?',
      section: 3,
      pointTitles: [
        '1. Que guia confiável Deus colocou à nossa disposição para fazermos escolhas?',
        '2. Qual é a diferença essencial entre uma lei bíblica direta e um princípio bíblico?',
        '3. Como podemos treinar e educar a nossa consciência pela Bíblia?',
        '4. O processo de orar e pesquisar antes de tomar decisões importantes',
        '5. Como respeitar a consciência de outros quando houver opiniões diferentes',
        '6. As bênçãos duradouras de tomar decisões que agradam ao Criador',
      ],
    ),
    LffLessonInfo(
      number: 36,
      title: 'Sempre seja honesto',
      section: 3,
      pointTitles: [
        '1. O que significa ser honesto em todas as circunstâncias da vida?',
        '2. Como praticar a honestidade no trabalho, nos negócios e nos impostos?',
        '3. Por que a honestidade deve reinar no casamento e dentro da família?',
        '4. O que a Bíblia ensina sobre mentiras, roubos e práticas fraudulentas',
        '5. Os benefícios de manter uma consciência limpa e uma boa reputação',
        '6. Como a nossa honestidade reflete a justiça e glorifica a Jeová',
      ],
    ),
    LffLessonInfo(
      number: 37,
      title: 'O que a Bíblia diz sobre trabalho e dinheiro?',
      section: 3,
      pointTitles: [
        '1. Como desenvolver um ponto de vista equilibrado e digno sobre o trabalho?',
        '2. O que a Bíblia alerta sobre os perigos do materialismo e da ganância?',
        '3. Como aprender a estar contente com o sustento e o abrigo necessários?',
        '4. Trabalhar com dedicação como se estivesse fazendo para Jeová',
        '5. A armadilha de colocar o dinheiro ou bens materiais em primeiro lugar',
        '6. A promessa inabalável de que Deus nunca abandona os que o servem fielmente',
      ],
    ),
    LffLessonInfo(
      number: 38,
      title: 'Dê valor ao presente da vida',
      section: 3,
      pointTitles: [
        '1. Por que a vida humana é preciosa e sagrada aos olhos do Criador?',
        '2. Qual é o ponto de vista bíblico equilibrado sobre a preservação da saúde?',
        '3. O que a Bíblia ensina sobre o respeito à vida antes mesmo do nascimento?',
        '4. Medidas de segurança e prudência no trânsito, trabalho e recreação',
        '5. Por que rejeitar a violência, esportes perigosos e ódio contra outros',
        '6. Como demonstrar apreço profundo pela dádiva da vida a cada dia',
      ],
    ),
    LffLessonInfo(
      number: 39,
      title: 'O ponto de vista de Deus sobre o sangue',
      section: 3,
      pointTitles: [
        '1. Por que o sangue representa a própria vida aos olhos de Deus?',
        '2. Que ordem clara e repetida as Escrituras dão sobre abster-se de sangue?',
        '3. Como a lei divina sobre o sangue se aplica a procedimentos médicos hoje?',
        '4. A ordem bíblica dada a Noé e reiterada aos cristãos em Atos 15',
        '5. As excelentes opções de tratamentos médicos e cirurgias sem sangue',
        '6. A importância de preencher e portar a diretiva médica antecipada',
      ],
    ),
    LffLessonInfo(
      number: 40,
      title: 'Como podemos ser limpos aos olhos de Deus?',
      section: 3,
      pointTitles: [
        '1. Por que a limpeza em todos os sentidos agrada tanto a Jeová?',
        '2. O que envolve manter a pureza física e cuidar bem do nosso lar e aparência?',
        '3. Como podemos manter nossos pensamentos puros e nossa mente limpa?',
        '4. Evitar práticas prejudiciais, vícios, fumo e abuso de substâncias',
        '5. A importância de rejeitar a imoralidade e conversas obscenas',
        '6. A limpeza espiritual: adorar a Deus sem contaminação com rituais pagãos',
      ],
    ),
    LffLessonInfo(
      number: 41,
      title: 'O que a Bíblia diz sobre sexo?',
      section: 3,
      pointTitles: [
        '1. Como Jeová criou a intimidade sexual e com que limites amorosos?',
        '2. Por que o relacionamento sexual só é digno e honroso dentro do casamento?',
        '3. O que a Bíblia define pelo termo imoralidade sexual (porneia)?',
        '4. A proteção que a obediência às leis morais traz para o coração e para a família',
        '5. Os perigos mortais da pornografia e como fugir de tentações imorais',
        '6. Como manter uma conduta casta, honrosa e respeitosa em todas as relações',
      ],
    ),
    LffLessonInfo(
      number: 42,
      title: 'O que a Bíblia diz sobre se casar e ficar solteiro?',
      section: 3,
      pointTitles: [
        '1. Como o estado de solteiro pode ser encarado como um dom para servir mais a Deus?',
        '2. Que qualidades buscar ao escolher um cônjuge para a vida inteira?',
        '3. Por que a Bíblia aconselha a casar-se \'somente no Senhor\'?',
        '4. Como a pessoa solteira pode usar sua liberdade para avançar no ministério',
        '5. O namoro cristão com propósito sério, dignidade e pureza moral',
        '6. O casamento como um pacto sagrado e permanente diante do Criador',
      ],
    ),
    LffLessonInfo(
      number: 43,
      title: 'O que a Bíblia diz sobre as bebidas alcoólicas?',
      section: 3,
      pointTitles: [
        '1. Será que a Bíblia proíbe o consumo moderado de bebidas alcoólicas?',
        '2. O que as Escrituras advertem expressamente sobre a bebedeira e os excessos?',
        '3. Em que situações pessoais o cristão decide sensatamente não beber?',
        '4. O equilíbrio e a moderação que devem governar todas as nossas escolhas',
        '5. Os estragos familiares, emocionais e físicos causados pelo álcool em excesso',
        '6. Como respeitar a decisão e a consciência de quem prefere se abster totalmente',
      ],
    ),
    LffLessonInfo(
      number: 44,
      title: 'Será que todos os feriados agradam a Deus?',
      section: 3,
      pointTitles: [
        '1. Como podemos saber se um feriado ou celebração agrada ou ofende a Deus?',
        '2. O que a história revela sobre a origem de muitas festividades populares?',
        '3. Como podemos explicar nossas decisões religiosas a parentes e colegas com respeito?',
        '4. Festas pagãs associadas ao espiritismo, idolatria e superstição',
        '5. Como manter a paz na família mesmo sem participar de celebrações antibíblicas',
        '6. A verdadeira alegria de dar presentes e comemorar momentos especiais a qualquer época',
      ],
    ),
    LffLessonInfo(
      number: 45,
      title: 'O que significa ser neutro?',
      section: 3,
      pointTitles: [
        '1. Por que os verdadeiros seguidores de Cristo não se envolvem na política?',
        '2. Como manter a neutralidade e ao mesmo tempo ser um cidadão respeitador das leis?',
        '3. Como o cristão deve agir quando exigências governamentais colidem com a lei de Deus?',
        '4. O exemplo notável de Jesus ao recusar tronos e facções deste mundo',
        '5. Pagar impostos com honestidade e honrar as autoridades constituídas',
        '6. Como permanecer inabalavelmente leal ao Reino celestial em tempos de guerra',
      ],
    ),
    LffLessonInfo(
      number: 46,
      title: 'Por que se dedicar a Jeová e ser batizado?',
      section: 3,
      pointTitles: [
        '1. O que é a oração solene de dedicação a Jeová Deus?',
        '2. Como a dedicação e o batismo em água se complementam?',
        '3. Que motivos amorosos impulsionam a pessoa a tomar essa nobre decisão?',
        '4. Vencer o medo do fracasso e confiar inteiramente no apoio de Deus',
        '5. A oração de entrega pessoal exclusiva a Jeová como Soberano',
        '6. As bênçãos inestimáveis de pertencer para sempre ao Criador amoroso',
      ],
    ),
    LffLessonInfo(
      number: 47,
      title: 'Você está pronto para ser batizado?',
      section: 3,
      pointTitles: [
        '1. O que é necessário para a pessoa ser considerada pronta para o batismo?',
        '2. Como funciona a consideração bíblica amorosa com os anciãos da congregação?',
        '3. O que acontece no dia do batismo e que compromisso vital ele representa?',
        '4. A importância de conhecer as doutrinas fundamentais e viver em harmonia com elas',
        '5. O procedimento solene do batismo bíblico por imersão completa',
        '6. O início abençoado de uma jornada eterna de serviço zeloso a Jeová',
      ],
    ),
    LffLessonInfo(
      number: 48,
      title: 'Escolha bem os amigos',
      section: 4,
      pointTitles: [
        '1. Como as pessoas com quem convivemos moldam a nossa personalidade?',
        '2. Por que a Bíblia avisa que \'más companhias corrompem bons hábitos\'?',
        '3. Onde e como podemos encontrar amigos leais que amam a Jeová de verdade?',
        '4. O perigo das amizades virtuais e com pessoas que desrespeitam as normas divinas',
        '5. Construir amizades profundas, duradouras e edificantes na congregação',
        '6. Como ser um amigo leal, confiável e consolador nos momentos de aflição',
      ],
    ),
    LffLessonInfo(
      number: 49,
      title: 'Como ter uma família feliz? — Parte 1',
      section: 4,
      pointTitles: [
        '1. Qual é o papel amoroso do marido como chefe de família?',
        '2. Como a esposa sábia apoia o marido e ganha o profundo respeito do lar?',
        '3. Como marido e esposa podem manter a comunicação aberta e resolver atritos?',
        '4. O exemplo supremo de Jesus em amar e cuidar da congregação',
        '5. O respeito mútuo, a fidelidade inegociável e o carinho diário no casamento',
        '6. O poder do perdão sincero para manter a paz conjugal ao longo dos anos',
      ],
    ),
    LffLessonInfo(
      number: 50,
      title: 'Como ter uma família feliz? — Parte 2',
      section: 4,
      pointTitles: [
        '1. Que responsabilidade sagrada os pais receberam para instruir os filhos?',
        '2. Como os pais podem disciplinar com amor, consistência e paciência?',
        '3. Como os filhos devem honrar e obedecer aos pais no Senhor?',
        '4. O valor indispensável da Adoração em Família semanal com criatividade',
        '5. Proteger os filhos contra perigos morais, más companhias e abusos',
        '6. Criar um ambiente acolhedor onde reina o amor, o diálogo e a confiança',
      ],
    ),
    LffLessonInfo(
      number: 51,
      title: 'Como agradar a Jeová pelo modo como falamos?',
      section: 4,
      pointTitles: [
        '1. Que poder imenso têm as palavras que saem da nossa boca?',
        '2. O que a Bíblia ensina sobre usar a língua para curar, edificar e consolar?',
        '3. Que tipos de linguagem, piadas ou expressões devemos evitar a todo custo?',
        '4. Fugir de fofocas maldosas, boatos difamatórios e calúnias',
        '5. Falar com brandura, tato e calma mesmo quando provocados por outros',
        '6. Usar a fala para louvar a Jeová na oração e na proclamação das boas novas',
      ],
    ),
    LffLessonInfo(
      number: 52,
      title: 'Por que é importante pensar na nossa roupa e aparência?',
      section: 4,
      pointTitles: [
        '1. Como o nosso modo de vestir reflete o respeito que temos por Jeová?',
        '2. O que os princípios bíblicos ensinam sobre modéstia e bom senso no vestuário?',
        '3. Como a nossa aparência no ministério e nas reuniões dá bom testemunho?',
        '4. Evitar estilos provocantes, desleixados ou que imitam o espírito rebelde do mundo',
        '5. Respeitar a sensibilidade e a consciência dos irmãos e do público',
        '6. Vestir-se com elegância e decência de modo a glorificar o nome de Deus',
      ],
    ),
    LffLessonInfo(
      number: 53,
      title: 'Como escolher bem as diversões?',
      section: 4,
      pointTitles: [
        '1. Que diversões são sadias e realmente revigoram a mente e o corpo?',
        '2. Por que devemos rejeitar filmes, músicas e jogos que promovem violência ou imoralidade?',
        '3. Como controlar o tempo gasto com diversão para não sufocar as coisas espirituais?',
        '4. O princípio bíblico de \'odiar o que é mau\' na escolha do entretenimento',
        '5. Os perigos ocultos de produções com feitiçaria, magia ou ocultismo',
        '6. Desfrutar de momentos felizes de recreação que aproximam a família e os amigos',
      ],
    ),
    LffLessonInfo(
      number: 54,
      title: 'O que “o escravo fiel e prudente” faz?',
      section: 4,
      pointTitles: [
        '1. Quem foi designado por Jesus para fornecer alimento espiritual no tempo devido?',
        '2. Como o Corpo Governante coordena a pregação mundial e as publicações bíblicas?',
        '3. Por que podemos confiar plenamente na orientação bíblica desse canal espiritual?',
        '4. A profecia de Mateus 24:45-47 e seu cumprimento moderno desde 1919',
        '5. Como o alimento espiritual fortalece congregações em todo o globo terrestre',
        '6. Apoiar de coração as orientações teocráticas providas para nossa proteção',
      ],
    ),
    LffLessonInfo(
      number: 55,
      title: 'Apoie a sua congregação',
      section: 4,
      pointTitles: [
        '1. Como podemos apoiar ativamente a congregação por meio de comentários e partes?',
        '2. De que maneira todos podem colaborar na limpeza e conservação do Salão do Reino?',
        '3. Como o arranjo de donativos voluntários apoia a obra local e mundial?',
        '4. A importância de chegar pontualmente às reuniões e encorajar os presentes',
        '5. Ajudar os idosos, os doentes e as famílias necessitadas na congregação',
        '6. Dar com generosidade alegre sem qualquer tipo de constrangimento ou dízimo',
      ],
    ),
    LffLessonInfo(
      number: 56,
      title: 'Faça sua parte para manter a união',
      section: 4,
      pointTitles: [
        '1. Por que a união fraternal entre o povo de Deus é tão preciosa e rara?',
        '2. O que a Bíblia instrui sobre perdoar de coração as imperfeições dos irmãos?',
        '3. Que passos bíblicos amorosos seguir se surgir um mal-entendido pessoal grave?',
        '4. O conselho de Jesus em Mateus 18:15-17 para resolver ofensas em particular',
        '5. Vencer o ressentimento, a mágoa e o orgulho antes que causem divisões',
        '6. Promover a paz ativa e o vínculo perfeito de amor que une a fraternidade',
      ],
    ),
    LffLessonInfo(
      number: 57,
      title: 'E se você cometer um pecado grave?',
      section: 4,
      pointTitles: [
        '1. O que a pessoa deve fazer de imediato se tropeçar num erro espiritual grave?',
        '2. Como os anciãos atuam como pastores amorosos para curar e reajustar espiritualmente?',
        '3. O que a Bíblia ensina sobre o arrependimento genuíno e a misericórdia de Jeová?',
        '4. O perigo de tentar esconder o pecado e endurecer o coração',
        '5. A disciplina bíblica como demonstração do amor e da justiça purificadora de Deus',
        '6. A certeza consoladora de que Jeová perdoa amplamente quem se arrepende com sinceridade',
      ],
    ),
    LffLessonInfo(
      number: 58,
      title: 'Continue leal a Jeová',
      section: 4,
      pointTitles: [
        '1. O que significa demonstrar lealdade inabalável a Jeová em toda e qualquer provação?',
        '2. Como agir com sabedoria e fidelidade se alguém próximo abandonar a verdade?',
        '3. Por que rejeitar sem hesitação a apostasia e as mentiras espalhadas por opositores?',
        '4. O valor de manter a integridade pessoal quando nossa fé é colocada à prova',
        '5. Como a Palavra de Deus e a oração fortalecem o coração leal contra desvios',
        '6. A promessa gloriosa de Jeová: \'Com quem é leal, tu ages com lealdade\'',
      ],
    ),
    LffLessonInfo(
      number: 59,
      title: 'Enfrente perseguição com coragem!',
      section: 4,
      pointTitles: [
        '1. Por que os verdadeiros discípulos de Cristo sabem que enfrentarão perseguição?',
        '2. Como podemos fortalecer a nossa fé com antecedência para não temer os homens?',
        '3. Que consolo temos ao saber que Jeová nos dará forças que vão além do normal?',
        '4. O exemplo inspirador dos profetas, dos apóstolos e dos cristãos do primeiro século',
        '5. Como manter a integridade sob proscrição, prisões ou difamação pública',
        '6. A coroa da vida e a felicidade eterna garantidas aos que perseveram até o fim',
      ],
    ),
    LffLessonInfo(
      number: 60,
      title: 'Continue a fortalecer sua amizade com Jeová',
      section: 4,
      pointTitles: [
        '1. Que excelentes hábitos espirituais você deve manter com zelo para sempre?',
        '2. Que novos alvos teocráticos você pode estabelecer no ministério e na congregação?',
        '3. Como você pode ajudar outras pessoas sinceras a também se tornarem amigas de Deus?',
        '4. Manter vivo o amor fervoroso que você sentiu ao aprender as verdades bíblicas',
        '5. Expandir seu serviço sagrado como pioneiro auxiliar, pioneiro regular ou onde houver mais necessidade',
        '6. A perspectiva radiante de desfrutar de uma vida verdadeiramente feliz para sempre com Jeová!',
      ],
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
        label = 'Próximo: Revisão da Seção 1 (Lições 01 a 12) ou Lição 13';
      } else if (currentLesson == 33) {
        label = 'Próximo: Revisão da Seção 2 (Lições 13 a 33) ou Lição 34';
      } else if (currentLesson == 47) {
        label = 'Próximo: Revisão da Seção 3 (Lições 34 a 47) ou Lição 48';
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
        category: 'Lições do Livro (Seção ${l.section})',
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
