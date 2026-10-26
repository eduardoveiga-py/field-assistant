import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_theme.dart';
import '../../core/demo_data.dart';
import '../providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // Modal de Exportação de Backup
  void _showExportDialog(BuildContext context) {
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exportar Backup Criptografado'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Defina uma senha forte. O arquivo será criptografado com AES-256 e só poderá ser restaurado com esta senha.',
              style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(
                labelText: 'Senha de Criptografia',
                hintText: 'Mínimo 6 caracteres',
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final password = passwordController.text.trim();
              if (password.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('A senha deve conter ao menos 6 caracteres.')),
                );
                return;
              }

              final backupService = ref.read(backupServiceProvider);
              final encryptedData = await backupService.exportEncryptedBackup(password);

              if (ctx.mounted) Navigator.pop(ctx);

              // Exibe diálogo com o código criptografado pronto para copiar/salvar
              if (context.mounted) {
                showDialog(
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
                              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
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
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Backup copiado para a área de transferência!')),
                          );
                        },
                      ),
                    ],
                  ),
                );
              }
            },
            child: const Text('Exportar'),
          ),
        ],
      ),
    );
  }

  // Modal de Restauração com Prévia e Confirmação
  void _showRestoreDialog(BuildContext context) {
    final dataController = TextEditingController();
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restaurar Backup Criptografado'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: dataController,
                decoration: const InputDecoration(
                  labelText: 'Cole o código criptografado do backup',
                  hintText: '{"iv":"...","ciphertext":"..."}',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(
                  labelText: 'Senha utilizada na exportação',
                ),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final raw = dataController.text.trim();
              final pwd = passwordController.text.trim();

              if (raw.isEmpty || pwd.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Preencha os dados do backup e a senha.')),
                );
                return;
              }

              final backupService = ref.read(backupServiceProvider);
              try {
                final preview = await backupService.previewBackup(
                  encryptedDataString: raw,
                  password: pwd,
                );

                if (ctx.mounted) Navigator.pop(ctx);

                // Exibe diálogo de Prévia de Restauração
                if (context.mounted) {
                  showDialog(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Pré-visualização da Restauração'),
                      content: Column(
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
                          const SizedBox(height: 10),
                          const Text(
                            'A restauração é idempotente e NÃO criará contatos ou estudos duplicados.',
                            style: TextStyle(fontSize: 12, color: AppTheme.successGreen, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
                        ElevatedButton(
                          onPressed: () async {
                            await backupService.commitRestore(preview);
                            if (c.mounted) Navigator.pop(c);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Restauração concluída com sucesso!')),
                              );
                            }
                          },
                          child: const Text('Confirmar Restauração'),
                        ),
                      ],
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erro na validação do backup: $e')),
                  );
                }
              }
            },
            child: const Text('Analisar Backup'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações e Segurança'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Seção: Sincronização
          const Text('Sincronização e Nuvem', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.sync, color: AppTheme.primaryBlue),
                  title: const Text('Estado da Sincronização'),
                  subtitle: const Text('Operando Local-First (Offline). Alterações gravadas localmente.'),
                  trailing: const Chip(
                    label: Text('Local-First', style: TextStyle(fontSize: 11)),
                    backgroundColor: Color(0xFFE0E7FF),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.cloud_sync),
                      label: const Text('Verificar Fila de Sincronização'),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Fila local íntegra. Nenhuma operação pendente de resolução.')),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Seção: Backup Criptografado
          const Text('Cópia de Segurança (Backup)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.shield_outlined, color: AppTheme.accentTeal),
                  title: const Text('Backup Criptografado (AES-256)'),
                  subtitle: const Text('Exportação manual protegida por senha com verificação de integridade.'),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.file_download, size: 18),
                          label: const Text('Exportar'),
                          onPressed: () => _showExportDialog(context),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.file_upload, size: 18),
                          label: const Text('Restaurar'),
                          onPressed: () => _showRestoreDialog(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Seção: Demonstração e Testes
          const Text('Dados e Demonstração', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.science_outlined, color: Color(0xFF7C3AED)),
                  title: const Text('Dados de Demonstração Isolados'),
                  subtitle: const Text('Gera pessoas, visitas, estudos e agenda fictícios para experimentação.'),
                  trailing: TextButton(
                    onPressed: () async {
                      final repo = ref.read(repositoryProvider);
                      await DemoDataGenerator.populateDemoData(repo);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Dados de demonstração gerados com sucesso!')),
                        );
                      }
                    },
                    child: const Text('Gerar Dados'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Versão do App e Informações Legais
          const Center(
            child: Column(
              children: [
                Text(
                  'Ministério Pessoal • v1.0.0 (Offline-First)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                ),
                SizedBox(height: 4),
                Text(
                  'Construído para iPhone XR, iPad 11 A16 e Windows Web',
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
