import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import 'app_logger.dart';
import '../ui/widgets/pin_auth_dialog.dart';

/// Exceção lançada quando o usuário excede as tentativas permitidas de PIN.
class PinLockoutException implements Exception {
  final Duration remainingDuration;

  PinLockoutException(this.remainingDuration);

  @override
  String toString() =>
      'Muitas tentativas inválidas. Tente novamente em ${remainingDuration.inSeconds}s.';
}

/// Serviço de segurança e autenticação biométrica (Face ID, Touch ID, Biometria Android e PIN/Passcode)
/// com fallback obrigatório por PIN para proteção de áreas confidenciais (Área Restrita do Hub JW e Cartas).
class BiometricAuthService extends ChangeNotifier {
  final LocalAuthentication _auth;
  final FlutterSecureStorage _storage;

  BiometricAuthService({
    LocalAuthentication? auth,
    FlutterSecureStorage? storage,
  })  : _auth = auth ?? LocalAuthentication(),
        _storage = storage ?? const FlutterSecureStorage();

  static const String _pinSaltKey = 'app_security_pin_salt';
  static const String _pinHashKey = 'app_security_pin_hash';
  static const String _failedAttemptsKey = 'app_security_pin_failed_attempts';
  static const String _lockoutUntilKey = 'app_security_pin_lockout_until';

  static const int _maxAttemptsBeforeLockout = 5;
  static const Duration _initialLockoutDuration = Duration(seconds: 30);
  static const Duration _sessionTimeout = Duration(minutes: 5);

  bool _isUnlockedForSession = false;
  DateTime? _lastAuthenticatedTime;

  /// Indica se a sessão atual ainda está desbloqueada
  bool get isSessionUnlocked {
    if (!_isUnlockedForSession) return false;
    if (_lastAuthenticatedTime == null) return false;
    if (DateTime.now().difference(_lastAuthenticatedTime!) > _sessionTimeout) {
      _isUnlockedForSession = false;
      notifyListeners();
      return false;
    }
    return true;
  }

  /// Trava a sessão imediatamente
  void lockSession() {
    _isUnlockedForSession = false;
    _lastAuthenticatedTime = null;
    notifyListeners();
  }

  /// Verifica se o dispositivo possui hardware biométrico configurado e ativo
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

  /// Verifica se o usuário já cadastrou um PIN no armazenamento seguro
  Future<bool> hasPin() async {
    try {
      final hash = await _storage.read(key: _pinHashKey);
      return hash != null && hash.isNotEmpty;
    } catch (e) {
      debugPrint('[BiometricAuthService] Erro ao verificar PIN: $e');
      return false;
    }
  }

  /// Cadastra ou redefine o PIN de segurança com salt e SHA-256
  Future<bool> setPin(String pin) async {
    final sanitized = pin.trim();
    if (sanitized.length < 4 || sanitized.length > 8) {
      throw ArgumentError('O PIN deve ter entre 4 e 8 dígitos.');
    }

    try {
      final random = Random.secure();
      final saltBytes = List<int>.generate(16, (_) => random.nextInt(256));
      final saltHex =
          saltBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

      final hash =
          sha256.convert(utf8.encode('$saltHex:$sanitized')).toString();

      await _storage.write(key: _pinSaltKey, value: saltHex);
      await _storage.write(key: _pinHashKey, value: hash);
      await _clearLockout();

      _isUnlockedForSession = true;
      _lastAuthenticatedTime = DateTime.now();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[BiometricAuthService] Erro ao gravar PIN: $e');
      return false;
    }
  }

  /// Valida o PIN inserido pelo usuário
  Future<bool> verifyPin(String pin) async {
    final lockoutDuration = await getRemainingLockoutDuration();
    if (lockoutDuration != null && lockoutDuration > Duration.zero) {
      throw PinLockoutException(lockoutDuration);
    }

    try {
      final storedSalt = await _storage.read(key: _pinSaltKey);
      final storedHash = await _storage.read(key: _pinHashKey);

      if (storedSalt == null || storedHash == null) {
        return false;
      }

      final computedHash =
          sha256.convert(utf8.encode('$storedSalt:${pin.trim()}')).toString();
      final isValid = computedHash == storedHash;

      if (isValid) {
        await _clearLockout();
        _isUnlockedForSession = true;
        _lastAuthenticatedTime = DateTime.now();
        notifyListeners();
        return true;
      } else {
        await _recordFailedAttempt();
        return false;
      }
    } catch (e) {
      if (e is PinLockoutException) rethrow;
      debugPrint('[BiometricAuthService] Erro na verificação do PIN: $e');
      return false;
    }
  }

