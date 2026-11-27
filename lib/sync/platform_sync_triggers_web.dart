import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'platform_sync_triggers.dart';

class _WebPlatformSyncTriggersHandle implements PlatformSyncTriggersHandle {
  _WebPlatformSyncTriggersHandle(this._onSyncTrigger) {
    _visibilityHandler = ((web.Event _) {
      if (web.document.visibilityState == 'visible') {
        _onSyncTrigger();
      }
    }).toJS;
    _focusHandler = ((web.Event _) {
      _onSyncTrigger();
    }).toJS;
    _onlineHandler = ((web.Event _) {
      _onSyncTrigger();
    }).toJS;

    web.document.addEventListener('visibilitychange', _visibilityHandler);
    web.window.addEventListener('focus', _focusHandler);
    web.window.addEventListener('online', _onlineHandler);
  }

  final void Function() _onSyncTrigger;
  late final JSFunction _visibilityHandler;
  late final JSFunction _focusHandler;
  late final JSFunction _onlineHandler;
  bool _disposed = false;

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    web.document.removeEventListener('visibilitychange', _visibilityHandler);
    web.window.removeEventListener('focus', _focusHandler);
    web.window.removeEventListener('online', _onlineHandler);
  }
}

PlatformSyncTriggersHandle registerPlatformSyncTriggers({
  required void Function() onSyncTrigger,
}) => _WebPlatformSyncTriggersHandle(onSyncTrigger);
