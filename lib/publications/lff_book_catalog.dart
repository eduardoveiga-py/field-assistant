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
/// Extraído com 100% de exatidão diretamente da publicação oficial lff (EPUB/JW Library)
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
        '1. Quais são algumas perguntas que a Bíblia responde?',
        '2. Como a Bíblia pode nos ajudar a ser mais felizes no dia a dia?',
        '3. A Bíblia pode guiar nosso caminho',
        '4. A Bíblia pode responder a nossas perguntas',
        '5. Você pode gostar de ler a Bíblia',
        '6. Outras pessoas podem nos ajudar a entender a Bíblia',
      ],
      somePeopleSay: 'Estudar a Bíblia é uma perda de tempo.',
      summary: 'A Bíblia dá conselhos para o dia a dia, responde a perguntas importantes e traz consolo e esperança.',
      reviewQuestions: [
        'Sobre que assuntos a Bíblia dá conselhos?',
        'Quais são algumas perguntas que a Bíblia responde?',
        'O que você gostaria de aprender da Bíblia?',
      ],
      tryThis: 'Ler a primeira parte da próxima lição.',
    ),
    LffLessonInfo(
      number: 2,
      title: 'A Bíblia nos dá esperança',
      section: 1,
      pointTitles: [
        '1. Que esperança a Bíblia nos dá?',
        '2. Qual é a promessa da Bíblia para o futuro?',
        '3. Como você pode ter certeza de que tudo que a Bíblia diz vai acontecer?',
        '4. A Bíblia promete que podemos viver para sempre sem sofrimento',
        '5. As promessas da Bíblia podem fazer a diferença na sua vida',
      ],
      somePeopleSay: 'As promessas da Bíblia para o futuro são boas demais para ser verdade.',
      summary: 'A Bíblia nos dá esperança. E saber que ela promete um futuro feliz nos ajuda a enfrentar os problemas.',
      reviewQuestions: [
        'Por que as pessoas precisam de esperança?',
        'O que a Bíblia diz sobre o futuro?',
        'Como a esperança da Bíblia pode fazer a diferença na sua vida?',
      ],
      tryThis: 'Ler de novo as passagens bíblicas desta lição para conhecer melhor as promessas da Bíblia.',
    ),
    LffLessonInfo(
      number: 3,
      title: 'Será que você pode acreditar na Bíblia?',
      section: 1,
      pointTitles: [
        '1. Será que as histórias da Bíblia aconteceram mesmo?',
        '2. Por que podemos dizer que a Bíblia é de confiança apesar de ser tão antiga?',
        '3. Por que podemos acreditar no que a Bíblia diz para o futuro?',
        '4. A ciência concorda com a Bíblia',
        '5. A Bíblia falou com antecedência sobre acontecimentos importantes',
        '6. A Bíblia já falava sobre as coisas que vemos hoje',
      ],
      somePeopleSay: 'A Bíblia não passa de um livro de lendas e histórias inventadas.',
      summary: 'A História, a ciência e as profecias mostram que você pode acreditar na Bíblia.',
      reviewQuestions: [
        'Será que as histórias da Bíblia aconteceram mesmo?',
        'Quais são alguns exemplos de que a ciência concorda com a Bíblia?',
        'Você acredita que a Bíblia pode dizer o que vai acontecer no futuro? Por que você acha isso?',
      ],
      tryThis: 'Para aumentar sua confiança na Bíblia, leia um dos artigos ou assista ao vídeo da seção “Quer Pesquisar Mais?”.',
    ),
    LffLessonInfo(
      number: 4,
      title: 'Quem é Deus?',
      section: 1,
      pointTitles: [
        '1. Qual é o nome de Deus? E o que mostra que ele quer que a gente conheça o nome dele?',
        '2. O que a Bíblia diz sobre Jeová?',
        '3. Deus tem muitos títulos, mas apenas um nome',
        '4. Jeová quer que você conheça e use o nome dele',
        '5. Jeová quer que você se aproxime mais dele',
      ],
      somePeopleSay: 'Deus é um só. Então, não faz diferença o jeito que você chama a ele.',
      summary: 'Jeová é o nome do único Deus verdadeiro. Ele quer que a gente se aproxime mais dele. Por isso, é importante conhecer e usar o nome de Jeová.',
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
        '3. Como Jeová protegeu a Bíblia?',
        '4. A Bíblia diz quem é o seu Autor',
        '5. A Bíblia sofreu muitos ataques, mas ela sobreviveu',
        '6. Um livro para todas as pessoas',
      ],
      somePeopleSay: 'A Bíblia é só um livro antigo escrito por homens.',
      summary: 'A Bíblia é a Palavra de Deus, e ele fez questão de que ela estivesse disponível para todas as pessoas.',
      reviewQuestions: [
        'Quando a Bíblia diz que Deus inspirou homens para escreverem a Bíblia, o que isso quer dizer?',
        'O que mais chama a sua atenção sobre a tradução e distribuição da Bíblia? E o que você acha de a Bíblia ter sobrevivido a tantos ataques?',
        'Como você se sente ao saber de todo o esforço que Deus fez para transmitir a mensagem dele para você?',
      ],
      tryThis: 'Começar a ler a Bíblia todos os dias usando o quadro “Comece sua leitura da Bíblia”.',
    ),
    LffLessonInfo(
      number: 6,
      title: 'Como a vida começou?',
      section: 1,
      pointTitles: [
        '1. Como o Universo começou?',
        '2. Por que Deus criou a Terra?',
        '3. O que faz os humanos serem diferentes dos animais?',
        '4. A vida teve um projeto',
        '5. Tudo o que a Bíblia diz sobre a criação faz sentido',
        '6. Os humanos são uma criação especial de Deus',
      ],
      somePeopleSay: 'O que a Bíblia diz sobre a criação não é verdade. É só uma história inventada.',
      summary: 'Jeová criou o Universo e todos os seres vivos.',
      reviewQuestions: [
        'O que a Bíblia ensina sobre como o Universo começou?',
        'Será que Deus usou a evolução para formar todas as espécies? Ou ele criou todas elas?',
        'O que faz os humanos serem tão especiais?',
      ],
      tryThis: 'Ler um artigo ou ver um vídeo da seção “Teve um Projeto?” no jw.org.',
    ),
    LffLessonInfo(
      number: 7,
      title: 'Conheça mais a Jeová',
      section: 1,
      pointTitles: [
        '1. Por que não conseguimos ver a Deus?',
        '2. Que qualidades Jeová tem?',
        '3. Como Jeová mostra que nos ama?',
        '4. O espírito santo é a força ativa de Deus',
        '5. Jeová tem qualidades maravilhosas',
        '6. Jeová se importa com as pessoas',
        '7. A natureza nos ensina sobre as qualidades de Jeová',
      ],
      somePeopleSay: 'Deus é uma força que está em todo lugar. Ele não é como a gente, que pensa e tem sentimentos.',
      summary: 'Não podemos ver a Jeová porque ele é espírito. Ele tem muitas qualidades, e a principal é o amor.',
      reviewQuestions: [
        'Por que não conseguimos ver a Jeová?',
        'O que é o espírito santo?',
        'Quais são algumas qualidades de Jeová?',
      ],
      tryThis: 'Ler o Salmo 23. Depois, pare e pense: ‘O que essa passagem da Bíblia me ensina sobre as qualidades de Jeová?’',
    ),
    LffLessonInfo(
      number: 8,
      title: 'Você pode ser amigo de Jeová',
      section: 1,
      pointTitles: [
        '1. Que convite Jeová faz a você?',
        '2. Por que Jeová é o melhor Amigo que você pode ter?',
        '3. O que Jeová espera dos amigos dele?',
        '4. Abraão era amigo de Jeová',
        '5. O que Jeová espera de quem é amigo dele',
        '6. O que Jeová faz pelos amigos dele',
        '7. Para ser amigo de Jeová, precisamos falar com ele e ouvir o que ele diz',
      ],
      somePeopleSay: 'É impossível ser amigo de Deus.',
      summary: 'Jeová quer ser seu Amigo, e ele vai te ajudar a se aproximar mais dele.',
      reviewQuestions: [
        'Como Jeová ajuda os amigos dele?',
        'Por que Jeová pede que seus amigos façam mudanças na vida?',
        'Você acha que é muito difícil ser amigo de Jeová? Por que você acha isso?',
      ],
      tryThis: 'Contar para um amigo alguma coisa que você aprendeu sobre Jeová.',
    ),
    LffLessonInfo(
      number: 9,
      title: 'A oração fortalece sua amizade com Deus',
      section: 1,
      pointTitles: [
        '1. Para quem devemos orar, e sobre o quê?',
        '2. Como devemos orar?',
        '3. Como Deus responde nossas orações?',
        '4. O que fazer para Deus ouvir nossas orações',
        '5. Nossas orações devem ser feitas de coração',
        '6. A oração é um presente de Deus',
        '7. Tire tempo para orar',
      ],
      somePeopleSay: 'A oração é só uma forma de as pessoas se sentirem bem, mas não adianta nada.',
      summary: 'As orações feitas de coração podem nos aproximar mais de Deus, nos dar paz mental e nos dar a força que precisamos para agradar a Jeová.',
      reviewQuestions: [
        'Para quem devemos orar?',
        'Como devemos orar?',
        'Como a oração pode nos ajudar?',
      ],
      tryThis: 'Nas suas orações, ore sobre alguma coisa (1) que preocupa você, (2) que você pode agradecer a Jeová e (3) que você pode pedir por outra pessoa.',
    ),
    LffLessonInfo(
      number: 10,
      title: 'Como as reuniões das Testemunhas de Jeová podem ajudar você?',
      section: 1,
      pointTitles: [
        '1. Qual o principal objetivo das reuniões das Testemunhas de Jeová?',
        '2. O que você vai aprender nas nossas reuniões?',
        '3. Por que vai ser bom você conhecer outras pessoas nas reuniões?',
        '4. Conheça as reuniões das Testemunhas de Jeová',
        '5. É preciso esforço para ir às reuniões',
      ],
      somePeopleSay: 'Você não precisa sair de casa para adorar a Deus. Ler a Bíblia sozinho já é o suficiente.',
      summary: 'Ir às reuniões vai ajudar você a aprender mais sobre Jeová e tornar sua amizade com ele mais forte. Além disso, as reuniões vão dar a você a oportunidade de adorar a Deus junto com outras pessoas.',
      reviewQuestions: [
        'Por que Jeová quer que a gente vá às reuniões?',
        'O que você vai aprender nas reuniões das Testemunhas de Jeová?',
        'Consegue pensar em mais uma maneira em que as reuniões podem te ajudar?',
      ],
      tryThis: 'Ir a uma reunião e conhecer algumas das pessoas que estão lá.',
    ),
    LffLessonInfo(
      number: 11,
      title: 'Como você pode aproveitar ao máximo a leitura da Bíblia?',
      section: 1,
      pointTitles: [
        '1. Por que é importante ler a Bíblia regularmente?',
        '2. Como você pode aproveitar ao máximo sua leitura da Bíblia?',
        '3. Como você pode encontrar tempo para ler a Bíblia?',
        '4. Aprenda a gostar de ler a Bíblia',
        '5. Prepare-se para seu estudo da Bíblia',
      ],
      somePeopleSay: 'Estudar a Bíblia é muito difícil. Além disso, meu dia é corrido e eu fico muito cansado.',
      summary: 'Para aproveitar ao máximo o que a Palavra de Deus diz, separe um tempo para ler a Bíblia, ore para entender o que você está lendo e se prepare bem para cada estudo.',
      reviewQuestions: [
        'O que vai ajudar você a aproveitar ao máximo o que a Bíblia ensina?',
        'Quando você poderia tirar um tempo para ler e estudar a Bíblia?',
        'Por que vale a pena se preparar para seu estudo da Bíblia?',
      ],
      tryThis: 'Prepare-se para o seu próximo estudo usando as sugestões desta lição.',
    ),
    LffLessonInfo(
      number: 12,
      title: 'O que vai ajudar você a continuar estudando a Bíblia?',
      section: 1,
      pointTitles: [
        '1. Por que estudar a Bíblia é tão importante?',
        '2. Por que é importante dar valor ao que a Bíblia ensina?',
        '3. Como Jeová pode ajudar você a continuar seu estudo?',
        '4. Mostre que o estudo da Bíblia é muito importante para você',
        '5. Não deixe que outros façam você desistir',
        '6. Confie que Jeová vai ajudar você',
      ],
      summary: 'É verdade que estudar a Bíblia tem seus desafios. Mas fazer isso vai ajudar você a ser feliz para sempre. Continue confiando em Jeová, e ele vai abençoar você.',
      reviewQuestions: [
        'Por que as verdades da Bíblia são um tesouro para você?',
        'Como você pode mostrar que dá valor às “coisas mais importantes”?',
        'Por que você deve pedir ajuda a Jeová para continuar seu estudo da Bíblia?',
      ],
      tryThis: 'Ter seu estudo da Bíblia pelo menos uma vez na semana. Se acontecer um imprevisto, remarque para outro dia.',
    ),
    // === Parte 2: Conheça a Jeová, a Jesus e o propósito deles (Lições 13 a 33) ===
    LffLessonInfo(
      number: 13,
      title: 'Como as religiões falsas afastam as pessoas de Deus?',
      section: 2,
      pointTitles: [
        '1. Como as religiões falsas afastam as pessoas de Deus por meio do que ensinam?',
        '2. Como as religiões falsas afastam as pessoas de Deus por meio do que fazem?',
        '3. O que Deus pensa sobre as religiões falsas?',
        '4. Deus não aceita todas as religiões',
        '5. As religiões falsas não mostram o amor de Deus',
        '6. Deus quer tirar as pessoas das religiões falsas',
        '7. Continue aprendendo sobre o Deus verdadeiro',
      ],
      somePeopleSay: 'Eu não quero saber de religião; elas só dão problemas.',
      summary: 'As religiões falsas afastam as pessoas de Deus. Elas fazem isso por ensinar coisas erradas e fazer coisas ruins. Deus vai destruir as religiões falsas.',
      reviewQuestions: [
        'O que você acha do que as religiões falsas ensinam e fazem?',
        'O que Jeová pensa sobre as religiões falsas?',
        'O que Deus vai fazer com as religiões falsas?',
      ],
      tryThis: 'Na próxima reunião no Salão do Reino, pergunte a alguém: “Por que você se tornou Testemunha de Jeová?”',
    ),
    LffLessonInfo(
      number: 14,
      title: 'O que temos que fazer para Deus aceitar nossa adoração?',
      section: 2,
      pointTitles: [
        '1. Nossa adoração deve se basear em quê?',
        '2. Como devemos adorar a Jeová?',
        '3. Por que devemos adorar a Jeová junto com outras pessoas?',
        '4. Não devemos usar imagens para adorar a Deus',
        '5. Adorar apenas a Jeová nos livra de ensinos falsos',
        '6. Nós adoramos a Deus nas reuniões no Salão do Reino',
        '7. Jeová fica feliz quando falamos a outros o que aprendemos',
      ],
      somePeopleSay: 'Não importa a maneira que a gente adora a Deus. O importante é que seja de coração.',
      summary: 'Deixamos nosso Criador feliz quando adoramos apenas a ele, louvamos a ele nas reuniões e falamos a outros o que aprendemos.',
      reviewQuestions: [
        'Como podemos aprender a adorar a Deus do jeito que ele acha certo?',
        'Por que devemos adorar apenas a Jeová?',
        'Por que devemos adorar a Deus junto com outros que querem fazer a vontade dele?',
      ],
      tryThis: 'Comentar em uma reunião.',
    ),
    LffLessonInfo(
      number: 15,
      title: 'Quem é Jesus?',
      section: 2,
      pointTitles: [
        '1. Quem é Jesus?',
        '2. Por que Jesus veio à Terra?',
        '3. Onde Jesus está agora?',
        '4. Jesus não é o Deus Todo-Poderoso',
        '5. Provas de que Jesus era o Messias',
        '6. Aprender sobre Jesus é muito bom para nós',
      ],
      somePeopleSay: 'As Testemunhas de Jeová não acreditam em Jesus.',
      summary: 'Jesus é um anjo poderoso. Ele é o Filho de Deus e o Messias.',
      reviewQuestions: [
        'Por que Jesus é chamado de “o primogênito de toda a criação”?',
        'O que Jesus fez antes de vir à Terra?',
        'Como sabemos que Jesus é o Messias?',
      ],
      tryThis: 'Assistir ao vídeo “Tenha a plena certeza de que Deus o fez Senhor e Cristo” — Parte I ou ler Lucas capítulos 2 e 3 para aprender mais sobre a vida de Jesus na Terra.',
    ),
    LffLessonInfo(
      number: 16,
      title: 'O que Jesus fez quando esteve na Terra?',
      section: 2,
      pointTitles: [
        '1. Qual era o trabalho mais importante de Jesus?',
        '2. Por que Jesus fazia milagres?',
        '3. O que podemos aprender da vida de Jesus?',
        '4. Jesus pregava as boas novas',
        '5. Jesus ensinou verdades muito importantes',
        '6. Jesus fez milagres',
      ],
      somePeopleSay: 'Jesus não era o Filho de Deus; era apenas uma pessoa boa.',
      summary: 'Jesus pregou sobre o Reino de Deus, fez milagres e obedeceu a Jeová em tudo.',
      reviewQuestions: [
        'Qual foi o trabalho mais importante de Jesus na Terra?',
        'O que os milagres de Jesus provam?',
        'Que conselhos muito bons Jesus deu?',
      ],
      tryThis: 'Assistir ao vídeo “Tenha a plena certeza de que Deus o fez Senhor e Cristo” — Parte II ou ler Mateus capítulos 5 a 7 para aprender mais sobre o que Jesus fez na Terra.',
    ),
    LffLessonInfo(
      number: 17,
      title: 'Que tipo de pessoa é Jesus?',
      section: 2,
      pointTitles: [
        '1. Em que sentido Jesus é como seu Pai, Jeová?',
        '2. Como Jesus mostrou que ama Jeová?',
        '3. Como Jesus mostrou que ama as pessoas?',
        '4. Jesus ama seu Pai',
        '5. Jesus se importa com as pessoas que precisam de ajuda',
        '6. Jesus é generoso',
      ],
      somePeopleSay: 'Deus não liga para o sofrimento das pessoas.',
      summary: 'Jesus ama a Jeová e as pessoas. Já que Jesus é como seu Pai, quanto mais você conhecer a Jesus, mais você vai conhecer a Jeová.',
      reviewQuestions: [
        'Como podemos imitar o amor de Jesus por Jeová?',
        'Como podemos imitar o amor de Jesus pelas pessoas?',
        'Que qualidades de Jesus você mais gostou?',
      ],
      tryThis: 'Escolher uma das qualidades de Jesus para imitar esta semana.',
    ),
    LffLessonInfo(
      number: 18,
      title: 'Como saber quem são os cristãos verdadeiros?',
      section: 2,
      pointTitles: [
        '1. O que é um cristão?',
        '2. Como os cristãos verdadeiros mostram amor?',
        '3. Os cristãos verdadeiros participam de que obra?',
        '4. Eles querem saber a verdade que está na Bíblia',
        '5. Eles pregam a verdade da Bíblia',
        '6. Eles fazem o que ensinam',
        '7. O amor entre eles é verdadeiro',
      ],
      somePeopleSay: 'Não importa a sua religião; o importante é acreditar em Jesus.',
      summary: 'Os cristãos verdadeiros obedecem ao que a Bíblia diz, mostram amor de verdade e pregam as boas novas da Bíblia.',
      reviewQuestions: [
        'Tudo o que os cristãos verdadeiros dizem e fazem está de acordo com o quê?',
        'Que qualidade mostra quem são os cristãos verdadeiros?',
        'Que obra os cristãos verdadeiros fazem?',
      ],
      tryThis: 'Se possível, visitar uma filial das Testemunhas de Jeová.',
    ),
    LffLessonInfo(
      number: 19,
      title: 'Será que as Testemunhas de Jeová são cristãos de verdade?',
      section: 2,
      pointTitles: [
        '1. As Testemunhas de Jeová baseiam suas crenças em quê?',
        '2. Por que temos o nome de Testemunhas de Jeová?',
        '3. Como as Testemunhas de Jeová imitam o amor que Jesus mostrou?',
        '4. Baseamos nossas crenças na Bíblia',
        '5. Testemunhas de Jeová: vivemos de acordo com o nosso nome',
        '6. Nós amamos uns aos outros',
      ],
      somePeopleSay: 'As Testemunhas de Jeová são só mais uma dessas religiões novas que surgiram.',
      summary: 'As Testemunhas de Jeová são cristãos de verdade. Somos uma família mundial de servos de Deus, baseamos nossas crenças na Bíblia e ensinamos a outros a verdade sobre Jeová.',
      reviewQuestions: [
        'Por que nós escolhemos o nome Testemunhas de Jeová?',
        'Como nós mostramos amor uns pelos outros?',
        'Você acha que as Testemunhas de Jeová são cristãos de verdade?',
      ],
      tryThis: 'Perguntar a uma Testemunha de Jeová: “O que convenceu você de que essa é a verdade?”',
    ),
    LffLessonInfo(
      number: 20,
      title: 'Como a congregação está organizada?',
      section: 2,
      pointTitles: [
        '1. Quem é o líder da congregação?',
        '2. Quem são os anciãos, e o que eles fazem?',
        '3. Que responsabilidade cada Testemunha de Jeová tem?',
        '4. Jesus é um líder bondoso',
        '5. Os anciãos ensinam dando o exemplo',
        '6. Podemos ajudar os anciãos',
      ],
      somePeopleSay: 'Você não precisa fazer parte de uma religião para adorar a Deus.',
      summary: 'Jesus é o líder da congregação, e os anciãos seguem as orientações dele. Ficamos felizes de ajudar os anciãos porque eles são bondosos e nos ensinam pelo exemplo que dão.',
      reviewQuestions: [
        'Quem é o líder da congregação?',
        'Como os anciãos ajudam a congregação?',
        'Qual é a responsabilidade de cada um na congregação?',
      ],
      tryThis: 'Na próxima reunião, perguntar a um ancião o que ele mais gosta do trabalho que faz na congregação.',
    ),
    LffLessonInfo(
      number: 21,
      title: 'Como as boas novas são pregadas?',
      section: 2,
      pointTitles: [
        '1. Como Mateus 24:14 está se cumprindo hoje?',
        '2. Como nos esforçamos para pregar às pessoas?',
        '3. Quem tem a responsabilidade de pregar as boas novas?',
        '4. Nós nos esforçamos bastante para pregar para todas as pessoas',
        '5. Somos colaboradores de Deus',
        '6. Obedecemos à ordem que Deus nos deu',
      ],
      summary: 'Jesus disse a seus discípulos para pregarem as boas novas em todas as nações. Jeová está ajudando o seu povo a fazer essa obra.',
      reviewQuestions: [
        'Como as boas novas estão sendo pregadas no mundo todo?',
        'Como nossa obra de pregação mostra que amamos as pessoas?',
        'Você acha que a obra de pregação pode trazer felicidade? Por quê?',
      ],
      tryThis: 'Perguntar a alguns irmãos no Salão do Reino: “Que desafios você teve que enfrentar para pregar as boas novas? Que bênçãos você recebeu por causa disso?”',
    ),
    LffLessonInfo(
      number: 22,
      title: 'Como você pode falar das boas novas para outros?',
      section: 2,
      pointTitles: [
        '1. Como você pode falar para outros sobre o que está aprendendo?',
        '2. Por que vale a pena pregar com a congregação?',
        '3. Jeová vai estar do seu lado',
        '4. Fale de modo bondoso',
        '5. Falar a outros sobre as boas novas dá alegria',
      ],
      somePeopleSay: 'E SE ALGUÉM PERGUNTAR: “Quais são as novidades?',
      summary: 'Falar sobre as boas novas para outros dá alegria e é mais fácil do que você imagina.',
      reviewQuestions: [
        'Por que falamos sobre as boas novas para outros?',
        'Como você pode fazer isso de modo bondoso?',
        'Como você pode vencer o medo de pregar?',
      ],
      tryThis: 'Escolher uma pessoa para falar sobre as boas novas. Pense no que dizer, como dizer e quando dizer.',
    ),
    LffLessonInfo(
      number: 23,
      title: 'Batismo — Um alvo que vale a pena ter!',
      section: 2,
      pointTitles: [
        '1. O que é o batismo?',
        '2. O que a pessoa mostra quando é batizada?',
        '3. Para poder se batizar, o que a pessoa tem que fazer?',
        '4. Aprendemos muito com o batismo de Jesus',
        '5. O batismo é um alvo que você pode alcançar',
        '6. Quando nos batizamos, nos tornamos parte da família de Jeová',
      ],
      somePeopleSay: 'Eu não estou pronto para me batizar.',
      summary: 'Jesus ensinou que os cristãos precisam se batizar. Para isso, a pessoa precisa ter forte fé em Jeová, viver de acordo com o que ele diz que é certo e dedicar sua vida a ele.',
      reviewQuestions: [
        'O que é o batismo, e por que ele é importante?',
        'O que a dedicação tem a ver com o batismo?',
        'Que coisas a pessoa precisa fazer antes de dedicar a vida a Jeová e ser batizada?',
      ],
      tryThis: 'Ver as listas “Estou pronto para pregar com a congregação?” e “Estou pronto para me batizar?” no final da parte 4. Nelas, você vai ver o que tem que fazer para pregar com a congregação e se batizar no futuro.',
    ),
    LffLessonInfo(
      number: 24,
      title: 'Quem são os anjos, e o que eles fazem?',
      section: 2,
      pointTitles: [
        '1. Quem são os anjos?',
        '2. Quem são Satanás e seus demônios?',
        '3. Como Satanás e os demônios tentam nos enganar?',
        '4. Os anjos ajudam as pessoas a aprender sobre Jeová',
        '5. Fique bem longe do ocultismo',
        '6. Vença a luta contra Satanás e seus demônios',
      ],
      somePeopleSay: 'Não tem problema nenhum jogar videogame ou ver filmes que tenham a ver com o ocultismo. É só uma diversão.',
      summary: 'Os anjos fiéis nos ajudam. Satanás e seus demônios são inimigos de Jeová e usam o ocultismo para enganar as pessoas.',
      reviewQuestions: [
        'Como os anjos ajudam as pessoas a aprender sobre Jeová?',
        'Quem são Satanás e seus demônios?',
        'Por que você quer ficar bem longe do ocultismo?',
      ],
      tryThis: 'Veja se você tem qualquer objeto ligado ao ocultismo e ore pedindo sabedoria para decidir o que fazer com eles.',
    ),
    LffLessonInfo(
      number: 25,
      title: 'Qual é o objetivo de Deus para nós?',
      section: 2,
      pointTitles: [
        '1. Que vida Jeová quer para nós?',
        '2. Como podemos ter uma vida feliz mesmo agora?',
        '3. Jeová quer que os humanos tenham uma vida maravilhosa',
        '4. O que Jeová quer para nós não mudou',
        '5. Adorar a Jeová dá verdadeiro sentido à nossa vida',
      ],
      summary: 'Jeová quer que a gente viva para sempre e tenha uma vida perfeita em todos os sentidos. Quando adoramos a Jeová de todo o nosso coração, nossa vida passa a ter verdadeiro significado, mesmo agora.',
      reviewQuestions: [
        'O que Jeová queria para Adão e Eva?',
        'Como sabemos que a vontade de Deus para os humanos não mudou?',
        'Como a sua vida pode ter verdadeiro sentido?',
      ],
      tryThis: 'Contar para alguém o futuro maravilhoso que Jeová promete para nós.',
    ),
    LffLessonInfo(
      number: 26,
      title: 'Por que a maldade e o sofrimento existem?',
      section: 2,
      pointTitles: [
        '1. Como surgiu a maldade no mundo?',
        '2. O que Adão e Eva decidiram fazer?',
        '3. Como a decisão de Adão e Eva afetou a nossa vida?',
        '4. O verdadeiro culpado pelo nosso sofrimento',
        '5. Veja os resultados do governo de Satanás',
        '6. Jeová se importa com o nosso sofrimento',
        '7. Deus vai acabar com todo o sofrimento',
      ],
      somePeopleSay: 'O sofrimento é um teste de Deus.',
      summary: 'Satanás, Adão e Eva são os principais culpados pela maldade no mundo. Jeová se importa muito com a gente e, em breve, ele vai acabar com todo o sofrimento.',
      reviewQuestions: [
        'Que mentira Satanás, o Diabo, contou para Eva?',
        'Como a decisão de Adão e Eva afetou a nossa vida?',
        'Como sabemos que Jeová se importa com o nosso sofrimento?',
      ],
      tryThis: 'Contar para alguém por que Deus não é o culpado pela maldade no mundo.',
    ),
    LffLessonInfo(
      number: 27,
      title: 'Como a morte de Jesus pode nos salvar?',
      section: 2,
      pointTitles: [
        '1. Como a morte de Jesus pode nos ajudar hoje?',
        '2. Como a morte de Jesus vai nos ajudar no futuro?',
        '3. O sacrifício de Jesus nos livra do pecado e da morte',
        '4. A morte de Jesus pode ajudar todas as pessoas',
        '5. O resgate é um presente de Jeová para você',
      ],
      summary: 'Por causa da morte de Jesus, Jeová pode perdoar nossos pecados. A morte de Jesus também nos dá a oportunidade de viver para sempre.',
      reviewQuestions: [
        'Por que Jesus teve que morrer?',
        'Como a vida perfeita de Jesus pôde ser um resgate correspondente por toda a humanidade?',
        'Como a morte de Jesus pode ajudar você?',
      ],
      tryThis: 'Não se esquecer de agradecer a Jeová nas suas orações por ter nos dado o Filho dele.',
    ),
    LffLessonInfo(
      number: 28,
      title: 'Como mostrar gratidão pelo que Jeová e Jesus fizeram por você',
      section: 2,
      pointTitles: [
        '1. Qual é uma maneira de mostrar que damos valor ao que Jeová e Jesus fizeram por nós?',
        '2. Que ocasião especial nos ajuda a mostrar gratidão pelo que Jeová e Jesus fizeram?',
        '3. Maneiras de mostrar gratidão',
        '4. Imite a Jesus',
        '5. Esteja presente na Celebração da morte de Cristo',
      ],
      somePeopleSay: 'Tudo que você tem que fazer para ser salvo é acreditar em Jesus.',
      summary: 'Mostramos que damos valor ao que Jesus fez por nós por exercer fé nele e por estar presentes na Celebração da sua morte.',
      reviewQuestions: [
        'O que significa exercer fé em Jesus?',
        'Como você gostaria de mostrar gratidão pelo que Jeová e Jesus fizeram por você?',
        'Por que é tão importante estar presente na Celebração da morte de Cristo?',
      ],
      tryThis: 'Estar presente na próxima Celebração da morte de Cristo. Pergunte ao seu instrutor da Bíblia em que dia vai ser e anote no seu calendário.',
    ),
    LffLessonInfo(
      number: 29,
      title: 'O que acontece quando a pessoa morre?',
      section: 2,
      pointTitles: [
        '1. O que acontece quando a pessoa morre?',
        '2. Como saber a verdade sobre a morte nos ajuda?',
        '3. Aprenda a verdade sobre os mortos',
        '4. Saber a verdade sobre a morte nos ajuda muito',
        '5. É um alívio saber a verdade sobre a morte',
      ],
      somePeopleSay: 'Eu tenho medo do que vai acontecer comigo quando eu morrer.',
      summary: 'Quando a pessoa morre, ela não sabe de mais nada. Os mortos não estão sofrendo nem podem prejudicar os vivos.',
      reviewQuestions: [
        'O que acontece quando a pessoa morre?',
        'Como nos ajuda saber a verdade sobre a morte?',
        'Por que saber a verdade sobre a morte é um alívio?',
      ],
      tryThis: 'Memorizar um texto desta lição para poder explicar para alguém o que acontece na morte.',
    ),
    LffLessonInfo(
      number: 30,
      title: 'As pessoas que você ama podem voltar a viver!',
      section: 2,
      pointTitles: [
        '1. O que Jeová quer fazer pelos nossos parentes e amigos que morreram?',
        '2. Como sabemos que os mortos podem ser ressuscitados?',
        '3. Que esperança existe para seus amigos e parentes que morreram?',
        '4. Jesus provou que pode ressuscitar os mortos',
        '5. Muitas pessoas serão ressuscitadas!',
        '6. A ressurreição pode te dar consolo e esperança',
      ],
      somePeopleSay: 'Essa história de ressurreição é muito boa para ser verdade.',
      summary: 'A Bíblia promete que bilhões de pessoas que morreram vão ser ressuscitadas. Jeová quer que elas voltem a viver e ele deu poder para Jesus fazer isso acontecer.',
      reviewQuestions: [
        'O que Jeová e Jesus querem fazer pelos que morreram?',
        'Os bilhões de pessoas que vão ser ressuscitadas vão viver onde — no céu ou na Terra? Por que você diz isso?',
        'Você tem certeza que as pessoas que você ama podem voltar a viver? Por quê?',
      ],
      tryThis: 'Conhece uma pessoa que está sofrendo a dor de perder alguém na morte? Quando o momento for apropriado, fale com jeito sobre a esperança da ressurreição.',
    ),
    LffLessonInfo(
      number: 31,
      title: 'O que é o Reino de Deus?',
      section: 2,
      pointTitles: [
        '1. O que é o Reino de Deus, e quem é o Rei desse Reino?',
        '2. Quem vai governar junto com Jesus?',
        '3. Por que o Reino de Deus é melhor do que os governos humanos?',
        '4. O Reino de Deus vai governar a Terra inteira',
        '5. Os governos humanos precisam ser substituídos',
        '6. O Reino de Deus tem governantes que nos entendem',
        '7. As leis do Reino de Deus são muito melhores do que as de qualquer governo humano',
      ],
      summary: 'O Reino de Deus é um governo de verdade lá no céu e vai governar a Terra toda.',
      reviewQuestions: [
        'Quem são os governantes do Reino de Deus?',
        'Por que o Reino de Deus é melhor do que qualquer governo humano?',
        'O que Jeová quer que as pessoas façam para fazer parte do seu Reino?',
      ],
      tryThis: 'Leia Isaías 11:1-10 para ver como vai ser o governo de Jesus. Depois, compare isso com os governos humanos.',
    ),
    LffLessonInfo(
      number: 32,
      title: 'O Reino de Deus já está governando!',
      section: 2,
      pointTitles: [
        '1. O que a Bíblia predisse?',
        '2. O que tem acontecido no mundo desde 1914?',
        '3. Por que o mundo está ficando cada vez pior desde que o Reino de Deus começou a governar?',
        '4. As profecias da Bíblia indicam o ano de 1914',
        '5. O mundo mudou muito desde 1914',
        '6. Queremos apoiar o Reino de Deus',
      ],
      summary: 'As profecias da Bíblia e a situação do mundo provam que o Reino de Deus já está governando. Quando pregamos e assistimos às reuniões, mostramos que acreditamos nisso.',
      reviewQuestions: [
        'O livro de Daniel falou sobre sete tempos. O que aconteceu no final desse período?',
        'O que convence você de que o Reino de Deus começou a governar em 1914?',
        'Como você pode mostrar que acredita que o Reino de Deus já está governando?',
      ],
      tryThis: 'Dar os passos necessários para se tornar um publicador das boas novas.',
    ),
    LffLessonInfo(
      number: 33,
      title: 'O que o Reino de Deus vai fazer?',
      section: 2,
      pointTitles: [
        '1. Como o Reino de Deus vai trazer paz e justiça para a Terra?',
        '2. Como vai ser nossa vida quando a vontade de Deus for feita na Terra?',
        '3. O que o Reino de Deus vai fazer depois que os maus forem destruídos?',
        '4. O Reino de Deus vai acabar com os governos humanos',
        '5. Jesus é um Rei perfeito',
        '6. O Reino de Deus vai trazer um futuro maravilhoso',
      ],
      somePeopleSay: 'Se cada um fizer a sua parte, podemos resolver os problemas do mundo.',
      summary: 'O Reino vai fazer tudo o que Deus quer que seja feito. Vai transformar a Terra num paraíso, cheio de pessoas boas que vão adorar a Jeová para sempre.',
      reviewQuestions: [
        'Como o Reino de Deus vai santificar o nome de Jeová?',
        'Por que podemos acreditar que o Reino de Deus vai cumprir todas as promessas da Bíblia?',
        'De todas as coisas boas que o Reino vai fazer, quais delas você mais quer que aconteça?',
      ],
      tryThis: 'Usar o folheto Como o Reino de Deus vai resolver nossos problemas? para iniciar uma conversa sobre a Bíblia.',
    ),
    // === Parte 3: Viva de um modo que agrade a Deus (Lições 34 a 47) ===
    LffLessonInfo(
      number: 34,
      title: 'Como podemos mostrar nosso amor por Jeová?',
      section: 3,
      pointTitles: [
        '1. Como podemos mostrar que amamos a Jeová?',
        '2. Por que pode ser difícil mostrar nosso amor por Jeová?',
        '3. Uma questão que tem a ver com você',
        '4. Alegre o coração de Jeová',
        '5. Você pode ser leal a Jeová',
        '6. Obedecer a Jeová é sempre o melhor',
      ],
      somePeopleSay: 'Deus não liga para as coisas que eu faço ou o que eu deixo de fazer.',
      summary: 'Você pode mostrar que ama a Jeová quando obedece a ele e é leal apesar dos desafios.',
      reviewQuestions: [
        'O que você aprendeu do exemplo de Jó?',
        'Como você pode provar que ama a Jeová?',
        'O que vai ajudar você a ser leal a Jeová?',
      ],
      tryThis: 'Decorar Provérbios 27:11. Tente se lembrar desse texto sempre que achar difícil obedecer a Jeová.',
    ),
    LffLessonInfo(
      number: 35,
      title: 'Como podemos tomar boas decisões?',
      section: 3,
      pointTitles: [
        '1. Como você pode usar a Bíblia para tomar boas decisões?',
        '2. O que você deveria levar em conta antes de tomar uma decisão?',
        '3. Deixe a Bíblia guiar você',
        '4. Treine sua consciência para tomar boas decisões',
        '5. Respeite a consciência de outros',
      ],
      somePeopleSay: 'A vida é minha, eu faço o que quero. Não estou nem aí para o que os outros pensam.',
      summary: 'Para tomar boas decisões, precisamos saber o que Jeová pensa sobre certo assunto e avaliar como a nossa decisão vai afetar outros.',
      reviewQuestions: [
        'Como você pode tomar decisões que agradam a Jeová?',
        'Como você pode treinar sua consciência?',
        'Como você pode mostrar respeito pela consciência de outras pessoas?',
      ],
      tryThis: 'Pense numa decisão que você vai ter que tomar em breve. Daí coloque em prática os três pontos do quadro “O que fazer para tomar boas decisões?”.',
    ),
    LffLessonInfo(
      number: 36,
      title: 'Seja sempre honesto',
      section: 3,
      pointTitles: [
        '1. Qual é o motivo mais importante para sermos honestos?',
        '2. Como podemos ser honestos no nosso dia a dia?',
        '3. Por que é bom ser honesto?',
        '4. A honestidade agrada a Jeová',
        '5. Seja honesto em tudo',
        '6. A honestidade é para o nosso bem',
      ],
      somePeopleSay: 'Uma mentirinha de nada não faz mal a ninguém.',
      summary: 'Jeová quer que seus amigos sejam honestos em tudo o que dizem e fazem.',
      reviewQuestions: [
        'Quais são algumas das maneiras de sermos honestos?',
        'Por que não devemos achar que podemos esconder alguma coisa de Jeová?',
        'Por que você quer ser honesto em tudo?',
      ],
      tryThis: 'Pergunte-se: ‘Será que Jeová acha que eu sou uma pessoa honesta?’ Daí, veja onde você poderia melhorar.',
    ),
    LffLessonInfo(
      number: 37,
      title: 'O que a Bíblia diz sobre trabalho e dinheiro?',
      section: 3,
      pointTitles: [
        '1. O que a Bíblia diz sobre trabalho?',
        '2. Qual é um ponto de vista equilibrado sobre o dinheiro?',
        '3. Como podemos usar o dinheiro para ajudar outros?',
        '4. O modo como você trabalha pode dar honra a Jeová',
        '5. Estar contentes com o que temos traz alegria',
        '6. Jeová vai cuidar das nossas necessidades',
      ],
      somePeopleSay: 'Eu tenho que trabalhar para sustentar minha família. Não posso ir para as reuniões toda semana.',
      summary: 'Trabalho e dinheiro são importantes, mas essas coisas nunca devem atrapalhar nosso serviço a Jeová.',
      reviewQuestions: [
        'O que pode ajudar você a ter um ponto de vista equilibrado sobre o trabalho?',
        'Por que é bom estar contente com as coisas que temos?',
        'Como você pode mostrar que confia na promessa de Jeová de cuidar do povo dele?',
      ],
      tryThis: 'Será que você perdeu várias reuniões nos últimos meses por causa do seu trabalho? Nesse caso, pense no que você poderia fazer para melhorar nisso.',
    ),
    LffLessonInfo(
      number: 38,
      title: 'Dê valor ao presente da vida',
      section: 3,
      pointTitles: [
        '1. Por que devemos dar valor à vida?',
        '2. Como podemos mostrar a Jeová que damos valor à vida?',
        '3. Cuide da saúde',
        '4. Tome cuidado para não causar acidentes ou mortes',
        '5. Respeite a vida do bebê que ainda não nasceu',
      ],
      somePeopleSay: 'Toda mulher tem o direito de fazer um aborto. Afinal, o corpo é dela.',
      summary: 'A Bíblia nos ensina a amar, respeitar e proteger a vida, esse maravilhoso presente que Jeová nos deu. Isso inclui tanto a nossa vida como a vida de outros.',
      reviewQuestions: [
        'Por que a vida humana é valiosa para Jeová?',
        'Como Jeová se sente quando uma pessoa tira a vida de alguém ou a própria vida?',
        'Por que você dá valor ao presente da vida?',
      ],
      tryThis: 'Identificar uma maneira em que você pode proteger sua saúde.',
    ),
    LffLessonInfo(
      number: 39,
      title: 'O ponto de vista de Deus sobre o sangue',
      section: 3,
      pointTitles: [
        '1. Qual é o ponto de vista de Jeová sobre o sangue?',
        '2. Que usos do sangue Deus proíbe?',
        '3. Escolha um tratamento que agrade a Jeová',
        '4. As Testemunhas de Jeová querem o melhor tratamento de saúde',
        '5. Frações de sangue: Tome a sua decisão',
      ],
      summary: 'Jeová quer que a gente mostre respeito pelo sangue.',
      reviewQuestions: [
        'Por que o sangue é sagrado para Jeová?',
        'Como sabemos que a ordem de Deus de se abster de sangue inclui as transfusões de sangue?',
        'Como podemos tomar boas decisões sobre o uso de sangue em tratamentos de saúde?',
      ],
      tryThis: 'Usar os artigos na sessão “Quer Pesquisar Mais?” para tomar sua decisão sobre (1) transfusões de sangue, (2) remédios ou vacinas que usem frações de sangue e (3) o uso do seu próprio sangue durante um procedimento médico. Daí, coloque sua decisão por escrito.',
    ),
    LffLessonInfo(
      number: 40,
      title: 'Como podemos ser limpos aos olhos de Deus?',
      section: 3,
      pointTitles: [
        '1. Como podemos ser limpos em sentido físico?',
        '2. Que hábitos poderiam nos tornar impuros?',
        '3. A limpeza física dá honra a Jeová',
        '4. Vença hábitos impuros',
        '5. Lute contra pensamentos e hábitos errados',
      ],
      somePeopleSay: 'Eu já estou viciado. Não consigo parar.',
      summary: 'Quando mantemos nosso corpo, nossa mente e nosso modo de agir limpos, agradamos a Jeová.',
      reviewQuestions: [
        'Por que é tão importante sermos limpos em todos os sentidos?',
        'Como você pode ser limpo em sentido físico?',
        'Como você pode manter suas ações e seus pensamentos limpos?',
      ],
      tryThis: 'Orar a Jeová para ver se você poderia melhorar em alguma coisa que aprendeu nesta lição.',
    ),
    LffLessonInfo(
      number: 41,
      title: 'O que a Bíblia diz sobre sexo?',
      section: 3,
      pointTitles: [
        '1. Qual é o ponto de vista de Jeová sobre o sexo?',
        '2. O que é imoralidade sexual?',
        '3. Fuja da imoralidade sexual',
        '4. Você pode vencer as tentações',
        '5. Os padrões de Jeová são para o nosso bem',
      ],
      somePeopleSay: 'Sexo entre duas pessoas que se amam é a coisa mais natural do mundo.',
      summary: 'O sexo é um presente de Jeová para o marido e a esposa.',
      reviewQuestions: [
        'Que práticas são consideradas imoralidade sexual?',
        'O que vai nos ajudar a fugir da imoralidade sexual?',
        'Por que obedecer aos padrões de moral de Jeová é para o nosso bem?',
      ],
      tryThis: 'Decorar um ou dois textos desta lição que vão ajudar você a vencer tentações.',
    ),
    LffLessonInfo(
      number: 42,
      title: 'O que a Bíblia diz sobre se casar e ficar solteiro?',
      section: 3,
      pointTitles: [
        '1. Quais são algumas vantagens de ser solteiro?',
        '2. Quais são algumas vantagens de estar casado legalmente?',
        '3. Qual é o ponto de vista de Jeová sobre o casamento?',
        '4. Como os solteiros podem usar bem a sua vida',
        '5. Escolha bem com quem vai se casar',
        '6. Tenha o ponto de vista de Jeová sobre o casamento',
        '7. Coloque em prática o que Jeová diz sobre o casamento',
      ],
      summary: 'A vida de casado e de solteiro são presentes de Deus. Solteiros e casados podem ter alegria e satisfação na vida se viverem de acordo com a vontade de Jeová.',
      reviewQuestions: [
        'Como um solteiro pode usar bem a sua vida?',
        'Por que a Bíblia diz para se casar apenas com alguém que serve a Jeová?',
        'Qual é o único motivo que a Bíblia dá para o divórcio?',
      ],
      tryThis: 'Se você estiver vivendo com alguém sem ser casado, ore pedindo ajuda para decidir o que fazer para agradar a Jeová.',
    ),
    LffLessonInfo(
      number: 43,
      title: 'O que a Bíblia diz sobre as bebidas alcoólicas?',
      section: 3,
      pointTitles: [
        '1. É errado beber?',
        '2. Que conselho a Bíblia dá para aqueles que decidem beber?',
        '3. Como podemos respeitar a decisão de outros?',
        '4. Decida se você vai beber ou não',
        '5. Decida o quanto você vai beber',
        '6. Ajudas para quem bebe demais',
      ],
      summary: 'As bebidas estão entre os muitos presentes que Jeová nos deu, mas ele condena beber demais e ficar bêbado.',
      reviewQuestions: [
        'Qual é o ponto de vista da Bíblia sobre as bebidas alcoólicas?',
        'Quais são os perigos de beber demais?',
        'Como podemos respeitar a decisão de outros?',
      ],
      tryThis: 'Se você decidir beber, pense em como isso pode afetar você e outras pessoas, e estabeleça um limite.',
    ),
    LffLessonInfo(
      number: 44,
      title: 'Será que todos os feriados agradam a Deus?',
      section: 3,
      pointTitles: [
        '1. Por que muitos feriados não agradam a Jeová?',
        '2. Como Jeová se sente sobre feriados que dão honra exagerada a humanos?',
        '3. Será que faz diferença o modo como as pessoas agem em certos feriados?',
        '4. Rejeite feriados que desagradam a Jeová',
        '5. Ajude outros a entender sua decisão',
        '6. Jeová quer que sejamos felizes',
      ],
      somePeopleSay: 'Saber de onde vem o feriado não interessa. O importante é passar tempo com a família e os amigos.',
      summary: 'Jeová quer que tenhamos bons momentos com nossa família e nossos amigos. Mas ele também quer que a gente não comemore feriados que desagradam a ele.',
      reviewQuestions: [
        'Que perguntas podem nos ajudar a saber se um feriado desagrada a Jeová?',
        'Como podemos ajudar nossa família e nossos amigos a entender por que não comemoramos alguns feriados?',
        'Como sabemos que Jeová quer que a gente seja feliz e se divirta?',
      ],
      tryThis: 'Usar o que você aprendeu nesta lição para decidir se deve participar dos feriados da sua região.',
    ),
    LffLessonInfo(
      number: 45,
      title: 'O que significa ser neutro?',
      section: 3,
      pointTitles: [
        '1. Qual é o ponto de vista dos cristãos sobre os governos humanos?',
        '2. Como podemos mostrar que somos neutros?',
        '3. Os cristãos verdadeiros são neutros',
        '4. Seja neutro em pensamentos e ações',
      ],
      summary: 'Os cristãos se esforçam bastante para serem neutros em pensamentos, palavras e ações.',
      reviewQuestions: [
        'O que devemos dar aos governos humanos?',
        'Por que temos que ser neutros?',
        'Que situações podem testar nossa neutralidade?',
      ],
      tryThis: 'Pense numa situação que poderia testar sua neutralidade e decida como lidar com isso.',
    ),
    LffLessonInfo(
      number: 46,
      title: 'Por que se dedicar a Jeová e ser batizado?',
      section: 3,
      pointTitles: [
        '1. O que motiva alguém a se dedicar a Jeová?',
        '2. Que bênçãos a pessoa recebe de Jeová quando se batiza?',
        '3. Todos nós temos que decidir a quem vamos servir',
        '4. Medite no amor que Jeová tem por você',
        '5. Dedicar-se a Jeová traz muitas bênçãos',
      ],
      somePeopleSay: 'Eu sei que essa é a verdade, mas não quero assumir um compromisso desse.',
      summary: 'O amor nos motiva a dedicar nossa vida a Jeová e ser batizados.',
      reviewQuestions: [
        'Por que Jeová merece todo o nosso amor e adoração?',
        'Que bênçãos Jeová dá para seus servos batizados?',
        'Você gostaria de se dedicar a Jeová?',
      ],
      tryThis: 'Ao preparar a próxima lição, pense no que está impedindo você de se dedicar a Jeová.',
    ),
    LffLessonInfo(
      number: 47,
      title: 'Você está pronto para ser batizado?',
      section: 3,
      pointTitles: [
        '1. Será que você precisa saber tudo da Bíblia para se batizar?',
        '2. Quais são algumas das coisas que você precisa fazer antes de se batizar?',
        '3. Por que você não deve ter medo de se batizar?',
        '4. Conheça melhor a Jeová',
        '5. Vencendo qualquer dificuldade para se batizar',
        '6. Confie na ajuda de Jeová',
        '7. Aumente sua gratidão pelo amor de Jeová',
      ],
      somePeopleSay: 'Eu tenho medo de me batizar e depois fazer alguma coisa errada.',
      summary: 'Com a ajuda de Jeová, você pode vencer qualquer dificuldade para se batizar.',
      reviewQuestions: [
        'Será que você precisa saber tudo da Bíblia para se batizar?',
        'Que mudanças você talvez precise fazer antes de se batizar?',
        'Por que você não deve deixar que o medo impeça você de se batizar?',
      ],
      tryThis: 'Ler as listas: “Estou pronto para pregar com a congregação?” e “Estou pronto para me batizar?” no final da parte 4.',
    ),
    // === Parte 4: Continue a fortalecer sua amizade com Jeová (Lições 48 a 60) ===
    LffLessonInfo(
      number: 48,
      title: 'Escolha bem os amigos',
      section: 4,
      pointTitles: [
        '1. Como os amigos influenciam você?',
        '2. Como a sua escolha de amigos pode fazer Jeová se sentir?',
        '3. Cuidado com as más companhias',
        '4. Nossos amigos não precisam ser iguais a nós',
        '5. Como ter boas amizades',
      ],
      somePeopleSay: 'O importante é ter amigos, não importa quem.',
      summary: 'Ter cuidado ao escolher os amigos é bom para nós e agrada a Jeová.',
      reviewQuestions: [
        'Por que nossa escolha de amigos é importante para Jeová?',
        'Que tipos de amizade nós devemos evitar?',
        'Como você pode ter boas amizades com o tipo certo de pessoas?',
      ],
      tryThis: 'Conhecer mais pessoas na congregação.',
    ),
    LffLessonInfo(
      number: 49,
      title: 'Como ter uma família feliz? — Parte 1',
      section: 4,
      pointTitles: [
        '1. Que conselhos a Bíblia dá para os maridos?',
        '2. Que conselhos a Bíblia dá para as esposas?',
        '3. Como um casal pode fortalecer o casamento?',
        '4. O marido precisa amar a esposa e cuidar dela',
        '5. A esposa precisa amar e respeitar o marido',
        '6. É possível vencer os problemas no casamento',
      ],
      somePeopleSay: 'As coisas mudaram no meu casamento. A gente se afastou um do outro.',
      summary: 'O marido e a esposa podem ser felizes quando os dois se amam, se respeitam e colocam em prática os conselhos da Bíblia.',
      reviewQuestions: [
        'Como o marido pode fazer a parte dele para ter um casamento feliz?',
        'Como a esposa pode fazer a parte dela para ter um casamento feliz?',
        'Se você for casado, que princípio da Bíblia poderia fortalecer seu casamento?',
      ],
      tryThis: 'Se você for casado, leia com seu marido ou sua esposa um dos artigos sobre casamento no site jw.org.',
    ),
    LffLessonInfo(
      number: 50,
      title: 'Como ter uma família feliz? — Parte 2',
      section: 4,
      pointTitles: [
        '1. Que conselhos Jeová dá para os pais?',
        '2. Que conselhos Jeová dá para os filhos?',
        '3. Como a família pode se aproximar mais de Deus?',
        '4. Eduque os filhos com amor',
        '5. Proteja seus filhos',
        '6. Respeite seus pais',
        '7. Adorem a Jeová em família',
      ],
      somePeopleSay: 'A Bíblia é difícil demais para as crianças.',
      summary: 'Jeová quer que (1) os pais amem, eduquem e protejam os filhos, (2) os filhos obedeçam e respeitem os pais e (3) a família adore a ele juntos.',
      reviewQuestions: [
        'Como os pais podem educar e proteger os filhos?',
        'Como os filhos podem mostrar respeito pelos pais?',
        'Por que é bom fazer a Adoração em Família toda semana?',
      ],
      tryThis: 'Pedir ideias para outros na congregação de como fazer a Adoração em Família',
    ),
    LffLessonInfo(
      number: 51,
      title: 'Como agradar a Jeová pelo modo como falamos?',
      section: 4,
      pointTitles: [
        '1. Como devemos usar nossas palavras?',
        '2. Que tipo de linguagem temos que evitar?',
        '3. O que vai nos ajudar a usar bem a fala?',
        '4. Cuidado com o que fala',
        '5. Fale bem de outros',
        '6. Seja bondoso ao falar com sua família',
      ],
      somePeopleSay: 'Eu falo o que eu penso. Se a pessoa não gostar, o problema é dela.',
      summary: 'As palavras têm poder. Precisamos tomar cuidado sobre o que falar, quando falar e como falar.',
      reviewQuestions: [
        'De que maneiras você pode usar a fala para ajudar outros?',
        'Que tipo de linguagem você não quer usar?',
        'O que pode nos ajudar a sempre ser bondosos e encorajar outros pelas nossas palavras?',
      ],
      tryThis: 'Elogiar alguém da sua família ou da congregação esta semana.',
    ),
    LffLessonInfo(
      number: 52,
      title: 'Por que é importante pensar na nossa roupa e aparência?',
      section: 4,
      pointTitles: [
        '1. O que pode nos ajudar a decidir como nos vestir e nos arrumar?',
        '2. Como o nosso modo de vestir pode afetar nossos irmãos?',
        '3. Como o nosso modo de vestir pode dar bom testemunho sobre Jeová?',
        '4. Ter uma boa aparência mostra respeito por Jeová',
        '5. Como tomar boas decisões sobre o modo de nos vestir e nos arrumar',
      ],
      somePeopleSay: 'Não importa o que os outros pensam. Eu tenho o direito de usar o que eu quiser.',
      summary: 'Quando tomamos boas decisões sobre o modo de nos vestir e nos arrumar, mostramos respeito por Jeová e por outros.',
      reviewQuestions: [
        'Por que o modo de nos vestir e nos arrumar é importante para Jeová?',
        'Quais são alguns princípios que podem nos ajudar a decidir como nos vestir e nos arrumar?',
        'Como a nossa aparência pode dar um bom testemunho ou um mau testemunho sobre Jeová?',
      ],
      tryThis: 'Ver se você precisa fazer alguma mudança no modo de se vestir e se arrumar.',
    ),
    LffLessonInfo(
      number: 53,
      title: 'Como escolher bem as diversões?',
      section: 4,
      pointTitles: [
        '1. O que devemos levar em conta ao escolher uma diversão?',
        '2. Por que é importante controlar o tempo que gastamos com diversão?',
        '3. Fique longe do que desagrada a Jeová',
        '4. Use bem o tempo',
        '5. Escolha sua diversão com cuidado',
      ],
      somePeopleSay: 'Não tem problema nenhum eu ver um filme ou ler um livro que tem violência, imoralidade ou ocultismo. O importante é eu não fazer essas coisas.',
      summary: 'Jeová quer que a gente escolha bem nossa diversão e que se divirta com coisas que sejam boas para nós.',
      reviewQuestions: [
        'Que tipo de diversão os cristãos devem evitar?',
        'Por que devemos tomar cuidado com o tempo que gastamos com diversão?',
        'Por que você quer escolher diversões que agradam a Jeová?',
      ],
      tryThis: 'Usar o quadro “Como escolher bem a diversão?” para avaliar o tipo de diversão que você gosta.',
    ),
    LffLessonInfo(
      number: 54,
      title: 'O que “o escravo fiel e prudente” faz?',
      section: 4,
      pointTitles: [
        '1. Quem é “o escravo fiel e prudente”?',
        '2. Como o escravo fiel dá alimento espiritual para o povo de Jeová?',
        '3. O povo de Jeová precisa estar organizado',
        '4. O escravo fiel organiza nossa obra de pregação',
        '5. O escravo fiel nos dá orientação',
      ],
      somePeopleSay: 'Se você obedece ao Corpo Governante, você está apenas seguindo homens.',
      summary: 'O Corpo Governante é “o escravo fiel e prudente” designado por Jesus Cristo. Esses irmãos dão orientação e alimento espiritual para os cristãos no mundo todo.',
      reviewQuestions: [
        'Quem designou “o escravo fiel e prudente”?',
        'Como o Corpo Governante cuida de nós hoje?',
        'Você acredita que o Corpo Governante é “o escravo fiel e prudente”?',
      ],
      tryThis: 'Ter o costume de orar pedindo para Jeová abençoar o trabalho do Corpo Governante, como diz 2 Tessalonicenses 3:1.',
    ),
    LffLessonInfo(
      number: 55,
      title: 'Apoie a sua congregação',
      section: 4,
      pointTitles: [
        '1. Como você pode usar seu tempo e sua energia para apoiar a congregação?',
        '2. Como podemos usar nossos bens materiais para apoiar a congregação?',
        '3. Apoie a congregação com os seus donativos',
        '4. Podemos nos oferecer para ajudar',
        '5. Irmãos podem fazer mais pela congregação',
      ],
      summary: 'Jeová dá muito valor aos nossos esforços de apoiar a congregação com o nosso tempo, energia e bens materiais.',
      reviewQuestions: [
        'Como podemos usar nosso tempo e nossa energia para apoiar a congregação?',
        'Como podemos usar nossos bens materiais para apoiar a congregação?',
        'Como você gostaria de apoiar a congregação?',
      ],
      tryThis: 'Ajudar na limpeza e na manutenção do Salão do Reino da sua congregação.',
    ),
    LffLessonInfo(
      number: 56,
      title: 'Faça sua parte para manter a união',
      section: 4,
      pointTitles: [
        '1. O que é incrível no povo de Jeová?',
        '2. O que você pode fazer para manter a união?',
        '3. O que você pode fazer se tiver um desentendimento com um irmão?',
        '4. Vença o preconceito',
        '5. Perdoe de coração e faça as pazes',
        '6. Concentre-se nas qualidades dos irmãos',
      ],
      somePeopleSay: 'Eu posso até perdoar a pessoa, mas ela tem que pedir desculpas primeiro.',
      summary: 'Você pode ajudar a manter a união na congregação sendo perdoador e mostrando amor por todos os irmãos.',
      reviewQuestions: [
        'Como você pode vencer o preconceito?',
        'O que você vai fazer se tiver um desentendimento com um irmão?',
        'Por que você quer imitar o exemplo de Jeová em perdoar outros?',
      ],
      tryThis: 'Se estiver tendo dificuldades para se dar bem com um irmão, tente conhecê-lo melhor e ver as qualidades dele.',
    ),
    LffLessonInfo(
      number: 57,
      title: 'E se você cometer um pecado grave?',
      section: 4,
      pointTitles: [
        '1. O que temos que fazer para Jeová nos perdoar?',
        '2. Como Jeová usa os anciãos para nos ajudar quando pecamos?',
        '3. Confessar o erro nos ajuda',
        '4. Jeová é misericordioso com os pecadores',
        '5. Jeová perdoa quando nos arrependemos',
      ],
      somePeopleSay: 'Se eu contar o que eu fiz para os anciãos, eles vão me remover da congregação.',
      summary: 'Se cometermos um pecado grave, Jeová pode nos perdoar. Para isso, precisamos nos arrepender de coração e estar decididos a parar de fazer o que é errado.',
      reviewQuestions: [
        'Por que é bom confessar nossos pecados para Jeová?',
        'O que precisamos fazer para ter nossos pecados perdoados?',
        'Se cometermos um pecado grave, por que devemos procurar a ajuda dos anciãos?',
      ],
      tryThis: 'Conhecer os anciãos da sua congregação.',
    ),
    LffLessonInfo(
      number: 58,
      title: 'Continue leal a Jeová',
      section: 4,
      pointTitles: [
        '1. Como outros poderiam testar nossa lealdade a Jeová?',
        '2. Como nossas decisões mostram que somos leais a Jeová?',
        '3. Cuidado com ensinos falsos',
        '4. Continue leal a Deus mesmo quando um irmão cometer um pecado',
        '5. Fique longe de Babilônia, a Grande',
      ],
      somePeopleSay: 'Eu preciso saber o que os apóstatas estão falando sobre as Testemunhas de Jeová para eu poder defender a verdade.',
      summary: 'Para continuarmos leais a Jeová, precisamos evitar nos associar com aqueles que tentam nos desencaminhar.',
      reviewQuestions: [
        'Por que não devemos ouvir ideias de apóstatas?',
        'Se ficarmos sabendo que um irmão cometeu um pecado grave, o que devemos fazer?',
        'Como podemos obedecer ao aviso de fugir da religião falsa?',
      ],
      tryThis: 'Se você ainda tiver alguma ligação com a religião falsa, faça o que for preciso para se separar dela.',
    ),
    LffLessonInfo(
      number: 59,
      title: 'Enfrente perseguição com coragem!',
      section: 4,
      pointTitles: [
        '1. Por que podemos esperar perseguição?',
        '2. Como podemos nos preparar para perseguição?',
        '3. Por que perseverar durante perseguição nos ajuda?',
        '4. Você pode vencer a oposição na família',
        '5. Continue servindo a Jeová apesar de perseguição',
        '6. Jeová vai ajudar você a perseverar',
      ],
      somePeopleSay: 'Eu não conseguiria suportar perseguição.',
      summary: 'Jeová dá muito valor aos nossos esforços de servir a ele, apesar de perseguição. Com a ajuda dele, nós podemos perseverar!',
      reviewQuestions: [
        'Por que os cristãos devem esperar perseguição?',
        'O que você pode fazer agora para se preparar para a perseguição?',
        'Por que você pode ter certeza de que é possível servir a Jeová, apesar de perseguição?',
      ],
      tryThis: 'Pergunte a um irmão na congregação: “Alguém já tentou fazer você desistir de servir a Jeová? Como você lidou com isso?”',
    ),
    LffLessonInfo(
      number: 60,
      title: 'Continue a fortalecer sua amizade com Jeová',
      section: 4,
      pointTitles: [
        '1. Por que você deve continuar fortalecendo sua amizade com Jeová?',
        '2. O que mais você deve continuar fazendo?',
        '3. Como Jeová vai ajudar você a ser cada vez mais amigo dele?',
        '4. Não deixe de conversar com o seu melhor Amigo',
        '5. Tenha alvos espirituais',
        '6. Seja feliz para sempre!',
      ],
      summary: 'Continue a fortalecer sua amizade com Jeová e a ter alvos espirituais. Assim você poderá ser feliz para sempre!',
      reviewQuestions: [
        'Por que você pode ter certeza que Jeová vai te ajudar a servir a ele fielmente?',
        'Como você pode fortalecer sua amizade com Jeová?',
        'Por que ter alvos espirituais pode fortalecer sua amizade com Jeová?',
      ],
      tryThis: 'Nos próximos meses, leia os livros Achegue-se a Jeová e ‘Venha Ser Meu Seguidor’. Esses livros vão ajudar você a continuar fortalecendo sua amizade com Jeová e com o Filho dele, Jesus.',
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
    final maxPoints = lessonInfo?.totalPoints ?? 6;
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
    final maxPoints = lessonInfo?.totalPoints ?? 6;

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
