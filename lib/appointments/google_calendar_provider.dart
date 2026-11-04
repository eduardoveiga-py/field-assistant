import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:drift/drift.dart' as drift;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import 'calendar_provider.dart';

/// Enumeração de causas específicas de falha de autenticação/autorização com Google Calendar.
enum GoogleAuthFailureReason {
  none,
  userCancelled,
  popupBlocked,
  clientConfigurationError,
  scopeDenied,
  networkError,
  calendarApiDisabled,
  unknown;

  String get userFriendlyMessage {
    switch (this) {
      case GoogleAuthFailureReason.popupBlocked:
        return 'Janela de login bloqueada pelo navegador. Permita pop-ups para este site e tente novamente.';
      case GoogleAuthFailureReason.clientConfigurationError:
        return 'Configuração do Google Cloud inválida: Client ID ausente ou origem Web não autorizada no console do Google Cloud.';
      case GoogleAuthFailureReason.userCancelled:
        return 'Conexão com Google Calendar cancelada pelo usuário.';
      case GoogleAuthFailureReason.scopeDenied:
        return 'Permissão de acesso à agenda negada. Conceda permissão aos eventos para sincronizar.';
      case GoogleAuthFailureReason.networkError:
        return 'Falha de conexão com os servidores do Google. Verifique sua conexão com a internet.';
      case GoogleAuthFailureReason.calendarApiDisabled:
        return 'A Google Calendar API não está habilitada no projeto Google Cloud. Habilite-a no console GCP.';
      case GoogleAuthFailureReason.none:
      case GoogleAuthFailureReason.unknown:
        return 'Não foi possível conectar ao Google Calendar. Verifique a autenticação e tente novamente.';
    }
  }
}

/// Resultado detalhado de solicitação de autenticação/autorização Google.
class GoogleAuthResult {
  final bool success;
  final GoogleAuthFailureReason failureReason;
  final String? errorMessage;

  const GoogleAuthResult({
    required this.success,
    this.failureReason = GoogleAuthFailureReason.none,
    this.errorMessage,
  });

  factory GoogleAuthResult.success() => const GoogleAuthResult(success: true);
  factory GoogleAuthResult.failure(
    GoogleAuthFailureReason reason, [
    String? message,
  ]) =>
      GoogleAuthResult(
        success: false,
        failureReason: reason,
        errorMessage: message,
      );
}

/// Utilitários para conformidade estrita de privacidade e higiene de logs (sem Bearer tokens, senhas ou e-mails completos).
class LoggingHygiene {
  static String maskEmail(String? email) {
    if (email == null || email.trim().isEmpty) return '(sem email)';
    final parts = email.trim().split('@');
    if (parts.length != 2) return '***';
    final user = parts[0];
    final domain = parts[1];
    if (user.length <= 2) {
      return '${user[0]}*@$domain';
    }
    return '${user[0]}***${user[user.length - 1]}@$domain';
  }

  static String sanitizeErrorMessage(Object? error) {
    if (error == null) return '';
    var msg = error.toString();
    // Remove tokens Bearer
    msg = msg.replaceAll(
      RegExp(r'Bearer\s+[A-Za-z0-9\-._~+/]+=*', caseSensitive: false),
      'Bearer [REDACTED]',
    );
    // Mascara emails completos
    msg = msg.replaceAllMapped(
      RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'),
      (match) => maskEmail(match.group(0)),
    );
    // Mascara parâmetros de credenciais sensíveis
    msg = msg.replaceAllMapped(
      RegExp(r'(access_token|key|client_secret)=[^&\s]+'),
      (match) => '${match.group(1)}=[REDACTED]',
    );
    return msg;
  }
}

class _AuthenticatedClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();
  final Duration _timeout = const Duration(seconds: 15);

  _AuthenticatedClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request).timeout(_timeout);
  }

  @override
  void close() {
    _client.close();
    super.close();
  }
}

class GoogleCalendarProvider implements CalendarProvider {
  final GoogleSignIn _googleSignIn;
  final FlutterSecureStorage _secureStorage;
  final Uuid _uuid = const Uuid();
  final String? webClientId;
  final gcal.CalendarApi? calendarApi;
  final String? accountName;

  static const String _calendarScope =
      'https://www.googleapis.com/auth/calendar.events';
  static const String _keySelectedCalendarId = 'google_calendar_selected_id';
  static const String _keySyncTokenPrefix = 'google_calendar_synctoken_';

  GoogleSignInAccount? _currentUser;
  bool _initialized = false;
  Map<String, String>? _webAuthHeaders;

