import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../core/date_utils.dart';
import '../../appointments/calendar_provider.dart';
import '../../appointments/calendar_sync_coordinator.dart';
import '../../appointments/ics_management_sheet.dart';

class ConnectedCalendarsScreen extends ConsumerStatefulWidget {
  const ConnectedCalendarsScreen({super.key});

  @override
  ConsumerState<ConnectedCalendarsScreen> createState() =>
      _ConnectedCalendarsScreenState();
}

class _ConnectedCalendarsScreenState
    extends ConsumerState<ConnectedCalendarsScreen> {
  bool _isSyncing = false;
  String? _syncMessage;
  bool _isGoogleAuthorized = false;
  String? _googleAccount;
  List<ExternalCalendarItem> _googleCalendars = [];
  String? _selectedGoogleCalId;

  bool _isAppleAuthorized = false;
  String? _appleAccount;
  List<ExternalCalendarItem> _appleCalendars = [];
  String? _selectedAppleCalId;

  List<CalendarConflictItem> _conflicts = [];

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final coordinator = ref.read(calendarSyncCoordinatorProvider);

    // Google state
    final gAuth = await coordinator.googleProvider.isAuthorized();
    String? gAcc;
    List<ExternalCalendarItem> gCals = [];
    String? gSelectedId;
    if (gAuth) {
      gAcc = await coordinator.googleProvider.getConnectedAccountName();
      gCals = await coordinator.googleProvider.getAvailableCalendars();
      gSelectedId = await coordinator.googleProvider.getSelectedCalendarId();
    }

    // Apple state (somente executado em plataformas com suporte nativo)
    bool aAuth = false;
    String? aAcc;
    List<ExternalCalendarItem> aCals = [];
    String? aSelectedId;
    if (!kIsWeb) {
      aAuth = await coordinator.appleProvider.isAuthorized();
      if (aAuth) {
        aAcc = await coordinator.appleProvider.getConnectedAccountName();
        aCals = await coordinator.appleProvider.getAvailableCalendars();
        aSelectedId = await coordinator.appleProvider.getSelectedCalendarId();
      }
    }

    final pendingConflicts = await coordinator.getPendingConflicts();

    if (mounted) {
      setState(() {
        _isGoogleAuthorized = gAuth;
        _googleAccount = gAcc;
        _googleCalendars = gCals;
        _selectedGoogleCalId =
            gSelectedId ?? (gCals.isNotEmpty ? gCals.first.id : 'primary');

        _isAppleAuthorized = aAuth;
        _appleAccount = aAcc;
        _appleCalendars = aCals;
        _selectedAppleCalId =
            aSelectedId ?? (aCals.isNotEmpty ? aCals.first.id : null);

        _conflicts = pendingConflicts;
      });
    }
  }

  Future<void> _syncNow() async {
    setState(() {
      _isSyncing = true;
      _syncMessage = null;
    });

    final coordinator = ref.read(calendarSyncCoordinatorProvider);
    final result = await coordinator.syncAll();

    if (mounted) {
      setState(() {
        _isSyncing = false;
        if (result.success) {
          _syncMessage =
              'Sincronização concluída com sucesso! (${result.eventsDownloaded} recebidos, ${result.eventsUploaded} enviados)';
        } else {
          _syncMessage = 'Aviso: ${result.errorMessage}';
        }
      });
      await _loadState();
    }
  }

  Future<void> _connectGoogle() async {
    setState(() {
      _isSyncing = true;
      _syncMessage = null;
    });

    try {
      final coordinator = ref.read(calendarSyncCoordinatorProvider);
      final authorized = await coordinator.googleProvider
          .requestAuthorization();
      if (authorized) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Conta Google conectada com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
        await _syncNow();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Não foi possível conectar ao Google Calendar. Verifique a autenticação e tente novamente.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao conectar ao Google Agenda: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
        await _loadState();
      }
    }
  }

  Future<void> _disconnectGoogle() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desconectar Google Agenda?'),
        content: const Text(
          'A desconexão remove o acesso à sua conta Google. Seus compromissos e históricos pastorais salvos no Field Assistant permanecerão 100% preservados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Desconectar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final coordinator = ref.read(calendarSyncCoordinatorProvider);
      await coordinator.googleProvider.disconnect();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google Calendar desconectado.')),
        );
      }
      await _loadState();
    }
  }

  Future<void> _connectApple() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'A sincronização com calendário nativo/Apple Calendar só está disponível em dispositivos iOS e macOS.',
          ),
          backgroundColor: Colors.blueGrey,
        ),
      );
      return;
    }

    setState(() {
      _isSyncing = true;
      _syncMessage = null;
    });

    try {
      final coordinator = ref.read(calendarSyncCoordinatorProvider);
      final authorized = await coordinator.appleProvider.requestAuthorization();
      if (authorized) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Acesso ao calendário do dispositivo autorizado!'),
              backgroundColor: Colors.green,
            ),
          );
        }
        await _syncNow();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Permissão de acesso ao calendário negada pelo usuário.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao autorizar calendário: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
        await _loadState();
      }
    }
  }

  Future<void> _disconnectApple() async {
    final coordinator = ref.read(calendarSyncCoordinatorProvider);
    await coordinator.appleProvider.disconnect();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Calendário do dispositivo desvinculado.'),
        ),
      );
    }
    await _loadState();
  }

  void _showConflictDialog(CalendarConflictItem conflict) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Conflito de Sincronização'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'O compromisso foi modificado tanto no Field Assistant quanto no calendário externo.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Versão Field Assistant:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  Text(
                    '${conflict.localAppointment.title} (${AppDateUtils.formatDateTime(conflict.localAppointment.startTime)})',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (conflict.externalEvent != null)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Versão Calendário Externo:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '${conflict.externalEvent!.title} (${AppDateUtils.formatDateTime(conflict.externalEvent!.startTime)})',
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final coordinator = ref.read(calendarSyncCoordinatorProvider);
              await coordinator.resolveConflictKeepExternal(conflict);
              await _loadState();
            },
            child: const Text('Manter Versão Externa'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final coordinator = ref.read(calendarSyncCoordinatorProvider);
              await coordinator.resolveConflictKeepLocal(conflict);
              await _loadState();
            },
            child: const Text('Manter Versão Local'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendários Conectados'),
        actions: [
          IconButton(
            icon: _isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            tooltip: 'Sincronizar Agora',
            onPressed: _isSyncing ? null : _syncNow,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Banner explicativo sobre configuração única e sincronização bidirecional
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primaryBlue.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.sync_alt,
                  color: AppTheme.primaryBlue,
                  size: 26,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sincronização Bidirecional Automática',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Conecte seu Google Calendar ou Apple Calendar uma única vez. As alterações feitas no Field Assistant serão enviadas aos calendários externos, e seus eventos externos aparecerão na sua agenda de forma contínua.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).textTheme.bodyMedium?.color
                              ?.withValues(alpha: 0.85),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_syncMessage != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _syncMessage!.startsWith('Aviso')
                    ? Colors.orange.withValues(alpha: 0.15)
                    : Colors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _syncMessage!,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _syncMessage!.startsWith('Aviso')
                      ? Colors.orange[900]
                      : Colors.green[900],
                ),
              ),
            ),

          // Seção Conflitos (se houver)
          if (_conflicts.isNotEmpty) ...[
            Card(
              color: Colors.amber.withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Colors.amber),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.warning, color: Colors.amber),
                        const SizedBox(width: 8),
                        Text(
                          '${_conflicts.length} Conflito(s) Pendente(s)',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Detectamos edições simultâneas que requerem sua escolha para evitar sobrescrita silenciosa:',
                    ),
                    const SizedBox(height: 12),
                    for (final c in _conflicts)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(c.localAppointment.title),
                        subtitle: Text(
                          AppDateUtils.formatDateTime(
                            c.localAppointment.startTime,
                          ),
                        ),
                        trailing: ElevatedButton(
                          onPressed: () => _showConflictDialog(c),
                          child: const Text('Resolver'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // CARD GOOGLE CALENDAR
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.calendar_today,
                          color: Colors.red,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Google Calendar',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              _isGoogleAuthorized
                                  ? (_googleAccount ?? 'Conta Conectada')
                                  : 'Não conectado',
                              style: TextStyle(
                                fontSize: 13,
                                color: _isGoogleAuthorized
                                    ? Colors.green[700]
                                    : Colors.grey,
                                fontWeight: _isGoogleAuthorized
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_isGoogleAuthorized)
                        OutlinedButton(
                          onPressed: _disconnectGoogle,
                          child: const Text('Desconectar'),
                        )
                      else
                        ElevatedButton.icon(
                          icon: const Icon(Icons.login, size: 18),
                          label: const Text('Conectar'),
                          onPressed: _connectGoogle,
                        ),
                    ],
                  ),
                  if (_isGoogleAuthorized && _googleCalendars.isNotEmpty) ...[
                    const Divider(height: 24),
                    const Text(
                      'Calendário de Destino:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedGoogleCalId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      items: _googleCalendars.map((c) {
                        return DropdownMenuItem<String>(
                          value: c.id,
                          child: Text(
                            '${c.name}${c.isReadOnly ? " (Somente Leitura)" : ""}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) async {
                        if (val != null) {
                          setState(() => _selectedGoogleCalId = val);
                          final coordinator = ref.read(
                            calendarSyncCoordinatorProvider,
                          );
                          await coordinator.googleProvider
                              .setSelectedCalendarId(val);
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // CARD APPLE CALENDAR / EVENTKIT
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.white : Colors.black)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.apple,
                          color: isDark ? Colors.white : Colors.black,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Apple Calendar / Dispositivo',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              kIsWeb
                                  ? 'Disponível no app iOS / macOS'
                                  : (_isAppleAuthorized
                                        ? (_appleAccount ?? 'Acesso Autorizado')
                                        : 'Não autorizado'),
                              style: TextStyle(
                                fontSize: 13,
                                color: kIsWeb
                                    ? Colors.grey
                                    : (_isAppleAuthorized
                                          ? Colors.green[700]
                                          : Colors.grey),
                                fontWeight: (!kIsWeb && _isAppleAuthorized)
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (kIsWeb)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Apenas iOS',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )
                      else if (_isAppleAuthorized)
                        OutlinedButton(
                          onPressed: _disconnectApple,
                          child: const Text('Desvincular'),
                        )
                      else
                        ElevatedButton.icon(
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Autorizar'),
                          onPressed: _connectApple,
                        ),
                    ],
                  ),
                  if (kIsWeb) ...[
                    const SizedBox(height: 10),
                    Text(
                      'No navegador Web, utilize a integração oficial com Google Calendar ou importe/exporte arquivos .ics na seção de Sincronização das Configurações.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodySmall?.color
                            ?.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                  if (!kIsWeb &&
                      _isAppleAuthorized &&
                      _appleCalendars.isNotEmpty) ...[
                    const Divider(height: 24),
                    const Text(
                      'Calendário Selecionado no Dispositivo:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedAppleCalId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      items: _appleCalendars.map((c) {
                        return DropdownMenuItem<String>(
                          value: c.id,
                          child: Text(
                            '${c.name} (${c.accountName ?? "Local"})${c.isReadOnly ? " [Leitura]" : ""}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) async {
                        if (val != null) {
                          setState(() => _selectedAppleCalId = val);
                          final coordinator = ref.read(
                            calendarSyncCoordinatorProvider,
                          );
                          await coordinator.appleProvider.setSelectedCalendarId(
                            val,
                          );
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Botão Sincronizar Tudo
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              icon: _isSyncing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.sync),
              label: Text(
                _isSyncing
                    ? 'Sincronizando...'
                    : 'Sincronizar Todos os Calendários Agora',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _isSyncing ? null : _syncNow,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              icon: const Icon(
                Icons.file_download_outlined,
                color: Color(0xFF7C3AED),
              ),
              label: const Text('Importar / Exportar Arquivo .ics (iCalendar)'),
              onPressed: () => showIcsManagementModal(context, ref),
            ),
          ),
        ],
      ),
    );
  }
}
