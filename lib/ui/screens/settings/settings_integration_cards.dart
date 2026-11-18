part of '../settings_screen.dart';

extension _SettingsIntegrationCards on _SettingsScreenState {
  Widget _buildLanguageSelectorCard(BuildContext context) {
    final currentLocale = ref.watch(appLocaleTypeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.language, color: AppTheme.primaryBlue),
                SizedBox(width: 8),
                Text(
                  'Idioma do Aplicativo (i18n)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Alterne entre os idiomas suportados com suporte offline completo.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? const Color(0xFFCBD5E1) : AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AppLocaleType.values.map((loc) {
                final isSelected = loc == currentLocale;
                return ChoiceChip(
                  label: Text('${loc.flagEmoji} ${loc.label}'),
                  selected: isSelected,
                  selectedColor: AppTheme.primaryBlue.withValues(alpha: 0.2),
                  onSelected: (val) {
                    if (val) {
                      ref.read(appLocaleTypeProvider.notifier).setLocale(loc);
                    }
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpdateCheckerCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.system_update_rounded, color: Color(0xFF2563EB)),
                SizedBox(width: 8),
                Text(
                  'Atualizações do Aplicativo',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Versão Atual: ${AppVersion.fullDisplayVersion} (${AppVersion.releaseDate})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              'Verifique novas versões no GitHub Releases ou catálogo LiveContainer.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? const Color(0xFFCBD5E1) : AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 12),
            if (_checkedUpdateInfo != null) ...[
              Builder(
                builder: (context) {
                  final status = _checkedUpdateInfo!.status;
                  final Color cardColor;
                  final IconData cardIcon;
                  final String cardTitle;

                  switch (status) {
                    case UpdateCheckStatus.updateAvailable:
                      cardColor = const Color(0xFF2563EB);
                      cardIcon = Icons.download_for_offline_rounded;
                      cardTitle =
                          'Nova Versão Disponível: v${_checkedUpdateInfo!.latestVersion}';
                      break;
                    case UpdateCheckStatus.upToDate:
                      cardColor = const Color(0xFF16A34A);
                      cardIcon = Icons.check_circle_rounded;
                      cardTitle = 'Você já está usando a versão mais recente!';
                      break;
                    case UpdateCheckStatus.sourceUnavailable:
                      cardColor = const Color(0xFFD97706);
                      cardIcon = Icons.cloud_off_rounded;
                      cardTitle = 'Fonte de atualização indisponível';
                      break;
                    case UpdateCheckStatus.checkFailed:
                      cardColor = const Color(0xFFDC2626);
                      cardIcon = Icons.error_outline_rounded;
                      cardTitle = 'Não foi possível verificar';
                      break;
                  }

                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cardColor.withValues(alpha: isDark ? 0.3 : 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: cardColor.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(cardIcon, color: cardColor, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                cardTitle,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_checkedUpdateInfo!.hasUpdate) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Lançamento: ${_checkedUpdateInfo!.releaseDate} • ${_checkedUpdateInfo!.formattedSize}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _checkedUpdateInfo!.releaseNotes,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(
                              Icons.install_mobile_rounded,
                              size: 18,
                            ),
                            label: const Text('Atualizar Agora'),
                            onPressed: () {
                              ref
                                  .read(updateCheckerServiceProvider)
                                  .launchUpdate(_checkedUpdateInfo!);
                            },
                          ),
                        ] else if (status != UpdateCheckStatus.upToDate) ...[
                          const SizedBox(height: 6),
                          Text(
                            _checkedUpdateInfo!.releaseNotes,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
            if (_updateError != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _updateError!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
              const SizedBox(height: 10),
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: _isCheckingUpdate
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 18),
                label: Text(
                  _isCheckingUpdate
                      ? 'Verificando atualizações...'
                      : 'Verificar Atualizações Agora',
                ),
                onPressed: _isCheckingUpdate
                    ? null
                    : () async {
                        _updateState(() {
                          _isCheckingUpdate = true;
                          _updateError = null;
                        });
                        try {
                          final info = await ref
                              .read(updateCheckStateProvider.notifier)
                              .check(force: true);
                          if (mounted) {
                            _updateState(() {
                              _checkedUpdateInfo = info;
                            });
                          }
                        } catch (e) {
                          if (mounted) {
                            _updateState(() {
                              _updateError = 'Falha ao buscar atualizações: $e';
                            });
                          }
                        } finally {
                          if (mounted) {
                            _updateState(() {
                              _isCheckingUpdate = false;
                            });
                          }
                        }
                      },
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Nota técnica: No iOS/LiveContainer, as políticas de sandbox impedem a auto-substituição do binário em execução; tocar em atualizar abre diretamente a fonte oficial no LiveContainer.',
              style: TextStyle(
                fontSize: 10.5,
                color: isDark ? const Color(0xFF94A3B8) : AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupabaseCard(BuildContext context) {
    final isSupabaseReady = SupabaseSyncService.isInitialized;
    User? currentUser;
    if (isSupabaseReady) {
      try {
        currentUser = Supabase.instance.client.auth.currentUser;
      } catch (e, st) {
        AppLogger.warning('Falha ao obter sessão Supabase atual', e, st);
        currentUser = null;
      }
    }
    final isConnected = currentUser != null;
    final userEmail = currentUser?.email ?? 'Nenhum usuário autenticado';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.cloud_sync, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Conta e Sincronização (Supabase)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(),
            if (!isSupabaseReady) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade700),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.cloud_off,
                      color: Colors.amber.shade800,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Sincronização na nuvem indisponível: Supabase não configurado ou falhou ao inicializar. Operando apenas localmente.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  isConnected
                      ? Icons.check_circle
                      : (isSupabaseReady
                            ? Icons.error_outline
                            : Icons.cloud_off),
                  color: isConnected
                      ? Colors.green
                      : (isSupabaseReady ? Colors.orange : Colors.red),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  isConnected
                      ? 'Status: Conectado'
                      : (isSupabaseReady
                            ? 'Status: Não conectado'
                            : 'Status: Indisponível (offline)'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isConnected
                        ? Colors.green
                        : (isSupabaseReady ? Colors.orange : Colors.red),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('E-mail: $userEmail', style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 10),
            () {
              final effectiveUserId = currentUser?.id ?? 'local_user';
              return FutureBuilder<bool>(
                future: _getE2eeFuture(effectiveUserId),
                builder: (ctx, snapshot) {
                  final isE2eeConfigured = snapshot.data ?? false;
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(height: 2);
                  }
                  if (isE2eeConfigured) {
                    return Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade400),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.lock,
                                color: Colors.green.shade700,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Criptografia de Ponta a Ponta Ativa (E2EE)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Colors.green,
                                  ),
                                ),
                              ),
                              Chip(
                                label: const Text(
                                  'Protegido',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                  ),
                                ),
                                backgroundColor: Colors.green.shade700,
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Seus registros e mídias são cifrados no aparelho com chave BIP-39 e AES-256-GCM antes de trafegar na nuvem.',
                            style: TextStyle(fontSize: 11),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () async {
                                  final updated = await E2eeSetupDialog.show(
                                    context,
                                    userId: effectiveUserId,
                                  );
                                  if (updated == true && mounted) {
                                    _e2eeFuture = null;
                                    _updateState(() {});
                                  }
                                },
                                icon: const Icon(Icons.sync_lock, size: 16),
                                label: const Text(
                                  'Configurar / Restaurar Chave (24 Palavras)',
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final isInstalled = await ref
                                      .read(e2eeServiceProvider)
                                      .isKeyInstalled(effectiveUserId);
                                  final hasVault = currentUser != null
                                      ? await ref
                                            .read(e2eeServiceProvider)
                                            .hasRemoteVault(currentUser.id)
                                      : false;
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          hasVault
                                              ? 'Cofre remoto E2EE ativo e sincronizado com este dispositivo.'
                                              : (isInstalled
                                                    ? 'Chave E2EE instalada localmente neste dispositivo.'
                                                    : 'Chave E2EE não encontrada.'),
                                        ),
                                        backgroundColor: isInstalled
                                            ? Colors.green
                                            : Colors.orange,
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.verified_user, size: 16),
                                label: const Text('Verificar Status do Cofre'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  } else {
                    return Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade700),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.shield_outlined,
                                color: Colors.amber.shade900,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Chave E2EE de 24 Palavras Necessária',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Colors.amber,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'A sincronização com a nuvem requer criptografia de ponta a ponta (E2EE) com frase de segurança de 24 palavras. Configure uma nova chave ou restaure sua frase existente a qualquer momento.',
                            style: TextStyle(fontSize: 11),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final updated = await E2eeSetupDialog.show(
                                context,
                                userId: effectiveUserId,
                              );
                              if (updated == true && mounted) {
                                _e2eeFuture = null;
                                _updateState(() {});
                              }
                            },
                            icon: const Icon(Icons.security, size: 16),
                            label: const Text(
                              'Configurar / Restaurar Chave de 24 Palavras',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber.shade800,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                },
              );
            }(),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!isSupabaseReady)
                  ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        await SupabaseSyncService.initialize();
                        if (mounted) _updateState(() {});
                      } catch (e, st) {
                        AppLogger.error('Falha ao inicializar Supabase', e, st);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Erro ao conectar Supabase: $e'),
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Reconectar / Inicializar Padrão'),
                  ),
                ElevatedButton.icon(
                  onPressed: !isSupabaseReady
                      ? null
                      : () async {
                          try {
                            final result = await ref
                                .read(supabaseSyncServiceProvider)
                                .sync();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(result.message)),
                              );
                            }
                          } catch (e, st) {
                            AppLogger.error(
                              'Erro ao sincronizar via configurações',
                              e,
                              st,
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Erro ao sincronizar: $e'),
                                ),
                              );
                            }
                          }
                        },
                  icon: const Icon(Icons.sync, size: 18),
                  label: const Text('Sincronizar Agora'),
                ),
                if (isConnected)
                  OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        await Supabase.instance.client.auth.signOut();
                        _updateState(() {});
                      } catch (e, st) {
                        AppLogger.warning(
                          'Falha ao fazer logout do Supabase',
                          e,
                          st,
                        );
                      }
                    },
                    icon: const Icon(Icons.logout, color: Colors.red, size: 18),
                    label: const Text(
                      'Sair da Conta (Logout)',
                      style: TextStyle(color: Colors.red),
                    ),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: !isSupabaseReady
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (authContext) => SupabaseAuthScreen(
                                  onAuthenticated: () async {
                                    final db = ref.read(databaseProvider);
                                    String? currentUserId;
                                    try {
                                      if (Supabase.instance.isInitialized) {
                                        currentUserId = Supabase
                                            .instance
                                            .client
                                            .auth
                                            .currentUser
                                            ?.id;
                                      }
                                    } catch (_) {}
                                    if (currentUserId != null &&
                                        currentUserId.isNotEmpty) {
                                      final prep =
                                          await SyncOwnerGuard.prepareWorkspaceForAuthenticatedAccount(
                                            db: db,
                                            authenticatedUserId: currentUserId,
                                          );
                                      if (prep.status ==
                                              AccountWorkspacePreparationStatus
                                                  .requiresConfirmationDueToUnsyncedData &&
                                          authContext.mounted) {
                                        final confirmed = await showDialog<bool>(
                                          context: authContext,
                                          barrierDismissible: false,
                                          builder: (dialogCtx) => AlertDialog(
                                            title: const Text(
                                              'Troca de Conta Detectada',
                                            ),
                                            content: Text(
                                              'Este dispositivo contém ${prep.pendingUnsyncedCount} alteração(ões) local(is) pendente(s) de outra conta. '
                                              'Confirmar limpará os dados locais da conta anterior para manter isolamento total entre contas.',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.of(dialogCtx)
                                                        .pop(false),
                                                child: const Text('Cancelar'),
                                              ),
                                              FilledButton(
                                                onPressed: () =>
                                                    Navigator.of(dialogCtx)
                                                        .pop(true),
                                                child: const Text(
                                                  'Limpar Local e Entrar',
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirmed != true) {
                                          try {
                                            await Supabase.instance.client.auth
                                                .signOut(
                                                  scope: SignOutScope.local,
                                                );
                                          } catch (_) {}
                                          return;
                                        }
                                        await SyncOwnerGuard.prepareWorkspaceForAuthenticatedAccount(
                                          db: db,
                                          authenticatedUserId: currentUserId,
                                          discardUnsyncedIfSwitching: true,
                                        );
                                      }
                                    }
                                    if (!mounted || !authContext.mounted) {
                                      return;
                                    }
                                    Navigator.of(authContext).pop();
                                    _updateState(() {});
                                  },
                                ),
                              ),
                            );
                          },
                    icon: const Icon(Icons.login, size: 18),
                    label: const Text('Fazer Login'),
                  ),
                OutlinedButton.icon(
                  onPressed: () => _showRuntimeSupabaseConfigDialog(context),
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: Text(
                    isSupabaseReady
                        ? 'Configurar Servidor'
                        : 'Configurar Supabase (URL/Chave)',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRuntimeSupabaseConfigDialog(BuildContext context) async {
    final existingUrl = await SupabaseSyncService.getRuntimeUrl() ?? '';
    final hasRuntime = await SupabaseSyncService.hasRuntimeConfig();
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => ManagedTextControllers(
        initialTexts: [existingUrl, ''],
        builder: (ctx, ctrls) {
          final urlCtrl = ctrls[0];
          final keyCtrl = ctrls[1];
          bool isSaving = false;
          String? errorText;

          return StatefulBuilder(
            builder: (ctx, setDlgState) => AlertDialog(
              title: const Text('Configuração Runtime do Supabase'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      SupabaseConfig.isConfigured
                          ? 'Compilado com --dart-define. Definir URL/Chave aqui sobrescreve o servidor em runtime.'
                          : 'Informe a URL e a Chave Anon/Publishable para configurar o login sem recompilar o app. A sincronização em nuvem permanece pausada.',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: urlCtrl,
                      enabled: !isSaving,
                      decoration: const InputDecoration(
                        labelText: 'Supabase URL *',
                        hintText: 'https://seu-projeto.supabase.co',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: keyCtrl,
                      enabled: !isSaving,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Supabase Anon / Publishable Key *',
                        hintText: hasRuntime
                            ? 'Informe para atualizar ou cole a chave...'
                            : 'sb_publishable_... ou eyJ...',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        errorText!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(ctx).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                if (hasRuntime)
                  TextButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            setDlgState(() => isSaving = true);
                            await SupabaseSyncService.clearRuntimeConfig();
                            await SupabaseSyncService.initialize();
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) {
                              _updateState(() {});
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Configuração runtime do Supabase removida.',
                                  ),
                                ),
                              );
                            }
                          },
                    child: const Text(
                      'Remover',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final validationError =
                              SupabaseSyncService.validateSupabaseCredentials(
                                urlCtrl.text,
                                keyCtrl.text,
                              );
                          if (validationError != null) {
                            setDlgState(() => errorText = validationError);
                            return;
                          }
                          setDlgState(() {
                            isSaving = true;
                            errorText = null;
                          });
                          try {
                            await SupabaseSyncService.configureAndInitialize(
                              url: urlCtrl.text,
                              anonKey: keyCtrl.text,
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) {
                              _updateState(() {});
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Supabase inicializado com sucesso em runtime!',
                                  ),
                                  backgroundColor: AppTheme.successGreen,
                                ),
                              );
                            }
                          } catch (e, st) {
                            AppLogger.warning(
                              'Falha ao inicializar Supabase em runtime',
                              e,
                              st,
                            );
                            if (ctx.mounted) {
                              setDlgState(() {
                                isSaving = false;
                                errorText = 'Falha ao inicializar Supabase: $e';
                              });
                            }
                          }
                        },
                  child: Text(isSaving ? 'Conectando...' : 'Salvar e Conectar'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _persistEmailAccountConfig({
    required AppDatabase db,
    required String email,
    required String pass,
    required String imapHost,
    required int imapPort,
    required String smtpHost,
    required int smtpPort,
    required String smtpSecurity,
  }) async {
    final now = Value(DateTime.now());
    await db
        .into(db.appKvStore)
        .insertOnConflictUpdate(
          AppKvStoreCompanion.insert(
            key: 'jw_imap_email',
            value: email,
            updatedAt: now,
          ),
        );
    await const FlutterSecureStorage().write(
      key: 'jw_imap_password',
      value: pass,
    );
    await (db.delete(
      db.appKvStore,
    )..where((t) => t.key.equals('jw_imap_password'))).go();
    await db
        .into(db.appKvStore)
        .insertOnConflictUpdate(
          AppKvStoreCompanion.insert(
            key: 'jw_imap_host',
            value: imapHost,
            updatedAt: now,
          ),
        );
    await db
        .into(db.appKvStore)
        .insertOnConflictUpdate(
          AppKvStoreCompanion.insert(
            key: 'jw_imap_port',
            value: imapPort.toString(),
            updatedAt: now,
          ),
        );
    await db
        .into(db.appKvStore)
        .insertOnConflictUpdate(
          AppKvStoreCompanion.insert(
            key: 'jw_smtp_host',
            value: smtpHost,
            updatedAt: now,
          ),
        );
    await db
        .into(db.appKvStore)
        .insertOnConflictUpdate(
          AppKvStoreCompanion.insert(
            key: 'jw_smtp_port',
            value: smtpPort.toString(),
            updatedAt: now,
          ),
        );
    await db
        .into(db.appKvStore)
        .insertOnConflictUpdate(
          AppKvStoreCompanion.insert(
            key: 'jw_smtp_security',
            value: smtpSecurity,
            updatedAt: now,
          ),
        );
  }

  Future<void> _testAndSaveJwEmail({bool includeImap = true}) async {
    final email = _jwEmailCtrl.text.trim();
    final pass = _jwPasswordCtrl.text;
    final imapHost = _jwHostCtrl.text.trim().isNotEmpty
        ? _jwHostCtrl.text.trim()
        : 'mail.jw.org';
    final imapPort = int.tryParse(_jwPortCtrl.text.trim()) ?? 993;
    final smtpHost = _jwSmtpHostCtrl.text.trim().isNotEmpty
        ? _jwSmtpHostCtrl.text.trim()
        : imapHost;
    final defaultSmtpPort = _jwSmtpSecurity == 'ssl' ? 465 : 587;
    final smtpPort =
        int.tryParse(_jwSmtpPortCtrl.text.trim()) ?? defaultSmtpPort;

    if (email.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Preencha o e-mail e a senha antes de testar a conexão.',
          ),
        ),
      );
      return;
    }

    _updateState(() => _isTestingJwEmail = true);
    try {
      if (includeImap) {
        const imapClient = JwImapClient();
        await imapClient.verifyConnection(
          host: imapHost,
          port: imapPort,
          username: email,
          password: pass,
        );
      }

      const smtpClient = JwSmtpClient();
      await smtpClient.verifyConnection(
        host: smtpHost,
        port: smtpPort,
        username: email,
        password: pass,
        securityMode: _jwSmtpSecurity,
      );

      final db = ref.read(repositoryProvider).db;
      await _persistEmailAccountConfig(
        db: db,
        email: email,
        pass: pass,
        imapHost: imapHost,
        imapPort: imapPort,
        smtpHost: smtpHost,
        smtpPort: smtpPort,
        smtpSecurity: _jwSmtpSecurity,
      );

      await db
          .into(db.appKvStore)
          .insertOnConflictUpdate(
            AppKvStoreCompanion.insert(
              key: 'jw_mail_protocol',
              value: 'imap',
              updatedAt: Value(DateTime.now()),
            ),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              includeImap
                  ? 'Conexões IMAP e SMTP verificadas com sucesso! Configurações salvas com segurança.'
                  : 'Conexão SMTP ($smtpHost:$smtpPort) verificada com sucesso! Configurações salvas.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Falha na verificação de e-mail: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } finally {
      if (mounted) _updateState(() => _isTestingJwEmail = false);
    }
  }

  Future<void> _testExchange() async {
    final host = _exchangeHostCtrl.text.trim();
    final email = _exchangeEmailCtrl.text.trim();
    final password = _exchangePasswordCtrl.text;
    if (host.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe servidor, usuário e senha Exchange.'),
        ),
      );
      return;
    }
    _updateState(() => _isTestingExchange = true);
    try {
      const storage = FlutterSecureStorage();
      var deviceId = await storage.read(key: 'jw_eas_device_id');
      if (deviceId == null || deviceId.isEmpty) {
        deviceId = const Uuid().v4().replaceAll('-', '');
        await storage.write(key: 'jw_eas_device_id', value: deviceId);
      }
      final session = ExchangeProtocolSession(
        host: host,
        username: email,
        password: password,
        deviceId: deviceId,
      );
      try {
        await session.inboxId();
      } finally {
        session.close();
      }
      await storage.write(key: 'jw_eas_password', value: password);
      final db = ref.read(repositoryProvider).db;
      await db.transaction(() async {
        final now = Value(DateTime.now());
        for (final entry in {
          'jw_eas_host': host.toLowerCase(),
          'jw_eas_email': email,
          'jw_mail_protocol': 'exchange',
        }.entries) {
          await db
              .into(db.appKvStore)
              .insertOnConflictUpdate(
                AppKvStoreCompanion.insert(
                  key: entry.key,
                  value: entry.value,
                  updatedAt: now,
                ),
              );
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Conexão Exchange verificada e salva. As mensagens ainda não foram baixadas: abra Inbox & JW Mail e toque em Sincronizar. Leitura experimental.',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 10),
          ),
        );
      }
    } catch (e) {
      String message =
          'Não foi possível verificar o Exchange. Confira servidor, autenticação e rede.';
      if (e is ExchangeException) message = e.message;
      if (e is eas.EasAuthException) message = 'Autenticação Exchange recusada. O provedor pode exigir OAuth ou outro método.';
      if (e is eas.EasForbiddenException) {
        message = 'O servidor negou acesso para este dispositivo ou conta.';
      }
      if (e is eas.EasCommandException && e.requiresProvisioning) message = 'O servidor exige políticas de segurança que o app ainda não aplica.';
      if (e is eas.EasRemoteWipeException) message = 'O servidor solicita ação de segurança; nada foi apagado ou confirmado pelo aplicativo.';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } finally {
      if (mounted) _updateState(() => _isTestingExchange = false);
    }
  }

  Widget _buildExchangeConfigCard() => Card(
    child: ExpansionTile(
      title: const Text(
        'Exchange ActiveSync (experimental)',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Somente leitura da INBOX, por senha (Basic) e HTTPS. Não suporta OAuth, políticas de dispositivo, envio ou anexos. Mensagens podem ser parciais; mantenha o correio oficial e seu backup.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _exchangeEmailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Usuário Exchange',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _exchangePasswordCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Senha Exchange',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _exchangeHostCtrl,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Servidor Exchange (somente nome)',
                  hintText: 'eas.exemplo.org',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Use somente o servidor oficial autorizado pelo provedor; sua senha será enviada a esse servidor via HTTPS.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _isTestingExchange ? null : _testExchange,
                child: Text(
                  _isTestingExchange
                      ? 'Testando Exchange...'
                      : 'Testar Exchange e salvar',
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildJwEmailConfigCard(bool isDark) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.mark_email_unread_outlined,
                  color: AppTheme.primaryBlue,
                  size: 22,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sincronização e Envio de E-mail (IMAP / SMTP)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Use os servidores e portas IMAP e SMTP fornecidos pelo seu provedor. Exchange ActiveSync não é IMAP/SMTP; o teste não valida esse protocolo. O teste IMAP verifica acesso à INBOX sem baixar mensagens.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? const Color(0xFFCBD5E1) : AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _jwEmailCtrl,
              decoration: const InputDecoration(
                labelText: 'E-mail Teocrático *',
                hintText: 'ex: usuario@jw.org ou usuario@jwpub.org',
                prefixIcon: Icon(Icons.email_outlined, size: 18),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _jwPasswordCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Senha ou Senha de Aplicativo *',
                prefixIcon: Icon(Icons.lock_outline, size: 18),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _jwHostCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Servidor IMAP (Entrada)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: _jwPortCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Porta',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _jwSmtpHostCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Servidor SMTP (Saída)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: _jwSmtpPortCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Porta',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text(
                  'Segurança SMTP:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 10),
                ChoiceChip(
                  label: const Text('STARTTLS (587)'),
                  selected: _jwSmtpSecurity == 'starttls',
                  onSelected: (_) {
                    _updateState(() {
                      _jwSmtpSecurity = 'starttls';
                      if (_jwSmtpPortCtrl.text.trim() == '465' ||
                          _jwSmtpPortCtrl.text.trim().isEmpty) {
                        _jwSmtpPortCtrl.text = '587';
                      }
                    });
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('SSL/TLS (465)'),
                  selected: _jwSmtpSecurity == 'ssl',
                  onSelected: (_) {
                    _updateState(() {
                      _jwSmtpSecurity = 'ssl';
                      if (_jwSmtpPortCtrl.text.trim() == '587' ||
                          _jwSmtpPortCtrl.text.trim().isEmpty) {
                        _jwSmtpPortCtrl.text = '465';
                      }
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  icon: _isTestingJwEmail
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined, size: 18),
                  label: Text(
                    _isTestingJwEmail
                        ? 'Testando Conexão...'
                        : 'Testar IMAP/SMTP e Salvar',
                  ),
                  onPressed: _isTestingJwEmail
                      ? null
                      : () => _testAndSaveJwEmail(includeImap: true),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: const Text('Testar Só SMTP'),
                  onPressed: _isTestingJwEmail
                      ? null
                      : () => _testAndSaveJwEmail(includeImap: false),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Limpar'),
                  onPressed: () async {
                    final db = ref.read(repositoryProvider).db;
                    await const FlutterSecureStorage().delete(
                      key: 'jw_imap_password',
                    );
                    for (final k in const [
                      'jw_imap_email',
                      'jw_imap_password',
                      'jw_imap_host',
                      'jw_imap_port',
                      'jw_smtp_host',
                      'jw_smtp_port',
                      'jw_smtp_security',
                    ]) {
                      await (db.delete(
                        db.appKvStore,
                      )..where((t) => t.key.equals(k))).go();
                    }
                    _updateState(() {
                      _jwEmailCtrl.clear();
                      _jwPasswordCtrl.clear();
                      _jwHostCtrl.text = 'mail.jw.org';
                      _jwPortCtrl.text = '993';
                      _jwSmtpHostCtrl.text = 'mail.jw.org';
                      _jwSmtpPortCtrl.text = '587';
                      _jwSmtpSecurity = 'starttls';
                    });
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Configurações removidas.'),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
