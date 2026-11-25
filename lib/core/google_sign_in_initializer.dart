import 'dart:async';

import 'package:google_sign_in/google_sign_in.dart';

/// Shared single-flight initializer for [GoogleSignIn].
///
/// Prevents concurrent calls from calendar sync and Gmail sync during app
/// startup from racing `GoogleSignIn.instance.initialize(...)`, which can stall
/// or throw on Web when triggered simultaneously in `Future.wait`.
class GoogleSignInInitializer {
  GoogleSignInInitializer._();

  static final Map<GoogleSignIn, Future<void>> _inFlight = {};
  static final Set<GoogleSignIn> _initialized = {};
  static bool _hasPromptedWebSession = false;

  /// Evita que múltiplos serviços (Gmail + Google Calendar) disparem o seletor
  /// FedCM / One-Tap do Google repetidas vezes na mesma sessão Web.
  static bool get hasPromptedWebSession => _hasPromptedWebSession;

  static void markWebSessionPrompted() {
    _hasPromptedWebSession = true;
  }

  static Future<void> ensureInitialized(
    GoogleSignIn googleSignIn, {
    String? clientId,
  }) {
    if (_initialized.contains(googleSignIn)) {
      return Future<void>.value();
    }

    final pending = _inFlight[googleSignIn];
    if (pending != null) {
      return pending;
    }

    final future = _runInit(googleSignIn, clientId: clientId);
    _inFlight[googleSignIn] = future;
    return future;
  }

  static Future<void> _runInit(
    GoogleSignIn googleSignIn, {
    String? clientId,
  }) async {
    try {
      await googleSignIn.initialize(
        clientId: (clientId != null && clientId.isNotEmpty) ? clientId : null,
      );
      _initialized.add(googleSignIn);
    } finally {
      _inFlight.remove(googleSignIn);
    }
  }

  /// Clears cached initialization state for tests that swap or mock instances.
  static void resetForTesting([GoogleSignIn? googleSignIn]) {
    _hasPromptedWebSession = false;
    if (googleSignIn == null) {
      _initialized.clear();
      _inFlight.clear();
    } else {
      _initialized.remove(googleSignIn);
      _inFlight.remove(googleSignIn);
    }
  }
}
