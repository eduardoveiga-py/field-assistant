import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../core/date_utils.dart';
import '../../appointments/calendar_provider.dart';
import '../../appointments/calendar_sync_coordinator.dart';
import '../providers.dart';

/// Mantém apenas IDs válidos e únicos para os seletores de calendário.
List<ExternalCalendarItem> uniqueCalendarItems(List<ExternalCalendarItem> items) {
  final seen = <String>{};
  return items.where((item) => item.id.isNotEmpty && seen.add(item.id)).toList();
}

/// Não troca silenciosamente um destino salvo que deixou de estar disponível.
String? resolveCalendarSelection(
  List<ExternalCalendarItem> items,
  String? selectedId, {
  bool google = false,
}) {
  if (items.any((item) => item.id == selectedId)) return selectedId;
  if (google && selectedId == 'primary') {
    final primary = items.where((item) => item.isPrimary).toList();
    if (primary.length == 1) return primary.single.id;
  }
  return null;
}

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
  Set<String> _readOnlyGoogleCalIds = {};

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
    Set<String> gReadOnlyIds = {};
    if (gAuth) {
      gAcc = await coordinator.googleProvider.getConnectedAccountName();
      gCals = uniqueCalendarItems(
        await coordinator.googleProvider.getAvailableCalendars(),
      );
      gSelectedId = await coordinator.googleProvider.getSelectedCalendarId();
      gReadOnlyIds = await coordinator.googleProvider.getReadOnlyCalendarIds();
    }

    // Apple state
    final aAuth = await coordinator.appleProvider.isAuthorized();
    String? aAcc;
    List<ExternalCalendarItem> aCals = [];
    String? aSelectedId;
    if (aAuth) {
      aAcc = await coordinator.appleProvider.getConnectedAccountName();
      aCals = uniqueCalendarItems(
        await coordinator.appleProvider.getAvailableCalendars(),
      );
      aSelectedId = await coordinator.appleProvider.getSelectedCalendarId();
    }

    final pendingConflicts = await coordinator.getPendingConflicts();

    if (mounted) {
      setState(() {
        _isGoogleAuthorized = gAuth;
        _googleAccount = gAcc;
        _googleCalendars = gCals;
        _selectedGoogleCalId = resolveCalendarSelection(
          gCals.where((calendar) => !calendar.isReadOnly).toList(),
          gSelectedId, google: true,
        );
        _readOnlyGoogleCalIds = gReadOnlyIds;

        _isAppleAuthorized = aAuth;
        _appleAccount = aAcc;
        _appleCalendars = aCals;
        _selectedAppleCalId = resolveCalendarSelection(aCals, aSelectedId);

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
                      ? Colors.orange[400]
                      : Colors.green[400],
                ),
              ),
            ),

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
                                    ? Colors.green[500]
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
                      key: ValueKey('google-$_selectedGoogleCalId'),
                      initialValue: _selectedGoogleCalId,
                      hint: const Text('Selecione um calendário disponível'),
                      isExpanded: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      items: _googleCalendars.where((calendar) => !calendar.isReadOnly).map((c) {
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
                    if (_googleCalendars.any((calendar) => calendar.isReadOnly)) ...[
                      const SizedBox(height: 12),
                      const Text('Calendários adicionais (somente leitura)',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const Text('Selecione, por exemplo, seus calendários de feriados.'),
                      for (final calendar in _googleCalendars.where((c) => c.isReadOnly))
                        CheckboxListTile(
                          dense: true,
                          title: Text(calendar.name),
                          value: _readOnlyGoogleCalIds.contains(calendar.id),
                          onChanged: (selected) async {
                            final ids = Set<String>.of(_readOnlyGoogleCalIds);
                            if (selected == true) {
                              ids.add(calendar.id);
                            } else {
                              ids.remove(calendar.id);
                            }
                            final coordinator = ref.read(calendarSyncCoordinatorProvider);
                            final db = ref.read(databaseProvider);
                            await coordinator.googleProvider.setReadOnlyCalendarIds(ids);
                            if (selected != true) {
                              await (db.delete(db.externalCalendarEvents)
                                    ..where((event) => event.provider.equals('google'))
                                    ..where((event) => event.calendarId.equals(calendar.id)))
                                  .go();
                            }
                            if (mounted) setState(() => _readOnlyGoogleCalIds = ids);
                          },
                        ),
                    ],
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
                              _isAppleAuthorized
                                  ? (_appleAccount ?? 'Acesso Autorizado')
                                  : 'Não autorizado',
                              style: TextStyle(
                                fontSize: 13,
                                color: _isAppleAuthorized
                                    ? Colors.green[500]
                                    : Colors.grey,
                                fontWeight: _isAppleAuthorized
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_isAppleAuthorized)
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
                  if (_isAppleAuthorized && _appleCalendars.isNotEmpty) ...[
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
                      key: ValueKey('apple-$_selectedAppleCalId'),
                      initialValue: _selectedAppleCalId,
                      hint: const Text('Selecione um calendário disponível'),
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
