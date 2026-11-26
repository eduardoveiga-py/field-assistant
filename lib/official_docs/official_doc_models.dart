import 'dart:convert';

import 'official_doc_fonts.dart';

/// Tipos de documento suportados pelo módulo de Cartas, Pautas e Atas.
enum OfficialDocType {
  presentationLetter(
    id: 'presentation_letter',
    label: 'Carta de Apresentação',
    shortLabel: 'Apresentação',
    defaultRef: 'Carta de apresentação',
    isMeeting: false,
  ),
  generalLetter(
    id: 'general_letter',
    label: 'Carta Geral / Correspondência',
    shortLabel: 'Carta Geral',
    defaultRef: 'Correspondência oficial',
    isMeeting: false,
  ),
  meetingAgenda(
    id: 'meeting_agenda',
    label: 'Pauta de Reunião',
    shortLabel: 'Pauta',
    defaultRef: 'Pauta de reunião',
    isMeeting: true,
  ),
  meetingMinutes(
    id: 'meeting_minutes',
    label: 'Ata de Reunião',
    shortLabel: 'Ata',
    defaultRef: 'Ata de reunião',
    isMeeting: true,
  );

  final String id;
  final String label;
  final String shortLabel;
  final String defaultRef;
  final bool isMeeting;

  const OfficialDocType({
    required this.id,
    required this.label,
    required this.shortLabel,
    required this.defaultRef,
    required this.isMeeting,
  });

  static OfficialDocType fromId(String? id) {
    for (final t in values) {
      if (t.id == id) return t;
    }
    return OfficialDocType.presentationLetter;
  }
}

/// Os 7 estilos visuais disponíveis (Padrão Original + 3 criados + 3 adicionais).
enum OfficialDocLayoutStyle {
  original(
    id: 'original',
    name: 'Meu Padrão (Original)',
    description: 'Layout fiel ao modelo clássico enviado: barra azul superior, timbre em duas colunas e corpo serifado tradicional.',
    defaultHeaderFontId: 'pt_sans',
    defaultMetaFontId: 'pt_sans',
    defaultBodyFontId: 'pt_serif',
    defaultSignatureFontId: 'sacramento',
    defaultJustify: false,
  ),
  classicRefined(
    id: 'classic_refined',
    name: '1 · Clássico Institucional Refinado',
    description: 'Barra dupla azul-marinho e verde-petróleo, destaque sutil em Ref: e leitura serifada refinada.',
    defaultHeaderFontId: 'pt_sans',
    defaultMetaFontId: 'pt_sans',
    defaultBodyFontId: 'pt_serif',
    defaultSignatureFontId: 'alex_brush',
    defaultJustify: true,
  ),
  editorialModern(
    id: 'editorial_modern',
    name: '2 · Editorial Moderno Sóbrio',
    description: 'Faixa lateral esquerda, cartão suave para Ref./Data/A/C e tipografia sans-serif contemporânea.',
    defaultHeaderFontId: 'lato',
    defaultMetaFontId: 'lato',
    defaultBodyFontId: 'lato',
    defaultSignatureFontId: 'courgette',
    defaultJustify: false,
  ),
  executiveMinimal(
    id: 'executive_minimal',
    name: '3 · Executivo Minimalista',
    description: 'Emblema numérico da congregação à esquerda, grade limpa de metadados e assinatura caligráfica clássica.',
    defaultHeaderFontId: 'pt_sans',
    defaultMetaFontId: 'pt_sans',
    defaultBodyFontId: 'caladea',
    defaultSignatureFontId: 'great_vibes',
    defaultJustify: true,
  ),
  diplomaticGold(
    id: 'diplomatic_gold',
    name: '4 · Solene Filete Dourado',
    description: 'Cabeçalho centralizado com filetes duplos azul-noite e dourado-âmbar discreto para ocasiões solenes.',
    defaultHeaderFontId: 'pt_sans',
    defaultMetaFontId: 'pt_sans',
    defaultBodyFontId: 'crimson_text',
    defaultSignatureFontId: 'great_vibes',
    defaultJustify: true,
  ),
  contemporaryPanel(
    id: 'contemporary_panel',
    name: '5 · Contemporâneo Painel',
    description: 'Cabeçalho em bloco escuro elegante e pílulas separadas para Destinatário e Assunto; excelente para atas e pautas.',
    defaultHeaderFontId: 'lato',
    defaultMetaFontId: 'lato',
    defaultBodyFontId: 'pt_sans',
    defaultSignatureFontId: 'courgette',
    defaultJustify: false,
  ),
  stationeryWatermark(
    id: 'stationery_watermark',
    name: '6 · Papelaria Marca d\'Água',
    description: 'Faixa superior em papel timbrado claro, separador ornamental discreto e marca d\'água suave ao fundo.',
    defaultHeaderFontId: 'pt_serif',
    defaultMetaFontId: 'pt_sans',
    defaultBodyFontId: 'caladea',
    defaultSignatureFontId: 'allura',
    defaultJustify: true,
  );

