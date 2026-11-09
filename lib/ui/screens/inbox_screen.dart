import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../database/app_database.dart';
import '../../voice_notes/audio_recording_service.dart';
import '../providers.dart';
import '../widgets/adaptive_ministry_sheet.dart';
import '../widgets/quick_capture_sheet.dart';

/// Tela do Módulo A — Inbox Universal do Field Assistant.
/// Centraliza itens capturados com visualização em lista, reprodução de áudio,
/// visualização de anexos e pipeline de triagem/conversão sem perda de dados.
class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  String _selectedFilter = 'unprocessed'; // unprocessed, in_review, converted, all
  late final AudioPlayerService _playerService;
  String? _currentlyPlayingPath;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _playerService = kIsWeb ? LocalAudioPlayerService() : RealAudioPlayerService();
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

  @override
  Widget build(BuildContext context) {
    final inboxMgr = ref.watch(inboxManagerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.all_inbox_rounded, color: AppTheme.primaryBlue, size: 24),
            SizedBox(width: 8),
            Text('Inbox Universal', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Nova Captura',
            icon: const Icon(Icons.add_circle_outline, color: AppTheme.primaryBlue),
            onPressed: () => QuickCaptureSheet.show(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => QuickCaptureSheet.show(context),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.bolt_rounded),
        label: const Text('Captura Rápida', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
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
      ),
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
            Text(
              entry.content,
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
                  return Chip(
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
    final titleCtrl = TextEditingController(text: entry.content);
    final descCtrl = TextEditingController();
    String priority = 'normal';
    String category = entry.suggestedCategory ?? 'ministry';
    DateTime? dueDate;

    showAdaptiveMinistrySheet(
      context: context,
      title: 'Converter em Tarefa',
      titleLeading: const Icon(Icons.check_circle_outline, color: Color(0xFF10B981)),
      builder: (ctx, scroll) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
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
                      final inboxMgr = ref.read(inboxManagerProvider);
                      await inboxMgr.convertToTask(
                        entry.id,
                        title: titleCtrl.text.trim().isEmpty ? entry.content : titleCtrl.text.trim(),
                        description: descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : null,
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
            );
          },
        );
      },
    );
  }

  void _showConvertToProjectDialog(InboxEntry entry) {
    final nameCtrl = TextEditingController(text: entry.content);
    final objCtrl = TextEditingController();
    String category = entry.suggestedCategory ?? 'ministry';

    showAdaptiveMinistrySheet(
      context: context,
      title: 'Converter em Projeto',
      titleLeading: const Icon(Icons.folder_special_outlined, color: Color(0xFF3B82F6)),
      builder: (ctx, scroll) {
        return Padding(
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
                  final inboxMgr = ref.read(inboxManagerProvider);
                  await inboxMgr.convertToProject(
                    entry.id,
                    name: nameCtrl.text.trim().isEmpty ? entry.content : nameCtrl.text.trim(),
                    objective: objCtrl.text.trim().isNotEmpty ? objCtrl.text.trim() : null,
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
        );
      },
    );
  }

  void _showConvertToNoteDialog(InboxEntry entry) {
    final titleCtrl = TextEditingController(text: entry.content.length > 40 ? '${entry.content.substring(0, 40)}...' : entry.content);
    final contentCtrl = TextEditingController(text: entry.content);

    showAdaptiveMinistrySheet(
      context: context,
      title: 'Converter em Nota de Conhecimento',
      titleLeading: const Icon(Icons.note_add_outlined, color: Color(0xFF8B5CF6)),
      builder: (ctx, scroll) {
        return Padding(
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
                  final inboxMgr = ref.read(inboxManagerProvider);
                  await inboxMgr.convertToNote(
                    entry.id,
                    title: titleCtrl.text.trim().isEmpty ? 'Nova Nota' : titleCtrl.text.trim(),
                    content: contentCtrl.text.trim(),
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
        );
      },
    );
  }

  void _showConvertToQuestionDialog(InboxEntry entry) {
    final qCtrl = TextEditingController(text: entry.content);

    showAdaptiveMinistrySheet(
      context: context,
      title: 'Converter em Dúvida Teocrática',
      titleLeading: const Icon(Icons.help_outline, color: Color(0xFFF59E0B)),
      builder: (ctx, scroll) {
        return Padding(
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
                  final inboxMgr = ref.read(inboxManagerProvider);
                  await inboxMgr.convertToQuestion(
                    entry.id,
                    question: qCtrl.text.trim().isEmpty ? entry.content : qCtrl.text.trim(),
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
        );
      },
    );
  }

  void _handleCardMenuAction(String action, InboxEntry entry) async {
    final inboxMgr = ref.read(inboxManagerProvider);
    if (action == 'in_review') {
      await inboxMgr.markInReview(entry.id);
    } else if (action == 'archive') {
      await inboxMgr.archiveEntry(entry.id);
    } else if (action == 'delete') {
      await inboxMgr.softDeleteEntry(entry.id);
    }
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
    } catch (_) {}
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
}
