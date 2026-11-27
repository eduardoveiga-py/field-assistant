import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart' as digest;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../core/app_logger.dart';

/// Coordenador leve de notificações Realtime E2EE zero-plaintext.
/// Combina um canal Broadcast por conta autenticada (funciona sem DDL extra)
/// e `postgres_changes` em `public.encrypted_records` (protegido por RLS) para
/// acordar os demais dispositivos em ~1 segundo após um envio bem-sucedido.
class RealtimeSyncNotifier {
  RealtimeSyncNotifier({String? instanceId})
    : instanceId = instanceId ?? const Uuid().v4();

  final String instanceId;
  RealtimeChannel? _channel;
  SupabaseClient? _boundClient;
  String? _boundOwnerId;
  Timer? _debounce;
  bool _disposed = false;

  /// Tópico derivado apenas por hash truncado do `ownerId` (sem dados pessoais no nome).
  static String channelTopicForOwner(String ownerId) {
    final hash = digest.sha256
        .convert(utf8.encode('sync_notify_v1:${ownerId.trim()}'))
        .toString();
    return 'sync_notify_${hash.substring(0, 24)}';
  }

  String? get boundOwnerId => _boundOwnerId;
  bool get isSubscribed => _channel != null && !_disposed;

  Future<void> start({
    required SupabaseClient client,
    required String ownerId,
    required void Function() onRemoteActivity,
    Duration debounceDuration = const Duration(milliseconds: 650),
  }) async {
    final cleanOwner = ownerId.trim();
    if (_disposed || cleanOwner.isEmpty) return;
    if (_boundOwnerId == cleanOwner &&
        identical(_boundClient, client) &&
        _channel != null) {
      return;
    }

    await stop();
    if (_disposed) return;

    _boundClient = client;
    _boundOwnerId = cleanOwner;
    final topic = channelTopicForOwner(cleanOwner);

    void triggerRemote() {
      if (_disposed) return;
      _debounce?.cancel();
      _debounce = Timer(debounceDuration, () {
        if (!_disposed) {
          onRemoteActivity();
        }
      });
    }

    try {
      final channel = client
          .channel(topic)
          .onBroadcast(
            event: 'record_updated',
            callback: (payload) {
              if (shouldTriggerFromBroadcast(payload)) {
                triggerRemote();
              }
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'encrypted_records',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'owner_id',
              value: cleanOwner,
            ),
            callback: (_) => triggerRemote(),
          );
      channel.subscribe((status, [error]) {
        if (error != null) {
          AppLogger.debug('Aviso no canal Realtime E2EE ($status): $error');
        }
      });
      _channel = channel;
    } catch (e, st) {
      AppLogger.warning(
        'Canal Realtime E2EE indisponível no momento (seguindo com polling/foco)',
        e,
        st,
      );
    }
  }

  /// Ignora ecos enviados pela própria instância do aplicativo.
  bool shouldTriggerFromBroadcast(Map<String, dynamic> payload) {
    final directSender = payload['sender']?.toString();
    final nested = payload['payload'];
    final nestedSender = nested is Map ? nested['sender']?.toString() : null;
    final sender = directSender ?? nestedSender;
    if (sender != null && sender == instanceId) {
      return false;
    }
    return true;
  }

  /// Envia ping opaco (zero conteúdo/metadados) após envio E2EE bem-sucedido.
  Future<void> notifyRemoteDevices() async {
    final channel = _channel;
    if (_disposed || channel == null) return;
    try {
      await channel.sendBroadcastMessage(
        event: 'record_updated',
        payload: {'sender': instanceId},
      );
    } catch (e, st) {
      AppLogger.debug(
        'Ping Realtime pós-push não pôde ser entregue (dispositivos buscarão no próximo ciclo): $e',
        st,
      );
    }
  }

  Future<void> stop() async {
    _debounce?.cancel();
    _debounce = null;
    final channel = _channel;
    final client = _boundClient;
    _channel = null;
    _boundClient = null;
    _boundOwnerId = null;
    if (channel != null && client != null) {
      try {
        await client.removeChannel(channel);
      } catch (e, st) {
        AppLogger.debug('Falha não-crítica ao encerrar canal Realtime: $e', st);
      }
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    await stop();
  }
}
