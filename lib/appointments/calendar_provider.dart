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

/// Resolve qual calendrier externe deve ser selecionado a partir do ID salvo.
///
/// - Se [savedId] for 'primary' e [google] for verdadeiro, retorna o ID do
///   calendário primário (isPrimary) da conta Google; se não houver, null.
/// - Se [savedId] existir na lista, retorna ele mesmo.
/// - Caso contrário, retorna null (não seleciona outro calendário por engano).
String? resolveCalendarSelection(
  List<ExternalCalendarItem> calendars,
  String? savedId, {
  bool google = false,
}) {
  if (savedId == null || savedId.trim().isEmpty) return null;
  if (savedId == 'primary') {
    if (!google) return null;
    for (final c in calendars) {
      if (c.isPrimary && c.id.isNotEmpty) return c.id;
    }
    for (final c in calendars) {
      if (c.id == 'primary') return c.id;
    }
    return null;
  }
  for (final c in calendars) {
    if (c.id == savedId) return c.id;
  }
  return null;
}

/// Remove itens com ID vazio e duplicados (mantém a primeira ocorrência),
/// preservando a ordem original — usado para montar o seletor de calendários.
List<ExternalCalendarItem> uniqueCalendarItems(List<ExternalCalendarItem> items) {
  final seen = <String>{};
  final result = <ExternalCalendarItem>[];
  for (final item in items) {
    if (item.id.trim().isEmpty) continue;
    if (seen.add(item.id)) result.add(item);
  }
  return result;
}

class ExternalCalendarItem {
  final String id;
  final String name;
  final String? accountName;
  final bool isReadOnly;
  final bool isPrimary;
  final Color? color;

  ExternalCalendarItem({
    required this.id,
    required this.name,
    this.accountName,
    this.isReadOnly = false,
    this.isPrimary = false,
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

  /// Retorna se o provedor é suportado na plataforma atual de execução.
  bool get isSupportedOnCurrentPlatform => true;

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
  Future<bool> deleteExternalEvent(AppDatabase db, String externalEventId);
}
