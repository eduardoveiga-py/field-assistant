import 'official_doc_models.dart';

/// Presets estruturais padrão (genéricos para repositório público; perfis reais são importados localmente/Drive).
class OfficialDocPresets {
  OfficialDocPresets._();

  static const List<OfficialHeaderProfile> defaultHeaders = [
    OfficialHeaderProfile(
      id: 'hdr-cong-padrao',
      label: 'Congregação Local (Modelo)',
      topSubtitle: 'CONGREGAÇÃO LOCAL (000000)',
      mainTitle: 'Cidade · UF',
      addressLine1: 'Endereço do Salão do Reino',
      addressLine2: 'Cidade · UF',
      contactEmail: 'cong000000@jwpub.org',
      primaryColorHex: '#1D4ED8',
      accentColorHex: '#0F766E',
      footerNote: '',
      showPageNumbers: false,
      isDefault: true,
    ),
    OfficialHeaderProfile(
      id: 'hdr-sem-cabecalho',
      label: 'Sem Cabeçalho (Interno)',
      primaryColorHex: '#1E3A5F',
      accentColorHex: '#0F766E',
      isEmptyHeader: true,
    ),
  ];

  static const List<ElderSignerProfile> defaultElders = [
    ElderSignerProfile(
      id: 'elder-coordenador',
      name: 'Coordenador do Corpo',
      defaultRole: 'Coordenador',
      signatureFontId: 'sacramento',
    ),
    ElderSignerProfile(
      id: 'elder-secretario',
      name: 'Secretário da Congregação',
      defaultRole: 'Secretário',
      alternateRoles: ['Sup. de Serviço'],
      signatureFontId: 'sacramento',
    ),
  ];

  static const List<OfficialSignatureBlock> defaultSignatureBlocks = [
    OfficialSignatureBlock(
      id: 'sig-comissao-servico',
      label: 'A Comissão de Serviço',
      groupTitle: 'A Comissão de Serviço',
      isDefault: true,
      signers: [
        SignerSlot(
          elderId: 'elder-coordenador',
          name: 'Nome do Coordenador',
          role: 'Coordenador',
        ),
        SignerSlot(
          elderId: 'elder-secretario',
          name: 'Nome do Secretário',
          role: 'Secretário',
        ),
        SignerSlot(
          elderId: 'elder-secretario',
          name: 'Nome do Sup. de Serviço',
          role: 'Sup. de Serviço',
        ),
      ],
    ),
    OfficialSignatureBlock(
      id: 'sig-corpo-anciaos',
      label: 'O Corpo de Anciãos',
      groupTitle: 'O Corpo de Anciãos',
      signers: [
        SignerSlot(
          elderId: 'elder-coordenador',
          name: 'Nome do Coordenador',
          role: 'Coordenador',
        ),
        SignerSlot(
          elderId: 'elder-secretario',
          name: 'Nome do Secretário',
          role: 'Secretário',
        ),
      ],
    ),
    OfficialSignatureBlock(
      id: 'sig-individual',
      label: 'Assinatura Individual',
      groupTitle: '',
      signers: [
        SignerSlot(
          elderId: 'elder-secretario',
          name: 'Nome do Ancião',
          role: 'Secretário',
        ),
      ],
    ),
    OfficialSignatureBlock(
      id: 'sig-sem-assinatura',
      label: 'Sem Assinatura',
      groupTitle: '',
      signers: [],
      isEmptySignature: true,
    ),
  ];

