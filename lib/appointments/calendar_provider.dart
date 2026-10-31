import 'package:flutter/material.dart';
import '../database/app_database.dart';

enum CalendarProviderType {
  google('google', 'Google Calendar'),
  appleEventKit('apple_eventkit', 'Apple Calendar / Dispositivo');

  final String id;
  final String displayName;
  const CalendarProviderType(this.id, this.displayName);
}

enum SyncDirection {
  bidirectional('Bidirecional (Enviar e Receber)'),
  receiveOnly('Somente Receber Eventos Externos'),
  sendOnly('Somente Enviar do Field Assistant');

  final String label;
  const SyncDirection(this.label);
}

class ExternalCalendarItem {
  final String id;
  final String name;
  final String? accountName;
  final bool isReadOnly;
  final Color? color;

  ExternalCalendarItem({
    required this.id,
    required this.name,
    this.accountName,
    this.isReadOnly = false,
    this.color,
  });
}

class CalendarSyncResult {
  final bool success;
  final int eventsUploaded;
  final int eventsDownloaded;
  final int conflictsFound;
  final String? errorMessage;

  CalendarSyncResult({
    required this.success,
    this.eventsUploaded = 0,
    this.eventsDownloaded = 0,
    this.conflictsFound = 0,
    this.errorMessage,
  });
}

abstract class CalendarProvider {
  CalendarProviderType get providerType;

  /// Retorna se o provedor está atualmente conectado e autorizado
  Future<bool> isAuthorized();

  /// Solicita permissão/autorização ao usuário
  Future<bool> requestAuthorization();

  /// Retorna o nome da conta conectada (ex: email google, icloud)
  Future<String?> getConnectedAccountName();

  /// Lista os calendários disponíveis na conta/dispositivo
  Future<List<ExternalCalendarItem>> getAvailableCalendars();

  /// Obtém o ID do calendário atualmente selecionado para sincronização
  Future<String?> getSelectedCalendarId();

  /// Define o calendário selecionado
  Future<void> setSelectedCalendarId(String calendarId);

  /// Desconecta a conta e limpa credenciais locais sem apagar dados locais
  Future<void> disconnect();

  /// Sincronização incremental ou total
  Future<CalendarSyncResult> syncEvents({
    required AppDatabase db,
    bool fullSync = false,
  });

  /// Envia compromisso do FA para o calendário externo
  Future<String?> pushAppointmentToExternal(
    AppDatabase db,
    AppointmentEntry appointment,
  );

  /// Exclui evento no calendário externo
  Future<bool> deleteExternalEvent(
    AppDatabase db,
    String externalEventId,
  );
}
