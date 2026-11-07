import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../appointments/calendar_provider.dart';
import '../../appointments/calendar_sync_coordinator.dart';
import '../../core/app_theme.dart';
import '../../sync/supabase_sync_service.dart';
import '../main_navigation_shell.dart';

enum _AuthGateState { loadingSplash, unauthenticated, authenticated }

class AuthSplashScreen extends AuthGateShell {
  const AuthSplashScreen({super.key});
}

class AuthGateShell extends ConsumerStatefulWidget {
  const AuthGateShell({super.key});

  @override
  ConsumerState<AuthGateShell> createState() => _AuthGateShellState();
}

class _AuthGateShellState extends ConsumerState<AuthGateShell>
    with SingleTickerProviderStateMixin {
  _AuthGateState _gateState = _AuthGateState.loadingSplash;
  bool _isSplashActive = true;
  Session? _latestSession;
  String _statusMessage = 'Inicializando Assistente de Campo...';
  StreamSubscription<AuthState>? _authSub;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _initializeAuthGate();
  }

  void _initializeAuthGate() async {
    SupabaseClient? client;
    try {
      client = Supabase.instance.client;
    } catch (_) {
      client = null;
    }

    if (client != null) {
      _latestSession = client.auth.currentSession;
      _authSub = client.auth.onAuthStateChange.listen((data) {
        if (!mounted) return;
        _latestSession = data.session;
        // Não transiciona prematuramente se a splash screen ainda estiver no tempo mínimo
        if (!_isSplashActive) {
          setState(() {
            _gateState = data.session != null
                ? _AuthGateState.authenticated
                : _AuthGateState.unauthenticated;
          });
          if (data.session != null) {
            Future.microtask(() {
              if (mounted) {
                ref.read(supabaseSyncServiceProvider).sync();
                ref.read(calendarSyncCoordinatorProvider).syncAll();
              }
            });
          }
        }
      });
    }

    if (mounted) {
      setState(() {
        _statusMessage = 'Sincronizando registros e calendário...';
      });
    }

    // Dispara sincronização em segundo plano para Supabase e Calendários externos
    try {
      unawaited(
        ref
            .read(supabaseSyncServiceProvider)
            .sync()
            .catchError(
              (_) => const SyncProcessResult(
                totalProcessed: 0,
                successCount: 0,
                failureCount: 0,
                conflictCount: 0,
                message: 'Modo offline ou sem conexão',
              ),
            ),
      );
    } catch (_) {}

    try {
      unawaited(
        ref
            .read(calendarSyncCoordinatorProvider)
            .syncAll()
            .catchError(
              (_) => CalendarSyncResult(
                success: false,
                eventsDownloaded: 0,
                eventsUploaded: 0,
              ),
            ),
      );
    } catch (_) {}

    // Garante que a Splash Screen permaneça visível por pelo menos 1800ms
    const minSplashDurationMs = 1800;
    await Future<void>.delayed(
      const Duration(milliseconds: minSplashDurationMs),
    );
    if (!mounted) return;

    if (client != null) {
      final uriStr = Uri.base.toString();
      if (uriStr.contains('access_token=') ||
          uriStr.contains('refresh_token=') ||
          uriStr.contains('code=')) {
        try {
          await client.auth.getSessionFromUrl(Uri.base);
        } catch (_) {}
      }
    }

    _isSplashActive = false;
    _pulseController.stop();
    final session = _latestSession ?? client?.auth.currentSession;
    setState(() {
      _gateState = session != null
          ? _AuthGateState.authenticated
          : _AuthGateState.unauthenticated;
    });

    if (session != null) {
      Future.microtask(() {
        if (mounted) {
          ref.read(supabaseSyncServiceProvider).sync();
          ref.read(calendarSyncCoordinatorProvider).syncAll();
        }
      });
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (_gateState) {
      case _AuthGateState.loadingSplash:
        return _SplashScreenView(
          pulseAnimation: _pulseController,
          statusMessage: _statusMessage,
          version: 'v1.0.0',
        );
      case _AuthGateState.unauthenticated:
        return SupabaseAuthScreen(
          onAuthenticated: () {
            if (mounted) {
              setState(() {
                _gateState = _AuthGateState.authenticated;
              });
              ref.read(supabaseSyncServiceProvider).sync();
              ref.read(calendarSyncCoordinatorProvider).syncAll();
            }
          },
        );
      case _AuthGateState.authenticated:
        return const MainNavigationShell();
    }
  }
}

