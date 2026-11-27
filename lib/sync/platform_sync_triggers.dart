import 'platform_sync_triggers_stub.dart'
    if (dart.library.js_interop) 'platform_sync_triggers_web.dart'
    as impl;

/// Assinatura multiplataforma de eventos de retorno de visibilidade, foco e rede
/// (útil principalmente no navegador PWA, onde `AppLifecycleState.resumed` nem
/// sempre dispara ao alternar abas/janelas).
abstract class PlatformSyncTriggersHandle {
  void dispose();
}

PlatformSyncTriggersHandle registerPlatformSyncTriggers({
  required void Function() onSyncTrigger,
}) => impl.registerPlatformSyncTriggers(onSyncTrigger: onSyncTrigger);
