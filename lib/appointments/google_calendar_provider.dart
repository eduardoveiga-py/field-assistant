import 'package:drift/drift.dart' as drift;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
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
  final Uuid _uuid = const Uuid();

  static const String _calendarScope =
      'https://www.googleapis.com/auth/calendar.events';
  static const String _keySelectedCalendarId = 'google_calendar_selected_id';
  static const String _keySyncTokenPrefix = 'google_calendar_synctoken_';

  GoogleSignInAccount? _currentUser;
  bool _initialized = false;

  GoogleCalendarProvider({
    GoogleSignIn? googleSignIn,
    FlutterSecureStorage? secureStorage,
  }) : _googleSignIn = googleSignIn ?? GoogleSignIn.instance,
       _secureStorage = secureStorage ?? const FlutterSecureStorage();

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    try {
      await _googleSignIn.initialize();
    } catch (_) {}
    _initialized = true;
  }

  @override
  CalendarProviderType get providerType => CalendarProviderType.google;

  @override
  Future<bool> isAuthorized() async {
    try {
      await _ensureInitialized();
      _currentUser ??= await _googleSignIn.attemptLightweightAuthentication();
      return _currentUser != null;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> requestAuthorization() async {
    try {
      await _ensureInitialized();
      _currentUser = await _googleSignIn.authenticate(
        scopeHint: [_calendarScope],
      );
      return _currentUser != null;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> getConnectedAccountName() async {
    if (_currentUser == null) {
      await isAuthorized();
    }
    return _currentUser?.email;
  }

  Future<gcal.CalendarApi?> _getCalendarApi() async {
    if (_currentUser == null) {
      await isAuthorized();
      if (_currentUser == null) {
        final authorized = await requestAuthorization();
        if (!authorized || _currentUser == null) return null;
      }
    }

    try {
      final headers = await _currentUser!.authorizationClient
          .authorizationHeaders([_calendarScope], promptIfNecessary: true);
      if (headers == null) return null;
      final authClient = _AuthenticatedClient(headers);
      return gcal.CalendarApi(authClient);
    } catch (_) {
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
    } catch (_) {
      return [
        ExternalCalendarItem(
          id: 'primary',
          name: 'Principal (${_currentUser?.email ?? "Google"})',
          accountName: _currentUser?.email,
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

  @override
  Future<void> disconnect() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    _currentUser = null;
    await _secureStorage.delete(key: _keySelectedCalendarId);
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
        errorMessage: 'Não foi possível autenticar com a Google Calendar API.',
      );
    }

    final calendarId = await getSelectedCalendarId() ?? 'primary';
    String? syncToken;
    if (!fullSync) {
      syncToken = await _secureStorage.read(
        key: '$_keySyncTokenPrefix$calendarId',
      );
    }

    int downloaded = 0;
    int uploaded = 0;
    int conflicts = 0;

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
            maxResults: 250,
          );
        } else {
          // Sincronização completa (janela de 90 dias atrás até 180 dias à frente)
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
            maxResults: 250,
          );
        }

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

          // Atualiza ou insere na tabela tipada ExternalCalendarEvents
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
          // Sync token expirado (410 Gone) -> executa full sync com segurança
          syncToken = null;
          pageToken = null;
          needsFullSync = true;
          continue;
        } else {
          return CalendarSyncResult(
            success: false,
            errorMessage: 'Erro da API Google: ${e.message}',
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
    } while (pageToken != null);

    if (nextSyncToken != null) {
      await _secureStorage.write(
        key: '$_keySyncTokenPrefix$calendarId',
        value: nextSyncToken,
      );
    }

    return CalendarSyncResult(
      success: true,
      eventsDownloaded: downloaded,
      eventsUploaded: uploaded,
      conflictsFound: conflicts,
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
    } catch (_) {
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
      return false;
    } catch (_) {
      return false;
    }
  }
}