class _SplashScreenView extends StatelessWidget {
  final Animation<double> pulseAnimation;
  final String statusMessage;
  final String version;

  const _SplashScreenView({
    required this.pulseAnimation,
    this.statusMessage = 'Inicializando Assistente de Campo...',
    this.version = 'v1.0.0',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('splash_screen_scaffold'),
      body: Container(
        key: const ValueKey('splash_screen_view'),
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF070B14), Color(0xFF0F172A), Color(0xFF1E1B4B)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: pulseAnimation,
                builder: (context, child) {
                  final scale = 1.0 + (pulseAnimation.value * 0.06);
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryBlue.withValues(alpha: 0.35),
                            const Color(0xFF7C3AED).withValues(alpha: 0.35),
                          ],
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryBlue.withValues(
                              alpha: 0.25 + (pulseAnimation.value * 0.2),
                            ),
                            blurRadius: 32,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.menu_book_rounded,
                        size: 46,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'Assistente de Campo',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Ministério Pessoal • Sincronização em Nuvem',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 36),
              SizedBox(
                width: 200,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: const LinearProgressIndicator(
                    minHeight: 4,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF60A5FA),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                statusMessage,
                key: const ValueKey('splash_status_message'),
                style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.white.withValues(alpha: 0.75),
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Text(
                  '$version • Offline-First',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.5,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SupabaseAuthScreen extends StatefulWidget {
  final VoidCallback onAuthenticated;

  const SupabaseAuthScreen({super.key, required this.onAuthenticated});

  @override
  State<SupabaseAuthScreen> createState() => _SupabaseAuthScreenState();
}

class _SupabaseAuthScreenState extends State<SupabaseAuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isSignUp = false;
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;
  String? _infoMessage;
  bool _canResendConfirmation = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  String _translateAuthError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('email not confirmed')) {
      _canResendConfirmation = true;
      return 'Seu e-mail ainda não foi confirmado. Verifique sua caixa de entrada/spam ou clique em "Reenviar confirmação".';
    }
    if (lower.contains('invalid login credentials')) {
      return 'E-mail ou senha incorretos. Verifique seus dados ou cadastre uma nova conta.';
    }
    if (lower.contains('user already registered')) {
      return 'Este e-mail já está cadastrado. Mude para "Entrar na Conta".';
    }
    if (lower.contains('password should be at least')) {
      return 'A senha deve ter pelo menos 6 caracteres.';
    }
    return raw;
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _errorMessage = 'Informe um endereço de e-mail válido.';
        _infoMessage = null;
      });
      return;
    }
    if (password.length < 6) {
      setState(() {
        _errorMessage = 'A senha deve conter no mínimo 6 caracteres.';
        _infoMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
      _canResendConfirmation = false;
    });

    try {
      final client = Supabase.instance.client;
      if (_isSignUp) {
        final res = await client.auth.signUp(
          email: email,
          password: password,
          data: name.isNotEmpty ? {'full_name': name} : null,
        );
        if (res.session != null) {
          widget.onAuthenticated();
          return;
        } else {
          // Tenta login imediato caso confirmação de e-mail esteja desativada
          try {
            final signInRes = await client.auth.signInWithPassword(
              email: email,
              password: password,
            );
            if (signInRes.session != null) {
              widget.onAuthenticated();
              return;
            }
          } catch (_) {}
          setState(() {
            _isSignUp = false;
            _infoMessage = 'Conta criada com sucesso! Se a confirmação por e-mail estiver ativa, confirme no seu e-mail antes de entrar.';
          });
        }
      } else {
        final res = await client.auth.signInWithPassword(
          email: email,
          password: password,
        );
        if (res.session != null) {
          widget.onAuthenticated();
          return;
        }
      }
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = _translateAuthError(e.message);
      });
    } catch (e) {
      setState(() {
        _errorMessage = _translateAuthError(e.toString());
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resendConfirmation() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: email,
      );
      setState(() {
        _infoMessage =
            'Link de confirmação reenviado para $email! Verifique também o Lixo Eletrônico / Spam.';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Não foi possível reenviar: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _errorMessage = 'Digite seu e-mail no campo acima para receber o link de redefinição de senha.';
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      setState(() {
        _infoMessage = 'E-mail de recuperação de senha enviado para $email.';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro ao enviar recuperação: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF070B14), Color(0xFF0F172A), Color(0xFF1E1B4B)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B).withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.14),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.45),
                            blurRadius: 32,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryBlue.withValues(
                                    alpha: 0.2,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: AppTheme.primaryBlue.withValues(
                                      alpha: 0.4,
                                    ),
                                  ),
                                ),
                                child: Icon(
                                  _isSignUp
                                      ? Icons.person_add_alt_1_rounded
                                      : Icons.lock_person_rounded,
                                  color: const Color(0xFF60A5FA),
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _isSignUp
                                          ? 'Criar Conta'
                                          : 'Entrar na Conta',
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Acesse sua conta para sincronizar suas visitas, estudos e territórios.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white.withValues(
                                          alpha: 0.7,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          if (_isSignUp) ...[
                            TextField(
                              controller: _nameController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Seu Nome',
                                labelStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                                prefixIcon: const Icon(
                                  Icons.badge_outlined,
                                  color: Color(0xFF94A3B8),
                                ),
                                filled: true,
                                fillColor: Colors.black.withValues(alpha: 0.25),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.18),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF60A5FA),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(color: Colors.white),
                            onSubmitted: (_) => _submit(),
                            decoration: InputDecoration(
                              labelText: 'E-mail *',
                              labelStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                              prefixIcon: const Icon(
                                Icons.email_outlined,
                                color: Color(0xFF94A3B8),
                              ),
                              filled: true,
                              fillColor: Colors.black.withValues(alpha: 0.25),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.18),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFF60A5FA),
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: const TextStyle(color: Colors.white),
                            onSubmitted: (_) => _submit(),
                            decoration: InputDecoration(
                              labelText: 'Senha *',
                              labelStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                              prefixIcon: const Icon(
                                Icons.lock_outline,
                                color: Color(0xFF94A3B8),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: const Color(0xFF94A3B8),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              filled: true,
                              fillColor: Colors.black.withValues(alpha: 0.25),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.18),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFF60A5FA),
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.redAccent.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      color: Color(0xFFFCA5A5),
                                      fontSize: 12.5,
                                    ),
                                  ),
                                  if (_canResendConfirmation) ...[
                                    const SizedBox(height: 6),
                                    TextButton.icon(
                                      icon: const Icon(
                                        Icons.mark_email_read_outlined,
                                        size: 16,
                                        color: Color(0xFF93C5FD),
                                      ),
                                      label: const Text(
                                        'Reenviar e-mail de confirmação',
                                        style: TextStyle(
                                          color: Color(0xFF93C5FD),
                                          fontSize: 12,
                                        ),
                                      ),
                                      onPressed: _isLoading
                                          ? null
                                          : _resendConfirmation,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                          if (_infoMessage != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.greenAccent.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                              ),
                              child: Text(
                                _infoMessage!,
                                style: const TextStyle(
                                  color: Color(0xFF86EFAC),
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ],
                          if (!_isSignUp) ...[
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _isLoading ? null : _resetPassword,
                                child: const Text(
                                  'Esqueci minha senha',
                                  style: TextStyle(
                                    color: Color(0xFF60A5FA),
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                            ),
                          ] else
                            const SizedBox(height: 18),
                          const SizedBox(height: 6),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3B82F6),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      _isSignUp
                                          ? 'Cadastrar e Entrar'
                                          : 'Entrar',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextButton(
                            onPressed: _isLoading
                                ? null
                                : () {
                                    setState(() {
                                      _isSignUp = !_isSignUp;
                                      _errorMessage = null;
                                      _infoMessage = null;
                                    });
                                  },
                            child: Text(
                              _isSignUp
                                  ? 'Já possui uma conta? Entrar'
                                  : 'Não tem conta? Cadastrar',
                              style: const TextStyle(
                                color: Color(0xFF93C5FD),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextButton(
                            onPressed: _isLoading ? null : widget.onAuthenticated,
                            child: const Text(
                              'Continuar em Modo Offline (Sem Conta)',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
