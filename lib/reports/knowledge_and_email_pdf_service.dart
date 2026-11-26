import 'dart:convert';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/app_logger.dart';
import '../database/app_database.dart';
import '../inbox/email_html_sanitizer.dart';
import '../inbox/jw_email_service.dart';
import '../official_docs/official_doc_fonts.dart';
import '../official_docs/official_doc_models.dart';
import '../reports/binary_file_saver.dart';

/// Gerador 100% offline e multiplataforma (Web PWA + iOS + Android + Windows) de PDF
/// para E-mails, Capturas do Inbox e todas as abas da Base de Conhecimento.
class KnowledgeAndEmailPdfService {
  KnowledgeAndEmailPdfService._();

  static String sanitizeFileName(String raw, {String fallback = 'documento'}) {
    final clean = raw
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|\r\n]+'), '_')
        .replaceAll(RegExp(r'\s+'), '_');
    return clean.isEmpty ? fallback : clean;
  }

  static Future<pw.ThemeData> _buildUnicodePdfTheme() async {
    final sans = await OfficialDocFonts.loadPdfBundle('pt_sans');
    return pw.ThemeData.withFont(
      base: sans.base,
      bold: sans.bold,
      italic: sans.italic,
      boldItalic: sans.boldItalic,
    );
  }

  static String _cleanBodyText(String raw) {
    if (raw.trim().isEmpty) return '';
    final plain = EmailHtmlSanitizer.extractPlainText(raw, cleanMarkdown: true);
    // Remove emojis fora do plano latino para evitar glifos ausentes nas fontes TTF embutidas.
    return plain
        .replaceAll(
          RegExp(
            r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE0E}\u{FE0F}]',
            unicode: true,
          ),
          '',
        )
        .replaceAll(RegExp(r' {2,}'), ' ')
        .trim();
  }

  static List<String> _splitParagraphs(String cleanText) {
    return cleanText
        .split(RegExp(r'\n{2,}'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
  }

  static Future<Uint8List> buildEmailPdfBytes(JwEmailMessage msg) async {
    final theme = await _buildUnicodePdfTheme();
    final pdf = pw.Document(
      title: msg.subject.trim().isEmpty ? '(Sem assunto)' : msg.subject,
      author: EmailHtmlSanitizer.displaySenderName(msg.from),
      theme: theme,
    );

    final rawBody = (msg.bodyHtml != null && msg.bodyHtml!.trim().isNotEmpty)
        ? msg.bodyHtml!
        : msg.bodyText;
    final cleanBody = _cleanBodyText(rawBody);
    final paragraphs = _splitParagraphs(cleanBody);
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm').format(msg.date);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.centerRight,
          padding: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            'Field Assistant • Página ${ctx.pageNumber} de ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600),
          ),
        ),
        build: (ctx) => [
          pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 10),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.blue700, width: 1.5),
              ),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  msg.isHubCommunication
                      ? 'CORRESPONDÊNCIA HUB JW / E-MAIL'
                      : 'JW MAIL — CORRESPONDÊNCIA',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800,
                    letterSpacing: 1.0,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  msg.subject.trim().isEmpty ? '(Sem assunto)' : msg.subject,
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey900,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _metaLine('De', msg.from),
                _metaLine('Para', msg.to),
                if (msg.cc.isNotEmpty) _metaLine('CC', msg.cc.join(', ')),
                _metaLine('Data', dateFmt),
                if (msg.folderName != null && msg.folderName!.isNotEmpty)
                  _metaLine('Pasta', msg.folderName!),
                if (msg.tags.isNotEmpty)
                  _metaLine('Tags', msg.tags.map((t) => '#$t').join(' ')),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          if (paragraphs.isEmpty)
            pw.Text(
              '(Sem conteúdo textual)',
              style: pw.TextStyle(
                fontSize: 11,
                fontStyle: pw.FontStyle.italic,
                color: PdfColors.grey600,
              ),
            )
          else
            for (final p in paragraphs) ...[
              pw.Text(
                p,
                style: const pw.TextStyle(fontSize: 11, lineSpacing: 3),
              ),
              pw.SizedBox(height: 8),
            ],
          if (msg.attachments.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 6),
            pw.Text(
              'Anexos (${msg.attachments.length})',
              style: pw.TextStyle(
                fontSize: 11.5,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900,
              ),
            ),
            pw.SizedBox(height: 4),
            for (final att in msg.attachments)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 3),
                child: pw.Text(
                  '• ${att['name'] ?? 'anexo'}'
                  '${att['size'] is num ? ' (${((att['size'] as num) / 1024).toStringAsFixed(1)} KB)' : ''}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
          ],
        ],
      ),
    );
    return pdf.save();
  }

  static Future<String?> exportEmailPdf(JwEmailMessage msg) async {
    final bytes = await buildEmailPdfBytes(msg);
    final fileName =
        '${sanitizeFileName(msg.subject, fallback: 'email_retido')}.pdf';
    return BinaryFileSaver.saveBytes(
      fileName: fileName,
      bytes: bytes,
      mimeType: 'application/pdf',
      dialogTitle: 'Exportar E-mail em PDF',
    );
  }

  static Future<Uint8List> buildInboxEntryPdfBytes(InboxEntry entry) async {
    final theme = await _buildUnicodePdfTheme();
    final pdf = pw.Document(title: 'Captura do Inbox', theme: theme);
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm').format(entry.capturedAt);
    final paragraphs = _splitParagraphs(_cleanBodyText(entry.content));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (ctx) => [
          pw.Text(
            'INBOX — CAPTURA (${entry.sourceType.toUpperCase()})',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Capturado em: $dateFmt'
            '${entry.suggestedCategory != null ? ' • Categoria: ${entry.suggestedCategory}' : ''}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.Divider(color: PdfColors.blue700),
          pw.SizedBox(height: 10),
          for (final p in paragraphs) ...[
            pw.Text(p, style: const pw.TextStyle(fontSize: 11, lineSpacing: 3)),
            pw.SizedBox(height: 8),
          ],
        ],
      ),
    );
    return pdf.save();
  }

  static Future<String?> exportInboxEntryPdf(InboxEntry entry) async {
    final bytes = await buildInboxEntryPdfBytes(entry);
    final shortId = entry.id.length >= 8 ? entry.id.substring(0, 8) : entry.id;
    return BinaryFileSaver.saveBytes(
      fileName: 'inbox_captura_$shortId.pdf',
      bytes: bytes,
      mimeType: 'application/pdf',
      dialogTitle: 'Exportar Captura em PDF',
    );
  }

  static Future<Uint8List> buildSingleItemPdfBytes({
    required String title,
    required String content,
    required String itemType,
    required String category,
    String? subtitle,
    String? url,
    List<String> tags = const [],
    DateTime? updatedAt,
  }) async {
    final theme = await _buildUnicodePdfTheme();
    final pdf = pw.Document(title: title, theme: theme);
    final paragraphs = _splitParagraphs(_cleanBodyText(content));
    final dateText = updatedAt != null
        ? DateFormat('dd/MM/yyyy').format(updatedAt)
        : DateFormat('dd/MM/yyyy').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Base de Conhecimento • Página ${ctx.pageNumber} de ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600),
          ),
        ),
        build: (ctx) => [
          pw.Text(
            'BASE DE CONHECIMENTO — ${itemType.toUpperCase()}',
            style: pw.TextStyle(
              fontSize: 9.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue800,
              letterSpacing: 0.8,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 17,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey900,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Categoria: $category • Data: $dateText'
            '${subtitle != null && subtitle.trim().isNotEmpty ? ' • $subtitle' : ''}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          if (tags.isNotEmpty) ...[
            pw.SizedBox(height: 3),
            pw.Text(
              'Tags: ${tags.map((t) => '#$t').join(' ')}',
              style: const pw.TextStyle(
                fontSize: 9.5,
                color: PdfColors.blue700,
              ),
            ),
          ],
          if (url != null && url.trim().isNotEmpty) ...[
            pw.SizedBox(height: 3),
            pw.Text(
              'Link: $url',
              style: const pw.TextStyle(
                fontSize: 9.5,
                color: PdfColors.teal700,
              ),
            ),
          ],
          pw.SizedBox(height: 8),
          pw.Divider(color: PdfColors.blue700, thickness: 1.2),
          pw.SizedBox(height: 10),
          if (paragraphs.isEmpty)
            pw.Text(
              'Nenhum conteúdo adicional registrado.',
              style: pw.TextStyle(
                fontSize: 11,
                fontStyle: pw.FontStyle.italic,
                color: PdfColors.grey600,
              ),
            )
          else
            for (final p in paragraphs) ...[
              pw.Text(
                p,
                style: const pw.TextStyle(fontSize: 11, lineSpacing: 3),
              ),
              pw.SizedBox(height: 8),
            ],
        ],
      ),
    );
    return pdf.save();
  }

  static Future<String?> exportSingleItemPdf({
    required String title,
    required String content,
    required String itemType,
    required String category,
    String? subtitle,
    String? url,
    List<String> tags = const [],
    DateTime? updatedAt,
  }) async {
    final bytes = await buildSingleItemPdfBytes(
      title: title,
      content: content,
      itemType: itemType,
      category: category,
      subtitle: subtitle,
      url: url,
      tags: tags,
      updatedAt: updatedAt,
    );
    return BinaryFileSaver.saveBytes(
      fileName:
          '${sanitizeFileName(title, fallback: itemType.toLowerCase())}.pdf',
      bytes: bytes,
      mimeType: 'application/pdf',
      dialogTitle: 'Exportar $itemType em PDF',
    );
  }

  static Future<Uint8List> buildNotesListPdfBytes(
    List<KnowledgeNoteEntry> notes, {
    String? filterDescription,
  }) async {
    final theme = await _buildUnicodePdfTheme();
    final pdf = pw.Document(
      title: 'Base de Conhecimento — Notas',
      theme: theme,
    );
    final nowFmt = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Notas • Página ${ctx.pageNumber} de ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600),
          ),
        ),
        build: (ctx) {
          final widgets = <pw.Widget>[
            _buildCollectionHeader(
              title: 'BASE DE CONHECIMENTO — NOTAS',
              subtitle:
                  '${notes.length} nota(s) • Exportado em $nowFmt${filterDescription != null ? ' • $filterDescription' : ''}',
            ),
          ];
          for (final n in notes) {
            final tags = _decodeTags(n.tags)
                .where((t) => !t.startsWith('research:'))
                .toList();
            final paras = _splitParagraphs(_cleanBodyText(n.content));
            widgets.add(
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 12),
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(4),
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      n.title,
                      style: pw.TextStyle(
                        fontSize: 12.5,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Categoria: ${n.category} • Atualizado: ${DateFormat('dd/MM/yyyy').format(n.updatedAt)}'
                      '${tags.isNotEmpty ? ' • ${tags.map((t) => '#$t').join(' ')}' : ''}',
                      style: const pw.TextStyle(
                        fontSize: 8.5,
                        color: PdfColors.grey600,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    for (final p in paras) ...[
                      pw.Text(
                        p,
                        style: const pw.TextStyle(
                          fontSize: 10.5,
                          lineSpacing: 2.5,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                    ],
                  ],
                ),
              ),
            );
          }
          return widgets;
        },
      ),
    );
    return pdf.save();
  }

  static Future<String?> exportNotesListPdf(
    List<KnowledgeNoteEntry> notes, {
    String? filterDescription,
  }) async {
    final bytes = await buildNotesListPdfBytes(
      notes,
      filterDescription: filterDescription,
    );
    return BinaryFileSaver.saveBytes(
      fileName: 'base_conhecimento_notas.pdf',
      bytes: bytes,
      mimeType: 'application/pdf',
      dialogTitle: 'Exportar Notas em PDF',
    );
  }

  static Future<Uint8List> buildQuestionsListPdfBytes(
    List<KnowledgeQuestionEntry> questions, {
    String? filterDescription,
  }) async {
    final theme = await _buildUnicodePdfTheme();
    final pdf = pw.Document(
      title: 'Base de Conhecimento — Perguntas & Dúvidas',
      theme: theme,
    );
    final nowFmt = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Perguntas & Dúvidas • Página ${ctx.pageNumber} de ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600),
          ),
        ),
        build: (ctx) {
          final widgets = <pw.Widget>[
            _buildCollectionHeader(
              title: 'BASE DE CONHECIMENTO — PERGUNTAS & DÚVIDAS',
              subtitle:
                  '${questions.length} dúvida(s) • Exportado em $nowFmt${filterDescription != null ? ' • $filterDescription' : ''}',
            ),
          ];
          for (final q in questions) {
            final isAnswered = q.status == 'answered';
            final ctxClean = q.context != null
                ? _cleanBodyText(q.context!)
                : '';
            final ansClean = q.answer != null ? _cleanBodyText(q.answer!) : '';
            widgets.add(
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 12),
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(4),
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(
                          child: pw.Text(
                            q.question,
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.grey900,
                            ),
                          ),
                        ),
                        pw.SizedBox(width: 8),
                        pw.Text(
                          isAnswered ? 'Respondida' : 'Em Aberto',
                          style: pw.TextStyle(
                            fontSize: 8.5,
                            fontWeight: pw.FontWeight.bold,
                            color: isAnswered
                                ? PdfColors.green800
                                : PdfColors.orange800,
                          ),
                        ),
                      ],
                    ),
                    if (ctxClean.isNotEmpty) ...[
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Contexto: $ctxClean',
                        style: const pw.TextStyle(
                          fontSize: 9.5,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                    if (ansClean.isNotEmpty) ...[
                      pw.SizedBox(height: 5),
                      pw.Text(
                        'Resposta: $ansClean',
                        style: const pw.TextStyle(
                          fontSize: 10.5,
                          lineSpacing: 2.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }
          return widgets;
        },
      ),
    );
    return pdf.save();
  }

  static Future<String?> exportQuestionsListPdf(
    List<KnowledgeQuestionEntry> questions, {
    String? filterDescription,
  }) async {
    final bytes = await buildQuestionsListPdfBytes(
      questions,
      filterDescription: filterDescription,
    );
    return BinaryFileSaver.saveBytes(
      fileName: 'base_conhecimento_duvidas.pdf',
      bytes: bytes,
      mimeType: 'application/pdf',
      dialogTitle: 'Exportar Dúvidas em PDF',
    );
  }

  static Future<Uint8List> buildDocumentsListPdfBytes(
    List<KnowledgeDocumentEntry> docs, {
    String? filterDescription,
  }) async {
    final theme = await _buildUnicodePdfTheme();
    final pdf = pw.Document(
      title: 'Base de Conhecimento — Documentos',
      theme: theme,
    );
    final nowFmt = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Documentos • Página ${ctx.pageNumber} de ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600),
          ),
        ),
        build: (ctx) {
          final widgets = <pw.Widget>[
            _buildCollectionHeader(
              title: 'BASE DE CONHECIMENTO — DOCUMENTOS',
              subtitle:
                  '${docs.length} documento(s) • Exportado em $nowFmt${filterDescription != null ? ' • $filterDescription' : ''}',
            ),
          ];
          for (final d in docs) {
            final tags = _decodeTags(d.tags);
            final sizeKb = (d.fileSize / 1024).toStringAsFixed(1);
            final desc = d.description != null
                ? _cleanBodyText(d.description!)
                : '';
            widgets.add(
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 10),
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(4),
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      d.title,
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      '${d.fileName} (${d.fileType.toUpperCase()}) • $sizeKb KB • Categoria: ${d.category}'
                      '${tags.isNotEmpty ? ' • ${tags.map((t) => '#$t').join(' ')}' : ''}',
                      style: const pw.TextStyle(
                        fontSize: 8.5,
                        color: PdfColors.grey600,
                      ),
                    ),
                    if (desc.isNotEmpty) ...[
                      pw.SizedBox(height: 5),
                      pw.Text(
                        desc,
                        style: const pw.TextStyle(
                          fontSize: 10,
                          lineSpacing: 2.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }
          return widgets;
        },
      ),
    );
    return pdf.save();
  }

  static Future<String?> exportDocumentsListPdf(
    List<KnowledgeDocumentEntry> docs, {
    String? filterDescription,
  }) async {
    final bytes = await buildDocumentsListPdfBytes(
      docs,
      filterDescription: filterDescription,
    );
    return BinaryFileSaver.saveBytes(
      fileName: 'base_conhecimento_documentos.pdf',
      bytes: bytes,
      mimeType: 'application/pdf',
      dialogTitle: 'Exportar Lista de Documentos em PDF',
    );
  }

  static Future<Uint8List> buildResourcesListPdfBytes(
    List<KnowledgeResourceEntry> resources, {
    String? filterDescription,
  }) async {
    final theme = await _buildUnicodePdfTheme();
    final pdf = pw.Document(
      title: 'Base de Conhecimento — Recursos',
      theme: theme,
    );
    final nowFmt = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Recursos • Página ${ctx.pageNumber} de ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600),
          ),
        ),
        build: (ctx) {
          final widgets = <pw.Widget>[
            _buildCollectionHeader(
              title: 'BASE DE CONHECIMENTO — RECURSOS',
              subtitle:
                  '${resources.length} recurso(s) • Exportado em $nowFmt${filterDescription != null ? ' • $filterDescription' : ''}',
            ),
          ];
          for (final r in resources) {
            final tags = _decodeTags(r.tags);
            final desc = r.description != null
                ? _cleanBodyText(r.description!)
                : '';
            widgets.add(
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 10),
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(4),
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      r.title,
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.teal900,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Tipo: ${r.resourceType} • Categoria: ${r.category}'
                      '${tags.isNotEmpty ? ' • ${tags.map((t) => '#$t').join(' ')}' : ''}',
                      style: const pw.TextStyle(
                        fontSize: 8.5,
                        color: PdfColors.grey600,
                      ),
                    ),
                    if (r.url != null && r.url!.trim().isNotEmpty) ...[
                      pw.SizedBox(height: 3),
                      pw.Text(
                        r.url!,
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.blue700,
                        ),
                      ),
                    ],
                    if (desc.isNotEmpty) ...[
                      pw.SizedBox(height: 5),
                      pw.Text(
                        desc,
                        style: const pw.TextStyle(
                          fontSize: 10,
                          lineSpacing: 2.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }
          return widgets;
        },
      ),
    );
    return pdf.save();
  }

  static Future<String?> exportResourcesListPdf(
    List<KnowledgeResourceEntry> resources, {
    String? filterDescription,
  }) async {
    final bytes = await buildResourcesListPdfBytes(
      resources,
      filterDescription: filterDescription,
    );
    return BinaryFileSaver.saveBytes(
      fileName: 'base_conhecimento_recursos.pdf',
      bytes: bytes,
      mimeType: 'application/pdf',
      dialogTitle: 'Exportar Recursos em PDF',
    );
  }

  static Future<Uint8List> buildOfficialDocsIndexPdfBytes(
    List<OfficialDocumentRecord> docs,
  ) async {
    final theme = await _buildUnicodePdfTheme();
    final pdf = pw.Document(
      title: 'Base de Conhecimento — Cartas & Atas',
      theme: theme,
    );
    final nowFmt = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (ctx) {
          final widgets = <pw.Widget>[
            _buildCollectionHeader(
              title: 'BASE DE CONHECIMENTO — CARTAS & ATAS',
              subtitle: '${docs.length} documento(s) • Exportado em $nowFmt',
            ),
          ];
          for (final d in docs) {
            final cleanBody = _cleanBodyText(d.bodyMarkup);
            widgets.add(
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 10),
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(4),
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      d.title,
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      '${d.docType.label} • Atualizado em ${DateFormat('dd/MM/yyyy').format(d.updatedAt)}',
                      style: const pw.TextStyle(
                        fontSize: 8.5,
                        color: PdfColors.grey600,
                      ),
                    ),
                    if (cleanBody.isNotEmpty) ...[
                      pw.SizedBox(height: 5),
                      pw.Text(
                        cleanBody,
                        style: const pw.TextStyle(
                          fontSize: 10,
                          lineSpacing: 2.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }
          return widgets;
        },
      ),
    );
    return pdf.save();
  }

  static Future<String?> exportOfficialDocsIndexPdf(
    List<OfficialDocumentRecord> docs,
  ) async {
    final bytes = await buildOfficialDocsIndexPdfBytes(docs);
    return BinaryFileSaver.saveBytes(
      fileName: 'base_conhecimento_cartas_e_atas.pdf',
      bytes: bytes,
      mimeType: 'application/pdf',
      dialogTitle: 'Exportar Cartas & Atas em PDF',
    );
  }

  static pw.Widget _buildCollectionHeader({
    required String title,
    required String subtitle,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 14),
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.blue700, width: 1.5),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            subtitle,
            style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }

  static pw.Widget _metaLine(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 48,
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(
                fontSize: 9.5,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey800,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(value, style: const pw.TextStyle(fontSize: 9.5)),
          ),
        ],
      ),
    );
  }

  static List<String> _decodeTags(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .map((e) => e.toString().trim())
            .where((t) => t.isNotEmpty)
            .toList();
      }
    } catch (e, st) {
      AppLogger.debug('Falha ao ler tags JSON no exportador PDF: $e', st);
    }
    return const [];
  }
}
