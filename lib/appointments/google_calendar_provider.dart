import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../core/app_logger.dart';
import '../database/app_database.dart';
import '../inbox/oauth_token_store.dart';
import 'calendar_provider.dart';

class _AuthenticatedClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  _AuthenticatedClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
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
  final OAuthTokenStore _tokenStore;
  final Uuid _uuid = const Uuid();
  static const String defaultWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '',
  );
  static const String defaultIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue: '',
  );
  static const String _calendarScope =
      'https://www.googleapis.com/auth/calendar.events';
  static const String _calendarReadonlyScope =
      'https://www.googleapis.com/auth/calendar.readonly';
  static const String _emailScope =
      'https://www.googleapis.com/auth/userinfo.email';
  static const String _keySelectedCalendarId = 'google_calendar_selected_id';
  static const String _keyConnectedEmail = 'google_calendar_connected_email';
  static const String _keyAccountEmail = 'google_calendar_account_email';
  static const String _keyCalendarOAuthTokens = 'google_calendar_oauth_tokens';
  static const String _keyUserExplicitlyConnected =
      'google_calendar_explicitly_connected';
  static const String _keySyncTokenPrefix = 'google_calendar_synctoken_';
  static const String _keyReadOnlyCalendarIds = 'google_readonly_calendar_ids';

  /// IDs de calendários marcados como somente leitura (ex.: feriados públicos).
  Future<Set<String>> getReadOnlyCalendarIds() async {
    try {
      final raw = await _secureStorage.read(key: _keyReadOnlyCalendarIds);
      if (raw == null || raw.trim().isEmpty) return {};
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<String>().toSet();
      }
      return {};
    } catch (e, st) {
      AppLogger.warning(
        'Falha ao ler IDs de calendários somente leitura',
        e,
        st,
      );
      return {};
    }
  }

  Future<void> setReadOnlyCalendarIds(Set<String> ids) async {
    final previous = await getReadOnlyCalendarIds();
    await _secureStorage.write(
      key: _keyReadOnlyCalendarIds,
      value: jsonEncode(ids.toList()),
    );
    for (final id in previous.difference(ids)) {
      await _secureStorage.delete(key: '$_keySyncTokenPrefix$id');
    }
  }

  GoogleSignInAccount? _currentUser;
  Map<String, String>? _webAuthHeaders;
  String? _webUserEmail;
  String? lastError;
  bool _initialized = false;

  GoogleCalendarProvider({
    GoogleSignIn? googleSignIn,
    FlutterSecureStorage? secureStorage,
    OAuthTokenStore? tokenStore,
  }) : _googleSignIn = googleSignIn ?? GoogleSignIn.instance,
       _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _tokenStore =
           tokenStore ??
           OAuthTokenStore(
             secureStorage: secureStorage ?? const FlutterSecureStorage(),
           );

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    try {
      if (kIsWeb) {
        if (defaultWebClientId.trim().isEmpty) {
          lastError = 'Google Calendar na Web requer GOOGLE_WEB_CLIENT_ID configurado via --dart-define.';
          _initialized = true;
          return;
        }
        await _googleSignIn.initialize(clientId: defaultWebClientId);
        _webUserEmail ??= await _secureStorage.read(key: _keyConnectedEmail);
      } else {
        final isIos = defaultTargetPlatform == TargetPlatform.iOS;
        final iosClientId = defaultIosClientId.trim();
        await _googleSignIn.initialize(
          clientId: isIos && iosClientId.isNotEmpty ? iosClientId : null,
        );
      }
    } catch (e) {
      lastError = e.toString();
    }
    _initialized = true;
  }

  Future<void> _saveConnectedEmail(String email) async {
    _webUserEmail = email;
    await _secureStorage.write(key: _keyConnectedEmail, value: email);
    await _secureStorage.write(key: _keyAccountEmail, value: email);
  }

  String? _extractBearerToken(Map<String, String>? headers) {
    if (headers == null) return null;
    final raw = headers['Authorization'] ?? headers['authorization'];
    if (raw != null && raw.toLowerCase().startsWith('bearer ')) {
      return raw.substring(7).trim();
    }
    return null;
  }

  Future<void> _fetchAndSaveWebUserEmail(Map<String, String> headers) async {
    try {
      final resp = await http.get(
        Uri.parse('https://www.googleapis.com/oauth2/v2/userinfo'),
        headers: headers,
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final email = data['email'] as String?;
        if (email != null && email.isNotEmpty) {
          await _saveConnectedEmail(email);
        }
      }
    } catch (e, st) {
      AppLogger.warning('Falha ao consultar userinfo Google Web', e, st);
    }
  }

  @override
  CalendarProviderType get providerType => CalendarProviderType.google;

  @override
  bool get isSupportedOnCurrentPlatform => true;

  /// Retorna um access token válido para o Google Calendar.
  /// Se o token salvo em [OAuthTokenStore] for válido, reutiliza imediatamente sem seletores.
  /// Se expirado, tenta renovação silenciosa.
  /// Se a renovação silenciosa falhar e [interactive] for true, dispara autenticação interativa.
  /// Se [interactive] for false, retorna null (sem popups em background).
  Future<String?> getValidAccessToken({bool interactive = false}) async {
    await _ensureInitialized();

    // 1. Reutilização do token em cache se não expirado
    final cached = await _tokenStore.readNamedTokenBundle(
      _keyCalendarOAuthTokens,
    );
    if (cached != null &&
        !cached.isExpiredOrExpiringSoon &&
        cached.accessToken.isNotEmpty) {
      _webAuthHeaders = {'Authorization': 'Bearer ${cached.accessToken}'};
      _webUserEmail ??= await _secureStorage.read(key: _keyConnectedEmail);
      _webUserEmail ??= await _secureStorage.read(key: _keyAccountEmail);
      return cached.accessToken;
    }

    // 2. Tentativa de renovação silenciosa
    if (kIsWeb) {
      try {
        final silentHeaders = await _googleSignIn.authorizationClient
            .authorizationHeaders(const [
              _calendarScope,
              _calendarReadonlyScope,
              _emailScope,
            ], promptIfNecessary: false);
        final token = _extractBearerToken(silentHeaders);
        if (token != null && token.isNotEmpty) {
          final bundle = OAuthTokenBundle(
            accessToken: token,
            expiresAt: DateTime.now().add(const Duration(minutes: 55)),
            scopes: const [_calendarScope, _calendarReadonlyScope, _emailScope],
          );
          await _tokenStore.saveNamedTokenBundle(
            _keyCalendarOAuthTokens,
            bundle,
          );
          _webAuthHeaders = silentHeaders;
          if (_webUserEmail == null) {
            await _fetchAndSaveWebUserEmail(silentHeaders!);
          }
          return token;
        }
      } catch (e, st) {
        AppLogger.warning(
          'Falha na renovação silenciosa do Google Calendar (Web)',
          e,
          st,
        );
      }
    } else {
      try {
        _currentUser ??= await _googleSignIn.attemptLightweightAuthentication();
        if (_currentUser != null) {
          final silentHeaders = await _currentUser!.authorizationClient
              .authorizationHeaders(const [
                _calendarScope,
                _calendarReadonlyScope,
                _emailScope,
              ], promptIfNecessary: false);
          final token = _extractBearerToken(silentHeaders);
          if (token != null && token.isNotEmpty) {
            final bundle = OAuthTokenBundle(
              accessToken: token,
              expiresAt: DateTime.now().add(const Duration(minutes: 55)),
              scopes: const [
                _calendarScope,
                _calendarReadonlyScope,
                _emailScope,
              ],
            );
            await _tokenStore.saveNamedTokenBundle(
              _keyCalendarOAuthTokens,
              bundle,
            );
            if (_currentUser!.email.isNotEmpty) {
              await _saveConnectedEmail(_currentUser!.email);
            }
            return token;
          }
        }
      } catch (e, st) {
        AppLogger.warning(
          'Falha na renovação silenciosa do Google Calendar',
          e,
          st,
        );
      }
    }

    // Se silencioso falhou e não é interativo, encerra sem popup
    if (!interactive) {
      return null;
    }

    // 3. Autenticação interativa (apenas quando interactive == true)
    if (kIsWeb) {
      try {
        final headers = await _googleSignIn.authorizationClient
            .authorizationHeaders(const [
              _calendarScope,
              _calendarReadonlyScope,
              _emailScope,
            ], promptIfNecessary: true);
        final token = _extractBearerToken(headers);
        if (token != null && token.isNotEmpty) {
          final bundle = OAuthTokenBundle(
            accessToken: token,
            expiresAt: DateTime.now().add(const Duration(minutes: 55)),
            scopes: const [_calendarScope, _calendarReadonlyScope, _emailScope],
          );
          await _tokenStore.saveNamedTokenBundle(
            _keyCalendarOAuthTokens,
            bundle,
          );
          _webAuthHeaders = headers;
          await _fetchAndSaveWebUserEmail(headers!);
          await _secureStorage.write(
            key: _keyUserExplicitlyConnected,
            value: 'true',
          );
          return token;
        }

        if (_googleSignIn.supportsAuthenticate()) {
          _currentUser = await _googleSignIn.authenticate(
            scopeHint: [_calendarScope, _calendarReadonlyScope, _emailScope],
          );
          if (_currentUser != null) {
            final h = await _currentUser!.authorizationClient
                .authorizationHeaders([
                  _calendarScope,
                  _calendarReadonlyScope,
                  _emailScope,
                ], promptIfNecessary: true);
            final t = _extractBearerToken(h);
            if (t != null && t.isNotEmpty) {
              final bundle = OAuthTokenBundle(
                accessToken: t,
                expiresAt: DateTime.now().add(const Duration(minutes: 55)),
                scopes: const [
                  _calendarScope,
                  _calendarReadonlyScope,
                  _emailScope,
                ],
              );
              await _tokenStore.saveNamedTokenBundle(
                _keyCalendarOAuthTokens,
                bundle,
              );
              _webAuthHeaders = h;
              if (_currentUser!.email.isNotEmpty) {
                await _saveConnectedEmail(_currentUser!.email);
              }
              await _secureStorage.write(
                key: _keyUserExplicitlyConnected,
                value: 'true',
              );
              return t;
            }
          }
        }
      } catch (e) {
        lastError = e.toString();
      }
      return null;
    }

    try {
      _currentUser = await _googleSignIn.authenticate(
        scopeHint: [_calendarScope, _calendarReadonlyScope, _emailScope],
      );
      if (_currentUser != null) {
        final h = await _currentUser!.authorizationClient.authorizationHeaders([
          _calendarScope,
          _calendarReadonlyScope,
          _emailScope,
        ], promptIfNecessary: true);
        final t = _extractBearerToken(h);
        if (t != null && t.isNotEmpty) {
          final bundle = OAuthTokenBundle(
            accessToken: t,
            expiresAt: DateTime.now().add(const Duration(minutes: 55)),
            scopes: const [_calendarScope, _calendarReadonlyScope, _emailScope],
          );
          await _tokenStore.saveNamedTokenBundle(
            _keyCalendarOAuthTokens,
            bundle,
          );
          if (_currentUser!.email.isNotEmpty) {
            await _saveConnectedEmail(_currentUser!.email);
          }
          await _secureStorage.write(
            key: _keyUserExplicitlyConnected,
            value: 'true',
          );
          return t;
        }
      }
    } catch (e) {
      lastError = e.toString();
    }
    return null;
  }

  @override
  Future<bool> isAuthorized() async {
    try {
      final explicitlyConnected = await _secureStorage.read(
        key: _keyUserExplicitlyConnected,
      );
      if (explicitlyConnected != 'true') {
        return false;
      }

      await _ensureInitialized();
      final token = await getValidAccessToken(interactive: false);
      if (token != null && token.isNotEmpty) {
        return true;
      }
      final savedEmail = await _secureStorage.read(key: _keyConnectedEmail);
      return savedEmail != null && savedEmail.isNotEmpty;
    } catch (e, st) {
      AppLogger.warning(
        'Falha ao verificar autorização do Google Calendar',
        e,
        st,
      );
      return false;
    }
  }

  @override
  Future<bool> requestAuthorization() async {
    lastError = null;
    final token = await getValidAccessToken(interactive: true);
    if (token != null && token.isNotEmpty) {
      return true;
    }
    lastError ??=
        'Não foi possível obter o token de acesso do Google Calendar.';
    return false;
  }

  @override
  Future<String?> getConnectedAccountName() async {
    if (kIsWeb && _webUserEmail != null && _webUserEmail!.isNotEmpty) {
      return _webUserEmail;
    }
    _webUserEmail ??= await _secureStorage.read(key: _keyConnectedEmail);
    _webUserEmail ??= await _secureStorage.read(key: _keyAccountEmail);
    if (_webUserEmail != null && _webUserEmail!.isNotEmpty) {
      return _webUserEmail;
    }
    if (_currentUser == null) {
      await isAuthorized();
    }
    return _currentUser?.email ??
        _webUserEmail ??
        (kIsWeb && _webAuthHeaders != null ? 'Conta Google Conectada' : null);
  }

  Future<gcal.CalendarApi?> _getCalendarApi() async {
    final token = await getValidAccessToken(interactive: false);
    if (token == null || token.isEmpty) {
      return null;
    }
    final headers = {'Authorization': 'Bearer $token'};
    final authClient = _AuthenticatedClient(headers);
    return gcal.CalendarApi(authClient);
  }

  @override
  Future<List<ExternalCalendarItem>> getAvailableCalendars() async {
    final api = await _getCalendarApi();
    if (api == null) return [];

    final accountLabel = _currentUser?.email ?? _webUserEmail ?? 'Google';
    try {
      final list = await api.calendarList.list();
      final items = list.items ?? [];
      if (items.isEmpty) {
        return [
          ExternalCalendarItem(
            id: 'primary',
            isPrimary: true,
            name: 'Agenda Principal ($accountLabel)',
            accountName: accountLabel,
            isReadOnly: false,
          ),
        ];
      }
      return items.map((c) {
        final isReadOnly =
            c.accessRole == 'reader' || c.accessRole == 'freeBusyReader';
        return ExternalCalendarItem(
          id: c.id ?? '',
          isPrimary: c.primary == true,
          name: c.summary ?? 'Google Agenda',
          accountName: accountLabel,
          isReadOnly: isReadOnly,
        );
      }).toList();
    } catch (e, st) {
      AppLogger.warning(
        'Falha ao listar agendas do Google Calendar; usando primária',
        e,
        st,
      );
      return [
        ExternalCalendarItem(
          id: 'primary',
          isPrimary: true,
          name: 'Principal ($accountLabel)',
          accountName: accountLabel,
          isReadOnly: false,
        ),
      ];
    }
  }

  @override
  Future<String?> getSelectedCalendarId() async {
    return await _secureStorage.read(key: _keySelectedCalendarId) ?? 'primary';
  }

  @override
  Future<void> setSelectedCalendarId(String calendarId) async {
    await _secureStorage.write(key: _keySelectedCalendarId, value: calendarId);
  }

  Future<String> _getEffectiveCalendarId() async {
    final selected = await getSelectedCalendarId() ?? 'primary';
    if (selected != 'primary' && selected.trim().isNotEmpty) {
      return selected;
    }
    final calendars = await getAvailableCalendars();
    final primary = calendars
        .where((c) => c.isPrimary && c.id.isNotEmpty)
        .toList();
    if (primary.isNotEmpty) {
      final canonicalId = primary.first.id;
      await setSelectedCalendarId(canonicalId);
      return canonicalId;
    }
    return selected;
  }

  @override
  Future<void> disconnect() async {
    try {
      await _googleSignIn.signOut();
    } catch (e, st) {
      AppLogger.warning('Falha ao encerrar sessão Google Sign-In', e, st);
    }
    _currentUser = null;
    _webAuthHeaders = null;
    _webUserEmail = null;
    await _tokenStore.deleteNamedTokenBundle(_keyCalendarOAuthTokens);
    await _secureStorage.delete(key: _keySelectedCalendarId);
    await setReadOnlyCalendarIds({});
    await _secureStorage.delete(key: _keyReadOnlyCalendarIds);
    await _secureStorage.delete(key: _keyConnectedEmail);
    await _secureStorage.delete(key: _keyAccountEmail);
    await _secureStorage.delete(key: _keyUserExplicitlyConnected);
  }

  @override
  Future<CalendarSyncResult> syncEvents({
    required AppDatabase db,
    bool fullSync = false,
  }) async {
    lastError = null;
    final api = await _getCalendarApi();
    if (api == null) {
      return CalendarSyncResult(
        success: false,
        errorMessage:
            lastError ??
            'Não foi possível autenticar com a Google Calendar API.',
      );
    }

    final primaryId = await _getEffectiveCalendarId();
    final calendars = await getAvailableCalendars();
    final matches = calendars
        .where(
          (calendar) =>
              calendar.id == primaryId ||
              (primaryId == 'primary' && calendar.isPrimary),
        )
        .toList();
    if (matches.isNotEmpty && matches.first.isReadOnly) {
      return CalendarSyncResult(
        success: false,
        errorMessage: 'Selecione um calendário Google com permissão de edição nas configurações.',
      );
    }

    final ids = <String>{primaryId, ...await getReadOnlyCalendarIds()};
    var downloaded = 0;
    final errors = <String>[];
    for (final id in ids) {
      final result = await _syncCalendar(db, api, id, fullSync: fullSync);
      downloaded += result.eventsDownloaded;
      if (!result.success && result.errorMessage != null) {
        errors.add(result.errorMessage!);
      }
    }
    return CalendarSyncResult(
      success: errors.isEmpty,
      eventsDownloaded: downloaded,
      errorMessage: errors.isEmpty ? null : errors.join('; '),
    );
  }

  Future<CalendarSyncResult> _syncCalendar(
    AppDatabase db,
    gcal.CalendarApi api,
    String calendarId, {
    required bool fullSync,
  }) async {
    String? syncToken;
    if (!fullSync) {
      syncToken = await _secureStorage.read(
        key: '$_keySyncTokenPrefix$calendarId',
      );
    }

    int downloaded = 0;
    String? pageToken;
    String? nextSyncToken;
    bool needsFullSync = false;

    do {
      try {
        gcal.Events events;
        if (syncToken != null && syncToken.isNotEmpty && !needsFullSync) {
          events = await api.events.list(
            calendarId,
            syncToken: syncToken,
            pageToken: pageToken,
            singleEvents: true,
            showDeleted: true,
            maxResults: 250,
          );
        } else {
          final timeMin = DateTime.now()
              .subtract(const Duration(days: 90))
              .toUtc();
          final timeMax = DateTime.now().add(const Duration(days: 180)).toUtc();
          events = await api.events.list(
            calendarId,
            pageToken: pageToken,
            timeMin: timeMin,
            timeMax: timeMax,
            singleEvents: true,
            showDeleted: true,
            maxResults: 250,
          );
        }

        needsFullSync = false;
        pageToken = events.nextPageToken;
        nextSyncToken = events.nextSyncToken;

        final items = events.items ?? [];
        for (final item in items) {
          final eventId = item.id;
          if (eventId == null) continue;

          final isCancelled = item.status == 'cancelled';
          final startDt =
              item.start?.dateTime ?? item.start?.date ?? DateTime.now();
          final endDt =
              item.end?.dateTime ??
              item.end?.date ??
              startDt.add(const Duration(minutes: 30));

          final existing =
              await (db.select(db.externalCalendarEvents)..where(
                    (t) =>
                        t.provider.equals('google') &
                        t.externalEventId.equals(eventId),
                  ))
                  .getSingleOrNull();

          final now = DateTime.now();
          if (existing == null) {
            if (!isCancelled) {
              await db
                  .into(db.externalCalendarEvents)
                  .insert(
                    ExternalCalendarEventsCompanion.insert(
                      id: _uuid.v4(),
                      provider: 'google',
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
            await (db.update(
              db.externalCalendarEvents,
            )..where((t) => t.id.equals(existing.id))).write(
              ExternalCalendarEventsCompanion(
                title: drift.Value(item.summary ?? existing.title),
                location: drift.Value(item.location),
                description: drift.Value(item.description),
                startTime: drift.Value(startDt),
                endTime: drift.Value(endDt),
                timeZone: drift.Value(item.start?.timeZone),
                isAllDay: drift.Value(item.start?.date != null),
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
      } on gcal.DetailedApiRequestError catch (e) {
        if (e.status == 410) {
          syncToken = null;
          pageToken = null;
          needsFullSync = true;
          continue;
        } else {
          if (e.status == 401) {
            _webAuthHeaders = null;
            lastError = 'A autorização do Google expirou. Reconecte a conta em Calendários Conectados.';
          }
          return CalendarSyncResult(
            success: false,
            errorMessage:
                lastError ?? 'Erro da API Google (${e.status}): ${e.message}',
            eventsDownloaded: downloaded,
          );
        }
      } catch (e) {
        return CalendarSyncResult(
          success: false,
          errorMessage: 'Falha durante sincronização: $e',
          eventsDownloaded: downloaded,
        );
      }
    } while (pageToken != null || needsFullSync);

    if (nextSyncToken != null) {
      await _secureStorage.write(
        key: '$_keySyncTokenPrefix$calendarId',
        value: nextSyncToken,
      );
    }

    return CalendarSyncResult(success: true, eventsDownloaded: downloaded);
  }

  @override
  Future<String?> pushAppointmentToExternal(
    AppDatabase db,
    AppointmentEntry appointment,
  ) async {
    final api = await _getCalendarApi();
    if (api == null) return null;

    final calendarId = await _getEffectiveCalendarId();

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
    } catch (e, st) {
      AppLogger.warning(
        'Falha ao criar/atualizar evento no Google Calendar',
        e,
        st,
      );
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

    final calendarId = await _getEffectiveCalendarId();
    final readOnlyIds = await getReadOnlyCalendarIds();
    if (readOnlyIds.contains(calendarId)) {
      AppLogger.warning(
        'Tentativa de exclusão em calendário Google marcado como somente leitura ($calendarId)',
      );
      return false;
    }
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
      return false;
    } catch (e, st) {
      AppLogger.warning('Falha ao excluir evento no Google Calendar', e, st);
      return false;
    }
  }
}