  final String id;
  final String name;
  final String description;
  final String defaultHeaderFontId;
  final String defaultMetaFontId;
  final String defaultBodyFontId;
  final String defaultSignatureFontId;
  final bool defaultJustify;

  const OfficialDocLayoutStyle({
    required this.id,
    required this.name,
    required this.description,
    required this.defaultHeaderFontId,
    required this.defaultMetaFontId,
    required this.defaultBodyFontId,
    required this.defaultSignatureFontId,
    required this.defaultJustify,
  });

  static OfficialDocLayoutStyle fromId(String? id) {
    for (final s in values) {
      if (s.id == id) return s;
    }
    return OfficialDocLayoutStyle.original;
  }

  OfficialFontSpec get defaultFonts => OfficialFontSpec(
    headerFontId: defaultHeaderFontId,
    metaFontId: defaultMetaFontId,
    bodyFontId: defaultBodyFontId,
    signatureFontId: defaultSignatureFontId,
  );
}

/// Especificação independente das fontes do documento (padrão fiel ao PDF enviado).
class OfficialFontSpec {
  final String headerFontId;
  final String metaFontId;
  final String bodyFontId;
  final String signatureFontId;
  final double bodyFontSizePt;
  final bool justifyBody;

  const OfficialFontSpec({
    this.headerFontId = 'pt_sans',
    this.metaFontId = 'pt_sans',
    this.bodyFontId = 'pt_serif',
    this.signatureFontId = 'sacramento',
    this.bodyFontSizePt = 10.0,
    this.justifyBody = false,
  });

  OfficialFontSpec copyWith({
    String? headerFontId,
    String? metaFontId,
    String? bodyFontId,
    String? signatureFontId,
    double? bodyFontSizePt,
    bool? justifyBody,
  }) {
    return OfficialFontSpec(
      headerFontId: headerFontId ?? this.headerFontId,
      metaFontId: metaFontId ?? this.metaFontId,
      bodyFontId: bodyFontId ?? this.bodyFontId,
      signatureFontId: signatureFontId ?? this.signatureFontId,
      bodyFontSizePt: bodyFontSizePt ?? this.bodyFontSizePt,
      justifyBody: justifyBody ?? this.justifyBody,
    );
  }

  Map<String, dynamic> toJson() => {
    'headerFontId': headerFontId,
    'metaFontId': metaFontId,
    'bodyFontId': bodyFontId,
    'signatureFontId': signatureFontId,
    'bodyFontSizePt': bodyFontSizePt,
    'justifyBody': justifyBody,
  };

  factory OfficialFontSpec.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const OfficialFontSpec();
    final sizeVal = (json['bodyFontSizePt'] as num?)?.toDouble() ?? 10.0;
    return OfficialFontSpec(
      headerFontId: OfficialDocFonts.normalizeFontId(
        (json['headerFontId'] ?? json['headerFontFamily'])?.toString(),
        fallback: 'pt_sans',
      ),
      metaFontId: OfficialDocFonts.normalizeFontId(
        (json['metaFontId'] ?? json['metaFontFamily'])?.toString(),
        fallback: 'pt_sans',
      ),
      bodyFontId: OfficialDocFonts.normalizeFontId(
        (json['bodyFontId'] ?? json['bodyFontFamily'])?.toString(),
        fallback: 'pt_serif',
      ),
      signatureFontId: OfficialDocFonts.normalizeFontId(
        (json['signatureFontId'] ?? json['signatureFontFamily'])?.toString(),
        fallback: 'sacramento',
      ),
      bodyFontSizePt: sizeVal.clamp(8.5, 13.0),
      justifyBody: json['justifyBody'] as bool? ?? false,
    );
  }
}

