import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_logger.dart';
import '../../../core/app_theme.dart';
import '../../../database/app_database.dart';
import '../../../sync/supabase_sync_service.dart';
import '../../providers.dart';

/// Modal avançado para gestão da fila de sincronização (pendentes, falhas e conflitos).
class SyncQueueManagementSheet extends ConsumerStatefulWidget {
  const SyncQueueManagementSheet({super.key});

  @override
  ConsumerState<SyncQueueManagementSheet> createState() =>
      _SyncQueueManagementSheetState();
}

class _SyncQueueManagementSheetState
    extends ConsumerState<SyncQueueManagementSheet> {
  List<SyncQueueEntry> _items = const [];
  String _filter = 'all';
  bool _loading = true;
  bool _busy = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _loadQueue();
  }

  Future<void> _loadQueue() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final list = await ref
          .read(repositoryProvider)
          .getUnresolvedSyncOperations();
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e, st) {
      AppLogger.error('Erro ao carregar fila de sincronização', e, st);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _statusMessage = 'Erro ao carregar fila: $e';
      });
    }
  }

  Future<void> _retryOne(SyncQueueEntry op) async {
    setState(() => _busy = true);
    try {
      final repo = ref.read(repositoryProvider);
      await repo.retrySyncOperation(op.id);
      if (SupabaseSyncService.isInitialized) {
        final res = await ref.read(supabaseSyncServiceProvider).sync();
        _statusMessage = res.message;
      } else {
        _statusMessage = 'Operação marcada como pendente para reenvio.';
      }
      await _loadQueue();
    } catch (e, st) {
      AppLogger.error('Erro ao reprocessar operação ${op.id}', e, st);
      if (mounted) {
        setState(() => _statusMessage = 'Falha ao reprocessar: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _retryAllFailed() async {
    setState(() => _busy = true);
    try {
      final repo = ref.read(repositoryProvider);
      final count = await repo.retryAllFailedOperations();
      if (SupabaseSyncService.isInitialized) {
        final res = await ref.read(supabaseSyncServiceProvider).sync();
        _statusMessage = '$count reativada(s). ${res.message}';
      } else {
        _statusMessage = '$count operação(ões) marcada(s) como pendente(s).';
      }
      await _loadQueue();
    } catch (e, st) {
      AppLogger.error('Erro ao reprocessar falhas em lote', e, st);
      if (mounted) {
        setState(() => _statusMessage = 'Falha ao reprocessar: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resolveKeepLocal(SyncQueueEntry op) async {
    setState(() => _busy = true);
    try {
      await ref.read(repositoryProvider).resolveSyncConflictKeepLocal(op.id);
      if (SupabaseSyncService.isInitialized) {
        final res = await ref.read(supabaseSyncServiceProvider).sync();
        _statusMessage = 'Versão local mantida. ${res.message}';
      } else {
        _statusMessage = 'Versão local selecionada e enfileirada para envio.';
      }
      await _loadQueue();
    } catch (e, st) {
      AppLogger.error(
        'Erro ao resolver conflito mantendo local ${op.id}',
        e,
        st,
      );
      if (mounted) {
        setState(() => _statusMessage = 'Erro ao resolver conflito: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resolveAcceptRemote(SyncQueueEntry op) async {
    setState(() => _busy = true);
    try {
      final ok = await ref
          .read(supabaseSyncServiceProvider)
          .resolveConflictAcceptRemote(op.id);
      _statusMessage = ok
          ? 'Versão remota aplicada localmente com sucesso.'
          : 'Não foi possível obter os dados remotos deste registro.';
      await _loadQueue();
    } catch (e, st) {
      AppLogger.error('Erro ao aceitar versão remota ${op.id}', e, st);
      if (mounted) {
        setState(() => _statusMessage = 'Erro ao aplicar versão remota: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<Map<String, String>> _extractConflictFields(SyncQueueEntry op) {
    final diffs = <Map<String, String>>[];
    try {
      final raw = jsonDecode(op.payload);
      if (raw is! Map<String, dynamic>) return diffs;
      final explicit = raw['_conflicts'];
      if (explicit is List) {
        for (final item in explicit) {
          if (item is Map) {
            diffs.add({
              'field': '${item['fieldName'] ?? item['field'] ?? 'campo'}',
              'local': '${item['local'] ?? item['localValue'] ?? ''}',
              'remote': '${item['remote'] ?? item['remoteValue'] ?? ''}',
            });
          }
        }
      }
      if (diffs.isEmpty && raw['_remote'] is Map) {
        final remote = Map<String, dynamic>.from(raw['_remote'] as Map);
        const ignored = {
          '_remote',
          '_conflicts',
          '_base',
          'id',
          'user_id',
          'userId',
        };
        for (final key in remote.keys) {
          if (ignored.contains(key)) continue;
          final rVal = remote[key]?.toString() ?? '';
          final lVal = (raw[key] ?? '')?.toString() ?? '';
          if (lVal != rVal) {
            diffs.add({'field': key, 'local': lVal, 'remote': rVal});
          }
        }
      }
    } catch (e, st) {
      AppLogger.warning('Falha ao extrair diff de conflito de ${op.id}', e, st);
    }
    return diffs;
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _items
        .where((i) => i.status == 'pending' || i.status == 'in_progress')
        .length;
    final failedCount = _items.where((i) => i.status == 'failed').length;
    final conflictCount = _items.where((i) => i.status == 'conflict').length;
    final filtered = _items.where((i) {
      if (_filter == 'all') return true;
      if (_filter == 'pending') {
        return i.status == 'pending' || i.status == 'in_progress';
      }
      return i.status == _filter;
    }).toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: const Text(
                        'Fila de Sincronização (Sync Queue)',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Atualizar fila de sincronização',
                    child: IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Atualizar',
                      onPressed: _busy ? null : _loadQueue,
                    ),
                  ),
                ],
              ),
              if (_statusMessage != null) ...[
                const SizedBox(height: 4),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _statusMessage!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ChoiceChip(
                    label: Text('Todos (${_items.length})'),
                    selected: _filter == 'all',
                    onSelected: (_) => setState(() => _filter = 'all'),
                  ),
                  ChoiceChip(
                    label: Text('Pendentes ($pendingCount)'),
                    selected: _filter == 'pending',
                    onSelected: (_) => setState(() => _filter = 'pending'),
                  ),
                  ChoiceChip(
                    label: Text('Falhas ($failedCount)'),
                    selected: _filter == 'failed',
                    onSelected: (_) => setState(() => _filter = 'failed'),
                  ),
                  ChoiceChip(
                    label: Text('Conflitos ($conflictCount)'),
                    selected: _filter == 'conflict',
                    onSelected: (_) => setState(() => _filter = 'conflict'),
                  ),
                ],
              ),
              if (failedCount > 0 || SupabaseSyncService.isInitialized) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (failedCount > 0)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.alertAmber,
                          foregroundColor: Colors.black87,
                        ),
                        onPressed: _busy ? null : _retryAllFailed,
                        icon: const Icon(Icons.replay, size: 16),
                        label: Text('Reprocessar $failedCount Falha(s)'),
                      ),
                    if (SupabaseSyncService.isInitialized && _items.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () async {
                                setState(() => _busy = true);
                                try {
                                  final res = await ref
                                      .read(supabaseSyncServiceProvider)
                                      .sync();
                                  _statusMessage = res.message;
                                  await _loadQueue();
                                } finally {
                                  if (mounted) setState(() => _busy = false);
                                }
                              },
                        icon: const Icon(Icons.sync, size: 16),
                        label: const Text('Sincronizar Agora'),
                      ),
                  ],
                ),
              ],
              const Divider(height: 16),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : filtered.isEmpty
                    ? const Center(
                        child: Text(
                          'Nenhum item pendente, com falha ou conflito neste filtro.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final op = filtered[index];
                          final isConflict = op.status == 'conflict';
                          final isFailed = op.status == 'failed';
                          final badgeColor = isConflict
                              ? AppTheme.alertAmber
                              : isFailed
                              ? AppTheme.alertRed
                              : AppTheme.primaryBlue;
                          final badgeLabel = isConflict
                              ? 'CONFLITO'
                              : isFailed
                              ? 'FALHA'
                              : 'PENDENTE';
                          final diffs = isConflict
                              ? _extractConflictFields(op)
                              : const <Map<String, String>>[];

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: badgeColor.withValues(
                                            alpha: 0.16,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          badgeLabel,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: isConflict
                                                ? Colors.orange.shade900
                                                : badgeColor,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${op.entityType} • ${op.operation}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        'Tentativas: ${op.attempts}',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'ID: ${op.entityId}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  if (op.lastError != null &&
                                      op.lastError!.trim().isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      op.lastError!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isConflict
                                            ? Colors.orange.shade900
                                            : AppTheme.alertRed,
                                      ),
                                    ),
                                  ],
                                  if (diffs.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Campos divergentes:',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          for (final d in diffs.take(6))
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 2,
                                              ),
                                              child: Text(
                                                '• ${d['field']}: Local="${d['local']}" vs Remoto="${d['remote']}"',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      if (isConflict) ...[
                                        ElevatedButton.icon(
                                          onPressed: _busy
                                              ? null
                                              : () => _resolveKeepLocal(op),
                                          icon: const Icon(
                                            Icons.upload,
                                            size: 16,
                                          ),
                                          label: const Text('Manter Local'),
                                        ),
                                        OutlinedButton.icon(
                                          onPressed: _busy
                                              ? null
                                              : () => _resolveAcceptRemote(op),
                                          icon: const Icon(
                                            Icons.download,
                                            size: 16,
                                          ),
                                          label: const Text('Aceitar Remoto'),
                                        ),
                                      ] else
                                        OutlinedButton.icon(
                                          onPressed: _busy
                                              ? null
                                              : () => _retryOne(op),
                                          icon: const Icon(
                                            Icons.refresh,
                                            size: 16,
                                          ),
                                          label: Text(
                                            isFailed
                                                ? 'Reprocessar'
                                                : 'Tentar Enviar Agora',
                                          ),
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
      },
    );
  }
}
