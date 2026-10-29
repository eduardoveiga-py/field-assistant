import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_theme.dart';
import '../../core/date_utils.dart';
import '../../database/app_database.dart';
import '../../publications/periodicals_catalog.dart';
import '../../publications/person_publications_manager.dart';

class PersonPublicationsTab extends ConsumerStatefulWidget {
  final PersonEntry person;

  const PersonPublicationsTab({super.key, required this.person});

  @override
  ConsumerState<PersonPublicationsTab> createState() => _PersonPublicationsTabState();
}

class _PersonPublicationsTabState extends ConsumerState<PersonPublicationsTab> {
  void _quickAddPlaced(String title) async {
    final mgr = ref.read(personPublicationsManagerProvider);
    await mgr.addPlacedPublication(
      personId: widget.person.id,
      title: title,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"$title" registrada como deixada com ${widget.person.name}!')),
      );
    }
  }

  void _showAddCustomPlacedDialog() {
    final titleController = TextEditingController();
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.auto_stories, color: AppTheme.primaryBlue),
            SizedBox(width: 8),
            Text('Publicação Deixada'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Nome da Publicação *',
                hintText: 'Ex: Brochura Quem Está Fazendo a Vontade de Jeová?',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Observações (opcional)',
                hintText: 'Ex: Deixada com o filho mais velho',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final text = titleController.text.trim();
              if (text.isEmpty) return;
              final mgr = ref.read(personPublicationsManagerProvider);
              await mgr.addPlacedPublication(
                personId: widget.person.id,
                title: text,
                notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  void _showFolhetosDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.description, color: AppTheme.primaryBlue),
            SizedBox(width: 8),
            Expanded(child: Text('Selecionar Folheto', style: TextStyle(fontSize: 16))),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: PeriodicalsCatalog.folhetos.length,
            itemBuilder: (context, i) {
              final item = PeriodicalsCatalog.folhetos[i];
              return ListTile(
                dense: true,
                leading: const Icon(Icons.article_outlined, size: 20, color: AppTheme.accentTeal),
                title: Text(item.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _quickAddPlaced(item.title);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar')),
        ],
      ),
    );
  }

  void _showSentinelasDialog() {
    int selectedYear = 2026;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final yearItems = PeriodicalsCatalog.sentinelas.where((s) => s.year == selectedYear).toList();
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.newspaper, color: AppTheme.primaryBlue),
                SizedBox(width: 8),
                Expanded(child: Text('A Sentinela (Edição para o Público)', style: TextStyle(fontSize: 16))),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Selecione o ano da revista (2018 a 2027):', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(10, (idx) {
                        final y = 2018 + idx;
                        final isSel = y == selectedYear;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text('$y', style: TextStyle(fontSize: 11, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                            selected: isSel,
                            onSelected: (_) => setDialogState(() => selectedYear = y),
                          ),
                        );
                      }),
                    ),
                  ),
                  const Divider(height: 16),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: yearItems.length,
                      itemBuilder: (context, i) {
                        final item = yearItems[i];
                        return ListTile(
                          dense: true,
                          leading: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('N.º ${item.issueNumber}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                          ),
                          title: Text(item.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          subtitle: Text('Tema de capa: "${item.coverTheme}"', style: const TextStyle(fontSize: 11)),
                          onTap: () {
                            Navigator.pop(ctx);
                            _quickAddPlaced('${item.title} — "${item.coverTheme}"');
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar')),
            ],
          );
        },
      ),
    );
  }

  void _showDespertaisDialog() {
    int selectedYear = 2026;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final yearItems = PeriodicalsCatalog.despertais.where((s) => s.year == selectedYear).toList();
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.alarm, color: Color(0xFFD97706)),
                SizedBox(width: 8),
                Expanded(child: Text('Despertai! (2018 a 2027)', style: TextStyle(fontSize: 16))),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Selecione o ano da revista (2018 a 2027):', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(10, (idx) {
                        final y = 2018 + idx;
                        final isSel = y == selectedYear;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text('$y', style: TextStyle(fontSize: 11, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                            selected: isSel,
                            onSelected: (_) => setDialogState(() => selectedYear = y),
                          ),
                        );
                      }),
                    ),
                  ),
                  const Divider(height: 16),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: yearItems.length,
                      itemBuilder: (context, i) {
                        final item = yearItems[i];
                        return ListTile(
                          dense: true,
                          leading: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD97706).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('N.º ${item.issueNumber}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                          ),
                          title: Text(item.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          subtitle: Text('Tema de capa: "${item.coverTheme}"', style: const TextStyle(fontSize: 11)),
                          onTap: () {
                            Navigator.pop(ctx);
                            _quickAddPlaced('${item.title} — "${item.coverTheme}"');
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar')),
            ],
          );
        },
      ),
    );
  }

  void _showAddRequestDialog() {
    final titleController = TextEditingController();
    final reminderNotesController = TextEditingController(text: 'Pedir no balcão de publicações no Salão do Reino');
    DateTime chosenDate = DateTime.now().add(const Duration(days: 7));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.bookmark_add, color: AppTheme.accentTeal),
              SizedBox(width: 8),
              Expanded(child: Text('Pedido de Publicação do Estudante', style: TextStyle(fontSize: 16))),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Registre pedidos do estudante e configure lembretes para você não esquecer de pedir no balcão e trazer na visita.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Publicação Pedida *',
                    hintText: 'Ex: Bíblia de Letra Grande, Livro em Espanhol...',
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: reminderNotesController,
                  decoration: const InputDecoration(
                    labelText: 'Lembrete para mim *',
                    hintText: 'Ex: Lembrar de pedir no balcão no domingo',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text('Trazer até:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 14),
                      label: Text('${chosenDate.day}/${chosenDate.month}/${chosenDate.year}'),
                      onPressed: () async {
                        final p = await showDatePicker(
                          context: context,
                          initialDate: chosenDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 180)),
                        );
                        if (p != null) setDialogState(() => chosenDate = p);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                final t = titleController.text.trim();
                if (t.isEmpty) return;
                final mgr = ref.read(personPublicationsManagerProvider);
                await mgr.addStudentRequest(
                  personId: widget.person.id,
                  title: t,
                  notes: reminderNotesController.text.trim(),
                  targetDate: chosenDate,
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Salvar Pedido'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pubsAsync = ref.watch(personPublicationsStreamProvider);
    final allPubs = pubsAsync.value ?? [];
    final personPubs = allPubs.where((p) => p.personId == widget.person.id).toList();

    final placedPubs = personPubs.where((p) => p.itemType == 'entregue').toList();
    final requestedPubs = personPubs.where((p) => p.itemType == 'pedido').toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // SEÇÃO 1: PUBLICAÇÕES ENTREGUES / DEIXADAS
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_stories, color: AppTheme.primaryBlue, size: 20),
                  SizedBox(width: 8),
                  Text('Publicações Deixadas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.add_circle, color: AppTheme.primaryBlue),
                tooltip: 'Adicionar Outra Publicação',
                onPressed: _showAddCustomPlacedDialog,
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Toque para registrar rapidamente as publicações deixadas com a pessoa:',
            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 8),

          // Chips rápidos de publicações usuais
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ActionChip(
                avatar: const Icon(Icons.menu_book, size: 14),
                label: const Text('📖 Bíblia Sagrada (TNM)', style: TextStyle(fontSize: 11)),
                onPressed: () => _quickAddPlaced('Bíblia Sagrada (Tradução do Novo Mundo)'),
              ),
              ActionChip(
                avatar: const Icon(Icons.book, size: 14),
                label: const Text('📘 Brochura Seja Feliz', style: TextStyle(fontSize: 11)),
                onPressed: () => _quickAddPlaced('Brochura "Seja Feliz para Sempre!"'),
              ),
              ActionChip(
                avatar: const Icon(Icons.book_online, size: 14),
                label: const Text('📗 Livro Seja Feliz', style: TextStyle(fontSize: 11)),
                onPressed: () => _quickAddPlaced('Livro "Seja Feliz para Sempre!"'),
              ),
              ActionChip(
                avatar: const Icon(Icons.newspaper, size: 14),
                label: const Text('📰 A Sentinela (2018-2027)', style: TextStyle(fontSize: 11)),
                onPressed: _showSentinelasDialog,
              ),
              ActionChip(
                avatar: const Icon(Icons.alarm, size: 14),
                label: const Text('⏰ Despertai! (2018-2027)', style: TextStyle(fontSize: 11)),
                onPressed: _showDespertaisDialog,
              ),
              ActionChip(
                avatar: const Icon(Icons.description, size: 14),
                label: const Text('📄 Folhetos', style: TextStyle(fontSize: 11)),
                onPressed: _showFolhetosDialog,
              ),
              ActionChip(
                avatar: const Icon(Icons.edit_note, size: 14),
                label: const Text('✍️ Outra Publicação', style: TextStyle(fontSize: 11)),
                onPressed: _showAddCustomPlacedDialog,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Lista de publicações deixadas com histórico
          if (placedPubs.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'Nenhuma publicação registrada para ${widget.person.name}.\nToque em um dos botões acima para registrar.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                ),
              ),
            )
          else
            Column(
              children: placedPubs.map((p) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    dense: true,
                    leading: const Icon(Icons.check_circle, color: AppTheme.successGreen, size: 20),
                    title: Text(p.publicationTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text(
                      'Deixada em ${AppDateUtils.formatDate(p.date)}${p.notes != null && p.notes!.isNotEmpty ? " • ${p.notes}" : ""}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 16, color: Colors.grey),
                      tooltip: 'Remover',
                      onPressed: () async {
                        final mgr = ref.read(personPublicationsManagerProvider);
                        await mgr.deletePublication(p.id);
                      },
                    ),
                  ),
                );
              }).toList(),
            ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),

          // SEÇÃO 2: PEDIDOS DO ESTUDANTE & LEMBRETES
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.notification_important, color: AppTheme.accentTeal, size: 20),
                  SizedBox(width: 8),
                  Text('Pedidos & Lembretes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentTeal,
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Novo Pedido', style: TextStyle(fontSize: 11)),
                onPressed: _showAddRequestDialog,
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Lembretes para não esquecer de pedir no balcão e trazer na próxima visita:',
            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 10),

          if (requestedPubs.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'Nenhum pedido pendente para ${widget.person.name}.\nToque em "+ Novo Pedido" se o estudante pedir alguma publicação.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                ),
              ),
            )
          else
            Column(
              children: requestedPubs.map((p) {
                final isDone = p.status == 'entregue';
                final isSecured = p.status == 'conseguido';

                Color statusColor = const Color(0xFFD97706); // Âmbar
                String statusLabel = '⏳ Pedir no balcão';
                if (isSecured) {
                  statusColor = const Color(0xFF2563EB); // Azul
                  statusLabel = '📦 Conseguido / Levar';
                } else if (isDone) {
                  statusColor = AppTheme.successGreen;
                  statusLabel = '✅ Entregue';
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                p.publicationTitle,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  decoration: isDone ? TextDecoration.lineThrough : null,
                                ),
                              ),
                            ),
                            PopupMenuButton<String>(
                              initialValue: p.status,
                              tooltip: 'Alterar situação do pedido',
                              onSelected: (val) async {
                                final mgr = ref.read(personPublicationsManagerProvider);
                                await mgr.updatePublicationStatus(id: p.id, newStatus: val);
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'a_pedir', child: Text('⏳ A pedir no balcão')),
                                PopupMenuItem(value: 'conseguido', child: Text('📦 Conseguido / Levar na visita')),
                                PopupMenuItem(value: 'entregue', child: Text('✅ Entregue ao estudante')),
                              ],
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(statusLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
                              ),
                            ),
                          ],
                        ),
                        if (p.notes != null && p.notes!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.alarm, size: 14, color: AppTheme.accentTeal),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  p.notes!,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.accentTeal),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Previsão: ${AppDateUtils.formatDate(p.date)}', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 16, color: Colors.grey),
                              tooltip: 'Remover pedido',
                              onPressed: () async {
                                final mgr = ref.read(personPublicationsManagerProvider);
                                await mgr.deletePublication(p.id);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
