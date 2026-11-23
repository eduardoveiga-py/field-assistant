import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Bundle de tokens OAuth 2.0 com ciclo de vida e expiração
class OAuthTokenBundle {
  final String accessToken;
  final String? refreshToken;
  final DateTime expiresAt;
  final List<String> scopes;

  const OAuthTokenBundle({
    required this.accessToken,
    this.refreshToken,
    required this.expiresAt,
    this.scopes = const [],
  });

  /// Retorna true se o token já ultrapassou a sua data de expiração
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Retorna true se o token já expirou ou se expira dentro da margem de segurança de 5 minutos
  bool get isExpiredOrExpiringSoon =>
      DateTime.now().isAfter(expiresAt.subtract(const Duration(minutes: 5)));

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'expiresAt': expiresAt.toIso8601String(),
    'scopes': scopes,
  };

  factory OAuthTokenBundle.fromJson(Map<String, dynamic> json) {
    return OAuthTokenBundle(
      accessToken: json['accessToken'] as String? ?? '',
      refreshToken: json['refreshToken'] as String?,
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      scopes: json['scopes'] is List
          ? (json['scopes'] as List).map((e) => e.toString()).toList()
          : const [],
    );
  }
}

/// Armazenamento seguro de tokens OAuth 2.0 por conta com hardware-backed storage
class OAuthTokenStore {
  final FlutterSecureStorage _secureStorage;

  const OAuthTokenStore({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static String tokenKey(String accountId) =>
      'email_acc_${accountId}_oauth_tokens';

  Future<void> saveTokenBundle(
    String accountId,
    OAuthTokenBundle bundle,
  ) async {
    final raw = jsonEncode(bundle.toJson());
    await _secureStorage.write(key: tokenKey(accountId), value: raw);
  }

  Future<OAuthTokenBundle?> readTokenBundle(String accountId) async {
    try {
      final raw = await _secureStorage.read(key: tokenKey(accountId));
      if (raw == null || raw.trim().isEmpty) return null;
      final map = jsonDecode(raw);
      if (map is Map<String, dynamic>) {
        return OAuthTokenBundle.fromJson(map);
      }
      if (map is Map) {
        return OAuthTokenBundle.fromJson(Map<String, dynamic>.from(map));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteTokenBundle(String accountId) async {
    try {
      await _secureStorage.delete(key: tokenKey(accountId));
    } catch (_) {}
  }

  static const String _pendingMsStateKey = 'ms_oauth_pending_state';
  static const String _pendingMsVerifierKey = 'ms_oauth_pending_verifier';

  Future<void> savePendingWebAuth({
    required String state,
    required String verifier,
  }) async {
    await _secureStorage.write(key: _pendingMsStateKey, value: state);
    await _secureStorage.write(key: _pendingMsVerifierKey, value: verifier);
  }

  Future<Map<String, String>?> readPendingWebAuth() async {
    try {
      final state = await _secureStorage.read(key: _pendingMsStateKey);
      final verifier = await _secureStorage.read(key: _pendingMsVerifierKey);
      if (state != null && verifier != null) {
        return {'state': state, 'verifier': verifier};
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearPendingWebAuth() async {
    try {
      await _secureStorage.delete(key: _pendingMsStateKey);
      await _secureStorage.delete(key: _pendingMsVerifierKey);
    } catch (_) {}
  }

  // Aliases de conveniência
  Future<void> save(String accountId, OAuthTokenBundle bundle) =>
      saveTokenBundle(accountId, bundle);
  Future<OAuthTokenBundle?> read(String accountId) =>
      readTokenBundle(accountId);
  Future<void> delete(String accountId) => deleteTokenBundle(accountId);
}
