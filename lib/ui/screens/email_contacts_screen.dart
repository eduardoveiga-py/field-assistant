import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_logger.dart';
import '../../core/app_theme.dart';
import '../../inbox/email_contacts_manager.dart';
import '../../inbox/email_html_sanitizer.dart';
import '../providers.dart';

/// Tela CRUD completa de Contatos de E-mail para o Field Assistant.
/// Suporta pesquisa em tempo real, adição, edição, exclusão e seleção rápida para composição.
class EmailContactsScreen extends ConsumerStatefulWidget {
  final void Function(String email)? onSelectEmail;

  const EmailContactsScreen({super.key, this.onSelectEmail});

  @override
  ConsumerState<EmailContactsScreen> createState() =>
      _EmailContactsScreenState();
}

class _EmailContactsScreenState extends ConsumerState<EmailContactsScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<EmailContact> _allContacts = [];
  List<EmailContact> _filteredContacts = [];
  bool _isLoading = true;
  String? _selectedTag;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_applyFilter);
    _loadContacts();
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_applyFilter);
    _searchCtrl.dispose();
    super.dispose();
  }

  static String _normalize(String input) {
    var s = input.trim().toLowerCase();
    const withAccents = 'áàãâäéèêëíìîïóòõôöúùûüçñ';
    const withoutAccents = 'aaaaaeeeeiiiiooooouuuucn';
    for (int i = 0; i < withAccents.length; i++) {
      s = s.replaceAll(withAccents[i], withoutAccents[i]);
    }
    return s;
  }

  Future<void> _loadContacts() async {
    setState(() => _isLoading = true);
    try {
      final db = ref.read(repositoryProvider).db;
      final contacts = await EmailContactsManager.getAllSuggestions(db);
      if (!mounted) return;
      if (_selectedTag != null &&
          !EmailContactsManager.extractAllTags(contacts)
              .contains(_selectedTag)) {
        _selectedTag = null;
      }
      setState(() {
        _allContacts = contacts;
        _isLoading = false;
      });
      _applyFilter();
    } catch (e, st) {
      AppLogger.warning('Falha ao carregar contatos de e-mail', e, st);
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao carregar contatos: $e'),
          backgroundColor: AppTheme.alertRed,
        ),
      );
    }
  }

  void _applyFilter() {
    final query = _normalize(_searchCtrl.text);
    setState(() {
      _filteredContacts = _allContacts.where((c) {
        if (_selectedTag != null && !c.tags.contains(_selectedTag)) {
          return false;
        }
        if (query.isEmpty) return true;
        final nName = _normalize(c.name);
        final nEmail = _normalize(c.email);
        return nName.contains(query) ||
            nEmail.contains(query) ||
            c.tags.any((t) => _normalize(t).contains(query));
      }).toList();
    });
  }

  Future<void> _showAddOrEditDialog({EmailContact? existing}) async {
    final isEditing = existing != null;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => _AddOrEditContactDialog(
        existing: existing,
        allContacts: _allContacts,
        initialTags: existing?.tags ?? const [],
        availableTags: EmailContactsManager.extractAllTags(_allContacts),
        onSave:
            ({
              required String name,
              required String email,
              required List<String> tags,
            }) async {
              final db = ref.read(repositoryProvider).db;
              if (isEditing) {
                await EmailContactsManager.updateContact(
                  db,
                  oldEmail: existing.email,
                  newEmail: email,
                  name: name,
                  tags: tags,
                );
              } else {
                await EmailContactsManager.saveContact(
                  db,
                  email: email,
                  name: name,
                  source: 'manual',
                  tags: tags,
                );
              }
            },
      ),
    );

    if (saved == true) {
      await _loadContacts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEditing
                  ? 'Contato atualizado com sucesso!'
                  : 'Contato salvo com sucesso!',
            ),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteContact(EmailContact contact) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: const Text('Excluir contato?'),
        content: Text(
          'Deseja realmente remover o contato "${contact.name.isNotEmpty ? contact.name : contact.email}" (${contact.email})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('btn_confirm_delete_contact'),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.alertRed),
            onPressed: () => Navigator.pop(dlgCtx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final db = ref.read(repositoryProvider).db;
      await EmailContactsManager.deleteContact(db, contact.email);
      await _loadContacts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Contato "${contact.email}" removido.'),
            backgroundColor: AppTheme.alertAmber,
          ),
        );
      }
    }
  }

  void _handleSendEmail(EmailContact contact) {
    if (widget.onSelectEmail != null) {
      widget.onSelectEmail!(contact.email);
    }
    if (Navigator.canPop(context)) {
      Navigator.pop(context, contact.email);
    }
  }

  String _sourceLabel(String source) {
    switch (source) {
      case 'field_contact':
        return 'Ministério';
      case 'auto_sender':
        return 'Automático';
      case 'manual':
      default:
        return 'Manual';
    }
  }

  Color _sourceColor(String source) {
    switch (source) {
      case 'field_contact':
        return AppTheme.accentTeal;
      case 'auto_sender':
        return const Color(0xFF8B5CF6);
      case 'manual':
      default:
        return AppTheme.primaryBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final allTags = EmailContactsManager.extractAllTags(_allContacts);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contatos de E-mail'),
        actions: [
          IconButton(
            key: const Key('btn_add_contact'),
            icon: const Icon(Icons.person_add_alt_1_outlined),
            tooltip: 'Novo Contato',
            onPressed: () => _showAddOrEditDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de Pesquisa
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: TextField(
              key: const Key('search_contacts_field'),
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Pesquisar por nome, e-mail ou etiqueta...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          _applyFilter();
                        },
                      )
                    : null,
                isDense: true,
                filled: true,
                fillColor: isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          if (allTags.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      key: const Key('tag_filter_all'),
                      label: const Text('Todas'),
                      selected: _selectedTag == null,
                      onSelected: (_) {
                        _selectedTag = null;
                        _applyFilter();
                      },
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  for (final tag in allTags)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        key: ValueKey('tag_filter_$tag'),
                        label: Text(tag),
                        selected: _selectedTag == tag,
                        onSelected: (selected) {
                          _selectedTag = selected ? tag : null;
                          _applyFilter();
                        },
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
            ), // Lista de Contatos
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredContacts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.contacts_outlined,
                          size: 48,
                          color: isDark
                              ? const Color(0xFF475569)
                              : const Color(0xFF94A3B8),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _searchCtrl.text.isNotEmpty
                              ? 'Nenhum contato encontrado para "${_searchCtrl.text}".'
                              : _selectedTag != null
                              ? 'Nenhum contato encontrado na etiqueta "$_selectedTag".'
                              : 'Nenhum contato salvo ainda.',
                          style: TextStyle(
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : AppTheme.textMuted,
                            fontSize: 14,
                          ),
                        ),
                        if (_searchCtrl.text.isEmpty &&
                            _selectedTag == null &&
                            _allContacts.isEmpty) ...[
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: () => _showAddOrEditDialog(),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Cadastrar Primeiro Contato'),
                          ),
                        ] else if (_searchCtrl.text.isNotEmpty ||
                            _selectedTag != null) ...[
                          const SizedBox(height: 12),
                          TextButton.icon(
                            key: const Key('btn_clear_contact_filters'),
                            onPressed: () {
                              _searchCtrl.clear();
                              _selectedTag = null;
                              _applyFilter();
                            },
                            icon: const Icon(Icons.filter_alt_off, size: 18),
                            label: const Text('Limpar filtros'),
                          ),
                        ],
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _filteredContacts.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1, indent: 68, endIndent: 16),
                    itemBuilder: (ctx, index) {
                      final c = _filteredContacts[index];
                      final initials = EmailHtmlSanitizer.senderInitials(
                        c.displayName,
                      );
                      final color = _sourceColor(c.source);

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: color.withValues(alpha: 0.16),
                          foregroundColor: color,
                          child: Text(
                            initials,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                c.name.isNotEmpty ? c.name : c.email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _sourceLabel(c.source),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : AppTheme.textMuted,
                              ),
                            ),
                            if (c.tags.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: [
                                  for (final tag in c.tags)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        tag,
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              key: ValueKey('btn_send_email_${c.email}'),
                              icon: const Icon(
                                Icons.send_outlined,
                                size: 18,
                                color: AppTheme.primaryBlue,
                              ),
                              tooltip: 'Compor E-mail',
                              onPressed: () => _handleSendEmail(c),
                            ),
                            IconButton(
                              key: ValueKey('btn_edit_contact_${c.email}'),
                              icon: const Icon(
                                Icons.edit_outlined,
                                size: 18,
                                color: Colors.grey,
                              ),
                              tooltip: 'Editar Contato',
                              onPressed: () =>
                                  _showAddOrEditDialog(existing: c),
                            ),
                            IconButton(
                              key: ValueKey('btn_delete_contact_${c.email}'),
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: AppTheme.alertRed,
                              ),
                              tooltip: 'Excluir Contato',
                              onPressed: () => _confirmDeleteContact(c),
                            ),
                          ],
                        ),
                        onTap: () => _handleSendEmail(c),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _AddOrEditContactDialog extends StatefulWidget {
  final EmailContact? existing;
  final List<EmailContact> allContacts;
  final List<String> initialTags;
  final List<String> availableTags;
  final Future<void> Function({
    required String name,
    required String email,
    required List<String> tags,
  })
  onSave;

  const _AddOrEditContactDialog({
    required this.existing,
    required this.allContacts,
    required this.initialTags,
    required this.availableTags,
    required this.onSave,
  });

  @override
  State<_AddOrEditContactDialog> createState() =>
      _AddOrEditContactDialogState();
}

