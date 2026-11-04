import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../core/date_utils.dart';
import '../../core/demo_data.dart';
import '../providers.dart';
import 'activities_screen.dart';
import 'trash_screen.dart';
import 'customize_features_screen.dart';
import 'connected_calendars_screen.dart';
import '../../appointments/ics_management_sheet.dart';
import '../../core/app_config.dart';
import '../../core/supabase_initializer.dart';
import '../../database/app_database.dart';
import '../../sync/supabase_auth_service.dart';
import '../../sync/supabase_sync_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  DateTime? _lastBackupAt;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(backupServiceProvider).performSilentBackupIfNeeded();
    });
  }

  // Modal para cadastro de Eventos Teocráticos e Datas Especiais
  void _showAddTheocraticEventDialog(BuildContext context) {
    String selectedType = 'Visita do Superintendente de Circuito';
    final titleController = TextEditingController();
    final locationController = TextEditingController();
    DateTime startDate = DateTime.now().add(const Duration(days: 7));
    TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
    DateTime endDate = startDate;
    TimeOfDay endTime = const TimeOfDay(hour: 16, minute: 30);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.event_available, color: Color(0xFF7C3AED)),
                SizedBox(width: 8),
                Expanded(child: Text('Cadastrar Evento Teocrático')),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cadastre datas especiais para inserção automática no calendário oficial e sincronização.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? const Color(0xFFCBD5E1)
                          : AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: selectedType,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de Evento Teocrático *',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Visita do Superintendente de Circuito',
                        child: Text('Visita do Superintendente de Circuito'),
                      ),
                      DropdownMenuItem(
                        value: 'Assembleia de Circuito',
                        child: Text('Assembleia de Circuito'),
                      ),
                      DropdownMenuItem(
                        value: 'Congresso Regional',
                        child: Text('Congresso Regional'),
                      ),
                      DropdownMenuItem(
                        value: 'Celebração da Morte de Cristo',
                        child: Text('Celebração da Morte de Cristo'),
                      ),
                      DropdownMenuItem(
                        value: 'Reunião Especial',
                        child: Text('Reunião Especial'),
                      ),
                      DropdownMenuItem(
                        value: 'Dia Especial de Testemunho',
                        child: Text('Dia Especial de Testemunho'),
                      ),
                      DropdownMenuItem(
                        value: 'Outro Evento Teocrático',
                        child: Text('Outro Evento Teocrático'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedType = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Tema / Título complementar (opcional)',
                      hintText: 'Ex: Seja Corajoso! ou Tema da Visita',
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Data e Horário de Início:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(
                            AppDateUtils.formatDate(startDate),
                            style: const TextStyle(fontSize: 12),
                          ),
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: startDate,
                              firstDate: DateTime.now().subtract(
                                const Duration(days: 30),
                              ),
                              lastDate: DateTime.now().add(
                                const Duration(days: 730),
                              ),
                            );
                            if (d != null) {
                              setDialogState(() {
                                startDate = d;
                                if (endDate.isBefore(d)) endDate = d;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.access_time, size: 16),
                          label: Text(
                            '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          onPressed: () async {
                            final t = await showTimePicker(
                              context: context,
                              initialTime: startTime,
                            );
                            if (t != null) setDialogState(() => startTime = t);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Data e Horário de Término:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(
                            AppDateUtils.formatDate(endDate),
                            style: const TextStyle(fontSize: 12),
                          ),
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: endDate,
                              firstDate: startDate,
                              lastDate: DateTime.now().add(
                                const Duration(days: 730),
                              ),
                            );
                            if (d != null) setDialogState(() => endDate = d);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.access_time, size: 16),
                          label: Text(
                            '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          onPressed: () async {
                            final t = await showTimePicker(
                              context: context,
                              initialTime: endTime,
                            );
                            if (t != null) setDialogState(() => endTime = t);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: locationController,
                    decoration: const InputDecoration(
                      labelText: 'Local / Salão / Anotações',
                      hintText: 'Ex: Salão de Assembleias, Salão do Reino, JW Stream...',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final startDateTime = DateTime(
                    startDate.year,
                    startDate.month,
                    startDate.day,
                    startTime.hour,
                    startTime.minute,
                  );
                  final endDateTime = DateTime(
                    endDate.year,
                    endDate.month,
                    endDate.day,
                    endTime.hour,
                    endTime.minute,
                  );

                  int durationMins = endDateTime
                      .difference(startDateTime)
                      .inMinutes;
                  if (durationMins <= 0) durationMins = 120;

                  final extra = titleController.text.trim();
                  final fullTitle =
                      '[Evento Teocrático] $selectedType${extra.isNotEmpty ? ": $extra" : ""}';

                  final repo = ref.read(repositoryProvider);
                  await repo.createAppointment(
                    title: fullTitle,
                    startTime: startDateTime,
                    endTime: endDateTime,
                    durationMinutes: durationMins,
                    locationNotes: locationController.text.trim().isEmpty
                        ? null
                        : locationController.text.trim(),
                    status: 'confirmado',
                  );

                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Evento "$selectedType" inserido automaticamente no calendário oficial!',
                        ),
                      ),
                    );
                  }
                },
                child: const Text('Salvar no Calendário'),
              ),
            ],
          );
        },
      ),
    );
  }

  // Modal de Exportação de Backup
  void _showExportDialog(BuildContext context) {
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        final isDarkDialog = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          title: const Text('Exportar Backup Criptografado'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Defina uma senha forte. O arquivo será criptografado com AES-256 e só poderá ser restaurado com esta senha.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDarkDialog
                      ? const Color(0xFFCBD5E1)
                      : AppTheme.textMuted,
                ),
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
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final password = passwordController.text.trim();
                if (password.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'A senha deve conter ao menos 6 caracteres.',
                      ),
                    ),
                  );
                  return;
                }

                final backupService = ref.read(backupServiceProvider);
                final encryptedData = await backupService.exportEncryptedBackup(
                  password,
                );

                setState(() {
                  _lastBackupAt = DateTime.now();
                });

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
                            Clipboard.setData(
                              ClipboardData(text: encryptedData),
                            );
                            Navigator.pop(c);
                            ScaffoldMessenger.of(context).showSnackBar(
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
                }
              },
              child: const Text('Exportar'),
            ),
          ],
        );
      },
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
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final raw = dataController.text.trim();
              final pwd = passwordController.text.trim();

              if (raw.isEmpty || pwd.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Preencha os dados do backup e a senha.'),
                  ),
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
                          const Text(
                            'Registros verificados com integridade SHA-256:',
                          ),
                          const SizedBox(height: 8),
                          Text('• Novos contatos: ${preview.peopleToAdd}'),
                          Text(
                            '• Contatos a atualizar: ${preview.peopleToUpdate}',
                          ),
                          Text(
                            '• Contatos inalterados: ${preview.peopleUnchanged}',
                          ),
                          Text('• Visitas a importar: ${preview.visitsToAdd}'),
                          Text('• Estudos bíblicos: ${preview.studiesToAdd}'),
                          Text('• Sessões de estudo: ${preview.sessionsToAdd}'),
                          Text('• Compromissos: ${preview.appointmentsToAdd}'),
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
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(c),
                          child: const Text('Cancelar'),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            await backupService.commitRestore(preview);
                            if (c.mounted) Navigator.pop(c);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Restauração concluída com sucesso!',
                                  ),
                                ),
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

  // Diálogo de Configuração Dinâmica do Servidor Supabase
  void _showSupabaseConfigDialog(BuildContext context) {
    final currentConfig = ref.read(appConfigProvider);
    final urlController = TextEditingController(text: currentConfig.supabaseUrl);
    final anonKeyController = TextEditingController(text: currentConfig.supabaseAnonKey);
    final googleClientIdController = TextEditingController(text: currentConfig.googleWebClientId);
    bool isSaving = false;
    String? validationError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.cloud_sync, color: AppTheme.primaryBlue),
                SizedBox(width: 8),
                Expanded(child: Text('Configurar Servidor Supabase')),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Informe as credenciais públicas do seu projeto Supabase para habilitar autenticação e sincronização na nuvem.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: urlController,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'URL do Projeto Supabase *',
                      hintText: 'https://seu-projeto.supabase.co',
                      prefixIcon: Icon(Icons.link),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: anonKeyController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Chave Pública Anon Key *',
                      hintText: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
                      prefixIcon: Icon(Icons.vpn_key_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: googleClientIdController,
                    decoration: const InputDecoration(
                      labelText: 'Google Web Client ID (Opcional)',
                      hintText: 'xxxx.apps.googleusercontent.com',
                      prefixIcon: Icon(Icons.g_mobiledata),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (validationError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      validationError!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        final rawUrl = urlController.text.trim();
                        final rawKey = anonKeyController.text.trim();
                        final rawGoogleId = googleClientIdController.text.trim();

                        final testConfig = AppConfig.create(
                          environment: currentConfig.environment,
                          supabaseUrl: rawUrl,
                          supabaseAnonKey: rawKey,
                          googleWebClientId: rawGoogleId,
                        );

                        if (testConfig.isInvalid) {
                          setDialogState(() {
                            validationError = testConfig.validationErrorMessage ??
                                'Configuração inválida.';
                          });
                          return;
                        }

                        setDialogState(() {
                          isSaving = true;
                          validationError = null;
                        });

                        try {
                          final db = ref.read(databaseProvider);
                          await db.into(db.appKvStore).insertOnConflictUpdate(
                                AppKvStoreCompanion.insert(
                                  key: 'config_supabase_url',
                                  value: rawUrl,
                                ),
                              );
                          await db.into(db.appKvStore).insertOnConflictUpdate(
                                AppKvStoreCompanion.insert(
                                  key: 'config_supabase_anon_key',
                                  value: rawKey,
                                ),
                              );
                          if (rawGoogleId.isNotEmpty) {
                            await db.into(db.appKvStore).insertOnConflictUpdate(
                                  AppKvStoreCompanion.insert(
                                    key: 'config_google_web_client_id',
                                    value: rawGoogleId,
                                  ),
                                );
                          }

                          ref.read(appConfigProvider.notifier).updateConfig(testConfig);

                          if (testConfig.status == ConfigStatus.valid) {
                            await SupabaseInitializer.initializeIfConfigured(
                              config: testConfig,
                            );
                          }

                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Servidor Supabase configurado com sucesso!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            _showAuthModal(context);
                          }
                        } catch (e) {
                          setDialogState(() {
                            isSaving = false;
                            validationError = 'Erro ao conectar ao servidor: $e';
                          });
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Salvar e Conectar'),
              ),
            ],
          );
        },
      ),
    );
  }

  // Diálogo para Autenticação Supabase (Login, Cadastro e Recuperação de Senha)
  void _showAuthModal(BuildContext context) {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool isSignUp = false;
    bool isLoading = false;
    String? errorMessage;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final authService = ref.read(supabaseAuthServiceProvider);

          return AlertDialog(
            title: Row(
              children: [
                Icon(
                  isSignUp ? Icons.person_add : Icons.account_circle,
                  color: AppTheme.primaryBlue,
                ),
                const SizedBox(width: 8),
                Text(isSignUp ? 'Criar Nova Conta' : 'Entrar na Conta'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isSignUp
                        ? 'Crie uma conta para sincronizar seus dados entre iPhone, iPad e Web.'
                        : 'Acesse sua conta para sincronizar suas visitas, estudos e territórios.',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                  if (!authService.isConfigured) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.amber, size: 16),
                              SizedBox(width: 6),
                              Text(
                                'Servidor Supabase não configurado',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Configure a URL e Anon Key do seu projeto para poder entrar ou se cadastrar.',
                            style: TextStyle(fontSize: 11),
                          ),
                          const SizedBox(height: 6),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: const Icon(Icons.settings, size: 14),
                            label: const Text('Configurar Servidor', style: TextStyle(fontSize: 11)),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _showSupabaseConfigDialog(context);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'E-mail *',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Senha *',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 8),
                  if (!isSignUp)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: isLoading
                            ? null
                            : () async {
                                final email = emailController.text.trim();
                                if (email.isEmpty) {
                                  setDialogState(() {
                                    errorMessage = 'Informe seu e-mail para recuperar a senha.';
                                  });
                                  return;
                                }
                                setDialogState(() => isLoading = true);
                                final res = await authService.resetPasswordForEmail(email);
                                setDialogState(() {
                                  isLoading = false;
                                  errorMessage = res.message ?? res.error;
                                });
                              },
                        child: const Text('Esqueci minha senha', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading
                    ? null
                    : () {
                        setDialogState(() {
                          isSignUp = !isSignUp;
                          errorMessage = null;
                        });
                      },
                child: Text(
                  isSignUp ? 'Já tem conta? Entrar' : 'Não tem conta? Cadastrar',
                ),
              ),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        final email = emailController.text.trim();
                        final password = passwordController.text;
                        if (email.isEmpty || password.isEmpty) {
                          setDialogState(() {
                            errorMessage = 'Preencha e-mail e senha.';
                          });
                          return;
                        }

                        if (!authService.isConfigured) {
                          setDialogState(() {
                            errorMessage = 'Servidor não configurado. Toque em "Configurar Servidor" acima.';
                          });
                          return;
                        }

                        setDialogState(() {
                          isLoading = true;
                          errorMessage = null;
                        });

                        final result = isSignUp
                            ? await authService.signUpWithEmailPassword(
                                email: email,
                                password: password,
                              )
                            : await authService.signInWithEmailPassword(
                                email: email,
                                password: password,
                              );

                        if (!ctx.mounted) return;

                        if (!result.success) {
                          setDialogState(() {
                            isLoading = false;
                            errorMessage = result.error ?? 'Falha na autenticação.';
                          });
                          return;
                        }

                        Navigator.pop(ctx);
                        _handlePostLoginDataMigration(context, result.user?.id);
                      },
                child: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(isSignUp ? 'Cadastrar' : 'Entrar'),
              ),
            ],
          );
        },
      ),
    );
  }

  // Trata dados locais criados antes do login
  Future<void> _handlePostLoginDataMigration(BuildContext context, String? userId) async {
    if (userId == null) return;
    final repo = ref.read(repositoryProvider);
    final authService = ref.read(supabaseAuthServiceProvider);
    final preLoginCount = await authService.countPreLoginRecords(repo.db);

    if (preLoginCount > 0 && context.mounted) {
      final choice = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.cloud_upload, color: AppTheme.primaryBlue),
              SizedBox(width: 8),
              Expanded(child: Text('Dados Locais Detectados')),
            ],
          ),
          content: Text(
            'Você possui $preLoginCount registro(s) criados neste aparelho antes de entrar na conta. '
            'Deseja associar esses dados à sua conta na nuvem?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'discard'),
              child: const Text('Descartar Locais', style: TextStyle(color: Colors.red)),
            ),
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx, 'keep'),
              child: const Text('Manter no Aparelho'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, 'associate'),
              child: const Text('Associar à Conta (Recomendado)'),
            ),
          ],
        ),
      );

      if (choice == 'associate') {
        await authService.associatePreLoginData(
          repository: repo,
          userId: userId,
        );
      } else if (choice == 'discard') {
        await authService.discardPreLoginData(repo.db);
      }
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sincronizando seus dados com a nuvem...')),
      );
      await ref.read(supabaseSyncServiceProvider).sync();
    }
  }

  // Confirmação de Logout
  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sair da Conta'),
        content: const Text(
          'Deseja realmente sair da sua conta Supabase? '
          'Seus dados salvos localmente permanecerão no aparelho, mas a sincronização na nuvem será pausada.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(supabaseAuthServiceProvider).signOut();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sessão encerrada com sucesso.')),
                );
              }
            },
            child: const Text('Sair', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildSupabaseAccountTile(BuildContext context) {
    final authService = ref.watch(supabaseAuthServiceProvider);
    final user = authService.currentUser;

    if (user != null) {
      return ListTile(
        leading: const Icon(Icons.account_circle, color: Color(0xFF166534), size: 28),
        title: const Text('Conta Supabase Conectada'),
        subtitle: Text(
          user.email ?? 'Usuário Autenticado',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        trailing: TextButton.icon(
          icon: const Icon(Icons.logout, size: 16, color: Colors.red),
          label: const Text('Sair', style: TextStyle(color: Colors.red, fontSize: 12)),
          onPressed: () => _showLogoutConfirmation(context),
        ),
      );
    }

    final isConfigured = authService.isConfigured;

    if (!isConfigured) {
      return ListTile(
        leading: const Icon(Icons.cloud_queue, color: Color(0xFFD97706), size: 28),
        title: const Text('Conta Supabase (Nuvem)'),
        subtitle: const Text('Servidor não configurado. Toque para conectar seu projeto.'),
        trailing: ElevatedButton.icon(
          icon: const Icon(Icons.settings, size: 16),
          label: const Text('Configurar', style: TextStyle(fontSize: 12)),
          onPressed: () => _showSupabaseConfigDialog(context),
        ),
      );
    }

    return ListTile(
      leading: const Icon(Icons.cloud_off, color: Color(0xFFD97706), size: 28),
      title: const Text('Conta Supabase'),
      subtitle: const Text('Não conectado. Entre para sincronizar entre aparelhos.'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 20),
            tooltip: 'Configurações do Servidor',
            onPressed: () => _showSupabaseConfigDialog(context),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.login, size: 16),
            label: const Text('Entrar', style: TextStyle(fontSize: 12)),
            onPressed: () => _showAuthModal(context),
          ),
        ],
      ),
    );
  }

  // Modal de Inspeção da Fila de Sincronização
  void _showSyncQueueModal(BuildContext context) async {
    final repo = ref.read(repositoryProvider);
    final pendingOps = await repo.getPendingSyncOperations();

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.cloud_sync,
                  color: AppTheme.primaryBlue,
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Fila de Sincronização',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${pendingOps.length} operação(ões) aguardando sincronização com a nuvem:',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(ctx).brightness == Brightness.dark
                    ? const Color(0xFFCBD5E1)
                    : AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 12),
            if (pendingOps.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: AppTheme.successGreen,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Tudo sincronizado ou sem alterações pendentes.',
                      style: TextStyle(
                        color: Color(0xFF166534),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 250),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: pendingOps.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final op = pendingOps[index];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Chip(
                        label: Text(
                          op.operation.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        backgroundColor: op.operation == 'insert'
                            ? const Color(0xFFDCFCE7)
                            : op.operation == 'update'
                            ? const Color(0xFFFEF3C7)
                            : const Color(0xFFFEE2E2),
                      ),
                      title: Text(
                        '${op.entityType} (${op.entityId.substring(0, op.entityId.length > 8 ? 8 : op.entityId.length)}...)',
                      ),
                      subtitle: Text(
                        'Tentativas: ${op.attempts} • Criado em: ${AppDateUtils.formatDateTime(op.createdAt)}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allAppointments = ref.watch(appointmentsStreamProvider).value ?? [];
    final theocraticEvents =
        allAppointments
            .where(
              (a) =>
                  a.deletedAt == null &&
                  (a.title.startsWith('[Evento Teocrático]') ||
                      a.title.startsWith('[Evento]') ||
                      a.status == 'evento_teocratico'),
            )
            .toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));

    return Scaffold(
      appBar: AppBar(title: const Text('Configurações e Segurança')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Seção: Sincronização
          const Text(
            'Sincronização e Nuvem',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _buildSupabaseAccountTile(context),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.sync, color: AppTheme.primaryBlue),
                  title: const Text('Estado da Sincronização'),
                  subtitle: Text(
                    ref.watch(supabaseAuthServiceProvider).isAuthenticated
                        ? 'Sincronização na nuvem ativa (Multi-dispositivo).'
                        : 'Operando Local-First (Offline). Alterações gravadas localmente.',
                  ),
                  trailing: Chip(
                    label: Text(
                      ref.watch(supabaseAuthServiceProvider).isAuthenticated
                          ? 'Nuvem Ativa'
                          : 'Local-First',
                      style: const TextStyle(fontSize: 11),
                    ),
                    backgroundColor:
                        ref.watch(supabaseAuthServiceProvider).isAuthenticated
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFE0E7FF),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    bottom: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.cloud_sync, size: 18),
                          label: const Text('Ver Fila', style: TextStyle(fontSize: 12)),
                          onPressed: () => _showSyncQueueModal(context),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Sincronizar', style: TextStyle(fontSize: 12)),
                          onPressed: () async {
                            final scaffold = ScaffoldMessenger.of(context);
                            scaffold.hideCurrentSnackBar();
                            scaffold.showSnackBar(
                              const SnackBar(
                                content: Text('Sincronizando com a nuvem...'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                            final result = await ref.read(supabaseSyncServiceProvider).sync();
                            scaffold.hideCurrentSnackBar();
                            scaffold.showSnackBar(
                              SnackBar(
                                content: Text(
                                  result.success
                                      ? 'Sincronização concluída (${result.totalProcessed} processados).'
                                      : 'Sincronização finalizada: ${result.message}',
                                ),
                                backgroundColor: result.success ? const Color(0xFF166534) : null,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.calendar_month,
                    color: AppTheme.primaryBlue,
                  ),
                  title: const Text('Calendários Conectados'),
                  subtitle: const Text(
                    'Google Agenda e Apple Calendário com sincronização bidirecional.',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ConnectedCalendarsScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  key: const ValueKey('settings_ics_import_export_tile'),
                  leading: const Icon(
                    Icons.file_download_outlined,
                    color: Color(0xFF7C3AED),
                  ),
                  title: const Text('Importar / Exportar Calendário (.ics)'),
                  subtitle: const Text(
                    'Importação e exportação de compromissos via arquivo iCalendar.',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () => showIcsManagementModal(context, ref),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Seção: Backup Criptografado
          const Text(
            'Cópia de Segurança (Backup)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.shield_outlined,
                    color: AppTheme.accentTeal,
                  ),
                  title: const Text('Backup Criptografado (AES-256)'),
                  subtitle: const Text(
                    'Exportação manual protegida por senha com verificação de integridade.',
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    _lastBackupAt != null
                        ? 'Último backup nesta sessão: ${AppDateUtils.formatDateTime(_lastBackupAt!)}'
                        : 'Nenhum backup realizado nesta sessão',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? const Color(0xFFCBD5E1)
                          : AppTheme.textMuted,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
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
          const SizedBox(height: 12),

          // Ideia 7: Backup Automático Silencioso
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.successGreen.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.cloud_done_outlined,
                              color: AppTheme.successGreen,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Backup Silencioso Automático',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                'Proteção diária em segundo plano',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.successGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Ativo (24h)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.successGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<DateTime?>(
                    future: ref
                        .read(backupServiceProvider)
                        .getLastSilentBackupDate(),
                    builder: (context, snapshot) {
                      final dt = snapshot.data;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              dt != null
                                  ? 'Último backup silencioso: ${AppDateUtils.formatDateTime(dt)}'
                                  : 'Primeiro backup diário pronto para execução.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? const Color(0xFFCBD5E1)
                                    : AppTheme.textMuted,
                              ),
                            ),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: const Icon(Icons.sync, size: 14),
                            label: const Text(
                              'Executar Agora',
                              style: TextStyle(fontSize: 11),
                            ),
                            onPressed: () async {
                              final backupSvc = ref.read(backupServiceProvider);
                              final success = await backupSvc
                                  .performSilentBackupIfNeeded(force: true);
                              setState(() {});
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      success
                                          ? 'Backup silencioso concluído com sucesso!'
                                          : 'Erro ao gerar backup silencioso.',
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Seção: Datas Especiais & Eventos Teocráticos
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Datas Especiais & Eventos Teocráticos',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Cadastrar'),
                onPressed: () => _showAddTheocraticEventDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ListTile(
                  leading: Icon(
                    Icons.event_available,
                    color: Color(0xFF7C3AED),
                  ),
                  title: Text('Eventos Oficiais e Visitas'),
                  subtitle: Text(
                    'Visita do Viajante, Assembleias, Congresso e Celebração integrados ao calendário oficial.',
                  ),
                ),
                if (theocraticEvents.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      bottom: 16,
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Nenhum evento teocrático cadastrado no momento.\nToque em "+ Cadastrar" para programar no calendário.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? const Color(0xFFCBD5E1)
                              : AppTheme.textMuted,
                        ),
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: theocraticEvents.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final event = theocraticEvents[index];
                      final displayTitle = event.title
                          .replaceFirst('[Evento Teocrático] ', '')
                          .replaceFirst('[Evento] ', '');
                      return ListTile(
                        dense: true,
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C3AED)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.calendar_month,
                            color: Color(0xFF7C3AED),
                            size: 18,
                          ),
                        ),
                        title: Text(
                          displayTitle,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Text(
                          '${AppDateUtils.formatDateTime(event.startTime)} • ${event.locationNotes ?? "Sem local definido"}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: AppTheme.alertRed,
                          ),
                          tooltip: 'Excluir evento',
                          onPressed: () async {
                            final repo = ref.read(repositoryProvider);
                            await repo.deleteAppointment(event.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Evento removido do calendário.',
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      );
                    },
                  ),
                Padding(
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    bottom: 12,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Cadastrar Novo Evento Teocrático'),
                      onPressed: () => _showAddTheocraticEventDialog(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Seção: Módulos Adicionais
          const Text(
            'Módulos e Recursos',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.dashboard_customize_outlined,
                    color: Color(0xFF7C3AED),
                  ),
                  title: const Text('Personalizar Aplicativo e Recursos'),
                  subtitle: const Text(
                    'Ative ou oculte módulos (Estudos, Agenda, Pesquisa, etc.) com preservação total de dados.',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CustomizeFeaturesScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.timer_outlined,
                    color: AppTheme.primaryBlue,
                  ),
                  title: const Text('Atividades e Metas de Serviço'),
                  subtitle: const Text(
                    'Registro de horas diárias, modalidades e metas anuais.',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ActivitiesScreen(),
                      ),
                    );
                  },
                ),

                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline,
                    color: AppTheme.alertRed,
                  ),
                  title: const Text('Lixeira e Registros Excluídos'),
                  subtitle: const Text(
                    'Recuperação de contatos, visitas e compromissos excluídos.',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TrashScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Seção: Experiência e Acessibilidade no Campo
          const Text(
            'Acessibilidade e Campo',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.wb_sunny_outlined,
                    color: AppTheme.alertAmber,
                  ),
                  title: const Text('Modo Sol Intenso & Alto Contraste'),
                  subtitle: const Text(
                    'Tipografia semibold, superfícies claras e bordas reforçadas para uso sob luz direta do sol no ministério.',
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.successGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Ativo',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.successGreen,
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.devices, color: AppTheme.primaryBlue),
                  title: Text('Responsividade Mobile & Tablet'),
                  subtitle: Text(
                    'Interface otimizada com área de toque mínima de 44x44px para iPhone XR e iPad 11.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Seção: Demonstração e Testes
          const Text(
            'Dados e Demonstração',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.science_outlined,
                    color: Color(0xFF7C3AED),
                  ),
                  title: const Text('Dados de Demonstração Isolados'),
                  subtitle: const Text(
                    'Gera pessoas, visitas, estudos e agenda fictícios para experimentação.',
                  ),
                  trailing: TextButton(
                    onPressed: () async {
                      final repo = ref.read(repositoryProvider);
                      await DemoDataGenerator.populateDemoData(repo);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Dados de demonstração gerados com sucesso!',
                            ),
                          ),
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
          Center(
            child: Column(
              children: [
                Text(
                  'Ministério Pessoal • v1.0.0 (Offline-First)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? const Color(0xFFCBD5E1)
                        : AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Construído para iPhone XR, iPad 11 A16 e Windows Web',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? const Color(0xFFCBD5E1)
                        : AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
