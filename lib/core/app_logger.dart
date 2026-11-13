import 'package:flutter/foundation.dart';

/// Utilitário central de logging técnico para diagnóstico sem exposição de PII.
class AppLogger {
  static void debug(
    String message, [
    Object? errorOrStack,
    StackTrace? stackTrace,
  ]) {
    if (kDebugMode) {
      if (errorOrStack is StackTrace && stackTrace == null) {
        debugPrint('[DEBUG] $message');
        debugPrint(errorOrStack.toString());
      } else {
        debugPrint(
          '[DEBUG] $message${errorOrStack != null ? ' : $errorOrStack' : ''}',
        );
        if (stackTrace != null) {
          debugPrint(stackTrace.toString());
        }
      }
    }
  }

  static void info(String message) {
    if (kDebugMode) {
      debugPrint('[INFO] $message');
    }
  }

  static void warning(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('[WARN] $message ${error != null ? ': $error' : ''}');
      if (stackTrace != null) {
        debugPrint(stackTrace.toString());
      }
    }
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('[ERROR] $message ${error != null ? ': $error' : ''}');
      if (stackTrace != null) {
        debugPrint(stackTrace.toString());
      }
    }
  }
}