class _AddOrEditContactDialogState extends State<_AddOrEditContactDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _customTagCtrl;
  late final List<String> _selectedTags;

  static const List<String> _defaultTags = [
    'Congregação',
    'Família',
    'Anciãos',
    'Trabalho',
    'Pessoal',
  ];
  late final TextEditingController _emailCtrl;
  String? _errorText;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _emailCtrl = TextEditingController(text: widget.existing?.email ?? '');
    _customTagCtrl = TextEditingController();
    _selectedTags = List<String>.from(widget.initialTags);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _customTagCtrl.dispose();
    super.dispose();
  }

  void _addCustomTag() {
    final tag = _customTagCtrl.text.trim();
    if (tag.isEmpty) return;
    final allOptions = <String>{
      ..._defaultTags,
      ...widget.availableTags,
      ..._selectedTags,
    };
    final canonical = allOptions.firstWhere(
      (existing) => existing.toLowerCase() == tag.toLowerCase(),
      orElse: () => tag,
    );
    setState(() {
      if (!_selectedTags.contains(canonical)) {
        _selectedTags.add(canonical);
      }
      _customTagCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;

    final allTagOptions = <String>{
      ..._defaultTags,
      ...widget.availableTags,
      ..._selectedTags,
    }.toList();
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            isEditing ? Icons.edit_outlined : Icons.person_add_outlined,
            color: AppTheme.primaryBlue,
            size: 22,
          ),
          const SizedBox(width: 8),
          Text(isEditing ? 'Editar Contato' : 'Novo Contato'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_errorText != null) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.alertRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorText!,
                  style: const TextStyle(
                    color: AppTheme.alertRed,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              key: const Key('contact_name_field'),
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nome do Contato *',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('contact_email_field'),
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Endereço de E-mail *',
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Etiquetas',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: allTagOptions.map((tag) {
                final selected = _selectedTags.contains(tag);
                return FilterChip(
                  key: ValueKey('contact_dialog_tag_$tag'),
                  label: Text(tag),
                  selected: selected,
                  visualDensity: VisualDensity.compact,
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        if (!_selectedTags.contains(tag)) {
                          _selectedTags.add(tag);
                        }
                      } else {
                        _selectedTags.remove(tag);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('contact_custom_tag_field'),
                    controller: _customTagCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nova etiqueta',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _addCustomTag(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  key: const Key('btn_add_custom_tag'),
                  onPressed: _addCustomTag,
                  tooltip: 'Adicionar etiqueta',
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('btn_save_contact'),
          onPressed: _isSaving
              ? null
              : () async {
                  final name = _nameCtrl.text.trim();
                  final rawEmail = _emailCtrl.text.trim().toLowerCase();

                  if (name.isEmpty) {
                    setState(() => _errorText = 'Informe o nome do contato.');
                    return;
                  }

                  final emailRegex = RegExp(
                    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                  );
                  if (!emailRegex.hasMatch(rawEmail)) {
                    setState(
                      () =>
                          _errorText = 'Informe um endereço de e-mail válido.',
                    );
                    return;
                  }

                  // Previne duplicata por e-mail normalizado
                  final exists = widget.allContacts.any(
                    (c) =>
                        c.email.trim().toLowerCase() == rawEmail &&
                        (widget.existing == null ||
                            c.email.trim().toLowerCase() !=
                                widget.existing!.email.trim().toLowerCase()),
                  );
                  if (exists) {
                    setState(
                      () => _errorText =
                          'Já existe um contato com o e-mail $rawEmail.',
                    );
                    return;
                  }

                  if (_customTagCtrl.text.trim().isNotEmpty) {
                    _addCustomTag();
                  }

                  setState(() {
                    _isSaving = true;
                    _errorText = null;
                  });
                  try {
                    await widget.onSave(
                      name: name,
                      email: rawEmail,
                      tags: List<String>.from(_selectedTags),
                    );
                    if (context.mounted) {
                      Navigator.pop(context, true);
                    }
                  } catch (e, st) {
                    AppLogger.warning(
                      'Falha ao salvar contato de e-mail',
                      e,
                      st,
                    );
                    if (mounted) {
                      setState(() {
                        _isSaving = false;
                        _errorText = 'Erro ao salvar contato: $e';
                      });
                    }
                  }
                },
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Salvar'),
        ),
      ],
    );
  }
}
