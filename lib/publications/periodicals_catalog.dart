/// Catálogo de Folhetos, A Sentinela (Edição para o Público) e Despertai! (2018 a 2027)
class PeriodicalItem {
  final String title;
  final String category; // 'folheto', 'sentinela', 'despertai', 'outro'
  final int? year;
  final int? issueNumber;
  final String? coverTheme;

  const PeriodicalItem({
    required this.title,
    required this.category,
    this.year,
    this.issueNumber,
    this.coverTheme,
  });

  String get fullDisplayName {
    if (coverTheme != null && coverTheme!.isNotEmpty) {
      return '$title — "$coverTheme"';
    }
    return title;
  }
}

class PeriodicalsCatalog {
  /// Lista oficial de Folhetos Atualizados das Testemunhas de Jeová (Edição Atual)
  static const List<PeriodicalItem> folhetos = [
    PeriodicalItem(
      title: 'Folheto: Futuro',
      category: 'folheto',
      coverTheme: 'Como você vê o futuro?',
    ),
    PeriodicalItem(
      title: 'Folheto: Família',
      category: 'folheto',
      coverTheme: 'O que pode ajudar sua família a ser feliz?',
    ),
    PeriodicalItem(
      title: 'Folheto: Deus',
      category: 'folheto',
      coverTheme: 'Quem é Deus?',
    ),
    PeriodicalItem(
      title: 'Folheto: Oração',
      category: 'folheto',
      coverTheme: 'Vale a pena orar?',
    ),
    PeriodicalItem(
      title: 'Folheto: Jesus',
      category: 'folheto',
      coverTheme: 'Quem é Jesus?',
    ),
    PeriodicalItem(
      title: 'Folheto: Reino de Deus',
      category: 'folheto',
      coverTheme: 'O que é o Reino de Deus?',
    ),
    PeriodicalItem(
      title: 'Folheto: Sofrimento',
      category: 'folheto',
      coverTheme: 'O sofrimento vai acabar algum dia?',
    ),
    PeriodicalItem(
      title: 'Folheto: Morte',
      category: 'folheto',
      coverTheme: 'Será que os mortos podem voltar a viver?',
    ),
    PeriodicalItem(
      title: 'Folheto: Religião',
      category: 'folheto',
      coverTheme: 'O que você acha da religião?',
    ),
    PeriodicalItem(
      title: 'Convite: Reuniões das Testemunhas de Jeová',
      category: 'folheto',
    ),
    PeriodicalItem(
      title: 'Convite: Celebração da Morte de Cristo',
      category: 'folheto',
    ),
    PeriodicalItem(
      title: 'Cartão de Contato: JW.ORG',
      category: 'folheto',
    ),
  ];

