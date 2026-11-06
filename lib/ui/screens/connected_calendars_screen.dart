import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../core/date_utils.dart';
import '../../appointments/calendar_provider.dart';
import '../../appointments/calendar_sync_coordinator.dart';

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

    // Apple state
    final aAuth = await coordinator.appleProvider.isAuthorized();
    String? aAcc;
    List<ExternalCalendarItem> aCals = [];
    String? aSelectedId;
    if (aAuth) {
      aAcc = await coordinator.appleProvider.getConnectedAccountName();
      aCals = await coordinator.appleProvider.getAvailableCalendars();
      aSelectedId = await coordinator.appleProvider.getSelectedCalendarId();
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
    final coordinator = ref.read(calendarSyncCoordinatorProvider);
    final authorized = await coordinator.googleProvider.requestAuthorization();
    if (authorized) {
      await _syncNow();
    } else {
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _syncMessage =
              'Aviso: Não foi possível conectar ao Google Calendar (${coordinator.googleProvider.lastError ?? "autorização não concluída"}). Verifique também se a Google Calendar API está ativada no Google Cloud Console.';
        });
      }
    }
    await _loadState();
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
      await _loadState();
    }
  }

  Future<void> _connectApple() async {
    final coordinator = ref.read(calendarSyncCoordinatorProvider);
    final authorized = await coordinator.appleProvider.requestAuthorization();
    if (authorized) {
      await _syncNow();
    }
    await _loadState();
  }

  Future<void> _disconnectApple() async {
    final coordinator = ref.read(calendarSyncCoordinatorProvider);
    await coordinator.appleProvider.disconnect();
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
              await ref
                  .read(calendarSyncCoordinatorProvider)
                  .resolveConflictKeepExternal(conflict);
              await _loadState();
            },
            child: const Text('Usar Versão Externa'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(calendarSyncCoordinatorProvider)
                  .resolveConflictKeepLocal(conflict);
              await _loadState();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Manter Versão do App'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendários Conectados'),
        actions: [
          IconButton(
            icon: _isSyncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
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
          // Banner de privacidade pastoral
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.teal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined, color: Colors.teal, size: 22),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Proteção de Dados Pastorais Sensíveis',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.teal,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Apenas título, horário e endereço são sincronizados. Notas pastorais confidenciais, histórico de visitas e progresso de estudos bíblicos NUNCA são enviados para calendários externos.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_syncMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _syncMessage!,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Seção de Conflitos Pendentes
          if (_conflicts.isNotEmpty) ...[
            const Text(
              'Conflitos Pendentes de Revisão',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 8),
            ..._conflicts.map(
              (c) => Card(
                color: Colors.orange.withValues(alpha: 0.08),
                child: ListTile(
                  leading: const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange,
                  ),
                  title: Text(c.localAppointment.title),
                  subtitle: Text(
                    'Modificado em ambos os lados (${c.providerName})',
                  ),
                  trailing: TextButton(
                    onPressed: () => _showConflictDialog(c),
                    child: const Text('Resolver'),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Card Google Calendar
          Card(
            elevation: 2,
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
                      const CircleAvatar(
                        backgroundColor: Color(0xFF4285F4),
                        child: Icon(Icons.calendar_today, color: Colors.white),
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
                                  ? 'Conectado: ${_googleAccount ?? "Conta Google"}'
                                  : 'Não conectado',
                              style: TextStyle(
                                fontSize: 12,
                                color: _isGoogleAuthorized
                                    ? Colors.green
                                    : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_isGoogleAuthorized)
                        OutlinedButton(
                          onPressed: _disconnectGoogle,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                          child: const Text('Desconectar'),
                        )
                      else
                        ElevatedButton(
                          onPressed: _connectGoogle,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4285F4),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Conectar'),
                        ),
                    ],
                  ),
                  if (_isGoogleAuthorized && _googleCalendars.isNotEmpty) ...[
                    const Divider(height: 24),
                    const Text(
                      'Calendário selecionado para sincronização:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue:
                          _googleCalendars.any(
                            (c) => c.id == _selectedGoogleCalId,
                          )
                          ? _selectedGoogleCalId
                          : _googleCalendars.first.id,
                      items: _googleCalendars
                          .map(
                            (c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(
                                c.title + (c.isPrimary ? ' (Principal)' : ''),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) async {
                        if (val != null) {
                          await ref
                              .read(calendarSyncCoordinatorProvider)
                              .googleProvider
                              .setSelectedCalendarId(val);
                          setState(() => _selectedGoogleCalId = val);
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Card Apple Calendar
          Card(
            elevation: 2,
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
                      const CircleAvatar(
                        backgroundColor: Colors.black87,
                        child: Icon(Icons.apple, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Apple Calendar / iCloud',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              _isAppleAuthorized
                                  ? 'Conectado: ${_appleAccount ?? "Calendário Nativo iOS/macOS"}'
                                  : 'Sincronização nativa com EventKit (iOS / macOS)',
                              style: TextStyle(
                                fontSize: 12,
                                color: _isAppleAuthorized
                                    ? Colors.green
                                    : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_isAppleAuthorized)
                        OutlinedButton(
                          onPressed: _disconnectApple,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                          child: const Text('Desconectar'),
                        )
                      else
                        ElevatedButton(
                          onPressed: _connectApple,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black87,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Ativar'),
                        ),
                    ],
                  ),
                  if (_isAppleAuthorized && _appleCalendars.isNotEmpty) ...[
                    const Divider(height: 24),
                    const Text(
                      'Calendário Apple selecionado:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue:
                          _appleCalendars.any(
                            (c) => c.id == _selectedAppleCalId,
                          )
                          ? _selectedAppleCalId
                          : _appleCalendars.first.id,
                      items: _appleCalendars
                          .map(
                            (c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.title),
                            ),
                          )
                          .toList(),
                      onChanged: (val) async {
                        if (val != null) {
                          await ref
                              .read(calendarSyncCoordinatorProvider)
                              .appleProvider
                              .setSelectedCalendarId(val);
                          setState(() => _selectedAppleCalId = val);
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

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
        ],
      ),
    );
  }
}
