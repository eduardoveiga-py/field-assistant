import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../official_docs/official_doc_fonts.dart';
import '../../../official_docs/official_doc_models.dart';
import '../../../official_docs/official_markup_parser.dart';

/// Pré-visualização WYSIWYG em proporção A4 fiel a todos os 7 estilos visuais,
/// respeitando fontes personalizadas, cabeçalho, metadados, marcações ricas e assinaturas.
class OfficialDocPreviewWidget extends StatelessWidget {
  final OfficialDocumentRecord doc;
  final OfficialHeaderProfile? header;
  final String signatureGroupTitle;
  final List<SignerSlot> signers;
  final double maxWidth;

  const OfficialDocPreviewWidget({
    super.key,
    required this.doc,
    required this.header,
    required this.signatureGroupTitle,
    required this.signers,
    this.maxWidth = 680,
  });

  static Color _hexToColor(String hex, Color fallback) {
    final c = hex.trim().replaceFirst('#', '');
    if (c.length != 6) return fallback;
    final parsed = int.tryParse(c, radix: 16);
    if (parsed == null) return fallback;
    return Color(0xFF000000 | parsed);
  }

  @override
  Widget build(BuildContext context) {
    final style = OfficialDocLayoutStyle.fromId(doc.layoutStyleId);
    final fonts = doc.fontSpec;
    final headerFamily = OfficialDocFonts.findById(fonts.headerFontId)
        .flutterFamily;
    final metaFamily = OfficialDocFonts.findById(fonts.metaFontId)
        .flutterFamily;
    final bodyFamily = OfficialDocFonts.findById(fonts.bodyFontId)
        .flutterFamily;
    final defaultSigFamily = OfficialDocFonts.findById(fonts.signatureFontId)
        .flutterFamily;

    final primary = _hexToColor(
      header?.primaryColorHex ?? '#1D4ED8',
      const Color(0xFF1D4ED8),
    );
    final accent = _hexToColor(
      header?.accentColorHex ?? '#0F766E',
      const Color(0xFF0F766E),
    );

    final showHeader =
        doc.includeHeader && header != null && !header!.isEmptyHeader;
    final showSignature =
        doc.includeSignature &&
        (signatureGroupTitle.trim().isNotEmpty || signers.isNotEmpty);

    final blocks = OfficialMarkupParser.parseBlocks(doc.bodyMarkup);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFFCBD5E1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Elementos decorativos de borda conforme o estilo
              if (style == OfficialDocLayoutStyle.original)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(height: 6, color: primary),
                ),
              if (style == OfficialDocLayoutStyle.classicRefined) ...[
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(height: 5, color: primary),
                ),
                Positioned(
                  top: 5,
                  left: 0,
                  right: 0,
                  child: Container(height: 2, color: accent),
                ),
              ],
              if (style == OfficialDocLayoutStyle.editorialModern)
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: 0,
                  child: Container(width: 8, color: primary),
                ),
              if (style == OfficialDocLayoutStyle.diplomaticGold) ...[
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(height: 4, color: const Color(0xFF0F294A)),
                ),
                Positioned(
                  top: 4,
                  left: 0,
                  right: 0,
                  child: Container(height: 2, color: const Color(0xFFB4832E)),
                ),
              ],
              if (style == OfficialDocLayoutStyle.stationeryWatermark &&
                  showHeader) ...[
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 112,
                    color: Color.alphaBlend(
                      primary.withValues(alpha: 0.06),
                      Colors.white,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: Center(
                      child: Transform.rotate(
                        angle: -0.35,
                        child: Text(
                          header!.extractedCode,
                          style: TextStyle(
                            fontFamily: headerFamily,
                            fontSize: 96,
                            fontWeight: FontWeight.w700,
                            color: primary.withValues(alpha: 0.045),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              Padding(
                padding: EdgeInsets.fromLTRB(
                  style == OfficialDocLayoutStyle.editorialModern ? 34 : 28,
                  28,
                  28,
                  26,
                ),
                child: DefaultTextStyle(
                  style: const TextStyle(color: Color(0xFF1E293B)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showHeader) ...[
                        _buildHeader(
                          style: style,
                          header: header!,
                          headerFamily: headerFamily,
                          primary: primary,
                          accent: accent,
                        ),
                        const SizedBox(height: 14),
                      ],
                      _buildMetadata(
                        style: style,
                        metaFamily: metaFamily,
                        primary: primary,
                        accent: accent,
                      ),
                      const SizedBox(height: 14),
                      ..._buildBodyBlocks(
                        blocks: blocks,
                        bodyFamily: bodyFamily,
                        fontSize: (fonts.bodyFontSizePt * 1.25).clamp(
                          11.0,
                          16.5,
                        ),
                        justify: fonts.justifyBody,
                        primary: primary,
                      ),
                      if (showSignature) ...[
                        const SizedBox(height: 20),
                        _buildSignatureSection(
                          style: style,
                          metaFamily: metaFamily,
                          defaultSigFamily: defaultSigFamily,
                          primary: primary,
                          accent: accent,
                        ),
                      ],
                      if ((header?.footerNote.trim().isNotEmpty ?? false) ||
                          style != OfficialDocLayoutStyle.original) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.only(top: 6),
                          decoration: const BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                color: Color(0xFFE2E8F0),
                                width: 0.8,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  (header?.footerNote.trim().isNotEmpty ??
                                          false)
                                      ? header!.footerNote.trim()
                                      : (header?.topSubtitle ?? ''),
                                  style: TextStyle(
                                    fontFamily: metaFamily,
                                    fontSize: 9.5,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                ),
                              ),
                              if (style != OfficialDocLayoutStyle.original ||
                                  (header?.showPageNumbers ?? false))
                                Text(
                                  'Página 1 de 1',
                                  style: TextStyle(
                                    fontFamily: metaFamily,
                                    fontSize: 9.5,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader({
    required OfficialDocLayoutStyle style,
    required OfficialHeaderProfile header,
    required String headerFamily,
    required Color primary,
    required Color accent,
  }) {
    final addr = [
      if (header.addressLine1.trim().isNotEmpty) header.addressLine1.trim(),
      if (header.addressLine2.trim().isNotEmpty) header.addressLine2.trim(),
    ];

    switch (style) {
      case OfficialDocLayoutStyle.contemporaryPanel:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF0F294A),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (header.topSubtitle.isNotEmpty)
                      Text(
                        header.topSubtitle,
                        style: TextStyle(
                          fontFamily: headerFamily,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: const Color(0xFF93C5FD),
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      header.mainTitle,
                      style: TextStyle(
                        fontFamily: headerFamily,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final line in addr)
                    Text(
                      line,
                      style: TextStyle(
                        fontFamily: headerFamily,
                        fontSize: 10.5,
                        color: const Color(0xFFE2E8F0),
                      ),
                    ),
                  if (header.contactEmail.trim().isNotEmpty)
                    Text(
                      header.contactEmail.trim(),
                      style: TextStyle(
                        fontFamily: headerFamily,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF93C5FD),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );

      case OfficialDocLayoutStyle.diplomaticGold:
        return Container(
          padding: const EdgeInsets.only(bottom: 10),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0xFFB4832E), width: 1.5),
            ),
          ),
          child: Column(
            children: [
              if (header.topSubtitle.isNotEmpty)
                Text(
                  header.topSubtitle.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: headerFamily,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: const Color(0xFFB4832E),
                  ),
                ),
              const SizedBox(height: 3),
              Text(
                header.mainTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: headerFamily,
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F294A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                [
                  ...addr,
                  if (header.contactEmail.isNotEmpty) header.contactEmail,
                ].join(' · '),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: headerFamily,
                  fontSize: 10.5,
                  color: const Color(0xFF475569),
                ),
              ),
            ],
          ),
        );

      case OfficialDocLayoutStyle.executiveMinimal:
        return Container(
          padding: const EdgeInsets.only(bottom: 10),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0xFFCBD5E1), width: 1),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  header.extractedCode,
                  style: TextStyle(
                    fontFamily: headerFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (header.topSubtitle.isNotEmpty)
                      Text(
                        header.topSubtitle,
                        style: TextStyle(
                          fontFamily: headerFamily,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: primary,
                        ),
                      ),
                    Text(
                      header.mainTitle,
                      style: TextStyle(
                        fontFamily: headerFamily,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final line in addr)
                    Text(
                      line,
                      style: TextStyle(
                        fontFamily: headerFamily,
                        fontSize: 10,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  if (header.contactEmail.isNotEmpty)
                    Text(
                      header.contactEmail,
                      style: TextStyle(
                        fontFamily: headerFamily,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: primary,
                      ),
                    ),
                ],
              ),
            ],
          ),
        );

      case OfficialDocLayoutStyle.stationeryWatermark:
        return Container(
          padding: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: primary.withValues(alpha: 0.35)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (header.topSubtitle.isNotEmpty)
                        Text(
                          header.topSubtitle,
                          style: TextStyle(
                            fontFamily: headerFamily,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: accent,
                          ),
                        ),
                      Text(
                        header.mainTitle,
                        style: TextStyle(
                          fontFamily: headerFamily,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: primary,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final line in addr)
                        Text(
                          line,
                          style: TextStyle(
                            fontFamily: headerFamily,
                            fontSize: 10,
                            color: const Color(0xFF475569),
                          ),
                        ),
                      if (header.contactEmail.isNotEmpty)
                        Text(
                          header.contactEmail,
                          style: TextStyle(
                            fontFamily: headerFamily,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: primary,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );

      case OfficialDocLayoutStyle.original:
      case OfficialDocLayoutStyle.classicRefined:
      case OfficialDocLayoutStyle.editorialModern:
        return Container(
          padding: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: style == OfficialDocLayoutStyle.classicRefined
                    ? accent
                    : const Color(0xFFCBD5E1),
                width: style == OfficialDocLayoutStyle.classicRefined ? 1.5 : 1,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (header.topSubtitle.isNotEmpty)
                      Text(
                        header.topSubtitle,
                        style: TextStyle(
                          fontFamily: headerFamily,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: primary,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      header.mainTitle,
                      style: TextStyle(
                        fontFamily: headerFamily,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final line in addr)
                    Text(
                      line,
                      style: TextStyle(
                        fontFamily: headerFamily,
                        fontSize: 10.5,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  if (header.contactEmail.trim().isNotEmpty)
                    Text(
                      header.contactEmail.trim(),
                      style: TextStyle(
                        fontFamily: headerFamily,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: primary,
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
    }
  }

  Widget _buildMetadata({
    required OfficialDocLayoutStyle style,
    required String metaFamily,
    required Color primary,
    required Color accent,
  }) {
    final isMeeting = doc.docType.isMeeting;
    final cardColor = style == OfficialDocLayoutStyle.editorialModern
        ? const Color(0xFFF1F5F9)
        : (style == OfficialDocLayoutStyle.contemporaryPanel
              ? const Color(0xFFF8FAFC)
              : null);

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!isMeeting && doc.locationDate.trim().isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              doc.locationDate.trim(),
              style: TextStyle(
                fontFamily: metaFamily,
                fontSize: 11.5,
                color: const Color(0xFF475569),
              ),
            ),
          ),
        if (doc.referenceSubject.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isMeeting ? 'Documento: ' : 'Ref.: ',
                style: TextStyle(
                  fontFamily: metaFamily,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: style == OfficialDocLayoutStyle.classicRefined
                      ? accent
                      : primary,
                ),
              ),
              Expanded(
                child: Text(
                  doc.referenceSubject.trim(),
                  style: TextStyle(
                    fontFamily: metaFamily,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
        ],
        if (doc.recipientLine.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isMeeting ? 'Convocação: ' : 'A/C: ',
                style: TextStyle(
                  fontFamily: metaFamily,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF475569),
                ),
              ),
              Expanded(
                child: Text(
                  doc.recipientLine.trim(),
                  style: TextStyle(
                    fontFamily: metaFamily,
                    fontSize: 11.5,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),
        ],
        if (isMeeting &&
            (doc.meetingDateTime.trim().isNotEmpty ||
                doc.meetingLocation.trim().isNotEmpty ||
                doc.participants.trim().isNotEmpty ||
                doc.openingPrayer.trim().isNotEmpty ||
                doc.closingPrayer.trim().isNotEmpty)) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              if (doc.meetingDateTime.trim().isNotEmpty)
                _metaChip(metaFamily, 'Data/Hora', doc.meetingDateTime),
              if (doc.meetingLocation.trim().isNotEmpty)
                _metaChip(metaFamily, 'Local', doc.meetingLocation),
              if (doc.openingPrayer.trim().isNotEmpty)
                _metaChip(metaFamily, 'Oração inicial', doc.openingPrayer),
              if (doc.closingPrayer.trim().isNotEmpty)
                _metaChip(metaFamily, 'Oração final', doc.closingPrayer),
              if (doc.participants.trim().isNotEmpty)
                _metaChip(metaFamily, 'Participantes', doc.participants),
            ],
          ),
        ],
      ],
    );

    if (cardColor != null) {
      content = Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: content,
      );
    }
    return content;
  }

  Widget _metaChip(String family, String k, String v) {
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontFamily: family,
          fontSize: 11,
          color: const Color(0xFF334155),
        ),
        children: [
          TextSpan(
            text: '$k: ',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: v.trim()),
        ],
      ),
    );
  }

  List<Widget> _buildBodyBlocks({
    required List<OfficialDocBlock> blocks,
    required String bodyFamily,
    required double fontSize,
    required bool justify,
    required Color primary,
  }) {
    if (blocks.isEmpty) {
      return [
        Text(
          '(O corpo da carta ou ata aparecerá aqui em tempo real)',
          style: TextStyle(
            fontFamily: bodyFamily,
            fontSize: fontSize,
            fontStyle: FontStyle.italic,
            color: const Color(0xFF94A3B8),
          ),
        ),
      ];
    }

    final widgets = <Widget>[];
    for (var i = 0; i < blocks.length; i++) {
      final b = blocks[i];
      final isFirst = i == 0;
      final isLast = i == blocks.length - 1;
      final align =
          (justify &&
              b.kind == OfficialBlockKind.paragraph &&
              !isFirst &&
              !isLast)
          ? TextAlign.justify
          : TextAlign.left;

      final spans = b.runs
          .map(
            (r) => TextSpan(
              text: r.text,
              style: TextStyle(
                fontFamily: bodyFamily,
                fontSize: b.kind == OfficialBlockKind.heading
                    ? (b.headingLevel == 1
                          ? fontSize + 4
                          : (b.headingLevel == 2 ? fontSize + 2 : fontSize + 1))
                    : fontSize,
                height: 1.48,
                fontWeight: (r.bold || b.kind == OfficialBlockKind.heading)
                    ? FontWeight.w700
                    : FontWeight.w400,
                fontStyle: (r.italic || b.kind == OfficialBlockKind.quote)
                    ? FontStyle.italic
                    : FontStyle.normal,
                decoration: TextDecoration.combine([
                  if (r.underline) TextDecoration.underline,
                  if (r.strikethrough) TextDecoration.lineThrough,
                ]),
                color: b.kind == OfficialBlockKind.heading
                    ? primary
                    : (b.kind == OfficialBlockKind.quote
                          ? const Color(0xFF475569)
                          : const Color(0xFF1E293B)),
              ),
            ),
          )
          .toList();

      switch (b.kind) {
        case OfficialBlockKind.heading:
          widgets.add(
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 4),
              child: RichText(text: TextSpan(children: spans)),
            ),
          );
          break;
        case OfficialBlockKind.bulletItem:
        case OfficialBlockKind.numberedItem:
          final prefix = b.kind == OfficialBlockKind.bulletItem
              ? '•  '
              : '${b.numberIndex ?? 1}.  ';
          widgets.add(
            Padding(
              padding: const EdgeInsets.only(left: 10, bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    prefix,
                    style: TextStyle(
                      fontFamily: bodyFamily,
                      fontSize: fontSize,
                      fontWeight: FontWeight.w700,
                      color: primary,
                    ),
                  ),
                  Expanded(
                    child: RichText(
                      textAlign: TextAlign.left,
                      text: TextSpan(children: spans),
                    ),
                  ),
                ],
              ),
            ),
          );
          break;
        case OfficialBlockKind.quote:
          widgets.add(
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                border: Border(left: BorderSide(color: primary, width: 3)),
              ),
              child: RichText(text: TextSpan(children: spans)),
            ),
          );
          break;
        case OfficialBlockKind.paragraph:
          widgets.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: RichText(
                textAlign: align,
                text: TextSpan(children: spans),
              ),
            ),
          );
          break;
      }
    }
    return widgets;
  }

  Widget _buildSignatureSection({
    required OfficialDocLayoutStyle style,
    required String metaFamily,
    required String defaultSigFamily,
    required Color primary,
    required Color accent,
  }) {
    final lineColor = style == OfficialDocLayoutStyle.diplomaticGold
        ? const Color(0xFFB4832E)
        : (style == OfficialDocLayoutStyle.classicRefined ? accent : primary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (signatureGroupTitle.trim().isNotEmpty) ...[
          Text(
            signatureGroupTitle.trim(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: metaFamily,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (signers.isNotEmpty)
          Wrap(
            alignment: WrapAlignment.spaceEvenly,
            spacing: 24,
            runSpacing: 16,
            children: signers.map((slot) {
              final sigFont = OfficialDocFonts.findById(
                slot.signatureFontIdOverride,
                fallbackId: OfficialDocFonts.findById(defaultSigFamily).id,
              ).flutterFamily;

              Uint8List? pngBytes;
              final b64 = slot.signaturePngBase64Override?.trim();
              if (b64 != null && b64.isNotEmpty) {
                try {
                  pngBytes = base64Decode(b64);
                } catch (_) {}
              }

              return SizedBox(
                width: signers.length == 1 ? 230 : 175,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 36,
                      child: Center(
                        child: pngBytes != null
                            ? Image.memory(
                                pngBytes,
                                height: 34,
                                fit: BoxFit.contain,
                              )
                            : Text(
                                slot.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: sigFont,
                                  fontSize: 22,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                      ),
                    ),
                    Container(
                      height: 1,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      color: lineColor.withValues(alpha: 0.45),
                    ),
                    Text(
                      slot.name,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: metaFamily,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    if (slot.role.trim().isNotEmpty)
                      Text(
                        slot.role.trim(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: metaFamily,
                          fontSize: 10,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}
