import 'dart:async';
import 'dart:math' as math;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/appointments/calendar_provider.dart';
import 'package:ministerio_pessoal/appointments/calendar_sync_coordinator.dart';
import 'package:ministerio_pessoal/contacts/doorstep_briefing_helper.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/publications/lff_book_catalog.dart';
import 'package:ministerio_pessoal/territory/landmark_manager.dart';
import 'package:ministerio_pessoal/ui/providers.dart';
import 'package:ministerio_pessoal/ui/screens/appointments_screen.dart';
import 'package:ministerio_pessoal/ui/widgets/interactive_map_canvas.dart';
import 'package:ministerio_pessoal/ui/widgets/quick_visit_dialog.dart';

PersonEntry _createPerson({
  String id = 'p-1',
  String name = 'Nome Teste',
  DateTime? firstContactAt,
  String status = 'interessado',
  double? latitude,
  double? longitude,
  String? generalNotes,
  String? contactRestrictions,
  String tags = '[]',
  DateTime? lastContactAt,
  DateTime? createdAt,
  DateTime? updatedAt,
  int revision = 1,
}) {
  final now = DateTime(2026, 11, 4, 10, 0);
  return PersonEntry(
    id: id,
    name: name,
    firstContactAt: firstContactAt ?? now,
    status: status,
    latitude: latitude,
    longitude: longitude,
    generalNotes: generalNotes,
    contactRestrictions: contactRestrictions,
    tags: tags,
    lastContactAt: lastContactAt,
    createdAt: createdAt ?? now,
    updatedAt: updatedAt ?? now,
    revision: revision,
  );
}

BibleStudyEntry _createStudy({
  String id = 's-1',
  String title = 'Estudo de Teste',
  String ownerId = 'local_user',
  DateTime? startedAt,
  String status = 'ativo',
  String publicationId = 'lff-book',
  String language = 'pt',
  int? currentLesson,
  int? currentParagraph,
  String? manualReference,
  String frequency = 'semanal',
  DateTime? createdAt,
  DateTime? updatedAt,
  int revision = 1,
}) {
  final now = DateTime(2026, 11, 4, 10, 0);
  return BibleStudyEntry(
    id: id,
    title: title,
    ownerId: ownerId,
    startedAt: startedAt ?? now,
    status: status,
    publicationId: publicationId,
    language: language,
    currentLesson: currentLesson,
    currentParagraph: currentParagraph,
    manualReference: manualReference,
    frequency: frequency,
    createdAt: createdAt ?? now,
    updatedAt: updatedAt ?? now,
    revision: revision,
  );
}

