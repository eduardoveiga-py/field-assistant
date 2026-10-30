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
    // ==========================================
    // PARTE 1 (Lições 01 a 12)
    // ==========================================
    LffLessonInfo(
      number: 1,
      title: 'Como a Bíblia pode ajudar você?',
      section: 1,
      pointTitles: [
        '1. A Bíblia pode nos guiar',
        '2. A Bíblia pode responder às nossas perguntas',
        '3. A leitura da Bíblia pode ser agradável',
        'Resumo, Revisão e Tente o Seguinte',
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
        'Resumo, Revisão e Tente o Seguinte',
      ],
    ),
    LffLessonInfo(
      number: 3,
      title: 'Será que você pode acreditar na Bíblia?',
      section: 1,
      pointTitles: [
        '1. A Bíblia está de acordo com a ciência',
        '2. A Bíblia relata acontecimentos históricos com exatidão',
        '3. As profecias da Bíblia se cumprem',
        'Resumo, Revisão e Tente o Seguinte',
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
        '1. Quem escreveu a Bíblia?',
        '2. A Bíblia sobreviveu a ataques',
        '3. Um livro para todas as pessoas',
        'Resumo, Revisão e Tente o Seguinte',
      ],
    ),
    LffLessonInfo(
      number: 6,
      title: 'Como a vida começou?',
      section: 1,
      pointTitles: [
        '1. O Universo e a Terra foram projetados',
        '2. O relato de Gênesis sobre a criação',
        '3. É razoável acreditar na criação',
        'Resumo, Revisão e Tente o Seguinte',
      ],
    ),
    LffLessonInfo(
      number: 7,
      title: 'Conheça mais a Jeová',
      section: 1,
      pointTitles: [
        '1. As qualidades de Jeová',
        '2. O amor é a qualidade principal de Jeová',
        '3. Jeová se importa com você',
        'Resumo, Revisão e Tente o Seguinte',
      ],
    ),
    LffLessonInfo(
      number: 8,
      title: 'Você pode ser amigo de Jeová',
      section: 1,
      pointTitles: [
        '1. Jeová convida você para ser amigo dele',
        '2. O que Jeová pede dos amigos dele',
        '3. Como Abraão se tornou amigo de Jeová',
        'Resumo, Revisão e Tente o Seguinte',
      ],
    ),
    LffLessonInfo(
      number: 9,
      title: 'A oração fortalece sua amizade com Deus',
      section: 1,
      pointTitles: [
        '1. Podemos orar a Jeová sobre qualquer assunto',
        '2. Como devemos orar',
        '3. Como Deus responde às nossas orações',
        'Resumo, Revisão e Tente o Seguinte',
      ],
    ),
    LffLessonInfo(
      number: 10,
      title: 'Como as reuniões das Testemunhas de Jeová podem ajudar você?',
      section: 1,
      pointTitles: [
        '1. O que acontece nas reuniões das Testemunhas de Jeová',
        '2. Por que assistir às reuniões vale a pena',
        '3. Como se preparar para assistir a uma reunião',
        'Resumo, Revisão e Tente o Seguinte',
      ],
    ),
    LffLessonInfo(
      number: 11,
      title: 'Como você pode aproveitar ao máximo a leitura da Bíblia?',
      section: 1,
      pointTitles: [
        '1. Como criar o hábito de ler a Bíblia',
        '2. Como meditar no que lemos',
        '3. Onde encontrar ajuda para entender a Bíblia',
        'Resumo, Revisão e Tente o Seguinte',
      ],
    ),
    LffLessonInfo(
      number: 12,
      title: 'O que vai ajudar você a continuar estudando a Bíblia?',
      section: 1,
      pointTitles: [
        '1. Dê valor ao seu estudo da Bíblia',
        '2. Como lidar com a oposição de outros',
        '3. Como vencer a falta de tempo e o desânimo',
        'Resumo, Revisão e Tente o Seguinte',
      ],
    ),

    // ==========================================
    // PARTE 2 (Lições 13 a 33)
    // ==========================================
    LffLessonInfo(
      number: 13,
      title: 'Como as religiões falsas afastam as pessoas de Deus?',
      section: 2,
      pointTitles: [
        '1. As religiões falsas ensinam mentiras sobre Deus',
        '2. As religiões falsas se envolvem em guerras e política',
        '3. Deus pede que saia da religião falsa',
        'Resumo, Revisão e Tente o Seguinte',
      ],
    ),
    LffLessonInfo(
      number: 14,
      title: 'O que temos que fazer para Deus aceitar nossa adoração?',
      section: 2,
      pointTitles: [
        '1. Devemos adorar somente a Jeová',
        '2. O uso de imagens e símbolos na adoração',
        '3. Adore a Deus com espírito e verdade',
        'Resumo, Revisão e Tente o Seguinte',
      ],
    ),
    LffLessonInfo(
      number: 15,
      title: 'Quem é Jesus?',
      section: 2,
      pointTitles: [
        '1. Jesus é o Filho de Deus',
        '2. A vida de Jesus antes de vir à Terra',
        '3. Jesus não é o Deus Todo-Poderoso',
        '4. O papel de Jesus no propósito de Deus',
        'Resumo, Revisão e Tente o Seguinte',
      ],
    ),
    LffLessonInfo(
      number: 16,
      title: 'O que Jesus fez quando esteve na Terra?',
      section: 2,
      pointTitles: [
        '1. Jesus ensinou a verdade sobre Deus',
        '2. Os milagres de Jesus mostram seu amor e poder',
        '3. Jesus deu sua vida em resgate por nós',
        'Resumo, Revisão e Tente o Seguinte',
      ],
    ),
    LffLessonInfo(
      number: 17,
      title: 'Que tipo de pessoa é Jesus?',
      section: 2,
      pointTitles: [
        '1. Jesus é amoroso e acessível',
        '2. Jesus é humilde e compassivo',
        '3. Jesus é corajoso e leal',
        'Resumo, Revisão e Tente o Seguinte',
      ],
    ),
    LffLessonInfo(
      number: 18,
      title: 'Como saber quem são os cristãos verdadeiros?',
      section: 2,
      pointTitles: [
        '1. Os cristãos verdadeiros amam uns aos outros',
        '2. Baseiam seus ensinos na Palavra de Deus',
        '3. Pregam o Reino de Deus e não fazem parte do mundo',
        'Resumo, Revisão e Tente o Seguinte',
      ],
    ),
    LffLessonInfo(
      number: 19,
      title: 'Será que as Testemunhas de Jeová são cristãos de verdade?',
      section: 2,
      pointTitles: [
        '1. Quem são as Testemunhas de Jeová?',
        '2. De onde vêm as nossas crenças?',
        '3. Por que usamos o nome Testemunhas de Jeová?',
        'Resumo, Revisão e Tente o Seguinte',
      ],
    ),
    LffLessonInfo(
      number: 20,
      title: 'Como a congregação está organizada?',
      section: 2,
      pointTitles: [
        '1. Jesus Cristo é o Líder da congregação',
        '2. O papel dos anciãos e servos ministeriais',
        '3. O Corpo Governante orienta os cristãos',
        'Resumo, Revisão e Tente o Seguinte',
      ],
    ),
    LffLessonInfo(
      number: 21,
      title: 'Como as boas novas são pregadas?',
      section: 2,
      pointTitles: [
        '1. Uma obra mundial profetizada por Jesus',
        '2. Como a pregação é realizada de casa em casa e em público',
        '3. A pregação alcança todas as línguas e povos',
        'Resumo, Revisão e Tente o Seguinte',
      ],
    ),
    LffLessonInfo(
      number: 22,
      title: 'Como você pode falar das boas novas para outros?',
      section: 2,
      pointTitles: [
        '1. Fale sobre sua fé de modo informal',
        '2. Como dar testemunho com tato e respeito',
        '3. Como se qualificar para pregar com a congregação',
        'Resumo, Revisão e Tente o Seguinte',
      ],
    ),
    LffLessonInfo(
      number: 23,
      title: 'Batismo — Um alvo que vale a pena ter!',
      section: 2,
      pointTitles: [
        '1. O que o batismo cristão significa',
        '2. O que Jesus ensinou sobre o batismo',
        '3. Passos para estar preparado para o batismo',
        'Resumo, Revisão e Tente o Seguinte',
      ],
    ),
    LffLessonInfo(
      number: 24,
      title: 'Quem são os anjos, e o que eles fazem?',
      section: 2,
      pointTitles: [
        '1. Os anjos fiéis servem a Jeová e apoiam a pregação',
        '2. Quem é Satanás, o Diabo, e os demônios?',
        '3. Como se proteger do espiritismo e forças ocultas',
        'Resumo, Revisão e Tente o Seguinte',
      ],
    ),
    LffLessonInfo(
      number: 25,
      title: 'Qual é o objetivo de Deus para nós?',
      section: 2,
      pointTitles: [
        '1. Deus criou a Terra para ser um paraíso',
        '2. O que deu errado no jardim do Éden',
        '3. O propósito original de Deus nunca mudou',
        'Resumo, Revisão e Tente o Seguinte',
      ],
    ),
    LffLessonInfo(
      number: 26,
      title: 'Por que a maldade e o sofrimento existem?',
      section: 2,
      pointTitles: [
        '1. Deus não é o causador do sofrimento',
        '2. A rebelião no Éden e a soberania de Deus',
        '3. Logo todo o sofrimento será eliminado',
        'Resumo, Revisão e Tente o Seguinte',
      ],
    ),
    LffLessonInfo(
      number: 27,
      title: 'Como a morte de Jesus pode nos salvar?',
      section: 2,
      pointTitles: [
        '1. O pecado de Adão e a necessidade do resgate',
        '2. Jesus deu a vida como resgate correspondente',
        '3. Os benefícios do resgate para a humanidade',
        'Resumo, Revisão e Tente o Seguinte',
      ],
    ),
    LffLessonInfo(
      number: 28,
      title: 'Como mostrar gratidão pelo que Jeová e Jesus fizeram por você',
      section: 2,
      pointTitles: [
        '1. Ter fé no sacrifício de resgate de Cristo',
        '2. Assistir à Celebração da Morte de Jesus',
        '3. Viver em harmonia com os princípios de Cristo',
        'Resumo, Revisão e Tente o Seguinte',
      ],
    ),
    LffLessonInfo(
      number: 29,
      title: 'O que acontece quando a pessoa morre?',
      section: 2,
      pointTitles: [
        '1. A condição dos mortos segundo a Bíblia',
        '2. A alma não é imortal',
        '3. A verdade sobre o inferno de fogo e o purgatório',
        'Resumo, Revisão e Tente o Seguinte',
      ],
    ),
    LffLessonInfo(
      number: 30,
      title: 'As pessoas que você ama podem voltar a viver!',
      section: 2,
      pointTitles: [
        '1. A Bíblia promete uma ressurreição',
        '2. Ressurreições que Jesus realizou na Terra',
        '3. Quem será ressuscitado no novo mundo',
        'Resumo, Revisão e Tente o Seguinte',
      ],
    ),
    LffLessonInfo(
      number: 31,
      title: 'O que é o Reino de Deus?',
      section: 2,
      pointTitles: [
        '1. O Reino de Deus é um governo real no céu',
        '2. Jesus é o Rei designado por Deus',
        '3. Quem governa com Jesus no céu',
        'Resumo, Revisão e Tente o Seguinte',
      ],
    ),
    LffLessonInfo(
      number: 32,
      title: 'O Reino de Deus já está governando!',
      section: 2,
      pointTitles: [
        '1. A profecia dos tempos dos gentios e o ano de 1914',
        '2. O que aconteceu no céu quando Jesus se tornou Rei',
        '3. Os sinais dos últimos dias cumprindo-se na Terra',
        'Resumo, Revisão e Tente o Seguinte',
      ],
    ),
    LffLessonInfo(
      number: 33,
      title: 'O que o Reino de Deus vai fazer?',
      section: 2,
      pointTitles: [
        '1. O fim de todos os governos humanos e injustiças',
        '2. A Terra se tornará um paraíso global',
        '3. Saúde perfeita, paz e vida eterna',
        'Resumo, Revisão e Tente o Seguinte',
      ],
    ),

    // ==========================================
    // PARTE 3 (Lições 34 a 47)
    // ==========================================
    LffLessonInfo(
      number: 34,
      title: 'Como podemos mostrar o nosso amor por Jeová?',
      section: 3,
      pointTitles: [
        '1. Amar a Jeová de todo o coração e alma',
        '2. Obedecer aos mandamentos de Deus por amor',
        '3. O amor a Deus supera as provações',
        'Resumo, Revisão e Tente o Seguinte',
      ],
    ),
    LffLessonInfo(
      number: 35,
      title: 'Como podemos tomar boas decisões?',
      section: 3,
      pointTitles: [
        '1. Usar os princípios bíblicos para guiar decisões',
        '2. Buscar conselhos e orar antes de decidir',
        '3. O papel da consciência educada pela Bíblia',
        'Resumo, Revisão e Tente o Seguinte',
      ],
    ),
    LffLessonInfo(
      number: 36,
      title: 'Sempre seja honesto',
      section: 3,
      pointTitles: [
        '1. Honestidade no trabalho e nas finanças',
        '2. Honestidade nos relacionamentos e na congregação',
        '3. Por que a honestidade agrada a Jeová e traz paz',
        'Resumo, Revisão e Tente o Seguinte',
      ],
    ),
    LffLessonInfo(
      number: 37,
      title: 'O que a Bíblia diz sobre trabalho e dinheiro?',
      section: 3,
      pointTitles: [
        '1. Ter um ponto de vista equilibrado sobre o trabalho',
        '2. Evitar o materialismo e o amor ao dinheiro',
        '3. Confiar que Jeová proverá as necessidades',
        'Resumo, Revisão e Tente o Seguinte',
      ],
    ),
    LffLessonInfo(
      number: 38,
      title: 'Dê valor ao presente da vida',
      section: 3,
      pointTitles: [
        '1. A vida humana é sagrada para o Criador',
        '2. Como encarar o aborto, suicídio e violência',
        '3. Medidas de segurança e cuidado com a saúde',
        'Resumo, Revisão e Tente o Seguinte',
      ],
    ),
    LffLessonInfo(
      number: 39,
      title: 'O ponto de vista de Deus sobre o sangue',
      section: 3,
      pointTitles: [
        '1. O que a Bíblia ordena sobre abster-se de sangue',
        '2. O sangue na medicina e tratamentos sem sangue',
        '3. Frações de sangue e procedimentos médicos',
        'Resumo, Revisão e Tente o Seguinte',
      ],
    ),
    LffLessonInfo(
      number: 40,
      title: 'Como podemos ser limpos aos olhos de Deus?',
      section: 3,
      pointTitles: [
        '1. Limpeza física, mental e moral',
        '2. Evitar hábitos prejudiciais e vícios',
        '3. A pureza espiritual e adoração limpa',
        'Resumo, Revisão e Tente o Seguinte',
      ],
    ),
    LffLessonInfo(
      number: 41,
      title: 'O que a Bíblia diz sobre sexo?',
      section: 3,
      pointTitles: [
        '1. O sexo dentro do casamento honroso',
        '2. O que a Bíblia define como imoralidade sexual (porneia)',
        '3. Por que fugir da fornicação e pornografia',
        'Resumo, Revisão e Tente o Seguinte',
      ],
    ),
    LffLessonInfo(
      number: 42,
      title: 'O que a Bíblia diz sobre se casar e ficar solteiro?',
      section: 3,
      pointTitles: [
        '1. As vantagens de servir a Jeová solteiro',
        '2. Escolher um cônjuge que ame a Jeová',
        '3. O casamento é uma união permanente',
        'Resumo, Revisão e Tente o Seguinte',
      ],
    ),
    LffLessonInfo(
      number: 43,
      title: 'O que a Bíblia diz sobre as bebidas alcoólicas?',
      section: 3,
      pointTitles: [
        '1. O ponto de vista equilibrado da Bíblia sobre álcool',
        '2. Os perigos da bebedeira e abuso de álcool',
        '3. Quando é melhor não beber',
        'Resumo, Revisão e Tente o Seguinte',
      ],
    ),
    LffLessonInfo(
      number: 44,
      title: 'Será que todos os feriados agradam a Deus?',
      section: 3,
      pointTitles: [
        '1. A origem de celebrações e feriados não bíblicos',
        '2. Como explicar suas decisões com bondade e respeito',
        '3. Comemorações que alegram a Deus e a família',
        'Resumo, Revisão e Tente o Seguinte',
      ],
    ),
    LffLessonInfo(
      number: 45,
      title: 'O que significa ser neutro?',
      section: 3,
      pointTitles: [
        '1. Não tomar partido em assuntos políticos ou guerras',
        '2. Respeitar as autoridades governamentais',
        '3. Manter a lealdade exclusiva a Deus em provações',
        'Resumo, Revisão e Tente o Seguinte',
      ],
    ),
    LffLessonInfo(
      number: 46,
      title: 'Por que se dedicar a Jeová e ser batizado?',
      section: 3,
      pointTitles: [
        '1. O que é a dedicação a Jeová em oração',
        '2. Como a dedicação e o batismo estão relacionados',
        '3. Como vencer temores e dar esse passo feliz',
        'Resumo, Revisão e Tente o Seguinte',
      ],
    ),
    LffLessonInfo(
      number: 47,
      title: 'Você está pronto para ser batizado?',
      section: 3,
      pointTitles: [
        '1. Revisar os ensinos bíblicos com os anciãos',
        '2. O modo correto do batismo por imersão completa',
        '3. O que acontece após o batismo',
        'Resumo, Revisão e Tente o Seguinte',
      ],
    ),

    // ==========================================
    // PARTE 4 (Lições 48 a 60)
    // ==========================================
    LffLessonInfo(
      number: 48,
      title: 'Escolha bem os amigos',
      section: 4,
      pointTitles: [
        '1. Como as companhias afetam nossa espiritualidade',
        '2. Encontrar amigos leais na congregação',
        '3. Ser um amigo verdadeiro e encorajador',
        'Resumo, Revisão e Tente o Seguinte',
      ],
    ),
    LffLessonInfo(
      number: 49,
      title: 'Como ter uma família feliz? — Parte 1',
      section: 4,
      pointTitles: [
        '1. O papel do marido com base no amor de Cristo',
        '2. O papel da esposa com profundo respeito',
        '3. Como resolver conflitos com amor e paciência',
        'Resumo, Revisão e Tente o Seguinte',
      ],
    ),
    LffLessonInfo(
      number: 50,
      title: 'Como ter uma família feliz? — Parte 2',
      section: 4,
      pointTitles: [
        '1. Ensinar e disciplinar os filhos com amor',
        '2. Como os filhos devem honrar e obedecer aos pais',
        '3. A Noite de Adoração em Família',
        'Resumo, Revisão e Tente o Seguinte',
      ],
    ),
    LffLessonInfo(
      number: 51,
      title: 'Como agradar a Jeová pelo modo como falamos?',
      section: 4,
      pointTitles: [
        '1. Usar a língua para edificar e consolar',
        '2. Evitar calúnia, fofoca maldosa e linguagem vulgar',
        '3. Falar com brandura e sabedoria em momentos tensos',
        'Resumo, Revisão e Tente o Seguinte',
      ],
    ),
    LffLessonInfo(
      number: 52,
      title: 'Por que é importante pensar na nossa roupa e aparência?',
      section: 4,
      pointTitles: [
        '1. Vestir-se com modéstia, bom senso e decência',
        '2. Honrar o nome de Jeová pelo nosso arranjo pessoal',
        '3. Respeitar a consciência de outros',
        'Resumo, Revisão e Tente o Seguinte',
      ],
    ),
    LffLessonInfo(
      number: 53,
      title: 'Como escolher bem as diversões?',
      section: 4,
      pointTitles: [
        '1. Rejeitar diversões violentas, imorais ou espíritas',
        '2. Escolher diversões sadias e edificantes',
        '3. Controlar o tempo gasto com entretenimento',
        'Resumo, Revisão e Tente o Seguinte',
      ],
    ),
    LffLessonInfo(
      number: 54,
      title: 'O que “o escravo fiel e prudente” faz?',
      section: 4,
      pointTitles: [
        '1. Como Jesus alimenta a congregação no tempo devido',
        '2. O Corpo Governante e a distribuição de alimento espiritual',
        '3. Confiar na liderança provida por Cristo',
        'Resumo, Revisão e Tente o Seguinte',
      ],
    ),
    LffLessonInfo(
      number: 55,
      title: 'Apoie a sua congregação',
      section: 4,
      pointTitles: [
        '1. Participar ativamente nas reuniões com comentários',
        '2. Apoiar a limpeza e manutenção do Salão do Reino',
        '3. Fazer donativos voluntários com alegria',
        'Resumo, Revisão e Tente o Seguinte',
      ],
    ),
    LffLessonInfo(
      number: 56,
      title: 'Faça sua parte para manter a união',
      section: 4,
      pointTitles: [
        '1. Perdoar liberalmente as falhas dos irmãos',
        '2. Seguir as instruções de Mateus 18 para resolver desacordos',
        '3. Promover a paz e a harmonia na congregação',
        'Resumo, Revisão e Tente o Seguinte',
      ],
    ),
    LffLessonInfo(
      number: 57,
      title: 'E se você cometer um pecado grave?',
      section: 4,
      pointTitles: [
        '1. Buscar a ajuda espiritual dos anciãos sem demora',
        '2. O arrependimento genuíno e a misericórdia de Jeová',
        '3. A disciplina bíblica como demonstração de amor',
        'Resumo, Revisão e Tente o Seguinte',
      ],
    ),
    LffLessonInfo(
      number: 58,
      title: 'Continue leal a Jeová',
      section: 4,
      pointTitles: [
        '1. Permanecer fiel quando outros abandonam a verdade',
        '2. Como reagir à oposição e notícias enganosas',
        '3. A recompensa gloriosa dos que perseveram leais',
        'Resumo, Revisão e Tente o Seguinte',
      ],
    ),
    LffLessonInfo(
      number: 59,
      title: 'Enfrente perseguição com coragem!',
      section: 4,
      pointTitles: [
        '1. Por que os verdadeiros cristãos sofrem oposição',
        '2. Como se preparar com antecedência para perseguição',
        '3. Jeová dá poder além do normal para vencer o medo',
        'Resumo, Revisão e Tente o Seguinte',
      ],
    ),
    LffLessonInfo(
      number: 60,
      title: 'Continue a fortalecer sua amizade com Jeová',
      section: 4,
      pointTitles: [
        '1. Manter uma excelente rotina espiritual após o batismo',
        '2. Estabelecer e buscar novos alvos espirituais',
        '3. A promessa de felicidade eterna com Jeová',
        'Resumo, Revisão e Tente o Seguinte',
      ],
    ),
  ];

  /// Retorna a lição pelo número (1 a 60)
  static LffLessonInfo? getLesson(int number) {
    if (number < 1 || number > lessons.length) return null;
    return lessons[number - 1];
  }

  /// Retorna a seção de uma determinada lição
  static LffSectionInfo getSectionForLesson(int lessonNumber) {
    if (lessonNumber <= 12) return sections[0];
    if (lessonNumber <= 33) return sections[1];
    if (lessonNumber <= 47) return sections[2];
    return sections[3];
  }

  /// Calcula o progresso percentual exato do livro (0.0% a 100.0%)
  static double calculateProgressPercentage({
    required int lesson,
    int? point,
  }) {
    if (lesson <= 0) return 0.0;
    if (lesson > totalLessons) return 100.0;

    // Soma ponderada baseada no total de lições
    final lessonWeight = 100.0 / totalLessons;
    final lessonInfo = getLesson(lesson);
    final maxPoints = lessonInfo?.totalPoints ?? 4;
    final currentPointClamped = (point ?? 1).clamp(1, maxPoints);

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
    final maxPoints = lessonInfo?.totalPoints ?? 4;

    if (currentPoint < maxPoints) {
      final nextP = currentPoint + 1;
      return (
        nextLesson: currentLesson,
        nextPoint: nextP,
        label: 'Lição $currentLesson, Ponto $nextP',
      );
    } else {
      // Concluiu todos os pontos da lição atual
      if (currentLesson >= totalLessons) {
        return (
          nextLesson: totalLessons,
          nextPoint: maxPoints,
          label: '🎉 Livro Concluído! Parabéns pelo progresso!',
        );
      }

      final nextL = currentLesson + 1;
      const nextP = 1;

      // Se concluiu a última lição de uma seção, sugere a revisão correspondente
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

    // Lições
    for (final l in lessons) {
      list.add((
        id: 'lesson_${l.number}',
        title: 'Lição ${l.number}: ${l.title}',
        category: 'Lições do Livro (Seção ${l.section})',
        totalPoints: l.totalPoints,
      ));
    }

    // Revisões de Seção
    for (final s in sections) {
      list.add((
        id: 'review_${s.sectionNumber}',
        title: s.reviewTitle,
        category: 'Revisões de Seção',
        totalPoints: 4,
      ));
    }

    // Notas de Apêndice / Entenda Melhor
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
        'Resumo, Revisão e Tente o Seguinte',
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
        'Resumo, Revisão e Tente o Seguinte',
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
        'Resumo, Revisão e Tente o Seguinte',
        'Decisão: Aceitar continuar o curso completo no livro "Seja Feliz para Sempre!"',
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
    (number: 1, title: 'Como Deus fala com a gente?', paragraphs: 4),
    (number: 2, title: 'Quem é Deus?', paragraphs: 4),
    (number: 3, title: 'Como era a vida no começo?', paragraphs: 4),
    (number: 4, title: 'O que aconteceu quando Adão e Eva escutaram Satanás?', paragraphs: 4),
    (number: 5, title: 'Como as pessoas eram nos dias de Noé?', paragraphs: 4),
    (number: 6, title: 'O que você pode aprender do Dilúvio?', paragraphs: 4),
    (number: 7, title: 'Quem era Jesus?', paragraphs: 4),
    (number: 8, title: 'O que a morte de Jesus tem a ver com você?', paragraphs: 4),
    (number: 9, title: 'Quando a Terra vai se tornar um paraíso?', paragraphs: 4),
    (number: 10, title: 'Se você escutar a Deus, que bênçãos você vai ter?', paragraphs: 4),
    (number: 11, title: 'Será que Jeová nos escuta?', paragraphs: 4),
    (number: 12, title: 'Como sua família pode ser feliz?', paragraphs: 4),
    (number: 13, title: 'O que você precisa fazer para deixar Jeová feliz?', paragraphs: 4),
    (number: 14, title: 'Como você mostra que é fiel a Jeová?', paragraphs: 4),
  ];

  static ({int number, String title, int paragraphs})? getLesson(int number) {
    if (number < 1 || number > lessons.length) return null;
    return lessons[number - 1];
  }
}
