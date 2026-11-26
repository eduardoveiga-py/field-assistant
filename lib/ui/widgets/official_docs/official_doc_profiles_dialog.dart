import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/app_logger.dart';
import '../../../core/app_theme.dart';
import '../../../official_docs/official_doc_fonts.dart';
import '../../../official_docs/official_doc_manager.dart';
import '../../../official_docs/official_doc_models.dart';
import '../../../official_docs/official_doc_presets.dart';
import '../../../reports/binary_file_saver.dart';
import '../../providers.dart';
import 'signature_pad_dialog.dart';

/// Modal completo de gerenciamento de Perfis Oficiais (Cabeçalhos, Anciãos + Assinatura PNG,
/// Blocos de Rodapé, Fontes Padrão) e Importação/Exportação JSON (Google Drive / Local).
class OfficialDocProfilesDialog extends ConsumerStatefulWidget {
  final int initialTab;

  const OfficialDocProfilesDialog({super.key, this.initialTab = 0});

  static Future<void> show(BuildContext context, {int initialTab = 0}) {
    return showDialog<void>(
      context: context,
      builder: (_) => OfficialDocProfilesDialog(initialTab: initialTab),
    );
  }

  @override
  ConsumerState<OfficialDocProfilesDialog> createState() =>
      _OfficialDocProfilesDialogState();
}

