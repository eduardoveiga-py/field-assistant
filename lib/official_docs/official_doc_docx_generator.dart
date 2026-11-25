import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'official_doc_fonts.dart';
import 'official_doc_models.dart';
import 'official_markup_parser.dart';

/// Gerador OOXML (.docx) em Dart puro (100% offline e PWA-safe via `package:archive`)
/// para edição posterior no Microsoft Word, Google Docs e LibreOffice.
class OfficialDocDocxGenerator {
  OfficialDocDocxGenerator._();

  static String _xmlEsc(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static String _cleanHex(String hex, String fallback) {
    final c = hex.trim().replaceFirst('#', '').toUpperCase();
    return RegExp(r'^[0-9A-F]{6}$').hasMatch(c) ? c : fallback;
  }

  static String _runXml({
    required String text,
    required String fontName,
    required int sizeHalfPt,
    bool bold = false,
    bool italic = false,
    bool underline = false,
    bool strike = false,
    String colorHex = '1E293B',
  }) {
    final safeFont = _xmlEsc(fontName);
    final buf = StringBuffer()
      ..write('<w:r><w:rPr>')
      ..write(
        '<w:rFonts w:ascii="$safeFont" w:hAnsi="$safeFont" w:cs="$safeFont"/>',
      )
      ..write('<w:sz w:val="$sizeHalfPt"/><w:szCs w:val="$sizeHalfPt"/>')
      ..write('<w:color w:val="$colorHex"/>');
    if (bold) buf.write('<w:b/><w:bCs/>');
    if (italic) buf.write('<w:i/><w:iCs/>');
    if (underline) buf.write('<w:u w:val="single"/>');
    if (strike) buf.write('<w:strike/>');
    buf
      ..write('</w:rPr><w:t xml:space="preserve">')
      ..write(_xmlEsc(text))
      ..write('</w:t></w:r>');
    return buf.toString();
  }

  static String _inlineImageXml({
    required String rId,
    required int docPrId,
    required String imageName,
  }) {
    // Largura fixa elegante ~1250000 EMU (~3.5 cm) x Altura ~420000 EMU (~1.16 cm)
    return '<w:r><w:drawing><wp:inline distT="0" distB="0" distL="0" distR="0" '
        'xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing">'
        '<wp:extent cx="1250000" cy="420000"/>'
        '<wp:docPr id="$docPrId" name="${_xmlEsc(imageName)}"/>'
        '<a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">'
        '<a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">'
        '<pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">'
        '<pic:nvPicPr><pic:cNvPr id="$docPrId" name="${_xmlEsc(imageName)}"/><pic:cNvPicPr/></pic:nvPicPr>'
        '<pic:blipFill><a:blip r:embed="$rId" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"/>'
        '<a:stretch><a:fillRect/></a:stretch></pic:blipFill>'
        '<pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="1250000" cy="420000"/></a:xfrm>'
        '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr>'
        '</pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing></w:r>';
  }

  static Uint8List generateDocxBytes({
    required OfficialDocumentRecord doc,
    OfficialHeaderProfile? header,
    required String signatureGroupTitle,
    required List<SignerSlot> signers,
  }) {
    final style = OfficialDocLayoutStyle.fromId(doc.layoutStyleId);
    final fonts = doc.fontSpec;
    final headerFont = OfficialDocFonts.findById(fonts.headerFontId)
        .docxFontName;
    final metaFont = OfficialDocFonts.findById(fonts.metaFontId).docxFontName;
    final bodyFont = OfficialDocFonts.findById(fonts.bodyFontId).docxFontName;
    final defaultSigFont = OfficialDocFonts.findById(fonts.signatureFontId)
        .docxFontName;
    final bodyHalfPt = (fonts.bodyFontSizePt * 2).round().clamp(16, 28);

    final primaryHex = _cleanHex(
      header?.primaryColorHex ?? '#1D4ED8',
      '1D4ED8',
    );
    final accentHex = _cleanHex(header?.accentColorHex ?? '#0F766E', '0F766E');

    final showHeader =
        doc.includeHeader && header != null && !header.isEmptyHeader;
    final showSignature =
        doc.includeSignature &&
        (signatureGroupTitle.trim().isNotEmpty || signers.isNotEmpty);

    // 1. Header XML
    final headerXml = showHeader
        ? _buildHeaderXml(header, headerFont, primaryHex, accentHex, style)
        : '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
              '<w:hdr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
              '<w:p/></w:hdr>';

    // 2. Footer XML
    final footerNote = header?.footerNote.trim() ?? '';
    final footerText = footerNote.isNotEmpty
        ? footerNote
        : (showHeader && header.topSubtitle.trim().isNotEmpty
              ? '${header.topSubtitle.trim()} · ${header.mainTitle.trim()}'
              : '');
    final footerXml =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:ftr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:p><w:pPr><w:pBdr><w:top w:val="single" w:sz="4" w:space="4" w:color="E2E8F0"/></w:pBdr><w:jc w:val="center"/></w:pPr>'
        '${footerText.isNotEmpty ? _runXml(text: footerText, fontName: metaFont, sizeHalfPt: 14, colorHex: "94A3B8") : ""}'
        '</w:p></w:ftr>';

    // 3. Body Metadata + Content + Signature Table (tracking media rels for drawn PNGs)
    final bodyBuf = StringBuffer();
    bodyBuf.write(
      _buildMetadataXml(
        doc: doc,
        metaFont: metaFont,
        primaryHex: primaryHex,
        style: style,
      ),
    );

    final blocks = OfficialMarkupParser.parseBlocks(doc.bodyMarkup);
    for (var i = 0; i < blocks.length; i++) {
      final b = blocks[i];
      final isFirst = i == 0;
      final isLast = i == blocks.length - 1;
      final jc =
          (fonts.justifyBody &&
              b.kind == OfficialBlockKind.paragraph &&
              !isFirst &&
              !isLast)
          ? 'both'
          : 'left';

      switch (b.kind) {
        case OfficialBlockKind.heading:
          final hSize = b.headingLevel == 1
              ? bodyHalfPt + 6
              : (b.headingLevel == 2 ? bodyHalfPt + 3 : bodyHalfPt + 1);
          final runsXml = b.runs
              .map(
                (r) => _runXml(
                  text: r.text,
                  fontName: bodyFont,
                  sizeHalfPt: hSize,
                  bold: true,
                  italic: r.italic,
                  underline: r.underline,
                  colorHex: primaryHex,
                ),
              )
              .join();
          bodyBuf.write(
            '<w:p><w:pPr><w:spacing w:before="140" w:after="60"/></w:pPr>$runsXml</w:p>',
          );
        case OfficialBlockKind.bulletItem:
          final runsXml = b.runs
              .map(
                (r) => _runXml(
                  text: r.text,
                  fontName: bodyFont,
                  sizeHalfPt: bodyHalfPt,
                  bold: r.bold,
                  italic: r.italic,
                  underline: r.underline,
                  strike: r.strikethrough,
                ),
              )
              .join();
          bodyBuf.write(
            '<w:p><w:pPr><w:ind w:left="360"/><w:spacing w:before="0" w:after="80" w:line="276" w:lineRule="auto"/></w:pPr>'
            '${_runXml(text: "• ", fontName: bodyFont, sizeHalfPt: bodyHalfPt, bold: true, colorHex: accentHex)}'
            '$runsXml</w:p>',
          );
        case OfficialBlockKind.numberedItem:
          final runsXml = b.runs
              .map(
                (r) => _runXml(
                  text: r.text,
                  fontName: bodyFont,
                  sizeHalfPt: bodyHalfPt,
                  bold: r.bold,
                  italic: r.italic,
                  underline: r.underline,
                  strike: r.strikethrough,
                ),
              )
              .join();
          bodyBuf.write(
            '<w:p><w:pPr><w:ind w:left="360"/><w:spacing w:before="0" w:after="80" w:line="276" w:lineRule="auto"/></w:pPr>'
            '${_runXml(text: "${b.numberIndex ?? 1}. ", fontName: bodyFont, sizeHalfPt: bodyHalfPt, bold: true, colorHex: primaryHex)}'
            '$runsXml</w:p>',
          );
        case OfficialBlockKind.quote:
          final runsXml = b.runs
              .map(
                (r) => _runXml(
                  text: r.text,
                  fontName: bodyFont,
                  sizeHalfPt: bodyHalfPt - 1,
                  bold: r.bold,
                  italic: r.italic,
                  underline: r.underline,
                  colorHex: '475569',
                ),
              )
              .join();
          bodyBuf.write(
            '<w:p><w:pPr><w:pBdr><w:left w:val="single" w:sz="12" w:space="8" w:color="$accentHex"/></w:pBdr><w:ind w:left="240"/><w:spacing w:before="40" w:after="100"/></w:pPr>$runsXml</w:p>',
          );
        case OfficialBlockKind.paragraph:
          final runsXml = b.runs
              .map(
                (r) => _runXml(
                  text: r.text,
                  fontName: bodyFont,
                  sizeHalfPt: bodyHalfPt,
                  bold: r.bold,
                  italic: r.italic,
                  underline: r.underline,
                  strike: r.strikethrough,
                ),
              )
              .join();
          bodyBuf.write(
            '<w:p><w:pPr><w:jc w:val="$jc"/><w:spacing w:before="0" w:after="115" w:line="276" w:lineRule="auto"/></w:pPr>$runsXml</w:p>',
          );
      }
    }

    final mediaEntries = <String, Uint8List>{};
    final mediaRels = <String>[];
    var nextRelNum = 3; // rId1=header, rId2=footer

    if (showSignature) {
      if (signatureGroupTitle.trim().isNotEmpty) {
        bodyBuf.write(
          '<w:p><w:pPr><w:jc w:val="center"/><w:spacing w:before="200" w:after="80"/></w:pPr>'
          '${_runXml(text: signatureGroupTitle.trim(), fontName: metaFont, sizeHalfPt: 19, bold: true, colorHex: primaryHex)}'
          '</w:p>',
        );
      }
      if (signers.isNotEmpty) {
        for (var i = 0; i < signers.length; i += 3) {
          final chunk = signers.sublist(
            i,
            i + 3 > signers.length ? signers.length : i + 3,
          );
          final colWidth = 9638 ~/ chunk.length;
          bodyBuf.write(
            '<w:tbl><w:tblPr><w:tblW w:w="9638" w:type="dxa"/>'
            '<w:tblBorders>'
            '<w:top w:val="none" w:sz="0" w:space="0" w:color="auto"/>'
            '<w:bottom w:val="none" w:sz="0" w:space="0" w:color="auto"/>'
            '<w:left w:val="none" w:sz="0" w:space="0" w:color="auto"/>'
            '<w:right w:val="none" w:sz="0" w:space="0" w:color="auto"/>'
            '<w:insideH w:val="none" w:sz="0" w:space="0" w:color="auto"/>'
            '<w:insideV w:val="none" w:sz="0" w:space="0" w:color="auto"/>'
            '</w:tblBorders>'
            '<w:tblCellMar><w:left w:w="120" w:type="dxa"/><w:right w:w="120" w:type="dxa"/></w:tblCellMar>'
            '</w:tblPr><w:tblGrid>'
            '${List.filled(chunk.length, '<w:gridCol w:w="$colWidth"/>').join()}'
            '</w:tblGrid><w:tr>',
          );

          for (var c = 0; c < chunk.length; c++) {
            final slot = chunk[c];
            final sFont = slot.signatureFontIdOverride != null
                ? OfficialDocFonts.findById(slot.signatureFontIdOverride)
                      .docxFontName
                : defaultSigFont;

            String sigTopXml;
            final b64 = slot.signaturePngBase64Override;
            Uint8List? pngBytes;
            if (b64 != null && b64.trim().isNotEmpty) {
              try {
                pngBytes = base64Decode(b64.trim());
              } catch (_) {
                pngBytes = null;
              }
            }

            if (pngBytes != null && pngBytes.isNotEmpty) {
              final relId = 'rId$nextRelNum';
              final imgName = 'sig_$nextRelNum.png';
              nextRelNum++;
              mediaEntries['word/media/$imgName'] = pngBytes;
              mediaRels.add(
                '<Relationship Id="$relId" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/$imgName"/>',
              );
              sigTopXml = _inlineImageXml(
                rId: relId,
                docPrId: nextRelNum,
                imageName: imgName,
              );
            } else {
              sigTopXml = _runXml(
                text: slot.name,
                fontName: sFont,
                sizeHalfPt: 30,
                colorHex: primaryHex,
              );
            }

            bodyBuf.write(
              '<w:tc><w:tcPr><w:tcW w:w="$colWidth" w:type="dxa"/></w:tcPr>'
              '<w:p><w:pPr><w:jc w:val="center"/><w:spacing w:before="100" w:after="20"/></w:pPr>$sigTopXml</w:p>'
              '<w:p><w:pPr><w:pBdr><w:top w:val="single" w:sz="6" w:space="4" w:color="94A3B8"/></w:pBdr><w:jc w:val="center"/><w:spacing w:before="0" w:after="15"/></w:pPr>'
              '${_runXml(text: slot.name, fontName: metaFont, sizeHalfPt: 18, bold: true, colorHex: "0F172A")}</w:p>'
              '<w:p><w:pPr><w:jc w:val="center"/><w:spacing w:before="0" w:after="40"/></w:pPr>'
              '${slot.role.trim().isNotEmpty ? _runXml(text: slot.role, fontName: metaFont, sizeHalfPt: 16, colorHex: "64748B") : ""}</w:p>'
              '</w:tc>',
            );
          }

          bodyBuf.write('</w:tr></w:tbl>');
        }
      }
    }

    final documentXml =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
        '<w:body>'
        '${bodyBuf.toString()}'
        '<w:sectPr>'
        '<w:headerReference w:type="default" r:id="rId1"/>'
        '<w:footerReference w:type="default" r:id="rId2"/>'
        '<w:pgSz w:w="11906" w:h="16838"/>'
        '<w:pgMar w:top="${showHeader ? 1600 : 1134}" w:right="1134" w:bottom="900" w:left="1134" w:header="450" w:footer="400" w:gutter="0"/>'
        '</w:sectPr></w:body></w:document>';

    final pngDefault = mediaEntries.isNotEmpty
        ? '<Default Extension="png" ContentType="image/png"/>'
        : '';
    final contentTypes =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '$pngDefault'
        '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
        '<Override PartName="/word/header1.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml"/>'
        '<Override PartName="/word/footer1.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.footer+xml"/>'
        '</Types>';

    const rootRels =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
        '</Relationships>';

    final docRels =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/header" Target="header1.xml"/>'
        '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer" Target="footer1.xml"/>'
        '${mediaRels.join()}'
        '</Relationships>';

    final archive = Archive();
    void addText(String name, String xmlStr) {
      final b = utf8.encode(xmlStr);
      archive.addFile(ArchiveFile(name, b.length, b));
    }

    addText('[Content_Types].xml', contentTypes);
    addText('_rels/.rels', rootRels);
    addText('word/_rels/document.xml.rels', docRels);
    addText('word/header1.xml', headerXml);
    addText('word/footer1.xml', footerXml);
    addText('word/document.xml', documentXml);

    for (final entry in mediaEntries.entries) {
      archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
    }

    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  static String _buildHeaderXml(
    OfficialHeaderProfile header,
    String headerFont,
    String primaryHex,
    String accentHex,
    OfficialDocLayoutStyle style,
  ) {
    final centered = style == OfficialDocLayoutStyle.diplomaticGold;
    if (centered) {
      final contact = [
        if (header.addressLine1.trim().isNotEmpty) header.addressLine1.trim(),
        if (header.contactEmail.trim().isNotEmpty) header.contactEmail.trim(),
      ].join(' • ');
      return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          '<w:hdr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
          '<w:p><w:pPr><w:jc w:val="center"/><w:spacing w:before="0" w:after="20"/></w:pPr>'
          '${_runXml(text: header.topSubtitle.toUpperCase(), fontName: headerFont, sizeHalfPt: 18, bold: true, colorHex: "B45309")}</w:p>'
          '<w:p><w:pPr><w:jc w:val="center"/><w:spacing w:before="0" w:after="20"/></w:pPr>'
          '${_runXml(text: header.mainTitle, fontName: headerFont, sizeHalfPt: 30, bold: true, colorHex: "0F172A")}</w:p>'
          '<w:p><w:pPr><w:pBdr><w:bottom w:val="double" w:sz="6" w:space="6" w:color="0F172A"/></w:pBdr><w:jc w:val="center"/><w:spacing w:before="0" w:after="80"/></w:pPr>'
          '${_runXml(text: contact, fontName: headerFont, sizeHalfPt: 16, colorHex: "64748B")}</w:p>'
          '</w:hdr>';
    }

    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:hdr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:tbl><w:tblPr><w:tblW w:w="9638" w:type="dxa"/>'
        '<w:tblBorders>'
        '<w:top w:val="none" w:sz="0" w:space="0" w:color="auto"/>'
        '<w:left w:val="none" w:sz="0" w:space="0" w:color="auto"/>'
        '<w:right w:val="none" w:sz="0" w:space="0" w:color="auto"/>'
        '<w:insideH w:val="none" w:sz="0" w:space="0" w:color="auto"/>'
        '<w:insideV w:val="none" w:sz="0" w:space="0" w:color="auto"/>'
        '<w:bottom w:val="double" w:sz="8" w:space="6" w:color="$primaryHex"/>'
        '</w:tblBorders></w:tblPr>'
        '<w:tblGrid><w:gridCol w:w="5400"/><w:gridCol w:w="4238"/></w:tblGrid><w:tr>'
        '<w:tc><w:tcPr><w:tcW w:w="5400" w:type="dxa"/><w:tcBorders><w:bottom w:val="double" w:sz="8" w:space="6" w:color="$primaryHex"/></w:tcBorders></w:tcPr>'
        '<w:p><w:pPr><w:spacing w:before="0" w:after="20"/></w:pPr>${_runXml(text: header.topSubtitle.toUpperCase(), fontName: headerFont, sizeHalfPt: 18, bold: true, colorHex: accentHex)}</w:p>'
        '<w:p><w:pPr><w:spacing w:before="0" w:after="80"/></w:pPr>${_runXml(text: header.mainTitle, fontName: headerFont, sizeHalfPt: 30, bold: true, colorHex: "0F172A")}</w:p>'
        '</w:tc>'
        '<w:tc><w:tcPr><w:tcW w:w="4238" w:type="dxa"/><w:tcBorders><w:bottom w:val="double" w:sz="8" w:space="6" w:color="$primaryHex"/></w:tcBorders></w:tcPr>'
        '<w:p><w:pPr><w:jc w:val="right"/><w:spacing w:before="0" w:after="10"/></w:pPr>${_runXml(text: header.addressLine1, fontName: headerFont, sizeHalfPt: 16, colorHex: "475569")}</w:p>'
        '<w:p><w:pPr><w:jc w:val="right"/><w:spacing w:before="0" w:after="10"/></w:pPr>${_runXml(text: header.addressLine2, fontName: headerFont, sizeHalfPt: 16, colorHex: "475569")}</w:p>'
        '<w:p><w:pPr><w:jc w:val="right"/><w:spacing w:before="0" w:after="80"/></w:pPr>${_runXml(text: header.contactEmail, fontName: headerFont, sizeHalfPt: 16, bold: true, colorHex: primaryHex)}</w:p>'
        '</w:tc></w:tr></w:tbl></w:hdr>';
  }

  static String _buildMetadataXml({
    required OfficialDocumentRecord doc,
    required String metaFont,
    required String primaryHex,
    required OfficialDocLayoutStyle style,
  }) {
    if (doc.docType.isMeeting) {
      final infoLines = <String>[
        if (doc.meetingDateTime.trim().isNotEmpty)
          'Data/Horário: ${doc.meetingDateTime.trim()}',
        if (doc.meetingLocation.trim().isNotEmpty)
          'Local: ${doc.meetingLocation.trim()}',
        if (doc.participants.trim().isNotEmpty)
          'Participantes: ${doc.participants.trim()}',
        if (doc.openingPrayer.trim().isNotEmpty)
          'Oração Inicial: ${doc.openingPrayer.trim()}',
        if (doc.closingPrayer.trim().isNotEmpty)
          'Oração Final: ${doc.closingPrayer.trim()}',
      ];
      return '<w:tbl><w:tblPr><w:tblW w:w="9638" w:type="dxa"/><w:shd w:val="clear" w:color="auto" w:fill="F8FAFC"/>'
          '<w:tblBorders><w:top w:val="single" w:sz="4" w:space="0" w:color="E2E8F0"/>'
          '<w:bottom w:val="single" w:sz="4" w:space="0" w:color="E2E8F0"/>'
          '<w:right w:val="single" w:sz="4" w:space="0" w:color="E2E8F0"/>'
          '<w:left w:val="single" w:sz="18" w:space="0" w:color="$primaryHex"/></w:tblBorders>'
          '<w:tblCellMar><w:top w:w="100" w:type="dxa"/><w:bottom w:w="100" w:type="dxa"/><w:left w:w="140" w:type="dxa"/><w:right w:w="140" w:type="dxa"/></w:tblCellMar>'
          '</w:tblPr><w:tblGrid><w:gridCol w:w="9638"/></w:tblGrid><w:tr><w:tc>'
          '<w:p><w:pPr><w:spacing w:before="0" w:after="40"/></w:pPr>${_runXml(text: doc.referenceSubject.trim().isNotEmpty ? doc.referenceSubject : doc.title, fontName: metaFont, sizeHalfPt: 22, bold: true, colorHex: primaryHex)}</w:p>'
          '<w:p><w:pPr><w:spacing w:before="0" w:after="0"/></w:pPr>${_runXml(text: infoLines.join(" · "), fontName: metaFont, sizeHalfPt: 18, colorHex: "475569")}</w:p>'
          '</w:tc></w:tr></w:tbl><w:p><w:pPr><w:spacing w:before="0" w:after="100"/></w:pPr></w:p>';
    }

    if (style == OfficialDocLayoutStyle.editorialModern) {
      return '<w:tbl><w:tblPr><w:tblW w:w="9638" w:type="dxa"/><w:shd w:val="clear" w:color="auto" w:fill="F8FAFC"/>'
          '<w:tblBorders><w:top w:val="single" w:sz="4" w:space="0" w:color="E2E8F0"/>'
          '<w:bottom w:val="single" w:sz="4" w:space="0" w:color="E2E8F0"/>'
          '<w:right w:val="single" w:sz="4" w:space="0" w:color="E2E8F0"/>'
          '<w:left w:val="single" w:sz="18" w:space="0" w:color="$primaryHex"/>'
          '<w:insideH w:val="none" w:sz="0" w:space="0" w:color="auto"/>'
          '<w:insideV w:val="none" w:sz="0" w:space="0" w:color="auto"/></w:tblBorders>'
          '<w:tblCellMar><w:top w:w="100" w:type="dxa"/><w:bottom w:w="100" w:type="dxa"/><w:left w:w="160" w:type="dxa"/><w:right w:w="160" w:type="dxa"/></w:tblCellMar>'
          '</w:tblPr><w:tblGrid><w:gridCol w:w="4819"/><w:gridCol w:w="4819"/></w:tblGrid>'
          '<w:tr>'
          '<w:tc><w:p><w:pPr><w:spacing w:before="0" w:after="40"/></w:pPr>${_runXml(text: "Ref: ${doc.referenceSubject}", fontName: metaFont, sizeHalfPt: 20, bold: true, colorHex: primaryHex)}</w:p></w:tc>'
          '<w:tc><w:p><w:pPr><w:jc w:val="right"/><w:spacing w:before="0" w:after="40"/></w:pPr>${_runXml(text: doc.locationDate, fontName: metaFont, sizeHalfPt: 18, colorHex: "475569")}</w:p></w:tc>'
          '</w:tr>'
          '<w:tr><w:tc><w:tcPr><w:gridSpan w:val="2"/></w:tcPr>'
          '<w:p><w:pPr><w:spacing w:before="0" w:after="0"/></w:pPr>${_runXml(text: "A/C: ", fontName: metaFont, sizeHalfPt: 19, bold: true, colorHex: primaryHex)}${_runXml(text: doc.recipientLine, fontName: metaFont, sizeHalfPt: 19, colorHex: "0F172A")}</w:p>'
          '</w:tc></w:tr></w:tbl><w:p><w:pPr><w:spacing w:before="0" w:after="100"/></w:pPr></w:p>';
    }

    final buf = StringBuffer();
    if (doc.locationDate.trim().isNotEmpty) {
      buf.write(
        '<w:p><w:pPr><w:jc w:val="right"/><w:spacing w:before="80" w:after="50"/></w:pPr>'
        '${_runXml(text: doc.locationDate, fontName: metaFont, sizeHalfPt: 18, colorHex: "475569")}</w:p>',
      );
    }
    if (doc.referenceSubject.trim().isNotEmpty) {
      buf.write(
        '<w:p><w:pPr><w:jc w:val="right"/><w:spacing w:before="0" w:after="70"/></w:pPr>'
        '${_runXml(text: "Ref: ${doc.referenceSubject}", fontName: metaFont, sizeHalfPt: 20, bold: true, colorHex: primaryHex)}</w:p>',
      );
    }
    if (doc.recipientLine.trim().isNotEmpty) {
      buf.write(
        '<w:p><w:pPr><w:spacing w:before="0" w:after="140"/></w:pPr>'
        '${_runXml(text: "A/C: ", fontName: metaFont, sizeHalfPt: 19, bold: true, colorHex: primaryHex)}'
        '${_runXml(text: doc.recipientLine, fontName: metaFont, sizeHalfPt: 19, colorHex: "0F172A")}</w:p>',
      );
    }
    return buf.toString();
  }
}
