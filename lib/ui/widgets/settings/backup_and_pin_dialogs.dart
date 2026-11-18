import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/app_logger.dart';
import '../../../core/app_theme.dart';
import '../../../core/biometric_auth_service.dart';
import '../../../settings/backup_service.dart';

/// Diálogo de alteração de PIN local de segurança.
class ChangePinDialog extends StatefulWidget {
  final BiometricAuthService biometricAuth;

  const ChangePinDialog({super.key, required this.biometricAuth});

  @override
  State<ChangePinDialog> createState() => _ChangePinDialogState();
}

class _ChangePinDialogState extends State<ChangePinDialog> {
  final TextEditingController _currentCtrl = TextEditingController();
  final TextEditingController _newCtrl = TextEditingController();
  final TextEditingController _confirmCtrl = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final current = _currentCtrl.text.trim();
    final next = _newCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();
    if (next.length < 4 || next.length > 8) {
      setState(() => _error = 'O novo PIN deve ter entre 4 e 8 dígitos.');
      return;
    }
    if (next != confirm) {
      setState(() => _error = 'Os novos PINs não coincidem.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final ok = await widget.biometricAuth.changePin(
        currentPin: current,
        newPin: next,
      );
      if (!mounted) return;
      if (ok) {
        Navigator.pop(context, true);
      } else {
        setState(() {
          _error = 'PIN atual incorreto.';
          _saving = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Alterar PIN de Segurança'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _currentCtrl,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 8,
            decoration: const InputDecoration(
              labelText: 'PIN Atual',
              counterText: '',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _newCtrl,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 8,
            decoration: const InputDecoration(
              labelText: 'Novo PIN (4 a 8 dígitos)',
              counterText: '',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _confirmCtrl,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 8,
            decoration: const InputDecoration(
              labelText: 'Confirmar Novo PIN',
              counterText: '',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Semantics(
              liveRegion: true,
              child: Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Salvar Novo PIN'),
        ),
      ],
    );
  }
}

/// Diálogo para exportação de backup criptografado AES-256-GCM (v3).
class ExportBackupDialog extends StatefulWidget {
  final BackupService backupService;
  final VoidCallback onExported;

  const ExportBackupDialog({
    super.key,
    required this.backupService,
    required this.onExported,
  });

  @override
  State<ExportBackupDialog> createState() => _ExportBackupDialogState();
}

class _ExportBackupDialogState extends State<ExportBackupDialog> {
  final TextEditingController _passwordController = TextEditingController();
  bool _exporting = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _export() async {
    final password = _passwordController.text.trim();
    if (password.length < 6) {
      setState(() => _error = 'A senha deve conter ao menos 6 caracteres.');
      return;
    }

    setState(() {
      _exporting = true;
      _error = null;
    });

    try {
      final encryptedData = await widget.backupService.exportEncryptedBackupV3(
        password,
      );
      widget.onExported();
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);

      showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Backup Gerado com Sucesso!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Copie o texto criptografado abaixo e salve-o com segurança no aplicativo Arquivos, iCloud Drive ou em seu computador:',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                constraints: const BoxConstraints(maxHeight: 120),
                child: SingleChildScrollView(
                  child: SelectableText(
                    encryptedData,
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton.icon(
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copiar Código do Backup'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: encryptedData));
                Navigator.pop(c);
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Backup copiado para a área de transferência!',
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      );
    } catch (e, st) {
      AppLogger.error('Erro ao exportar backup criptografado', e, st);
      if (mounted) {
        setState(() {
          _exporting = false;
          _error = 'Erro ao exportar backup: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkDialog = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      title: const Text('Exportar Backup Criptografado'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Defina uma senha forte. O arquivo será criptografado com AES-256-GCM (PBKDF2 100k) e só poderá ser restaurado com esta senha.',
            style: TextStyle(
              fontSize: 13,
              color: isDarkDialog
                  ? const Color(0xFFCBD5E1)
                  : AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            decoration: const InputDecoration(
              labelText: 'Senha de Criptografia',
              hintText: 'Mínimo 6 caracteres',
            ),
            obscureText: true,
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Semantics(
              liveRegion: true,
              child: Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _exporting ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _exporting ? null : _export,
          child: _exporting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Exportar'),
        ),
      ],
    );
  }
}

/// Diálogo para análise, pré-visualização e restauração idempotente de backup criptografado.
class RestoreBackupDialog extends StatefulWidget {
  final BackupService backupService;

  const RestoreBackupDialog({super.key, required this.backupService});

  @override
  State<RestoreBackupDialog> createState() => _RestoreBackupDialogState();
}

class _RestoreBackupDialogState extends State<RestoreBackupDialog> {
  final TextEditingController _dataController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _allowLegacyV1 = false;
  bool _showLegacyOption = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _dataController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    final raw = _dataController.text.trim();
    final pwd = _passwordController.text.trim();
    if (raw.isEmpty || pwd.isEmpty) {
      setState(() => _error = 'Preencha os dados do backup e a senha.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final preview = await widget.backupService.previewBackup(
        encryptedDataString: raw,
        password: pwd,
        allowLegacyV1: _allowLegacyV1,
      );

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);

      showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Pré-visualização da Restauração'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Registros verificados com integridade SHA-256:'),
                const SizedBox(height: 8),
                Text('• Novos contatos: ${preview.peopleToAdd}'),
                Text('• Contatos a atualizar: ${preview.peopleToUpdate}'),
                Text('• Contatos inalterados: ${preview.peopleUnchanged}'),
                Text('• Visitas a importar: ${preview.visitsToAdd}'),
                Text('• Estudos bíblicos: ${preview.studiesToAdd}'),
                Text('• Sessões de estudo: ${preview.sessionsToAdd}'),
                Text('• Compromissos: ${preview.appointmentsToAdd}'),
                Text(
                  '• Idiomas / Ticuna: ${preview.appLanguagesToAdd + preview.ticunaWordsToAdd + preview.ticunaPhrasesToAdd}',
                ),
                Text(
                  '• Documentos de conhecimento: ${preview.knowledgeDocumentsToAdd}',
                ),
                if (!preview.isIntegral) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Atenção: ${preview.corruptedAudioIds.length} áudio(s) e ${preview.corruptedDocumentIds.length} documento(s) falharam na verificação SHA-256 e não serão restaurados.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(c).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                const Text(
                  'A restauração é idempotente e NÃO criará contatos ou estudos duplicados.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.successGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                await widget.backupService.commitRestore(preview);
                if (c.mounted) Navigator.pop(c);
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Restauração concluída com sucesso!'),
                  ),
                );
              },
              child: const Text('Confirmar Restauração'),
            ),
          ],
        ),
      );
    } on LegacyBackupNotAllowedException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _showLegacyOption = true;
          _error = e.message;
        });
      }
    } catch (e, st) {
      AppLogger.warning('Erro na validação do backup', e, st);
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Erro na validação do backup: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Restaurar Backup Criptografado'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _dataController,
              decoration: const InputDecoration(
                labelText: 'Cole o código criptografado do backup',
                hintText: '{"iv":"...","ciphertext":"..."}',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Senha utilizada na exportação',
              ),
              obscureText: true,
            ),
            if (_showLegacyOption || _allowLegacyV1) ...[
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _allowLegacyV1,
                onChanged: (val) =>
                    setState(() => _allowLegacyV1 = val ?? false),
                title: const Text(
                  'Permitir backup legado (v1, criptografia antiga sem salt)',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _busy ? null : _analyze,
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Analisar Backup'),
        ),
      ],
    );
  }
}