class _OfficialDocProfilesDialogState
    extends ConsumerState<OfficialDocProfilesDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final Uuid _uuid = const Uuid();
  bool _busy = false;
  String? _statusMessage;
  bool _statusIsError = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 3),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  OfficialDocManager get _manager => ref.read(officialDocManagerProvider);

  void _setStatus(String msg, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _statusMessage = msg;
      _statusIsError = isError;
    });
  }

  Future<void> _saveBundle(
    OfficialDocProfileBundle updated,
    String okMsg,
  ) async {
    setState(() => _busy = true);
    try {
      await _manager.saveBundle(updated);
      _setStatus(okMsg);
    } catch (e, st) {
      AppLogger.warning('Erro ao salvar bundle de perfis', e, st);
      _setStatus('Erro ao salvar perfis: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importFromFile() async {
    setState(() => _busy = true);
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json', 'txt'],
      );
      if (picked.isEmpty) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      final bytes = await picked.first.readAsBytes();
      final raw = utf8.decode(bytes);
      final res = await _manager.importBundleFromJson(raw);
      _setStatus(
        'Importado e salvo offline (${res.bundle.headers.length} cabeçalho(s), '
        '${res.bundle.elders.length} ancião(s), '
        '${res.bundle.signatureBlocks.length} bloco(s) de assinatura'
        '${res.importedTemplates > 0 ? ", ${res.importedTemplates} modelo(s)" : ""}).',
      );
    } catch (e, st) {
      AppLogger.warning('Falha ao importar JSON de perfis oficiais', e, st);
      _setStatus('Arquivo JSON inválido ou ilegível: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importFromPastedJson() async {
    final pasted = await _JsonPasteDialog.show(context);
    if (pasted == null || pasted.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final res = await _manager.importBundleFromJson(pasted);
      _setStatus(
        'JSON importado e salvo localmente (${res.bundle.headers.length} cabeçalho(s), '
        '${res.bundle.elders.length} ancião(s), '
        '${res.bundle.signatureBlocks.length} bloco(s)).',
      );
    } catch (e, st) {
      AppLogger.warning('Falha ao importar JSON colado', e, st);
      _setStatus('JSON colado inválido: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportJson() async {
    setState(() => _busy = true);
    try {
      final jsonStr = await _manager.exportBundleToJsonString();
      final bytes = Uint8List.fromList(utf8.encode(jsonStr));
      final saved = await BinaryFileSaver.saveBytes(
        fileName: 'Perfil_Cartas_Atas_FieldAssistant.json',
        bytes: bytes,
        mimeType: 'application/json',
        dialogTitle: 'Exportar Perfis e Modelos (JSON)',
      );
      if (saved != null) {
        _setStatus('Backup JSON exportado: $saved');
      }
    } catch (e, st) {
      AppLogger.warning('Erro ao exportar JSON de perfis', e, st);
      _setStatus('Erro ao exportar JSON: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bundleAsync = ref.watch(officialDocBundleStreamProvider);
    final bundle =
        bundleAsync.value ?? OfficialDocPresets.createDefaultBundle();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: (size.width * 0.92).clamp(320.0, 860.0),
        height: (size.height * 0.86).clamp(440.0, 740.0),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  const Icon(Icons.tune_rounded, color: AppTheme.primaryBlue),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Perfis, Timbres, Assinaturas & Drive JSON',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Tudo é salvo localmente em modo offline-first e sincronizado com criptografia.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  if (_busy)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  IconButton(
                    tooltip: 'Fechar',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            if (_statusMessage != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _statusIsError
                      ? Theme.of(context).colorScheme.errorContainer
                      : const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      _statusIsError
                          ? Icons.error_outline
                          : Icons.check_circle_outline,
                      size: 16,
                      color: _statusIsError
                          ? Theme.of(context).colorScheme.onErrorContainer
                          : const Color(0xFF166534),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _statusMessage!,
                        style: TextStyle(
                          fontSize: 12,
                          color: _statusIsError
                              ? Theme.of(context).colorScheme.onErrorContainer
                              : const Color(0xFF166534),
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      iconSize: 16,
                      onPressed: () => setState(() => _statusMessage = null),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabs: const [
                Tab(icon: Icon(Icons.domain_outlined), text: 'Cabeçalhos'),
                Tab(icon: Icon(Icons.draw_outlined), text: 'Anciãos & PNG'),
                Tab(
                  icon: Icon(Icons.groups_outlined),
                  text: 'Blocos de Assinatura',
                ),
                Tab(
                  icon: Icon(Icons.cloud_download_outlined),
                  text: 'Padrões & Drive JSON',
                ),
              ],
            ),
            const Divider(height: 1),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildHeadersTab(bundle, isDark),
                  _buildEldersTab(bundle, isDark),
                  _buildSignatureBlocksTab(bundle, isDark),
                  _buildDefaultsAndDriveTab(bundle, isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 1: CABEÇALHOS
  // ---------------------------------------------------------------------------

  Widget _buildHeadersTab(OfficialDocProfileBundle bundle, bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Selecione ou cadastre timbres de congregação para reutilizar em cartas e atas.',
                style: TextStyle(fontSize: 12.5, color: Colors.grey),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed: _busy ? null : () => _editHeader(bundle, null),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Novo Cabeçalho'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final h in bundle.headers)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: h.isEmptyHeader
                    ? Colors.grey.shade200
                    : Color(
                        0xFF000000 |
                            (int.tryParse(
                                  h.primaryColorHex.replaceFirst('#', ''),
                                  radix: 16,
                                ) ??
                                0x1D4ED8),
                      ),
                child: Icon(
                  h.isEmptyHeader ? Icons.visibility_off : Icons.apartment,
                  color: h.isEmptyHeader ? Colors.grey.shade700 : Colors.white,
                  size: 18,
                ),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      h.label,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (h.isDefault)
                    const Chip(
                      label: Text('Padrão', style: TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              subtitle: h.isEmptyHeader
                  ? const Text('Oculta timbre superior (documentos internos)')
                  : Text(
                      [
                        if (h.topSubtitle.isNotEmpty) h.topSubtitle,
                        if (h.mainTitle.isNotEmpty) h.mainTitle,
                        if (h.contactEmail.isNotEmpty) h.contactEmail,
                      ].join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
              trailing: h.isEmptyHeader
                  ? null
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!h.isDefault)
                          IconButton(
                            tooltip: 'Definir como padrão',
                            icon: const Icon(Icons.star_border),
                            onPressed: () {
                              final next = bundle.headers
                                  .map(
                                    (item) => item.copyWith(
                                      isDefault: item.id == h.id,
                                    ),
                                  )
                                  .toList();
                              _saveBundle(
                                bundle.copyWith(headers: next),
                                'Cabeçalho "${h.label}" definido como padrão.',
                              );
                            },
                          ),
                        IconButton(
                          tooltip: 'Editar cabeçalho',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _editHeader(bundle, h),
                        ),
                        if (bundle.headers
                                .where((x) => !x.isEmptyHeader)
                                .length >
                            1)
                          IconButton(
                            tooltip: 'Remover',
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.redAccent,
                            ),
                            onPressed: () {
                              final next = bundle.headers
                                  .where((item) => item.id != h.id)
                                  .toList();
                              _saveBundle(
                                bundle.copyWith(headers: next),
                                'Cabeçalho removido.',
                              );
                            },
                          ),
                      ],
                    ),
            ),
          ),
      ],
    );
  }

  Future<void> _editHeader(
    OfficialDocProfileBundle bundle,
    OfficialHeaderProfile? existing,
  ) async {
    final result = await _HeaderEditDialog.show(
      context,
      existing: existing,
      newId: existing?.id ?? 'hdr-${_uuid.v4().substring(0, 8)}',
    );
    if (result == null) return;
    final list = [...bundle.headers];
    if (result.isDefault) {
      for (var i = 0; i < list.length; i++) {
        list[i] = list[i].copyWith(isDefault: false);
      }
    }
    final idx = list.indexWhere((h) => h.id == result.id);
    if (idx >= 0) {
      list[idx] = result;
    } else {
      final emptyIdx = list.indexWhere((h) => h.isEmptyHeader);
      if (emptyIdx >= 0) {
        list.insert(emptyIdx, result);
      } else {
        list.add(result);
      }
    }
    await _saveBundle(
      bundle.copyWith(headers: list),
      'Cabeçalho "${result.label}" salvo localmente.',
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 2: ANCIÃOS & ASSINATURAS (CURSIVA OU PNG DESENHADO)
  // ---------------------------------------------------------------------------

  Widget _buildEldersTab(OfficialDocProfileBundle bundle, bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Cadastre os anciãos, suas designações padrão/alternativas, fonte cursiva preferida ou assinatura desenhada em PNG.',
                style: TextStyle(fontSize: 12.5, color: Colors.grey),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed: _busy ? null : () => _editElder(bundle, null),
              icon: const Icon(Icons.person_add_outlined, size: 18),
              label: const Text('Novo Ancião'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final elder in bundle.elders)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  SizedBox(
                    width: 130,
                    height: 44,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      alignment: Alignment.center,
                      child: _buildElderSigPreview(elder),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          elder.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Designações: ${elder.allRoles.join(" · ")}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          elder.hasDrawnSignature
                              ? 'Assinatura PNG desenhada ativa'
                              : 'Fonte: ${OfficialDocFonts.findById(elder.signatureFontId).displayName}',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: elder.hasDrawnSignature
                                ? AppTheme.accentTeal
                                : AppTheme.primaryBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Desenhar / Importar PNG',
                    icon: const Icon(Icons.draw_outlined),
                    onPressed: () => _openSignaturePadForElder(bundle, elder),
                  ),
                  IconButton(
                    tooltip: 'Editar ancião',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _editElder(bundle, elder),
                  ),
                  IconButton(
                    tooltip: 'Remover ancião',
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                    ),
                    onPressed: () {
                      final next = bundle.elders
                          .where((e) => e.id != elder.id)
                          .toList();
                      _saveBundle(
                        bundle.copyWith(elders: next),
                        'Ancião removido do catálogo.',
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildElderSigPreview(ElderSignerProfile elder) {
    if (elder.hasDrawnSignature) {
      try {
        final bytes = base64Decode(elder.signaturePngBase64!);
        return Padding(
          padding: const EdgeInsets.all(4),
          child: Image.memory(bytes, fit: BoxFit.contain),
        );
      } catch (_) {}
    }
    final family = OfficialDocFonts.findById(
      elder.signatureFontId,
      fallbackId: 'sacramento',
    ).flutterFamily;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        elder.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: family,
          fontSize: 20,
          color: const Color(0xFF0F172A),
        ),
      ),
    );
  }

  Future<void> _openSignaturePadForElder(
    OfficialDocProfileBundle bundle,
    ElderSignerProfile elder,
  ) async {
    final result = await SignaturePadDialog.show(
      context,
      elderName: elder.name,
      initialPngBase64: elder.signaturePngBase64,
    );
    if (result == null) return;
    final nextElders = bundle.elders.map((e) {
      if (e.id != elder.id) return e;
      return result.isEmpty
          ? e.copyWith(clearSignaturePng: true)
          : e.copyWith(signaturePngBase64: result);
    }).toList();
    await _saveBundle(
      bundle.copyWith(elders: nextElders),
      result.isEmpty
          ? 'Assinatura manuscrita removida; fonte cursiva reativada para ${elder.name}.'
          : 'Assinatura PNG salva offline para ${elder.name}.',
    );
  }

  Future<void> _editElder(
    OfficialDocProfileBundle bundle,
    ElderSignerProfile? existing,
  ) async {
    final result = await _ElderEditDialog.show(
      context,
      existing: existing,
      newId: existing?.id ?? 'elder-${_uuid.v4().substring(0, 8)}',
    );
    if (result == null) return;
    final list = [...bundle.elders];
    final idx = list.indexWhere((e) => e.id == result.id);
    if (idx >= 0) {
      list[idx] = result;
    } else {
      list.add(result);
    }
    await _saveBundle(
      bundle.copyWith(elders: list),
      'Ancião "${result.name}" salvo localmente.',
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 3: BLOCOS DE ASSINATURA (RODAPÉS)
  // ---------------------------------------------------------------------------

  Widget _buildSignatureBlocksTab(
    OfficialDocProfileBundle bundle,
    bool isDark,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Combine anciãos cadastrados em rodapés reutilizáveis (Comissão de Serviço, Corpo de Anciãos, Individual, etc.).',
                style: TextStyle(fontSize: 12.5, color: Colors.grey),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed: _busy ? null : () => _editSignatureBlock(bundle, null),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Novo Bloco'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final block in bundle.signatureBlocks)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: Icon(
                block.isEmptySignature
                    ? Icons.block
                    : Icons.verified_user_outlined,
                color: block.isEmptySignature
                    ? Colors.grey
                    : AppTheme.primaryBlue,
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      block.label,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (block.isDefault)
                    const Chip(
                      label: Text('Padrão', style: TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              subtitle: Text(
                block.isEmptySignature
                    ? 'Sem assinatura ao final (útil para pautas)'
                    : '${block.groupTitle.isNotEmpty ? "${block.groupTitle} · " : ""}'
                          '${block.signers.map((s) => "${s.name} (${s.role})").join(", ")}',
              ),
              trailing: block.isEmptySignature
                  ? null
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!block.isDefault)
                          IconButton(
                            tooltip: 'Definir como padrão',
                            icon: const Icon(Icons.star_border),
                            onPressed: () {
                              final next = bundle.signatureBlocks
                                  .map(
                                    (b) =>
                                        b.copyWith(isDefault: b.id == block.id),
                                  )
                                  .toList();
                              _saveBundle(
                                bundle.copyWith(signatureBlocks: next),
                                'Rodapé "${block.label}" definido como padrão.',
                              );
                            },
                          ),
                        IconButton(
                          tooltip: 'Editar bloco',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _editSignatureBlock(bundle, block),
                        ),
                        if (bundle.signatureBlocks
                                .where((b) => !b.isEmptySignature)
                                .length >
                            1)
                          IconButton(
                            tooltip: 'Remover',
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.redAccent,
                            ),
                            onPressed: () {
                              final next = bundle.signatureBlocks
                                  .where((b) => b.id != block.id)
                                  .toList();
                              _saveBundle(
                                bundle.copyWith(signatureBlocks: next),
                                'Bloco de assinatura removido.',
                              );
                            },
                          ),
                      ],
                    ),
            ),
          ),
      ],
    );
  }

  Future<void> _editSignatureBlock(
    OfficialDocProfileBundle bundle,
    OfficialSignatureBlock? existing,
  ) async {
    final result = await _SignatureBlockEditDialog.show(
      context,
      existing: existing,
      elders: bundle.elders,
      newId: existing?.id ?? 'sig-${_uuid.v4().substring(0, 8)}',
    );
    if (result == null) return;
    final list = [...bundle.signatureBlocks];
    if (result.isDefault) {
      for (var i = 0; i < list.length; i++) {
        list[i] = list[i].copyWith(isDefault: false);
      }
    }
    final idx = list.indexWhere((b) => b.id == result.id);
    if (idx >= 0) {
      list[idx] = result;
    } else {
      final emptyIdx = list.indexWhere((b) => b.isEmptySignature);
      if (emptyIdx >= 0) {
        list.insert(emptyIdx, result);
      } else {
        list.add(result);
      }
    }
    await _saveBundle(
      bundle.copyWith(signatureBlocks: list),
      'Bloco "${result.label}" salvo localmente.',
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 4: PADRÕES GLOBAIS & GOOGLE DRIVE JSON
  // ---------------------------------------------------------------------------

  Widget _buildDefaultsAndDriveTab(
    OfficialDocProfileBundle bundle,
    bool isDark,
  ) {
    final f = bundle.defaultFonts;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF0F9FF),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.cloud_done_outlined,
                      color: AppTheme.primaryBlue,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Importar do Google Drive / Arquivo JSON',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Seus dados da congregação ficam salvos com segurança no seu Drive (ex.: Perfil_Congregacao_*.json). Após importar uma única vez, tudo fica armazenado localmente offline no app e sincronizado via E2EE.',
                  style: TextStyle(fontSize: 12.5),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      key: const Key('btn_import_official_bundle_json'),
                      onPressed: _busy ? null : _importFromFile,
                      icon: const Icon(Icons.file_open_outlined, size: 18),
                      label: const Text('Importar Arquivo JSON'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _importFromPastedJson,
                      icon: const Icon(Icons.paste_rounded, size: 18),
                      label: const Text('Colar JSON'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _exportJson,
                      icon: const Icon(Icons.download_outlined, size: 18),
                      label: const Text('Exportar Backup JSON'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Estilo Visual e Fontes Padrão para Novos Documentos',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: OfficialDocLayoutStyle.fromId(bundle.defaultStyleId).id,
          decoration: const InputDecoration(
            labelText: 'Estilo Visual Padrão',
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
            _saveBundle(
              bundle.copyWith(defaultStyleId: val),
              'Estilo padrão atualizado.',
            );
          },
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _fontPickerBox(
              label: 'Fonte Padrão — Cabeçalho',
              value: f.headerFontId,
              options: OfficialDocFonts.textFonts,
              onChanged: (v) => _saveBundle(
                bundle.copyWith(defaultFonts: f.copyWith(headerFontId: v)),
                'Fonte padrão do cabeçalho salva.',
              ),
            ),
            _fontPickerBox(
              label: 'Fonte Padrão — Metadados (Ref/Data)',
              value: f.metaFontId,
              options: OfficialDocFonts.textFonts,
              onChanged: (v) => _saveBundle(
                bundle.copyWith(defaultFonts: f.copyWith(metaFontId: v)),
                'Fonte padrão dos metadados salva.',
              ),
            ),
            _fontPickerBox(
              label: 'Fonte Padrão — Corpo do Texto',
              value: f.bodyFontId,
              options: OfficialDocFonts.textFonts,
              onChanged: (v) => _saveBundle(
                bundle.copyWith(defaultFonts: f.copyWith(bodyFontId: v)),
                'Fonte padrão do corpo salva.',
              ),
            ),
            _fontPickerBox(
              label: 'Fonte Padrão — Assinaturas',
              value: f.signatureFontId,
              options: OfficialDocFonts.signatureFonts,
              onChanged: (v) => _saveBundle(
                bundle.copyWith(defaultFonts: f.copyWith(signatureFontId: v)),
                'Fonte padrão de assinatura salva.',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                'Tamanho padrão do corpo: ${f.bodyFontSizePt.toStringAsFixed(1)} pt',
                style: const TextStyle(fontSize: 13),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => _saveBundle(
                bundle.copyWith(
                  defaultStyleId: 'original',
                  defaultFonts: const OfficialFontSpec(),
                ),
                'Padrão fiel ao PDF original restaurado (PT Sans + PT Serif + Sacramento).',
              ),
              icon: const Icon(Icons.restore, size: 16),
              label: const Text('Restaurar Fontes do PDF'),
            ),
          ],
        ),
        Slider(
          value: f.bodyFontSizePt,
          min: 8.5,
          max: 13.0,
          divisions: 9,
          label: '${f.bodyFontSizePt.toStringAsFixed(1)} pt',
          onChanged: (v) {
            _saveBundle(
              bundle.copyWith(defaultFonts: f.copyWith(bodyFontSizePt: v)),
              'Tamanho padrão atualizado para ${v.toStringAsFixed(1)} pt.',
            );
          },
        ),
        SwitchListTile(
          title: const Text('Justificar parágrafos do corpo por padrão'),
          value: f.justifyBody,
          onChanged: (v) => _saveBundle(
            bundle.copyWith(defaultFonts: f.copyWith(justifyBody: v)),
            'Preferência de alinhamento atualizada.',
          ),
        ),
      ],
    );
  }

  Widget _fontPickerBox({
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
      width: 260,
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
}

// =============================================================================
// SUB-DIÁLOGOS DE EDIÇÃO
// =============================================================================

class _HeaderEditDialog extends StatefulWidget {
  final OfficialHeaderProfile? existing;
  final String newId;

  const _HeaderEditDialog({this.existing, required this.newId});

  static Future<OfficialHeaderProfile?> show(
    BuildContext context, {
    OfficialHeaderProfile? existing,
    required String newId,
  }) {
    return showDialog<OfficialHeaderProfile>(
      context: context,
      builder: (_) => _HeaderEditDialog(existing: existing, newId: newId),
    );
  }

  @override
  State<_HeaderEditDialog> createState() => _HeaderEditDialogState();
}

class _HeaderEditDialogState extends State<_HeaderEditDialog> {
  late final TextEditingController _labelCtrl;
  late final TextEditingController _topCtrl;
  late final TextEditingController _mainCtrl;
  late final TextEditingController _addr1Ctrl;
  late final TextEditingController _addr2Ctrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _footerCtrl;
  late String _primaryHex;
  late String _accentHex;
  late bool _showPages;
  late bool _isDefault;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _labelCtrl = TextEditingController(text: e?.label ?? '');
    _topCtrl = TextEditingController(text: e?.topSubtitle ?? '');
    _mainCtrl = TextEditingController(text: e?.mainTitle ?? '');
    _addr1Ctrl = TextEditingController(text: e?.addressLine1 ?? '');
    _addr2Ctrl = TextEditingController(text: e?.addressLine2 ?? '');
    _emailCtrl = TextEditingController(text: e?.contactEmail ?? '');
    _footerCtrl = TextEditingController(text: e?.footerNote ?? '');
    _primaryHex = e?.primaryColorHex ?? '#1D4ED8';
    _accentHex = e?.accentColorHex ?? '#0F766E';
    _showPages = e?.showPageNumbers ?? false;
    _isDefault = e?.isDefault ?? false;
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _topCtrl.dispose();
    _mainCtrl.dispose();
    _addr1Ctrl.dispose();
    _addr2Ctrl.dispose();
    _emailCtrl.dispose();
    _footerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existing == null ? 'Novo Cabeçalho' : 'Editar Cabeçalho',
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _labelCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nome do Perfil *',
                  hintText: 'Ex.: Congregação Local / Circuito',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _topCtrl,
                decoration: const InputDecoration(
                  labelText: 'Subtítulo Superior',
                  hintText: 'Ex.: CONGREGAÇÃO EXEMPLO (000000)',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _mainCtrl,
                decoration: const InputDecoration(
                  labelText: 'Título Principal (Cidade · UF ou Nome)',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _addr1Ctrl,
                decoration: const InputDecoration(
                  labelText: 'Endereço Linha 1',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _addr2Ctrl,
                decoration: const InputDecoration(
                  labelText: 'Endereço Linha 2',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'E-mail de Contato no Timbre',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _footerCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nota Discreta de Rodapé (Opcional)',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text('Cor Principal:', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 8),
                  for (final hex in const [
                    '#1D4ED8',
                    '#0F294A',
                    '#0F766E',
                    '#475569',
                    '#7C3AED',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InkWell(
                        onTap: () => setState(() => _primaryHex = hex),
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Color(
                              0xFF000000 |
                                  int.parse(hex.substring(1), radix: 16),
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _primaryHex == hex
                                  ? Colors.black
                                  : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              CheckboxListTile(
                value: _showPages,
                title: const Text('Exibir numeração de páginas'),
                onChanged: (v) => setState(() => _showPages = v ?? false),
                contentPadding: EdgeInsets.zero,
              ),
              CheckboxListTile(
                value: _isDefault,
                title: const Text('Usar como cabeçalho padrão'),
                onChanged: (v) => setState(() => _isDefault = v ?? false),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final label = _labelCtrl.text.trim();
            if (label.isEmpty) return;
            Navigator.pop(
              context,
              OfficialHeaderProfile(
                id: widget.newId,
                label: label,
                topSubtitle: _topCtrl.text.trim(),
                mainTitle: _mainCtrl.text.trim(),
                addressLine1: _addr1Ctrl.text.trim(),
                addressLine2: _addr2Ctrl.text.trim(),
                contactEmail: _emailCtrl.text.trim(),
                primaryColorHex: _primaryHex,
                accentColorHex: _accentHex,
                footerNote: _footerCtrl.text.trim(),
                showPageNumbers: _showPages,
                isDefault: _isDefault,
              ),
            );
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

class _ElderEditDialog extends StatefulWidget {
  final ElderSignerProfile? existing;
  final String newId;

  const _ElderEditDialog({this.existing, required this.newId});

  static Future<ElderSignerProfile?> show(
    BuildContext context, {
    ElderSignerProfile? existing,
    required String newId,
  }) {
    return showDialog<ElderSignerProfile>(
      context: context,
      builder: (_) => _ElderEditDialog(existing: existing, newId: newId),
    );
  }

  @override
  State<_ElderEditDialog> createState() => _ElderEditDialogState();
}

class _ElderEditDialogState extends State<_ElderEditDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _roleCtrl;
  late final TextEditingController _altRolesCtrl;
  late String _fontId;
  String? _pngBase64;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _roleCtrl = TextEditingController(text: e?.defaultRole ?? 'Ancião');
    _altRolesCtrl = TextEditingController(
      text: e?.alternateRoles.join(', ') ?? '',
    );
    _fontId = OfficialDocFonts.normalizeFontId(
      e?.signatureFontId,
      fallback: 'sacramento',
    );
    _pngBase64 = e?.signaturePngBase64;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _roleCtrl.dispose();
    _altRolesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existing == null ? 'Cadastrar Ancião' : 'Editar Ancião',
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Nome Completo *'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _roleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Designação Principal *',
                  hintText: 'Ex.: Coordenador, Secretário, Sup. de Serviço',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _altRolesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Outras Designações (separadas por vírgula)',
                  hintText: 'Ex.: Sup. de Serviço, Dirigente de Sentinela',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _fontId,
                decoration: const InputDecoration(
                  labelText: 'Fonte da Assinatura',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: OfficialDocFonts.signatureFonts
                    .map(
                      (f) => DropdownMenuItem(
                        value: f.id,
                        child: Text(
                          f.displayName,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: f.flutterFamily,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _fontId = v);
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final res = await SignaturePadDialog.show(
                    context,
                    elderName: _nameCtrl.text.trim().isEmpty
                        ? 'Ancião'
                        : _nameCtrl.text.trim(),
                    initialPngBase64: _pngBase64,
                  );
                  if (res == null || !mounted) return;
                  setState(() {
                    _pngBase64 = res.isEmpty ? null : res;
                  });
                },
                icon: const Icon(Icons.draw_outlined, size: 18),
                label: Text(
                  (_pngBase64 != null && _pngBase64!.isNotEmpty)
                      ? 'Editar / Remover Assinatura PNG'
                      : 'Desenhar ou Importar Assinatura PNG',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final name = _nameCtrl.text.trim();
            final role = _roleCtrl.text.trim();
            if (name.isEmpty) return;
            final alts = _altRolesCtrl.text
                .split(',')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList();
            Navigator.pop(
              context,
              ElderSignerProfile(
                id: widget.newId,
                name: name,
                defaultRole: role.isEmpty ? 'Ancião' : role,
                alternateRoles: alts,
                signatureFontId: _fontId,
                signaturePngBase64: _pngBase64,
              ),
            );
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

class _SignatureBlockEditDialog extends StatefulWidget {
  final OfficialSignatureBlock? existing;
  final List<ElderSignerProfile> elders;
  final String newId;

  const _SignatureBlockEditDialog({
    this.existing,
    required this.elders,
    required this.newId,
  });

  static Future<OfficialSignatureBlock?> show(
    BuildContext context, {
    OfficialSignatureBlock? existing,
    required List<ElderSignerProfile> elders,
    required String newId,
  }) {
    return showDialog<OfficialSignatureBlock>(
      context: context,
      builder: (_) => _SignatureBlockEditDialog(
        existing: existing,
        elders: elders,
        newId: newId,
      ),
    );
  }

  @override
  State<_SignatureBlockEditDialog> createState() =>
      _SignatureBlockEditDialogState();
}

class _SignatureBlockEditDialogState extends State<_SignatureBlockEditDialog> {
  late final TextEditingController _labelCtrl;
  late final TextEditingController _groupCtrl;
  late List<SignerSlot> _slots;
  late bool _isDefault;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _labelCtrl = TextEditingController(text: e?.label ?? '');
    _groupCtrl = TextEditingController(text: e?.groupTitle ?? '');
    _slots = List<SignerSlot>.from(e?.signers ?? const []);
    _isDefault = e?.isDefault ?? false;
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _groupCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existing == null
            ? 'Novo Bloco de Assinaturas'
            : 'Editar Bloco de Assinaturas',
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _labelCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nome do Bloco no Seletor *',
                  hintText: 'Ex.: A Comissão de Serviço',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _groupCtrl,
                decoration: const InputDecoration(
                  labelText: 'Título Impresso Acima das Assinaturas',
                  hintText: 'Ex.: A Comissão de Serviço (ou deixe vazio)',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Assinantes neste bloco',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  PopupMenuButton<ElderSignerProfile?>(
                    tooltip: 'Adicionar assinante',
                    child: const Chip(
                      avatar: Icon(Icons.add, size: 16),
                      label: Text('Adicionar Assinante'),
                    ),
                    onSelected: (elder) async {
                      if (elder != null) {
                        setState(() {
                          _slots.add(
                            SignerSlot(
                              elderId: elder.id,
                              name: elder.name,
                              role: elder.defaultRole,
                            ),
                          );
                        });
                      } else {
                        final custom = await _CustomSignerPrompt.show(context);
                        if (custom != null && mounted) {
                          setState(() => _slots.add(custom));
                        }
                      }
                    },
                    itemBuilder: (_) => [
                      for (final e in widget.elders)
                        PopupMenuItem(
                          value: e,
                          child: Text('${e.name} (${e.defaultRole})'),
                        ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: null,
                        child: Text('Outro nome avulso...'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < _slots.length; i++)
                Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    dense: true,
                    title: Text(_slots[i].name),
                    subtitle: Text(_slots[i].role),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.elders.any(
                          (e) =>
                              e.id == _slots[i].elderId &&
                              e.allRoles.length > 1,
                        ))
                          DropdownButton<String>(
                            value: _slots[i].role,
                            underline: const SizedBox(),
                            items: widget.elders
                                .firstWhere((e) => e.id == _slots[i].elderId)
                                .allRoles
                                .map(
                                  (r) => DropdownMenuItem(
                                    value: r,
                                    child: Text(
                                      r,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (r) {
                              if (r == null) return;
                              setState(() {
                                _slots[i] = SignerSlot(
                                  elderId: _slots[i].elderId,
                                  name: _slots[i].name,
                                  role: r,
                                  signatureFontIdOverride:
                                      _slots[i].signatureFontIdOverride,
                                  signaturePngBase64Override:
                                      _slots[i].signaturePngBase64Override,
                                );
                              });
                            },
                          ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => setState(() => _slots.removeAt(i)),
                        ),
                      ],
                    ),
                  ),
                ),
              CheckboxListTile(
                value: _isDefault,
                title: const Text('Definir como bloco padrão'),
                onChanged: (v) => setState(() => _isDefault = v ?? false),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final label = _labelCtrl.text.trim();
            if (label.isEmpty) return;
            Navigator.pop(
              context,
              OfficialSignatureBlock(
                id: widget.newId,
                label: label,
                groupTitle: _groupCtrl.text.trim(),
                signers: _slots,
                isDefault: _isDefault,
              ),
            );
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

class _CustomSignerPrompt extends StatefulWidget {
  const _CustomSignerPrompt();

  static Future<SignerSlot?> show(BuildContext context) {
    return showDialog<SignerSlot>(
      context: context,
      builder: (_) => const _CustomSignerPrompt(),
    );
  }

  @override
  State<_CustomSignerPrompt> createState() => _CustomSignerPromptState();
}

class _CustomSignerPromptState extends State<_CustomSignerPrompt> {
  final _nameCtrl = TextEditingController();
  final _roleCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _roleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Assinante Avulso'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Nome *'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _roleCtrl,
            decoration: const InputDecoration(labelText: 'Função / Designação'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final name = _nameCtrl.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(
              context,
              SignerSlot(name: name, role: _roleCtrl.text.trim()),
            );
          },
          child: const Text('Adicionar'),
        ),
      ],
    );
  }
}

class _JsonPasteDialog extends StatefulWidget {
  const _JsonPasteDialog();

  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      builder: (_) => const _JsonPasteDialog(),
    );
  }

  @override
  State<_JsonPasteDialog> createState() => _JsonPasteDialogState();
}

class _JsonPasteDialogState extends State<_JsonPasteDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Colar JSON de Perfis do Drive'),
      content: SizedBox(
        width: 480,
        child: TextField(
          controller: _ctrl,
          maxLines: 12,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: '{ "schemaVersion": 1, "headers": [...], ... }',
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _ctrl.text),
          child: const Text('Importar'),
        ),
      ],
    );
  }
}
