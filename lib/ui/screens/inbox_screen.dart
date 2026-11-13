import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../../core/app_logger.dart';
import '../../core/app_theme.dart';
import '../../database/app_database.dart';
import '../../inbox/inbox_manager.dart';
import '../../inbox/jw_email_service.dart';
import '../../research/research_manager.dart';
import '../../voice_notes/audio_recording_service.dart';
import '../providers.dart';
import 'settings_screen.dart';
import '../widgets/adaptive_ministry_sheet.dart';
import '../widgets/managed_text_controllers.dart';
import '../widgets/markdown_preview_text.dart';
import '../widgets/quick_capture_sheet.dart';
import '../widgets/rich_markdown_toolbar.dart';
import '../widgets/universal_attachment_viewer.dart';

/// Tela do Módulo A — Inbox Universal do Field Assistant.
/// Centraliza itens capturados com visualização em lista, reprodução de áudio,
/// visualização de anexos, e-mail teocrático JW.org (retenção permanente imune à purga de 90 dias),
/// correspondências restritas do Hub (com biometria) e pipeline de triagem/conversão sem perda de dados.
class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen>
    with SingleTickerProviderStateMixin {
  String _selectedFilter = 'unprocessed'; // unprocessed, in_review, converted, all
  late final AudioPlayerService _playerService;
  String? _currentlyPlayingPath;
  bool _isPlaying = false;

  late final TabController _tabController;
  final TextEditingController _emailSearchController = TextEditingController();
  String? _selectedEmailTag;
  bool _isSyncingEmails = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _playerService = RealAudioPlayerService();
    _playerService.playingStateStream.listen((isPlaying) {
      if (mounted) {
        setState(() {
          _isPlaying = isPlaying;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailSearchController.dispose();
    _playerService.dispose();
    super.dispose();
  }

  Future<void> _toggleAudio(String path) async {
    if (_currentlyPlayingPath == path && _isPlaying) {
      await _playerService.pause();
    } else {
      _currentlyPlayingPath = path;
      await _playerService.play(path);
    }
  }

  Future<void> _syncEmails() async {
    setState(() => _isSyncingEmails = true);
    try {
      final db = ref.read(repositoryProvider).db;
      final emailEntry = await (db.select(db.appKvStore)..where((t) => t.key.equals('jw_imap_email'))).getSingleOrNull();
      const secureStorage = FlutterSecureStorage();
      String? password = await secureStorage.read(key: 'jw_imap_password');
      if (password == null || password.isEmpty) {
        final legacyPass = await (db.select(db.appKvStore)..where((t) => t.key.equals('jw_imap_password'))).getSingleOrNull();
        password = legacyPass?.value;
      }
      final hostEntry = await (db.select(db.appKvStore)..where((t) => t.key.equals('jw_imap_host'))).getSingleOrNull();
      final portEntry = await (db.select(db.appKvStore)..where((t) => t.key.equals('jw_imap_port'))).getSingleOrNull();

      final host = (hostEntry?.value.trim().isNotEmpty == true) ? hostEntry!.value.trim() : 'mail.jw.org';
      final port = int.tryParse(portEntry?.value ?? '') ?? 993;
      final username = emailEntry?.value.trim();

      // Se a conta não estiver configurada, orienta o usuário com ação direta
      if (username == null || username.isEmpty || password == null || password.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Configure sua conta de e-mail teocrático em Configurações para sincronizar.'),
              action: SnackBarAction(
                label: 'Configurar',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
            ),
          );
        }
        return;
      }

      final emailService = ref.read(jwEmailServiceProvider);
      final count = await emailService.syncEmails(
        host: host,
        port: port,
        username: username,
        password: password,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              count > 0
                  ? '$count mensagem(ns) importada(s). O MIME original fica salvo; anexos ainda não abrem individualmente.'
                  : 'Nenhuma mensagem nova na caixa de entrada.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro na sincronização de e-mail: $e. Páginas já salvas foram preservadas; sincronize novamente.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncingEmails = false);
    }
  }

  Widget _buildLockedInboxScreen(bool isDark, dynamic biometric) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.fingerprint_rounded, size: 56, color: Color(0xFF6366F1)),
            ),
            const SizedBox(height: 20),
            const Text(
              'Área Protegida — Inbox & E-mails JW',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Todas as capturas, e-mails teocráticos permanentes e cartas do Hub estão protegidos por criptografia e biometria.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              icon: const Icon(Icons.lock_open, size: 18),
              label: const Text('Autenticar com Biometria / PIN', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () async {
                final authenticated = await biometric.authenticate(
                  context: context,
                  localizedReason: 'Confirme sua identidade para acessar a Inbox, cartas e e-mails.',
                );
                if (authenticated && mounted) {
                  setState(() {});
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inboxMgr = ref.watch(inboxManagerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final biometric = ref.watch(biometricAuthServiceProvider);
    final isUnlocked = biometric.isSessionUnlocked;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.all_inbox_rounded, color: AppTheme.primaryBlue, size: 24),
            SizedBox(width: 8),
            Text('Inbox & JW Mail', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          if (isUnlocked) ...[
            IconButton(
              tooltip: 'Bloquear Sessão da Inbox',
              icon: const Icon(Icons.lock, color: Colors.orangeAccent),
              onPressed: () {
                biometric.lockSession();
                setState(() {});
              },
            ),
            IconButton(
              tooltip: 'Sincronizar E-mails / Hub',
              icon: _isSyncingEmails
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.sync_alt, color: AppTheme.primaryBlue),
              onPressed: _isSyncingEmails ? null : _syncEmails,
            ),
            IconButton(
              tooltip: 'Nova Captura',
              icon: const Icon(Icons.add_circle_outline, color: AppTheme.primaryBlue),
              onPressed: () => QuickCaptureSheet.show(context),
            ),
          ],
        ],
        bottom: isUnlocked
            ? TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.inbox), text: 'Capturas'),
                  Tab(icon: Icon(Icons.mark_email_unread_outlined), text: 'JW Mail'),
                  Tab(icon: Icon(Icons.shield_outlined), text: 'Hub Restrito'),
                ],
              )
            : null,
      ),
      floatingActionButton: isUnlocked ? _buildFab() : null,
      body: isUnlocked
          ? TabBarView(
              controller: _tabController,
              children: [
                _buildCapturesTab(inboxMgr, isDark),
                _buildJwMailTab(isDark),
                _buildHubRestrictedTab(isDark),
              ],
            )
          : _buildLockedInboxScreen(isDark, biometric),
    );
  }

  Widget? _buildFab() {
    return FloatingActionButton.extended(
      onPressed: () {
        if (_tabController.index == 1) {
          _showNewDraftDialog();
        } else {
          QuickCaptureSheet.show(context);
        }
      },
      backgroundColor: AppTheme.primaryBlue,
      foregroundColor: Colors.white,
      icon: Icon(_tabController.index == 1 ? Icons.edit_note : Icons.bolt_rounded),
      label: Text(
        _tabController.index == 1 ? 'Novo Rascunho' : 'Captura Rápida',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildCapturesTab(InboxManager inboxMgr, bool isDark) {
    return Column(
      children: [
        // Filtros de Status
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('unprocessed', 'Pendentes', Icons.hourglass_top),
                const SizedBox(width: 8),
                _buildFilterChip('in_review', 'Em Análise', Icons.rate_review),
                const SizedBox(width: 8),
                _buildFilterChip('converted', 'Processadas', Icons.task_alt),
                const SizedBox(width: 8),
                _buildFilterChip('all', 'Todas', Icons.list_alt),
              ],
            ),
          ),
        ),
        const Divider(height: 1),

        // Lista de Entradas Reativa
        Expanded(
          child: StreamBuilder<List<InboxEntry>>(
            stream: inboxMgr.watchEntries(
              statusFilter: _selectedFilter == 'all' ? null : _selectedFilter,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final entries = snapshot.data ?? [];
              if (entries.isEmpty) {
                return _buildEmptyState(isDark);
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: entries.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) => _buildEntryCard(entries[i], isDark),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String key, String label, IconData icon) {
    final isSelected = _selectedFilter == key;
    return ChoiceChip(
      avatar: Icon(icon, size: 14, color: isSelected ? Colors.white : AppTheme.primaryBlue),
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) setState(() => _selectedFilter = key);
      },
      selectedColor: AppTheme.primaryBlue,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : null,
        fontSize: 13,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
            ),
            const SizedBox(height: 16),
            Text(
              _selectedFilter == 'unprocessed'
                  ? 'Nenhum item pendente no Inbox!'
                  : 'Nenhum registro encontrado neste filtro.',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Use a Captura Rápida a qualquer momento para guardar ideias sem interromper o que estiver fazendo.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryCard(InboxEntry entry, bool isDark) {
    final isAudio = entry.sourceType == 'audio' && entry.mediaPath != null;
    final isPlayingThisAudio = _currentlyPlayingPath == entry.mediaPath && _isPlaying;
    final attachmentsList = _parseJsonList(entry.attachments);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Linha do Cabeçalho: Tipo + Categoria + Ações Rápidas
            Row(
              children: [
                _buildSourceBadge(entry.sourceType),
                const SizedBox(width: 8),
                if (entry.suggestedCategory != null && entry.suggestedCategory!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _categoryLabel(entry.suggestedCategory!),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.primaryBlue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const Spacer(),
                Text(
                  _formatDate(entry.capturedAt),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (val) => _handleCardMenuAction(val, entry),
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_note, size: 18, color: AppTheme.primaryBlue),
                          SizedBox(width: 8),
                          Text('Editar Captura'),
                        ],
                      ),
                    ),
                    if (entry.status == 'unprocessed')
                      const PopupMenuItem(
                        value: 'in_review',
                        child: Row(
                          children: [
                            Icon(Icons.rate_review, size: 18, color: Colors.amber),
                            SizedBox(width: 8),
                            Text('Marcar Em Análise'),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'archive',
                      child: Row(
                        children: [
                          Icon(Icons.archive_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Arquivar'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'export',
                      child: Row(
                        children: [
                          Icon(Icons.download_rounded, size: 18, color: Colors.blueAccent),
                          SizedBox(width: 8),
                          Text('Exportar Item'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                          SizedBox(width: 8),
                          Text('Excluir', style: TextStyle(color: Colors.redAccent)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Conteúdo textual
            MarkdownPreviewText(
              text: entry.content,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
              ),
            ),

            // Player de Áudio incorporado
            if (isAudio) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        isPlayingThisAudio ? Icons.pause_circle_filled : Icons.play_circle_fill,
                        color: AppTheme.primaryBlue,
                        size: 32,
                      ),
                      onPressed: () => _toggleAudio(entry.mediaPath!),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Áudio gravado (${entry.mediaDurationSeconds ?? 0}s)',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],

            // Anexos
            if (attachmentsList.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: attachmentsList.map((att) {
                  final name = att['name']?.toString() ?? 'Arquivo';
                  final type = att['type']?.toString() ?? 'file';
                  return ActionChip(
                    avatar: Icon(
                      type == 'image' ? Icons.image : Icons.attach_file,
                      size: 14,
                      color: AppTheme.primaryBlue,
                    ),
                    label: Text(
                      name,
                      style: const TextStyle(fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: () {
                      final path = att['path']?.toString() ?? entry.mediaPath ?? '';
                      showUniversalAttachmentViewer(context, filePath: path, title: name, fileType: type);
                    },
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Botões de Conversão Não-Destrutiva
            if (entry.status != 'converted')
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildConvertButton(
                      label: 'Virar Tarefa',
                      icon: Icons.check_circle_outline,
                      color: const Color(0xFF10B981),
                      onTap: () => _showConvertToTaskDialog(entry),
                    ),
                    const SizedBox(width: 8),
                    _buildConvertButton(
                      label: 'Virar Projeto',
                      icon: Icons.folder_special_outlined,
                      color: const Color(0xFF3B82F6),
                      onTap: () => _showConvertToProjectDialog(entry),
                    ),
                    const SizedBox(width: 8),
                    _buildConvertButton(
                      label: 'Virar Nota',
                      icon: Icons.note_add_outlined,
                      color: const Color(0xFF8B5CF6),
                      onTap: () => _showConvertToNoteDialog(entry),
                    ),
                    const SizedBox(width: 8),
                    _buildConvertButton(
                      label: 'Virar Pergunta',
                      icon: Icons.help_outline,
                      color: const Color(0xFFF59E0B),
                      onTap: () => _showConvertToQuestionDialog(entry),
                    ),
                  ],
                ),
              )
            else
              Row(
                children: [
                  const Icon(Icons.check_circle, size: 16, color: Colors.green),
                  const SizedBox(width: 6),
                  Text(
                    'Convertido em ${_entityTypeLabel(entry.convertedEntityType ?? '')}',
                    style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceBadge(String sourceType) {
    IconData icon;
    Color color;
    String label;

    switch (sourceType) {
      case 'audio':
        icon = Icons.mic;
        color = Colors.redAccent;
        label = 'Áudio';
        break;
      case 'image':
        icon = Icons.image;
        color = Colors.purpleAccent;
        label = 'Foto';
        break;
      case 'file':
        icon = Icons.attach_file;
        color = Colors.orangeAccent;
        label = 'Arquivo';
        break;
      default:
        icon = Icons.edit_note;
        color = AppTheme.primaryBlue;
        label = 'Ideia';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildConvertButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // DIÁLOGOS DE CONVERSÃO RÁPIDA
  // ==========================================

  void _showConvertToTaskDialog(InboxEntry entry) {
    String priority = 'normal';
    String category = entry.suggestedCategory ?? 'ministry';
    DateTime? dueDate;

    showAdaptiveMinistrySheet(
      context: context,
      title: 'Converter em Tarefa',
      titleLeading: const Icon(Icons.check_circle_outline, color: Color(0xFF10B981)),
      builder: (ctx, scroll) => ManagedTextControllers(
        initialTexts: [entry.content, ''],
        builder: (ctx, ctrls) {
          final titleCtrl = ctrls[0];
          final descCtrl = ctrls[1];

          return StatefulBuilder(
            builder: (ctx, setModalState) {
              return SingleChildScrollView(
                controller: scroll,
                physics: const ClampingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Título da Tarefa',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: priority,
                              decoration: const InputDecoration(labelText: 'Prioridade', border: OutlineInputBorder()),
                              items: const [
                                DropdownMenuItem(value: 'low', child: Text('Baixa')),
                                DropdownMenuItem(value: 'normal', child: Text('Normal')),
                                DropdownMenuItem(value: 'high', child: Text('Alta')),
                                DropdownMenuItem(value: 'urgent', child: Text('Urgente')),
                              ],
                              onChanged: (v) => setModalState(() => priority = v ?? 'normal'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: category,
                              decoration: const InputDecoration(labelText: 'Categoria', border: OutlineInputBorder()),
                              items: const [
                                DropdownMenuItem(value: 'ministry', child: Text('Ministério')),
                                DropdownMenuItem(value: 'personal', child: Text('Pessoal')),
                                DropdownMenuItem(value: 'study', child: Text('Estudo')),
                              ],
                              onChanged: (v) => setModalState(() => category = v ?? 'ministry'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        title: Text(dueDate == null ? 'Definir Data de Vencimento' : 'Vencimento: ${_formatDate(dueDate!)}'),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now().subtract(const Duration(days: 30)),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) setModalState(() => dueDate = picked);
                        },
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () async {
                          final title = titleCtrl.text.trim().isEmpty ? entry.content : titleCtrl.text.trim();
                          final desc = descCtrl.text.trim();
                          final inboxMgr = ref.read(inboxManagerProvider);
                          await inboxMgr.convertToTask(
                            entry.id,
                            title: title,
                            description: desc.isNotEmpty ? desc : null,
                            priority: priority,
                            category: category,
                            dueDate: dueDate,
                          );
                          if (ctx.mounted) {
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('Tarefa criada com sucesso!')),
                            );
                          }
                        },
                        child: const Text('Confirmar Conversão em Tarefa', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showConvertToProjectDialog(InboxEntry entry) {
    String category = entry.suggestedCategory ?? 'ministry';

    showAdaptiveMinistrySheet(
      context: context,
      title: 'Converter em Projeto',
      titleLeading: const Icon(Icons.folder_special_outlined, color: Color(0xFF3B82F6)),
      builder: (ctx, scroll) => ManagedTextControllers(
        initialTexts: [entry.content, ''],
        builder: (ctx, ctrls) {
          final nameCtrl = ctrls[0];
          final objCtrl = ctrls[1];

          return SingleChildScrollView(
            controller: scroll,
            physics: const ClampingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Nome do Projeto', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: objCtrl,
                    decoration: const InputDecoration(labelText: 'Objetivo Principal', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () async {
                      final name = nameCtrl.text.trim().isEmpty ? entry.content : nameCtrl.text.trim();
                      final obj = objCtrl.text.trim();
                      final inboxMgr = ref.read(inboxManagerProvider);
                      await inboxMgr.convertToProject(
                        entry.id,
                        name: name,
                        objective: obj.isNotEmpty ? obj : null,
                        category: category,
                      );
                      if (ctx.mounted) {
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Projeto criado com sucesso!')),
                        );
                      }
                    },
                    child: const Text('Confirmar Conversão em Projeto', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showConvertToNoteDialog(InboxEntry entry) {
    final initTitle = entry.content.length > 40 ? '${entry.content.substring(0, 40)}...' : entry.content;

    showAdaptiveMinistrySheet(
      context: context,
      title: 'Converter em Nota de Conhecimento',
      titleLeading: const Icon(Icons.note_add_outlined, color: Color(0xFF8B5CF6)),
      builder: (ctx, scroll) => ManagedTextControllers(
        initialTexts: [initTitle, entry.content],
        builder: (ctx, ctrls) {
          final titleCtrl = ctrls[0];
          final contentCtrl = ctrls[1];

          return SingleChildScrollView(
            controller: scroll,
            physics: const ClampingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: 'Título da Nota', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contentCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Conteúdo', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () async {
                      final title = titleCtrl.text.trim().isEmpty ? 'Nova Nota' : titleCtrl.text.trim();
                      final content = contentCtrl.text.trim();
                      final inboxMgr = ref.read(inboxManagerProvider);
                      await inboxMgr.convertToNote(
                        entry.id,
                        title: title,
                        content: content,
                      );
                      if (ctx.mounted) {
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Nota salva na Base de Conhecimento!')),
                        );
                      }
                    },
                    child: const Text('Confirmar Conversão em Nota', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showConvertToQuestionDialog(InboxEntry entry) {
    showAdaptiveMinistrySheet(
      context: context,
      title: 'Converter em Dúvida Teocrática',
      titleLeading: const Icon(Icons.help_outline, color: Color(0xFFF59E0B)),
      builder: (ctx, scroll) => ManagedTextControllers(
        initialTexts: [entry.content],
        builder: (ctx, ctrls) {
          final qCtrl = ctrls[0];

          return SingleChildScrollView(
            controller: scroll,
            physics: const ClampingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: qCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Pergunta ou Assunto Bíblico',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () async {
                      final qText = qCtrl.text.trim().isEmpty ? entry.content : qCtrl.text.trim();
                      final inboxMgr = ref.read(inboxManagerProvider);
                      await inboxMgr.convertToQuestion(
                        entry.id,
                        question: qText,
                      );
                      if (ctx.mounted) {
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Dúvida registrada para pesquisa bíblica!')),
                        );
                      }
                    },
                    child: const Text('Confirmar Conversão em Dúvida', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _handleCardMenuAction(String action, InboxEntry entry) async {
    final inboxMgr = ref.read(inboxManagerProvider);
    if (action == 'edit') {
      _showEditInboxEntryModal(entry);
    } else if (action == 'in_review') {
      await inboxMgr.markInReview(entry.id);
    } else if (action == 'archive') {
      await inboxMgr.archiveEntry(entry.id);
    } else if (action == 'delete') {
      await inboxMgr.softDeleteEntry(entry.id);
    } else if (action == 'export') {
      _showExportInboxModal(entry);
    }
  }

  void _showEditInboxEntryModal(InboxEntry entry) {
    String? category = entry.suggestedCategory;

    showAdaptiveMinistrySheet(
      context: context,
      title: 'Editar Captura',
      titleLeading: const Icon(Icons.edit_note, color: AppTheme.primaryBlue),
      builder: (ctx, scroll) => ManagedTextControllers(
        initialTexts: [entry.content],
        builder: (ctx, ctrls) {
          final contentCtrl = ctrls[0];

          return StatefulBuilder(
            builder: (ctx, setModalState) {
              return SingleChildScrollView(
                controller: scroll,
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    RichMarkdownToolbar(controller: contentCtrl),
                    const SizedBox(height: 8),
                    TextField(
                      controller: contentCtrl,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Conteúdo da Captura (Markdown e Imagens)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: const InputDecoration(
                        labelText: 'Categoria Sugerida',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('Sem categoria')),
                        DropdownMenuItem(value: 'ministry', child: Text('Ministério')),
                        DropdownMenuItem(value: 'personal', child: Text('Pessoal')),
                        DropdownMenuItem(value: 'study', child: Text('Estudo')),
                        DropdownMenuItem(value: 'question', child: Text('Dúvida')),
                        DropdownMenuItem(value: 'idea', child: Text('Ideia')),
                      ],
                      onChanged: (v) => setModalState(() => category = v),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () async {
                        final updated = contentCtrl.text.trim();
                        if (updated.isEmpty) return;
                        final inboxMgr = ref.read(inboxManagerProvider);
                        await inboxMgr.updateEntry(
                          entry.id,
                          content: updated,
                          suggestedCategory: category,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Captura atualizada com sucesso!')),
                          );
                        }
                      },
                      child: const Text('Salvar Alterações', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ==========================================
  // FORMATAÇÃO E AUXILIARES
  // ==========================================

  List<Map<String, dynamic>> _parseJsonList(String jsonString) {
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is List) {
        return decoded.whereType<Map<String, dynamic>>().toList();
      }
    } catch (e, st) {
      AppLogger.debug('Falha ao parsear lista JSON no Inbox: $e', st);
    }
    return [];
  }

  String _categoryLabel(String cat) {
    switch (cat) {
      case 'ministry':
        return 'Ministério';
      case 'personal':
        return 'Pessoal';
      case 'study':
        return 'Estudo';
      case 'question':
        return 'Dúvida';
      case 'idea':
        return 'Ideia';
      default:
        return cat;
    }
  }

  String _entityTypeLabel(String entity) {
    switch (entity) {
      case 'task':
        return 'Tarefa';
      case 'project':
        return 'Projeto';
      case 'note':
        return 'Nota';
      case 'question':
        return 'Dúvida Teocrática';
      default:
        return entity;
    }
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Agora';
    if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'há ${diff.inHours}h';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  // ==========================================
  // EXPORTAÇÃO DINÂMICA
  // ==========================================

  void _showExportInboxModal(InboxEntry entry) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.download_rounded, color: AppTheme.primaryBlue),
                  SizedBox(width: 8),
                  Text(
                    'Exportar Item do Inbox',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Escolha o formato para exportar e baixar ou copiar o conteúdo:',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEFF6FF),
                  child: Icon(Icons.code, color: Color(0xFF3B82F6)),
                ),
                title: const Text('Markdown (.md)'),
                subtitle: const Text('Formatado com cabeçalho, pronto para documentação'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await ref.read(jwEmailServiceProvider).exportInboxEntry(entry, format: 'markdown');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Nota copiada e arquivo Markdown gerado!')),
                    );
                  }
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFF0FDF4),
                  child: Icon(Icons.text_snippet, color: Color(0xFF10B981)),
                ),
                title: const Text('Texto Simples (.txt)'),
                subtitle: const Text('Copia texto puro e baixa arquivo .txt'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await ref.read(jwEmailServiceProvider).exportInboxEntry(entry, format: 'text');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Nota copiada em texto puro!')),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showExportEmailModal(JwEmailMessage msg) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.forward_to_inbox, color: AppTheme.primaryBlue),
                  SizedBox(width: 8),
                  Text(
                    'Exportar Correspondência / E-mail',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Escolha o formato desejado para salvar no disco ou copiar:',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEFF6FF),
                  child: Icon(Icons.code, color: Color(0xFF3B82F6)),
                ),
                title: const Text('Markdown (.md)'),
                subtitle: const Text('Metadados teocráticos e corpo formatado em Markdown'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await ref.read(jwEmailServiceProvider).exportEmail(msg, format: 'markdown');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('E-mail copiado e arquivo Markdown baixado!')),
                    );
                  }
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFEF3C7),
                  child: Icon(Icons.mail_outline, color: Color(0xFFD97706)),
                ),
                title: const Text('Formato Padrão RFC822 / E-mail (.eml)'),
                subtitle: const Text('Compatível com clientes de e-mail e arquivos oficiais'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await ref.read(jwEmailServiceProvider).exportEmail(msg, format: 'eml');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Arquivo .eml gerado com sucesso!')),
                    );
                  }
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFF0FDF4),
                  child: Icon(Icons.text_snippet, color: Color(0xFF10B981)),
                ),
                title: const Text('Texto Puro (.txt)'),
                subtitle: const Text('Copia para a área de transferência e baixa .txt'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await ref.read(jwEmailServiceProvider).exportEmail(msg, format: 'text');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Conteúdo copiado em texto puro!')),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // ABA: JW MAIL (RETENÇÃO PERMANENTE)
  // ==========================================

  Widget _buildJwMailTab(bool isDark) {
    final emailService = ref.watch(jwEmailServiceProvider);

    return Column(
      children: [
        // Banner do Motor de Retenção Permanente
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFBFDBFE),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.security_rounded, size: 24, color: Color(0xFF2563EB)),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Retenção Permanente Ativa',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1D4ED8)),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Correspondências salvas localmente nunca expiram após os 90 dias do servidor.',
                      style: TextStyle(fontSize: 11, color: Colors.blueGrey),
                    ),
                  ],
                ),
              ),
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                onPressed: _isSyncingEmails ? null : _syncEmails,
                child: Text(_isSyncingEmails ? '...' : 'Sincronizar', style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),

        // Barra de Busca
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            controller: _emailSearchController,
            decoration: InputDecoration(
              hintText: 'Pesquisar e-mails, assuntos, remetente ou tags...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _emailSearchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _emailSearchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true,
            ),
            onChanged: (val) => setState(() {}),
          ),
        ),

        // Chips de Filtro por Tag
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Todos'),
                  selected: _selectedEmailTag == null,
                  onSelected: (sel) {
                    if (sel) setState(() => _selectedEmailTag = null);
                  },
                ),
                const SizedBox(width: 6),
                ...['assembleia', 'circuito', 'cartas', 'broadcasting', 'notícias'].map((tag) {
                  final isSel = _selectedEmailTag == tag;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text('#$tag'),
                      selected: isSel,
                      onSelected: (sel) {
                        setState(() => _selectedEmailTag = sel ? tag : null);
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        const Divider(height: 1),

        // Lista Reativa de E-mails
        Expanded(
          child: StreamBuilder<List<JwEmailMessage>>(
            stream: emailService.watchRetainedEmails(
              hubOnly: false,
              tagFilter: _selectedEmailTag,
              searchQuery: _emailSearchController.text,
            ),
            builder: (ctx, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final emails = snapshot.data ?? [];
              if (emails.isEmpty) {
                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.mark_email_unread_outlined, size: 52, color: Colors.grey.shade400),
                        const SizedBox(height: 14),
                        const Text(
                          'Nenhuma correspondência teocrática retida',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Conecte sua conta IMAP em Configurações para importar mensagens da caixa de entrada. O MIME original é salvo localmente, mas anexos ainda não podem ser abertos individualmente. Mantenha um backup de e-mail.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
                        ),
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                                );
                              },
                              icon: const Icon(Icons.settings_outlined, size: 18),
                              label: const Text('Configurar E-mail'),
                            ),
                            FilledButton.icon(
                              onPressed: _syncEmails,
                              icon: const Icon(Icons.sync, size: 18),
                              label: const Text('Sincronizar Agora'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: emails.length,
                separatorBuilder: (c, i) => const SizedBox(height: 10),
                itemBuilder: (c, i) => _buildEmailCard(emails[i], isDark, isHub: false),
              );
            },
          ),
        ),
      ],
    );
  }

  // ==========================================
  // ABA: HUB RESTRITO (TRAVA BIOMÉTRICA)
  // ==========================================

  Widget _buildHubRestrictedTab(bool isDark) {
    final biometric = ref.watch(biometricAuthServiceProvider);
    final isUnlocked = biometric.isSessionUnlocked;

    if (!isUnlocked) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.fingerprint_rounded, size: 56, color: Color(0xFF6366F1)),
              ),
              const SizedBox(height: 20),
              const Text(
                'Área Restrita — Hub JW.org',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Cartas ao Corpo de Anciãos, comunicados confidenciais e formulários teocráticos são protegidos por criptografia e biometria.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                icon: const Icon(Icons.lock_open, size: 18),
                label: const Text('Autenticar com Biometria / PIN', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () async {
                  final authenticated = await biometric.authenticate(
                    context: context,
                    localizedReason: 'Confirme sua identidade para acessar as cartas e formulários do Hub.',
                  );
                  if (authenticated && mounted) {
                    setState(() {});
                  }
                },
              ),
            ],
          ),
        ),
      );
    }

    final emailService = ref.watch(jwEmailServiceProvider);

    return Column(
      children: [
        // Status da Sessão Desbloqueada
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              const Icon(Icons.verified_user, size: 20, color: Color(0xFF10B981)),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Sessão Desbloqueada (Hub.jw.org)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF047857),
                  ),
                ),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                icon: const Icon(Icons.lock, size: 16),
                label: const Text('Bloquear', style: TextStyle(fontSize: 12)),
                onPressed: () {
                  biometric.lockSession();
                  setState(() {});
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Lista de Cartas e Formulários do Hub
        Expanded(
          child: StreamBuilder<List<JwEmailMessage>>(
            stream: emailService.watchRetainedEmails(
              hubOnly: true,
              searchQuery: _emailSearchController.text,
            ),
            builder: (ctx, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final letters = snapshot.data ?? [];
              if (letters.isEmpty) {
                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_outline, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text(
                          'Nenhuma correspondência restrita do Hub',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Cartas do corpo de anciãos e formulários oficiais sincronizados pelo IMAP serão armazenados aqui sob proteção biométrica.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: letters.length,
                separatorBuilder: (c, i) => const SizedBox(height: 10),
                itemBuilder: (c, i) => _buildEmailCard(letters[i], isDark, isHub: true),
              );
            },
          ),
        ),
      ],
    );
  }

  // ==========================================
  // CARD DE E-MAIL / CARTA
  // ==========================================

  Widget _buildEmailCard(JwEmailMessage msg, bool isDark, {bool isHub = false}) {
    final badgeColor = isHub
        ? (msg.hubType == 'form' ? const Color(0xFF8B5CF6) : const Color(0xFFEF4444))
        : (msg.isDraft ? Colors.amber : const Color(0xFF3B82F6));
    final badgeLabel = isHub
        ? (msg.hubType == 'form' ? 'FORMULÁRIO HUB' : 'CARTA DO CORPO')
        : (msg.isDraft ? 'RASCUNHO' : 'JW MAIL');

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _showEmailDetailsModal(context, msg),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Topo: Badge + De + Data + Menu
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badgeLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: badgeColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Tooltip(
                  message: 'Retenção Permanente (não expira após 90 dias)',
                  child: Icon(Icons.shield_rounded, size: 14, color: Color(0xFF10B981)),
                ),
                const Spacer(),
                Text(
                  _formatDate(msg.date),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18),
                  onSelected: (val) {
                    if (val == 'export') {
                      _showExportEmailModal(msg);
                    } else if (val == 'to_task') {
                      _convertEmailToTask(msg);
                    } else if (val == 'to_research') {
                      _convertEmailToResearch(msg);
                    }
                  },
                  itemBuilder: (ctx) => const [
                    PopupMenuItem(
                      value: 'export',
                      child: Row(
                        children: [
                          Icon(Icons.download_rounded, size: 18, color: Colors.blueAccent),
                          SizedBox(width: 8),
                          Text('Exportar (.md / .eml)'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'to_task',
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline, size: 18, color: Colors.green),
                          SizedBox(width: 8),
                          Text('Virar Tarefa'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'to_research',
                      child: Row(
                        children: [
                          Icon(Icons.menu_book, size: 18, color: Colors.purple),
                          SizedBox(width: 8),
                          Text('Virar Artigo de Pesquisa'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Remetente
            Text(
              'De: ${msg.from}',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 4),

            // Assunto
            Text(
              msg.subject,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 6),

            // Trecho do Corpo
            Text(
              msg.bodyText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 10),

            // Tags e Anexos
            Row(
              children: [
                if (msg.attachments.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.attach_file, size: 12, color: Colors.blueGrey),
                        const SizedBox(width: 4),
                        Text(
                          '${msg.attachments.length} anexo(s)',
                          style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
                        ),
                      ],
                    ),
                  ),
                ...msg.tags.take(3).map((tag) => Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '#$tag',
                        style: const TextStyle(fontSize: 10, color: AppTheme.primaryBlue),
                      ),
                    )),
                const Spacer(),
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: () => _showEmailDetailsModal(context, msg),
                  child: const Text('Ler Detalhes', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // MODAL DE DETALHES DE E-MAIL / CARTA
  // ==========================================

  void _showEmailDetailsModal(BuildContext context, JwEmailMessage msg) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.90,
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Barra Superior do Modal
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        msg.subject,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Metadados
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.shield_outlined, size: 14, color: Color(0xFF10B981)),
                          const SizedBox(width: 6),
                          const Text(
                            'Retido Permanentemente (Protegido contra exclusão de 90 dias)',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('De: ${msg.from}', style: const TextStyle(fontSize: 12)),
                      Text('Para: ${msg.to}', style: const TextStyle(fontSize: 12)),
                      Text('Data: ${msg.date.day}/${msg.date.month}/${msg.date.year} às ${msg.date.hour}:${msg.date.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontSize: 12)),
                      if (msg.tags.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('Tags: ${msg.tags.map((t) => "#$t").join(" ")}',
                            style: const TextStyle(fontSize: 12, color: AppTheme.primaryBlue)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Corpo
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText(
                          msg.bodyText,
                          style: const TextStyle(fontSize: 14, height: 1.5),
                        ),
                        if (msg.attachments.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          const Text('Anexos:', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          ...msg.attachments.map((att) {
                            final name = att['name']?.toString() ?? 'anexo';
                            final path = att['path'] as String? ?? name;
                            final type = att['type'] as String? ?? 'pdf';
                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.attach_file, color: AppTheme.primaryBlue),
                              title: Text(name),
                              trailing: IconButton(
                                icon: const Icon(Icons.open_in_new),
                                onPressed: () {
                                  showUniversalAttachmentViewer(
                                    context,
                                    filePath: path,
                                    title: name,
                                    fileType: type,
                                  );
                                },
                              ),
                              onTap: () {
                                showUniversalAttachmentViewer(
                                  context,
                                  filePath: path,
                                  title: name,
                                  fileType: type,
                                );
                              },
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                ),

                const Divider(),
                // Ações
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (msg.isDraft)
                      FilledButton.icon(
                        icon: const Icon(Icons.send_rounded, size: 16),
                        label: const Text('Enviar via SMTP'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showNewDraftDialog(existingDraft: msg);
                        },
                      )
                    else
                      OutlinedButton.icon(
                        icon: const Icon(Icons.reply_rounded, size: 16),
                        label: const Text('Responder SMTP'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          final replyTo = JwSmtpClient.extractValidEmailAddress(msg.from) ?? msg.from;
                          final replySubj = msg.subject.toLowerCase().startsWith('re:')
                              ? msg.subject
                              : 'Re: ${msg.subject}';
                          _showNewDraftDialog(
                            initialTo: replyTo,
                            initialSubject: replySubj,
                          );
                        },
                      ),
                    FilledButton.tonalIcon(
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text('Exportar'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showExportEmailModal(msg);
                      },
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text('Virar Tarefa'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _convertEmailToTask(msg);
                      },
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.menu_book, size: 16),
                      label: const Text('Virar Pesquisa'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _convertEmailToResearch(msg);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // COMPOR / EDITAR / ENVIAR E-MAIL TEOCRÁTICO
  // ==========================================

  void _showNewDraftDialog({
    JwEmailMessage? existingDraft,
    String? initialTo,
    String? initialSubject,
  }) {
    final initTo = existingDraft?.to ?? initialTo ?? '';
    final initSubject = existingDraft?.subject ?? initialSubject ?? '';
    final initBody = existingDraft?.bodyText ?? '';
    final initTags = existingDraft?.tags.join(', ') ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => ManagedTextControllers(
        initialTexts: [initTo, initSubject, initBody, initTags],
        builder: (ctx, ctrls) {
          final toCtrl = ctrls[0];
          final subjectCtrl = ctrls[1];
          final contentCtrl = ctrls[2];
          final tagsCtrl = ctrls[3];
          bool isSending = false;
          String? inlineError;
          bool needsConfig = false;

          return StatefulBuilder(
            builder: (ctx, setSheetState) => SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  top: 20,
                  left: 20,
                  right: 20,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.edit_note, color: AppTheme.primaryBlue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              existingDraft != null
                                  ? 'Enviar ou Editar Rascunho'
                                  : 'Compor / Rascunho Teocrático',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                      if (inlineError != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Theme.of(ctx).colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                inlineError!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(ctx).colorScheme.onErrorContainer,
                                ),
                              ),
                              if (needsConfig) ...[
                                const SizedBox(height: 6),
                                TextButton.icon(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const SettingsScreen(),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.settings, size: 16),
                                  label: const Text('Configurar E-mail/SMTP'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextField(
                        controller: toCtrl,
                        enabled: !isSending,
                        decoration: const InputDecoration(
                          labelText: 'Para (ex: corpo.anciaos@jw.org)',
                          isDense: true,
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: subjectCtrl,
                        enabled: !isSending,
                        decoration: const InputDecoration(
                          labelText: 'Assunto *',
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: tagsCtrl,
                        enabled: !isSending,
                        decoration: const InputDecoration(
                          labelText: 'Tags (separadas por vírgula)',
                          hintText: 'cartas, assembleia, pioneiro',
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      RichMarkdownToolbar(controller: contentCtrl),
                      const SizedBox(height: 6),
                      TextField(
                        controller: contentCtrl,
                        enabled: !isSending,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Conteúdo da Mensagem *',
                          hintText: 'Escreva a mensagem ou nota que deseja enviar ou salvar permanentemente...',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          TextButton(
                            onPressed: isSending ? null : () => Navigator.pop(ctx),
                            child: const Text('Cancelar'),
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.save, size: 16),
                            label: const Text('Salvar Rascunho'),
                            onPressed: isSending
                                ? null
                                : () async {
                                    final subject = subjectCtrl.text.trim();
                                    if (subject.isEmpty) {
                                      setSheetState(() {
                                        inlineError = 'Informe o assunto para salvar o rascunho.';
                                        needsConfig = false;
                                      });
                                      return;
                                    }
                                    final to = toCtrl.text.trim();
                                    final bodyText = contentCtrl.text.trim();
                                    final tags = tagsCtrl.text
                                        .split(',')
                                        .map((t) => t.trim().replaceAll('#', ''))
                                        .where((t) => t.isNotEmpty)
                                        .toList();

                                    final db = ref.read(repositoryProvider).db;
                                    final emailEntry = await (db.select(db.appKvStore)
                                          ..where((t) => t.key.equals('jw_imap_email')))
                                        .getSingleOrNull();
                                    final userEmail = emailEntry?.value.trim() ?? '';

                                    final draft = JwEmailMessage(
                                      id: existingDraft?.id ?? const Uuid().v4(),
                                      subject: subject,
                                      from: userEmail.isNotEmpty ? userEmail : 'local@dispositivo',
                                      to: to,
                                      date: DateTime.now(),
                                      bodyText: bodyText,
                                      isDraft: true,
                                      tags: tags,
                                    );
                                    await ref.read(jwEmailServiceProvider).saveDraft(draft);
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Rascunho salvo na retenção permanente!'),
                                        ),
                                      );
                                    }
                                  },
                          ),
                          FilledButton.icon(
                            icon: isSending
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.send_rounded, size: 16),
                            label: Text(isSending ? 'Enviando SMTP...' : 'Enviar Agora (SMTP)'),
                            onPressed: isSending
                                ? null
                                : () async {
                                    final to = toCtrl.text.trim();
                                    final subject = subjectCtrl.text.trim();
                                    final bodyText = contentCtrl.text.trim();
                                    if (to.isEmpty ||
                                        JwSmtpClient.parseRecipients(to).isEmpty) {
                                      setSheetState(() {
                                        inlineError =
                                            'Informe pelo menos um destinatário de e-mail válido no campo "Para".';
                                        needsConfig = false;
                                      });
                                      return;
                                    }
                                    if (subject.isEmpty) {
                                      setSheetState(() {
                                        inlineError = 'O assunto não pode ficar em branco.';
                                        needsConfig = false;
                                      });
                                      return;
                                    }

                                    setSheetState(() {
                                      isSending = true;
                                      inlineError = null;
                                      needsConfig = false;
                                    });

                                    try {
                                      final db = ref.read(repositoryProvider).db;
                                      final emailEntry = await (db.select(db.appKvStore)
                                            ..where((t) => t.key.equals('jw_imap_email')))
                                          .getSingleOrNull();
                                      const secureStorage = FlutterSecureStorage();
                                      String? password = await secureStorage.read(key: 'jw_imap_password');
                                      if (password == null || password.isEmpty) {
                                        final legacyPass = await (db.select(db.appKvStore)
                                              ..where((t) => t.key.equals('jw_imap_password')))
                                            .getSingleOrNull();
                                        password = legacyPass?.value;
                                      }
                                      final username = emailEntry?.value.trim() ?? '';
                                      if (username.isEmpty || password == null || password.isEmpty) {
                                        if (ctx.mounted) {
                                          setSheetState(() {
                                            isSending = false;
                                            needsConfig = true;
                                            inlineError =
                                                'Credenciais IMAP/SMTP não configuradas. Configure seu e-mail e senha teocráticos em Configurações antes de enviar.';
                                          });
                                        }
                                        return;
                                      }

                                      final smtpHostEntry = await (db.select(db.appKvStore)
                                            ..where((t) => t.key.equals('jw_smtp_host')))
                                          .getSingleOrNull();
                                      final imapHostEntry = await (db.select(db.appKvStore)
                                            ..where((t) => t.key.equals('jw_imap_host')))
                                          .getSingleOrNull();
                                      final smtpPortEntry = await (db.select(db.appKvStore)
                                            ..where((t) => t.key.equals('jw_smtp_port')))
                                          .getSingleOrNull();
                                      final smtpSecEntry = await (db.select(db.appKvStore)
                                            ..where((t) => t.key.equals('jw_smtp_security')))
                                          .getSingleOrNull();

                                      final smtpHost =
                                          (smtpHostEntry?.value.trim().isNotEmpty == true)
                                              ? smtpHostEntry!.value.trim()
                                              : ((imapHostEntry?.value.trim().isNotEmpty == true)
                                                  ? imapHostEntry!.value.trim()
                                                  : 'mail.jw.org');
                                      final securityMode =
                                          (smtpSecEntry?.value.trim().isNotEmpty == true)
                                              ? smtpSecEntry!.value.trim()
                                              : 'starttls';
                                      final smtpPort = int.tryParse(smtpPortEntry?.value ?? '') ??
                                          (securityMode == 'ssl' ? 465 : 587);

                                      final tags = tagsCtrl.text
                                          .split(',')
                                          .map((t) => t.trim().replaceAll('#', ''))
                                          .where((t) => t.isNotEmpty)
                                          .toList();

                                      final msgToSend = JwEmailMessage(
                                        id: existingDraft?.id ?? const Uuid().v4(),
                                        subject: subject,
                                        from: username,
                                        to: to,
                                        date: DateTime.now(),
                                        bodyText: bodyText,
                                        isDraft: false,
                                        tags: tags,
                                      );

                                      await ref.read(jwEmailServiceProvider).sendEmail(
                                            host: smtpHost,
                                            port: smtpPort,
                                            username: username,
                                            password: password,
                                            message: msgToSend,
                                            securityMode: securityMode,
                                            draftId: existingDraft?.id,
                                          );

                                      if (ctx.mounted) Navigator.pop(ctx);
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'E-mail enviado via SMTP ($smtpHost:$smtpPort) e salvo na retenção permanente!',
                                            ),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      }
                                    } catch (e, st) {
                                      AppLogger.warning('Falha ao enviar e-mail SMTP', e, st);
                                      if (ctx.mounted) {
                                        setSheetState(() {
                                          isSending = false;
                                          needsConfig = e is JwEmailAuthException;
                                          inlineError = 'Falha no envio SMTP: $e';
                                        });
                                      }
                                    }
                                  },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ==========================================
  // CONVERSÃO DE E-MAILS EM TAREFAS / PESQUISA
  // ==========================================

  Future<void> _convertEmailToTask(JwEmailMessage msg) async {
    try {
      await ref.read(taskManagerProvider).createTask(
            title: msg.subject,
            description: 'E-mail de ${msg.from}:\n\n${msg.bodyText}',
            priority: 'normal',
            category: 'ministry',
            tags: msg.tags,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('E-mail convertido em Tarefa com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao converter: $e')),
        );
      }
    }
  }

  Future<void> _convertEmailToResearch(JwEmailMessage msg) async {
    try {
      await ref.read(researchManagerProvider).addArticle(
            title: msg.subject,
            summary: 'Correspondência JW de ${msg.from}',
            content: msg.bodyText,
            tags: msg.tags.isNotEmpty ? msg.tags : ['email_retido'],
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Correspondência convertida em Artigo de Pesquisa!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao converter em pesquisa: $e')),
        );
      }
    }
  }
}
