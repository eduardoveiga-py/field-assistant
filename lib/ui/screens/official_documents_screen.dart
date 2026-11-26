import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../core/app_logger.dart';
import '../../core/app_theme.dart';
import '../../official_docs/official_doc_docx_generator.dart';
import '../../official_docs/official_doc_fonts.dart';
import '../../official_docs/official_doc_manager.dart';
import '../../official_docs/official_doc_models.dart';
import '../../official_docs/official_doc_pdf_generator.dart';
import '../../official_docs/official_doc_presets.dart';
import '../../references/app_reference.dart';
import '../../reports/binary_file_saver.dart';
import '../../reports/knowledge_and_email_pdf_service.dart';
import '../providers.dart';
import 'inbox_screen.dart';
import '../widgets/official_docs/official_doc_preview_widget.dart';
import '../widgets/official_docs/official_doc_profiles_dialog.dart';
import '../widgets/rich_formatted_editing_controller.dart';
import '../widgets/rich_markdown_toolbar.dart';

/// Tela e workspace completo de Documentos Oficiais:
/// Cartas de Apresentação, Cartas Gerais, Pautas e Atas de Reunião.
/// Suporta 7 estilos visuais, cabeçalhos/rodapés selecionáveis, fontes personalizáveis,
/// modelos extensíveis, assinatura manuscrita PNG, exportação PDF/PNG/DOCX e envio por e-mail.
class OfficialDocumentsScreen extends ConsumerStatefulWidget {
  final bool embedded;
  final ValueNotifier<String?>? externalSelectionNotifier;

  const OfficialDocumentsScreen({
    super.key,
    this.embedded = false,
    this.externalSelectionNotifier,
  });

  /// Abre o seletor de modelos (4 nativos + modelos personalizados) e cria um documento novo.
  static Future<OfficialDocumentRecord?> openTemplateChooserAndCreate(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final manager = ref.read(officialDocManagerProvider);
    final templates = [
      ...OfficialDocPresets.builtInTemplates,
      ...await manager.getCustomTemplates(),
    ];
    if (!context.mounted) return null;

    final chosen = await showDialog<OfficialDocTemplate>(
      context: context,
      builder: (dCtx) => _TemplatePickerDialog(
        templates: templates,
        onDeleteCustom: (tpl) async {
          await manager.deleteCustomTemplate(tpl.id);
        },
      ),
    );
    if (chosen == null) return null;
    return manager.createFromTemplate(chosen);
  }

  @override
  ConsumerState<OfficialDocumentsScreen> createState() =>
      _OfficialDocumentsScreenState();
}

