import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import 'package:file_picker/file_picker.dart';

import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

import '../../core/app_logger.dart';
import '../../core/app_theme.dart';
import '../../database/app_database.dart';
import '../../inbox/email_account_model.dart';
import '../../inbox/email_contacts_manager.dart';
import '../../inbox/email_html_sanitizer.dart';
import '../../inbox/email_sync_coordinator.dart';
import '../../inbox/exchange_service.dart';
import '../../inbox/inbox_manager.dart';
import '../../inbox/jw_email_service.dart';
import '../../inbox/gmail_oauth_service.dart';
import '../../inbox/microsoft_oauth_service.dart';
import '../../inbox/oauth_token_store.dart';
import '../../references/app_reference.dart';
import '../../research/research_manager.dart';
import '../../sync/supabase_sync_service.dart';
import '../../voice_notes/audio_recording_service.dart';
import '../providers.dart';
import 'email_contacts_screen.dart';
import 'settings_screen.dart';
import '../widgets/adaptive_ministry_sheet.dart';
import '../widgets/app_reference_viewer.dart';
import '../widgets/email_html_frame.dart';
import '../widgets/knowledge_item_reader_dialog.dart';
import '../widgets/managed_text_controllers.dart';
import '../widgets/markdown_preview_text.dart';
import '../widgets/quick_capture_sheet.dart';
import '../widgets/rich_email_editing_controller.dart';
import '../widgets/rich_markdown_toolbar.dart';
import '../widgets/universal_attachment_viewer.dart';

/// Tela do Módulo A — Inbox Universal do Field Assistant.
/// Centraliza itens capturados com visualização em lista, reprodução de áudio,
/// visualização de anexos, e-mail teocrático JW.org (retenção permanente imune à purga de 90 dias),
/// correspondências restritas do Hub (com biometria) e pipeline de triagem/conversão sem perda de dados.
class InboxScreen extends ConsumerStatefulWidget {
  final int? initialTabIndex;
  final int navigationEpoch;