  /// Revistas A Sentinela (Edição para o Público) de 2018 a 2027 com temas de capa
  static const List<PeriodicalItem> sentinelas = [
    // 2018
    PeriodicalItem(title: 'A Sentinela N.º 1 2018', category: 'sentinela', year: 2018, issueNumber: 1, coverTheme: '12 chaves para uma família ser feliz'),
    PeriodicalItem(title: 'A Sentinela N.º 2 2018', category: 'sentinela', year: 2018, issueNumber: 2, coverTheme: 'Quem é Deus?'),
    PeriodicalItem(title: 'A Sentinela N.º 3 2018', category: 'sentinela', year: 2018, issueNumber: 3, coverTheme: 'O sofrimento vai acabar?'),

    // 2019
    PeriodicalItem(title: 'A Sentinela N.º 1 2019', category: 'sentinela', year: 2019, issueNumber: 1, coverTheme: 'O que a Bíblia diz sobre a morte?'),
    PeriodicalItem(title: 'A Sentinela N.º 2 2019', category: 'sentinela', year: 2019, issueNumber: 2, coverTheme: 'Como lidar com o estresse'),
    PeriodicalItem(title: 'A Sentinela N.º 3 2019', category: 'sentinela', year: 2019, issueNumber: 3, coverTheme: 'O que é o Reino de Deus?'),

    // 2020
    PeriodicalItem(title: 'A Sentinela N.º 1 2020', category: 'sentinela', year: 2020, issueNumber: 1, coverTheme: 'O que o futuro reserva para você?'),
    PeriodicalItem(title: 'A Sentinela N.º 2 2020', category: 'sentinela', year: 2020, issueNumber: 2, coverTheme: 'Por que pessoas boas sofrem?'),
    PeriodicalItem(title: 'A Sentinela N.º 3 2020', category: 'sentinela', year: 2020, issueNumber: 3, coverTheme: 'Será que Deus ouve as orações?'),

    // 2021
    PeriodicalItem(title: 'A Sentinela N.º 1 2021', category: 'sentinela', year: 2021, issueNumber: 1, coverTheme: 'Como ter esperança em tempos difíceis'),
    PeriodicalItem(title: 'A Sentinela N.º 2 2021', category: 'sentinela', year: 2021, issueNumber: 2, coverTheme: 'Você pode ter fé na Bíblia'),
    PeriodicalItem(title: 'A Sentinela N.º 3 2021', category: 'sentinela', year: 2021, issueNumber: 3, coverTheme: 'O que a Bíblia ensina sobre o amor?'),

    // 2022
    PeriodicalItem(title: 'A Sentinela N.º 1 2022', category: 'sentinela', year: 2022, issueNumber: 1, coverTheme: 'Como ter verdadeira paz mental'),
    PeriodicalItem(title: 'A Sentinela N.º 2 2022', category: 'sentinela', year: 2022, issueNumber: 2, coverTheme: 'Quem pode nos salvar?'),
    PeriodicalItem(title: 'A Sentinela N.º 3 2022', category: 'sentinela', year: 2022, issueNumber: 3, coverTheme: 'Como lidar com a ansiedade'),

    // 2023
    PeriodicalItem(title: 'A Sentinela N.º 1 2023', category: 'sentinela', year: 2023, issueNumber: 1, coverTheme: 'Um mundo sem ódio — Quando?'),
    PeriodicalItem(title: 'A Sentinela N.º 2 2023', category: 'sentinela', year: 2023, issueNumber: 2, coverTheme: 'Como enfrentar a perda de quem amamos'),
    PeriodicalItem(title: 'A Sentinela N.º 3 2023', category: 'sentinela', year: 2023, issueNumber: 3, coverTheme: 'Por que confiar no Criador?'),

    // 2024
    PeriodicalItem(title: 'A Sentinela N.º 1 2024', category: 'sentinela', year: 2024, issueNumber: 1, coverTheme: 'A ressurreição — Uma esperança real'),
    PeriodicalItem(title: 'A Sentinela N.º 2 2024', category: 'sentinela', year: 2024, issueNumber: 2, coverTheme: 'O que significa o fim do mundo?'),
    PeriodicalItem(title: 'A Sentinela N.º 3 2024', category: 'sentinela', year: 2024, issueNumber: 3, coverTheme: 'O que a Bíblia diz sobre o dinheiro?'),

    // 2025
    PeriodicalItem(title: 'A Sentinela N.º 1 2025', category: 'sentinela', year: 2025, issueNumber: 1, coverTheme: 'Como ter um casamento feliz'),
    PeriodicalItem(title: 'A Sentinela N.º 2 2025', category: 'sentinela', year: 2025, issueNumber: 2, coverTheme: 'Como encontrar verdadeira segurança'),
    PeriodicalItem(title: 'A Sentinela N.º 3 2025', category: 'sentinela', year: 2025, issueNumber: 3, coverTheme: 'A Bíblia pode ajudar você a ser feliz?'),

    // 2026
    PeriodicalItem(title: 'A Sentinela N.º 1 2026', category: 'sentinela', year: 2026, issueNumber: 1, coverTheme: 'O que o Reino de Deus fará por você'),
    PeriodicalItem(title: 'A Sentinela N.º 2 2026', category: 'sentinela', year: 2026, issueNumber: 2, coverTheme: 'Esperança para tempos de crise'),
    PeriodicalItem(title: 'A Sentinela N.º 3 2026', category: 'sentinela', year: 2026, issueNumber: 3, coverTheme: 'Aproximando-se de Deus em oração'),

    // 2027
    PeriodicalItem(title: 'A Sentinela N.º 1 2027', category: 'sentinela', year: 2027, issueNumber: 1, coverTheme: 'O futuro da humanidade segundo a Bíblia'),
    PeriodicalItem(title: 'A Sentinela N.º 2 2027', category: 'sentinela', year: 2027, issueNumber: 2, coverTheme: 'Paz verdadeira em tempos de conflito'),
    PeriodicalItem(title: 'A Sentinela N.º 3 2027', category: 'sentinela', year: 2027, issueNumber: 3, coverTheme: 'Vivendo de acordo com o propósito de Deus'),
  ];