  GoogleAuthFailureReason _lastAuthFailureReason =
      GoogleAuthFailureReason.none;
  String? _lastAuthErrorMessage;

  GoogleAuthFailureReason get lastAuthFailureReason => _lastAuthFailureReason;
  GoogleAuthFailureReason get lastFailureReason => _lastAuthFailureReason;
  String? get lastAuthErrorMessage => _lastAuthErrorMessage;

  GoogleCalendarProvider({
    GoogleSignIn? googleSignIn,
    FlutterSecureStorage? secureStorage,
    this.webClientId,
    this.calendarApi,
    this.accountName,
  }) : _googleSignIn = googleSignIn ?? GoogleSignIn.instance,
       _secureStorage = secureStorage ?? const FlutterSecureStorage();

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    try {
      final effectiveClientId = webClientId?.trim().isNotEmpty == true
          ? webClientId!.trim()
          : const String.fromEnvironment(
              'GOOGLE_WEB_CLIENT_ID',
              defaultValue: '',
            ).trim();

      await _googleSignIn.initialize(
        clientId: kIsWeb && effectiveClientId.isNotEmpty
            ? effectiveClientId
            : null,
      );
      _initialized = true;
    } catch (e) {
      _initialized = false;
      _lastAuthFailureReason = _classifyException(e);
      _lastAuthErrorMessage = LoggingHygiene.sanitizeErrorMessage(e);
      rethrow;
    }
  }

  GoogleAuthFailureReason _classifyException(Object e) {
    final str = e.toString().toLowerCase();
    if (str.contains('canceled') ||
        str.contains('cancelled') ||
        str.contains('popup_closed_by_user')) {
      return GoogleAuthFailureReason.userCancelled;
    }
    if (str.contains('uiunavailable') ||
        str.contains('popup_blocked') ||
        str.contains('popup_failed_to_open') ||
        str.contains('blocked')) {
      return GoogleAuthFailureReason.popupBlocked;
    }
    if (str.contains('clientconfigurationerror') ||
        str.contains('unauthorized_client') ||
        str.contains('idpiframe_initialization_failed') ||
        str.contains('clientid') ||
        str.contains('client_id') ||
        str.contains('origin')) {
      return GoogleAuthFailureReason.clientConfigurationError;
    }
    if (str.contains('access_denied') ||
        str.contains('denied') ||
        str.contains('scope')) {
      return GoogleAuthFailureReason.scopeDenied;
    }
    if (str.contains('accessnotconfigured') ||
        str.contains('api not enabled') ||
        str.contains('not activated')) {
      return GoogleAuthFailureReason.calendarApiDisabled;
    }
    if (str.contains('network') ||
        str.contains('socket') ||
        str.contains('offline') ||
        str.contains('failed to fetch')) {
      return GoogleAuthFailureReason.networkError;
    }
    return GoogleAuthFailureReason.unknown;
  }

  @override
  CalendarProviderType get providerType => CalendarProviderType.google;

  @override
  Future<bool> isAuthorized() async {
    if (calendarApi != null) return true;
    try {
      await _ensureInitialized();
      if (_googleSignIn.supportsAuthenticate()) {
        _currentUser ??= await _googleSignIn.attemptLightweightAuthentication();
        return _currentUser != null;
      } else {
        if (_webAuthHeaders != null) return true;
        final auth = await _googleSignIn.authorizationClient
            .authorizationForScopes([_calendarScope]);
        if (auth != null) {
          _webAuthHeaders = {
            'Authorization': 'Bearer ${auth.accessToken}',
            'X-Goog-AuthUser': '0',
          };
          return true;
        }
        return false;
      }
    } catch (e) {
      _lastAuthFailureReason = _classifyException(e);
      _lastAuthErrorMessage = LoggingHygiene.sanitizeErrorMessage(e);
      return false;
    }
  }

  /// Solicita autorização expondo o resultado detalhado com motivo da falha.
  Future<GoogleAuthResult> requestAuthorizationResult() async {
    _lastAuthFailureReason = GoogleAuthFailureReason.none;
    _lastAuthErrorMessage = null;
    try {
      await _ensureInitialized();
      if (_googleSignIn.supportsAuthenticate()) {
        _currentUser = await _googleSignIn.authenticate(
          scopeHint: [_calendarScope],
        );
        if (_currentUser != null) {
          return GoogleAuthResult.success();
        } else {
          _lastAuthFailureReason = GoogleAuthFailureReason.userCancelled;
          return GoogleAuthResult.failure(
            GoogleAuthFailureReason.userCancelled,
            'Conexão cancelada pelo usuário.',
          );
        }
      } else {
        final clientAuth = await _googleSignIn.authorizationClient
            .authorizeScopes([_calendarScope]);
        _webAuthHeaders = {
          'Authorization': 'Bearer ${clientAuth.accessToken}',
          'X-Goog-AuthUser': '0',
        };
        return GoogleAuthResult.success();
      }
    } catch (e) {
      _lastAuthFailureReason = _classifyException(e);
      final sanitized = LoggingHygiene.sanitizeErrorMessage(e);
      _lastAuthErrorMessage = sanitized;
      return GoogleAuthResult.failure(_lastAuthFailureReason, sanitized);
    }
  }

  @override
  Future<bool> requestAuthorization() async {
    final result = await requestAuthorizationResult();
    return result.success;
  }

  @override
  Future<String?> getConnectedAccountName() async {
    if (accountName != null) return accountName;
    if (_currentUser == null && _webAuthHeaders == null) {
      await isAuthorized();
    }
    return _currentUser?.email ??
        (_webAuthHeaders != null ? 'Conta Google' : null);
  }

  Future<gcal.CalendarApi?> _getCalendarApi() async {
    if (calendarApi != null) return calendarApi;
    final authorized = await isAuthorized();
    if (!authorized) {
      final reqAuth = await requestAuthorization();
      if (!reqAuth) return null;
    }

    try {
      Map<String, String>? headers;
      if (_currentUser != null) {
        headers = await _currentUser!.authorizationClient.authorizationHeaders([
          _calendarScope,
        ], promptIfNecessary: true);
      } else if (_webAuthHeaders != null) {
        headers = _webAuthHeaders;
      } else {
        final clientAuth = await _googleSignIn.authorizationClient
            .authorizeScopes([_calendarScope]);
        headers = {
          'Authorization': 'Bearer ${clientAuth.accessToken}',
          'X-Goog-AuthUser': '0',
        };
        _webAuthHeaders = headers;
      }
      if (headers == null) return null;
      final authClient = _AuthenticatedClient(headers);
      return gcal.CalendarApi(authClient);
    } catch (e) {
      _lastAuthFailureReason = _classifyException(e);
      _lastAuthErrorMessage = LoggingHygiene.sanitizeErrorMessage(e);
      return null;
    }
  }

  @override
  Future<List<ExternalCalendarItem>> getAvailableCalendars() async {
    final api = await _getCalendarApi();
    if (api == null) return [];

    try {
      final list = await api.calendarList.list();
      final items = list.items ?? [];
      return items.map((c) {
        final isReadOnly =
            c.accessRole == 'reader' || c.accessRole == 'freeBusyReader';
        return ExternalCalendarItem(
          id: c.id ?? 'primary',
          name: c.summary ?? 'Google Agenda',
          accountName: _currentUser?.email,
          isReadOnly: isReadOnly,
        );
      }).toList();
    } catch (e) {
      _lastAuthErrorMessage =
          'Erro ao listar calendários disponíveis: ${LoggingHygiene.sanitizeErrorMessage(e)}';
      return []; // NUNCA retorna calendário artificial "primary" quando a API falhar
    }
  }

  String _selectedCalendarKey(String accountKey) =>
      'google_calendar_${accountKey}_selected_id';

  String _syncTokenKey(String accountKey, String calendarId) =>
      'google_calendar_${accountKey}_synctoken_$calendarId';

  Future<String> _getAccountStorageKey() async {
    if (_currentUser != null) {
      if (_currentUser!.id.isNotEmpty) return _currentUser!.id;
      if (_currentUser!.email.isNotEmpty) {
        return _hashAccount(_currentUser!.email);
      }
    }
    final name = await getConnectedAccountName();
    if (name != null && name != 'Conta Google' && name.isNotEmpty) {
      return _hashAccount(name);
    }
    return 'default';
  }

  String _hashAccount(String raw) {
    final sanitized =
        raw.trim().toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    return sanitized.length > 32 ? sanitized.substring(0, 32) : sanitized;
  }

  Future<String?> _getSyncToken(String accountKey, String calendarId) async {
    final scoped = await _secureStorage.read(
      key: _syncTokenKey(accountKey, calendarId),
    );
    if (scoped != null && scoped.isNotEmpty) return scoped;
    return await _secureStorage.read(
      key: '$_keySyncTokenPrefix$calendarId',
    );
  }

  Future<void> _setSyncToken(
    String accountKey,
    String calendarId,
    String token,
  ) async {
    await _secureStorage.write(
      key: _syncTokenKey(accountKey, calendarId),
      value: token,
    );
  }

  Future<void> _deleteSyncToken(String accountKey, String calendarId) async {
    await _secureStorage.delete(key: _syncTokenKey(accountKey, calendarId));
    await _secureStorage.delete(key: '$_keySyncTokenPrefix$calendarId');
  }

  @override
  Future<String?> getSelectedCalendarId() async {
    final accountKey = await _getAccountStorageKey();
    final scoped =
        await _secureStorage.read(key: _selectedCalendarKey(accountKey));
    if (scoped != null && scoped.isNotEmpty) return scoped;
    return await _secureStorage.read(key: _keySelectedCalendarId) ?? 'primary';
  }

  @override
  Future<void> setSelectedCalendarId(String calendarId) async {
    final accountKey = await _getAccountStorageKey();
    await _secureStorage.write(
      key: _selectedCalendarKey(accountKey),
      value: calendarId,
    );
    await _secureStorage.write(
      key: _keySelectedCalendarId,
      value: calendarId,
    );
  }

  @override
  Future<void> disconnect() async {
    final accountKey = await _getAccountStorageKey();
    final calendarId = await getSelectedCalendarId() ?? 'primary';
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    _currentUser = null;
    _webAuthHeaders = null;
    _initialized = false;
    _lastAuthFailureReason = GoogleAuthFailureReason.none;
    _lastAuthErrorMessage = null;

    // Limpa chaves isoladas da conta
    await _secureStorage.delete(key: _selectedCalendarKey(accountKey));
    await _secureStorage.delete(key: _syncTokenKey(accountKey, calendarId));
    // Limpa chaves globais legadas
    await _secureStorage.delete(key: _keySelectedCalendarId);
    await _secureStorage.delete(key: '$_keySyncTokenPrefix$calendarId');
  }

  @override
  Future<CalendarSyncResult> syncEvents({
    required AppDatabase db,
    bool fullSync = false,
  }) async {
    final api = await _getCalendarApi();
    if (api == null) {
      return CalendarSyncResult(
        success: false,
        errorMessage: _lastAuthErrorMessage ??
            'Não foi possível autenticar com a Google Calendar API.',
      );
    }

    final accountKey = await _getAccountStorageKey();
    final calendarId = await getSelectedCalendarId() ?? 'primary';

    if (fullSync) {
      await _deleteSyncToken(accountKey, calendarId);
      try {
        return await _runSyncLoop(
          api: api,
          db: db,
          calendarId: calendarId,
          accountKey: accountKey,
          isFullSync: true,
        );
      } catch (e) {
        return CalendarSyncResult(
          success: false,
          errorMessage:
              'Falha durante sincronização: ${LoggingHygiene.sanitizeErrorMessage(e)}',
        );
      }
    }

    final syncToken = await _getSyncToken(accountKey, calendarId);
    if (syncToken == null || syncToken.isEmpty) {
      try {
        return await _runSyncLoop(
          api: api,
          db: db,
          calendarId: calendarId,
          accountKey: accountKey,
          isFullSync: true,
        );
      } catch (e) {
        return CalendarSyncResult(
          success: false,
          errorMessage:
              'Falha durante sincronização: ${LoggingHygiene.sanitizeErrorMessage(e)}',
        );
      }
    }

    try {
      return await _runSyncLoop(
        api: api,
        db: db,
        calendarId: calendarId,
        accountKey: accountKey,
        isFullSync: false,
        syncToken: syncToken,
      );
    } on gcal.DetailedApiRequestError catch (e) {
      if (e.status == 410) {
        // Sync token expirado (HTTP 410 Gone) -> 
        // 1. Apaga token expirado do secure storage imediatamente
        await _deleteSyncToken(accountKey, calendarId);
        // 2. Executa e conclui sincronização completa real em todas as páginas
        try {
          return await _runSyncLoop(
            api: api,
            db: db,
            calendarId: calendarId,
            accountKey: accountKey,
            isFullSync: true,
          );
        } catch (fullSyncError) {
          return CalendarSyncResult(
            success: false,
            errorMessage:
                'Falha durante full sync pós-410: ${LoggingHygiene.sanitizeErrorMessage(fullSyncError)}',
          );
        }
      }
      return CalendarSyncResult(
        success: false,
        errorMessage: 'Erro da API Google: ${e.message}',
      );
    } catch (e) {
      return CalendarSyncResult(
        success: false,
        errorMessage:
            'Falha durante sincronização: ${LoggingHygiene.sanitizeErrorMessage(e)}',
      );
    }
  }

  Future<CalendarSyncResult> _runSyncLoop({
    required gcal.CalendarApi api,
    required AppDatabase db,
    required String calendarId,
    required String accountKey,
    required bool isFullSync,
    String? syncToken,
  }) async {
    int downloaded = 0;
    String? pageToken;
    String? nextSyncToken;

    do {
      gcal.Events events;
      if (!isFullSync && syncToken != null && syncToken.isNotEmpty) {
        events = await api.events.list(
          calendarId,
          syncToken: syncToken,
          pageToken: pageToken,
          maxResults: 250,
        );
      } else {
        final timeMin =
            DateTime.now().subtract(const Duration(days: 90)).toUtc();
        final timeMax = DateTime.now().add(const Duration(days: 180)).toUtc();
        events = await api.events.list(
          calendarId,
          pageToken: pageToken,
          timeMin: timeMin,
          timeMax: timeMax,
          singleEvents: true,
          maxResults: 250,
        );
      }

      pageToken = events.nextPageToken;
      if (events.nextSyncToken != null) {
        nextSyncToken = events.nextSyncToken;
      }

      final items = events.items ?? [];
      for (final item in items) {
        final eventId = item.id;
        if (eventId == null) continue;

        final isCancelled = item.status == 'cancelled';
        final startDt =
            item.start?.dateTime ?? item.start?.date ?? DateTime.now();
        final endDt = item.end?.dateTime ??
            item.end?.date ??
            startDt.add(const Duration(minutes: 30));

        // Consulta tipada com escopo de chave composta: provider, calendarId, externalEventId e externalAccount
        final existing = await (db.select(db.externalCalendarEvents)..where(
              (t) =>
                  t.provider.equals('google') &
                  t.calendarId.equals(calendarId) &
                  t.externalEventId.equals(eventId) &
                  (accountKey.isNotEmpty && accountKey != 'default'
                      ? (t.externalAccount.equals(accountKey) |
                          t.externalAccount.isNull())
                      : const drift.Constant(true)),
            )).getSingleOrNull();

        final now = DateTime.now();
        if (existing == null) {
          if (!isCancelled) {
            await db.into(db.externalCalendarEvents).insert(
                  ExternalCalendarEventsCompanion.insert(
                    id: _uuid.v4(),
                    provider: 'google',
                    externalAccount: drift.Value(
                      accountKey.isNotEmpty && accountKey != 'default'
                          ? accountKey
                          : null,
                    ),
                    calendarId: calendarId,
                    externalEventId: eventId,
                    iCalUid: drift.Value(item.iCalUID),
                    title: item.summary ?? 'Evento Google',
                    location: drift.Value(item.location),
                    description: drift.Value(item.description),
                    startTime: startDt,
                    endTime: endDt,
                    timeZone: drift.Value(item.start?.timeZone),
                    isAllDay: drift.Value(item.start?.date != null),
                    externalStatus: drift.Value(item.status),
                    lastModifiedExternal: drift.Value(item.updated),
                    lastSyncedAt: drift.Value(now),
                    isDeletedExternal: const drift.Value(false),
                    etag: drift.Value(item.etag),
                    createdAt: now,
                    updatedAt: now,
                  ),
                );
            downloaded++;
          }
        } else {
          await (db.update(db.externalCalendarEvents)
                ..where((t) => t.id.equals(existing.id)))
              .write(
            ExternalCalendarEventsCompanion(
              externalAccount: drift.Value(
                accountKey.isNotEmpty && accountKey != 'default'
                    ? accountKey
                    : existing.externalAccount,
              ),
              title: drift.Value(item.summary ?? existing.title),
              location: drift.Value(item.location),
              description: drift.Value(item.description),
              startTime: drift.Value(startDt),
              endTime: drift.Value(endDt),
              externalStatus: drift.Value(item.status),
              lastModifiedExternal: drift.Value(item.updated),
              lastSyncedAt: drift.Value(now),
              isDeletedExternal: drift.Value(isCancelled),
              etag: drift.Value(item.etag),
              updatedAt: drift.Value(now),
            ),
          );
          downloaded++;
        }
      }
    } while (pageToken != null);

    if (nextSyncToken != null) {
      await _setSyncToken(accountKey, calendarId, nextSyncToken);
    }

    return CalendarSyncResult(
      success: true,
      eventsDownloaded: downloaded,
      eventsUploaded: 0,
      conflictsFound: 0,
    );
  }

  @override
  Future<String?> pushAppointmentToExternal(
    AppDatabase db,
    AppointmentEntry appointment,
  ) async {
    final api = await _getCalendarApi();
    if (api == null) return null;

    final calendarId = await getSelectedCalendarId() ?? 'primary';

    // Verifica se já existe vínculo
    final link =
        await (db.select(db.calendarEventLinks)..where(
              (t) =>
                  t.appointmentId.equals(appointment.id) &
                  t.provider.equals('google') &
                  t.deletedAt.isNull(),
            ))
            .getSingleOrNull();

    final gEvent = gcal.Event(
      summary: appointment.title,
      description: 'Sincronizado via Field Assistant Ministerial',
      location: appointment.locationNotes,
      start: gcal.EventDateTime(dateTime: appointment.startTime.toUtc()),
      end: gcal.EventDateTime(dateTime: appointment.endTime.toUtc()),
    );

    try {
      if (link != null && link.externalEventId.isNotEmpty) {
        final updated = await api.events.patch(
          gEvent,
          calendarId,
          link.externalEventId,
        );
        final now = DateTime.now();
        await (db.update(
          db.calendarEventLinks,
        )..where((t) => t.id.equals(link.id))).write(
          CalendarEventLinksCompanion(
            externalETagAtSync: drift.Value(updated.etag),
            localRevisionAtSync: drift.Value(appointment.revision),
            syncStatus: const drift.Value('synced'),
            updatedAt: drift.Value(now),
          ),
        );
        return updated.id;
      } else {
        final created = await api.events.insert(gEvent, calendarId);
        final now = DateTime.now();
        if (link != null) {
          await (db.update(
            db.calendarEventLinks,
          )..where((t) => t.id.equals(link.id))).write(
            CalendarEventLinksCompanion(
              externalEventId: drift.Value(created.id ?? _uuid.v4()),
              externalETagAtSync: drift.Value(created.etag),
              localRevisionAtSync: drift.Value(appointment.revision),
              syncStatus: const drift.Value('synced'),
              updatedAt: drift.Value(now),
            ),
          );
        } else {
          final linkId = _uuid.v4();
          await db
              .into(db.calendarEventLinks)
              .insert(
                CalendarEventLinksCompanion.insert(
                  id: linkId,
                  appointmentId: appointment.id,
                  externalEventId: created.id ?? _uuid.v4(),
                  provider: 'google',
                  syncStatus: const drift.Value('synced'),
                  localRevisionAtSync: drift.Value(appointment.revision),
                  externalETagAtSync: drift.Value(created.etag),
                  createdAt: now,
                  updatedAt: now,
                ),
              );
        }
        return created.id;
      }
    } catch (e) {
      _lastAuthErrorMessage = LoggingHygiene.sanitizeErrorMessage(e);
      return null;
    }
  }

  @override
  Future<bool> deleteExternalEvent(
    AppDatabase db,
    String externalEventId,
  ) async {
    final api = await _getCalendarApi();
    if (api == null) return false;

    final calendarId = await getSelectedCalendarId() ?? 'primary';
    try {
      await api.events.delete(calendarId, externalEventId);
      final now = DateTime.now();
      await (db.update(db.calendarEventLinks)..where(
            (t) =>
                t.externalEventId.equals(externalEventId) &
                t.provider.equals('google'),
          ))
          .write(
            CalendarEventLinksCompanion(
              deletedAt: drift.Value(now),
              syncStatus: const drift.Value('synced'),
              updatedAt: drift.Value(now),
            ),
          );
      return true;
    } on gcal.DetailedApiRequestError catch (e) {
      if (e.status == 404 || e.status == 410) {
        // Evento já foi removido no Google Calendar remotamente (idempotência)
        final now = DateTime.now();
        await (db.update(db.calendarEventLinks)..where(
              (t) =>
                  t.externalEventId.equals(externalEventId) &
                  t.provider.equals('google'),
            ))
            .write(
              CalendarEventLinksCompanion(
                deletedAt: drift.Value(now),
                syncStatus: const drift.Value('synced'),
                updatedAt: drift.Value(now),
              ),
            );
        return true;
      }
      _lastAuthErrorMessage = LoggingHygiene.sanitizeErrorMessage(e);
      return false;
    } catch (e) {
      _lastAuthErrorMessage = LoggingHygiene.sanitizeErrorMessage(e);
      return false;
    }
  }
}