  const InboxScreen({
    super.key,
    this.initialTabIndex,
    this.navigationEpoch = 0,
  });

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen>
    with SingleTickerProviderStateMixin {
  String _selectedFilter =
      'unprocessed'; // unprocessed, in_review, converted, all
  String? _selectedEntryId;
  late final AudioPlayerService _playerService;
  String? _currentlyPlayingPath;
  bool _isPlaying = false;

  late final TabController _tabController;
  final TextEditingController _emailSearchController = TextEditingController();
  String? _selectedEmailTag;
  String? _selectedEmailFolder;
  bool _unreadOnly = false;
  String? _selectedEmailAccount;
  String? _selectedEmailId;
  String? _stickyOpenedEmailId;
  bool _isEmailSelectionMode = false;
  final Set<String> _selectedEmailIds = <String>{};
  bool _isSyncingEmails = false;
  final ScrollController _emailsScrollController = ScrollController();
  final ScrollController _capturesScrollController = ScrollController();
  List<InboxEntry> _cachedCaptures = const [];
  List<JwEmailMessage> _cachedEmails = const [];
  String _selectedCaptureAccount = '__all__';
  List<EmailAccount> _cachedAccounts = const [];
  Future<List<EmailAccount>>? _accountsFuture;
  final Map<String, DateTime> _lastAuthWarnAt = {};

  Future<List<EmailAccount>> _getAccountsFuture() {
    final db = ref.read(repositoryProvider).db;
    return _accountsFuture ??= EmailAccountsManager.loadAccounts(db);
  }

  Future<void> _loadCachedAccounts() async {
    try {
      final db = ref.read(repositoryProvider).db;
      final future = EmailAccountsManager.loadAccounts(db);
      _accountsFuture = future;
      final accs = await future;
      if (mounted) setState(() => _cachedAccounts = accs);
    } catch (e, st) {
      AppLogger.warning('Falha ao carregar contas de e-mail em cache', e, st);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadCachedAccounts();
    final safeIdx = (widget.initialTabIndex ?? 0).clamp(0, 2);
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: safeIdx,
    );
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
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(() async {
          try {
            await ref.read(supabaseSyncServiceProvider).sync();
          } catch (e, st) {
            AppLogger.warning(
              'Falha na sincronização inicial do Supabase na Web',
              e,
              st,
            );
          }
        }());
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_syncEmailsSilently());
    });
  }

  Future<void> _syncEmailsSilently() async {
    if (_isSyncingEmails) return;
    try {
      final db = ref.read(repositoryProvider).db;
      final coordinator = EmailSyncCoordinator(
        db,
        jwEmailService: ref.read(jwEmailServiceProvider),
      );
      await coordinator.syncAll(interactive: false);
      if (mounted) setState(() {});
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant InboxScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTabIndex != null &&
        (widget.initialTabIndex != oldWidget.initialTabIndex ||
            widget.navigationEpoch != oldWidget.navigationEpoch)) {
      final safeIdx = widget.initialTabIndex!.clamp(0, 2);
      if (_tabController.index != safeIdx) {
        _tabController.animateTo(safeIdx);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailSearchController.dispose();
    _emailsScrollController.dispose();
    _capturesScrollController.dispose();
    _playerService.dispose();
    super.dispose();
  }

  String? _extractCaptureAccountEmail(InboxEntry entry) {
    if (entry.sourceType != 'email') {
      return null;
    }
    // 1. Tenta extrair de metadata (padrão gravado por EmailSyncCoordinator)
    if (entry.metadata.isNotEmpty) {
      try {
        final decoded = jsonDecode(entry.metadata);
        if (decoded is Map<String, dynamic>) {
          final emailMap = decoded['email'];
          if (emailMap is Map<String, dynamic>) {
            final acc = emailMap['accountEmail'];
            if (acc is String && acc.trim().isNotEmpty) {
              return acc.trim().toLowerCase();
            }
          }
          final direct = decoded['accountEmail'];
          if (direct is String && direct.trim().isNotEmpty) {
            return direct.trim().toLowerCase();
          }
        }
      } catch (_) {}
    }

    // 2. Fallback legado em attachments
    if (entry.attachments.isNotEmpty) {
      try {
        final decoded = jsonDecode(entry.attachments);
        if (decoded is Map<String, dynamic>) {
          final direct = decoded['accountEmail'];
          if (direct is String && direct.trim().isNotEmpty) {
            return direct.trim().toLowerCase();
          }
          final emailMap = decoded['email'];
          if (emailMap is Map<String, dynamic>) {
            final nested = emailMap['accountEmail'];
            if (nested is String && nested.trim().isNotEmpty) {
              return nested.trim().toLowerCase();
            }
          }
        }
      } catch (_) {}
    }
    return null;
  }

  ({String? from, String? subject}) _extractCaptureEmailHeader(
    InboxEntry entry,
  ) {
    if (entry.sourceType != 'email' || entry.metadata.isEmpty) {
      return (from: null, subject: null);
    }
    try {
      final decoded = jsonDecode(entry.metadata);
      if (decoded is Map<String, dynamic>) {
        final emailMap = decoded['email'];
        if (emailMap is Map<String, dynamic>) {
          final from = emailMap['from'] as String?;
          final subject = emailMap['subject'] as String?;
          return (from: from, subject: subject);
        }
      }
    } catch (_) {}
    return (from: null, subject: null);
  }

  List<InboxEntry> _filterCapturesByAccount(List<InboxEntry> entries) {
    if (_selectedCaptureAccount == '__all__') return entries;
    if (_selectedCaptureAccount == '__none__') {
      return entries.where((e) => e.sourceType != 'email').toList();
    }
    final target = _selectedCaptureAccount.trim().toLowerCase();
    return entries
        .where(
          (e) => _extractCaptureAccountEmail(e)?.trim().toLowerCase() == target,
        )
        .toList();
  }

  Widget _buildCaptureAccountFilterBar(bool isDark) {
    return FutureBuilder<List<EmailAccount>>(
      future: _getAccountsFuture(),
      builder: (context, snapshot) {
        final accounts = snapshot.data ?? const <EmailAccount>[];
        final items = <DropdownMenuItem<String>>[
          const DropdownMenuItem(
            value: '__all__',
            child: Text('Todas as caixas'),
          ),
          const DropdownMenuItem(
            value: '__none__',
            child: Text('Nenhuma (só manuais)'),
          ),
          for (final acc in accounts)
            DropdownMenuItem(
              value: acc.email.toLowerCase(),
              child: Text(
                acc.name.trim().isNotEmpty ? acc.name : acc.email,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ];
        final validValues = items.map((e) => e.value).toSet();
        final currentValue = validValues.contains(_selectedCaptureAccount)
            ? _selectedCaptureAccount
            : '__all__';
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: DropdownButtonFormField<String>(
            initialValue: currentValue,
            isDense: true,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Caixa de captura',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: items,
            onChanged: (value) {
              if (value == null) return;
              setState(() => _selectedCaptureAccount = value);
            },
          ),
        );
      },
    );
  }

  Future<void> _toggleAudio(String path) async {
    if (_currentlyPlayingPath == path && _isPlaying) {
      await _playerService.pause();
    } else {
      _currentlyPlayingPath = path;
      await _playerService.play(path);
    }
  }

  String _friendlySyncError(Object e, [EmailAccount? acc]) {
    return EmailSyncCoordinator.friendlyErrorMessage(e, acc);
  }

  Future<void> _syncEmails() async {
    if (_isSyncingEmails) return;
    setState(() => _isSyncingEmails = true);
    try {
      final db = ref.read(repositoryProvider).db;
      final coordinator = EmailSyncCoordinator(
        db,
        jwEmailService: ref.read(jwEmailServiceProvider),
      );
      final res = await coordinator.syncAll(interactive: true);

      unawaited(() async {
        try {
          await ref.read(supabaseSyncServiceProvider).sync();
        } catch (_) {}
      }());

      if (mounted) {
        if (res.failedDetails.isNotEmpty && res.accountsSynced == 0) {
          await _showSyncOrMutationErrorSnackBar(
            warnings: [
              'Falha na sincronização de e-mail:\n${res.failedDetails.join('\n')}',
            ],
            isError: true,
            duration: const Duration(seconds: 6),
          );
        } else if (res.accountsSynced > 0 && res.failedDetails.isNotEmpty) {
          await _showSyncOrMutationErrorSnackBar(
            warnings: [
              'Sincronização parcial: ${res.totalMessagesSaved} nova(s) mensagem(ns) de ${res.accountsSynced} conta(s). '
                  'Falhas:\n${res.failedDetails.join('\n')}',
            ],
            duration: const Duration(seconds: 6),
          );
        } else if (res.accountsSynced > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Sincronização global concluída: ${res.totalMessagesSaved} nova(s) mensagem(ns) de ${res.accountsSynced} conta(s) e todas as pastas.',
              ),
              backgroundColor: AppTheme.successGreen,
            ),
          );
        } else {
          final accounts = await EmailAccountsManager.loadAccounts(db);
          if (!mounted) return;
          if (accounts.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Nenhuma conta de e-mail cadastrada. Adicione uma em Configurações.',
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Nenhuma conta ativa para sincronização.'),
              ),
            );
          }
        }
      }
      return;
    } catch (e, st) {
      AppLogger.warning('Erro ao sincronizar e-mails: $e', e, st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erro ao sincronizar e-mails: ${_friendlySyncError(e)}',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncingEmails = false);
      }
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
              child: const Icon(
                Icons.fingerprint_rounded,
                size: 56,
                color: Color(0xFF6366F1),
              ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              icon: const Icon(Icons.lock_open, size: 18),
              label: const Text(
                'Autenticar com Biometria / PIN',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
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
            Icon(
              Icons.all_inbox_rounded,
              color: AppTheme.primaryBlue,
              size: 24,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Inbox & JW Mail',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        actions: [
          if (isUnlocked) ...[
            IconButton(
              key: const Key('btn_email_contacts'),
              tooltip: 'Contatos de E-mail',
              icon: const Icon(
                Icons.contacts_outlined,
                color: AppTheme.primaryBlue,
              ),
              onPressed: () async {
                final selectedEmail = await Navigator.push<String>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EmailContactsScreen(
                      onSelectEmail: (email) {
                        _showNewDraftDialog(initialTo: email);
                      },
                    ),
                  ),
                );
                if (selectedEmail != null && mounted) {
                  _showNewDraftDialog(initialTo: selectedEmail);
                }
              },
            ),
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
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync_alt, color: AppTheme.primaryBlue),
              onPressed: _isSyncingEmails ? null : _syncEmails,
            ),
            IconButton(
              tooltip: 'Nova Captura',
              icon: const Icon(
                Icons.add_circle_outline,
                color: AppTheme.primaryBlue,
              ),
              onPressed: () => QuickCaptureSheet.show(context),
            ),
          ],
        ],
        bottom: isUnlocked
            ? PreferredSize(
                preferredSize: const Size.fromHeight(42),
                child: TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(
                      height: 38,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inbox, size: 18),
                            SizedBox(width: 4),
                            Text('Capturas'),
                          ],
                        ),
                      ),
                    ),
                    Tab(
                      height: 38,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.mark_email_unread_outlined, size: 18),
                            SizedBox(width: 4),
                            Text('JW Mail'),
                          ],
                        ),
                      ),
                    ),
                    Tab(
                      height: 38,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.shield_outlined, size: 18),
                            SizedBox(width: 4),
                            Text('Hub Restrito'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
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
    final isLargeScreen = MediaQuery.sizeOf(context).width >= 700;
    if (_tabController.index == 1 && isLargeScreen) {
      return null;
    }
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
      icon: Icon(
        _tabController.index == 1 ? Icons.edit_note : Icons.bolt_rounded,
      ),
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
                _buildFilterChip(
                  'unprocessed',
                  'Pendentes',
                  Icons.hourglass_top,
                ),
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
        _buildCaptureAccountFilterBar(isDark),
        const Divider(height: 1),

        // Lista de Entradas Reativa
        Expanded(
          child: StreamBuilder<List<InboxEntry>>(
            stream: inboxMgr.watchEntries(
              statusFilter: _selectedFilter == 'all' ? null : _selectedFilter,
            ),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                _cachedCaptures = snapshot.data!;
              }
              if (snapshot.connectionState == ConnectionState.waiting &&
                  _cachedCaptures.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              final allEntries = snapshot.data ?? _cachedCaptures;
              final entries = _filterCapturesByAccount(allEntries);
              if (entries.isEmpty) {
                return _buildEmptyState(isDark);
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 900;
                  InboxEntry? selectedEntry;
                  if (_selectedEntryId != null) {
                    for (final item in entries) {
                      if (item.id == _selectedEntryId) {
                        selectedEntry = item;
                        break;
                      }
                    }
                  }

                  final listWidget = ListView.separated(
                    key: const PageStorageKey<String>('inbox_captures_list'),
                    controller: _capturesScrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    itemCount: entries.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) {
                      final entry = entries[i];
                      final card = _buildEntryCard(entry, isDark);
                      if (!isWide) return card;
                      final isSelected = _selectedEntryId == entry.id;
                      return Semantics(
                        selected: isSelected,
                        label: 'Captura rápida: ${entry.content}',
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _selectedEntryId = entry.id),
                          child: Container(
                            decoration: isSelected
                                ? BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: AppTheme.primaryBlue,
                                      width: 2,
                                    ),
                                  )
                                : null,
                            child: card,
                          ),
                        ),
                      );
                    },
                  );

                  if (!isWide) return listWidget;

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(width: 420, child: listWidget),
                      const VerticalDivider(width: 1),
                      Expanded(
                        child: selectedEntry == null
                            ? Center(
                                child: Semantics(
                                  label: 'Selecione uma captura para visualizar detalhes',
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.inbox_outlined,
                                        size: 52,
                                        color: Colors.grey.shade400,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Selecione uma captura para visualizar detalhes',
                                        style: TextStyle(
                                          color: isDark
                                              ? const Color(0xFF94A3B8)
                                              : AppTheme.textMuted,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : SingleChildScrollView(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Semantics(
                                      header: true,
                                      child: Text(
                                        'Detalhe da Captura (${selectedEntry.status})',
                                        style: const TextStyle(
                                          fontSize: 19,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Origem: ${selectedEntry.sourceType}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textMuted,
                                      ),
                                    ),
                                    const Divider(height: 24),
                                    _buildCaptureDetailContent(
                                      selectedEntry,
                                      isDark,
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCaptureDetailContent(InboxEntry entry, bool isDark) {
    Map<String, dynamic>? emailMetadata;
    List<Map<String, dynamic>> attachments = [];
    if (entry.metadata.isNotEmpty) {
      try {
        final decoded = jsonDecode(entry.metadata);
        if (decoded is Map<String, dynamic> && decoded['email'] is Map) {
          emailMetadata = Map<String, dynamic>.from(decoded['email'] as Map);
        }
      } catch (_) {}
    }

    if (entry.attachments.isNotEmpty) {
      try {
        final decoded = jsonDecode(entry.attachments);
        if (decoded is List) {
          attachments = decoded
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      } catch (_) {}
    }

    final isEmailSource = entry.sourceType == 'email' || emailMetadata != null;
    final lowerContent = entry.content.toLowerCase();
    final hasHtmlTags =
        lowerContent.contains('<html') ||
        lowerContent.contains('<div') ||
        lowerContent.contains('<p') ||
        lowerContent.contains('<table') ||
        lowerContent.contains('<span') ||
        lowerContent.contains('<br');

    if (isEmailSource || hasHtmlTags) {
      final htmlBody =
          emailMetadata?['bodyHtml'] as String? ??
          (hasHtmlTags ? entry.content : null);
      final textBody = emailMetadata?['bodyText'] as String? ?? entry.content;

      return _ProfessionalEmailBodyView(
        text: textBody,
        html: htmlBody,
        isDark: isDark,
        attachments: attachments,
      );
    }

    return MarkdownPreviewText(
      text: entry.content,
      selectable: true,
      allowHighlights: true,
      maxLines: 120,
      onContentUpdated: (updated) async {
        await ref
            .read(inboxManagerProvider)
            .updateEntry(entry.id, content: updated);
      },
      style: TextStyle(
        fontSize: 15,
        height: 1.55,
        color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, IconData icon) {
    final isSelected = _selectedFilter == key;
    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 14,
        color: isSelected ? Colors.white : AppTheme.primaryBlue,
      ),
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
                color: isDark
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Use a Captura Rápida a qualquer momento para guardar ideias sem interromper o que estiver fazendo.',
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? const Color(0xFF64748B)
                    : const Color(0xFF94A3B8),
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
    final isPlayingThisAudio =
        _currentlyPlayingPath == entry.mediaPath && _isPlaying;
    final attachmentsList = _parseJsonList(entry.attachments);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Linha do Cabeçalho: Tipo + Categoria + Ações Rápidas
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      _buildSourceBadge(entry.sourceType),
                      if (entry.suggestedCategory != null &&
                          entry.suggestedCategory!.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryBlue.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _resolveCategoryLabel(entry),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: AppTheme.primaryBlue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                if (entry.sourceType == 'email') ...[
                  IconButton(
                    key: Key('btn_capture_fullscreen_${entry.id}'),
                    icon: const Icon(
                      Icons.open_in_full_rounded,
                      size: 16,
                      color: AppTheme.primaryBlue,
                    ),
                    tooltip: 'Ler e-mail em tela cheia',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    style: IconButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      minimumSize: const Size(28, 28),
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: () {
                      final emailMsg = _captureEntryToJwEmail(entry);
                      if (!emailMsg.isRead) {
                        unawaited(
                          _markEmailsReadStatus(
                            [emailMsg],
                            isRead: true,
                            showFeedback: false,
                          ),
                        );
                      }
                      _openEmailReaderScreen(
                        context,
                        emailMsg,
                        _cachedAccounts,
                      );
                    },
                  ),
                  const SizedBox(width: 4),
                ] else ...[
                  IconButton(
                    key: Key('btn_capture_reader_${entry.id}'),
                    icon: const Icon(
                      Icons.chrome_reader_mode_outlined,
                      size: 16,
                      color: AppTheme.primaryBlue,
                    ),
                    tooltip: 'Ler e sublinhar captura',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    style: IconButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      minimumSize: const Size(28, 28),
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: () {
                      final inboxMgr = ref.read(inboxManagerProvider);
                      showKnowledgeItemReader(
                        context,
                        title: _resolveCategoryLabel(entry),
                        content: entry.content,
                        category: entry.suggestedCategory ?? 'Captura',
                        itemType: 'Captura Inbox',
                        subtitle: _formatDate(entry.capturedAt),
                        attachments: attachmentsList,
                        updatedAt: entry.updatedAt,
                        allowHighlights: true,
                        onContentUpdated: (updated) async {
                          await inboxMgr.updateEntry(
                            entry.id,
                            content: updated,
                          );
                        },
                        onDelete: () => inboxMgr.softDeleteEntry(entry.id),
                      );
                    },
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  _formatDate(entry.capturedAt),
                  style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                ),
                const SizedBox(width: 2),
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  iconSize: 18,
                  style: IconButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    minimumSize: const Size(28, 28),
                    padding: EdgeInsets.zero,
                  ),
                  icon: const Icon(Icons.more_vert, size: 18),
                  onSelected: (val) => _handleCardMenuAction(val, entry),
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(
                            Icons.edit_note,
                            size: 18,
                            color: AppTheme.primaryBlue,
                          ),
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
                            Icon(
                              Icons.rate_review,
                              size: 18,
                              color: Colors.amber,
                            ),
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
                          Icon(
                            Icons.download_rounded,
                            size: 18,
                            color: Colors.blueAccent,
                          ),
                          SizedBox(width: 8),
                          Text('Exportar Item'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: Colors.redAccent,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Excluir',
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Conteúdo textual ou Cabeçalho de E-mail
            if (entry.sourceType == 'email') ...[
              Builder(
                builder: (context) {
                  final header = _extractCaptureEmailHeader(entry);
                  final senderName =
                      header.from != null && header.from!.isNotEmpty
                      ? EmailHtmlSanitizer.displaySenderName(header.from)
                      : null;
                  final subject =
                      header.subject != null &&
                          header.subject!.trim().isNotEmpty
                      ? header.subject!.trim()
                      : null;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (senderName != null) ...[
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 13,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                senderName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                      ],
                      if (subject != null) ...[
                        Text(
                          subject,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      Text(
                        EmailHtmlSanitizer.extractPlainText(
                          entry.content,
                          cleanMarkdown: true,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark
                              ? const Color(0xFFCBD5E1)
                              : const Color(0xFF475569),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ] else ...[
              MarkdownPreviewText(
                text: entry.content,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? const Color(0xFFF1F5F9)
                      : const Color(0xFF1E293B),
                ),
              ),
            ],

            // Player de Áudio incorporado
            if (isAudio) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        isPlayingThisAudio
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_fill,
                        color: AppTheme.primaryBlue,
                        size: 32,
                      ),
                      onPressed: () => _toggleAudio(entry.mediaPath!),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Áudio gravado (${entry.mediaDurationSeconds ?? 0}s)',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
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
                      final path =
                          att['path']?.toString() ?? entry.mediaPath ?? '';
                      showUniversalAttachmentViewer(
                        context,
                        filePath: path,
                        title: name,
                        fileType: type,
                      );
                    },
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 6),
            const Divider(height: 1),
            const SizedBox(height: 6),

            // Botões de Conversão Não-Destrutiva
            if (entry.status != 'converted')
              Wrap(
                spacing: 6,
                runSpacing: 5,
                children: [
                  _buildConvertButton(
                    label: 'Virar Tarefa',
                    icon: Icons.check_circle_outline,
                    color: const Color(0xFF10B981),
                    onTap: () => _showConvertToTaskDialog(entry),
                  ),
                  _buildConvertButton(
                    label: 'Virar Projeto',
                    icon: Icons.folder_special_outlined,
                    color: const Color(0xFF3B82F6),
                    onTap: () => _showConvertToProjectDialog(entry),
                  ),
                  _buildConvertButton(
                    label: 'Virar Nota',
                    icon: Icons.note_add_outlined,
                    color: const Color(0xFF8B5CF6),
                    onTap: () => _showConvertToNoteDialog(entry),
                  ),
                  _buildConvertButton(
                    label: 'Virar Pergunta',
                    icon: Icons.help_outline,
                    color: const Color(0xFFF59E0B),
                    onTap: () => _showConvertToQuestionDialog(entry),
                  ),
                ],
              )
            else
              Row(
                children: [
                  const Icon(Icons.check_circle, size: 16, color: Colors.green),
                  const SizedBox(width: 6),
                  Text(
                    'Convertido em ${_entityTypeLabel(entry.convertedEntityType ?? '')}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
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
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
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
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
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
      titleLeading: const Icon(
        Icons.check_circle_outline,
        color: Color(0xFF10B981),
      ),
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
                              decoration: const InputDecoration(
                                labelText: 'Prioridade',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'low',
                                  child: Text('Baixa'),
                                ),
                                DropdownMenuItem(
                                  value: 'normal',
                                  child: Text('Normal'),
                                ),
                                DropdownMenuItem(
                                  value: 'high',
                                  child: Text('Alta'),
                                ),
                                DropdownMenuItem(
                                  value: 'urgent',
                                  child: Text('Urgente'),
                                ),
                              ],
                              onChanged: (v) =>
                                  setModalState(() => priority = v ?? 'normal'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: category,
                              decoration: const InputDecoration(
                                labelText: 'Categoria',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'ministry',
                                  child: Text('Ministério'),
                                ),
                                DropdownMenuItem(
                                  value: 'personal',
                                  child: Text('Pessoal'),
                                ),
                                DropdownMenuItem(
                                  value: 'study',
                                  child: Text('Estudo'),
                                ),
                              ],
                              onChanged: (v) => setModalState(
                                () => category = v ?? 'ministry',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        title: Text(
                          dueDate == null
                              ? 'Definir Data de Vencimento'
                              : 'Vencimento: ${_formatDate(dueDate!)}',
                        ),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now().subtract(
                              const Duration(days: 30),
                            ),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                          );
                          if (picked != null) {
                            setModalState(() => dueDate = picked);
                          }
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
                          final title = titleCtrl.text.trim().isEmpty
                              ? entry.content
                              : titleCtrl.text.trim();
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
                              const SnackBar(
                                content: Text('Tarefa criada com sucesso!'),
                              ),
                            );
                          }
                        },
                        child: const Text(
                          'Confirmar Conversão em Tarefa',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
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
      titleLeading: const Icon(
        Icons.folder_special_outlined,
        color: Color(0xFF3B82F6),
      ),
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
                    decoration: const InputDecoration(
                      labelText: 'Nome do Projeto',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: objCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Objetivo Principal',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () async {
                      final name = nameCtrl.text.trim().isEmpty
                          ? entry.content
                          : nameCtrl.text.trim();
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
                          const SnackBar(
                            content: Text('Projeto criado com sucesso!'),
                          ),
                        );
                      }
                    },
                    child: const Text(
                      'Confirmar Conversão em Projeto',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
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
    final initTitle = entry.content.length > 40
        ? '${entry.content.substring(0, 40)}...'
        : entry.content;

    showAdaptiveMinistrySheet(
      context: context,
      title: 'Converter em Nota de Conhecimento',
      titleLeading: const Icon(
        Icons.note_add_outlined,
        color: Color(0xFF8B5CF6),
      ),
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
                    decoration: const InputDecoration(
                      labelText: 'Título da Nota',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contentCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Conteúdo',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () async {
                      final title = titleCtrl.text.trim().isEmpty
                          ? 'Nova Nota'
                          : titleCtrl.text.trim();
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
                          const SnackBar(
                            content: Text(
                              'Nota salva na Base de Conhecimento!',
                            ),
                          ),
                        );
                      }
                    },
                    child: const Text(
                      'Confirmar Conversão em Nota',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
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
                      final qText = qCtrl.text.trim().isEmpty
                          ? entry.content
                          : qCtrl.text.trim();
                      final inboxMgr = ref.read(inboxManagerProvider);
                      await inboxMgr.convertToQuestion(
                        entry.id,
                        question: qText,
                      );
                      if (ctx.mounted) {
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Dúvida registrada para pesquisa bíblica!',
                            ),
                          ),
                        );
                      }
                    },
                    child: const Text(
                      'Confirmar Conversão em Dúvida',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
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
                        DropdownMenuItem(
                          value: null,
                          child: Text('Sem categoria'),
                        ),
                        DropdownMenuItem(
                          value: 'ministry',
                          child: Text('Ministério'),
                        ),
                        DropdownMenuItem(
                          value: 'personal',
                          child: Text('Pessoal'),
                        ),
                        DropdownMenuItem(value: 'study', child: Text('Estudo')),
                        DropdownMenuItem(
                          value: 'question',
                          child: Text('Dúvida'),
                        ),
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
                            const SnackBar(
                              content: Text('Captura atualizada com sucesso!'),
                            ),
                          );
                        }
                      },
                      child: const Text(
                        'Salvar Alterações',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
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

  String _resolveCategoryLabel(InboxEntry entry) {
    var cat = entry.suggestedCategory ?? '';
    if (cat == 'email_jw') {
      final accEmail = _extractCaptureAccountEmail(entry);
      bool isExchange = false;

      if (entry.metadata.isNotEmpty) {
        try {
          final decoded = jsonDecode(entry.metadata);
          if (decoded is Map) {
            final proto = decoded['protocol']?.toString().toLowerCase();
            final isExchangeMail = decoded['exchangeMail'] as bool?;
            if (proto == 'exchange' || isExchangeMail == true) {
              isExchange = true;
            } else if (proto == 'gmail_api' ||
                proto == 'microsoft_graph' ||
                proto == 'imap' ||
                isExchangeMail == false) {
              isExchange = false;
            }
          }
        } catch (_) {}
      }

      if (!isExchange && accEmail != null && accEmail.isNotEmpty) {
        final acc = _cachedAccounts.firstWhereOrNull(
          (a) => a.email.toLowerCase() == accEmail.toLowerCase(),
        );
        if (acc != null) {
          isExchange = acc.incomingProtocol == 'exchange';
        }
      }

      if (!isExchange) {
        cat = 'email';
      }
    }
    return _categoryLabel(cat);
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
      case 'email_jw':
        return 'JW Mail';
      case 'email':
        return 'E-mail';
      case 'hub_comms':
        return 'Comunicação Hub';
      case 'hub_letter':
        return 'Carta Hub';
      case 'hub_form':
        return 'Formulário Hub';
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
                subtitle: const Text(
                  'Formatado com cabeçalho, pronto para documentação',
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await ref
                      .read(jwEmailServiceProvider)
                      .exportInboxEntry(entry, format: 'markdown');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Nota copiada e arquivo Markdown gerado!',
                        ),
                      ),
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
                  await ref
                      .read(jwEmailServiceProvider)
                      .exportInboxEntry(entry, format: 'text');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Nota copiada em texto puro!'),
                      ),
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
                subtitle: const Text(
                  'Metadados teocráticos e corpo formatado em Markdown',
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await ref
                      .read(jwEmailServiceProvider)
                      .exportEmail(msg, format: 'markdown');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'E-mail copiado e arquivo Markdown baixado!',
                        ),
                      ),
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
                subtitle: const Text(
                  'Compatível com clientes de e-mail e arquivos oficiais',
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await ref
                      .read(jwEmailServiceProvider)
                      .exportEmail(msg, format: 'eml');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Arquivo .eml gerado com sucesso!'),
                      ),
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
                subtitle: const Text(
                  'Copia para a área de transferência e baixa .txt',
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await ref
                      .read(jwEmailServiceProvider)
                      .exportEmail(msg, format: 'text');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Conteúdo copiado em texto puro!'),
                      ),
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
    final isLargeScreen = MediaQuery.sizeOf(context).width >= 700;

    return Column(
      children: [
        // Barra de Busca + Botão Sincronizar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    controller: _emailSearchController,
                    decoration: InputDecoration(
                      hintText:
                          'Pesquisar e-mails, assuntos, remetente ou tags...',
                      hintStyle: const TextStyle(fontSize: 12),
                      prefixIcon: const Icon(Icons.search, size: 18),
                      suffixIcon: _emailSearchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                _emailSearchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 12),
                    onChanged: (val) => setState(() {}),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                key: const Key('btn_toggle_email_selection'),
                tooltip: _isEmailSelectionMode
                    ? 'Sair da seleção'
                    : 'Selecionar e-mails',
                icon: Icon(
                  _isEmailSelectionMode
                      ? Icons.checklist_rtl_rounded
                      : Icons.checklist_rounded,
                  size: 20,
                  color: _isEmailSelectionMode ? AppTheme.primaryBlue : null,
                ),
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  setState(() {
                    _isEmailSelectionMode = !_isEmailSelectionMode;
                    if (!_isEmailSelectionMode) {
                      _selectedEmailIds.clear();
                    }
                  });
                },
              ),
              const SizedBox(width: 4),
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(0, 36),
                ),
                onPressed: _isSyncingEmails ? null : _syncEmails,
                icon: _isSyncingEmails
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync, size: 16),
                label: Text(
                  _isSyncingEmails ? '...' : 'Sincronizar',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              if (isLargeScreen) ...[
                const SizedBox(width: 8),
                FilledButton.icon(
                  key: const Key('btn_new_draft_header'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: const Size(0, 36),
                  ),
                  onPressed: _showNewDraftDialog,
                  icon: const Icon(Icons.edit_note, size: 16),
                  label: const Text(
                    'Novo Rascunho',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
        ),

        // Barra Dedicada de Pastas (Compacta)
        Container(
          key: const Key('email_folder_selector_bar'),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...const [
                  'Todas as pastas',
                  'Caixa de Entrada',
                  'Enviadas',
                  'Rascunhos',
                  'Spam',
                  'Lixeira',
                ].map((folder) {
                  final currentFolder =
                      _selectedEmailFolder ?? 'Todas as pastas';
                  final isSelected = currentFolder == folder;
                  IconData icon;
                  switch (folder) {
                    case 'Caixa de Entrada':
                      icon = Icons.inbox_outlined;
                      break;
                    case 'Enviadas':
                    case 'Enviados':
                      icon = Icons.send_outlined;
                      break;
                    case 'Rascunhos':
                      icon = Icons.drafts_outlined;
                      break;
                    case 'Spam':
                      icon = Icons.report_outlined;
                      break;
                    case 'Lixeira':
                      icon = Icons.delete_outline;
                      break;
                    default:
                      icon = Icons.folder_outlined;
                  }
                  final chipKey =
                      'folder_chip_${folder.toLowerCase().replaceAll(' ', '_')}';
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      key: Key(chipKey),
                      avatar: Icon(icon, size: 14),
                      label: Text(folder, style: const TextStyle(fontSize: 11)),
                      selected: isSelected,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 0,
                      ),
                      selectedColor: AppTheme.primaryBlue.withValues(
                        alpha: 0.2,
                      ),
                      onSelected: (val) {
                        setState(() {
                          _selectedEmailFolder = folder == 'Todas as pastas'
                              ? null
                              : folder;
                          _stickyOpenedEmailId = null;
                          _selectedEmailIds.clear();
                        });
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
              if (snapshot.hasData) {
                _cachedEmails = snapshot.data!;
              }
              if (snapshot.connectionState == ConnectionState.waiting &&
                  _cachedEmails.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              final emails = snapshot.data ?? _cachedEmails;
              if (emails.isEmpty) {
                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.mark_email_unread_outlined,
                          size: 52,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Nenhuma correspondência teocrática retida',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Configure suas contas de e-mail (JWPUB, Exchange, Google, Hotmail) em Ajustes e toque em Sincronizar Agora para baixar mensagens e anexos de todas as pastas.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                            height: 1.4,
                          ),
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
                                  MaterialPageRoute(
                                    builder: (_) => const SettingsScreen(),
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.settings_outlined,
                                size: 18,
                              ),
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

              final currentFolder = _selectedEmailFolder ?? 'Todas as pastas';
              final visible = emails.where((email) {
                if (_unreadOnly &&
                    email.isRead &&
                    email.id != _stickyOpenedEmailId) {
                  return false;
                }
                // Filtro por pasta
                if (currentFolder == 'Caixa de Entrada') {
                  final fn = (email.folderName ?? '').toLowerCase();
                  if (email.isDraft) return false;
                  if (fn.contains('enviad') ||
                      fn.contains('sent') ||
                      fn.contains('lixeir') ||
                      fn.contains('trash') ||
                      fn.contains('delet') ||
                      fn.contains('rascunh') ||
                      fn.contains('draft') ||
                      fn.contains('spam') ||
                      fn.contains('junk') ||
                      fn.contains('lixo eletr')) {
                    return false;
                  }
                } else if (currentFolder == 'Enviadas' ||
                    currentFolder == 'Enviados') {
                  final fn = (email.folderName ?? '').toLowerCase();
                  final hasSentLabel = email.labels.contains('SENT');
                  if (!fn.contains('enviad') &&
                      !fn.contains('sent') &&
                      !hasSentLabel) {
                    return false;
                  }
                } else if (currentFolder == 'Rascunhos') {
                  final fn = (email.folderName ?? '').toLowerCase();
                  if (!email.isDraft &&
                      !fn.contains('rascunh') &&
                      !fn.contains('draft')) {
                    return false;
                  }
                } else if (currentFolder == 'Spam') {
                  final fn = (email.folderName ?? '').toLowerCase();
                  if (!fn.contains('spam') &&
                      !fn.contains('junk') &&
                      !fn.contains('lixo eletr')) {
                    return false;
                  }
                } else if (currentFolder == 'Lixeira') {
                  final fn = (email.folderName ?? '').toLowerCase();
                  if (!fn.contains('lixeir') &&
                      !fn.contains('trash') &&
                      !fn.contains('delet')) {
                    return false;
                  }
                }

                // Filtro por conta de e-mail (Multi-contas)
                if (_selectedEmailAccount != null &&
                    _selectedEmailAccount!.isNotEmpty) {
                  final acc = _selectedEmailAccount!.toLowerCase();
                  final matchAccount =
                      (email.accountEmail?.toLowerCase() == acc) ||
                      email.from.toLowerCase().contains(acc) ||
                      email.to.toLowerCase().contains(acc);
                  if (!matchAccount) return false;
                }
                return true;
              }).toList();

              return FutureBuilder<List<EmailAccount>>(
                future: _getAccountsFuture(),
                builder: (ctx, accSnapshot) {
                  final accounts = accSnapshot.data ?? _cachedAccounts;
                  final visibleIds = visible.map((m) => m.id).toSet();
                  final selectedTargets = visible
                      .where((m) => _selectedEmailIds.contains(m.id))
                      .toList();
                  final allSelected =
                      visible.isNotEmpty &&
                      selectedTargets.length == visible.length;
                  final anyUnreadSelected = selectedTargets.any(
                    (m) => !m.isRead,
                  );
                  return Column(
                    children: [
                      if (_isEmailSelectionMode)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          margin: const EdgeInsets.fromLTRB(16, 4, 16, 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withValues(
                              alpha: isDark ? 0.22 : 0.1,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppTheme.primaryBlue.withValues(
                                alpha: 0.4,
                              ),
                            ),
                          ),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                '${selectedTargets.length} selecionada(s)',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextButton(
                                key: const Key('btn_batch_select_all_emails'),
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                ),
                                onPressed: visible.isEmpty
                                    ? null
                                    : () {
                                        setState(() {
                                          if (allSelected) {
                                            _selectedEmailIds.clear();
                                          } else {
                                            _selectedEmailIds
                                              ..clear()
                                              ..addAll(visibleIds);
                                          }
                                        });
                                      },
                                child: Text(allSelected ? 'Limpar' : 'Todas'),
                              ),
                              FilledButton.tonalIcon(
                                key: const Key('btn_batch_move_folder'),
                                style: FilledButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.drive_file_move_outlined,
                                  size: 16,
                                ),
                                label: const Text(
                                  'Mover pasta',
                                  style: TextStyle(fontSize: 12),
                                ),
                                onPressed: selectedTargets.isEmpty
                                    ? null
                                    : () => _showMoveToFolderDialog(
                                        selectedTargets,
                                      ),
                              ),
                              FilledButton.tonalIcon(
                                key: const Key('btn_batch_mark_read'),
                                style: FilledButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                ),
                                icon: Icon(
                                  anyUnreadSelected
                                      ? Icons.mark_email_read_outlined
                                      : Icons.mark_email_unread_outlined,
                                  size: 16,
                                ),
                                label: Text(
                                  anyUnreadSelected
                                      ? 'Marcar lida'
                                      : 'Não lida',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                onPressed: selectedTargets.isEmpty
                                    ? null
                                    : () => _markEmailsReadStatus(
                                        selectedTargets,
                                        isRead: anyUnreadSelected,
                                      ),
                              ),
                              FilledButton.tonalIcon(
                                key: const Key('btn_batch_delete_emails'),
                                style: FilledButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  foregroundColor: Colors.redAccent,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 16,
                                ),
                                label: const Text(
                                  'Excluir',
                                  style: TextStyle(fontSize: 12),
                                ),
                                onPressed: selectedTargets.isEmpty
                                    ? null
                                    : () => _deleteEmailsWithConfirm(
                                        selectedTargets,
                                      ),
                              ),
                              IconButton(
                                key: const Key('btn_exit_email_selection'),
                                icon: const Icon(Icons.close, size: 18),
                                tooltip: 'Sair da seleção',
                                visualDensity: VisualDensity.compact,
                                onPressed: () {
                                  setState(() {
                                    _isEmailSelectionMode = false;
                                    _selectedEmailIds.clear();
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      // Barra de Seleção de Conta, Tags, Não Lidos e Contador
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: SizedBox(
                          height: 32,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            children: [
                              // Seletor de Conta (Todas as Caixas ou Conta Específica)
                              if (accounts.isNotEmpty) ...[
                                PopupMenuButton<String>(
                                  tooltip: 'Selecionar Caixa de E-mail',
                                  initialValue: _selectedEmailAccount ?? '',
                                  child: Container(
                                    height: 32,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryBlue.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.account_tree_outlined,
                                          size: 15,
                                          color: AppTheme.primaryBlue,
                                        ),
                                        const SizedBox(width: 4),
                                        Builder(
                                          builder: (ctx) {
                                            final currentAcc = accounts
                                                .cast<EmailAccount?>()
                                                .firstWhere(
                                                  (a) =>
                                                      a?.email.toLowerCase() ==
                                                      _selectedEmailAccount
                                                          ?.toLowerCase(),
                                                  orElse: () => null,
                                                );
                                            final displayAccount =
                                                currentAcc != null
                                                ? (currentAcc.name
                                                          .trim()
                                                          .isNotEmpty
                                                      ? currentAcc.name.trim()
                                                      : currentAcc.email.trim())
                                                : 'Todas as Caixas';
                                            return ConstrainedBox(
                                              constraints: const BoxConstraints(
                                                maxWidth: 130,
                                              ),
                                              child: Text(
                                                displayAccount,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppTheme.primaryBlue,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                        const Icon(
                                          Icons.arrow_drop_down,
                                          size: 16,
                                        ),
                                      ],
                                    ),
                                  ),
                                  onSelected: (val) {
                                    setState(() {
                                      _selectedEmailAccount = val.isEmpty
                                          ? null
                                          : val;
                                    });
                                  },
                                  itemBuilder: (ctx) => [
                                    const PopupMenuItem(
                                      value: '',
                                      child: Text(
                                        'Todas as Caixas (Unificado)',
                                      ),
                                    ),
                                    ...accounts.map(
                                      (a) => PopupMenuItem(
                                        value: a.email,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              a.name.trim().isNotEmpty
                                                  ? a.name.trim()
                                                  : a.email,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                            if (a.name.trim().isNotEmpty &&
                                                a.name.trim() != a.email.trim())
                                              Text(
                                                a.email,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 6),
                              ],
                              FilterChip(
                                key: const Key('filter_unread_chip'),
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 0,
                                ),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                avatar: Icon(
                                  _unreadOnly
                                      ? Icons.mark_email_unread
                                      : Icons.mark_email_unread_outlined,
                                  size: 14,
                                ),
                                label: const Text(
                                  'Não lidos',
                                  style: TextStyle(fontSize: 11),
                                ),
                                selected: _unreadOnly,
                                selectedColor: AppTheme.primaryBlue.withValues(
                                  alpha: 0.2,
                                ),
                                onSelected: (val) {
                                  setState(() {
                                    _unreadOnly = val;
                                    _stickyOpenedEmailId = null;
                                  });
                                },
                              ),
                              const SizedBox(width: 6),
                              // Botão / Menu compacto de Tags
                              PopupMenuButton<String>(
                                tooltip: 'Filtrar por Tag',
                                child: Container(
                                  height: 32,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _selectedEmailTag != null
                                        ? AppTheme.primaryBlue.withValues(
                                            alpha: 0.15,
                                          )
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _selectedEmailTag != null
                                          ? AppTheme.primaryBlue
                                          : (isDark
                                                ? const Color(0xFF334155)
                                                : const Color(0xFFCBD5E1)),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.tag,
                                        size: 14,
                                        color: _selectedEmailTag != null
                                            ? AppTheme.primaryBlue
                                            : (isDark
                                                  ? Colors.white70
                                                  : Colors.black87),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _selectedEmailTag != null
                                            ? '#$_selectedEmailTag'
                                            : 'Tags',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: _selectedEmailTag != null
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: _selectedEmailTag != null
                                              ? AppTheme.primaryBlue
                                              : (isDark
                                                    ? Colors.white70
                                                    : Colors.black87),
                                        ),
                                      ),
                                      if (_selectedEmailTag != null) ...[
                                        const SizedBox(width: 4),
                                        InkWell(
                                          onTap: () => setState(
                                            () => _selectedEmailTag = null,
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            size: 13,
                                            color: AppTheme.primaryBlue,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                onSelected: (val) {
                                  setState(() {
                                    _selectedEmailTag = val.isEmpty
                                        ? null
                                        : val;
                                  });
                                },
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(
                                    value: '',
                                    child: Text('Todas as tags'),
                                  ),
                                  ...[
                                    'assembleia',
                                    'circuito',
                                    'cartas',
                                    'broadcasting',
                                    'notícias',
                                  ].map(
                                    (tag) => PopupMenuItem(
                                      value: tag,
                                      child: Text('#$tag'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              // Contador de Mensagens
                              Center(
                                child: Text(
                                  '${visible.length} mensagem(ns)',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 2),

                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final isMasterDetail = constraints.maxWidth >= 700;

                            if (visible.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.mail_outline,
                                      size: 48,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'Nenhum e-mail encontrado em "$currentFolder".',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            final selectedMsg = visible.firstWhere(
                              (m) => m.id == _selectedEmailId,
                              orElse: () => visible.first,
                            );

                            final listWidget = ListView.separated(
                              key: const PageStorageKey('inbox_emails_list'),
                              controller: _emailsScrollController,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              itemCount: visible.length,
                              separatorBuilder: (c, i) =>
                                  const SizedBox(height: 4),
                              itemBuilder: (c, i) {
                                final msg = visible[i];
                                final isChecked = _selectedEmailIds.contains(
                                  msg.id,
                                );
                                final isSelected = _isEmailSelectionMode
                                    ? isChecked
                                    : (isMasterDetail &&
                                          msg.id == selectedMsg.id);
                                return _buildEmailCard(
                                  msg,
                                  isDark,
                                  isHub: false,
                                  isSelected: isSelected,
                                  isSelectionMode: _isEmailSelectionMode,
                                  isChecked: isChecked,
                                  accounts: accounts,
                                  onLongPress: () {
                                    setState(() {
                                      _isEmailSelectionMode = true;
                                      _selectedEmailIds.add(msg.id);
                                    });
                                  },
                                  onTap: () {
                                    if (_isEmailSelectionMode) {
                                      setState(() {
                                        if (_selectedEmailIds.contains(
                                          msg.id,
                                        )) {
                                          _selectedEmailIds.remove(msg.id);
                                        } else {
                                          _selectedEmailIds.add(msg.id);
                                        }
                                      });
                                      return;
                                    }
                                    _openEmailAndMarkRead(
                                      msg,
                                      accounts,
                                      isMasterDetail: isMasterDetail,
                                    );
                                  },
                                );
                              },
                            );

                            if (!isMasterDetail) {
                              return listWidget;
                            }

                            final listWidth = (constraints.maxWidth * 0.36)
                                .clamp(300.0, 420.0);

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(width: listWidth, child: listWidget),
                                VerticalDivider(
                                  width: 1,
                                  thickness: 1,
                                  color: isDark
                                      ? const Color(0xFF334155)
                                      : const Color(0xFFE2E8F0),
                                ),
                                Expanded(
                                  child: _buildOutlookDetailPane(
                                    selectedMsg,
                                    isDark,
                                    accounts,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
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
                child: const Icon(
                  Icons.fingerprint_rounded,
                  size: 56,
                  color: Color(0xFF6366F1),
                ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                icon: const Icon(Icons.lock_open, size: 18),
                label: const Text(
                  'Autenticar com Biometria / PIN',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
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
            border: Border.all(
              color: const Color(0xFF10B981).withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.verified_user,
                size: 20,
                color: Color(0xFF10B981),
              ),
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
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
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
                        Icon(
                          Icons.lock_outline,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Nenhuma correspondência restrita do Hub',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                itemCount: letters.length,
                separatorBuilder: (c, i) => const SizedBox(height: 4),
                itemBuilder: (c, i) {
                  final letter = letters[i];
                  return _buildEmailCard(
                    letter,
                    isDark,
                    isHub: true,
                    onTap: () => _openEmailAndMarkRead(
                      letter,
                      _cachedAccounts,
                      isMasterDetail: false,
                      openModalInstead: true,
                      isHub: true,
                    ),
                  );
                },
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

  Widget _buildEmailCard(
    JwEmailMessage msg,
    bool isDark, {
    bool isHub = false,
    bool isSelected = false,
    bool isSelectionMode = false,
    bool isChecked = false,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    List<EmailAccount>? accounts,
  }) {
    final cleanPreview = EmailHtmlSanitizer.extractPlainText(
      msg.bodyText.isNotEmpty ? msg.bodyText : msg.bodyHtml,
      cleanMarkdown: true,
    ).replaceAll('\n', ' ').trim();
    final isUnread = !msg.isRead;
    final senderName = EmailHtmlSanitizer.displaySenderName(msg.from);
    final initials = EmailHtmlSanitizer.senderInitials(msg.from);

    String? accBadge;
    if (!isHub && accounts != null && accounts.isNotEmpty) {
      final acc = accounts.firstWhereOrNull(
        (a) => a.email.toLowerCase() == (msg.accountEmail ?? '').toLowerCase(),
      );
      if (acc != null) {
        final isExchange = acc.incomingProtocol == 'exchange';
        final rawName = acc.name.trim();
        if (isExchange) {
          accBadge = rawName.isNotEmpty ? rawName : 'JW Mail';
        } else {
          if (rawName.isNotEmpty && rawName.toLowerCase() != 'jw mail') {
            accBadge = rawName;
          } else if (acc.isGmailApi) {
            accBadge = 'Gmail';
          } else if (acc.isMicrosoftGraph) {
            accBadge = 'Outlook';
          } else {
            accBadge = 'E-mail';
          }
        }
      }
    }

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onLongPress: onLongPress,
      onTap:
          onTap ??
          () => _openEmailAndMarkRead(
            msg,
            accounts ?? _cachedAccounts,
            isMasterDetail: false,
            openModalInstead: true,
            isHub: isHub,
          ),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                    ? const Color(0xFF1E3A8A).withValues(alpha: 0.35)
                    : const Color(0xFFDBEAFE))
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryBlue
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Indicador não lido + Avatar (ou Checkbox em modo de seleção)
            if (isSelectionMode)
              SizedBox(
                width: 32,
                height: 32,
                child: Checkbox(
                  key: Key('chk_email_${msg.id}'),
                  value: isChecked,
                  visualDensity: VisualDensity.compact,
                  onChanged: (_) => onTap?.call(),
                ),
              )
            else
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: isHub
                        ? const Color(0xFF8B5CF6).withValues(alpha: 0.16)
                        : (msg.isDraft
                              ? Colors.amber.withValues(alpha: 0.16)
                              : AppTheme.primaryBlue.withValues(alpha: 0.12)),
                    child: Text(
                      initials,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isHub
                            ? const Color(0xFF8B5CF6)
                            : (msg.isDraft
                                  ? Colors.amber.shade800
                                  : AppTheme.primaryBlue),
                      ),
                    ),
                  ),
                  if (isUnread)
                    Positioned(
                      top: -2,
                      left: -2,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppTheme.primaryBlue,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            const SizedBox(width: 10),

            // Conteúdo principal
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Linha 1: Remetente + Anexo + Data + Menu
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          senderName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isUnread
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: isDark
                                ? (isUnread
                                      ? Colors.white
                                      : const Color(0xFFCBD5E1))
                                : (isUnread
                                      ? Colors.black87
                                      : const Color(0xFF334155)),
                          ),
                        ),
                      ),
                      if (msg.attachments.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.attach_file,
                          size: 14,
                          color: Colors.blueGrey,
                        ),
                      ],
                      const SizedBox(width: 6),
                      Text(
                        _formatDate(msg.date),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isUnread
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: isUnread
                              ? (isDark
                                    ? Colors.blue.shade300
                                    : AppTheme.primaryBlue)
                              : Colors.grey,
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Mais opções',
                        onSelected: (val) async {
                          if (val == 'toggle_read') {
                            await _markEmailsReadStatus([
                              msg,
                            ], isRead: !msg.isRead);
                          } else if (val == 'move_folder') {
                            await _showMoveToFolderDialog([msg]);
                          } else if (val == 'export') {
                            _showExportEmailModal(msg);
                          } else if (val == 'to_task') {
                            _convertEmailToTask(msg);
                          } else if (val == 'to_research') {
                            _convertEmailToResearch(msg);
                          } else if (val == 'delete') {
                            await _deleteEmailsWithConfirm([msg]);
                          }
                        },
                        itemBuilder: (ctx) => [
                          PopupMenuItem(
                            value: 'toggle_read',
                            child: Row(
                              children: [
                                Icon(
                                  msg.isRead
                                      ? Icons.mark_email_unread_outlined
                                      : Icons.mark_email_read_outlined,
                                  size: 18,
                                  color: AppTheme.primaryBlue,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  msg.isRead
                                      ? 'Marcar como não lida'
                                      : 'Marcar como lida',
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'move_folder',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.drive_file_move_outlined,
                                  size: 18,
                                  color: Colors.indigoAccent,
                                ),
                                SizedBox(width: 8),
                                Text('Mover para pasta...'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'export',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.download_rounded,
                                  size: 18,
                                  color: Colors.blueAccent,
                                ),
                                SizedBox(width: 8),
                                Text('Exportar (.md / .eml)'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'to_task',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  size: 18,
                                  color: Colors.green,
                                ),
                                SizedBox(width: 8),
                                Text('Virar Tarefa'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'to_research',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.menu_book,
                                  size: 18,
                                  color: Colors.purple,
                                ),
                                SizedBox(width: 8),
                                Text('Virar Artigo de Pesquisa'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: Colors.redAccent,
                                ),
                                SizedBox(width: 8),
                                Text('Excluir'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  if (msg.isDraft ||
                      isHub ||
                      (accBadge != null && accBadge.isNotEmpty)) ...[
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 4,
                      runSpacing: 2,
                      children: [
                        if (msg.isDraft)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Rascunho',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber,
                              ),
                            ),
                          ),
                        if (isHub)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6)
                                  .withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              msg.hubType == 'form' ? 'Formulário' : 'Carta',
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF8B5CF6),
                              ),
                            ),
                          ),
                        if (accBadge != null && accBadge.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryBlue.withValues(
                                alpha: 0.14,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              accBadge,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryBlue,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 2),

                  // Linha 2: Assunto (destaque) + prévia
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          msg.subject.trim().isEmpty
                              ? '(Sem assunto)'
                              : msg.subject,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isUnread
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isDark
                                ? (isUnread
                                      ? const Color(0xFFF1F5F9)
                                      : const Color(0xFFCBD5E1))
                                : (isUnread
                                      ? const Color(0xFF0F172A)
                                      : const Color(0xFF334155)),
                          ),
                        ),
                      ),
                      if (cleanPreview.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '— $cleanPreview',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // MODAL DE DETALHES DE E-MAIL / CARTA
  // ==========================================

  Future<void> _openAttachment(
    BuildContext context,
    JwEmailMessage msg,
    Map<String, dynamic> att,
    List<EmailAccount> accounts,
  ) async {
    final name = att['name']?.toString() ?? 'anexo';
    final rawPath = att['path']?.toString().trim();
    final hasPath = rawPath != null && rawPath.isNotEmpty;
    final rawType = att['type']?.toString().trim();
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    final type = (rawType != null && rawType.isNotEmpty)
        ? rawType
        : (ext.isNotEmpty ? ext : 'file');
    final base64Str = att['base64']?.toString();
    final rawBytesVal = att['rawBytes'];
    Uint8List? rawBytes;
    if (rawBytesVal is Uint8List) {
      rawBytes = rawBytesVal;
    } else if (rawBytesVal is List) {
      rawBytes = Uint8List.fromList(rawBytesVal.whereType<int>().toList());
    }

    if (rawBytes == null && base64Str != null && base64Str.isNotEmpty) {
      try {
        var cleaned = base64Str.trim();
        final idx = cleaned.indexOf('base64,');
        if (cleaned.startsWith('data:') && idx != -1) {
          cleaned = cleaned.substring(idx + 7);
        }
        cleaned = cleaned.replaceAll(RegExp(r'\s+'), '');
        rawBytes = base64.decode(cleaned);
        att['rawBytes'] = rawBytes;
      } catch (_) {}
    }

    if (rawBytes == null && !hasPath) {
      final attachmentId = att['attachmentId'] as String?;
      if (attachmentId != null && attachmentId.isNotEmpty) {
        try {
          final acc = accounts.cast<EmailAccount?>().firstWhere(
            (a) =>
                a?.email.toLowerCase() ==
                (msg.accountEmail ?? '').toLowerCase(),
            orElse: () => accounts.cast<EmailAccount?>().firstWhere(
              (a) => a?.isOAuth == true,
              orElse: () => null,
            ),
          );
          if (acc != null) {
            Uint8List? downloaded;
            if (acc.incomingProtocol == 'gmail_api') {
              downloaded = await GmailOAuthService().downloadAttachment(
                accountId: acc.id,
                messageId: msg.id,
                attachmentId: attachmentId,
              );
            } else if (acc.incomingProtocol == 'microsoft_graph') {
              downloaded = await MicrosoftOAuthService().downloadAttachment(
                accountId: acc.id,
                messageId: msg.id,
                attachmentId: attachmentId,
              );
            }
            if (downloaded != null && downloaded.isNotEmpty) {
              rawBytes = downloaded;
              att['rawBytes'] = downloaded;
            }
          }
        } catch (e) {
          AppLogger.warning('Falha ao baixar anexo sob demanda: $e');
        }
      }
    }

    if (!context.mounted) return;
    if (rawBytes == null && !hasPath) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Anexo indisponível para abrir.')),
      );
      return;
    }
    showUniversalAttachmentViewer(
      context,
      filePath: hasPath ? rawPath : name,
      title: name,
      fileType: type,
      bytes: rawBytes,
    );
  }

  void _openEmailReaderScreen(
    BuildContext context,
    JwEmailMessage msg,
    List<EmailAccount> accounts,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          appBar: AppBar(
            title: Text(
              msg.subject.trim().isEmpty ? '(Sem assunto)' : msg.subject,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          body: SafeArea(
            child: _buildOutlookDetailPane(
              msg,
              isDark,
              accounts,
              isFullScreen: true,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailReferencesBar(JwEmailMessage msg, bool isDark) {
    final sources = '${msg.bodyText}\n${msg.bodyHtml ?? ''}';
    final refs = <({String label, String url})>[];
    final seen = <String>{};

    for (final m in RegExp(
      r'\[([^\]]+)\]\((app://ref/[^\)]+)\)',
    ).allMatches(sources)) {
      final url = m.group(2)?.trim() ?? '';
      final label = m.group(1)?.trim() ?? 'Referência';
      if (url.isNotEmpty && seen.add(url)) {
        refs.add((label: label, url: url));
      }
    }
    for (final m in RegExp(
      r'href=["\x27](app://ref/[^"\x27]+)["\x27][^>]*>([^<]+)<',
      caseSensitive: false,
    ).allMatches(sources)) {
      final url = m.group(1)?.trim() ?? '';
      final label = m.group(2)?.trim() ?? 'Referência';
      if (url.isNotEmpty && seen.add(url)) {
        refs.add((label: label, url: url));
      }
    }

    if (refs.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.accentTeal.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.bookmark_outline,
                size: 15,
                color: AppTheme.accentTeal,
              ),
              SizedBox(width: 6),
              Text(
                'Referências do App neste E-mail:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: refs.map((r) {
              return ActionChip(
                avatar: const Icon(
                  Icons.open_in_new,
                  size: 14,
                  color: AppTheme.accentTeal,
                ),
                label: Text(r.label, style: const TextStyle(fontSize: 12)),
                onPressed: () => AppReferenceViewer.openUrl(context, r.url),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildOutlookDetailPane(
    JwEmailMessage msg,
    bool isDark,
    List<EmailAccount> accounts, {
    bool isFullScreen = false,
  }) {
    final acc = accounts.cast<EmailAccount?>().firstWhere(
      (a) => a?.email.toLowerCase() == (msg.accountEmail ?? '').toLowerCase(),
      orElse: () => accounts.cast<EmailAccount?>().firstWhere(
        (a) => a?.email.toLowerCase() == msg.to.toLowerCase(),
        orElse: () => null,
      ),
    );
    final isExchange = acc?.incomingProtocol == 'exchange';
    final rawName = acc?.name.trim() ?? '';
    final accountName =
        (rawName.isNotEmpty &&
            (isExchange || rawName.toLowerCase() != 'jw mail'))
        ? rawName
        : (isExchange
              ? 'JW Mail'
              : (acc?.isGmailApi == true
                    ? 'Gmail'
                    : (acc?.isMicrosoftGraph == true ? 'Outlook' : 'E-mail')));

    final senderName = EmailHtmlSanitizer.displaySenderName(msg.from);
    final senderEmail = EmailHtmlSanitizer.extractEmailAddress(msg.from);
    final initials = EmailHtmlSanitizer.senderInitials(msg.from);

    return Container(
      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabeçalho Outlook
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Assunto + Botão Maximizar Tela Cheia
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SelectableText(
                        msg.subject.trim().isEmpty
                            ? '(Sem assunto)'
                            : msg.subject,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    if (!isFullScreen)
                      IconButton(
                        key: const Key('btn_maximize_email'),
                        tooltip: 'Maximizar tela cheia',
                        icon: const Icon(Icons.open_in_full, size: 20),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (ctx) => Scaffold(
                                appBar: AppBar(
                                  title: Text(
                                    msg.subject.trim().isEmpty
                                        ? '(Sem assunto)'
                                        : msg.subject,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                body: _buildOutlookDetailPane(
                                  msg,
                                  isDark,
                                  accounts,
                                  isFullScreen: true,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Linha do remetente com Avatar, Nome/E-mail, Badges e Data
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppTheme.primaryBlue.withValues(
                        alpha: 0.15,
                      ),
                      child: Text(
                        initials,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  senderName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              if (senderEmail.isNotEmpty &&
                                  senderEmail != senderName) ...[
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    '<$senderEmail>',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Para: ${msg.to}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatDate(msg.date),
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Badge da Conta
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryBlue.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                accountName,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryBlue,
                                ),
                              ),
                            ),
                            if (msg.folderName != null &&
                                msg.folderName!.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  msg.folderName!,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: isDark
                                        ? const Color(0xFFCBD5E1)
                                        : const Color(0xFF475569),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Corpo rolável com HTML rico ou texto + Anexos
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ProfessionalEmailBodyView(
                    text: msg.bodyText,
                    html: msg.bodyHtml,
                    isDark: isDark,
                  ),
                  _buildEmailReferencesBar(msg, isDark),
                  if (msg.attachments.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(
                      'Anexos (${msg.attachments.length})',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? const Color(0xFFCBD5E1)
                            : const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: msg.attachments.map((att) {
                        final name = att['name']?.toString() ?? 'anexo';
                        final sizeVal = att['size'];
                        final sizeNum = sizeVal is num ? sizeVal : null;
                        final isPdf = name.toLowerCase().endsWith('.pdf');
                        return ActionChip(
                          avatar: Icon(
                            isPdf ? Icons.picture_as_pdf : Icons.attach_file,
                            size: 16,
                            color: isPdf
                                ? Colors.redAccent
                                : AppTheme.primaryBlue,
                          ),
                          label: Text(
                            sizeNum != null && sizeNum > 0
                                ? '$name (${(sizeNum / 1024).toStringAsFixed(1)} KB)'
                                : name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onPressed: () =>
                              _openAttachment(context, msg, att, accounts),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Barra inferior de Ações
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                if (msg.isDraft)
                  FilledButton.icon(
                    icon: const Icon(Icons.send_rounded, size: 16),
                    label: const Text('Enviar E-mail'),
                    onPressed: () {
                      if (isFullScreen) Navigator.pop(context);
                      _showNewDraftDialog(existingDraft: msg);
                    },
                  )
                else
                  OutlinedButton.icon(
                    icon: const Icon(Icons.reply_rounded, size: 16),
                    label: const Text('Responder'),
                    onPressed: () {
                      if (isFullScreen) Navigator.pop(context);
                      final replyTo =
                          JwSmtpClient.extractValidEmailAddress(msg.from) ??
                          msg.from;
                      final replySubj =
                          msg.subject.toLowerCase().startsWith('re:')
                          ? msg.subject
                          : 'Re: ${msg.subject}';
                      _showNewDraftDialog(
                        initialTo: replyTo,
                        initialSubject: replySubj,
                        initialAccountEmail: msg.accountEmail,
                      );
                    },
                  ),
                OutlinedButton.icon(
                  icon: Icon(
                    msg.isRead
                        ? Icons.mark_email_unread_outlined
                        : Icons.mark_email_read_outlined,
                    size: 16,
                  ),
                  label: Text(msg.isRead ? 'Não lida' : 'Lida'),
                  onPressed: () =>
                      _markEmailsReadStatus([msg], isRead: !msg.isRead),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.drive_file_move_outlined, size: 16),
                  label: const Text('Mover pasta'),
                  onPressed: () => _showMoveToFolderDialog([msg]),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                  ),
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Excluir'),
                  onPressed: () async {
                    if (isFullScreen) Navigator.pop(context);
                    await _confirmDeleteEmail(msg);
                  },
                ),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Exportar'),
                  onPressed: () => _showExportEmailModal(msg),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text('Virar Tarefa'),
                  onPressed: () => _convertEmailToTask(msg),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.menu_book, size: 16),
                  label: const Text('Virar Pesquisa'),
                  onPressed: () => _convertEmailToResearch(msg),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEmailDetailsModal(
    BuildContext context,
    JwEmailMessage msg, [
    List<EmailAccount>? accounts,
  ]) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
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
                          const Icon(
                            Icons.shield_outlined,
                            size: 14,
                            color: Color(0xFF10B981),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            msg.isDraft
                                ? 'Rascunho'
                                : (msg.isPermanentRetained
                                      ? 'Cópia local salva'
                                      : 'E-mail sincronizado'),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF047857),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (msg.folderName != null)
                        Text(
                          'Pasta: ${msg.folderName}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      Text(
                        'De: ${msg.from}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        'Para: ${msg.to}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        'Data: ${msg.date.day}/${msg.date.month}/${msg.date.year} às ${msg.date.hour}:${msg.date.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      if (msg.tags.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Tags: ${msg.tags.map((t) => "#$t").join(" ")}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
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
                        _ProfessionalEmailBodyView(
                          text: msg.bodyText,
                          html: msg.bodyHtml,
                          isDark: isDark,
                          attachments: msg.attachments,
                        ),
                        _buildEmailReferencesBar(msg, isDark),
                        if (msg.attachments.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          const Text(
                            'Anexos:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          ...msg.attachments.map((att) {
                            final name = att['name']?.toString() ?? 'anexo';
                            final sizeVal = att['size'];
                            final sizeNum = sizeVal is num ? sizeVal : null;
                            Future<void> openAttachment() async {
                              final accs =
                                  accounts ??
                                  await EmailAccountsManager.loadAccounts(
                                    ref.read(repositoryProvider).db,
                                  );
                              if (!ctx.mounted) return;
                              await _openAttachment(ctx, msg, att, accs);
                            }

                            return ListTile(
                              dense: true,
                              leading: const Icon(
                                Icons.attach_file,
                                color: AppTheme.primaryBlue,
                              ),
                              title: Text(name),
                              subtitle: sizeNum != null && sizeNum > 0
                                  ? Text(
                                      '${(sizeNum / 1024).toStringAsFixed(1)} KB',
                                    )
                                  : null,
                              trailing: IconButton(
                                icon: const Icon(Icons.open_in_new),
                                onPressed: openAttachment,
                              ),
                              onTap: openAttachment,
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
                        label: const Text('Enviar E-mail'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showNewDraftDialog(existingDraft: msg);
                        },
                      )
                    else
                      OutlinedButton.icon(
                        icon: const Icon(Icons.reply_rounded, size: 16),
                        label: const Text('Responder'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          final replyTo =
                              JwSmtpClient.extractValidEmailAddress(msg.from) ??
                              msg.from;
                          final replySubj =
                              msg.subject.toLowerCase().startsWith('re:')
                              ? msg.subject
                              : 'Re: ${msg.subject}';
                          _showNewDraftDialog(
                            initialTo: replyTo,
                            initialSubject: replySubj,
                            initialAccountEmail: msg.accountEmail,
                          );
                        },
                      ),
                    OutlinedButton.icon(
                      icon: Icon(
                        msg.isRead
                            ? Icons.mark_email_unread_outlined
                            : Icons.mark_email_read_outlined,
                        size: 16,
                      ),
                      label: Text(msg.isRead ? 'Não lida' : 'Lida'),
                      onPressed: () async {
                        if (ctx.mounted) Navigator.pop(ctx);
                        await _markEmailsReadStatus([msg], isRead: !msg.isRead);
                      },
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(
                        Icons.drive_file_move_outlined,
                        size: 16,
                      ),
                      label: const Text('Mover pasta'),
                      onPressed: () async {
                        if (ctx.mounted) Navigator.pop(ctx);
                        await _showMoveToFolderDialog([msg]);
                      },
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                      ),
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('Excluir'),
                      onPressed: () async {
                        if (ctx.mounted) Navigator.pop(ctx);
                        await _confirmDeleteEmail(msg);
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
  // SELETOR MODAL DE CONTATOS DE E-MAIL
  // ==========================================

  Future<void> _showContactPickerModal(
    BuildContext context, {
    required ValueChanged<String> onSelected,
  }) async {
    final db = ref.read(repositoryProvider).db;
    final allContacts = await EmailContactsManager.getAllSuggestions(db);
    if (!context.mounted) return;
    final searchCtrl = TextEditingController();
    final selectedEmails = <String>{};

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final query = searchCtrl.text.trim().toLowerCase();
          final filtered = allContacts.where((c) {
            return query.isEmpty ||
                c.name.toLowerCase().contains(query) ||
                c.email.toLowerCase().contains(query);
          }).toList();

          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.85,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.contacts, color: AppTheme.primaryBlue),
                            SizedBox(width: 8),
                            Text(
                              'Selecionar Destinatários',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Pesquisar por nome ou e-mail...',
                        prefixIcon: const Icon(Icons.search),
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onChanged: (_) => setModalState(() {}),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.person_search,
                                    size: 48,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Nenhum contato encontrado.',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (c, i) {
                                final contact = filtered[i];
                                final isChecked = selectedEmails.contains(
                                  contact.email,
                                );
                                return CheckboxListTile(
                                  value: isChecked,
                                  onChanged: (val) {
                                    setModalState(() {
                                      if (val == true) {
                                        selectedEmails.add(contact.email);
                                      } else {
                                        selectedEmails.remove(contact.email);
                                      }
                                    });
                                  },
                                  title: Text(
                                    contact.name.isNotEmpty
                                        ? contact.name
                                        : contact.email,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  subtitle: Text(
                                    contact.email,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  secondary: CircleAvatar(
                                    radius: 18,
                                    backgroundColor: AppTheme.primaryBlue
                                        .withValues(alpha: 0.12),
                                    child: Text(
                                      (contact.name.isNotEmpty
                                              ? contact.name
                                              : contact.email)[0]
                                          .toUpperCase(),
                                      style: const TextStyle(
                                        color: AppTheme.primaryBlue,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${selectedEmails.length} selecionado(s)',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                        FilledButton(
                          onPressed: selectedEmails.isEmpty
                              ? null
                              : () {
                                  onSelected(selectedEmails.join(', '));
                                  Navigator.pop(ctx);
                                },
                          child: const Text('Confirmar Destinatários'),
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

  // ==========================================
  // COMPOR / EDITAR / ENVIAR E-MAIL TEOCRÁTICO
  // ==========================================

  Future<void> _showNewDraftDialog({
    JwEmailMessage? existingDraft,
    String? initialTo,
    String? initialSubject,
    String? initialAccountEmail,
  }) async {
    final db = ref.read(repositoryProvider).db;
    final accounts = await EmailAccountsManager.loadAccounts(db);

    EmailAccount? selectedAccount;
    if (existingDraft?.accountEmail != null &&
        existingDraft!.accountEmail!.isNotEmpty) {
      selectedAccount = accounts.firstWhereOrNull(
        (a) =>
            a.email.toLowerCase() == existingDraft.accountEmail!.toLowerCase(),
      );
    } else if (initialAccountEmail != null && initialAccountEmail.isNotEmpty) {
      selectedAccount = accounts.firstWhereOrNull(
        (a) => a.email.toLowerCase() == initialAccountEmail.toLowerCase(),
      );
    } else if (_selectedEmailAccount != null &&
        _selectedEmailAccount!.isNotEmpty) {
      selectedAccount = accounts.firstWhereOrNull(
        (a) => a.email.toLowerCase() == _selectedEmailAccount!.toLowerCase(),
      );
    }
    selectedAccount ??=
        accounts.where((a) => a.isActive).firstOrNull ?? accounts.firstOrNull;

    if (!mounted) return;

    final initTo = existingDraft?.to ?? initialTo ?? '';
    final initCc = existingDraft?.cc.join(', ') ?? '';
    final initBcc = existingDraft?.bcc.join(', ') ?? '';
    final initSubject = existingDraft?.subject ?? initialSubject ?? '';
    final initBody = existingDraft?.bodyText ?? '';
    final initTags = existingDraft?.tags.join(', ') ?? '';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => ManagedTextControllers(
        initialTexts: [
          initTo,
          initCc,
          initBcc,
          initSubject,
          initBody,
          initTags,
        ],
        customFactories: [
          null,
          null,
          null,
          null,
          (text) => RichEmailEditingController(text: text),
          null,
        ],
        builder: (ctx, ctrls) {
          final toCtrl = ctrls[0];
          final ccCtrl = ctrls[1];
          final bccCtrl = ctrls[2];
          final subjectCtrl = ctrls[3];
          final contentCtrl = ctrls[4];
          final tagsCtrl = ctrls[5];
          bool showCcBcc = initCc.isNotEmpty || initBcc.isNotEmpty;
          bool isHtmlPreview = false;
          bool includeSignature = true;
          final attachments = List<Map<String, dynamic>>.from(
            existingDraft?.attachments ?? [],
          );
          bool isSending = false;
          String? inlineError;
          bool needsConfig = false;

          return StatefulBuilder(
            builder: (ctx, setSheetState) {
              final db = ref.read(repositoryProvider).db;

              Future<void> pickAttachments() async {
                try {
                  final res = await FilePicker.pickFiles(type: FileType.any);
                  if (res.isNotEmpty) {
                    for (final f in res) {
                      String base64Str = '';
                      int size = 0;
                      try {
                        size = (await f.length()) ?? 0;
                      } catch (_) {}
                      try {
                        final bytes = await f.readAsBytes();
                        base64Str = base64.encode(bytes);
                        if (size == 0) size = bytes.length;
                      } catch (_) {
                        if (f.path != null && !kIsWeb) {
                          try {
                            final bytes = await File(f.path!).readAsBytes();
                            base64Str = base64.encode(bytes);
                            if (size == 0) size = bytes.length;
                          } catch (_) {}
                        }
                      }
                      final ext = f.name.contains('.')
                          ? f.name.split('.').last.toLowerCase()
                          : 'file';
                      attachments.add({
                        'name': f.name,
                        'size': size,
                        'path': f.path ?? f.name,
                        'base64': base64Str,
                        'contentType': 'application/octet-stream',
                        'type': ext,
                      });
                    }
                    setSheetState(() {});
                  }
                } catch (e) {
                  AppLogger.warning('Falha ao selecionar arquivo', e);
                }
              }

              final isDark = Theme.of(ctx).brightness == Brightness.dark;

              return SafeArea(
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
                            const Icon(
                              Icons.edit_note,
                              color: AppTheme.primaryBlue,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                existingDraft != null
                                    ? 'Enviar ou Editar Rascunho'
                                    : 'Compor / Novo E-mail',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
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
                                    color: Theme.of(ctx)
                                        .colorScheme
                                        .onErrorContainer,
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
                                          builder: (_) =>
                                              const SettingsScreen(),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.settings, size: 16),
                                    label: const Text(
                                      'Configurações de E-mail',
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                        if (accounts.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          DropdownButtonFormField<EmailAccount>(
                            key: const ValueKey('compose_account_selector'),
                            initialValue: selectedAccount,
                            decoration: const InputDecoration(
                              labelText: 'De (Conta de Envio) *',
                              isDense: true,
                              prefixIcon: Icon(
                                Icons.alternate_email,
                                color: AppTheme.primaryBlue,
                                size: 20,
                              ),
                            ),
                            items: accounts.map((acc) {
                              return DropdownMenuItem(
                                value: acc,
                                child: Text(
                                  '${acc.name} <${acc.email}>',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              );
                            }).toList(),
                            onChanged: isSending
                                ? null
                                : (val) {
                                    if (val != null) {
                                      setSheetState(
                                        () => selectedAccount = val,
                                      );
                                    }
                                  },
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: toCtrl,
                                enabled: !isSending,
                                onChanged: (_) => setSheetState(() {}),
                                decoration: InputDecoration(
                                  labelText: 'Para *',
                                  hintText: 'Digite o e-mail ou toque em Para',
                                  isDense: true,
                                  prefixIcon: TextButton(
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    onPressed: isSending
                                        ? null
                                        : () => _showContactPickerModal(
                                            ctx,
                                            onSelected: (emails) {
                                              if (toCtrl.text.trim().isEmpty) {
                                                toCtrl.text = emails;
                                              } else {
                                                toCtrl.text =
                                                    '${toCtrl.text}, $emails';
                                              }
                                              setSheetState(() {});
                                            },
                                          ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Para:',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.primaryBlue,
                                          ),
                                        ),
                                        Icon(
                                          Icons.arrow_drop_down,
                                          size: 16,
                                          color: AppTheme.primaryBlue,
                                        ),
                                      ],
                                    ),
                                  ),
                                  suffixIcon: IconButton(
                                    icon: const Icon(
                                      Icons.contacts,
                                      size: 20,
                                      color: AppTheme.primaryBlue,
                                    ),
                                    tooltip: 'Buscar e selecionar contatos',
                                    onPressed: isSending
                                        ? null
                                        : () => _showContactPickerModal(
                                            ctx,
                                            onSelected: (emails) {
                                              if (toCtrl.text.trim().isEmpty) {
                                                toCtrl.text = emails;
                                              } else {
                                                toCtrl.text =
                                                    '${toCtrl.text}, $emails';
                                              }
                                              setSheetState(() {});
                                            },
                                          ),
                                  ),
                                ),
                                keyboardType: TextInputType.emailAddress,
                              ),
                            ),
                            if (!showCcBcc)
                              TextButton(
                                onPressed: isSending
                                    ? null
                                    : () =>
                                          setSheetState(() => showCcBcc = true),
                                child: const Text('Cc / Cco'),
                              ),
                          ],
                        ),
                        if (showCcBcc) ...[
                          const SizedBox(height: 8),
                          TextField(
                            controller: ccCtrl,
                            enabled: !isSending,
                            onChanged: (_) => setSheetState(() {}),
                            decoration: InputDecoration(
                              labelText: 'Cc',
                              hintText: 'Com cópia',
                              isDense: true,
                              prefixIcon: TextButton(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: isSending
                                    ? null
                                    : () => _showContactPickerModal(
                                        ctx,
                                        onSelected: (emails) {
                                          if (ccCtrl.text.trim().isEmpty) {
                                            ccCtrl.text = emails;
                                          } else {
                                            ccCtrl.text =
                                                '${ccCtrl.text}, $emails';
                                          }
                                          setSheetState(() {});
                                        },
                                      ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Cc:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryBlue,
                                      ),
                                    ),
                                    Icon(
                                      Icons.arrow_drop_down,
                                      size: 16,
                                      color: AppTheme.primaryBlue,
                                    ),
                                  ],
                                ),
                              ),
                              suffixIcon: IconButton(
                                icon: const Icon(
                                  Icons.contacts,
                                  size: 20,
                                  color: AppTheme.primaryBlue,
                                ),
                                tooltip: 'Buscar e selecionar contatos',
                                onPressed: isSending
                                    ? null
                                    : () => _showContactPickerModal(
                                        ctx,
                                        onSelected: (emails) {
                                          if (ccCtrl.text.trim().isEmpty) {
                                            ccCtrl.text = emails;
                                          } else {
                                            ccCtrl.text =
                                                '${ccCtrl.text}, $emails';
                                          }
                                          setSheetState(() {});
                                        },
                                      ),
                              ),
                            ),
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: bccCtrl,
                            enabled: !isSending,
                            onChanged: (_) => setSheetState(() {}),
                            decoration: InputDecoration(
                              labelText: 'Cco',
                              hintText: 'Cópia oculta',
                              isDense: true,
                              prefixIcon: TextButton(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: isSending
                                    ? null
                                    : () => _showContactPickerModal(
                                        ctx,
                                        onSelected: (emails) {
                                          if (bccCtrl.text.trim().isEmpty) {
                                            bccCtrl.text = emails;
                                          } else {
                                            bccCtrl.text =
                                                '${bccCtrl.text}, $emails';
                                          }
                                          setSheetState(() {});
                                        },
                                      ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Cco:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryBlue,
                                      ),
                                    ),
                                    Icon(
                                      Icons.arrow_drop_down,
                                      size: 16,
                                      color: AppTheme.primaryBlue,
                                    ),
                                  ],
                                ),
                              ),
                              suffixIcon: IconButton(
                                icon: const Icon(
                                  Icons.contacts,
                                  size: 20,
                                  color: AppTheme.primaryBlue,
                                ),
                                tooltip: 'Buscar e selecionar contatos',
                                onPressed: isSending
                                    ? null
                                    : () => _showContactPickerModal(
                                        ctx,
                                        onSelected: (emails) {
                                          if (bccCtrl.text.trim().isEmpty) {
                                            bccCtrl.text = emails;
                                          } else {
                                            bccCtrl.text =
                                                '${bccCtrl.text}, $emails';
                                          }
                                          setSheetState(() {});
                                        },
                                      ),
                              ),
                            ),
                            keyboardType: TextInputType.emailAddress,
                          ),
                        ],
                        FutureBuilder<List<EmailContact>>(
                          future: EmailContactsManager.getAllSuggestions(
                            db,
                            query: _extractLastRecipientToken(toCtrl.text),
                          ),
                          builder: (c, snap) {
                            final contacts = (snap.data ?? []).take(8).toList();
                            if (contacts.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            final token = _extractLastRecipientToken(
                              toCtrl.text,
                            );
                            return Padding(
                              padding: const EdgeInsets.only(top: 6, bottom: 4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.person_search_outlined,
                                        size: 14,
                                        color: AppTheme.primaryBlue,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        token.isNotEmpty
                                            ? 'Sugestões baseadas no que escreveu:'
                                            : 'Contatos frequentes:',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color:
                                              Theme.of(ctx).brightness ==
                                                  Brightness.dark
                                              ? Colors.grey.shade400
                                              : Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        ...contacts.map((contact) {
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              right: 6,
                                            ),
                                            child: ActionChip(
                                              visualDensity:
                                                  VisualDensity.compact,
                                              avatar: CircleAvatar(
                                                radius: 8,
                                                backgroundColor:
                                                    AppTheme.primaryBlue,
                                                child: Text(
                                                  (contact.name.isNotEmpty
                                                          ? contact.name
                                                          : contact.email)[0]
                                                      .toUpperCase(),
                                                  style: const TextStyle(
                                                    fontSize: 9,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                              label: Text(
                                                contact.name.isNotEmpty
                                                    ? '${contact.name} (${contact.email})'
                                                    : contact.email,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                ),
                                              ),
                                              onPressed: isSending
                                                  ? null
                                                  : () {
                                                      _applyRecipientSuggestion(
                                                        toCtrl,
                                                        contact.email,
                                                      );
                                                      setSheetState(() {});
                                                    },
                                            ),
                                          );
                                        }),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
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
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            const Text(
                              'Editor Rico / Prévia',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            SegmentedButton<bool>(
                              segments: const [
                                ButtonSegment(
                                  value: false,
                                  label: Text(
                                    'Editar',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                  icon: Icon(Icons.edit_note, size: 14),
                                ),
                                ButtonSegment(
                                  value: true,
                                  label: Text(
                                    'Prévia HTML',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                  icon: Icon(Icons.visibility, size: 14),
                                ),
                              ],
                              selected: {isHtmlPreview},
                              onSelectionChanged: (val) {
                                setSheetState(() => isHtmlPreview = val.first);
                              },
                              style: const ButtonStyle(
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (!isHtmlPreview) ...[
                          RichMarkdownToolbar(
                            controller: contentCtrl,
                            enableHighlightPalette: false,
                            enableCrossReferences: true,
                            onReferenceInserted: (picked) async {
                              final imgData =
                                  picked.candidate?.previewImageData;
                              if (picked.category == AppRefCategory.picture &&
                                  imgData != null &&
                                  imgData.isNotEmpty &&
                                  ctx.mounted) {
                                final shouldAttach = await showDialog<bool>(
                                  context: ctx,
                                  builder: (dCtx) => AlertDialog(
                                    title: const Text(
                                      'Anexar gravura ao e-mail?',
                                    ),
                                    content: Text(
                                      'Deseja anexar "${picked.candidate?.title ?? 'Gravura'}" como imagem neste e-mail para o destinatário?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(dCtx, false),
                                        child: const Text('Somente referência'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(dCtx, true),
                                        child: const Text('Anexar Imagem'),
                                      ),
                                    ],
                                  ),
                                );
                                if (shouldAttach == true) {
                                  String b64 = '';
                                  int size = 0;
                                  var mime = 'image/jpeg';
                                  var ext = 'jpg';
                                  if (imgData.startsWith('data:image')) {
                                    final headerEnd = imgData.indexOf(
                                      'base64,',
                                    );
                                    if (headerEnd != -1) {
                                      b64 = imgData.substring(headerEnd + 7);
                                      final header = imgData
                                          .substring(0, headerEnd)
                                          .toLowerCase();
                                      if (header.contains('png')) {
                                        mime = 'image/png';
                                        ext = 'png';
                                      }
                                      try {
                                        size = base64Decode(b64).length;
                                      } catch (_) {}
                                    }
                                  } else if (!kIsWeb &&
                                      !imgData.startsWith('http') &&
                                      !imgData.startsWith('assets/')) {
                                    try {
                                      final file = File(imgData);
                                      if (await file.exists()) {
                                        final bytes = await file.readAsBytes();
                                        b64 = base64.encode(bytes);
                                        size = bytes.length;
                                        if (imgData.toLowerCase().endsWith(
                                          '.png',
                                        )) {
                                          mime = 'image/png';
                                          ext = 'png';
                                        }
                                      }
                                    } catch (e, st) {
                                      AppLogger.debug(
                                        'Falha ao anexar gravura referenciada: $e',
                                        st,
                                      );
                                    }
                                  }
                                  if (b64.isNotEmpty) {
                                    final safeTitle =
                                        (picked.candidate?.title ?? 'gravura')
                                            .replaceAll(
                                              RegExp(r'[^a-zA-Z0-9_-]'),
                                              '_',
                                            );
                                    attachments.add({
                                      'name': '$safeTitle.$ext',
                                      'size': size,
                                      'path': '$safeTitle.$ext',
                                      'base64': b64,
                                      'contentType': mime,
                                      'type': ext,
                                    });
                                    setSheetState(() {});
                                  }
                                }
                              }
                            },
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            key: const ValueKey('compose_content_field'),
                            controller: contentCtrl,
                            enabled: !isSending,
                            maxLines: 5,
                            decoration: const InputDecoration(
                              labelText: 'Conteúdo da Mensagem *',
                              hintText: 'Escreva a mensagem ou nota que deseja enviar ou salvar permanentemente...',
                            ),
                          ),
                        ] else ...[
                          Theme(
                            data: ThemeData.light(),
                            child: Container(
                              width: double.infinity,
                              constraints: const BoxConstraints(minHeight: 120),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFCBD5E1),
                                ),
                              ),
                              child: contentCtrl.text.trim().isEmpty
                                  ? const Text(
                                      '(Nenhum conteúdo digitado)',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    )
                                  : HtmlWidget(
                                      EmailHtmlSanitizer.markdownToCleanHtml(
                                        contentCtrl.text.trim(),
                                      ),
                                      textStyle: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                            ),
                          ),
                        ],
                        if (selectedAccount?.signatureHtml.trim().isNotEmpty ==
                            true) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFCBD5E1),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.draw_outlined,
                                            size: 16,
                                            color: AppTheme.primaryBlue,
                                          ),
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              'Assinatura ativa (${selectedAccount!.name})',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Switch.adaptive(
                                      value: includeSignature,
                                      activeTrackColor: AppTheme.primaryBlue,
                                      onChanged: (val) => setSheetState(
                                        () => includeSignature = val,
                                      ),
                                    ),
                                  ],
                                ),
                                if (includeSignature) ...[
                                  const SizedBox(height: 6),
                                  Theme(
                                    data: ThemeData.light(),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      child: HtmlWidget(
                                        selectedAccount!.signatureHtml,
                                        textStyle: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF1E293B),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Anexos (${attachments.length})',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                              ),
                              icon: const Icon(Icons.attach_file, size: 16),
                              label: const Text(
                                'Adicionar Anexo',
                                style: TextStyle(fontSize: 12),
                              ),
                              onPressed: isSending ? null : pickAttachments,
                            ),
                          ],
                        ),
                        if (attachments.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: attachments.map((att) {
                              final name = att['name']?.toString() ?? 'arquivo';
                              final size = (att['size'] as int? ?? 0) / 1024;
                              return InputChip(
                                avatar: const Icon(Icons.attachment, size: 15),
                                label: Text(
                                  '$name (${size.toStringAsFixed(1)} KB)',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                onDeleted: isSending
                                    ? null
                                    : () {
                                        setSheetState(() {
                                          attachments.remove(att);
                                        });
                                      },
                              );
                            }).toList(),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            TextButton(
                              onPressed: isSending
                                  ? null
                                  : () => Navigator.pop(ctx),
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
                                      final ccList =
                                          JwSmtpClient.parseRecipients(
                                            ccCtrl.text,
                                          );
                                      final bccList =
                                          JwSmtpClient.parseRecipients(
                                            bccCtrl.text,
                                          );
                                      final rawText = contentCtrl.text.trim();
                                      final baseLocalHtml =
                                          EmailHtmlSanitizer.markdownToCleanHtml(
                                            rawText,
                                            preserveAppRefLinks: true,
                                          );
                                      final baseCleanPlain =
                                          EmailHtmlSanitizer.markdownToCleanPlainText(
                                            rawText,
                                          );
                                      final String localHtmlBody;
                                      final String finalPlainBody;
                                      if (includeSignature &&
                                          selectedAccount?.signatureHtml
                                                  .trim()
                                                  .isNotEmpty ==
                                              true) {
                                        localHtmlBody =
                                            '$baseLocalHtml<br><br>--<br>${selectedAccount!.signatureHtml}';
                                        finalPlainBody =
                                            '$baseCleanPlain\n\n--\n${EmailHtmlSanitizer.extractPlainText(selectedAccount!.signatureHtml, cleanMarkdown: true)}';
                                      } else {
                                        localHtmlBody = baseLocalHtml;
                                        finalPlainBody = baseCleanPlain;
                                      }

                                      final tags = tagsCtrl.text
                                          .split(',')
                                          .map(
                                            (t) => t.trim().replaceAll('#', ''),
                                          )
                                          .where((t) => t.isNotEmpty)
                                          .toList();

                                      final emailEntry =
                                          await (db.select(db.appKvStore)
                                                ..where(
                                                  (t) => t.key.equals(
                                                    'jw_imap_email',
                                                  ),
                                                ))
                                              .getSingleOrNull();
                                      final userEmail =
                                          selectedAccount?.email ??
                                          emailEntry?.value.trim() ??
                                          '';

                                      final draft = JwEmailMessage(
                                        id:
                                            existingDraft?.id ??
                                            const Uuid().v4(),
                                        accountEmail: selectedAccount?.email,
                                        folderName: 'Rascunhos',
                                        subject: subject,
                                        from: userEmail.isNotEmpty
                                            ? userEmail
                                            : 'local@dispositivo',
                                        to: to,
                                        cc: ccList,
                                        bcc: bccList,
                                        date: DateTime.now(),
                                        bodyText: finalPlainBody,
                                        bodyHtml: localHtmlBody.isNotEmpty
                                            ? localHtmlBody
                                            : null,
                                        attachments: attachments,
                                        isDraft: true,
                                        tags: tags,
                                      );
                                      await ref
                                          .read(jwEmailServiceProvider)
                                          .saveDraft(draft);
                                      if (ctx.mounted) Navigator.pop(ctx);
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Rascunho salvo na retenção permanente!',
                                                ),
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
                              label: Text(
                                isSending ? 'Enviando...' : 'Enviar E-mail',
                              ),
                              onPressed: isSending
                                  ? null
                                  : () async {
                                      final to = toCtrl.text.trim();
                                      final subject = subjectCtrl.text.trim();
                                      final rawText = contentCtrl.text.trim();
                                      final baseCleanHtml =
                                          EmailHtmlSanitizer.markdownToCleanHtml(
                                            rawText,
                                            preserveAppRefLinks: false,
                                          );
                                      final baseLocalHtml =
                                          EmailHtmlSanitizer.markdownToCleanHtml(
                                            rawText,
                                            preserveAppRefLinks: true,
                                          );
                                      final baseCleanPlain =
                                          EmailHtmlSanitizer.markdownToCleanPlainText(
                                            rawText,
                                          );
                                      final String finalHtmlBody;
                                      final String localHtmlBody;
                                      final String finalPlainBody;
                                      if (includeSignature &&
                                          selectedAccount?.signatureHtml
                                                  .trim()
                                                  .isNotEmpty ==
                                              true) {
                                        finalHtmlBody =
                                            '$baseCleanHtml<br><br>--<br>${selectedAccount!.signatureHtml}';
                                        localHtmlBody =
                                            '$baseLocalHtml<br><br>--<br>${selectedAccount!.signatureHtml}';
                                        finalPlainBody =
                                            '$baseCleanPlain\n\n--\n${EmailHtmlSanitizer.extractPlainText(selectedAccount!.signatureHtml, cleanMarkdown: true)}';
                                      } else {
                                        finalHtmlBody = baseCleanHtml;
                                        localHtmlBody = baseLocalHtml;
                                        finalPlainBody = baseCleanPlain;
                                      }
                                      final bodyText = finalPlainBody;
                                      final ccList =
                                          JwSmtpClient.parseRecipients(
                                            ccCtrl.text,
                                          );
                                      final bccList =
                                          JwSmtpClient.parseRecipients(
                                            bccCtrl.text,
                                          );
                                      if (to.isEmpty ||
                                          JwSmtpClient.parseRecipients(to)
                                              .isEmpty) {
                                        setSheetState(() {
                                          inlineError = 'Informe pelo menos um destinatário de e-mail válido no campo "Para".';
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
                                        if (kIsWeb &&
                                            (selectedAccount == null ||
                                                !selectedAccount!.isOAuth)) {
                                          setSheetState(() {
                                            isSending = false;
                                            needsConfig = false;
                                            inlineError = 'Envio direto via socket SMTP/Exchange não é suportado no navegador Web. Utilize o aplicativo Desktop ou Mobile.';
                                          });
                                          return;
                                        }

                                        final tags = tagsCtrl.text
                                            .split(',')
                                            .map(
                                              (t) =>
                                                  t.trim().replaceAll('#', ''),
                                            )
                                            .where((t) => t.isNotEmpty)
                                            .toList();

                                        if (selectedAccount != null) {
                                          if (selectedAccount!
                                                      .outgoingProtocol ==
                                                  'gmail_api' ||
                                              selectedAccount!
                                                      .incomingProtocol ==
                                                  'gmail_api') {
                                            final service = GmailOAuthService();
                                            final remoteSentId = await service
                                                .sendEmail(
                                                  accountId:
                                                      selectedAccount!.id,
                                                  from: selectedAccount!.email,
                                                  to: JwSmtpClient.parseRecipients(
                                                    to,
                                                  ),
                                                  cc: ccList,
                                                  bcc: bccList,
                                                  subject: subject,
                                                  bodyText: bodyText,
                                                  bodyHtml:
                                                      finalHtmlBody.isNotEmpty
                                                      ? finalHtmlBody
                                                      : null,
                                                  attachments: attachments,
                                                );

                                            final now = DateTime.now().toUtc();
                                            final effectiveId =
                                                (remoteSentId != null &&
                                                    remoteSentId.isNotEmpty)
                                                ? remoteSentId
                                                : (existingDraft?.id ??
                                                      const Uuid().v4());
                                            final sentMsg = JwEmailMessage(
                                              id: effectiveId,
                                              accountEmail:
                                                  selectedAccount!.email,
                                              folderName: 'Enviadas',
                                              subject: subject,
                                              from: selectedAccount!.email,
                                              to: to,
                                              cc: ccList,
                                              bcc: bccList,
                                              date: now,
                                              bodyText: bodyText,
                                              bodyHtml: localHtmlBody.isNotEmpty
                                                  ? localHtmlBody
                                                  : null,
                                              attachments: attachments,
                                              isRead: true,
                                              isDraft: false,
                                              isPermanentRetained: true,
                                              tags: tags,
                                            );

                                            final sentEmailMap = sentMsg
                                                .toJson();
                                            if (remoteSentId != null &&
                                                remoteSentId.isNotEmpty) {
                                              sentEmailMap['remoteId'] =
                                                  remoteSentId;
                                            } else {
                                              sentEmailMap['isLocalSentOnly'] =
                                                  true;
                                            }

                                            final metadata = {
                                              'permanentRetention': true,
                                              'isDraft': false,
                                              'sentAt': now.toIso8601String(),
                                              'protocol': 'gmail_api',
                                              'email': sentEmailMap,
                                            };

                                            if (existingDraft != null &&
                                                existingDraft.id !=
                                                    effectiveId) {
                                              final oldDraftKey =
                                                  existingDraft.id.startsWith(
                                                    'email_',
                                                  )
                                                  ? existingDraft.id
                                                  : 'email_${existingDraft.id}';
                                              await (db.delete(db.inboxEntries)
                                                    ..where(
                                                      (t) => t.id.equals(
                                                        oldDraftKey,
                                                      ),
                                                    ))
                                                  .go();
                                            }

                                            final entryId =
                                                'email_${sentMsg.id}';
                                            await db
                                                .into(db.inboxEntries)
                                                .insertOnConflictUpdate(
                                                  InboxEntriesCompanion.insert(
                                                    id: entryId,
                                                    content:
                                                        '${sentMsg.subject}\n\n${sentMsg.bodyText}',
                                                    sourceType:
                                                        const drift.Value(
                                                          'email',
                                                        ),
                                                    suggestedCategory:
                                                        const drift.Value(
                                                          'email',
                                                        ),
                                                    attachments: drift.Value(
                                                      jsonEncode(
                                                        sentMsg.attachments,
                                                      ),
                                                    ),
                                                    capturedAt: now,
                                                    metadata: drift.Value(
                                                      jsonEncode(metadata),
                                                    ),
                                                    createdAt: now,
                                                    updatedAt: now,
                                                  ),
                                                );

                                            for (final rcpt in [
                                              ...JwSmtpClient.parseRecipients(
                                                to,
                                              ),
                                              ...ccList,
                                              ...bccList,
                                            ]) {
                                              await EmailContactsManager.saveContact(
                                                db,
                                                email: rcpt,
                                                source: 'sent_recipient',
                                              );
                                            }

                                            if (ctx.mounted) Navigator.pop(ctx);
                                            if (mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'E-mail enviado via Gmail REST API e arquivado na pasta Enviadas!',
                                                  ),
                                                  backgroundColor: Colors.green,
                                                ),
                                              );
                                            }
                                            return;
                                          }

                                          if (selectedAccount!
                                                      .outgoingProtocol ==
                                                  'microsoft_graph' ||
                                              selectedAccount!
                                                      .incomingProtocol ==
                                                  'microsoft_graph') {
                                            final service =
                                                MicrosoftOAuthService();
                                            await service.sendEmail(
                                              accountId: selectedAccount!.id,
                                              to: JwSmtpClient.parseRecipients(
                                                to,
                                              ),
                                              cc: ccList,
                                              bcc: bccList,
                                              subject: subject,
                                              bodyText: bodyText,
                                              bodyHtml: finalHtmlBody.isNotEmpty
                                                  ? finalHtmlBody
                                                  : null,
                                              attachments: attachments,
                                            );

                                            final now = DateTime.now().toUtc();
                                            final remoteSentId = await service
                                                .findRecentSentMessageId(
                                                  accountId:
                                                      selectedAccount!.id,
                                                  subject: subject,
                                                  sentAfterUtc: now,
                                                );
                                            final effectiveId =
                                                (remoteSentId != null &&
                                                    remoteSentId.isNotEmpty)
                                                ? remoteSentId
                                                : (existingDraft?.id ??
                                                      const Uuid().v4());
                                            final sentMsg = JwEmailMessage(
                                              id: effectiveId,
                                              accountEmail:
                                                  selectedAccount!.email,
                                              folderName: 'Enviadas',
                                              subject: subject,
                                              from: selectedAccount!.email,
                                              to: to,
                                              cc: ccList,
                                              bcc: bccList,
                                              date: now,
                                              bodyText: bodyText,
                                              bodyHtml: localHtmlBody.isNotEmpty
                                                  ? localHtmlBody
                                                  : null,
                                              attachments: attachments,
                                              isRead: true,
                                              isDraft: false,
                                              isPermanentRetained: true,
                                              tags: tags,
                                            );

                                            final sentEmailMap = sentMsg
                                                .toJson();
                                            if (remoteSentId != null &&
                                                remoteSentId.isNotEmpty) {
                                              sentEmailMap['remoteId'] =
                                                  remoteSentId;
                                            } else {
                                              sentEmailMap['isLocalSentOnly'] =
                                                  true;
                                            }

                                            final metadata = {
                                              'permanentRetention': true,
                                              'isDraft': false,
                                              'sentAt': now.toIso8601String(),
                                              'protocol': 'microsoft_graph',
                                              'email': sentEmailMap,
                                            };

                                            if (existingDraft != null &&
                                                existingDraft.id !=
                                                    effectiveId) {
                                              final oldDraftKey =
                                                  existingDraft.id.startsWith(
                                                    'email_',
                                                  )
                                                  ? existingDraft.id
                                                  : 'email_${existingDraft.id}';
                                              await (db.delete(db.inboxEntries)
                                                    ..where(
                                                      (t) => t.id.equals(
                                                        oldDraftKey,
                                                      ),
                                                    ))
                                                  .go();
                                            }

                                            final entryId =
                                                'email_${sentMsg.id}';
                                            await db
                                                .into(db.inboxEntries)
                                                .insertOnConflictUpdate(
                                                  InboxEntriesCompanion.insert(
                                                    id: entryId,
                                                    content:
                                                        '${sentMsg.subject}\n\n${sentMsg.bodyText}',
                                                    sourceType:
                                                        const drift.Value(
                                                          'email',
                                                        ),
                                                    suggestedCategory:
                                                        const drift.Value(
                                                          'email',
                                                        ),
                                                    attachments: drift.Value(
                                                      jsonEncode(
                                                        sentMsg.attachments,
                                                      ),
                                                    ),
                                                    capturedAt: now,
                                                    metadata: drift.Value(
                                                      jsonEncode(metadata),
                                                    ),
                                                    createdAt: now,
                                                    updatedAt: now,
                                                  ),
                                                );

                                            for (final rcpt in [
                                              ...JwSmtpClient.parseRecipients(
                                                to,
                                              ),
                                              ...ccList,
                                              ...bccList,
                                            ]) {
                                              await EmailContactsManager.saveContact(
                                                db,
                                                email: rcpt,
                                                source: 'sent_recipient',
                                              );
                                            }

                                            if (ctx.mounted) Navigator.pop(ctx);
                                            if (mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'E-mail enviado via Microsoft Graph API e arquivado na pasta Enviadas!',
                                                  ),
                                                  backgroundColor: Colors.green,
                                                ),
                                              );
                                            }
                                            return;
                                          }

                                          final pass =
                                              await EmailAccountsManager.getAccountPassword(
                                                selectedAccount!.id,
                                                db,
                                              );
                                          if (pass == null ||
                                              pass.trim().isEmpty) {
                                            if (ctx.mounted) {
                                              setSheetState(() {
                                                isSending = false;
                                                needsConfig = true;
                                                inlineError =
                                                    'Senha não configurada para a conta ${selectedAccount!.name}. Acesse Configurações para validar seu acesso.';
                                              });
                                            }
                                            return;
                                          }

                                          if (selectedAccount!
                                                  .incomingProtocol ==
                                              'exchange') {
                                            final storage =
                                                const FlutterSecureStorage();
                                            final deviceId =
                                                (await storage.read(
                                                  key: 'jw_eas_device_id',
                                                )) ??
                                                const Uuid().v4();
                                            final session =
                                                ExchangeProtocolSession(
                                                  host: selectedAccount!
                                                      .incomingHost,
                                                  username:
                                                      selectedAccount!.username,
                                                  password: pass,
                                                  deviceId: deviceId,
                                                );

                                            await session.sendMail(
                                              to: to,
                                              subject: subject,
                                              body: finalHtmlBody.isNotEmpty
                                                  ? finalHtmlBody
                                                  : bodyText,
                                              from: selectedAccount!.email,
                                              cc: ccList,
                                              bcc: bccList,
                                              attachments: attachments,
                                            );

                                            final now = DateTime.now().toUtc();
                                            final sentMsg = JwEmailMessage(
                                              id:
                                                  existingDraft?.id ??
                                                  const Uuid().v4(),
                                              accountEmail:
                                                  selectedAccount!.email,
                                              folderName: 'Enviados',
                                              subject: subject,
                                              from: selectedAccount!.email,
                                              to: to,
                                              cc: ccList,
                                              bcc: bccList,
                                              date: now,
                                              bodyText: bodyText,
                                              bodyHtml: localHtmlBody.isNotEmpty
                                                  ? localHtmlBody
                                                  : null,
                                              attachments: attachments,
                                              isRead: true,
                                              isDraft: false,
                                              isPermanentRetained: true,
                                              tags: tags,
                                            );

                                            final metadata = {
                                              'permanentRetention': true,
                                              'isDraft': false,
                                              'sentAt': now.toIso8601String(),
                                              'exchangeMail': true,
                                              'email': sentMsg.toJson(),
                                            };

                                            final entryId =
                                                'email_${sentMsg.id}';
                                            await db
                                                .into(db.inboxEntries)
                                                .insertOnConflictUpdate(
                                                  InboxEntriesCompanion.insert(
                                                    id: entryId,
                                                    content:
                                                        '${sentMsg.subject}\n\n${sentMsg.bodyText}',
                                                    sourceType:
                                                        const drift.Value(
                                                          'email',
                                                        ),
                                                    suggestedCategory:
                                                        const drift.Value(
                                                          'email',
                                                        ),
                                                    attachments: drift.Value(
                                                      jsonEncode(
                                                        sentMsg.attachments,
                                                      ),
                                                    ),
                                                    capturedAt: now,
                                                    metadata: drift.Value(
                                                      jsonEncode(metadata),
                                                    ),
                                                    createdAt: now,
                                                    updatedAt: now,
                                                  ),
                                                );

                                            for (final rcpt in [
                                              ...JwSmtpClient.parseRecipients(
                                                to,
                                              ),
                                              ...ccList,
                                              ...bccList,
                                            ]) {
                                              await EmailContactsManager.saveContact(
                                                db,
                                                email: rcpt,
                                                source: 'sent_recipient',
                                              );
                                            }

                                            if (ctx.mounted) Navigator.pop(ctx);
                                            if (mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'E-mail enviado via Exchange (${selectedAccount!.name}) e arquivado na pasta Enviados!',
                                                  ),
                                                  backgroundColor: Colors.green,
                                                ),
                                              );
                                            }
                                            return;
                                          } else {
                                            // Envio via SMTP
                                            final msgToSend = JwEmailMessage(
                                              id:
                                                  existingDraft?.id ??
                                                  const Uuid().v4(),
                                              accountEmail:
                                                  selectedAccount!.email,
                                              folderName: 'Enviados',
                                              subject: subject,
                                              from: selectedAccount!.email,
                                              to: to,
                                              cc: ccList,
                                              bcc: bccList,
                                              date: DateTime.now(),
                                              bodyText: bodyText,
                                              bodyHtml: finalHtmlBody.isNotEmpty
                                                  ? finalHtmlBody
                                                  : null,
                                              attachments: attachments,
                                              isRead: true,
                                              isDraft: false,
                                              tags: tags,
                                            );

                                            await ref
                                                .read(jwEmailServiceProvider)
                                                .sendEmail(
                                                  host: selectedAccount!
                                                      .outgoingHost,
                                                  port: selectedAccount!
                                                      .outgoingPort,
                                                  username:
                                                      selectedAccount!.username,
                                                  password: pass,
                                                  message: msgToSend,
                                                  securityMode: selectedAccount!
                                                      .outgoingSecurity,
                                                  draftId: existingDraft?.id,
                                                );

                                            for (final rcpt in [
                                              ...JwSmtpClient.parseRecipients(
                                                to,
                                              ),
                                              ...ccList,
                                              ...bccList,
                                            ]) {
                                              await EmailContactsManager.saveContact(
                                                db,
                                                email: rcpt,
                                                source: 'sent_recipient',
                                              );
                                            }

                                            if (ctx.mounted) Navigator.pop(ctx);
                                            if (mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'E-mail enviado com sucesso via SMTP (${selectedAccount!.outgoingHost}:${selectedAccount!.outgoingPort}) e arquivado!',
                                                  ),
                                                  backgroundColor: Colors.green,
                                                ),
                                              );
                                            }
                                            return;
                                          }
                                        }

                                        final protocol =
                                            await (db.select(db.appKvStore)
                                                  ..where(
                                                    (t) => t.key.equals(
                                                      'jw_mail_protocol',
                                                    ),
                                                  ))
                                                .getSingleOrNull();

                                        if (protocol?.value == 'exchange') {
                                          final accounts =
                                              await EmailAccountsManager.loadAccounts(
                                                db,
                                              );
                                          final exchangeAccounts = accounts
                                              .where(
                                                (a) =>
                                                    a.isActive &&
                                                    a.incomingProtocol ==
                                                        'exchange',
                                              )
                                              .toList();
                                          final exchangeAcc =
                                              exchangeAccounts.isNotEmpty
                                              ? exchangeAccounts.first
                                              : null;
                                          const secureStore =
                                              FlutterSecureStorage();
                                          final accPass = exchangeAcc != null
                                              ? await secureStore.read(
                                                  key:
                                                      'email_acc_${exchangeAcc.id}_password',
                                                )
                                              : null;
                                          final accDeviceId = await secureStore
                                              .read(key: 'jw_eas_device_id');
                                          final hostEntry =
                                              await (db.select(db.appKvStore)
                                                    ..where(
                                                      (t) => t.key.equals(
                                                        'eas_host',
                                                      ),
                                                    ))
                                                  .getSingleOrNull();
                                          final emailEntry =
                                              await (db.select(db.appKvStore)
                                                    ..where(
                                                      (t) => t.key.equals(
                                                        'eas_email',
                                                      ),
                                                    ))
                                                  .getSingleOrNull();
                                          const secureStorage =
                                              FlutterSecureStorage();
                                          final password = await secureStorage
                                              .read(key: 'eas_password');
                                          final deviceId =
                                              await (db.select(db.appKvStore)
                                                    ..where(
                                                      (t) => t.key.equals(
                                                        'eas_device_id',
                                                      ),
                                                    ))
                                                  .getSingleOrNull();

                                          final resolvedHost =
                                              (exchangeAcc
                                                      ?.incomingHost
                                                      .isNotEmpty ??
                                                  false)
                                              ? exchangeAcc!.incomingHost
                                              : hostEntry?.value;
                                          final resolvedEmail =
                                              (exchangeAcc?.email.isNotEmpty ??
                                                  false)
                                              ? exchangeAcc!.email
                                              : emailEntry?.value;
                                          final resolvedPassword =
                                              (accPass != null &&
                                                  accPass.isNotEmpty)
                                              ? accPass
                                              : password;
                                          final resolvedDeviceId =
                                              (accDeviceId != null &&
                                                  accDeviceId.isNotEmpty)
                                              ? accDeviceId
                                              : (deviceId?.value.isNotEmpty ==
                                                        true
                                                    ? deviceId!.value
                                                    : (exchangeAcc != null
                                                          ? const Uuid().v4()
                                                          : null));
                                          if (resolvedHost == null ||
                                              resolvedHost.isEmpty ||
                                              resolvedEmail == null ||
                                              resolvedEmail.isEmpty ||
                                              resolvedPassword == null ||
                                              resolvedPassword.isEmpty ||
                                              resolvedDeviceId == null ||
                                              resolvedDeviceId.isEmpty) {
                                            if (ctx.mounted) {
                                              setSheetState(() {
                                                isSending = false;
                                                needsConfig = true;
                                                inlineError = 'Credenciais do Exchange não configuradas. Acesse Configurações para validar seu acesso.';
                                              });
                                            }
                                            return;
                                          }

                                          final session =
                                              ExchangeProtocolSession(
                                                host: resolvedHost,
                                                username: resolvedEmail,
                                                password: resolvedPassword,
                                                deviceId: resolvedDeviceId,
                                              );

                                          await session.sendMail(
                                            to: to,
                                            subject: subject,
                                            body: bodyText,
                                            cc: ccList,
                                            bcc: bccList,
                                            attachments: attachments,
                                          );

                                          final now = DateTime.now().toUtc();
                                          final sentMsg = JwEmailMessage(
                                            id:
                                                existingDraft?.id ??
                                                const Uuid().v4(),
                                            folderName: 'Enviados',
                                            subject: subject,
                                            from: resolvedEmail,
                                            to: to,
                                            cc: ccList,
                                            bcc: bccList,
                                            date: now,
                                            bodyText: bodyText,
                                            attachments: attachments,
                                            isRead: true,
                                            isDraft: false,
                                            isPermanentRetained: true,
                                            tags: tags,
                                          );

                                          final isExchange =
                                              selectedAccount
                                                  ?.incomingProtocol ==
                                              'exchange';
                                          final metadata = {
                                            'permanentRetention': true,
                                            'isDraft': false,
                                            'sentAt': now.toIso8601String(),
                                            'exchangeMail': isExchange,
                                            'email': sentMsg.toJson(),
                                            'protocol':
                                                selectedAccount
                                                    ?.incomingProtocol ??
                                                'smtp',
                                          };

                                          final entryId = 'email_${sentMsg.id}';
                                          await db
                                              .into(db.inboxEntries)
                                              .insertOnConflictUpdate(
                                                InboxEntriesCompanion.insert(
                                                  id: entryId,
                                                  content:
                                                      '${sentMsg.subject}\n\n${sentMsg.bodyText}',
                                                  sourceType: const drift.Value(
                                                    'email',
                                                  ),
                                                  suggestedCategory:
                                                      drift.Value(
                                                        isExchange
                                                            ? 'email_jw'
                                                            : 'email',
                                                      ),
                                                  attachments: drift.Value(
                                                    jsonEncode(
                                                      sentMsg.attachments,
                                                    ),
                                                  ),
                                                  capturedAt: now,
                                                  metadata: drift.Value(
                                                    jsonEncode(metadata),
                                                  ),
                                                  createdAt: now,
                                                  updatedAt: now,
                                                ),
                                              );

                                          for (final rcpt in [
                                            ...JwSmtpClient.parseRecipients(to),
                                            ...ccList,
                                            ...bccList,
                                          ]) {
                                            await EmailContactsManager.saveContact(
                                              db,
                                              email: rcpt,
                                              source: 'sent_recipient',
                                            );
                                          }

                                          if (ctx.mounted) Navigator.pop(ctx);
                                          if (mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'E-mail enviado via Exchange e arquivado na pasta Enviados!',
                                                ),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                          }
                                          return;
                                        }

                                        // Envio via SMTP
                                        final emailEntry =
                                            await (db.select(db.appKvStore)
                                                  ..where(
                                                    (t) => t.key.equals(
                                                      'jw_imap_email',
                                                    ),
                                                  ))
                                                .getSingleOrNull();
                                        const secureStorage =
                                            FlutterSecureStorage();
                                        String? password = await secureStorage
                                            .read(key: 'jw_imap_password');
                                        if (password == null ||
                                            password.isEmpty) {
                                          final legacyPass =
                                              await (db.select(db.appKvStore)
                                                    ..where(
                                                      (t) => t.key.equals(
                                                        'jw_imap_password',
                                                      ),
                                                    ))
                                                  .getSingleOrNull();
                                          password = legacyPass?.value;
                                        }
                                        final username =
                                            emailEntry?.value.trim() ?? '';
                                        if (username.isEmpty ||
                                            password == null ||
                                            password.isEmpty) {
                                          if (ctx.mounted) {
                                            setSheetState(() {
                                              isSending = false;
                                              needsConfig = true;
                                              inlineError = 'Credenciais IMAP/SMTP não configuradas. Configure seu e-mail e senha teocráticos em Configurações antes de enviar.';
                                            });
                                          }
                                          return;
                                        }

                                        final smtpHostEntry =
                                            await (db.select(db.appKvStore)
                                                  ..where(
                                                    (t) => t.key.equals(
                                                      'jw_smtp_host',
                                                    ),
                                                  ))
                                                .getSingleOrNull();
                                        final imapHostEntry =
                                            await (db.select(db.appKvStore)
                                                  ..where(
                                                    (t) => t.key.equals(
                                                      'jw_imap_host',
                                                    ),
                                                  ))
                                                .getSingleOrNull();
                                        final smtpPortEntry =
                                            await (db.select(db.appKvStore)
                                                  ..where(
                                                    (t) => t.key.equals(
                                                      'jw_smtp_port',
                                                    ),
                                                  ))
                                                .getSingleOrNull();
                                        final smtpSecEntry =
                                            await (db.select(db.appKvStore)
                                                  ..where(
                                                    (t) => t.key.equals(
                                                      'jw_smtp_security',
                                                    ),
                                                  ))
                                                .getSingleOrNull();

                                        final smtpHost =
                                            (smtpHostEntry?.value
                                                    .trim()
                                                    .isNotEmpty ==
                                                true)
                                            ? smtpHostEntry!.value.trim()
                                            : ((imapHostEntry?.value
                                                          .trim()
                                                          .isNotEmpty ==
                                                      true)
                                                  ? imapHostEntry!.value.trim()
                                                  : 'mail.jw.org');
                                        final securityMode =
                                            (smtpSecEntry?.value
                                                    .trim()
                                                    .isNotEmpty ==
                                                true)
                                            ? smtpSecEntry!.value.trim()
                                            : 'starttls';
                                        final smtpPort =
                                            int.tryParse(
                                              smtpPortEntry?.value ?? '',
                                            ) ??
                                            (securityMode == 'ssl' ? 465 : 587);

                                        final msgToSend = JwEmailMessage(
                                          id:
                                              existingDraft?.id ??
                                              const Uuid().v4(),
                                          folderName: 'Enviados',
                                          subject: subject,
                                          from: username,
                                          to: to,
                                          cc: ccList,
                                          bcc: bccList,
                                          date: DateTime.now(),
                                          bodyText: bodyText,
                                          attachments: attachments,
                                          isRead: true,
                                          isDraft: false,
                                          tags: tags,
                                        );

                                        await ref
                                            .read(jwEmailServiceProvider)
                                            .sendEmail(
                                              host: smtpHost,
                                              port: smtpPort,
                                              username: username,
                                              password: password,
                                              message: msgToSend,
                                              securityMode: securityMode,
                                              draftId: existingDraft?.id,
                                            );

                                        for (final rcpt in [
                                          ...JwSmtpClient.parseRecipients(to),
                                          ...ccList,
                                          ...bccList,
                                        ]) {
                                          await EmailContactsManager.saveContact(
                                            db,
                                            email: rcpt,
                                            source: 'sent_recipient',
                                          );
                                        }

                                        if (ctx.mounted) Navigator.pop(ctx);
                                        if (mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'E-mail enviado com sucesso via SMTP ($smtpHost:$smtpPort) e arquivado!',
                                              ),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                        }
                                      } catch (e, st) {
                                        AppLogger.warning(
                                          'Falha ao enviar e-mail',
                                          e,
                                          st,
                                        );
                                        if (ctx.mounted) {
                                          setSheetState(() {
                                            isSending = false;
                                            needsConfig =
                                                e is JwEmailAuthException;
                                            inlineError =
                                                'Falha no envio de e-mail: $e';
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
              );
            },
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
      await ref
          .read(taskManagerProvider)
          .createTask(
            title: msg.subject,
            description:
                'E-mail de ${msg.from}:\n\n${EmailHtmlSanitizer.stripMarkdown(msg.bodyText)}',
            priority: 'normal',
            category: 'ministry',
            tags: msg.tags,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('E-mail convertido em Tarefa com sucesso!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao converter: $e')));
      }
    }
  }

  Future<void> _convertEmailToResearch(JwEmailMessage msg) async {
    try {
      await ref
          .read(researchManagerProvider)
          .addArticle(
            title: msg.subject,
            summary: 'Correspondência JW de ${msg.from}',
            content: EmailHtmlSanitizer.stripMarkdown(msg.bodyText),
            tags: msg.tags.isNotEmpty ? msg.tags : ['email_retido'],
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Correspondência convertida em Artigo de Pesquisa!'),
          ),
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

  JwEmailMessage _captureEntryToJwEmail(InboxEntry entry) {
    if (entry.metadata.isNotEmpty) {
      try {
        final decoded = jsonDecode(entry.metadata);
        if (decoded is Map<String, dynamic> && decoded['email'] is Map) {
          final emailMap = Map<String, dynamic>.from(decoded['email'] as Map);
          return JwEmailMessage.fromJson(emailMap);
        }
      } catch (_) {}
    }
    final lines = entry.content.trim().split('\n');
    final subject = lines.isNotEmpty && lines.first.trim().isNotEmpty
        ? lines.first.trim()
        : 'E-mail capturado';
    final body = lines.length > 1
        ? lines.sublist(1).join('\n').trim()
        : entry.content.trim();
    return JwEmailMessage(
      id: entry.id,
      subject: subject,
      from: _extractCaptureAccountEmail(entry) ?? 'Remetente desconhecido',
      to: '',
      accountEmail: _extractCaptureAccountEmail(entry),
      date: entry.capturedAt,
      bodyText: body,
      attachments: _parseJsonList(entry.attachments),
      isRead: true,
    );
  }

  Future<void> _openEmailAndMarkRead(
    JwEmailMessage msg,
    List<EmailAccount> accounts, {
    required bool isMasterDetail,
    bool openModalInstead = false,
    bool isHub = false,
  }) async {
    setState(() {
      _selectedEmailId = msg.id;
      _stickyOpenedEmailId = msg.id;
      if (!msg.isRead) {
        _cachedEmails = _cachedEmails
            .map((e) => e.id == msg.id ? e.copyWith(isRead: true) : e)
            .toList();
      }
    });

    final openedMsg = msg.isRead ? msg : msg.copyWith(isRead: true);
    if (!msg.isRead) {
      unawaited(
        _markEmailsReadStatus([msg], isRead: true, showFeedback: false),
      );
    }

    if (openModalInstead) {
      _showEmailDetailsModal(context, openedMsg, accounts);
    } else if (!isMasterDetail) {
      _openEmailReaderScreen(context, openedMsg, accounts);
    }
  }

  Future<void> _reconnectAccountFromInbox(EmailAccount acc) async {
    try {
      final db = ref.read(repositoryProvider).db;
      OAuthTokenBundle? newBundle;
      if (acc.isGmailApi) {
        final res = await GmailOAuthService().authenticateUser();
        newBundle = res?.tokenBundle;
      } else if (acc.isMicrosoftGraph) {
        final res = await MicrosoftOAuthService().authenticateUser();
        newBundle = res?.tokenBundle;
      }
      if (newBundle == null) return;
      await const OAuthTokenStore().saveTokenBundle(acc.id, newBundle);
      _lastAuthWarnAt.remove(acc.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${acc.name} reconectada! Sincronizando alterações pendentes...',
          ),
          backgroundColor: AppTheme.successGreen,
        ),
      );
      unawaited(
        EmailSyncCoordinator(
          db,
          jwEmailService: ref.read(jwEmailServiceProvider),
        ).syncAll(interactive: true),
      );
    } catch (e, st) {
      AppLogger.warning('Falha ao reconectar conta ${acc.name}', e, st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Não foi possível reconectar ${acc.name}: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _showSyncOrMutationErrorSnackBar({
    required List<String> warnings,
    bool passive = false,
    bool isError = false,
    Duration duration = const Duration(seconds: 4),
    String prefix = '',
  }) async {
    if (!mounted || warnings.isEmpty) return;
    final primaryText = warnings.first;
    final lower = primaryText.toLowerCase();
    final isAuthIssue =
        lower.contains('expirad') ||
        lower.contains('autentica') ||
        lower.contains('reconectar') ||
        lower.contains('401') ||
        lower.contains('token');

    EmailAccount? matchedOAuthAcc;
    if (isAuthIssue) {
      final db = ref.read(repositoryProvider).db;
      final accounts = _cachedAccounts.isNotEmpty
          ? _cachedAccounts
          : await EmailAccountsManager.loadAccounts(db);
      for (final acc in accounts) {
        if (!acc.isOAuth) continue;
        if (lower.contains(acc.name.toLowerCase()) ||
            lower.contains(acc.email.toLowerCase()) ||
            (acc.isGmailApi && lower.contains('gmail')) ||
            (acc.isMicrosoftGraph &&
                (lower.contains('microsoft') ||
                    lower.contains('outlook') ||
                    lower.contains('hotmail')))) {
          matchedOAuthAcc = acc;
          break;
        }
      }
      if (passive && matchedOAuthAcc != null) {
        final lastAt = _lastAuthWarnAt[matchedOAuthAcc.id];
        if (lastAt != null &&
            DateTime.now().difference(lastAt) < const Duration(seconds: 30)) {
          return;
        }
        _lastAuthWarnAt[matchedOAuthAcc.id] = DateTime.now();
      }
    }

    if (!mounted) return;
    final displayText = prefix.isNotEmpty ? '$prefix$primaryText' : primaryText;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(displayText),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Colors.orange.shade800,
        duration: duration,
        action: matchedOAuthAcc != null
            ? SnackBarAction(
                label: 'Reconectar',
                textColor: Colors.white,
                onPressed: () => _reconnectAccountFromInbox(matchedOAuthAcc!),
              )
            : null,
      ),
    );
  }

  Future<void> _markEmailsReadStatus(
    List<JwEmailMessage> targets, {
    required bool isRead,
    bool showFeedback = true,
  }) async {
    if (targets.isEmpty) return;
    try {
      final db = ref.read(repositoryProvider).db;
      final coordinator = EmailSyncCoordinator(
        db,
        jwEmailService: ref.read(jwEmailServiceProvider),
      );
      final res = await coordinator.updateReadStatus(
        targets,
        isRead: isRead,
        interactive: showFeedback,
      );
      if (!mounted) return;
      if (showFeedback) {
        setState(() {
          _isEmailSelectionMode = false;
          _selectedEmailIds.clear();
        });
      }
      if (res.warnings.isNotEmpty) {
        await _showSyncOrMutationErrorSnackBar(
          warnings: res.warnings,
          passive: !showFeedback,
        );
      } else if (showFeedback) {
        final label = isRead ? 'lida(s)' : 'não lida(s)';
        final syncSuffix = res.remoteSynced > 0
            ? ' e sincronizada(s) com o servidor.'
            : (res.hasReadOnlyAccountNotice
                  ? ' (conta Exchange/Hub permanece somente leitura no servidor).'
                  : '.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${targets.length} mensagem(ns) marcada(s) como $label$syncSuffix',
            ),
          ),
        );
      }
    } catch (e, st) {
      AppLogger.warning('Falha ao atualizar status de leitura', e, st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erro ao atualizar leitura: ${_friendlySyncError(e)}',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _showMoveToFolderDialog(List<JwEmailMessage> targets) async {
    if (targets.isEmpty) return;
    const folders = [
      ('Caixa de Entrada', Icons.inbox_outlined),
      ('Enviadas', Icons.send_outlined),
      ('Rascunhos', Icons.drafts_outlined),
      ('Spam', Icons.report_gmailerrorred_outlined),
      ('Lixeira', Icons.delete_outline),
    ];
    final destination = await showDialog<String>(
      context: context,
      builder: (dlgCtx) => SimpleDialog(
        title: Text(
          targets.length == 1
              ? 'Mover e-mail para pasta'
              : 'Mover ${targets.length} e-mails para pasta',
        ),
        children: folders.map((item) {
          return SimpleDialogOption(
            key: Key('opt_move_folder_${item.$1}'),
            onPressed: () => Navigator.pop(dlgCtx, item.$1),
            child: Row(
              children: [
                Icon(item.$2, size: 18, color: AppTheme.primaryBlue),
                const SizedBox(width: 12),
                Text(item.$1),
              ],
            ),
          );
        }).toList(),
      ),
    );
    if (destination == null || !mounted) return;

    try {
      final db = ref.read(repositoryProvider).db;
      final coordinator = EmailSyncCoordinator(
        db,
        jwEmailService: ref.read(jwEmailServiceProvider),
      );
      final res = await coordinator.moveMessagesToFolder(
        targets,
        targetFolderName: destination,
        interactive: true,
      );
      if (!mounted) return;
      setState(() {
        _isEmailSelectionMode = false;
        _selectedEmailIds.clear();
        if (targets.any((m) => m.id == _selectedEmailId)) {
          _stickyOpenedEmailId = null;
        }
      });
      if (res.warnings.isNotEmpty) {
        await _showSyncOrMutationErrorSnackBar(
          warnings: res.warnings,
          prefix:
              '${targets.length} mensagem(ns) movida(s) para "$destination". ',
        );
      } else {
        final syncNote = res.remoteSynced > 0
            ? ' e atualizado no servidor.'
            : (res.hasReadOnlyAccountNotice
                  ? ' (movido localmente; servidor Exchange/Hub somente leitura).'
                  : '.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${targets.length} mensagem(ns) movida(s) para "$destination"$syncNote',
            ),
          ),
        );
      }
    } catch (e, st) {
      AppLogger.warning('Falha ao mover e-mails para $destination', e, st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao mover pasta: ${_friendlySyncError(e)}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteEmailsWithConfirm(List<JwEmailMessage> targets) async {
    if (targets.isEmpty) return;
    final allInTrash = targets.every((m) => m.folderName == 'Lixeira');
    final isSingle = targets.length == 1;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: Text(
          allInTrash
              ? (isSingle
                    ? 'Excluir permanentemente?'
                    : 'Excluir ${targets.length} permanentemente?')
              : (isSingle
                    ? 'Excluir e-mail?'
                    : 'Excluir ${targets.length} e-mails?'),
        ),
        content: Text(
          allInTrash
              ? 'As mensagens já estão na Lixeira e serão removidas permanentemente do aplicativo e do servidor.'
              : 'As mensagens serão movidas para a Lixeira local e no servidor conectado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('btn_confirm_delete_emails'),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dlgCtx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    try {
      final db = ref.read(repositoryProvider).db;
      final coordinator = EmailSyncCoordinator(
        db,
        jwEmailService: ref.read(jwEmailServiceProvider),
      );
      final res = await coordinator.deleteMessages(targets, interactive: true);
      if (!mounted) return;
      setState(() {
        _isEmailSelectionMode = false;
        _selectedEmailIds.clear();
        if (targets.any((m) => m.id == _selectedEmailId)) {
          _selectedEmailId = null;
          _stickyOpenedEmailId = null;
        }
      });
      final msg = allInTrash
          ? '${targets.length} e-mail(s) excluído(s) definitivamente.'
          : '${targets.length} e-mail(s) movido(s) para a Lixeira.';
      if (res.warnings.isNotEmpty) {
        await _showSyncOrMutationErrorSnackBar(
          warnings: res.warnings,
          prefix: '$msg ',
        );
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e, st) {
      AppLogger.warning('Falha ao excluir e-mails', e, st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao excluir e-mails: ${_friendlySyncError(e)}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteEmail(JwEmailMessage msg) async {
    await _deleteEmailsWithConfirm([msg]);
  }

  static String _extractLastRecipientToken(String text) {
    if (text.isEmpty) return '';
    final parts = text.split(',');
    return parts.last.trim();
  }

  static void _applyRecipientSuggestion(
    TextEditingController ctrl,
    String email,
  ) {
    final raw = ctrl.text;
    final parts = raw
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isNotEmpty) {
      final last = parts.last;
      if (!last.contains('@') || !last.endsWith('.')) {
        parts.removeLast();
      }
    }
    if (!parts.contains(email)) {
      parts.add(email);
    }
    ctrl.text = parts.join(', ');
  }
}

/// Visualizador profissional de corpo de e-mail com tipografia limpa,
/// blocos estilizados de respostas (> citação) e limpeza garantida de tags de markdown.
class _ProfessionalEmailBodyView extends StatefulWidget {
  final String text;
  final String? html;
  final bool isDark;
  final List<Map<String, dynamic>> attachments;

  const _ProfessionalEmailBodyView({
    required this.text,
    this.html,
    required this.isDark,
    this.attachments = const [],
  });

  @override
  State<_ProfessionalEmailBodyView> createState() =>
      _ProfessionalEmailBodyViewState();
}

class _ProfessionalEmailBodyViewState
    extends State<_ProfessionalEmailBodyView> {
  final List<GestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  static String _cleanHtmlAndEntities(String raw) {
    return EmailHtmlSanitizer.extractPlainText(raw);
  }

  List<InlineSpan> _parseSpans(String rawText, TextStyle baseStyle) {
    final cleaned = _cleanHtmlAndEntities(rawText);
    final spans = <InlineSpan>[];
    final tokenRegex = RegExp(
      r'(\*\*\*([^\*]+?)\*\*\*)'
      r'|(\*\*([^\*]+?)\*\*)'
      r'|((?<!\*)\*([^\*\s\n](?:[^\*\n]*?[^\*\s\n])?)\*(?!\*))'
      r'|((?<!\w)___([^_]+?)___(?!\w))'
      r'|((?<!\w)__([^_]+?)__(?!\w))'
      r'|((?<!\w)_([^_ \n\t]+(?:\s+[^_ \n\t]+)*)_(?!\w))'
      r'|(`([^`]+?)`)'
      r'|(\[([^\]]+)\]\(([^\)]+)\))',
    );

    int lastEnd = 0;
    for (final m in tokenRegex.allMatches(cleaned)) {
      if (m.start > lastEnd) {
        final plain = cleaned.substring(lastEnd, m.start).replaceAll('**', '');
        if (plain.isNotEmpty) {
          spans.add(TextSpan(text: plain, style: baseStyle));
        }
      }
      if (m.group(2) != null) {
        spans.add(
          TextSpan(
            text: m.group(2)!,
            style: baseStyle.copyWith(
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
            ),
          ),
        );
      } else if (m.group(4) != null) {
        spans.add(
          TextSpan(
            text: m.group(4)!,
            style: baseStyle.copyWith(fontWeight: FontWeight.bold),
          ),
        );
      } else if (m.group(6) != null) {
        spans.add(
          TextSpan(
            text: m.group(6)!,
            style: baseStyle.copyWith(fontStyle: FontStyle.italic),
          ),
        );
      } else if (m.group(8) != null) {
        spans.add(
          TextSpan(
            text: m.group(8)!,
            style: baseStyle.copyWith(
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
            ),
          ),
        );
      } else if (m.group(10) != null) {
        spans.add(
          TextSpan(
            text: m.group(10)!,
            style: baseStyle.copyWith(fontWeight: FontWeight.bold),
          ),
        );
      } else if (m.group(12) != null) {
        spans.add(
          TextSpan(
            text: m.group(12)!,
            style: baseStyle.copyWith(fontStyle: FontStyle.italic),
          ),
        );
      } else if (m.group(14) != null) {
        spans.add(
          TextSpan(
            text: m.group(14)!,
            style: baseStyle.copyWith(
              fontFamily: 'monospace',
              backgroundColor: baseStyle.color?.withValues(alpha: 0.08),
            ),
          ),
        );
      } else if (m.group(16) != null) {
        final url = m.group(17) ?? '';
        TapGestureRecognizer? rec;
        if (url.isNotEmpty) {
          rec = TapGestureRecognizer()
            ..onTap = () => AppReferenceViewer.openUrl(context, url);
          _recognizers.add(rec);
        }
        spans.add(
          TextSpan(
            text: m.group(16)!,
            recognizer: rec,
            style: baseStyle.copyWith(
              color: AppTheme.primaryBlue,
              decoration: TextDecoration.underline,
            ),
          ),
        );
      }
      lastEnd = m.end;
    }

    if (lastEnd < cleaned.length) {
      final plain = cleaned.substring(lastEnd).replaceAll('**', '');
      if (plain.isNotEmpty) {
        spans.add(TextSpan(text: plain, style: baseStyle));
      }
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final isDark = widget.isDark;
    final html = widget.html;
    final text = widget.text;
    final attachments = widget.attachments;
    final baseStyle = TextStyle(
      fontSize: 14.5,
      height: 1.55,
      letterSpacing: 0.15,
      color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
    );

    if (html != null && html.trim().isNotEmpty) {
      final cleanHtml = EmailHtmlSanitizer.sanitizeHtmlForDisplay(html);
      if (cleanHtml.isNotEmpty) {
        return EmailHtmlFrame(html: html, attachments: attachments);
      }
    }

    final cleanFull = _cleanHtmlAndEntities(text).trim();
    if (cleanFull.isEmpty) {
      return Text(
        '(Mensagem sem conteúdo textual)',
        style: TextStyle(
          fontStyle: FontStyle.italic,
          color: Colors.grey.shade500,
        ),
      );
    }

    final paragraphs = cleanFull.split(RegExp(r'\n{2,}'));

    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final p in paragraphs) ...[
            if (p.trim().startsWith('>'))
              Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B).withValues(alpha: 0.7)
                      : const Color(0xFFF1F5F9),
                  border: const Border(
                    left: BorderSide(color: Color(0xFF94A3B8), width: 3.5),
                  ),
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(6),
                  ),
                ),
                child: Text.rich(
                  TextSpan(
                    children: _parseSpans(
                      p
                          .replaceAll(RegExp(r'^>\s*', multiLine: true), '')
                          .trim(),
                      baseStyle.copyWith(
                        fontStyle: FontStyle.italic,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text.rich(
                  TextSpan(children: _parseSpans(p.trim(), baseStyle)),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
