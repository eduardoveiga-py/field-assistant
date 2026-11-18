import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart' show kIsWeb;
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

String _derivePinPbkdf2HexSync(
  String pin,
  List<int> saltBytes,
  int iterations,
) {
  final hmac = crypto.Hmac(crypto.sha256, utf8.encode(pin));
  final saltAndBlock = Uint8List(saltBytes.length + 4);
  saltAndBlock.setRange(0, saltBytes.length, saltBytes);
  saltAndBlock[saltBytes.length + 3] = 1;

  var u = Uint8List.fromList(hmac.convert(saltAndBlock).bytes);
  final block = Uint8List.fromList(u);
  for (var iter = 1; iter < iterations; iter++) {
    u = Uint8List.fromList(hmac.convert(u).bytes);
    for (var i = 0; i < 32; i++) {
      block[i] ^= u[i];
    }
  }
  return block.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

Future<String> _derivePinPbkdf2Hex(
  String pin,
  List<int> saltBytes,
  int iterations,
) async {
  // Em ambiente de produção nativo executa em isolate para não travar a UI.
  // Na Web ou sob FakeAsync de testWidgets (onde pumpAndSettle não cede tempo real
  // ao isolate), executa inline preservando exatamente as mesmas iterações KDF.
  var isWidgetTestBinding = false;
  try {
    isWidgetTestBinding = WidgetsBinding.instance.runtimeType
        .toString()
        .contains('TestWidgetsFlutterBinding');
  } catch (_) {
    // Sem WidgetsBinding inicializado (Dart puro): usa isolate normalmente.
    isWidgetTestBinding = false;
  }
  if (kIsWeb || isWidgetTestBinding) {
    return _derivePinPbkdf2HexSync(pin, saltBytes, iterations);
  }
  return Isolate.run(() => _derivePinPbkdf2HexSync(pin, saltBytes, iterations));
}

List<int> _hexToBytes(String hex) {
  final clean = hex.trim();
  if (clean.length.isOdd) {
    throw const FormatException('Hex de salt inválido.');
  }
  return [
    for (var i = 0; i < clean.length; i += 2)
      int.parse(clean.substring(i, i + 2), radix: 16),
  ];
}

bool _constantTimeEquals(String a, String b) {
  final aBytes = utf8.encode(a);
  final bBytes = utf8.encode(b);
  if (aBytes.length != bBytes.length) return false;
  var diff = 0;
  for (var i = 0; i < aBytes.length; i++) {
    diff |= aBytes[i] ^ bBytes[i];
  }
  return diff == 0;
}

/// Serviço de segurança e autenticação biométrica (Face ID, Touch ID, Biometria Android e PIN/Passcode)
/// com derivação PBKDF2-HMAC-SHA256 (100.000 iterações calibradas em isolate + Keychain/Keystore + lockout — FA-SEC-07)
/// e migração transparente de hashes legados.
class BiometricAuthService extends ChangeNotifier {
  final LocalAuthentication _auth;
  final FlutterSecureStorage _storage;
  final int pbkdf2Iterations;

  BiometricAuthService({
    LocalAuthentication? auth,
    FlutterSecureStorage? storage,
    this.pbkdf2Iterations = defaultPbkdf2Iterations,
  }) : _auth = auth ?? LocalAuthentication(),
       _storage = storage ?? const FlutterSecureStorage();

  /// Iterações calibradas para PBKDF2-HMAC-SHA256 em Dart puro para PIN
  /// protegido adicionalmente por Keychain/Keystore + lockout de 5 tentativas (FA-SEC-07).
  static const int defaultPbkdf2Iterations = 100000;
  static const String _kdfPrefix = 'pbkdf2_hmac_sha256:';

  static const String _pinSaltKey = 'app_security_pin_salt';
  static const String _pinHashKey = 'app_security_pin_hash';
  static const String _pinKdfKey = 'app_security_pin_kdf';
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

  /// Cadastra ou redefine o PIN de segurança com salt aleatório de 16 bytes
  /// e KDF PBKDF2-HMAC-SHA256 (100.000 iterações padrão em isolate — FA-SEC-07).
  Future<bool> setPin(String pin) async {
    final sanitized = pin.trim();
    if (sanitized.length < 4 || sanitized.length > 8) {
      throw ArgumentError('O PIN deve ter entre 4 e 8 dígitos.');
    }

    try {
      final random = Random.secure();
      final saltBytes = List<int>.generate(16, (_) => random.nextInt(256));
      final saltHex = saltBytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();

      final hash = await _derivePinPbkdf2Hex(
        sanitized,
        saltBytes,
        pbkdf2Iterations,
      );

      await _storage.write(key: _pinSaltKey, value: saltHex);
      await _storage.write(key: _pinHashKey, value: hash);
      await _storage.write(
        key: _pinKdfKey,
        value: '$_kdfPrefix$pbkdf2Iterations',
      );
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

  /// Valida o PIN inserido pelo usuário com comparação em tempo constante.
  /// Migra transparentemente hashes legados SHA-256 (1 rodada) para PBKDF2-HMAC-SHA256.
  Future<bool> verifyPin(String pin) async {
    final lockoutDuration = await getRemainingLockoutDuration();
    if (lockoutDuration != null && lockoutDuration > Duration.zero) {
      throw PinLockoutException(lockoutDuration);
    }

    try {
      final storedSalt = await _storage.read(key: _pinSaltKey);
      final storedHash = await _storage.read(key: _pinHashKey);
      final storedKdf = await _storage.read(key: _pinKdfKey);

      if (storedSalt == null || storedHash == null) {
        return false;
      }

      final sanitized = pin.trim();
      final bool isValid;
      var shouldUpgradeLegacy = false;

      if (storedKdf != null && storedKdf.startsWith(_kdfPrefix)) {
        final iterations = int.tryParse(storedKdf.substring(_kdfPrefix.length));
        if (iterations == null || iterations < 1000) {
          return false;
        }
        final saltBytes = _hexToBytes(storedSalt);
        final computedHash = await _derivePinPbkdf2Hex(
          sanitized,
          saltBytes,
          iterations,
        );
        isValid = _constantTimeEquals(computedHash, storedHash);
      } else {
        // Compatibilidade de leitura com hash legado SHA-256 de 1 rodada
        final legacyHash = crypto.sha256
            .convert(utf8.encode('$storedSalt:$sanitized'))
            .toString();
        isValid = _constantTimeEquals(legacyHash, storedHash);
        shouldUpgradeLegacy = isValid;
      }

      if (isValid) {
        if (shouldUpgradeLegacy) {
          // Migração transparente imediata para PBKDF2-HMAC-SHA256 com novo salt aleatório de 16 bytes
          // (evita falha caso um salt legado não esteja em formato hexadecimal par).
          final random = Random.secure();
          final freshSaltBytes = List<int>.generate(
            16,
            (_) => random.nextInt(256),
          );
          final freshSaltHex = freshSaltBytes
              .map((b) => b.toRadixString(16).padLeft(2, '0'))
              .join();
          final upgradedHash = await _derivePinPbkdf2Hex(
            sanitized,
            freshSaltBytes,
            pbkdf2Iterations,
          );
          await _storage.write(key: _pinSaltKey, value: freshSaltHex);
          await _storage.write(key: _pinHashKey, value: upgradedHash);
          await _storage.write(
            key: _pinKdfKey,
            value: '$_kdfPrefix$pbkdf2Iterations',
          );
        }
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
    await _storage.delete(key: _pinKdfKey);
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
      AppLogger.warning(
        'Falha ao registrar tentativa de PIN no secure storage',
        e,
        st,
      );
    }
  }

  Future<void> _clearLockout() async {
    try {
      await _storage.delete(key: _failedAttemptsKey);
      await _storage.delete(key: _lockoutUntilKey);
    } catch (e, st) {
      AppLogger.warning(
        'Falha ao limpar bloqueio de PIN no secure storage',
        e,
        st,
      );
    }
  }
}
