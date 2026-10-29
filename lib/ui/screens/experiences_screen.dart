import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/app_theme.dart';
import '../../core/date_utils.dart';
import '../../experiences/experience_manager.dart';
import '../../media/media_picker_helper.dart';

class ExperiencesScreen extends ConsumerStatefulWidget {
  const ExperiencesScreen({super.key});

  @override
  ConsumerState<ExperiencesScreen> createState() => _ExperiencesScreenState();
}

class _ExperiencesScreenState extends ConsumerState<ExperiencesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedTagFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _copyExperience(MinistryExperienceItem exp) {
    final dtFormatted = AppDateUtils.formatDateTimeWithAt(exp.dateTime);
    final text = '✨ Experiência no Ministério: ${exp.title}\n'
        '📅 Data: $dtFormatted\n'
        '${exp.locationOrModality != null ? "Modalidade: ${exp.locationOrModality}\n" : ""}'
        '${exp.tags.isNotEmpty ? "Tags: ${exp.tags.join(', ')}\n" : ""}\n'
        '${exp.content}';

    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Experiência copiada para a área de transferência!')),
    );
  }

  Future<void> _exportPdf(List<MinistryExperienceItem> experiences) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Relato de Experiências do Ministério',
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                pw.Text('${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                    style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          for (final exp in experiences) ...[
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 16),
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(exp.title, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      pw.Text(
                        '${exp.dateTime.day}/${exp.dateTime.month}/${exp.dateTime.year} às ${exp.dateTime.hour.toString().padLeft(2, '0')}:${exp.dateTime.minute.toString().padLeft(2, '0')}',
                        style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                  if (exp.locationOrModality != null && exp.locationOrModality!.isNotEmpty) ...[
                    pw.SizedBox(height: 4),
                    pw.Text('Modalidade: ${exp.locationOrModality}', style: const pw.TextStyle(fontSize: 11, color: PdfColors.blue700)),
                  ],
                  if (exp.tags.isNotEmpty) ...[
                    pw.SizedBox(height: 4),
                    pw.Text('Tags: ${exp.tags.join(", ")}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                  ],
                  pw.SizedBox(height: 8),
                  pw.Text(exp.content, style: const pw.TextStyle(fontSize: 11, lineSpacing: 1.3)),
                ],
              ),
            ),
          ],
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'experiencias_ministerio.pdf',
    );
  }

  void _showAddEditExperienceModal(BuildContext context, {MinistryExperienceItem? existing}) {
    final titleController = TextEditingController(text: existing?.title ?? '');
    final contentController = TextEditingController(text: existing?.content ?? '');
    DateTime chosenDate = existing?.dateTime ?? DateTime.now();
    TimeOfDay chosenTime = TimeOfDay.fromDateTime(chosenDate);
    String selectedModality = existing?.locationOrModality ?? 'De Casa em Casa';
    final mediaList = List<String>.from(existing?.mediaUrls ?? []);
    final tags = List<String>.from(existing?.tags ?? []);
    final tagInputController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return Dialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Cabeçalho com Título e Fechar
                    Row(
                      children: [
                        Icon(existing != null ? Icons.edit_note : Icons.auto_stories, color: AppTheme.accentTeal, size: 26),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            existing != null ? 'Editar Experiência' : 'Relatar Nova Experiência',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          tooltip: 'Fechar',
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    // Conteúdo com rolagem garantida
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: titleController,
                              decoration: const InputDecoration(
                                labelText: 'Título da Experiência *',
                                hintText: 'Ex: Conversa marcante sobre o consolo bíblico',
                              ),
                              autofocus: existing == null,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.date_range, size: 16),
                                    label: Text('${chosenDate.day}/${chosenDate.month}/${chosenDate.year}'),
                                    onPressed: () async {
                                      final p = await showDatePicker(
                                        context: context,
                                        initialDate: chosenDate,
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime.now().add(const Duration(days: 30)),
                                      );
                                      if (p != null) setDialogState(() => chosenDate = p);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.access_time, size: 16),
                                    label: Text('${chosenTime.hour.toString().padLeft(2, '0')}:${chosenTime.minute.toString().padLeft(2, '0')}'),
                                    onPressed: () async {
                                      final t = await showTimePicker(context: context, initialTime: chosenTime);
                                      if (t != null) setDialogState(() => chosenTime = t);
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String>(
                              initialValue: selectedModality,
                              decoration: const InputDecoration(labelText: 'Modalidade / Local'),
                              items: const [
                                DropdownMenuItem(value: 'De Casa em Casa', child: Text('🏠 De Casa em Casa')),
                                DropdownMenuItem(value: 'TPL / Carrinho', child: Text('🛒 TPL (Testemunho Público)')),
                                DropdownMenuItem(value: 'Testemunho Informal', child: Text('💬 Testemunho Informal')),
                                DropdownMenuItem(value: 'Telefone', child: Text('📞 Telefone / Cartas')),
                                DropdownMenuItem(value: 'Revisita / Estudo', child: Text('📖 Revisita / Estudo Bíblico')),
                              ],
                              onChanged: (val) {
                                if (val != null) setDialogState(() => selectedModality = val);
                              },
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: contentController,
                              decoration: const InputDecoration(
                                labelText: 'Relato da Experiência *',
                                hintText: 'Escreva como foi o contato, reações, textos bíblicos usados e lições aprendidas...',
                              ),
                              maxLines: 5,
                            ),
                            const SizedBox(height: 12),

                            // INSERÇÃO DE IMAGEM / VÍDEO
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Fotos / Mídias Anexadas:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                IconButton.filledTonal(
                                  icon: const Icon(Icons.add_photo_alternate, size: 18),
                                  tooltip: 'Adicionar Foto / Vídeo',
                                  onPressed: () async {
                                    final img = await MediaPickerHelper.pickImage(context, title: 'Adicionar Foto à Experiência');
                                    if (img != null && img.isNotEmpty) {
                                      setDialogState(() => mediaList.add(img));
                                    }
                                  },
                                ),
                              ],
                            ),
                            if (mediaList.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: List.generate(mediaList.length, (i) {
                                  return Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Container(
                                        width: 70,
                                        height: 70,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.grey.shade300),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: MediaPickerHelper.buildImageWidget(mediaList[i]),
                                        ),
                                      ),
                                      Positioned(
                                        top: -4,
                                        right: -4,
                                        child: InkWell(
                                          onTap: () => setDialogState(() => mediaList.removeAt(i)),
                                          child: Container(
                                            padding: const EdgeInsets.all(2),
                                            decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
                                            child: const Icon(Icons.close, color: Colors.white, size: 14),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }),
                              ),
                            ],

                            const SizedBox(height: 12),
                            // TAGS
                            const Text('Tags da Experiência:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              children: tags.map((t) {
                                return Chip(
                                  label: Text(t, style: const TextStyle(fontSize: 11)),
                                  deleteIcon: const Icon(Icons.close, size: 14),
                                  onDeleted: () => setDialogState(() => tags.remove(t)),
                                  visualDensity: VisualDensity.compact,
                                );
                              }).toList(),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: tagInputController,
                                    decoration: const InputDecoration(
                                      labelText: 'Nova tag',
                                      hintText: 'Ex: jovem, oração, folheto',
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle, color: AppTheme.accentTeal),
                                  onPressed: () {
                                    final text = tagInputController.text.trim();
                                    if (text.isNotEmpty && !tags.contains(text)) {
                                      setDialogState(() {
                                        tags.add(text);
                                        tagInputController.clear();
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 20),
                    // Botões de Ação Inferiores
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Salvar Experiência'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentTeal,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () async {
                            final title = titleController.text.trim();
                            final content = contentController.text.trim();
                            if (title.isEmpty || content.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Informe ao menos o título e o relato da experiência.')),
                              );
                              return;
                            }

                            final dt = DateTime(chosenDate.year, chosenDate.month, chosenDate.day, chosenTime.hour, chosenTime.minute);
                            final mgr = ref.read(experienceManagerProvider);

                            if (existing != null) {
                              await mgr.updateExperience(MinistryExperienceItem(
                                id: existing.id,
                                title: title,
                                content: content,
                                mediaUrls: mediaList,
                                tags: tags,
                                dateTime: dt,
                                locationOrModality: selectedModality,
                                createdAt: existing.createdAt,
                                updatedAt: DateTime.now(),
                              ));
                            } else {
                              await mgr.addExperience(
                                title: title,
                                content: content,
                                mediaUrls: mediaList,
                                tags: tags,
                                dateTime: dt,
                                locationOrModality: selectedModality,
                              );
                            }

                            if (ctx.mounted) Navigator.pop(ctx);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(existing != null ? 'Experiência atualizada!' : 'Experiência salva com sucesso!')),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final experiencesAsync = ref.watch(experiencesStreamProvider);
    final experiences = experiencesAsync.value ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final allTags = <String>{};
    for (final exp in experiences) {
      allTags.addAll(exp.tags);
    }

    final query = _searchController.text.trim().toLowerCase();
    final filtered = experiences.where((exp) {
      if (query.isNotEmpty) {
        final matches = exp.title.toLowerCase().contains(query) ||
            exp.content.toLowerCase().contains(query) ||
            (exp.locationOrModality ?? '').toLowerCase().contains(query) ||
            exp.tags.any((t) => t.toLowerCase().contains(query));
        if (!matches) return false;
      }
      if (_selectedTagFilter != null && !exp.tags.contains(_selectedTagFilter)) {
        return false;
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Experiências no Ministério'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Exportar para PDF',
            onPressed: () => _exportPdf(filtered),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '+ Relatar Experiência',
            onPressed: () => _showAddEditExperienceModal(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.accentTeal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.edit_note),
        label: const Text('+ Relatar Experiência'),
        onPressed: () => _showAddEditExperienceModal(context),
      ),
      body: Column(
        children: [
          // Barra de Pesquisa
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Pesquisar experiências por título, relato ou tag...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),

          // Filtro por Tags
          if (allTags.isNotEmpty) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: const Text('Todas'),
                      selected: _selectedTagFilter == null,
                      onSelected: (val) => setState(() => _selectedTagFilter = null),
                      selectedColor: AppTheme.accentTeal.withValues(alpha: 0.15),
                      checkmarkColor: AppTheme.accentTeal,
                    ),
                  ),
                  for (final t in allTags)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text('#$t'),
                        selected: _selectedTagFilter == t,
                        onSelected: (val) => setState(() => _selectedTagFilter = val ? t : null),
                        selectedColor: AppTheme.accentTeal.withValues(alpha: 0.2),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Lista de Experiências
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.auto_stories_outlined, size: 56, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            query.isEmpty
                                ? 'Nenhuma experiência relatada ainda.\nToque em "+ Relatar Experiência" para guardar seus momentos especiais de pregação.'
                                : 'Nenhuma experiência encontrada para "$query".',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: isDark ? const Color(0xFFCBD5E1) : AppTheme.textMuted, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final exp = filtered[index];
                      final dtFormatted = AppDateUtils.formatDateTimeWithAt(exp.dateTime);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.accentTeal.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.bookmark_added, color: AppTheme.accentTeal, size: 22),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          exp.title,
                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 3),
                                        Row(
                                          children: [
                                            const Icon(Icons.access_time, size: 12, color: AppTheme.textMuted),
                                            const SizedBox(width: 4),
                                            Text(dtFormatted, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                            if (exp.locationOrModality != null && exp.locationOrModality!.isNotEmpty) ...[
                                              const SizedBox(width: 8),
                                              Text('• ${exp.locationOrModality!}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.accentTeal)),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    padding: EdgeInsets.zero,
                                    onSelected: (val) async {
                                      if (val == 'edit') {
                                        _showAddEditExperienceModal(context, existing: exp);
                                      } else if (val == 'delete') {
                                        final mgr = ref.read(experienceManagerProvider);
                                        await mgr.deleteExperience(exp.id);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Experiência removida.')),
                                          );
                                        }
                                      }
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(value: 'edit', child: Text('Editar')),
                                      PopupMenuItem(value: 'delete', child: Text('Excluir')),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                exp.content,
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.4,
                                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.textDark,
                                ),
                              ),

                              // Miniaturas de Mídias / Fotos
                              if (exp.mediaUrls.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                SizedBox(
                                  height: 80,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: exp.mediaUrls.length,
                                    itemBuilder: (ctx, i) {
                                      final img = exp.mediaUrls[i];
                                      return GestureDetector(
                                        onTap: () => MediaPickerHelper.showFullScreenImage(
                                          context,
                                          imageSource: img,
                                          title: exp.title,
                                        ),
                                        child: Container(
                                          margin: const EdgeInsets.only(right: 8),
                                          width: 80,
                                          height: 80,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.grey.shade300),
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: MediaPickerHelper.buildImageWidget(img),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],

                              if (exp.tags.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 4,
                                  children: exp.tags.map((t) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.accentTeal.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text('#$t', style: const TextStyle(fontSize: 10, color: AppTheme.accentTeal, fontWeight: FontWeight.bold)),
                                    );
                                  }).toList(),
                                ),
                              ],

                              const Divider(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                                    icon: const Icon(Icons.copy, size: 14),
                                    label: const Text('Copiar Relato', style: TextStyle(fontSize: 11)),
                                    onPressed: () => _copyExperience(exp),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.accentTeal,
                                      foregroundColor: Colors.white,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    icon: const Icon(Icons.picture_as_pdf, size: 14),
                                    label: const Text('Exportar PDF', style: TextStyle(fontSize: 11)),
                                    onPressed: () => _exportPdf([exp]),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