/// Perfil reutilizável de Cabeçalho / Timbre (ou "Sem Cabeçalho").
class OfficialHeaderProfile {
  final String id;
  final String label;
  final String topSubtitle;
  final String mainTitle;
  final String addressLine1;
  final String addressLine2;
  final String contactEmail;
  final String primaryColorHex;
  final String accentColorHex;
  final String footerNote;
  final bool showPageNumbers;
  final bool isDefault;
  final bool isEmptyHeader;

  const OfficialHeaderProfile({
    required this.id,
    required this.label,
    this.topSubtitle = '',
    this.mainTitle = '',
    this.addressLine1 = '',
    this.addressLine2 = '',
    this.contactEmail = '',
    this.primaryColorHex = '#1D4ED8',
    this.accentColorHex = '#0F766E',
    this.footerNote = '',
    this.showPageNumbers = false,
    this.isDefault = false,
    this.isEmptyHeader = false,
  });

  OfficialHeaderProfile copyWith({
    String? id,
    String? label,
    String? topSubtitle,
    String? mainTitle,
    String? addressLine1,
    String? addressLine2,
    String? contactEmail,
    String? primaryColorHex,
    String? accentColorHex,
    String? footerNote,
    bool? showPageNumbers,
    bool? isDefault,
    bool? isEmptyHeader,
  }) {
    return OfficialHeaderProfile(
      id: id ?? this.id,
      label: label ?? this.label,
      topSubtitle: topSubtitle ?? this.topSubtitle,
      mainTitle: mainTitle ?? this.mainTitle,
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      contactEmail: contactEmail ?? this.contactEmail,
      primaryColorHex: primaryColorHex ?? this.primaryColorHex,
      accentColorHex: accentColorHex ?? this.accentColorHex,
      footerNote: footerNote ?? this.footerNote,
      showPageNumbers: showPageNumbers ?? this.showPageNumbers,
      isDefault: isDefault ?? this.isDefault,
      isEmptyHeader: isEmptyHeader ?? this.isEmptyHeader,
    );
  }

  String get extractedCode {
    final m = RegExp(r'\((\d{4,})\)').firstMatch(topSubtitle);
    if (m != null) return m.group(1)!;
    final digits = RegExp(r'(\d{4,})').firstMatch(topSubtitle);
    return digits?.group(1) ?? 'CONG.';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'topSubtitle': topSubtitle,
    'mainTitle': mainTitle,
    'addressLine1': addressLine1,
    'addressLine2': addressLine2,
    'contactEmail': contactEmail,
    'primaryColorHex': primaryColorHex,
    'accentColorHex': accentColorHex,
    'footerNote': footerNote,
    'showPageNumbers': showPageNumbers,
    'isDefault': isDefault,
    'isEmptyHeader': isEmptyHeader,
  };

  factory OfficialHeaderProfile.fromJson(Map<String, dynamic> json) {
    final topSub = (json['topSubtitle'] ?? '').toString();
    final mainT = (json['mainTitle'] ?? '').toString();
    final emptyFlag =
        json['isEmptyHeader'] as bool? ??
        (topSub.trim().isEmpty && mainT.trim().isEmpty);
    return OfficialHeaderProfile(
      id: (json['id'] ?? '').toString(),
      label: (json['label'] ?? 'Cabeçalho').toString(),
      topSubtitle: topSub,
      mainTitle: mainT,
      addressLine1: (json['addressLine1'] ?? '').toString(),
      addressLine2: (json['addressLine2'] ?? '').toString(),
      contactEmail: (json['contactEmail'] ?? '').toString(),
      primaryColorHex: (json['primaryColorHex'] ?? '#1D4ED8').toString(),
      accentColorHex: (json['accentColorHex'] ?? '#0F766E').toString(),
      footerNote: (json['footerNote'] ?? '').toString(),
      showPageNumbers: json['showPageNumbers'] as bool? ?? false,
      isDefault: json['isDefault'] as bool? ?? false,
      isEmptyHeader: emptyFlag,
    );
  }
}

/// Cadastro de ancião assinante com suporte a fonte cursiva ou imagem PNG desenhada.
class ElderSignerProfile {
  final String id;
  final String name;
  final String defaultRole;
  final List<String> alternateRoles;
  final String signatureFontId;
  final String? signaturePngBase64;

  const ElderSignerProfile({
    required this.id,
    required this.name,
    required this.defaultRole,
    this.alternateRoles = const [],
    this.signatureFontId = 'sacramento',
    this.signaturePngBase64,
  });

