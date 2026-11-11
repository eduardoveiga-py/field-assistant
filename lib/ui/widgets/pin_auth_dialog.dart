import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/biometric_auth_service.dart';

export 'pin_setup_dialog.dart';

/// Diálogo modal para validação de PIN de segurança.
class PinAuthDialog extends StatefulWidget {
  final BiometricAuthService biometricAuth;

  const PinAuthDialog({super.key, required this.biometricAuth});

  static Future<bool> show(
    BuildContext context, {
    required BiometricAuthService biometricAuth,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PinAuthDialog(biometricAuth: biometricAuth),
    );
    return result ?? false;
  }

  @override
  State<PinAuthDialog> createState() => _PinAuthDialogState();
}

class _PinAuthDialogState extends State<PinAuthDialog> {
  final TextEditingController _pinController = TextEditingController();
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _submitPin() async {
    final pin = _pinController.text.trim();
    if (pin.isEmpty) {
      setState(() => _errorMessage = 'Digite o seu PIN.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success = await widget.biometricAuth.verifyPin(pin);
      if (success) {
        if (mounted) Navigator.of(context).pop(true);
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'PIN incorreto. Tente novamente.';
            _pinController.clear();
          });
        }
      }
    } on PinLockoutException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _pinController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Erro ao verificar PIN: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.password_rounded, color: Color(0xFF6366F1)),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'PIN de Segurança',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Informe seu PIN de 4 a 8 dígitos para desbloquear as áreas confidenciais.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pinController,
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(8),
              ],
              decoration: InputDecoration(
                labelText: 'PIN de Acesso',
                prefixIcon: const Icon(Icons.lock_outline),
                border: const OutlineInputBorder(),
                errorText: _errorMessage,
              ),
              onSubmitted: (_) => _submitPin(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
          onPressed: _isLoading ? null : _submitPin,
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Desbloquear'),
        ),
      ],
    );
  }
}

