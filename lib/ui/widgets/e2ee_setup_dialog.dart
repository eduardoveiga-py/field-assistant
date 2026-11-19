import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_logger.dart';
import '../../core/biometric_auth_service.dart';
import '../../sync/crypto/recovery_crypto.dart';
import '../../sync/supabase_sync_service.dart';

/// Diálogo completo para configuração e restauração do cofre E2EE.
class E2eeSetupDialog extends ConsumerStatefulWidget {
  final String userId;
  final VoidCallback? onCompleted;

  const E2eeSetupDialog({super.key, required this.userId, this.onCompleted});

  static Future<bool?> show(BuildContext context, {String? userId}) {
    final effectiveId = (userId != null && userId.trim().isNotEmpty)
        ? userId.trim()
        : 'local_user';
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => E2eeSetupDialog(userId: effectiveId),
    );
  }

  @override
  ConsumerState<E2eeSetupDialog> createState() => _E2eeSetupDialogState();
}

class _E2eeSetupDialogState extends ConsumerState<E2eeSetupDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  String? _errorMessage;

  // Estado da aba 'Criar Novo Cofre'
  String? _generatedPhrase;
  bool _confirmedPhraseWritten = false;

  // Estado da aba 'Restaurar com Frase'
  final TextEditingController _restorePhraseController =
      TextEditingController();
  int _wordCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _restorePhraseController.addListener(_updateWordCount);
    _initGeneratePhrase();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _restorePhraseController.dispose();
    super.dispose();
  }

  void _updateWordCount() {
    final words = _restorePhraseController.text
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    setState(() {
      _wordCount = words.length;
    });
  }

  void _initGeneratePhrase() {
    if (_isLoading) return;
    setState(() {
      _generatedPhrase = RecoveryCrypto.createPhrase();
      _confirmedPhraseWritten = false;
      _errorMessage = null;
    });
  }

  Future<void> _handleConfirmNewVault() async {
    if (!_confirmedPhraseWritten || _generatedPhrase == null) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final e2ee = ref.read(e2eeServiceProvider);
      await e2ee.setupVaultWithPhrase(widget.userId, _generatedPhrase!);

      AppLogger.info(
        'Cofre E2EE configurado com sucesso para ${widget.userId}',
      );
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Chave configurada. A sincronização depende das verificações de segurança.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e, st) {
      AppLogger.error('Erro ao configurar novo cofre E2EE', e, st);
      if (mounted) {
        setState(() {
          _errorMessage = 'Não foi possível confirmar o cofre. Guarde esta frase: se a criação remota tiver ocorrido, use-a para restaurar. $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleRestoreVault() async {
    final phrase = _restorePhraseController.text.trim();
    if (_wordCount != 24) {
      setState(() {
        _errorMessage =
            'A frase de recuperação precisa conter exatamente 24 palavras (digitadas: $_wordCount).';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final e2ee = ref.read(e2eeServiceProvider);
      await e2ee.restoreVault(widget.userId, phrase);
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Chave restaurada. A sincronização depende das verificações de segurança.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e, st) {
      AppLogger.error('Falha ao restaurar cofre E2EE', e, st);
      if (mounted) {
        setState(() {
          _errorMessage =
              'Frase de recuperação inválida ou não confere com o cofre desta conta: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _copyPhraseToClipboard() {
    if (_generatedPhrase == null) return;
    Clipboard.setData(ClipboardData(text: _generatedPhrase!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Frase de recuperação de 24 palavras copiada!'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      actionsPadding: const EdgeInsets.all(16),
      title: Row(
        children: [
          Icon(Icons.security, color: theme.colorScheme.primary, size: 28),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Criptografia Ponta a Ponta (E2EE)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'A sincronização cifrada está em validação. Guarde a frase de recuperação em local seguro; ela é necessária para recuperar o acesso ao cofre.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 12),
              TabBar(
                controller: _tabController,
                labelColor: theme.colorScheme.primary,
                tabs: const [
                  Tab(icon: Icon(Icons.key, size: 18), text: 'Novo Cofre'),
                  Tab(
                    icon: Icon(Icons.restore, size: 18),
                    text: 'Restaurar com Frase',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade400),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Colors.red.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
              SizedBox(
                height: 380,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildNewVaultTab(theme, isDark),
                    _buildRestoreVaultTab(theme, isDark),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar / Manter Local'),
        ),
      ],
    );
  }

  Widget _buildNewVaultTab(ThemeData theme, bool isDark) {
    final words = _generatedPhrase?.split(' ') ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber.shade700),
          ),
          child: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.amber.shade900,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'ATENÇÃO: Anote as 24 palavras abaixo em papel. Se perder seus aparelhos e esta frase, o acesso aos seus dados será permanentemente perdido.',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
              ),
            ),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 3.2,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemCount: words.length,
              itemBuilder: (ctx, idx) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black45 : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isDark
                          ? Colors.grey.shade700
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${idx + 1}.',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          words[idx],
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _copyPhraseToClipboard,
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copiar Palavras'),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: _isLoading ? null : _initGeneratePhrase,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Gerar Outra'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        CheckboxListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          value: _confirmedPhraseWritten,
          onChanged: (val) {
            setState(() => _confirmedPhraseWritten = val ?? false);
          },
          title: const Text(
            'Confirmo que anotei a frase em local seguro',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 4),
        ElevatedButton.icon(
          onPressed: (_confirmedPhraseWritten && !_isLoading)
              ? _handleConfirmNewVault
              : null,
          icon: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_circle, size: 18),
          label: const Text('Ativar Criptografia E2EE'),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildRestoreVaultTab(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Cole ou digite as 24 palavras da sua frase de recuperação mnemônica BIP-39 (separadas por espaço):',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: TextField(
            controller: _restorePhraseController,
            maxLines: 7,
            decoration: InputDecoration(
              hintText: 'exemplo: abaixar abelha abismo abrigo...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              counterText: '$_wordCount / 24 palavras',
              counterStyle: TextStyle(
                color: _wordCount == 24 ? Colors.green : Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () async {
            final data = await Clipboard.getData(Clipboard.kTextPlain);
            if (data?.text != null) {
              _restorePhraseController.text = data!.text!.trim();
            }
          },
          icon: const Icon(Icons.paste, size: 16),
          label: const Text('Colar da Área de Transferência'),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: (_wordCount == 24 && !_isLoading)
              ? _handleRestoreVault
              : null,
          icon: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.lock_open, size: 18),
          label: const Text('Restaurar Cofre e Sincronizar'),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

/// Diálogo seguro para visualização da frase de recuperação
class E2eeViewPhraseDialog extends StatelessWidget {
  final String phrase;

  const E2eeViewPhraseDialog({super.key, required this.phrase});

  static Future<void> show(
    BuildContext context, {
    required String phrase,
  }) async {
    // Exige autenticação biométrica ou PIN antes de exibir a frase
    final bioAuth = BiometricAuthService();
    final authenticated = await bioAuth.authenticate(
      context: context,
      localizedReason:
          'Autentique-se para visualizar sua frase de recuperação E2EE',
    );
    if (!authenticated) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Autenticação necessária para visualizar a frase de segurança.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (ctx) => E2eeViewPhraseDialog(phrase: phrase),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final words = phrase.split(' ');

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.lock_outline, color: Colors.blue),
          SizedBox(width: 8),
          Text('Frase de Recuperação E2EE'),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Esta é a sua chave mestra de 24 palavras. Nunca compartilhe esta frase com ninguém.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 280,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                  ),
                ),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 3.2,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                  ),
                  itemCount: words.length,
                  itemBuilder: (ctx, idx) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black45 : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isDark
                              ? Colors.grey.shade700
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            '${idx + 1}.',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              words[idx],
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: phrase));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Frase copiada para a área de transferência!'),
              ),
            );
          },
          icon: const Icon(Icons.copy, size: 16),
          label: const Text('Copiar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fechar'),
        ),
      ],
    );
  }
}