  bool get hasDrawnSignature =>
      signaturePngBase64 != null && signaturePngBase64!.trim().isNotEmpty;

  List<String> get allRoles => [
    defaultRole,
    ...alternateRoles.where((r) => r.trim().isNotEmpty && r != defaultRole),
  ];

  ElderSignerProfile copyWith({
    String? id,
    String? name,
    String? defaultRole,
    List<String>? alternateRoles,
    String? signatureFontId,
    String? signaturePngBase64,
    bool clearSignaturePng = false,
  }) {
    return ElderSignerProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      defaultRole: defaultRole ?? this.defaultRole,
      alternateRoles: alternateRoles ?? this.alternateRoles,
      signatureFontId: signatureFontId ?? this.signatureFontId,
      signaturePngBase64: clearSignaturePng
          ? null
          : (signaturePngBase64 ?? this.signaturePngBase64),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'defaultRole': defaultRole,
    'alternateRoles': alternateRoles,
    'signatureFontId': signatureFontId,
    if (signaturePngBase64 != null) 'signaturePngBase64': signaturePngBase64,
  };

  factory ElderSignerProfile.fromJson(Map<String, dynamic> json) {
    final alts = (json['alternateRoles'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .where((e) => e.trim().isNotEmpty)
        .toList();
    return ElderSignerProfile(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      defaultRole: (json['defaultRole'] ?? 'Ancião').toString(),
      alternateRoles: alts,
      signatureFontId: OfficialDocFonts.normalizeFontId(
        (json['signatureFontId'] ?? json['signatureFontFamily'])?.toString(),
        fallback: 'sacramento',
      ),
      signaturePngBase64: json['signaturePngBase64'] as String?,
    );
  }
}

/// Slot individual dentro de um bloco de assinaturas (ex.: Coordenador, Secretário, Sup. Serviço).
class SignerSlot {
  final String? elderId;
  final String name;
  final String role;
  final String? signatureFontIdOverride;
  final String? signaturePngBase64Override;

  const SignerSlot({
    this.elderId,
    required this.name,
    required this.role,
    this.signatureFontIdOverride,
    this.signaturePngBase64Override,
  });

  Map<String, dynamic> toJson() => {
    if (elderId != null) 'elderId': elderId,
    'name': name,
    'role': role,
    if (signatureFontIdOverride != null)
      'signatureFontIdOverride': signatureFontIdOverride,
    if (signaturePngBase64Override != null)
      'signaturePngBase64Override': signaturePngBase64Override,
  };

  factory SignerSlot.fromJson(Map<String, dynamic> json) {
    return SignerSlot(
      elderId: json['elderId']?.toString(),
      name: (json['name'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
      signatureFontIdOverride: json['signatureFontIdOverride']?.toString(),
      signaturePngBase64Override: json['signaturePngBase64Override']
          ?.toString(),
    );
  }
}

/// Conjunto reutilizável de rodapé / assinaturas (ex.: "A Comissão de Serviço", "O Corpo de Anciãos").
class OfficialSignatureBlock {
  final String id;
  final String label;
  final String groupTitle;
  final List<SignerSlot> signers;
  final bool isDefault;
  final bool isEmptySignature;

  const OfficialSignatureBlock({
    required this.id,
    required this.label,
    this.groupTitle = '',
    this.signers = const [],
    this.isDefault = false,
    this.isEmptySignature = false,
  });

  OfficialSignatureBlock copyWith({
    String? id,
    String? label,
    String? groupTitle,
    List<SignerSlot>? signers,
    bool? isDefault,
    bool? isEmptySignature,
  }) {
    return OfficialSignatureBlock(
      id: id ?? this.id,
      label: label ?? this.label,
      groupTitle: groupTitle ?? this.groupTitle,
      signers: signers ?? this.signers,
      isDefault: isDefault ?? this.isDefault,
      isEmptySignature: isEmptySignature ?? this.isEmptySignature,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'groupTitle': groupTitle,
    'signers': signers.map((s) => s.toJson()).toList(),
    'isDefault': isDefault,
    'isEmptySignature': isEmptySignature,
  };

  factory OfficialSignatureBlock.fromJson(Map<String, dynamic> json) {
    final slots = (json['signers'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(SignerSlot.fromJson)
        .toList();
    final title = (json['groupTitle'] ?? '').toString();
    final emptyFlag =
        json['isEmptySignature'] as bool? ??
        (slots.isEmpty && title.trim().isEmpty);
    return OfficialSignatureBlock(
      id: (json['id'] ?? '').toString(),
      label: (json['label'] ?? 'Assinatura').toString(),
      groupTitle: title,
      signers: slots,
      isDefault: json['isDefault'] as bool? ?? false,
      isEmptySignature: emptyFlag,
    );
  }
}

/// Modelo/Template extensível (4 nativos + modelos personalizados criados/importados pelo usuário).
class OfficialDocTemplate {
  final String id;
  final String name;
  final String description;
  final OfficialDocType docType;
  final bool isBuiltIn;
  final String? defaultHeaderId;
  final String? defaultSignatureBlockId;
  final String defaultLayoutId;
  final String defaultRef;
  final String defaultRecipient;
  final String defaultBodyMarkup;
  final String defaultMeetingLocation;
  final DateTime? updatedAt;

  const OfficialDocTemplate({
    required this.id,
    required this.name,
    this.description = '',
    required this.docType,
    this.isBuiltIn = false,
    this.defaultHeaderId,
    this.defaultSignatureBlockId,
    this.defaultLayoutId = 'original',
    this.defaultRef = '',
    this.defaultRecipient = '',
    this.defaultBodyMarkup = '',
    this.defaultMeetingLocation = '',
    this.updatedAt,
  });

  OfficialDocTemplate copyWith({
    String? id,
    String? name,
    String? description,
    OfficialDocType? docType,
    bool? isBuiltIn,
    String? defaultHeaderId,
    String? defaultSignatureBlockId,
    String? defaultLayoutId,
    String? defaultRef,
    String? defaultRecipient,
    String? defaultBodyMarkup,
    String? defaultMeetingLocation,
    DateTime? updatedAt,
  }) {
    return OfficialDocTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      docType: docType ?? this.docType,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      defaultHeaderId: defaultHeaderId ?? this.defaultHeaderId,
      defaultSignatureBlockId:
          defaultSignatureBlockId ?? this.defaultSignatureBlockId,
      defaultLayoutId: defaultLayoutId ?? this.defaultLayoutId,
      defaultRef: defaultRef ?? this.defaultRef,
      defaultRecipient: defaultRecipient ?? this.defaultRecipient,
      defaultBodyMarkup: defaultBodyMarkup ?? this.defaultBodyMarkup,
      defaultMeetingLocation:
          defaultMeetingLocation ?? this.defaultMeetingLocation,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'docType': docType.id,
    'isBuiltIn': isBuiltIn,
    'defaultHeaderId': defaultHeaderId,
    'defaultSignatureBlockId': defaultSignatureBlockId,
    'defaultLayoutId': defaultLayoutId,
    'defaultRef': defaultRef,
    'defaultRecipient': defaultRecipient,
    'defaultBodyMarkup': defaultBodyMarkup,
    'defaultMeetingLocation': defaultMeetingLocation,
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
  };

  factory OfficialDocTemplate.fromJson(Map<String, dynamic> json) {
    return OfficialDocTemplate(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Modelo Personalizado').toString(),
      description: (json['description'] ?? '').toString(),
      docType: OfficialDocType.fromId(json['docType']?.toString()),
      isBuiltIn: json['isBuiltIn'] as bool? ?? false,
      defaultHeaderId: json['defaultHeaderId']?.toString(),
      defaultSignatureBlockId: json['defaultSignatureBlockId']?.toString(),
      defaultLayoutId: OfficialDocLayoutStyle.fromId(
        json['defaultLayoutId']?.toString(),
      ).id,
      defaultRef: (json['defaultRef'] ?? '').toString(),
      defaultRecipient: (json['defaultRecipient'] ?? '').toString(),
      defaultBodyMarkup: (json['defaultBodyMarkup'] ?? '').toString(),
      defaultMeetingLocation: (json['defaultMeetingLocation'] ?? '').toString(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }
}

/// Registro completo de uma Carta, Pauta ou Ata editada no aplicativo.
class OfficialDocumentRecord {
  final String id;
  final String title;
  final OfficialDocType docType;
  final String layoutStyleId;
  final String? headerProfileId;
  final String? signatureBlockId;
  final bool includeHeader;
  final bool includeSignature;
  final String? customGroupTitle;
  final List<SignerSlot>? customSigners;
  final OfficialFontSpec fontSpec;
  final String locationDate;
  final String referenceSubject;
  final String recipientLine;
  final String meetingDateTime;
  final String meetingLocation;
  final String openingPrayer;
  final String closingPrayer;
  final String participants;
  final String bodyMarkup;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime updatedAt;

  const OfficialDocumentRecord({
    required this.id,
    required this.title,
    required this.docType,
    this.layoutStyleId = 'original',
    this.headerProfileId,
    this.signatureBlockId,
    this.includeHeader = true,
    this.includeSignature = true,
    this.customGroupTitle,
    this.customSigners,
    this.fontSpec = const OfficialFontSpec(),
    this.locationDate = '',
    this.referenceSubject = '',
    this.recipientLine = '',
    this.meetingDateTime = '',
    this.meetingLocation = '',
    this.openingPrayer = '',
    this.closingPrayer = '',
    this.participants = '',
    this.bodyMarkup = '',
    this.isPinned = false,
    required this.createdAt,
    required this.updatedAt,
  });

  OfficialDocumentRecord copyWith({
    String? id,
    String? title,
    OfficialDocType? docType,
    String? layoutStyleId,
    String? headerProfileId,
    String? signatureBlockId,
    bool? includeHeader,
    bool? includeSignature,
    String? customGroupTitle,
    List<SignerSlot>? customSigners,
    bool clearCustomSigners = false,
    OfficialFontSpec? fontSpec,
    String? locationDate,
    String? referenceSubject,
    String? recipientLine,
    String? meetingDateTime,
    String? meetingLocation,
    String? openingPrayer,
    String? closingPrayer,
    String? participants,
    String? bodyMarkup,
    bool? isPinned,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OfficialDocumentRecord(
      id: id ?? this.id,
      title: title ?? this.title,
      docType: docType ?? this.docType,
      layoutStyleId: layoutStyleId ?? this.layoutStyleId,
      headerProfileId: headerProfileId ?? this.headerProfileId,
      signatureBlockId: signatureBlockId ?? this.signatureBlockId,
      includeHeader: includeHeader ?? this.includeHeader,
      includeSignature: includeSignature ?? this.includeSignature,
      customGroupTitle: customGroupTitle ?? this.customGroupTitle,
      customSigners: clearCustomSigners
          ? null
          : (customSigners ?? this.customSigners),
      fontSpec: fontSpec ?? this.fontSpec,
      locationDate: locationDate ?? this.locationDate,
      referenceSubject: referenceSubject ?? this.referenceSubject,
      recipientLine: recipientLine ?? this.recipientLine,
      meetingDateTime: meetingDateTime ?? this.meetingDateTime,
      meetingLocation: meetingLocation ?? this.meetingLocation,
      openingPrayer: openingPrayer ?? this.openingPrayer,
      closingPrayer: closingPrayer ?? this.closingPrayer,
      participants: participants ?? this.participants,
      bodyMarkup: bodyMarkup ?? this.bodyMarkup,
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'docType': docType.id,
    'layoutStyleId': layoutStyleId,
    'headerProfileId': headerProfileId,
    'signatureBlockId': signatureBlockId,
    'includeHeader': includeHeader,
    'includeSignature': includeSignature,
    if (customGroupTitle != null) 'customGroupTitle': customGroupTitle,
    if (customSigners != null)
      'customSigners': customSigners!.map((s) => s.toJson()).toList(),
    'fontSpec': fontSpec.toJson(),
    'locationDate': locationDate,
    'referenceSubject': referenceSubject,
    'recipientLine': recipientLine,
    'meetingDateTime': meetingDateTime,
    'meetingLocation': meetingLocation,
    'openingPrayer': openingPrayer,
    'closingPrayer': closingPrayer,
    'participants': participants,
    'bodyMarkup': bodyMarkup,
    'isPinned': isPinned,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory OfficialDocumentRecord.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    final customSlots = json['customSigners'] is List
        ? (json['customSigners'] as List)
              .whereType<Map<String, dynamic>>()
              .map(SignerSlot.fromJson)
              .toList()
        : null;
    return OfficialDocumentRecord(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? 'Documento Oficial').toString(),
      docType: OfficialDocType.fromId(json['docType']?.toString()),
      layoutStyleId: OfficialDocLayoutStyle.fromId(
        json['layoutStyleId']?.toString(),
      ).id,
      headerProfileId: json['headerProfileId']?.toString(),
      signatureBlockId: json['signatureBlockId']?.toString(),
      includeHeader: json['includeHeader'] as bool? ?? true,
      includeSignature: json['includeSignature'] as bool? ?? true,
      customGroupTitle: json['customGroupTitle']?.toString(),
      customSigners: customSlots,
      fontSpec: OfficialFontSpec.fromJson(
        json['fontSpec'] as Map<String, dynamic>?,
      ),
      locationDate: (json['locationDate'] ?? '').toString(),
      referenceSubject: (json['referenceSubject'] ?? '').toString(),
      recipientLine: (json['recipientLine'] ?? '').toString(),
      meetingDateTime: (json['meetingDateTime'] ?? '').toString(),
      meetingLocation: (json['meetingLocation'] ?? '').toString(),
      openingPrayer: (json['openingPrayer'] ?? '').toString(),
      closingPrayer: (json['closingPrayer'] ?? '').toString(),
      participants: (json['participants'] ?? '').toString(),
      bodyMarkup: (json['bodyMarkup'] ?? '').toString(),
      isPinned: json['isPinned'] as bool? ?? false,
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ?? now,
      updatedAt: DateTime.tryParse((json['updatedAt'] ?? '').toString()) ?? now,
    );
  }
}

/// Pacote completo importável/exportável (Drive / JSON local) com cabeçalhos, anciãos,
/// blocos de assinatura, fontes padrão e modelos personalizados.
class OfficialDocProfileBundle {
  final int schemaVersion;
  final String bundleName;
  final String defaultStyleId;
  final OfficialFontSpec defaultFonts;
  final List<OfficialHeaderProfile> headers;
  final List<ElderSignerProfile> elders;
  final List<OfficialSignatureBlock> signatureBlocks;
  final List<OfficialDocTemplate> customTemplates;

  const OfficialDocProfileBundle({
    this.schemaVersion = 1,
    this.bundleName = 'Perfis de Cartas & Atas',
    this.defaultStyleId = 'original',
    this.defaultFonts = const OfficialFontSpec(),
    this.headers = const [],
    this.elders = const [],
    this.signatureBlocks = const [],
    this.customTemplates = const [],
  });

  OfficialDocProfileBundle copyWith({
    int? schemaVersion,
    String? bundleName,
    String? defaultStyleId,
    OfficialFontSpec? defaultFonts,
    List<OfficialHeaderProfile>? headers,
    List<ElderSignerProfile>? elders,
    List<OfficialSignatureBlock>? signatureBlocks,
    List<OfficialDocTemplate>? customTemplates,
  }) {
    return OfficialDocProfileBundle(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      bundleName: bundleName ?? this.bundleName,
      defaultStyleId: defaultStyleId ?? this.defaultStyleId,
      defaultFonts: defaultFonts ?? this.defaultFonts,
      headers: headers ?? this.headers,
      elders: elders ?? this.elders,
      signatureBlocks: signatureBlocks ?? this.signatureBlocks,
      customTemplates: customTemplates ?? this.customTemplates,
    );
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'bundleName': bundleName,
    'defaultStyleId': defaultStyleId,
    'defaultFonts': defaultFonts.toJson(),
    'headers': headers.map((h) => h.toJson()).toList(),
    'elders': elders.map((e) => e.toJson()).toList(),
    'signatureBlocks': signatureBlocks.map((s) => s.toJson()).toList(),
    'customTemplates': customTemplates.map((t) => t.toJson()).toList(),
  };

  String toPrettyJsonString() =>
      const JsonEncoder.withIndent('  ').convert(toJson());

  factory OfficialDocProfileBundle.fromJson(Map<String, dynamic> json) {
    return OfficialDocProfileBundle(
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
      bundleName: (json['bundleName'] ?? 'Perfis Importados').toString(),
      defaultStyleId: OfficialDocLayoutStyle.fromId(
        json['defaultStyleId']?.toString(),
      ).id,
      defaultFonts: OfficialFontSpec.fromJson(
        json['defaultFonts'] as Map<String, dynamic>?,
      ),
      headers: (json['headers'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(OfficialHeaderProfile.fromJson)
          .toList(),
      elders: (json['elders'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ElderSignerProfile.fromJson)
          .toList(),
      signatureBlocks: (json['signatureBlocks'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(OfficialSignatureBlock.fromJson)
          .toList(),
      customTemplates: (json['customTemplates'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(OfficialDocTemplate.fromJson)
          .toList(),
    );
  }
}