  static const List<OfficialDocTemplate> builtInTemplates = [
    OfficialDocTemplate(
      id: 'tpl-carta-apresentacao',
      name: 'Carta de Apresentação',
      description: 'Estrutura padrão da Comissão de Serviço para recomendação de publicadores, servos ministeriais ou anciãos.',
      docType: OfficialDocType.presentationLetter,
      isBuiltIn: true,
      defaultLayoutId: 'original',
      defaultRef: 'Carta de apresentação',
      defaultRecipient: 'Corpo de Anciãos da Congregação [Nome], [Cidade/UF]',
      defaultBodyMarkup:
          '*Queridos Irmãos,*\n\n'
          'É um prazer escrever para vocês para falar sobre nosso irmão(ã) **[Nome Completo]**.\n\n'
          '**Histórico e espiritualidade:** Descreva o tempo na congregação, assistência às reuniões, participação no ministério e qualidades espirituais observadas.\n\n'
          '**Privilégios e designações:** Informe designações exercidas (indicador, áudio/vídeo, partes, pioneiro, servo ministerial ou ancião) ou eventuais reavaliações recentes.\n\n'
          '**Atenção e pastoreio necessários:** Caso haja desafios familiares, de saúde ou emocionais, registre com equilíbrio como os anciãos locais têm prestado ajuda.\n\n'
          'Caso precisem de mais detalhes ou queiram esclarecer alguma dúvida, estaremos à inteira disposição de vocês. Por favor, aceitem nosso caloroso amor cristão.\n\n'
          'Seus irmãos e amigos,',
    ),
    OfficialDocTemplate(
      id: 'tpl-carta-geral',
      name: 'Carta Geral / Correspondência',
      description: 'Correspondência formal para Betel, Superintendente de Circuito, contas ou comunicações entre congregações.',
      docType: OfficialDocType.generalLetter,
      isBuiltIn: true,
      defaultLayoutId: 'original',
      defaultRef: '[Assunto da correspondência]',
      defaultRecipient: '[Destinatário / Escritório / Irmão]',
      defaultBodyMarkup:
          '*Queridos Irmãos,*\n\n'
          'Escrevemos esta correspondência para tratar de **[assunto principal]**.\n\n'
          'Apresentem os fatos objetivos, datas relevantes e eventuais decisões tomadas pelo Corpo de Anciãos ou pela Comissão de Serviço.\n\n'
          'Agradecemos antecipadamente a atenção de vocês. Recebam nosso caloroso amor cristão.\n\n'
          'Seus irmãos,',
    ),
    OfficialDocTemplate(
      id: 'tpl-pauta-reuniao',
      name: 'Pauta de Reunião',
      description: 'Roteiro organizado para reunião do Corpo de Anciãos, Comissão de Serviço ou preparação da Visita do SC.',
      docType: OfficialDocType.meetingAgenda,
      isBuiltIn: true,
      defaultLayoutId: 'contemporary_panel',
      defaultRef: 'Pauta — Reunião [Corpo de Anciãos / Comissão de Serviço]',
      defaultRecipient: 'Participantes: Anciãos / Comissão de Serviço',
      defaultBodyMarkup:
          '## 1. Abertura e Assuntos Espirituais\n'
          '- Cântico/Oração inicial e texto bíblico de abertura.\n'
          '- Pastoreio: acompanhamento de irmãos necessitados ou enfermos.\n\n'
          '## 2. Cartas, Anúncios e Pendências do Hub\n'
          '- Revisão de comunicações recebidas recentemente.\n\n'
          '## 3. Ministério de Campo, Pioneiros e Territórios\n'
          '- Situação dos grupos de campo, relatórios S-21 e territórios S-13.\n'
          '- Pedidos de pioneiro auxiliar/regular ou designações pendentes.\n\n'
          '## 4. Assuntos Administrativos & Manutenção\n'
          '- Contas, cronograma de limpeza/manutenção e próximos eventos.\n\n'
          '## 5. Encerramento e Oração Final',
    ),
    OfficialDocTemplate(
      id: 'tpl-ata-reuniao',
      name: 'Ata de Reunião',
      description: 'Registro formal de deliberações, responsáveis, prazos definidos e assinaturas do Coordenador e Secretário.',
      docType: OfficialDocType.meetingMinutes,
      isBuiltIn: true,
      defaultLayoutId: 'classic_refined',
      defaultRef: 'Ata de Reunião — [Corpo de Anciãos / Comissão de Serviço]',
      defaultRecipient: 'Registro Oficial da Congregação',
      defaultBodyMarkup:
          '## 1. Abertura\n'
          'Reunião iniciada com oração pelo irmão **[Nome]**.\n\n'
          '## 2. Assuntos Tratados e Decisões\n'
          '- **Ponto 1:** Resumo objetivo do que foi considerado e decisão unânime adotada.\n'
          '- **Ponto 2:** Responsável designado: **[Nome]** · Prazo: **[DD/MM/AAAA]**.\n\n'
          '## 3. Acompanhamentos Futuros\n'
          '- Itens que retornam na próxima reunião.\n\n'
          '## 4. Encerramento\n'
          'Nada mais havendo a tratar, a reunião foi encerrada com oração pelo irmão **[Nome]**.',
    ),
  ];

  static OfficialDocProfileBundle createDefaultBundle() =>
      const OfficialDocProfileBundle(
        schemaVersion: 1,
        bundleName: 'Padrão do Aplicativo',
        defaultStyleId: 'original',
        defaultFonts: OfficialFontSpec(),
        headers: defaultHeaders,
        elders: defaultElders,
        signatureBlocks: defaultSignatureBlocks,
      );

  static String formatPortugueseDate(DateTime date, {String? cityPrefix}) {
    const months = [
      'janeiro',
      'fevereiro',
      'março',
      'abril',
      'maio',
      'junho',
      'julho',
      'agosto',
      'setembro',
      'outubro',
      'novembro',
      'dezembro',
    ];
    final datePart = '${date.day} de ${months[date.month - 1]} de ${date.year}';
    if (cityPrefix != null && cityPrefix.trim().isNotEmpty) {
      final cleaned = cityPrefix.trim().replaceAll('·', ',');
      return '$cleaned, $datePart';
    }
    return datePart;
  }
}