  /// Altera o PIN exigindo validação do PIN atual
  Future<bool> changePin({
    required String currentPin,
    required String newPin,
  }) async {
    final verified = await verifyPin(currentPin);
    if (!verified) return false;
    return await setPin(newPin);
  }

  /// Remove o PIN (disponível apenas se biometria estiver ativa e funcional)
  Future<bool> removePin(String currentPin) async {
    final verified = await verifyPin(currentPin);
    if (!verified) return false;

    final hasBiometrics = await isBiometricAvailable();
    if (!hasBiometrics) {
      throw StateError(
        'Não é permitido remover o PIN em dispositivos sem biometria.',
      );
    }

    await _storage.delete(key: _pinSaltKey);
    await _storage.delete(key: _pinHashKey);
    await _clearLockout();
    return true;
  }

  /// Autentica exclusivamente por biometria (sem fallback automático)
  Future<bool> authenticateWithBiometrics({
    String localizedReason =
        'Confirme sua identidade para acessar a Área Restrita do Hub.',
  }) async {
    if (isSessionUnlocked) return true;

    try {
      final isAvailable = await isBiometricAvailable();
      if (!isAvailable) return false;

      final authenticated = await _auth.authenticate(
        localizedReason: localizedReason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );

      if (authenticated) {
        _isUnlockedForSession = true;
        _lastAuthenticatedTime = DateTime.now();
        notifyListeners();
      }

      return authenticated;
    } catch (e) {
      debugPrint('[BiometricAuthService] Erro na autenticação biométrica: $e');
      return false;
    }
  }

  /// Fluxo unificado de autenticação com fallback obrigatório para PIN quando biometria não disponível/falha
  Future<bool> authenticate({
    BuildContext? context,
    String localizedReason =
        'Confirme sua identidade para acessar a Área Restrita do Hub.',
  }) async {
    if (isSessionUnlocked) return true;

    // 1. Tenta biometria se o hardware suportar
    final hasBio = await isBiometricAvailable();
    if (hasBio) {
      final bioSuccess = await authenticateWithBiometrics(
        localizedReason: localizedReason,
      );
      if (bioSuccess) return true;
    }

    // 2. Se biometria não disponível ou falhou/cancelada, recorre ao PIN
    if (context != null && context.mounted) {
      final pinConfigured = await hasPin();
      if (!context.mounted) return false;
      if (!pinConfigured) {
        final setupOk = await PinSetupDialog.show(context, biometricAuth: this);
        return setupOk;
      } else {
        final authOk = await PinAuthDialog.show(context, biometricAuth: this);
        return authOk;
      }
    }

    // Sem contexto de UI e sem biometria: rejeição estrita (NUNCA auto-unlock)
    return false;
  }

  // --- Funções Auxiliares de Lockout ---

  Future<Duration?> getRemainingLockoutDuration() async {
    try {
      final lockoutStr = await _storage.read(key: _lockoutUntilKey);
      if (lockoutStr == null) return null;
      final lockoutUntil = DateTime.parse(lockoutStr);
      final remaining = lockoutUntil.difference(DateTime.now());
      return remaining.isNegative ? null : remaining;
    } catch (e, st) {
      AppLogger.warning('Falha ao ler duração de bloqueio do PIN', e, st);
      return null;
    }
  }

  Future<void> _recordFailedAttempt() async {
    try {
      final countStr = await _storage.read(key: _failedAttemptsKey);
      final count = (int.tryParse(countStr ?? '0') ?? 0) + 1;
      await _storage.write(key: _failedAttemptsKey, value: count.toString());

      if (count >= _maxAttemptsBeforeLockout) {
        final lockoutUntil = DateTime.now().add(_initialLockoutDuration);
        await _storage.write(
          key: _lockoutUntilKey,
          value: lockoutUntil.toIso8601String(),
        );
      }
    } catch (e, st) {
      AppLogger.warning('Falha ao registrar tentativa de PIN no secure storage', e, st);
    }
  }

  Future<void> _clearLockout() async {
    try {
      await _storage.delete(key: _failedAttemptsKey);
      await _storage.delete(key: _lockoutUntilKey);
    } catch (e, st) {
      AppLogger.warning('Falha ao limpar bloqueio de PIN no secure storage', e, st);
    }
  }
}