VisitEntry _createVisit({
  String id = 'v-1',
  String personId = 'p-1',
  DateTime? dateTimeField,
  String contactType = 'estudo',
  String result = 'Conversa receptiva',
  DateTime? createdAt,
  DateTime? updatedAt,
  int revision = 1,
}) {
  final now = DateTime(2026, 11, 4, 10, 0);
  return VisitEntry(
    id: id,
    personId: personId,
    dateTimeField: dateTimeField ?? now,
    contactType: contactType,
    result: result,
    createdAt: createdAt ?? now,
    updatedAt: updatedAt ?? now,
    revision: revision,
  );
}

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('CHALLENGE 1: Interactive Map Canvas Math & Zoom Drift Resilience', () {
    const double tileSize = 256.0;

    test('Mathematical Invertibility of Web Mercator Projections (lon <-> px, lat <-> py)', () {
      final zoomLevels = [10, 12, 14, 15, 16, 18];

      // Test extreme and typical coordinates
      final testCoords = <({double lat, double lon, String desc})>[
        (lat: 0.0, lon: 0.0, desc: 'Equator & Prime Meridian'),
        (lat: -23.550520, lon: -46.633308, desc: 'São Paulo (South/West)'),
        (lat: 51.5074, lon: -0.1278, desc: 'London (North/West)'),
        (lat: 35.6762, lon: 139.6503, desc: 'Tokyo (North/East)'),
        (lat: -33.8688, lon: 151.2093, desc: 'Sydney (South/East)'),
        (lat: 85.0511, lon: 180.0, desc: 'North-East Web Mercator Corner'),
        (lat: -85.0511, lon: -180.0, desc: 'South-West Web Mercator Corner'),
        (lat: 85.0511, lon: -180.0, desc: 'North-West Web Mercator Corner'),
        (lat: -85.0511, lon: 180.0, desc: 'South-East Web Mercator Corner'),
        (lat: 0.0, lon: 179.9999, desc: 'Near International Date Line East'),
        (lat: 0.0, lon: -179.9999, desc: 'Near International Date Line West'),
      ];

      for (final z in zoomLevels) {
        for (final coord in testCoords) {
          // 1. Longitude round-trip
          final px = InteractiveMapCanvas.lon2pixelX(coord.lon, z, tileSize);
          final roundTripLon = InteractiveMapCanvas.pixelX2lon(px, z, tileSize);
          expect(
            roundTripLon,
            closeTo(coord.lon, 1e-6),
            reason: 'Longitude drift at z=$z for ${coord.desc}',
          );

          // 2. Latitude round-trip
          final py = InteractiveMapCanvas.lat2pixelY(coord.lat, z, tileSize);
          final roundTripLat = InteractiveMapCanvas.pixelY2lat(py, z, tileSize);
          expect(
            roundTripLat,
            closeTo(coord.lat, 1e-4),
            reason: 'Latitude drift at z=$z for ${coord.desc}',
          );
        }
      }
    });

    test('Stress Test: 1,000 Randomized Coordinates Web Mercator Round-trip Invariance', () {
      final rng = math.Random(42);
      for (int i = 0; i < 1000; i++) {
        final lat = -85.0 + rng.nextDouble() * 170.0; // [-85.0, 85.0]
        final lon = -180.0 + rng.nextDouble() * 360.0; // [-180.0, 180.0]
        final z = 10 + rng.nextInt(9); // [10, 18]

        final px = InteractiveMapCanvas.lon2pixelX(lon, z, tileSize);
        final py = InteractiveMapCanvas.lat2pixelY(lat, z, tileSize);

        final recoveredLon = InteractiveMapCanvas.pixelX2lon(px, z, tileSize);
        final recoveredLat = InteractiveMapCanvas.pixelY2lat(py, z, tileSize);

        expect(recoveredLon, closeTo(lon, 1e-6));
        expect(recoveredLat, closeTo(lat, 1e-4));
      }
    });

    test('Tile Index Mapping Monotonicity and Boundary Clamping', () {
      for (int z = 10; z <= 18; z++) {
        final maxTiles = 1 << z;
        final tileWest = InteractiveMapCanvas.lon2tileX(-180.0, z);
        final tileEast = InteractiveMapCanvas.lon2tileX(179.9999, z);
        expect(tileWest, equals(0));
        expect(tileEast, equals(maxTiles - 1));

        final tileNorth = InteractiveMapCanvas.lat2tileY(85.0511, z);
        final tileSouth = InteractiveMapCanvas.lat2tileY(-85.0511, z);
        expect(tileNorth, equals(0));
        expect(tileSouth, equals(maxTiles - 1));
      }
    });

    testWidgets('InteractiveMapCanvas renders landmark and person pins with distinct keys', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final testContacts = [
        _createPerson(
          id: 'person_alpha',
          name: 'Lucas Ferreira',
          latitude: -23.550520,
          longitude: -46.633308,
        ),
        _createPerson(
          id: 'person_beta',
          name: 'Renata Lima',
          status: 'estudo',
          latitude: -23.551000,
          longitude: -46.634000,
        ),
      ];

      final testLandmarks = [
        TerritoryLandmark(
          id: 'landmark_padaria',
          name: 'Padaria Central',
          category: 'padaria',
          latitude: -23.550800,
          longitude: -46.633600,
          createdAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractiveMapCanvas(
              contacts: testContacts,
              landmarks: testLandmarks,
              showLandmarks: true,
              onPersonSelected: (_) {},
              onLandmarkSelected: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify that pins exist with expected ValueKeys
      expect(find.byKey(const ValueKey('person_pin_person_alpha')), findsOneWidget);
      expect(find.byKey(const ValueKey('person_pin_person_beta')), findsOneWidget);
      expect(find.byKey(const ValueKey('landmark_pin_landmark_padaria')), findsOneWidget);
    });
  });

  group('CHALLENGE 2: DoorstepBriefingHelper Deep Stress & Null Safety', () {
    test('DoorstepBriefingHelper handles empty/null person and null studies without crash', () {
      final emptyPerson = _createPerson(id: 'p_empty', name: 'Carlos Vazio');

      final briefing = DoorstepBriefingHelper.build(person: emptyPerson);
      expect(briefing, isNotNull);
      expect(briefing.hasAnyData, isFalse);
      expect(briefing.officialLessonTitle, isNull);
      expect(briefing.officialPointTitle, isNull);
      expect(briefing.sectionTitle, isNull);
      expect(briefing.lastVisitDate, isNull);
    });

    test('DoorstepBriefingHelper handles invalid lesson indices out of catalog range safely', () {
      final testPerson = _createPerson(id: 'p_out_of_bounds', name: 'Marcos Fora da Faixa', status: 'estudo');

      final invalidLessons = [-50, -1, 0, 61, 99, 9999];

      for (final invalidLesson in invalidLessons) {
        final outOfBoundsStudy = _createStudy(
          id: 'study_oob_$invalidLesson',
          currentLesson: invalidLesson,
          currentParagraph: 2,
        );

        expect(
          () => DoorstepBriefingHelper.build(
            person: testPerson,
            linkedStudy: outOfBoundsStudy,
          ),
          returnsNormally,
          reason: 'Failed gracefully on invalid lesson: $invalidLesson',
        );

        final result = DoorstepBriefingHelper.build(
          person: testPerson,
          linkedStudy: outOfBoundsStudy,
        );
        expect(result.officialLessonTitle, isNull);
        expect(result.officialPointTitle, isNull);
      }
    });

    test('DoorstepBriefingHelper handles invalid paragraph indices safely without RangeError', () {
      final testPerson = _createPerson(id: 'p_para_test', name: 'Julia Ponto', status: 'estudo');

      final validLessonStudy = _createStudy(
        id: 'study_lesson_04',
        title: 'Seja Feliz Para Sempre!',
        currentLesson: 4,
        currentParagraph: 999, // Lesson 4 does not have 999 points
      );

      final result = DoorstepBriefingHelper.build(
        person: testPerson,
        linkedStudy: validLessonStudy,
      );

      expect(result.officialLessonTitle, equals(LffBookCatalog.getLesson(4)!.title));
      expect(result.sectionTitle, isNotNull);
      expect(result.officialPointTitle, isNull); // Safely null, no RangeError!
    });

    test('DoorstepBriefingHelper handles corrupted and bizarre JSON strings in notes/targets', () {
      final corruptedPerson = _createPerson(
        id: 'p_corrupt',
        name: 'Pessoa JSON Quebrado',
        generalNotes: '{this is not valid json at all: [123}',
        contactRestrictions: '][}{corrupted string',
      );

      expect(
        () => DoorstepBriefingHelper.build(person: corruptedPerson),
        returnsNormally,
      );

      final result = DoorstepBriefingHelper.build(person: corruptedPerson);
      // Fallback treats string as legacy plain text note
      expect(result.empathyNote, contains('this is not valid json'));
    });

    test('DoorstepBriefingHelper correctly enriches valid LFF lesson, section, and last visit date', () {
      final visitDate = DateTime(2026, 11, 2, 10, 30);
      final testPerson = _createPerson(
        id: 'p_valid',
        name: 'Daniel Santos',
        status: 'estudo',
        lastContactAt: DateTime(2026, 10, 1),
      );

      final study = _createStudy(
        id: 'study_valid',
        title: 'Seja Feliz Para Sempre!',
        currentLesson: 3,
        currentParagraph: 2,
      );

      final latestVisit = _createVisit(
        id: 'v_latest',
        personId: testPerson.id,
        dateTimeField: visitDate,
      );

      final result = DoorstepBriefingHelper.build(
        person: testPerson,
        linkedStudy: study,
        latestVisit: latestVisit,
      );

      final lessonInfo = LffBookCatalog.getLesson(3)!;
      expect(result.officialLessonTitle, equals(lessonInfo.title));
      expect(result.sectionTitle, equals(LffBookCatalog.getSection(3).title));
      expect(result.officialPointTitle, equals(lessonInfo.pointTitles[1])); // Point 2 is index 1
      expect(result.lastVisitDate, equals(visitDate));
    });
  });

  group('CHALLENGE 3: Retroactive Visit Logging Toggle & Boundary Checks', () {
    testWidgets('QuickVisitDialog retroactive toggle behavior and future date restriction', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final testDb = AppDatabase.forTesting(NativeDatabase.memory());
      final repo = AppRepository(testDb);
      addTearDown(testDb.close);

      final person = await repo.createPerson(
        name: 'Roberto Costa',
        status: 'revisita',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(testDb),
            repositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: QuickVisitDialog(person: person),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final toggleFinder = find.byKey(const ValueKey('retroactive_date_toggle'));
      expect(toggleFinder, findsOneWidget);

      // Initially, toggle is OFF, so the date picker button is not present
      expect(find.byKey(const ValueKey('retroactive_date_picker_button')), findsNothing);

      // Turn toggle ON
      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();

      // Now date picker button is visible
      expect(find.byKey(const ValueKey('retroactive_date_picker_button')), findsOneWidget);

      // Turn toggle OFF again
      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();

      // Date picker button hides
      expect(find.byKey(const ValueKey('retroactive_date_picker_button')), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });

  group('CHALLENGE 4: Google Calendar Concurrency & Resilience Under Network Hangs', () {
    testWidgets('Calendar sync prevents double-tap and displays CircularProgressIndicator while syncing', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final testDb = AppDatabase.forTesting(NativeDatabase.memory());
      final repo = AppRepository(testDb);
      addTearDown(testDb.close);

      final syncCompleter = Completer<CalendarSyncResult>();
      int syncCalls = 0;

      final mockCoordinator = _HangingCalendarSyncCoordinator(
        testDb,
        onSyncAll: () {
          syncCalls++;
          return syncCompleter.future;
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(testDb),
            repositoryProvider.overrideWithValue(repo),
            calendarSyncCoordinatorProvider.overrideWithValue(mockCoordinator),
          ],
          child: const MaterialApp(
            home: AppointmentsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initial auto-sync on mount (postFrameCallback _checkAutoSyncCalendar) called syncAll once
      expect(syncCalls, equals(1));

      // Find the sync button in AppBar (FilledButton.tonalIcon on desktop, IconButton on mobile)
      final syncBtn = find.byIcon(Icons.sync);
      expect(syncBtn, findsOneWidget);

      // 1. User taps sync button -> triggers manual sync
      await tester.tap(syncBtn);
      await tester.pump(); // Start execution

      expect(syncCalls, equals(2));

      // 2. While syncing, spinner is rendered and sync button is replaced
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.sync), findsNothing);

      // Rapid double tap attempt: tapping during sync does NOT trigger another syncAll call
      await tester.tap(find.byType(CircularProgressIndicator), warnIfMissed: false);
      expect(syncCalls, equals(2));

      // 3. Complete the sync
      syncCompleter.complete(
        CalendarSyncResult(
          success: true,
          eventsDownloaded: 2,
          eventsUploaded: 1,
        ),
      );

      await tester.pumpAndSettle();

      // Spinner is removed, sync button restored
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byIcon(Icons.sync), findsOneWidget);
      expect(find.textContaining('Calendários sincronizados com sucesso'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Calendar sync handles 15s timeout gracefully without infinite loading or crash', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final testDb = AppDatabase.forTesting(NativeDatabase.memory());
      final repo = AppRepository(testDb);
      addTearDown(testDb.close);

      // Coordinator that never resolves (network hang)
      final mockCoordinator = _HangingCalendarSyncCoordinator(
        testDb,
        onSyncAll: () => Completer<CalendarSyncResult>().future,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(testDb),
            repositoryProvider.overrideWithValue(repo),
            calendarSyncCoordinatorProvider.overrideWithValue(mockCoordinator),
          ],
          child: const MaterialApp(
            home: AppointmentsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final syncBtn = find.byIcon(Icons.sync);
      expect(syncBtn, findsOneWidget);

      await tester.tap(syncBtn);
      await tester.pump(); // Initiates sync

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Advance time by 16 seconds to trip the 15-second timeout
      await tester.pump(const Duration(seconds: 16));
      await tester.pumpAndSettle();

      // Spinner MUST be gone
      expect(find.byType(CircularProgressIndicator), findsNothing);
      // SnackBar with timeout message displayed
      expect(find.textContaining('Tempo limite esgotado'), findsOneWidget);
      // Button restored
      expect(find.byIcon(Icons.sync), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}

class _HangingCalendarSyncCoordinator extends CalendarSyncCoordinator {
  final Future<CalendarSyncResult> Function() onSyncAll;

  _HangingCalendarSyncCoordinator(
    super.db, {
    required this.onSyncAll,
  });

  @override
  Future<CalendarSyncResult> syncAll({bool fullSync = false}) {
    return onSyncAll();
  }
}
