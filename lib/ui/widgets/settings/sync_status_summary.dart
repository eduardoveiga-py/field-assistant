import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/app_logger.dart';
import '../../../core/app_theme.dart';
import '../../../sync/supabase_sync_service.dart';
import '../../../sync/sync_engine.dart';
import '../../../sync/sync_privacy_policy.dart';

/// Estado amigável resumido para o card "Estado da Sincronização" em Configurações.
class SyncStatusPresentation {
  final IconData icon;
  final Color iconColor;
  final String subtitle;
  final String chipLabel;
  final Color chipColor;

  const SyncStatusPresentation({
    required this.icon,
    required this.iconColor,
    required this.subtitle,
    required this.chipLabel,
    required this.chipColor,
  });
}

class SyncStatusSummaryHeader extends ConsumerWidget {
  final ({int pending, int failed, int conflict}) syncCounts;
  final String? authenticatedUserIdOverride;
  final bool? remoteSyncEnabledOverride;

  const SyncStatusSummaryHeader({
    super.key,
    required this.syncCounts,
    @visibleForTesting this.authenticatedUserIdOverride,
    @visibleForTesting this.remoteSyncEnabledOverride,
  });

  Future<SyncStatusPresentation> _resolve(
    WidgetRef ref,
    SyncStatus liveStatus,
  ) async {
    if (syncCounts.conflict > 0) {
      return SyncStatusPresentation(
        icon: Icons.merge_type,
        iconColor: AppTheme.alertRed,
        subtitle:
            '${syncCounts.conflict} conflito(s) aguardando resolução e ${syncCounts.pending} pendente(s).',
        chipLabel: '${syncCounts.conflict} Conflitos',
        chipColor: const Color(0xFFFEE2E2),
      );
    }
    if (syncCounts.failed > 0) {
      return SyncStatusPresentation(
        icon: Icons.warning_amber_rounded,
        iconColor: AppTheme.alertRed,
        subtitle:
            '${syncCounts.failed} operação(ões) em falha e ${syncCounts.pending} pendente(s).',
        chipLabel: '${syncCounts.failed} Falhas',
        chipColor: const Color(0xFFFEE2E2),
      );
    }

    final cloudEnabled =
        remoteSyncEnabledOverride ?? SyncPrivacyPolicy.canRunRemoteSync();
    String? userId = authenticatedUserIdOverride;
    if (userId == null && SupabaseSyncService.isInitialized) {
      try {
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) {
          userId =
              Supabase.instance.client.auth.currentUser?.id ?? session.user.id;
        }
      } catch (e, st) {
        AppLogger.debug(
          'Sessão Supabase indisponível ao resolver status de sync',
          e,
          st,
        );
      }
    }

    if (!cloudEnabled || userId == null || userId.trim().isEmpty) {
      return SyncStatusPresentation(
        icon: Icons.sync,
        iconColor: AppTheme.primaryBlue,
        subtitle: syncCounts.pending > 0
            ? '${syncCounts.pending} alteração(ões) salva(s) localmente aguardando envio.'
            : 'Dados locais preservados no aparelho (nuvem não conectada).',
        chipLabel: 'Local-First',
        chipColor: const Color(0xFFE0E7FF),
      );
    }

    final e2ee = ref.read(e2eeServiceProvider);
    final isKeyInstalled = await e2ee.isKeyInstalled(userId);
    if (!isKeyInstalled) {
      final isPinLocked = await e2ee.isWebPinLocked(userId);
      return SyncStatusPresentation(
        icon: isPinLocked ? Icons.lock_clock_outlined : Icons.vpn_key_outlined,
        iconColor: Colors.orange.shade700,
        subtitle: isPinLocked
            ? 'Cofre E2EE bloqueado por PIN rápido neste navegador. Desbloqueie para sincronizar.'
            : 'Chave E2EE (24 palavras) pendente neste dispositivo.',
        chipLabel: isPinLocked ? 'Bloqueado (PIN)' : 'Chave Pendente',
        chipColor: const Color(0xFFFEF3C7),
      );
    }

    if (liveStatus == SyncStatus.syncing) {
      return const SyncStatusPresentation(
        icon: Icons.sync,
        iconColor: AppTheme.primaryBlue,
        subtitle: 'Sincronizando registros cifrados com a nuvem...',
        chipLabel: 'Sincronizando',
        chipColor: Color(0xFFDBEAFE),
      );
    }

    if (syncCounts.pending > 0) {
      return SyncStatusPresentation(
        icon: Icons.cloud_upload_outlined,
        iconColor: AppTheme.primaryBlue,
        subtitle:
            '${syncCounts.pending} alteração(ões) salva(s) localmente aguardando envio automático.',
        chipLabel: 'Pendente • Auto',
        chipColor: const Color(0xFFE0E7FF),
      );
    }

    return const SyncStatusPresentation(
      icon: Icons.verified_user_rounded,
      iconColor: AppTheme.successGreen,
      subtitle: 'Sincronização automática E2EE ativa entre seus dispositivos conectados.',
      chipLabel: 'Sincronizado • E2EE',
      chipColor: Color(0xFFDCFCE7),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveStatus =
        ref.watch(syncStatusStreamProvider).value ??
        ref.read(supabaseSyncServiceProvider).currentStatus;

    return FutureBuilder<SyncStatusPresentation>(
      future: _resolve(ref, liveStatus),
      builder: (context, snapshot) {
        final data =
            snapshot.data ??
            SyncStatusPresentation(
              icon: Icons.sync,
              iconColor: AppTheme.primaryBlue,
              subtitle: syncCounts.pending > 0
                  ? '${syncCounts.pending} alteração(ões) salva(s) localmente aguardando envio.'
                  : 'Verificando estado da sincronização E2EE...',
              chipLabel: syncCounts.pending > 0 ? 'Pendente' : 'Local-First',
              chipColor: const Color(0xFFE0E7FF),
            );

        return ListTile(
          leading: Icon(data.icon, color: data.iconColor),
          title: const Text('Estado da Sincronização'),
          subtitle: Text(data.subtitle),
          trailing: Chip(
            label: Text(
              data.chipLabel,
              style: const TextStyle(fontSize: 11, color: Color(0xFF0F172A)),
            ),
            backgroundColor: data.chipColor,
          ),
        );
      },
    );
  }
}