  /// Revistas Despertai! de 2018 a 2027 com temas de capa
  static const List<PeriodicalItem> despertais = [
    // 2018
    PeriodicalItem(title: 'Despertai! N.º 1 2018', category: 'despertai', year: 2018, issueNumber: 1, coverTheme: 'Como ser feliz — 7 passos comprovados'),
    PeriodicalItem(title: 'Despertai! N.º 2 2018', category: 'despertai', year: 2018, issueNumber: 2, coverTheme: 'Como superar o luto'),
    PeriodicalItem(title: 'Despertai! N.º 3 2018', category: 'despertai', year: 2018, issueNumber: 3, coverTheme: 'O que a Bíblia diz sobre a depressão'),

    // 2019
    PeriodicalItem(title: 'Despertai! N.º 1 2019', category: 'despertai', year: 2019, issueNumber: 1, coverTheme: '6 conselhos práticos para educar os filhos'),
    PeriodicalItem(title: 'Despertai! N.º 2 2019', category: 'despertai', year: 2019, issueNumber: 2, coverTheme: 'A ciência e a Bíblia concordam?'),
    PeriodicalItem(title: 'Despertai! N.º 3 2019', category: 'despertai', year: 2019, issueNumber: 3, coverTheme: 'Como vencer a solidão'),

    // 2020
    PeriodicalItem(title: 'Despertai! N.º 1 2020', category: 'despertai', year: 2020, issueNumber: 1, coverTheme: 'Como proteger a sua saúde'),
    PeriodicalItem(title: 'Despertai! N.º 2 2020', category: 'despertai', year: 2020, issueNumber: 2, coverTheme: 'Aprenda a perdoar'),
    PeriodicalItem(title: 'Despertai! N.º 3 2020', category: 'despertai', year: 2020, issueNumber: 3, coverTheme: 'Como manter o casamento forte'),

    // 2021
    PeriodicalItem(title: 'Despertai! N.º 1 2021', category: 'despertai', year: 2021, issueNumber: 1, coverTheme: 'Como ser resiliente em tempos de crise'),
    PeriodicalItem(title: 'Despertai! N.º 2 2021', category: 'despertai', year: 2021, issueNumber: 2, coverTheme: 'Você foi feito para viver para sempre?'),
    PeriodicalItem(title: 'Despertai! N.º 3 2021', category: 'despertai', year: 2021, issueNumber: 3, coverTheme: 'O perigo do preconceito'),

    // 2022
    PeriodicalItem(title: 'Despertai! N.º 1 2022', category: 'despertai', year: 2022, issueNumber: 1, coverTheme: 'Saúde mental — Há esperança na Bíblia'),
    PeriodicalItem(title: 'Despertai! N.º 2 2022', category: 'despertai', year: 2022, issueNumber: 2, coverTheme: 'Como melhorar a comunicação com os filhos'),
    PeriodicalItem(title: 'Despertai! N.º 3 2022', category: 'despertai', year: 2022, issueNumber: 3, coverTheme: 'O planeta Terra vai sobreviver?'),

    // 2023
    PeriodicalItem(title: 'Despertai! N.º 1 2023', category: 'despertai', year: 2023, issueNumber: 1, coverTheme: 'Como encontrar amigos de verdade'),
    PeriodicalItem(title: 'Despertai! N.º 2 2023', category: 'despertai', year: 2023, issueNumber: 2, coverTheme: 'Como controlar a raiva'),
    PeriodicalItem(title: 'Despertai! N.º 3 2023', category: 'despertai', year: 2023, issueNumber: 3, coverTheme: 'A natureza foi projetada?'),

    // 2024
    PeriodicalItem(title: 'Despertai! N.º 1 2024', category: 'despertai', year: 2024, issueNumber: 1, coverTheme: 'Como combater o estresse no trabalho'),
    PeriodicalItem(title: 'Despertai! N.º 2 2024', category: 'despertai', year: 2024, issueNumber: 2, coverTheme: 'Como lidar com as incertezas da vida'),
    PeriodicalItem(title: 'Despertai! N.º 3 2024', category: 'despertai', year: 2024, issueNumber: 3, coverTheme: 'Tecnologia e família — O equilíbrio'),

    // 2025
    PeriodicalItem(title: 'Despertai! N.º 1 2025', category: 'despertai', year: 2025, issueNumber: 1, coverTheme: 'A solidão na era digital — Como vencer'),
    PeriodicalItem(title: 'Despertai! N.º 2 2025', category: 'despertai', year: 2025, issueNumber: 2, coverTheme: 'Segredos da vida feliz em família'),
    PeriodicalItem(title: 'Despertai! N.º 3 2025', category: 'despertai', year: 2025, issueNumber: 3, coverTheme: 'Superando perdas e recomeçando com fé'),

    // 2026
    PeriodicalItem(title: 'Despertai! N.º 1 2026', category: 'despertai', year: 2026, issueNumber: 1, coverTheme: 'Saúde emocional e equilíbrio'),
    PeriodicalItem(title: 'Despertai! N.º 2 2026', category: 'despertai', year: 2026, issueNumber: 2, coverTheme: 'Criando filhos responsáveis no mundo atual'),
    PeriodicalItem(title: 'Despertai! N.º 3 2026', category: 'despertai', year: 2026, issueNumber: 3, coverTheme: 'A harmonia da criação e o Criador'),

    // 2027
    PeriodicalItem(title: 'Despertai! N.º 1 2027', category: 'despertai', year: 2027, issueNumber: 1, coverTheme: 'Construindo amizades duradouras'),
    PeriodicalItem(title: 'Despertai! N.º 2 2027', category: 'despertai', year: 2027, issueNumber: 2, coverTheme: 'Como manter o equilíbrio mental e a paz'),
    PeriodicalItem(title: 'Despertai! N.º 3 2027', category: 'despertai', year: 2027, issueNumber: 3, coverTheme: 'Esperança bíblica para um planeta renovado'),
  ];
}