class _OfficialDocumentsScreenState
    extends ConsumerState<OfficialDocumentsScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  OfficialDocType? _filterType;
  String? _selectedDocId;
  bool _showPreviewOnNarrow = false;
  bool _exporting = false;
  Timer? _autoSaveDebounce;

  // Estado local do editor para feedback WYSIWYG instantâneo
  OfficialDocumentRecord? _editingDoc;
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _locDateCtrl = TextEditingController();
  final TextEditingController _refCtrl = TextEditingController();
  final TextEditingController _recipientCtrl = TextEditingController();
  final TextEditingController _meetingDtCtrl = TextEditingController();
  final TextEditingController _meetingLocCtrl = TextEditingController();
  final TextEditingController _openingPrayerCtrl = TextEditingController();
  final TextEditingController _closingPrayerCtrl = TextEditingController();
  final TextEditingController _participantsCtrl = TextEditingController();
  RichFormattedEditingController? _bodyCtrl;
  bool _suppressAutoSave = false;

  OfficialDocManager get _manager => ref.read(officialDocManagerProvider);

  @override
  void initState() {
    super.initState();
    widget.externalSelectionNotifier?.addListener(_onExternalSelection);
  }

  void _onExternalSelection() {
    final extId = widget.externalSelectionNotifier?.value;
    if (extId != null && extId.isNotEmpty && extId != _selectedDocId) {
      _loadDocumentIntoEditor(extId);
    }
  }

  @override
  void dispose() {
    _autoSaveDebounce?.cancel();
    widget.externalSelectionNotifier?.removeListener(_onExternalSelection);
    _searchCtrl.dispose();
    _titleCtrl.dispose();
    _locDateCtrl.dispose();
    _refCtrl.dispose();
    _recipientCtrl.dispose();
    _meetingDtCtrl.dispose();
    _meetingLocCtrl.dispose();
    _openingPrayerCtrl.dispose();
    _closingPrayerCtrl.dispose();
    _participantsCtrl.dispose();
    _bodyCtrl?.dispose();
    super.dispose();
  }

  Future<void> _loadDocumentIntoEditor(String docId) async {
    final doc = await _manager.getDocumentById(docId);
    if (doc == null || !mounted) return;
    _bindDocument(doc);
  }

  void _bindDocument(OfficialDocumentRecord doc) {
    _autoSaveDebounce?.cancel();
    _suppressAutoSave = true;
    _bodyCtrl?.dispose();
    final newBody = RichFormattedEditingController.fromMarkup(doc.bodyMarkup);
    newBody.addListener(_onEditorFieldChanged);

    setState(() {
      _selectedDocId = doc.id;
      _editingDoc = doc;
      _showPreviewOnNarrow = false;
      _titleCtrl.text = doc.title;
      _locDateCtrl.text = doc.locationDate;
      _refCtrl.text = doc.referenceSubject;
      _recipientCtrl.text = doc.recipientLine;
      _meetingDtCtrl.text = doc.meetingDateTime;
      _meetingLocCtrl.text = doc.meetingLocation;
      _openingPrayerCtrl.text = doc.openingPrayer;
      _closingPrayerCtrl.text = doc.closingPrayer;
      _participantsCtrl.text = doc.participants;
      _bodyCtrl = newBody;
    });
    if (widget.externalSelectionNotifier != null &&
        widget.externalSelectionNotifier!.value != doc.id) {
      widget.externalSelectionNotifier!.value = doc.id;
    }
    _suppressAutoSave = false;
  }

  OfficialDocumentRecord _collectDraftRecord() {
    final base = _editingDoc!;
    final bodyMarkup = _bodyCtrl != null
        ? RichFormattedEditingController.readMarkup(_bodyCtrl!)
        : base.bodyMarkup;
    final refText = _refCtrl.text.trim();
    final manualTitle = _titleCtrl.text.trim();
    return base.copyWith(
      title: manualTitle.isNotEmpty
          ? manualTitle
          : (refText.isNotEmpty ? refText : base.docType.label),
      locationDate: _locDateCtrl.text,
      referenceSubject: _refCtrl.text,
      recipientLine: _recipientCtrl.text,
      meetingDateTime: _meetingDtCtrl.text,
      meetingLocation: _meetingLocCtrl.text,
      openingPrayer: _openingPrayerCtrl.text,
      closingPrayer: _closingPrayerCtrl.text,
      participants: _participantsCtrl.text,
      bodyMarkup: bodyMarkup,
      updatedAt: DateTime.now(),
    );
  }

  void _onEditorFieldChanged() {
    if (_suppressAutoSave || _editingDoc == null) return;
    setState(() {
      _editingDoc = _collectDraftRecord();
    });
    _autoSaveDebounce?.cancel();
    _autoSaveDebounce = Timer(const Duration(milliseconds: 650), () {
      _saveNow(silent: true);
    });
  }

  Future<void> _saveNow({bool silent = false}) async {
    final current = _editingDoc;
    if (current == null) return;
    final captured = _collectDraftRecord();
    try {
      final saved = await _manager.saveDocument(captured);
      if (mounted) {
        setState(() => _editingDoc = saved);
        if (!silent) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Documento salvo offline com sucesso!'),
            ),
          );
        }
      }
    } catch (e, st) {
      AppLogger.warning('Falha ao salvar documento oficial', e, st);
      if (mounted && !silent) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao salvar documento: $e')));
      }
    }
  }

  Future<void> _createNewDocument() async {
    final created = await OfficialDocumentsScreen.openTemplateChooserAndCreate(
      context,
      ref,
    );
    if (created != null && mounted) {
      _bindDocument(created);
    }
  }

  OfficialHeaderProfile? _resolveHeader(
    OfficialDocumentRecord doc,
    OfficialDocProfileBundle bundle,
  ) {
    if (!doc.includeHeader) return null;
    if (doc.headerProfileId != null) {
      final found = bundle.headers
          .where((h) => h.id == doc.headerProfileId)
          .firstOrNull;
      if (found != null) return found;
    }
    return bundle.headers.where((h) => h.isDefault).firstOrNull ??
        bundle.headers.firstOrNull;
  }

  String _safeBaseFileName(OfficialDocumentRecord doc) {
    final raw =
        (doc.referenceSubject.trim().isNotEmpty
                ? doc.referenceSubject
                : doc.title)
            .trim();
    final sanitized = raw
        .replaceAll(RegExp(r'[\\/:*?"<>|\r\n]+'), '_')
        .replaceAll(RegExp(r'\s+'), '_');
    return sanitized.isEmpty ? 'Documento_Oficial' : sanitized;
  }

  Future<void> _exportFile(
    String format,
    OfficialDocProfileBundle bundle, {
    bool archiveInKnowledge = false,
  }) async {
    if (_editingDoc == null || _exporting) return;
    await _saveNow(silent: true);
    final doc = _collectDraftRecord();
    final header = _resolveHeader(doc, bundle);
    final groupTitle = _manager.resolveGroupTitle(doc, bundle);
    final signers = _manager.resolveEffectiveSigners(doc, bundle);
    final baseName = _safeBaseFileName(doc);

    setState(() => _exporting = true);
    try {
      if (format == 'print') {
        final pdfBytes = await OfficialDocPdfGenerator.generatePdfBytes(
          doc: doc,
          header: header,
          signatureGroupTitle: groupTitle,
          signers: signers,
        );
        await Printing.layoutPdf(
          name: '$baseName.pdf',
          onLayout: (_) async => pdfBytes,
        );
      } else if (format == 'pdf') {
        final pdfBytes = await OfficialDocPdfGenerator.generatePdfBytes(
          doc: doc,
          header: header,
          signatureGroupTitle: groupTitle,
          signers: signers,
        );
        if (archiveInKnowledge) {
          await _manager.archiveExportedFile(
            title: doc.title,
            fileName: '$baseName.pdf',
            fileType: 'pdf',
            bytes: pdfBytes,
            description: doc.referenceSubject,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'PDF arquivado na aba Documentos da Base de Conhecimento!',
                ),
              ),
            );
          }
        } else {
          final saved = await BinaryFileSaver.saveBytes(
            fileName: '$baseName.pdf',
            bytes: pdfBytes,
            mimeType: 'application/pdf',
            dialogTitle: 'Exportar PDF Oficial',
          );
          if (saved != null && mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('PDF salvo: $saved')));
          }
        }
      } else if (format == 'png') {
        final pdfBytes = await OfficialDocPdfGenerator.generatePdfBytes(
          doc: doc,
          header: header,
          signatureGroupTitle: groupTitle,
          signers: signers,
        );
        final pages = await OfficialDocPdfGenerator.renderPngPages(pdfBytes);
        if (pages.isEmpty) {
          throw StateError('Nenhuma página PNG foi rasterizada.');
        }
        for (var i = 0; i < pages.length; i++) {
          final name = pages.length == 1
              ? '$baseName.png'
              : '${baseName}_pag${i + 1}.png';
          await BinaryFileSaver.saveBytes(
            fileName: name,
            bytes: pages[i],
            mimeType: 'image/png',
            dialogTitle: 'Exportar Imagem PNG',
          );
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                pages.length == 1
                    ? 'PNG exportado com sucesso!'
                    : '${pages.length} páginas PNG exportadas!',
              ),
            ),
          );
        }
      } else if (format == 'docx') {
        final docxBytes = OfficialDocDocxGenerator.generateDocxBytes(
          doc: doc,
          header: header,
          signatureGroupTitle: groupTitle,
          signers: signers,
        );
        final saved = await BinaryFileSaver.saveBytes(
          fileName: '$baseName.docx',
          bytes: docxBytes,
          mimeType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
          dialogTitle: 'Exportar Documento Editável (.docx)',
        );
        if (saved != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('DOCX editável salvo: $saved')),
          );
        }
      }
    } catch (e, st) {
      AppLogger.warning('Falha ao exportar documento ($format)', e, st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro na exportação ($format): $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _sendByEmail(OfficialDocProfileBundle bundle) async {
    if (_editingDoc == null || _exporting) return;
    final choice = await showDialog<String>(
      context: context,
      builder: (dCtx) => SimpleDialog(
        title: const Text('Enviar Documento por E-mail'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dCtx, 'pdf'),
            child: const ListTile(
              leading: Icon(Icons.picture_as_pdf, color: Colors.redAccent),
              title: Text('Anexar como PDF (Recomendado)'),
              subtitle: Text('Mantém exatamente o visual timbrado e fontes.'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dCtx, 'docx'),
            child: const ListTile(
              leading: Icon(Icons.description, color: AppTheme.primaryBlue),
              title: Text('Anexar como DOCX Editável'),
              subtitle: Text('Ideal quando o destinatário vai editar.'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dCtx, 'png'),
            child: ListTile(
              leading: Icon(Icons.image, color: AppTheme.accentTeal),
              title: Text('Anexar como Imagem PNG'),
              subtitle: Text('Visualização imediata em qualquer celular.'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dCtx, 'both'),
            child: const ListTile(
              leading: Icon(Icons.attach_file, color: Colors.indigo),
              title: Text('Anexar PDF + DOCX juntos'),
            ),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;

    await _saveNow(silent: true);
    final doc = _collectDraftRecord();
    final header = _resolveHeader(doc, bundle);
    final groupTitle = _manager.resolveGroupTitle(doc, bundle);
    final signers = _manager.resolveEffectiveSigners(doc, bundle);
    final baseName = _safeBaseFileName(doc);

    setState(() => _exporting = true);
    try {
      final attachments = <Map<String, dynamic>>[];

      Future<void> attachPdf() async {
        final Uint8List pdfBytes =
            await OfficialDocPdfGenerator.generatePdfBytes(
              doc: doc,
              header: header,
              signatureGroupTitle: groupTitle,
              signers: signers,
            );
        attachments.add({
          'name': '$baseName.pdf',
          'size': pdfBytes.length,
          'path': '$baseName.pdf',
          'base64': base64Encode(pdfBytes),
          'contentType': 'application/pdf',
          'type': 'pdf',
        });
      }

      Future<void> attachDocx() async {
        final docxBytes = OfficialDocDocxGenerator.generateDocxBytes(
          doc: doc,
          header: header,
          signatureGroupTitle: groupTitle,
          signers: signers,
        );
        attachments.add({
          'name': '$baseName.docx',
          'size': docxBytes.length,
          'path': '$baseName.docx',
          'base64': base64Encode(docxBytes),
          'contentType': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
          'type': 'docx',
        });
      }

      if (choice == 'pdf' || choice == 'both') await attachPdf();
      if (choice == 'docx' || choice == 'both') await attachDocx();
      if (choice == 'png') {
        final pdfBytes = await OfficialDocPdfGenerator.generatePdfBytes(
          doc: doc,
          header: header,
          signatureGroupTitle: groupTitle,
          signers: signers,
        );
        final pages = await OfficialDocPdfGenerator.renderPngPages(pdfBytes);
        for (var i = 0; i < pages.length; i++) {
          final pngName = pages.length == 1
              ? '$baseName.png'
              : '${baseName}_pag${i + 1}.png';
          attachments.add({
            'name': pngName,
            'size': pages[i].length,
            'path': pngName,
            'base64': base64Encode(pages[i]),
            'contentType': 'image/png',
            'type': 'png',
          });
        }
      }

      if (!mounted) return;
      final subject = doc.referenceSubject.trim().isNotEmpty
          ? doc.referenceSubject.trim()
          : doc.title;
      final bodyIntro =
          'Prezados irmãos,\n\n'
          'Segue em anexo o documento oficial: "$subject"'
          '${doc.recipientLine.trim().isNotEmpty ? " (${doc.recipientLine.trim()})" : ""}.\n\n'
          'Atenciosamente,\n'
          '${header?.topSubtitle.trim().isNotEmpty == true ? header!.topSubtitle.trim() : "Secretaria"}';

      await InboxScreen.showComposeSheet(
        context,
        ref,
        initialSubject: subject,
        initialBody: bodyIntro,
        initialAttachments: attachments,
      );
    } catch (e, st) {
      AppLogger.warning('Falha ao preparar anexo para e-mail', e, st);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao preparar e-mail: $e')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _saveAsCustomTemplate() async {
    if (_editingDoc == null) return;
    final doc = _collectDraftRecord();
    final nameCtrl = TextEditingController(text: '${doc.title} (Modelo)');
    final descCtrl = TextEditingController();
    String? name;
    String desc = '';
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dCtx) => AlertDialog(
          title: const Text('Salvar como Novo Modelo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nome do Modelo *',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Descrição (opcional)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dCtx, true),
              child: const Text('Salvar Modelo'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      name = nameCtrl.text.trim();
      desc = descCtrl.text.trim();
    } finally {
      nameCtrl.dispose();
      descCtrl.dispose();
    }

    if (name.isEmpty) return;
    await _manager.saveDocumentAsTemplate(
      doc,
      templateName: name,
      description: desc,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Modelo "$name" salvo! Ele já aparece em "+ Novo Documento".',
          ),
        ),
      );
    }
  }

  Future<void> _convertAgendaToMinutes() async {
    if (_editingDoc == null) return;
    final saved = await _manager.saveDocument(_collectDraftRecord());
    final minutes = await _manager.convertAgendaToMinutes(saved);
    if (mounted) {
      _bindDocument(minutes);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ata criada a partir da Pauta com os tópicos mantidos!',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bundle =
        ref.watch(officialDocBundleStreamProvider).value ??
        OfficialDocPresets.createDefaultBundle();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 940;

    final body = Column(
      children: [
        _buildTopActionBar(isDark),
        const Divider(height: 1),
        Expanded(
          child: isWide
              ? Row(
                  children: [
                    SizedBox(
                      width: 280,
                      child: _buildDocumentListPane(bundle, isDark),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: _editingDoc == null
                          ? _buildEmptyEditorState(bundle, isDark)
                          : Row(
                              children: [
                                Expanded(
                                  flex: 6,
                                  child: _buildEditorPane(bundle, isDark),
                                ),
                                const VerticalDivider(width: 1),
                                Expanded(
                                  flex: 5,
                                  child: _buildLivePreviewPane(bundle, isDark),
                                ),
                              ],
                            ),
                    ),
                  ],
                )
              : (_editingDoc == null
                    ? _buildDocumentListPane(bundle, isDark)
                    : Column(
                        children: [
                          _buildMobileEditorToolbar(bundle, isDark),
                          const Divider(height: 1),
                          Expanded(
                            child: _showPreviewOnNarrow
                                ? _buildLivePreviewPane(bundle, isDark)
                                : _buildEditorPane(bundle, isDark),
                          ),
                        ],
                      )),
        ),
      ],
    );

    if (widget.embedded) {
      return Material(color: Colors.transparent, child: body);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cartas, Pautas & Atas'),
        actions: [
          IconButton(
            tooltip: 'Perfis, Timbres, Assinaturas e Drive JSON',
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => OfficialDocProfilesDialog.show(context),
          ),
        ],
      ),
      body: body,
      floatingActionButton: (!isWide && _editingDoc == null)
          ? FloatingActionButton.extended(
              onPressed: _createNewDocument,
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.post_add),
              label: const Text('Novo Doc.'),
            )
          : null,
    );
  }

  Future<void> _exportQuickPdf() async {
    if (_exporting) return;
    if (_editingDoc != null) {
      final bundle =
          ref.read(officialDocBundleStreamProvider).value ??
          await _manager.loadBundle();
      await _exportFile('pdf', bundle);
      return;
    }
    setState(() => _exporting = true);
    try {
      final docs = await _manager.watchDocuments().first;
      await KnowledgeAndEmailPdfService.exportOfficialDocsIndexPdf(docs);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Relatório de Cartas & Atas exportado em PDF!'),
          ),
        );
      }
    } catch (e, st) {
      AppLogger.warning(
        'Falha ao exportar índice de Cartas & Atas em PDF',
        e,
        st,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao gerar PDF: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Widget _buildTopActionBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FilledButton.icon(
            key: const Key('btn_new_official_doc'),
            onPressed: _createNewDocument,
            icon: const Icon(Icons.post_add, size: 18),
            label: const Text('Novo Documento'),
          ),
          OutlinedButton.icon(
            key: const Key('btn_official_doc_profiles'),
            onPressed: () => OfficialDocProfilesDialog.show(context),
            icon: const Icon(Icons.tune_rounded, size: 18),
            label: const Text('Perfis & Drive'),
          ),
          OutlinedButton.icon(
            key: const Key('btn_official_doc_quick_pdf'),
            onPressed: _exporting ? null : _exportQuickPdf,
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
            label: Text(
              _editingDoc != null ? 'Exportar PDF' : 'Exportar Lista PDF',
            ),
          ),
          if (_exporting)
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 6),
                Text('Gerando arquivo...', style: TextStyle(fontSize: 12)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildMobileEditorToolbar(
    OfficialDocProfileBundle bundle,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: Row(
        children: [
          IconButton(
            tooltip: 'Voltar à lista',
            onPressed: () async {
              await _saveNow(silent: true);
              if (mounted) {
                setState(() {
                  _editingDoc = null;
                  _selectedDocId = null;
                });
                if (widget.externalSelectionNotifier != null) {
                  widget.externalSelectionNotifier!.value = null;
                }
              }
            },
            icon: const Icon(Icons.arrow_back),
          ),
          Expanded(
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.edit_note, size: 16),
                  label: Text('Editar'),
                ),
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.visibility_outlined, size: 16),
                  label: Text('Prévia A4'),
                ),
              ],
              selected: {_showPreviewOnNarrow},
              onSelectionChanged: (sel) {
                setState(() => _showPreviewOnNarrow = sel.first);
              },
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            key: const Key('btn_official_doc_mobile_pdf'),
            tooltip: 'Exportar PDF',
            onPressed: _exporting ? null : () => _exportFile('pdf', bundle),
            icon: const Icon(
              Icons.picture_as_pdf_outlined,
              color: Colors.redAccent,
            ),
          ),
          IconButton(
            tooltip: 'Enviar por E-mail',
            onPressed: () => _sendByEmail(bundle),
            icon: const Icon(Icons.mail_outline, color: AppTheme.primaryBlue),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentListPane(OfficialDocProfileBundle bundle, bool isDark) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Filtrar cartas, pautas ou atas...',
              prefixIcon: const Icon(Icons.search, size: 18),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() {});
                      },
                    )
                  : null,
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('Todos'),
                selected: _filterType == null,
                onSelected: (_) => setState(() => _filterType = null),
              ),
              const SizedBox(width: 6),
              for (final t in OfficialDocType.values) ...[
                ChoiceChip(
                  label: Text(t.shortLabel),
                  selected: _filterType == t,
                  onSelected: (_) => setState(() => _filterType = t),
                ),
                const SizedBox(width: 6),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<List<OfficialDocumentRecord>>(
            stream: _manager.watchDocuments(
              filterType: _filterType,
              query: _searchCtrl.text,
            ),
            builder: (ctx, snap) {
              final docs = snap.data ?? const [];
              if (docs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.description_outlined,
                          size: 46,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Nenhum documento oficial ainda.',
                          style: TextStyle(fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Toque em "Novo Documento" para criar cartas, pautas ou atas, ou importe seus perfis do Drive.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: _createNewDocument,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Criar Primeiro Documento'),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return ListView.separated(
                itemCount: docs.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final d = docs[i];
                  final isSel = d.id == _selectedDocId;
                  return ListTile(
                    selected: isSel,
                    selectedTileColor: AppTheme.primaryBlue.withValues(
                      alpha: 0.09,
                    ),
                    leading: Icon(
                      d.docType.isMeeting
                          ? Icons.event_note_outlined
                          : Icons.mail_outline,
                      color: isSel ? AppTheme.primaryBlue : Colors.grey,
                    ),
                    title: Row(
                      children: [
                        if (d.isPinned)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(
                              Icons.push_pin,
                              size: 14,
                              color: Colors.amber,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            d.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      '${d.docType.shortLabel} · ${d.updatedAt.day.toString().padLeft(2, '0')}/${d.updatedAt.month.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 11.5),
                    ),
                    trailing: PopupMenuButton<String>(
                      iconSize: 18,
                      onSelected: (action) async {
                        if (action == 'pin') {
                          await _manager.togglePinDocument(d.id);
                        } else if (action == 'delete') {
                          await _manager.deleteDocument(d.id);
                          if (_selectedDocId == d.id && mounted) {
                            setState(() {
                              _selectedDocId = null;
                              _editingDoc = null;
                            });
                          }
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'pin',
                          child: Text(d.isPinned ? 'Desafixar' : 'Fixar'),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Excluir'),
                        ),
                      ],
                    ),
                    onTap: () => _bindDocument(d),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyEditorState(OfficialDocProfileBundle bundle, bool isDark) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.mark_email_read_outlined,
                size: 56,
                color: AppTheme.primaryBlue.withValues(alpha: 0.7),
              ),
              const SizedBox(height: 16),
              const Text(
                'Cartas Oficiais, Pautas & Atas',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Selecione um documento na lista ao lado ou inicie um novo com 7 estilos visuais, timbres configuráveis, assinatura PNG/cursiva, PDF, PNG, DOCX e anexo direto no e-mail.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: _createNewDocument,
                    icon: const Icon(Icons.post_add),
                    label: const Text('Novo Documento'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        OfficialDocProfilesDialog.show(context, initialTab: 3),
                    icon: const Icon(Icons.cloud_download_outlined),
                    label: const Text('Importar Perfis do Drive'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditorPane(OfficialDocProfileBundle bundle, bool isDark) {
    final doc = _editingDoc!;
    final style = OfficialDocLayoutStyle.fromId(doc.layoutStyleId);
    final selectedHeader = _resolveHeader(doc, bundle);

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // Barra de Exportação, E-mail e Ações do Documento
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.tonalIcon(
              onPressed: () => _saveNow(),
              icon: const Icon(Icons.save_outlined, size: 17),
              label: const Text('Salvar'),
            ),
            FilledButton.icon(
              key: const Key('btn_official_doc_send_email'),
              onPressed: _exporting ? null : () => _sendByEmail(bundle),
              icon: const Icon(Icons.mail_outline, size: 17),
              label: const Text('Enviar por E-mail'),
            ),
            PopupMenuButton<String>(
              key: const Key('btn_official_doc_export_menu'),
              tooltip: 'Exportar / Baixar / Arquivar',
              onSelected: (fmt) {
                if (fmt == 'archive_pdf') {
                  _exportFile('pdf', bundle, archiveInKnowledge: true);
                } else {
                  _exportFile(fmt, bundle);
                }
              },
              child: const Chip(
                avatar: Icon(Icons.download_outlined, size: 17),
                label: Text('Exportar / Salvar Como'),
              ),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'pdf',
                  child: ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.picture_as_pdf,
                      color: Colors.redAccent,
                    ),
                    title: Text('Salvar / Baixar PDF'),
                  ),
                ),
                PopupMenuItem(
                  value: 'docx',
                  child: ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.description,
                      color: AppTheme.primaryBlue,
                    ),
                    title: Text('Salvar / Baixar DOCX (Editável)'),
                  ),
                ),
                PopupMenuItem(
                  value: 'png',
                  child: ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.image_outlined,
                      color: AppTheme.accentTeal,
                    ),
                    title: Text('Salvar / Baixar PNG (Imagem)'),
                  ),
                ),
                PopupMenuItem(
                  value: 'print',
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.print_outlined),
                    title: Text('Visualizar / Imprimir PDF'),
                  ),
                ),
                PopupMenuDivider(),
                PopupMenuItem(
                  value: 'archive_pdf',
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.folder_copy_outlined),
                    title: Text('Arquivar PDF em Documentos'),
                  ),
                ),
              ],
            ),
            if (doc.docType == OfficialDocType.meetingAgenda)
              OutlinedButton.icon(
                onPressed: _convertAgendaToMinutes,
                icon: const Icon(Icons.transform, size: 17),
                label: const Text('Converter Pauta em Ata'),
              ),
            OutlinedButton.icon(
              onPressed: _saveAsCustomTemplate,
              icon: const Icon(Icons.bookmark_add_outlined, size: 17),
              label: const Text('Salvar como Modelo'),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 1. Estilo Visual (7 opções) e Seletor de Cabeçalho
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                key: const Key('dropdown_official_style'),
                isExpanded: true,
                initialValue: style.id,
                decoration: const InputDecoration(
                  labelText: 'Estilo Visual (7 Modelos)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: OfficialDocLayoutStyle.values
                    .map(
                      (s) => DropdownMenuItem(
                        value: s.id,
                        child: Text(s.name, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val == null) return;
                  setState(() {
                    _editingDoc = _collectDraftRecord().copyWith(
                      layoutStyleId: val,
                    );
                  });
                  _onEditorFieldChanged();
                },
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: 'Aplicar fontes padrão deste estilo',
              child: IconButton.outlined(
                onPressed: () {
                  setState(() {
                    _editingDoc = _collectDraftRecord().copyWith(
                      fontSpec: style.defaultFonts.copyWith(
                        bodyFontSizePt: doc.fontSpec.bodyFontSizePt,
                        justifyBody: style.defaultJustify,
                      ),
                    );
                  });
                  _onEditorFieldChanged();
                },
                icon: const Icon(Icons.auto_fix_high, size: 18),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Cabeçalho Selecionável + Toggle
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                key: const Key('dropdown_official_header'),
                isExpanded: true,
                initialValue:
                    selectedHeader?.id ??
                    (bundle.headers.isNotEmpty
                        ? bundle.headers.first.id
                        : null),
                decoration: const InputDecoration(
                  labelText: 'Cabeçalho / Timbre',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: bundle.headers
                    .map(
                      (h) => DropdownMenuItem(
                        value: h.id,
                        child: Text(h.label, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val == null) return;
                  final hdr = bundle.headers.firstWhere((h) => h.id == val);
                  setState(() {
                    _editingDoc = _collectDraftRecord().copyWith(
                      headerProfileId: val,
                      includeHeader: !hdr.isEmptyHeader,
                    );
                  });
                  _onEditorFieldChanged();
                },
              ),
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: const Text('Cabeçalho'),
              selected:
                  doc.includeHeader &&
                  !(selectedHeader?.isEmptyHeader ?? false),
              onSelected: (v) {
                setState(() {
                  _editingDoc = _collectDraftRecord().copyWith(
                    includeHeader: v,
                  );
                });
                _onEditorFieldChanged();
              },
            ),
          ],
        ),
        const SizedBox(height: 10),

        // 2. Metadados
        if (!doc.docType.isMeeting) ...[
          TextField(
            controller: _locDateCtrl,
            onChanged: (_) => _onEditorFieldChanged(),
            decoration: const InputDecoration(
              labelText: 'Local e Data',
              hintText: 'Ex.: Cidade - UF, 25 de novembro de 2026',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: _refCtrl,
          onChanged: (_) => _onEditorFieldChanged(),
          decoration: InputDecoration(
            labelText: doc.docType.isMeeting
                ? 'Título / Pauta / Ata *'
                : 'Ref. / Assunto *',
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _recipientCtrl,
          onChanged: (_) => _onEditorFieldChanged(),
          decoration: InputDecoration(
            labelText: doc.docType.isMeeting
                ? 'Participantes / Destinatário'
                : 'A/C (Destinatário)',
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
        if (doc.docType.isMeeting) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _meetingDtCtrl,
                  onChanged: (_) => _onEditorFieldChanged(),
                  decoration: const InputDecoration(
                    labelText: 'Data e Hora',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _meetingLocCtrl,
                  onChanged: (_) => _onEditorFieldChanged(),
                  decoration: const InputDecoration(
                    labelText: 'Local da Reunião',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _openingPrayerCtrl,
                  onChanged: (_) => _onEditorFieldChanged(),
                  decoration: const InputDecoration(
                    labelText: 'Oração Inicial',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _closingPrayerCtrl,
                  onChanged: (_) => _onEditorFieldChanged(),
                  decoration: const InputDecoration(
                    labelText: 'Oração Final',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _participantsCtrl,
            onChanged: (_) => _onEditorFieldChanged(),
            decoration: const InputDecoration(
              labelText: 'Lista de Presentes',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
        const SizedBox(height: 12),

        // 3. Corpo WYSIWYG com RichMarkdownToolbar
        const Text(
          'Conteúdo do Documento',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 4),
        if (_bodyCtrl != null) ...[
          RichMarkdownToolbar(
            controller: _bodyCtrl!,
            enableCrossReferences: true,
            enableHighlightPalette: false,
            enableImagePicker: false,
            initialReferenceCategory: AppRefCategory.bible,
            onChanged: _onEditorFieldChanged,
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _bodyCtrl!,
            maxLines: 14,
            minLines: 8,
            style: TextStyle(
              fontFamily: OfficialDocFonts.findById(doc.fontSpec.bodyFontId)
                  .flutterFamily,
              fontSize: 14,
              height: 1.45,
            ),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText:
                  'Redija a carta, pauta ou ata aqui com formatação limpa...',
            ),
          ),
        ],
        const SizedBox(height: 12),

        // 4. Rodapé / Assinaturas
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                key: const Key('dropdown_official_signature'),
                isExpanded: true,
                initialValue:
                    bundle.signatureBlocks.any(
                      (s) => s.id == doc.signatureBlockId,
                    )
                    ? doc.signatureBlockId
                    : (bundle.signatureBlocks.isNotEmpty
                          ? bundle.signatureBlocks.first.id
                          : null),
                decoration: const InputDecoration(
                  labelText: 'Bloco de Assinatura / Rodapé',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: bundle.signatureBlocks
                    .map(
                      (s) => DropdownMenuItem(
                        value: s.id,
                        child: Text(s.label, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val == null) return;
                  final block = bundle.signatureBlocks.firstWhere(
                    (b) => b.id == val,
                  );
                  setState(() {
                    _editingDoc = _collectDraftRecord().copyWith(
                      signatureBlockId: val,
                      includeSignature: !block.isEmptySignature,
                      clearCustomSigners: true,
                    );
                  });
                  _onEditorFieldChanged();
                },
              ),
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: const Text('Assinar'),
              selected: doc.includeSignature,
              onSelected: (v) {
                setState(() {
                  _editingDoc = _collectDraftRecord().copyWith(
                    includeSignature: v,
                  );
                });
                _onEditorFieldChanged();
              },
            ),
          ],
        ),
        const SizedBox(height: 10),

        // 5. Personalização Completa de Fontes & Alinhamento
        ExpansionTile(
          title: const Text(
            'Personalizar Fontes de Tudo & Alinhamento',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
          ),
          subtitle: Text(
            'Cabeçalho: ${OfficialDocFonts.findById(doc.fontSpec.headerFontId).id} · '
            'Corpo: ${OfficialDocFonts.findById(doc.fontSpec.bodyFontId).id} (${doc.fontSpec.bodyFontSizePt.toStringAsFixed(1)}pt) · '
            'Assinatura: ${OfficialDocFonts.findById(doc.fontSpec.signatureFontId).id}',
            style: const TextStyle(fontSize: 11.5),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _docFontDropdown(
                  label: 'Fonte do Cabeçalho',
                  value: doc.fontSpec.headerFontId,
                  options: OfficialDocFonts.textFonts,
                  onChanged: (v) => _updateDocFontSpec(
                    doc.fontSpec.copyWith(headerFontId: v),
                  ),
                ),
                _docFontDropdown(
                  label: 'Fonte dos Metadados',
                  value: doc.fontSpec.metaFontId,
                  options: OfficialDocFonts.textFonts,
                  onChanged: (v) =>
                      _updateDocFontSpec(doc.fontSpec.copyWith(metaFontId: v)),
                ),
                _docFontDropdown(
                  label: 'Fonte do Corpo',
                  value: doc.fontSpec.bodyFontId,
                  options: OfficialDocFonts.textFonts,
                  onChanged: (v) =>
                      _updateDocFontSpec(doc.fontSpec.copyWith(bodyFontId: v)),
                ),
                _docFontDropdown(
                  label: 'Fonte da Assinatura',
                  value: doc.fontSpec.signatureFontId,
                  options: OfficialDocFonts.signatureFonts,
                  onChanged: (v) => _updateDocFontSpec(
                    doc.fontSpec.copyWith(signatureFontId: v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: doc.fontSpec.bodyFontSizePt,
                    min: 8.5,
                    max: 13.0,
                    divisions: 9,
                    label:
                        '${doc.fontSpec.bodyFontSizePt.toStringAsFixed(1)} pt',
                    onChanged: (v) => _updateDocFontSpec(
                      doc.fontSpec.copyWith(bodyFontSizePt: v),
                    ),
                  ),
                ),
                Text(
                  '${doc.fontSpec.bodyFontSizePt.toStringAsFixed(1)} pt',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Justificar texto do corpo'),
                    value: doc.fontSpec.justifyBody,
                    onChanged: (v) => _updateDocFontSpec(
                      doc.fontSpec.copyWith(justifyBody: v),
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _updateDocFontSpec(const OfficialFontSpec()),
                  icon: const Icon(Icons.restore, size: 16),
                  label: const Text('Fontes do PDF'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  void _updateDocFontSpec(OfficialFontSpec nextSpec) {
    setState(() {
      _editingDoc = _collectDraftRecord().copyWith(fontSpec: nextSpec);
    });
    _onEditorFieldChanged();
  }

  Widget _docFontDropdown({
    required String label,
    required String value,
    required List<OfficialFontOption> options,
    required ValueChanged<String> onChanged,
  }) {
    final norm = OfficialDocFonts.normalizeFontId(
      value,
      fallback: options.first.id,
    );
    return SizedBox(
      width: 230,
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: options.any((o) => o.id == norm)
            ? norm
            : options.first.id,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        items: options
            .map(
              (o) => DropdownMenuItem(
                value: o.id,
                child: Text(
                  o.displayName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: o.flutterFamily,
                    fontSize: o.category == OfficialFontCategory.cursive
                        ? 17
                        : 13,
                  ),
                ),
              ),
            )
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }

  Widget _buildLivePreviewPane(OfficialDocProfileBundle bundle, bool isDark) {
    final doc = _collectDraftRecord();
    final header = _resolveHeader(doc, bundle);
    final groupTitle = _manager.resolveGroupTitle(doc, bundle);
    final signers = _manager.resolveEffectiveSigners(doc, bundle);

    return Container(
      color: isDark ? const Color(0xFF0B1120) : const Color(0xFFE2E8F0),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: OfficialDocPreviewWidget(
          doc: doc,
          header: header,
          signatureGroupTitle: groupTitle,
          signers: signers,
        ),
      ),
    );
  }
}

class _TemplatePickerDialog extends StatefulWidget {
  final List<OfficialDocTemplate> templates;
  final Future<void> Function(OfficialDocTemplate) onDeleteCustom;

  const _TemplatePickerDialog({
    required this.templates,
    required this.onDeleteCustom,
  });

  @override
  State<_TemplatePickerDialog> createState() => _TemplatePickerDialogState();
}

class _TemplatePickerDialogState extends State<_TemplatePickerDialog> {
  late List<OfficialDocTemplate> _items;

  @override
  void initState() {
    super.initState();
    _items = List<OfficialDocTemplate>.from(widget.templates);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Escolha um Modelo para Começar'),
      content: SizedBox(
        width: 480,
        height: 380,
        child: ListView.separated(
          itemCount: _items.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (ctx, i) {
            final tpl = _items[i];
            return ListTile(
              leading: Icon(
                tpl.docType.isMeeting
                    ? Icons.event_note_outlined
                    : Icons.description_outlined,
                color: AppTheme.primaryBlue,
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      tpl.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (!tpl.isBuiltIn)
                    const Chip(
                      label: Text(
                        'Personalizado',
                        style: TextStyle(fontSize: 10.5),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              subtitle: Text(
                tpl.description.isNotEmpty
                    ? tpl.description
                    : tpl.docType.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: tpl.isBuiltIn
                  ? const Icon(Icons.chevron_right)
                  : IconButton(
                      tooltip: 'Remover modelo personalizado',
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                      ),
                      onPressed: () async {
                        await widget.onDeleteCustom(tpl);
                        if (mounted) {
                          setState(() => _items.removeAt(i));
                        }
                      },
                    ),
              onTap: () => Navigator.pop(context, tpl),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}
