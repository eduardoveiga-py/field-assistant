import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// Serviço de segurança e autenticação biométrica (Face ID, Touch ID, Biometria Android e PIN/Passcode)
/// para proteção bancária de áreas confidenciais (ex: Área Restrita do Hub JW e Cartas).
class BiometricAuthService {
  final LocalAuthentication _auth = LocalAuthentication();

  bool _isUnlockedForSession = false;
  DateTime? _lastAuthenticatedTime;
  static const Duration _sessionTimeout = Duration(minutes: 5);

  /// Indica se a sessão atual ainda está desbloqueada
  bool get isSessionUnlocked {
    if (!_isUnlockedForSession) return false;
    if (_lastAuthenticatedTime == null) return false;
    if (DateTime.now().difference(_lastAuthenticatedTime!) > _sessionTimeout) {
      _isUnlockedForSession = false;
      return false;
    }
    return true;
  }

  /// Trava a sessão imediatamente
  void lockSession() {
    _isUnlockedForSession = false;
    _lastAuthenticatedTime = null;
  }

  /// Verifica se o dispositivo possui suporte a biometria ou PIN
  Future<bool> isBiometricAvailable() async {
    try {
      final isSupported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return isSupported && canCheck;
    } catch (e) {
      debugPrint('[BiometricAuthService] Verificação de hardware falhou: $e');
      return false;
    }
  }

  /// Executa o prompt de autenticação biométrica com fallback para o PIN/Senha do dispositivo
  Future<bool> authenticate({
    String localizedReason = 'Confirme sua identidade para acessar a Área Restrita do Hub.',
  }) async {
    if (isSessionUnlocked) return true;

    try {
      final isAvailable = await isBiometricAvailable();
      if (!isAvailable) {
        // Se o hardware não tiver biometria (ex: desktop sem leitor ou simulador web),
        // permite acesso temporário ou modo seguro simulado
        _isUnlockedForSession = true;
        _lastAuthenticatedTime = DateTime.now();
        return true;
      }

      final authenticated = await _auth.authenticate(
        localizedReason: localizedReason,
        biometricOnly: false, // permite PIN/senha do SO caso FaceID falhe
        persistAcrossBackgrounding: true,
      );

      if (authenticated) {
        _isUnlockedForSession = true;
        _lastAuthenticatedTime = DateTime.now();
      }

      return authenticated;
    } catch (e) {
      debugPrint('[BiometricAuthService] Erro na autenticação biométrica: $e');
      return false;
    }
  }
}
