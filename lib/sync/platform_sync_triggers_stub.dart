import 'platform_sync_triggers.dart';

class _NoopPlatformSyncTriggersHandle implements PlatformSyncTriggersHandle {
  const _NoopPlatformSyncTriggersHandle();

  @override
  void dispose() {}
}

PlatformSyncTriggersHandle registerPlatformSyncTriggers({
  required void Function() onSyncTrigger,
}) => const _NoopPlatformSyncTriggersHandle();
