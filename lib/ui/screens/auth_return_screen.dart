import 'package:flutter/material.dart';

/// Resultado de um retorno de autenticação que já foi verificado pelo servidor.
class AuthReturnScreen extends StatelessWidget {
  const AuthReturnScreen({
    super.key,
    required this.success,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final bool success;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final color = success ? Colors.green : Theme.of(context).colorScheme.error;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(success ? Icons.check_circle_outline : Icons.error_outline,
                    size: 72, color: color),
                const SizedBox(height: 20),
                Text(title, textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                FilledButton(onPressed: onAction, child: Text(actionLabel)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Solicita uma senha nova depois que o servidor aceitou um link de recuperação.
class AuthNewPasswordScreen extends StatefulWidget {
  const AuthNewPasswordScreen({
    super.key,
    required this.updatePassword,
    required this.onSuccess,
    required this.onCancel,
  });

  final Future<void> Function(String password) updatePassword;
  final VoidCallback onSuccess;
  final VoidCallback onCancel;

  @override
  State<AuthNewPasswordScreen> createState() => _AuthNewPasswordScreenState();
}

class _AuthNewPasswordScreenState extends State<AuthNewPasswordScreen> {
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final password = _password.text;
    if (password.length < 6) {
      setState(() => _error = 'A senha deve ter pelo menos 6 caracteres.');
      return;
    }
    if (password != _confirmation.text) {
      setState(() => _error = 'As senhas não coincidem.');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      await widget.updatePassword(password);
      if (mounted) widget.onSuccess();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Não foi possível alterar a senha. Verifique sua conexão ou solicite um novo link de recuperação.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Criar nova senha')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Escolha uma nova senha para sua conta.'),
                const SizedBox(height: 20),
                TextField(
                  key: const ValueKey('new_password'),
                  controller: _password,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(labelText: 'Nova senha'),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('confirm_new_password'),
                  controller: _confirmation,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(labelText: 'Confirmar nova senha'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: Text(_busy ? 'Salvando...' : 'Salvar nova senha'),
                ),
                TextButton(onPressed: _busy ? null : widget.onCancel,
                    child: const Text('Cancelar')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
