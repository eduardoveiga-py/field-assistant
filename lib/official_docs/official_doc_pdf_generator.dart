import 'dart:convert';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'official_doc_fonts.dart';
import 'official_doc_models.dart';
import 'official_markup_parser.dart';

/// Gerador 100% offline e multiplataforma (PWA Web + Nativo) de PDF e PNG
/// para todos os 7 estilos visuais de Cartas, Pautas e Atas.
class OfficialDocPdfGenerator {
  OfficialDocPdfGenerator._();

  static PdfColor _hexColor(String hex, PdfColor fallback) {
    final cleaned = hex.trim().replaceFirst('#', '');
    if (cleaned.length != 6) return fallback;
    final val = int.tryParse(cleaned, radix: 16);
    if (val == null) return fallback;
    return PdfColor.fromInt(0xFF000000 | val);
  }

  static Future<Uint8List> generatePdfBytes({
    required OfficialDocumentRecord doc,
    OfficialHeaderProfile? header,
    required String signatureGroupTitle,
    required List<SignerSlot> signers,
  }) async {
    final style = OfficialDocLayoutStyle.fromId(doc.layoutStyleId);
    final fonts = doc.fontSpec;

    final headerFonts = await OfficialDocFonts.loadPdfBundle(
      fonts.headerFontId,
    );
    final metaFonts = await OfficialDocFonts.loadPdfBundle(fonts.metaFontId);
    final bodyFonts = await OfficialDocFonts.loadPdfBundle(fonts.bodyFontId);
    final defaultSigFonts = await OfficialDocFonts.loadPdfBundle(
      fonts.signatureFontId,
    );

    final perSignerFonts = <String, OfficialPdfFontBundle>{};
    for (final s in signers) {
      final fId = s.signatureFontIdOverride;
      if (fId != null && fId.isNotEmpty && !perSignerFonts.containsKey(fId)) {
        perSignerFonts[fId] = await OfficialDocFonts.loadPdfBundle(fId);
      }
    }

    final primaryColor = _hexColor(
      header?.primaryColorHex ?? '#1D4ED8',
      PdfColor.fromInt(0xFF1D4ED8),
    );
    final accentColor = _hexColor(
      header?.accentColorHex ?? '#0F766E',
      PdfColor.fromInt(0xFF0F766E),
    );

    final showHeader =
        doc.includeHeader && header != null && !header.isEmptyHeader;
    final showSignature =
        doc.includeSignature &&
        (signatureGroupTitle.trim().isNotEmpty || signers.isNotEmpty);

    final blocks = OfficialMarkupParser.parseBlocks(doc.bodyMarkup);
    final pdf = pw.Document(
      title: doc.title,
      author: header?.topSubtitle.isNotEmpty == true
          ? header!.topSubtitle
          : 'Ministério Pessoal',
      theme: pw.ThemeData.withFont(
        base: bodyFonts.base,
        bold: bodyFonts.bold,
        italic: bodyFonts.italic,
        boldItalic: bodyFonts.boldItalic,
      ),
    );

    final pageTheme = pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      margin: _marginsForStyle(style),
      buildBackground: (ctx) =>
          _buildPageBackground(style, header, primaryColor, accentColor),
    );

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pageTheme,
        footer: (ctx) => _buildPageFooter(
          style: style,
          header: header,
          metaFonts: metaFonts,
          context: ctx,
        ),
        build: (ctx) {
          final widgets = <pw.Widget>[];

          if (showHeader) {
            widgets.add(
              _buildHeader(
                style: style,
                header: header,
                headerFonts: headerFonts,
                primaryColor: primaryColor,
                accentColor: accentColor,
              ),
            );
            widgets.add(pw.SizedBox(height: 14));
          }

          widgets.add(
            _buildMetadataSection(
              style: style,
              doc: doc,
              metaFonts: metaFonts,
              primaryColor: primaryColor,
              accentColor: accentColor,
            ),
          );
          widgets.add(pw.SizedBox(height: 12));

          widgets.addAll(
            _buildBodyBlocks(
              blocks: blocks,
              fonts: fonts,
              bodyFonts: bodyFonts,
              primaryColor: primaryColor,
              accentColor: accentColor,
            ),
          );

          if (showSignature) {
            widgets.add(pw.SizedBox(height: 18));
            widgets.add(
              _buildSignatureSection(
                style: style,
                groupTitle: signatureGroupTitle,
                signers: signers,
                metaFonts: metaFonts,
                defaultSigFonts: defaultSigFonts,
                perSignerFonts: perSignerFonts,
                primaryColor: primaryColor,
                accentColor: accentColor,
              ),
            );
          }

          return widgets;
        },
      ),
    );

    return pdf.save();
  }

  /// Rasteriza cada página do PDF gerado em PNG fiel (compatível com Web PWA + Nativo).
  static Future<List<Uint8List>> renderPngPages(
    Uint8List pdfBytes, {
    double dpi = 180,
  }) async {
    final pages = <Uint8List>[];
    await for (final raster in Printing.raster(pdfBytes, dpi: dpi)) {
      pages.add(await raster.toPng());
    }
    return pages;
  }

  static pw.EdgeInsets _marginsForStyle(OfficialDocLayoutStyle style) {
    switch (style) {
      case OfficialDocLayoutStyle.editorialModern:
        return const pw.EdgeInsets.fromLTRB(56, 40, 48, 36);
      case OfficialDocLayoutStyle.diplomaticGold:
      case OfficialDocLayoutStyle.stationeryWatermark:
        return const pw.EdgeInsets.fromLTRB(52, 42, 52, 40);
      case OfficialDocLayoutStyle.original:
      case OfficialDocLayoutStyle.classicRefined:
      case OfficialDocLayoutStyle.executiveMinimal:
      case OfficialDocLayoutStyle.contemporaryPanel:
        return const pw.EdgeInsets.fromLTRB(48, 38, 48, 34);
    }
  }

  static pw.Widget _buildPageBackground(
    OfficialDocLayoutStyle style,
    OfficialHeaderProfile? header,
    PdfColor primaryColor,
    PdfColor accentColor,
  ) {
    switch (style) {
      case OfficialDocLayoutStyle.original:
        return pw.Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: pw.Container(height: 3.5, color: primaryColor),
        );
      case OfficialDocLayoutStyle.classicRefined:
        return pw.Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: pw.Row(
            children: [
              pw.Expanded(
                flex: 7,
                child: pw.Container(height: 9, color: primaryColor),
              ),
              pw.Expanded(
                flex: 3,
                child: pw.Container(height: 9, color: accentColor),
              ),
            ],
          ),
        );
      case OfficialDocLayoutStyle.editorialModern:
        return pw.Positioned(
          top: 0,
          bottom: 0,
          left: 0,
          child: pw.Container(width: 8, color: primaryColor),
        );
      case OfficialDocLayoutStyle.stationeryWatermark:
        final mark = header?.topSubtitle.trim().isNotEmpty == true
            ? header!.topSubtitle.trim()
            : 'CORRESPONDÊNCIA';
        return pw.Center(
          child: pw.Transform.rotateBox(
            angle: 0.30,
            child: pw.Opacity(
              opacity: 0.045,
              child: pw.Text(
                mark,
                style: pw.TextStyle(
                  fontSize: 38,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ),
          ),
        );
      case OfficialDocLayoutStyle.diplomaticGold:
        final gold = PdfColor.fromInt(0xFFB45309);
        return pw.Positioned.fill(
          child: pw.Padding(
            padding: const pw.EdgeInsets.all(22),
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  children: [
                    pw.Container(
                      height: 2.2,
                      color: PdfColor.fromInt(0xFF0F172A),
                    ),
                    pw.SizedBox(height: 2.2),
                    pw.Container(height: 0.8, color: gold),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.Container(height: 0.8, color: gold),
                    pw.SizedBox(height: 2.2),
                    pw.Container(
                      height: 1.8,
                      color: PdfColor.fromInt(0xFF0F172A),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      case OfficialDocLayoutStyle.executiveMinimal:
      case OfficialDocLayoutStyle.contemporaryPanel:
        return pw.SizedBox();
    }
  }

  static pw.Widget _buildHeader({
    required OfficialDocLayoutStyle style,
    required OfficialHeaderProfile header,
    required OfficialPdfFontBundle headerFonts,
    required PdfColor primaryColor,
    required PdfColor accentColor,
  }) {
    final textDark = PdfColor.fromInt(0xFF0F172A);
    final textMuted = PdfColor.fromInt(0xFF475569);

    if (style == OfficialDocLayoutStyle.diplomaticGold) {
      final gold = PdfColor.fromInt(0xFFB45309);
      final contactParts = [
        if (header.addressLine1.trim().isNotEmpty) header.addressLine1.trim(),
        if (header.contactEmail.trim().isNotEmpty) header.contactEmail.trim(),
      ].join('  •  ');
      return pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 10),
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(
              color: PdfColor.fromInt(0xFFCBD5E1),
              width: 0.8,
            ),
          ),
        ),
        child: pw.Column(
          children: [
            if (header.topSubtitle.trim().isNotEmpty)
              pw.Text(
                header.topSubtitle.toUpperCase(),
                style: pw.TextStyle(
                  font: headerFonts.bold,
                  fontSize: 8.8,
                  letterSpacing: 1.4,
                  color: gold,
                ),
              ),
            if (header.mainTitle.trim().isNotEmpty) ...[
              pw.SizedBox(height: 3),
              pw.Text(
                header.mainTitle,
                style: pw.TextStyle(
                  font: headerFonts.bold,
                  fontSize: 16,
                  color: PdfColor.fromInt(0xFF0F172A),
                ),
              ),
            ],
            if (contactParts.isNotEmpty) ...[
              pw.SizedBox(height: 3),
              pw.Text(
                contactParts,
                style: pw.TextStyle(
                  font: headerFonts.base,
                  fontSize: 8.2,
                  color: textMuted,
                ),
              ),
            ],
          ],
        ),
      );
    }

    if (style == OfficialDocLayoutStyle.contemporaryPanel) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromInt(0xFF0F294A),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (header.topSubtitle.trim().isNotEmpty)
                    pw.Text(
                      header.topSubtitle.toUpperCase(),
                      style: pw.TextStyle(
                        font: headerFonts.bold,
                        fontSize: 8.3,
                        letterSpacing: 1.1,
                        color: PdfColor.fromInt(0xFF5EEAD4),
                      ),
                    ),
                  if (header.mainTitle.trim().isNotEmpty) ...[
                    pw.SizedBox(height: 3),
                    pw.Text(
                      header.mainTitle,
                      style: pw.TextStyle(
                        font: headerFonts.bold,
                        fontSize: 15.5,
                        color: PdfColors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                if (header.addressLine1.trim().isNotEmpty)
                  pw.Text(
                    header.addressLine1,
                    style: pw.TextStyle(
                      font: headerFonts.base,
                      fontSize: 8,
                      color: PdfColor.fromInt(0xFFE2E8F0),
                    ),
                  ),
                if (header.addressLine2.trim().isNotEmpty)
                  pw.Text(
                    header.addressLine2,
                    style: pw.TextStyle(
                      font: headerFonts.base,
                      fontSize: 8,
                      color: PdfColor.fromInt(0xFFE2E8F0),
                    ),
                  ),
                if (header.contactEmail.trim().isNotEmpty)
                  pw.Text(
                    header.contactEmail,
                    style: pw.TextStyle(
                      font: headerFonts.bold,
                      fontSize: 8,
                      color: PdfColor.fromInt(0xFF99F6E4),
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
    }

    if (style == OfficialDocLayoutStyle.stationeryWatermark) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromInt(0xFFF8FAFC),
          border: pw.Border(
            top: pw.BorderSide(color: primaryColor, width: 2.0),
            bottom: const pw.BorderSide(
              color: PdfColor.fromInt(0xFF94A3B8),
              width: 0.8,
            ),
          ),
        ),
        child: _twoColHeaderRow(
          header: header,
          headerFonts: headerFonts,
          titleColor: textDark,
          subColor: accentColor,
          rightColor: textMuted,
          emailColor: primaryColor,
        ),
      );
    }

    if (style == OfficialDocLayoutStyle.executiveMinimal) {
      return pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 10),
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(
              color: PdfColor.fromInt(0xFF1E293B),
              width: 1.5,
            ),
          ),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Row(
              children: [
                pw.Container(
                  width: 34,
                  height: 34,
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFF1E3A5F),
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(2),
                    ),
                  ),
                  alignment: pw.Alignment.center,
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Text(
                        'CONG.',
                        style: pw.TextStyle(
                          font: headerFonts.base,
                          fontSize: 6.2,
                          color: PdfColor.fromInt(0xFFE2E8F0),
                        ),
                      ),
                      pw.Text(
                        header.extractedCode,
                        style: pw.TextStyle(
                          font: headerFonts.bold,
                          fontSize: 8.2,
                          color: PdfColors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (header.topSubtitle.trim().isNotEmpty)
                      pw.Text(
                        header.topSubtitle.toUpperCase(),
                        style: pw.TextStyle(
                          font: headerFonts.bold,
                          fontSize: 8.5,
                          letterSpacing: 0.9,
                          color: textMuted,
                        ),
                      ),
                    if (header.mainTitle.trim().isNotEmpty)
                      pw.Text(
                        header.mainTitle,
                        style: pw.TextStyle(
                          font: headerFonts.bold,
                          fontSize: 15,
                          color: textDark,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            _headerRightAddress(
              header: header,
              headerFonts: headerFonts,
              rightColor: textMuted,
              emailColor: primaryColor,
            ),
          ],
        ),
      );
    }

    if (style == OfficialDocLayoutStyle.editorialModern) {
      return pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 10),
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(
              color: PdfColor.fromInt(0xFFCBD5E1),
              width: 0.9,
            ),
          ),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.only(left: 9),
              decoration: pw.BoxDecoration(
                border: pw.Border(
                  left: pw.BorderSide(color: accentColor, width: 3),
                ),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (header.topSubtitle.trim().isNotEmpty)
                    pw.Text(
                      header.topSubtitle.toUpperCase(),
                      style: pw.TextStyle(
                        font: headerFonts.bold,
                        fontSize: 8.5,
                        letterSpacing: 0.9,
                        color: accentColor,
                      ),
                    ),
                  if (header.mainTitle.trim().isNotEmpty)
                    pw.Text(
                      header.mainTitle,
                      style: pw.TextStyle(
                        font: headerFonts.bold,
                        fontSize: 16,
                        color: textDark,
                      ),
                    ),
                ],
              ),
            ),
            _headerRightAddress(
              header: header,
              headerFonts: headerFonts,
              rightColor: textMuted,
              emailColor: primaryColor,
            ),
          ],
        ),
      );
    }

    // original & classicRefined: barra dupla abaixo
    return pw.Column(
      children: [
        _twoColHeaderRow(
          header: header,
          headerFonts: headerFonts,
          titleColor: textDark,
          subColor: accentColor,
          rightColor: textMuted,
          emailColor: style == OfficialDocLayoutStyle.original
              ? textMuted
              : primaryColor,
        ),
        pw.SizedBox(height: 8),
        pw.Container(height: 1.6, color: primaryColor),
        pw.SizedBox(height: 2),
        pw.Container(height: 0.8, color: accentColor),
      ],
    );
  }

  static pw.Widget _twoColHeaderRow({
    required OfficialHeaderProfile header,
    required OfficialPdfFontBundle headerFonts,
    required PdfColor titleColor,
    required PdfColor subColor,
    required PdfColor rightColor,
    required PdfColor emailColor,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (header.topSubtitle.trim().isNotEmpty)
                pw.Text(
                  header.topSubtitle.toUpperCase(),
                  style: pw.TextStyle(
                    font: headerFonts.bold,
                    fontSize: 9,
                    letterSpacing: 0.4,
                    color: subColor,
                  ),
                ),
              if (header.mainTitle.trim().isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text(
                  header.mainTitle,
                  style: pw.TextStyle(
                    font: headerFonts.bold,
                    fontSize: 16,
                    color: titleColor,
                  ),
                ),
              ],
            ],
          ),
        ),
        _headerRightAddress(
          header: header,
          headerFonts: headerFonts,
          rightColor: rightColor,
          emailColor: emailColor,
        ),
      ],
    );
  }

  static pw.Widget _headerRightAddress({
    required OfficialHeaderProfile header,
    required OfficialPdfFontBundle headerFonts,
    required PdfColor rightColor,
    required PdfColor emailColor,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        if (header.addressLine1.trim().isNotEmpty)
          pw.Text(
            header.addressLine1,
            style: pw.TextStyle(
              font: headerFonts.base,
              fontSize: 8.5,
              color: rightColor,
            ),
          ),
        if (header.addressLine2.trim().isNotEmpty)
          pw.Text(
            header.addressLine2,
            style: pw.TextStyle(
              font: headerFonts.base,
              fontSize: 8.5,
              color: rightColor,
            ),
          ),
        if (header.contactEmail.trim().isNotEmpty)
          pw.Text(
            header.contactEmail,
            style: pw.TextStyle(
              font: headerFonts.bold,
              fontSize: 8.5,
              color: emailColor,
            ),
          ),
      ],
    );
  }

  static pw.Widget _buildMetadataSection({
    required OfficialDocLayoutStyle style,
    required OfficialDocumentRecord doc,
    required OfficialPdfFontBundle metaFonts,
    required PdfColor primaryColor,
    required PdfColor accentColor,
  }) {
    final textDark = PdfColor.fromInt(0xFF0F172A);
    final textMuted = PdfColor.fromInt(0xFF475569);

    if (doc.docType.isMeeting) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromInt(0xFFF8FAFC),
          border: pw.Border(
            left: pw.BorderSide(color: primaryColor, width: 2.5),
            top: const pw.BorderSide(
              color: PdfColor.fromInt(0xFFE2E8F0),
              width: 0.6,
            ),
            right: const pw.BorderSide(
              color: PdfColor.fromInt(0xFFE2E8F0),
              width: 0.6,
            ),
            bottom: const pw.BorderSide(
              color: PdfColor.fromInt(0xFFE2E8F0),
              width: 0.6,
            ),
          ),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              doc.referenceSubject.trim().isNotEmpty
                  ? doc.referenceSubject.trim()
                  : doc.title,
              style: pw.TextStyle(
                font: metaFonts.bold,
                fontSize: 11.5,
                color: primaryColor,
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Wrap(
              spacing: 14,
              runSpacing: 3,
              children: [
                if (doc.meetingDateTime.trim().isNotEmpty)
                  _metaPair(
                    metaFonts,
                    'Data/Horário:',
                    doc.meetingDateTime,
                    textDark,
                    textMuted,
                  ),
                if (doc.meetingLocation.trim().isNotEmpty)
                  _metaPair(
                    metaFonts,
                    'Local:',
                    doc.meetingLocation,
                    textDark,
                    textMuted,
                  ),
                if (doc.participants.trim().isNotEmpty)
                  _metaPair(
                    metaFonts,
                    'Participantes:',
                    doc.participants,
                    textDark,
                    textMuted,
                  ),
                if (doc.openingPrayer.trim().isNotEmpty)
                  _metaPair(
                    metaFonts,
                    'Oração Inicial:',
                    doc.openingPrayer,
                    textDark,
                    textMuted,
                  ),
                if (doc.closingPrayer.trim().isNotEmpty)
                  _metaPair(
                    metaFonts,
                    'Oração Final:',
                    doc.closingPrayer,
                    textDark,
                    textMuted,
                  ),
              ],
            ),
          ],
        ),
      );
    }

    // Metadados de Carta (Apresentação ou Geral)
    if (style == OfficialDocLayoutStyle.editorialModern) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromInt(0xFFF8FAFC),
          border: pw.Border(
            left: pw.BorderSide(color: primaryColor, width: 2.8),
            top: const pw.BorderSide(
              color: PdfColor.fromInt(0xFFE2E8F0),
              width: 0.6,
            ),
            right: const pw.BorderSide(
              color: PdfColor.fromInt(0xFFE2E8F0),
              width: 0.6,
            ),
            bottom: const pw.BorderSide(
              color: PdfColor.fromInt(0xFFE2E8F0),
              width: 0.6,
            ),
          ),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Ref: ${doc.referenceSubject}',
                  style: pw.TextStyle(
                    font: metaFonts.bold,
                    fontSize: 10,
                    color: primaryColor,
                  ),
                ),
                pw.Text(
                  doc.locationDate,
                  style: pw.TextStyle(
                    font: metaFonts.base,
                    fontSize: 8.8,
                    color: textMuted,
                  ),
                ),
              ],
            ),
            if (doc.recipientLine.trim().isNotEmpty) ...[
              pw.SizedBox(height: 4),
              pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(
                      text: 'A/C: ',
                      style: pw.TextStyle(
                        font: metaFonts.bold,
                        fontSize: 9.5,
                        color: textDark,
                      ),
                    ),
                    pw.TextSpan(
                      text: doc.recipientLine,
                      style: pw.TextStyle(
                        font: metaFonts.base,
                        fontSize: 9.5,
                        color: textDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }

    if (style == OfficialDocLayoutStyle.contemporaryPanel) {
      return pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 6,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFF8FAFC),
                border: pw.Border.all(
                  color: PdfColor.fromInt(0xFFE2E8F0),
                  width: 0.6,
                ),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'DESTINATÁRIO',
                    style: pw.TextStyle(
                      font: metaFonts.bold,
                      fontSize: 7.2,
                      color: accentColor,
                      letterSpacing: 0.7,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'A/C: ${doc.recipientLine}',
                    style: pw.TextStyle(
                      font: metaFonts.base,
                      fontSize: 9.2,
                      color: textDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            flex: 4,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFF8FAFC),
                border: pw.Border.all(
                  color: PdfColor.fromInt(0xFFE2E8F0),
                  width: 0.6,
                ),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'ASSUNTO & DATA',
                    style: pw.TextStyle(
                      font: metaFonts.bold,
                      fontSize: 7.2,
                      color: accentColor,
                      letterSpacing: 0.7,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Ref: ${doc.referenceSubject}',
                    style: pw.TextStyle(
                      font: metaFonts.bold,
                      fontSize: 9.2,
                      color: textDark,
                    ),
                  ),
                  pw.Text(
                    doc.locationDate,
                    style: pw.TextStyle(
                      font: metaFonts.base,
                      fontSize: 8.2,
                      color: textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // original / classicRefined / executiveMinimal / diplomaticGold / stationeryWatermark
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        if (doc.locationDate.trim().isNotEmpty)
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              doc.locationDate,
              style: pw.TextStyle(
                font: metaFonts.base,
                fontSize: 9.5,
                color: textMuted,
              ),
            ),
          ),
        pw.SizedBox(height: 5),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: doc.recipientLine.trim().isNotEmpty
                  ? pw.RichText(
                      text: pw.TextSpan(
                        children: [
                          pw.TextSpan(
                            text: 'A/C: ',
                            style: pw.TextStyle(
                              font: metaFonts.bold,
                              fontSize: 9.8,
                              color: style == OfficialDocLayoutStyle.original
                                  ? textDark
                                  : primaryColor,
                            ),
                          ),
                          pw.TextSpan(
                            text: doc.recipientLine,
                            style: pw.TextStyle(
                              font: metaFonts.base,
                              fontSize: 9.8,
                              color: textDark,
                            ),
                          ),
                        ],
                      ),
                    )
                  : pw.SizedBox(),
            ),
            if (doc.referenceSubject.trim().isNotEmpty) ...[
              pw.SizedBox(width: 12),
              pw.Container(
                padding: style == OfficialDocLayoutStyle.classicRefined
                    ? const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3)
                    : pw.EdgeInsets.zero,
                decoration: style == OfficialDocLayoutStyle.classicRefined
                    ? pw.BoxDecoration(
                        color: PdfColor.fromInt(0xFFF1F5F9),
                        border: pw.Border(
                          right: pw.BorderSide(color: accentColor, width: 2.2),
                        ),
                      )
                    : null,
                child: pw.Text(
                  'Ref: ${doc.referenceSubject}',
                  style: pw.TextStyle(
                    font: metaFonts.bold,
                    fontSize: 9.8,
                    color: style == OfficialDocLayoutStyle.diplomaticGold
                        ? PdfColor.fromInt(0xFF92400E)
                        : textDark,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  static pw.Widget _metaPair(
    OfficialPdfFontBundle fonts,
    String label,
    String val,
    PdfColor textDark,
    PdfColor textMuted,
  ) {
    return pw.RichText(
      text: pw.TextSpan(
        children: [
          pw.TextSpan(
            text: '$label ',
            style: pw.TextStyle(
              font: fonts.bold,
              fontSize: 8.8,
              color: textMuted,
            ),
          ),
          pw.TextSpan(
            text: val,
            style: pw.TextStyle(
              font: fonts.base,
              fontSize: 8.8,
              color: textDark,
            ),
          ),
        ],
      ),
    );
  }

  static List<pw.Widget> _buildBodyBlocks({
    required List<OfficialDocBlock> blocks,
    required OfficialFontSpec fonts,
    required OfficialPdfFontBundle bodyFonts,
    required PdfColor primaryColor,
    required PdfColor accentColor,
  }) {
    final textDark = PdfColor.fromInt(0xFF1E293B);
    final align = fonts.justifyBody ? pw.TextAlign.justify : pw.TextAlign.left;
    final out = <pw.Widget>[];

    for (final block in blocks) {
      switch (block.kind) {
        case OfficialBlockKind.heading:
          final hSize = block.headingLevel == 1
              ? fonts.bodyFontSizePt + 3.0
              : (block.headingLevel == 2
                    ? fonts.bodyFontSizePt + 1.5
                    : fonts.bodyFontSizePt + 0.5);
          out.add(
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 6, bottom: 3),
              child: _richRunsWidget(
                block.runs,
                bodyFonts,
                fontSize: hSize,
                forceBold: true,
                color: primaryColor,
                textAlign: pw.TextAlign.left,
              ),
            ),
          );
        case OfficialBlockKind.bulletItem:
          out.add(
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 10, bottom: 4),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '•  ',
                    style: pw.TextStyle(
                      font: bodyFonts.bold,
                      fontSize: fonts.bodyFontSizePt,
                      color: accentColor,
                    ),
                  ),
                  pw.Expanded(
                    child: _richRunsWidget(
                      block.runs,
                      bodyFonts,
                      fontSize: fonts.bodyFontSizePt,
                      color: textDark,
                      textAlign: pw.TextAlign.left,
                    ),
                  ),
                ],
              ),
            ),
          );
        case OfficialBlockKind.numberedItem:
          out.add(
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 10, bottom: 4),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '${block.numberIndex ?? 1}. ',
                    style: pw.TextStyle(
                      font: bodyFonts.bold,
                      fontSize: fonts.bodyFontSizePt,
                      color: primaryColor,
                    ),
                  ),
                  pw.Expanded(
                    child: _richRunsWidget(
                      block.runs,
                      bodyFonts,
                      fontSize: fonts.bodyFontSizePt,
                      color: textDark,
                      textAlign: pw.TextAlign.left,
                    ),
                  ),
                ],
              ),
            ),
          );
        case OfficialBlockKind.quote:
          out.add(
            pw.Container(
              margin: const pw.EdgeInsets.only(left: 6, bottom: 6, top: 2),
              padding: const pw.EdgeInsets.only(left: 8, top: 2, bottom: 2),
              decoration: pw.BoxDecoration(
                border: pw.Border(
                  left: pw.BorderSide(color: accentColor, width: 2),
                ),
              ),
              child: _richRunsWidget(
                block.runs,
                bodyFonts,
                fontSize: fonts.bodyFontSizePt - 0.3,
                color: PdfColor.fromInt(0xFF475569),
                textAlign: pw.TextAlign.left,
              ),
            ),
          );
        case OfficialBlockKind.paragraph:
          out.add(
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 7.5),
              child: _richRunsWidget(
                block.runs,
                bodyFonts,
                fontSize: fonts.bodyFontSizePt,
                color: textDark,
                textAlign: align,
              ),
            ),
          );
      }
    }
    return out;
  }

  static pw.Widget _richRunsWidget(
    List<OfficialTextRun> runs,
    OfficialPdfFontBundle bundle, {
    required double fontSize,
    required PdfColor color,
    required pw.TextAlign textAlign,
    bool forceBold = false,
  }) {
    return pw.RichText(
      textAlign: textAlign,
      text: pw.TextSpan(
        children: [
          for (final r in runs)
            pw.TextSpan(
              text: r.text,
              style: pw.TextStyle(
                font: bundle.pick(
                  isBold: forceBold || r.bold,
                  isItalic: r.italic,
                ),
                fontSize: fontSize,
                lineSpacing: 3.2,
                color: color,
                decoration: r.underline
                    ? pw.TextDecoration.underline
                    : (r.strikethrough
                          ? pw.TextDecoration.lineThrough
                          : pw.TextDecoration.none),
              ),
            ),
        ],
      ),
    );
  }

  static pw.Widget _buildSignatureSection({
    required OfficialDocLayoutStyle style,
    required String groupTitle,
    required List<SignerSlot> signers,
    required OfficialPdfFontBundle metaFonts,
    required OfficialPdfFontBundle defaultSigFonts,
    required Map<String, OfficialPdfFontBundle> perSignerFonts,
    required PdfColor primaryColor,
    required PdfColor accentColor,
  }) {
    final textDark = PdfColor.fromInt(0xFF0F172A);
    final textMuted = PdfColor.fromInt(0xFF64748B);
    final boxed = style == OfficialDocLayoutStyle.editorialModern;

    final rows = <List<SignerSlot>>[];
    for (var i = 0; i < signers.length; i += 3) {
      rows.add(
        signers.sublist(i, (i + 3 > signers.length) ? signers.length : i + 3),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        if (groupTitle.trim().isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 10),
            child: pw.Text(
              style == OfficialDocLayoutStyle.editorialModern ||
                      style == OfficialDocLayoutStyle.diplomaticGold
                  ? groupTitle.toUpperCase()
                  : groupTitle,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                font: metaFonts.bold,
                fontSize: 9.6,
                letterSpacing: style == OfficialDocLayoutStyle.editorialModern
                    ? 0.9
                    : 0.2,
                color: style == OfficialDocLayoutStyle.original
                    ? textDark
                    : primaryColor,
              ),
            ),
          ),
        for (final rowSlots in rows) ...[
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              for (var idx = 0; idx < rowSlots.length; idx++) ...[
                if (idx > 0) pw.SizedBox(width: 18),
                pw.Expanded(
                  child: _buildSingleSignerCell(
                    slot: rowSlots[idx],
                    metaFonts: metaFonts,
                    sigFonts:
                        (rowSlots[idx].signatureFontIdOverride != null &&
                            perSignerFonts.containsKey(
                              rowSlots[idx].signatureFontIdOverride!,
                            ))
                        ? perSignerFonts[rowSlots[idx]
                              .signatureFontIdOverride!]!
                        : defaultSigFonts,
                    textDark: textDark,
                    textMuted: textMuted,
                    lineColor: style == OfficialDocLayoutStyle.diplomaticGold
                        ? PdfColor.fromInt(0xFFB45309)
                        : PdfColor.fromInt(0xFF94A3B8),
                    sigColor: PdfColor.fromInt(0xFF1E3A5F),
                    roleColor: boxed ? accentColor : textMuted,
                    boxed: boxed,
                  ),
                ),
              ],
            ],
          ),
          pw.SizedBox(height: 12),
        ],
      ],
    );
  }

  static pw.Widget _buildSingleSignerCell({
    required SignerSlot slot,
    required OfficialPdfFontBundle metaFonts,
    required OfficialPdfFontBundle sigFonts,
    required PdfColor textDark,
    required PdfColor textMuted,
    required PdfColor lineColor,
    required PdfColor sigColor,
    required PdfColor roleColor,
    required bool boxed,
  }) {
    pw.Widget signatureVisual;
    final b64 = slot.signaturePngBase64Override;
    if (b64 != null && b64.trim().isNotEmpty) {
      try {
        final imgBytes = base64Decode(b64.trim());
        signatureVisual = pw.SizedBox(
          height: 30,
          child: pw.Image(pw.MemoryImage(imgBytes), fit: pw.BoxFit.contain),
        );
      } catch (_) {
        signatureVisual = pw.Text(
          slot.name,
          style: pw.TextStyle(
            font: sigFonts.base,
            fontSize: 20,
            color: sigColor,
          ),
        );
      }
    } else {
      signatureVisual = pw.Text(
        slot.name,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(font: sigFonts.base, fontSize: 20, color: sigColor),
      );
    }

    final inner = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Container(
          height: 32,
          alignment: pw.Alignment.bottomCenter,
          child: signatureVisual,
        ),
        pw.SizedBox(height: 2),
        pw.Container(height: 0.75, color: lineColor),
        pw.SizedBox(height: 3),
        pw.Text(
          slot.name,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            font: metaFonts.bold,
            fontSize: 8.8,
            color: textDark,
          ),
        ),
        if (slot.role.trim().isNotEmpty)
          pw.Text(
            slot.role,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              font: metaFonts.base,
              fontSize: 7.8,
              color: roleColor,
            ),
          ),
      ],
    );

    if (!boxed) return inner;
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFF8FAFC),
        border: pw.Border.all(color: PdfColor.fromInt(0xFFE2E8F0), width: 0.6),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
      ),
      child: inner,
    );
  }

  static pw.Widget _buildPageFooter({
    required OfficialDocLayoutStyle style,
    required OfficialHeaderProfile? header,
    required OfficialPdfFontBundle metaFonts,
    required pw.Context context,
  }) {
    final showPages =
        (header?.showPageNumbers ?? false) ||
        style != OfficialDocLayoutStyle.original;
    final note = header?.footerNote.trim() ?? '';
    if (!showPages && note.isEmpty) return pw.SizedBox();

    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 6),
      padding: const pw.EdgeInsets.only(top: 5),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColor.fromInt(0xFFE2E8F0), width: 0.5),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            note.isNotEmpty ? note : (header?.topSubtitle ?? ''),
            style: pw.TextStyle(
              font: metaFonts.base,
              fontSize: 7.2,
              color: PdfColor.fromInt(0xFF94A3B8),
            ),
          ),
          if (showPages)
            pw.Text(
              'Página ${context.pageNumber} de ${context.pagesCount}',
              style: pw.TextStyle(
                font: metaFonts.base,
                fontSize: 7.2,
                color: PdfColor.fromInt(0xFF94A3B8),
              ),
            ),
        ],
      ),
    );
  }
}
