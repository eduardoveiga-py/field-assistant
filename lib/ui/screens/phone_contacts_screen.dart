import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/app_theme.dart';
import '../../contacts/phone_contacts_manager.dart';
import '../../database/app_database.dart';
import '../providers.dart';
import 'person_detail_screen.dart';

class PhoneContactsScreen extends ConsumerStatefulWidget {
  const PhoneContactsScreen({super.key});

  @override
  ConsumerState<PhoneContactsScreen> createState() => _PhoneContactsScreenState();
}

class _PhoneContactsScreenState extends ConsumerState<PhoneContactsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'Todos'; // 'Todos', 'Apenas Telefônicos', 'Pessoas com Telefone', 'Com WhatsApp'
  String? _selectedTagFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _makePhoneCall(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp(String phone, {String? customText}) async {
    final clean = phone.replaceAll(RegExp(r'\D'), '');
    final textParam = customText != null ? '?text=${Uri.encodeComponent(customText)}' : '';
    final number = clean.startsWith('55') ? clean : '55$clean';
    final uri = Uri.parse('https://wa.me/$number$textParam');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _exportPdf(List<dynamic> combinedList) async {
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
                pw.Text('Lista de Contatos Telefônicos - Ministério Pessoal',
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                pw.Text('${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                    style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Text('Total de Contatos: ${combinedList.length}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
          pw.SizedBox(height: 14),
          pw.TableHelper.fromTextArray(
            headers: ['Nome', 'Telefone', 'WhatsApp / Redes', 'Origem / Situação', 'Observações / Tags'],
            data: combinedList.map((item) {
              if (item is PhoneContactItem) {
                final wa = item.hasWhatsApp ? 'Sim ${item.whatsAppInfo ?? ""}' : 'Não';
                final social = item.hasSocial ? '${item.socialPlatform ?? ""}: ${item.socialHandle ?? ""}' : '';
                final waSocial = [if (item.hasWhatsApp) 'WA: $wa', if (item.hasSocial) social].join('\n');
                final tagsStr = item.tags.isNotEmpty ? ' [${item.tags.join(", ")}]' : '';
                return [
                  item.name,
                  item.phone,
                  waSocial.isNotEmpty ? waSocial : '-',
                  '${item.origin} (Telefônico)',
                  '${item.notes ?? ""}$tagsStr',
                ];
              } else if (item is PersonEntry) {
                return [
                  item.name,
                  item.phone ?? '-',
                  'WhatsApp',
                  '${item.status.toUpperCase()} (Pessoas)',
                  item.address ?? '-',
                ];
              }
              return ['', '', '', '', ''];
            }).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellPadding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'contatos_telefonicos_ministerio.pdf',
    );
  }

  void _showAddEditPhoneContactDialog(BuildContext context, {PhoneContactItem? existing}) {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final phoneController = TextEditingController(text: existing?.phone ?? '');
    final secPhoneController = TextEditingController(text: existing?.secondaryPhone ?? '');
    bool hasWhatsApp = existing?.hasWhatsApp ?? false;
    final waInfoController = TextEditingController(text: existing?.whatsAppInfo ?? '');
    bool hasSocial = existing?.hasSocial ?? false;
    String selectedPlatform = existing?.socialPlatform ?? 'Instagram';
    final socialHandleController = TextEditingController(text: existing?.socialHandle ?? '');
    final notesController = TextEditingController(text: existing?.notes ?? '');
    final tagInputController = TextEditingController();
    List<String> tags = List.from(existing?.tags ?? []);
    String selectedOrigin = existing?.origin ?? 'Testemunho na Rua';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;

          return AlertDialog(
            title: Row(
              children: [
                Icon(existing != null ? Icons.edit : Icons.person_add_alt, color: AppTheme.primaryBlue),
                const SizedBox(width: 8),
                Text(existing != null ? 'Editar Contato Telefônico' : 'Novo Contato Telefônico'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cadastre contatos obtidos na rua, carrinho ou testemunho informal sem localização exata da casa.',
                    style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFCBD5E1) : AppTheme.textMuted),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Nome ou como conheceu *', hintText: 'Ex: Carlos do Ponto de Ônibus'),
                    autofocus: existing == null,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: phoneController,
                          decoration: const InputDecoration(labelText: 'Telefone Principal *', hintText: '(11) 98765-4321'),
                          keyboardType: TextInputType.phone,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: secPhoneController,
                          decoration: const InputDecoration(labelText: 'Telefone Recado / Fixo', hintText: '(11) 3333-2222'),
                          keyboardType: TextInputType.phone,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: selectedOrigin,
                    decoration: const InputDecoration(labelText: 'Origem do Contato'),
                    items: const [
                      DropdownMenuItem(value: 'Testemunho na Rua', child: Text('🚶 Testemunho na Rua / Praça')),
                      DropdownMenuItem(value: 'TPL / Carrinho', child: Text('🛒 TPL (Testemunho Público / Carrinho)')),
                      DropdownMenuItem(value: 'Testemunho Informal', child: Text('💬 Testemunho Informal')),
                      DropdownMenuItem(value: 'Telefone', child: Text('📞 Testemunho por Telefone')),
                      DropdownMenuItem(value: 'Outro', child: Text('📍 Outra Origem')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedOrigin = val);
                    },
                  ),
                  const SizedBox(height: 12),

                  // CHECKBOX WHATSAPP
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Tem WhatsApp?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('Habilita botão de conversa direta no WhatsApp', style: TextStyle(fontSize: 11)),
                    value: hasWhatsApp,
                    onChanged: (val) => setDialogState(() => hasWhatsApp = val ?? false),
                  ),
                  if (hasWhatsApp) ...[
                    TextField(
                      controller: waInfoController,
                      decoration: const InputDecoration(
                        labelText: 'Informações do WhatsApp (opcional)',
                        hintText: 'Ex: Mesmo número ou colar link do contato',
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // CHECKBOX OUTRAS REDES SOCIAIS
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Tem outras Redes Sociais?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('Instagram, Facebook, LinkedIn...', style: TextStyle(fontSize: 11)),
                    value: hasSocial,
                    onChanged: (val) => setDialogState(() => hasSocial = val ?? false),
                  ),
                  if (hasSocial) ...[
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedPlatform,
                            decoration: const InputDecoration(labelText: 'Rede'),
                            items: const [
                              DropdownMenuItem(value: 'Instagram', child: Text('Instagram')),
                              DropdownMenuItem(value: 'Facebook', child: Text('Facebook')),
                              DropdownMenuItem(value: 'LinkedIn', child: Text('LinkedIn')),
                              DropdownMenuItem(value: 'Telegram', child: Text('Telegram')),
                              DropdownMenuItem(value: 'Outra', child: Text('Outra')),
                            ],
                            onChanged: (val) {
                              if (val != null) setDialogState(() => selectedPlatform = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: socialHandleController,
                            decoration: const InputDecoration(labelText: '@usuario ou link', hintText: '@nome.sobrenome'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],

                  const SizedBox(height: 10),
                  // TAGS
                  const Text('Tags / Categorias:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                            hintText: 'Ex: jovem, interessado, bíblia',
                            isDense: true,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: AppTheme.primaryBlue),
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
                  const SizedBox(height: 10),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Observações do Contato',
                      hintText: 'Ex: Conversamos sobre o futuro. Pediu para mandar mensagem na quinta.',
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  final phone = phoneController.text.trim();
                  if (name.isEmpty || phone.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Por favor, informe ao menos o nome e o telefone.')),
                    );
                    return;
                  }

                  final mgr = ref.read(phoneContactsManagerProvider);
                  if (existing != null) {
                    await mgr.updatePhoneContact(PhoneContactItem(
                      id: existing.id,
                      name: name,
                      phone: phone,
                      secondaryPhone: secPhoneController.text.trim().isEmpty ? null : secPhoneController.text.trim(),
                      hasWhatsApp: hasWhatsApp,
                      whatsAppInfo: waInfoController.text.trim().isEmpty ? null : waInfoController.text.trim(),
                      hasSocial: hasSocial,
                      socialPlatform: hasSocial ? selectedPlatform : null,
                      socialHandle: hasSocial ? socialHandleController.text.trim() : null,
                      notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                      tags: tags,
                      origin: selectedOrigin,
                      convertedPersonId: existing.convertedPersonId,
                      createdAt: existing.createdAt,
                      updatedAt: DateTime.now(),
                    ));
                  } else {
                    await mgr.addPhoneContact(
                      name: name,
                      phone: phone,
                      secondaryPhone: secPhoneController.text.trim().isEmpty ? null : secPhoneController.text.trim(),
                      hasWhatsApp: hasWhatsApp,
                      whatsAppInfo: waInfoController.text.trim().isEmpty ? null : waInfoController.text.trim(),
                      hasSocial: hasSocial,
                      socialPlatform: hasSocial ? selectedPlatform : null,
                      socialHandle: hasSocial ? socialHandleController.text.trim() : null,
                      notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                      tags: tags,
                      origin: selectedOrigin,
                    );
                  }

                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(existing != null ? 'Contato atualizado!' : 'Contato telefônico salvo com sucesso!')),
                    );
                  }
                },
                child: const Text('Salvar'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showConvertToPersonDialog(BuildContext context, PhoneContactItem contact) {
    final addressController = TextEditingController();
    String selectedStatus = 'interessado';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.person_add, color: AppTheme.accentTeal),
                const SizedBox(width: 8),
                Expanded(child: Text('Promover: ${contact.name}')),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Você conseguiu o endereço da casa? Promova este contato para o cadastro completo de Pessoas para gerenciar revisitas, rotas e mapa.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: addressController,
                    decoration: const InputDecoration(
                      labelText: 'Endereço da Casa (Rua, Número, Bairro) *',
                      hintText: 'Ex: Rua das Palmeiras, 140 - Betânia',
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedStatus,
                    decoration: const InputDecoration(labelText: 'Situação Inicial'),
                    items: const [
                      DropdownMenuItem(value: 'interessado', child: Text('Interessado')),
                      DropdownMenuItem(value: 'revisita', child: Text('Revisita')),
                      DropdownMenuItem(value: 'estudo', child: Text('Estudo Bíblico')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedStatus = val);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentTeal, foregroundColor: Colors.white),
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Promover para Pessoas'),
                onPressed: () async {
                  final addr = addressController.text.trim();
                  if (addr.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Por favor, informe o endereço da casa.')),
                    );
                    return;
                  }

                  final repo = ref.read(repositoryProvider);
                  final mgr = ref.read(phoneContactsManagerProvider);

                  await mgr.convertToPerson(
                    contact: contact,
                    repo: repo,
                    address: addr,
                    status: selectedStatus,
                  );

                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('"${contact.name}" foi promovido com sucesso para a lista de Pessoas!')),
                    );
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final phoneContactsAsync = ref.watch(phoneContactsStreamProvider);
    final peopleAsync = ref.watch(peopleStreamProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final phoneContacts = phoneContactsAsync.value ?? [];
    final peopleWithPhone = (peopleAsync.value ?? []).where((p) => p.phone != null && p.phone!.trim().isNotEmpty && p.deletedAt == null).toList();

    // Extrai todas as tags existentes para filtro
    final allTags = <String>{};
    for (final c in phoneContacts) {
      allTags.addAll(c.tags);
    }

    final query = _searchController.text.trim().toLowerCase();

    // Filtra Contatos Telefônicos
    final filteredPhoneContacts = phoneContacts.where((c) {
      if (query.isNotEmpty) {
        final matches = c.name.toLowerCase().contains(query) ||
            c.phone.toLowerCase().contains(query) ||
            (c.notes ?? '').toLowerCase().contains(query) ||
            (c.socialHandle ?? '').toLowerCase().contains(query) ||
            c.tags.any((t) => t.toLowerCase().contains(query));
        if (!matches) return false;
      }
      if (_selectedFilter == 'Com WhatsApp' && !c.hasWhatsApp) return false;
      if (_selectedFilter == 'Pessoas com Telefone') return false;
      if (_selectedTagFilter != null && !c.tags.contains(_selectedTagFilter)) return false;
      return true;
    }).toList();

    // Filtra Pessoas com Telefone (quando o filtro permitir)
    final filteredPeople = peopleWithPhone.where((p) {
      if (_selectedFilter == 'Apenas Telefônicos') return false;
      if (query.isNotEmpty) {
        final matches = p.name.toLowerCase().contains(query) ||
            (p.phone ?? '').toLowerCase().contains(query) ||
            (p.address ?? '').toLowerCase().contains(query) ||
            (p.generalNotes ?? '').toLowerCase().contains(query);
        if (!matches) return false;
      }
      return true;
    }).toList();

    // Lista combinada
    final combinedItems = <dynamic>[];
    if (_selectedFilter != 'Pessoas com Telefone') {
      combinedItems.addAll(filteredPhoneContacts);
    }
    if (_selectedFilter != 'Apenas Telefônicos') {
      combinedItems.addAll(filteredPeople);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Telefones e Contatos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Exportar para PDF',
            onPressed: () => _exportPdf(combinedItems),
          ),
          IconButton(
            icon: const Icon(Icons.person_add_alt),
            tooltip: '+ Novo Contato Telefônico',
            onPressed: () => _showAddEditPhoneContactDialog(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_call),
        label: const Text('+ Contato Telefônico'),
        onPressed: () => _showAddEditPhoneContactDialog(context),
      ),
      body: Column(
        children: [
          // Banner Informativo
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: AppTheme.primaryBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Contatos apenas de telefone (rua/informal) não aparecem na aba Pessoas até você adicionar o endereço da casa.',
                    style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF)),
                  ),
                ),
              ],
            ),
          ),

          // Barra de Busca
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por nome, telefone, WhatsApp, @rede ou tag...',
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

          // Filtros
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                for (final f in ['Todos', 'Apenas Telefônicos', 'Pessoas com Telefone', 'Com WhatsApp'])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(f),
                      selected: _selectedFilter == f,
                      onSelected: (val) {
                        if (val) setState(() => _selectedFilter = f);
                      },
                      selectedColor: AppTheme.primaryBlue.withValues(alpha: 0.15),
                      checkmarkColor: AppTheme.primaryBlue,
                    ),
                  ),
                if (allTags.isNotEmpty) ...[
                  const VerticalDivider(width: 12),
                  for (final t in allTags)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text('#$t'),
                        selected: _selectedTagFilter == t,
                        onSelected: (val) {
                          setState(() => _selectedTagFilter = val ? t : null);
                        },
                        selectedColor: AppTheme.accentTeal.withValues(alpha: 0.2),
                      ),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Lista de Contatos
          Expanded(
            child: combinedItems.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.phone_disabled_outlined, size: 56, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            query.isEmpty
                                ? 'Nenhum contato encontrado.\nToque em "+ Contato Telefônico" para registrar pessoas da rua ou carrinho.'
                                : 'Nenhum contato coincide com a busca "$query".',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: isDark ? const Color(0xFFCBD5E1) : AppTheme.textMuted, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: combinedItems.length,
                    itemBuilder: (context, index) {
                      final item = combinedItems[index];

                      if (item is PhoneContactItem) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.12),
                                      child: Text(
                                        item.name.isNotEmpty ? item.name[0].toUpperCase() : '?',
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  item.name,
                                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.blueGrey.withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  '${item.origin} • Telefônico',
                                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(Icons.phone, size: 14, color: AppTheme.textMuted),
                                              const SizedBox(width: 4),
                                              Text(item.phone, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                              if (item.secondaryPhone != null && item.secondaryPhone!.isNotEmpty) ...[
                                                const SizedBox(width: 8),
                                                Text('• ${item.secondaryPhone!}', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                                              ],
                                            ],
                                          ),
                                          if (item.hasWhatsApp || item.hasSocial) ...[
                                            const SizedBox(height: 4),
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 4,
                                              children: [
                                                if (item.hasWhatsApp)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.green.withValues(alpha: 0.12),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Icon(Icons.chat, size: 12, color: Colors.green),
                                                        const SizedBox(width: 4),
                                                        Text('WhatsApp ${item.whatsAppInfo ?? ""}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
                                                      ],
                                                    ),
                                                  ),
                                                if (item.hasSocial && item.socialHandle != null)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.purple.withValues(alpha: 0.12),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Icon(Icons.alternate_email, size: 12, color: Colors.purple),
                                                        const SizedBox(width: 4),
                                                        Text('${item.socialPlatform}: ${item.socialHandle}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.purple)),
                                                      ],
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                if (item.notes != null && item.notes!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    item.notes!,
                                    style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFCBD5E1) : AppTheme.textDark),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                if (item.tags.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 4,
                                    children: item.tags.map((t) {
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
                                const Divider(height: 18),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        IconButton.outlined(
                                          icon: const Icon(Icons.call, size: 16, color: AppTheme.primaryBlue),
                                          tooltip: 'Ligar',
                                          visualDensity: VisualDensity.compact,
                                          onPressed: () => _makePhoneCall(item.phone),
                                        ),
                                        const SizedBox(width: 6),
                                        if (item.hasWhatsApp)
                                          IconButton.outlined(
                                            icon: const Icon(Icons.chat, size: 16, color: Colors.green),
                                            tooltip: 'Abrir no WhatsApp',
                                            visualDensity: VisualDensity.compact,
                                            onPressed: () => _openWhatsApp(item.phone),
                                          ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        if (item.convertedPersonId == null || item.convertedPersonId!.isEmpty)
                                          OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              visualDensity: VisualDensity.compact,
                                              foregroundColor: AppTheme.accentTeal,
                                              side: const BorderSide(color: AppTheme.accentTeal),
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            ),
                                            icon: const Icon(Icons.home, size: 14),
                                            label: const Text('Promover para Pessoas', style: TextStyle(fontSize: 11)),
                                            onPressed: () => _showConvertToPersonDialog(context, item),
                                          )
                                        else
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.green.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text('✓ Promovido para Pessoas', style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                                          ),
                                        const SizedBox(width: 6),
                                        PopupMenuButton<String>(
                                          padding: EdgeInsets.zero,
                                          onSelected: (val) async {
                                            if (val == 'edit') {
                                              _showAddEditPhoneContactDialog(context, existing: item);
                                            } else if (val == 'delete') {
                                              final mgr = ref.read(phoneContactsManagerProvider);
                                              await mgr.deletePhoneContact(item.id);
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('Contato telefônico removido.')),
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
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      } else if (item is PersonEntry) {
                        // CONTATO VINCULADO AO CADASTRO DE PESSOAS (COM IDENTIFICAÇÃO)
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: Colors.purple.withValues(alpha: 0.2)),
                          ),
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => PersonDetailScreen(personId: item.id)),
                              );
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: Colors.purple.withValues(alpha: 0.12),
                                        child: Text(
                                          item.name.isNotEmpty ? item.name[0].toUpperCase() : '?',
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    item.name,
                                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.purple.withValues(alpha: 0.12),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    '${item.status.toUpperCase()} • Cadastro Pessoas',
                                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.purple),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(item.phone ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (item.address != null && item.address!.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(Icons.home_outlined, size: 14, color: AppTheme.textMuted),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            item.address!,
                                            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  const Divider(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          IconButton.outlined(
                                            icon: const Icon(Icons.call, size: 16, color: AppTheme.primaryBlue),
                                            tooltip: 'Ligar',
                                            visualDensity: VisualDensity.compact,
                                            onPressed: () => _makePhoneCall(item.phone!),
                                          ),
                                          const SizedBox(width: 6),
                                          IconButton.outlined(
                                            icon: const Icon(Icons.chat, size: 16, color: Colors.green),
                                            tooltip: 'WhatsApp',
                                            visualDensity: VisualDensity.compact,
                                            onPressed: () => _openWhatsApp(item.phone!),
                                          ),
                                        ],
                                      ),
                                      TextButton.icon(
                                        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                        icon: const Icon(Icons.visibility, size: 14),
                                        label: const Text('Ver Perfil em Pessoas', style: TextStyle(fontSize: 11)),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(builder: (_) => PersonDetailScreen(personId: item.id)),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
