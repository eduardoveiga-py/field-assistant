import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_theme.dart';
import '../../sync/supabase_sync_service.dart';
import '../main_navigation_shell.dart';

enum _AuthGateState { loadingSplash, unauthenticated, authenticated }



class AuthSplashScreen extends AuthGateShell { const AuthSplashScreen({super.key}); }
class AuthGateShell extends ConsumerStatefulWidget {
  const AuthGateShell({super.key});

  @override
  ConsumerState<AuthGateShell> createState() => _AuthGateShellState();
}

class _AuthGateShellState extends ConsumerState<AuthGateShell>
    with SingleTickerProviderStateMixin {
  _AuthGateState _gateState = _AuthGateState.loadingSplash;
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
    final stopwatch = Stopwatch()..start();
    SupabaseClient? client;
    try {
      client = Supabase.instance.client;
    } catch (_) {
      client = null;
    }

    final elapsed = stopwatch.elapsedMilliseconds;
    if (elapsed < 1200) {
      await Future<void>.delayed(Duration(milliseconds: 1200 - elapsed));
    }

    if (!mounted) return;

    if (client != null) {
      final uriStr = Uri.base.toString();
      if (uriStr.contains('access_token=') || uriStr.contains('refresh_token=') || uriStr.contains('code=')) {
        try {
          await client.auth.getSessionFromUrl(Uri.base);
        } catch (_) {}
      }
    }

    if (client == null || client.auth.currentSession == null) {
      setState(() {
        _gateState = _AuthGateState.unauthenticated;
      });
    } else {
      setState(() {
        _gateState = _AuthGateState.authenticated;
      });
    }

    if (client != null) {
      _authSub = client.auth.onAuthStateChange.listen((data) {
        if (!mounted) return;
        if (data.session != null) {
          setState(() {
            _gateState = _AuthGateState.authenticated;
          });
        } else {
          setState(() {
            _gateState = _AuthGateState.unauthenticated;
          });
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
        return _buildSplashScreen();
      case _AuthGateState.unauthenticated:
        return SupabaseAuthScreen(
          onAuthenticated: () {
            setState(() {
              _gateState = _AuthGateState.authenticated;
            });
          },
        );
      case _AuthGateState.authenticated:
        return const MainNavigationShell();
    }
  }

  Widget _buildSplashScreen() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0284C7)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: Tween<double>(begin: 0.95, end: 1.05).animate(
                  CurvedAnimation(
                    parent: _pulseController,
                    curve: Curves.easeInOut,
                  ),
                ),
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white30, width: 2),
                  ),
                  child: const Icon(
                    Icons.assignment_turned_in,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Assistente de Campo',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Organizando o seu ministério pessoal',
                style: TextStyle(fontSize: 14, color: Colors.white70),
              ),
              const SizedBox(height: 36),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SupabaseAuthScreen extends StatefulWidget {
  final VoidCallback? onAuthenticated;

    const SupabaseAuthScreen({super.key, this.onAuthenticated});

  @override
  State<SupabaseAuthScreen> createState() => _SupabaseAuthScreenState();
}

class _SupabaseAuthScreenState extends State<SupabaseAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSignUp = false;
  bool _isLoading = false;
  String? _errorMessage;
  String? _infoMessage;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      if (!SupabaseSyncService.isInitialized) {
        try {
          await SupabaseSyncService.initialize();
        } catch (_) {
          if (mounted) {
            setState(() {
              _errorMessage = 'Não foi possível iniciar a conexão. Verifique sua conexão e tente novamente.';
            });
          }
          return;
        }
      }
      if (!mounted) return;

      final client = Supabase.instance.client;
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      if (_isSignUp) {
        final res = await client.auth.signUp(email: email, password: password);
        if (!mounted) return;
        if (res.session == null) {
          setState(() {
            _infoMessage = 'Cadastro realizado! Por favor, verifique seu e-mail para confirmar a conta antes de fazer login.';
          });
        } else {
          widget.onAuthenticated?.call();
        }
      } else {
        final res = await client.auth.signInWithPassword(email: email, password: password);
        if (!mounted) return;
        if (res.session != null) {
          widget.onAuthenticated?.call();
        } else {
          setState(() {
            _errorMessage = 'Falha ao realizar login. Verifique suas credenciais.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Erro: ${e.toString()}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_outline, size: 48, color: AppTheme.primaryBlue),
                      const SizedBox(height: 12),
                      Text(
                        _isSignUp ? 'Criar Conta' : 'Entrar no Assistente',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (_errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                        ),
                      if (_infoMessage != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(_infoMessage!, style: const TextStyle(color: Colors.green)),
                        ),
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'E-mail',
                          prefixIcon: Icon(Icons.email),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o e-mail' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordController,
                        decoration: const InputDecoration(
                          labelText: 'Senha',
                          prefixIcon: Icon(Icons.lock),
                        ),
                        obscureText: true,
                        validator: (v) => (v == null || v.isEmpty) ? 'Informe a senha' : null,
                      ),
                      const SizedBox(height: 12),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submit,
                          child: _isLoading
                              ? const CircularProgressIndicator()
                              : Text(_isSignUp ? 'Cadastrar' : 'Entrar'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isSignUp = !_isSignUp;
                            _errorMessage = null;
                            _infoMessage = null;
                          });
                        },
                        child: Text(_isSignUp
                            ? 'Já tem uma conta? Faça Login'
                            : 'Não tem conta? Cadastre-se'),
                      ),
                    ],
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
