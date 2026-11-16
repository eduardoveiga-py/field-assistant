import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// Ativação explícita após validar allowlist e entrega real de links no aparelho.
/// Sem a flag, o comportamento atual do SDK e do Supabase permanece intacto.
class NativeAuthCallback {
  static const redirectUrl = 'ministeriopessoal://auth/callback';
  static const _enabled = bool.fromEnvironment('AUTH_NATIVE_CALLBACK');

  static bool get enabled => _enabled && !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
       defaultTargetPlatform == TargetPlatform.android);
  static String? get redirectTo => enabled ? redirectUrl : null;

  final Set<String> _handled = {};

  /// Uma mesma URI não pode consumir duas vezes o código de uso único.
  /// Não persiste nem registra a URI ou o token; mantém apenas um digest em memória.
  bool claim(Uri uri) {
    if (uri.scheme != 'ministeriopessoal' || uri.host != 'auth' ||
        uri.path != '/callback' || uri.userInfo.isNotEmpty || uri.hasPort) {
      return false;
    }
    final fragment = Uri.splitQueryString(uri.fragment);
    final hasAuth = ['code', 'access_token', 'error', 'error_code']
        .any((key) => uri.queryParameters.containsKey(key) || fragment.containsKey(key));
    if (!hasAuth) return false;
    return _handled.add(sha256.convert(utf8.encode(uri.toString())).toString());
  }
}
