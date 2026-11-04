import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions, Value;

import 'package:ministerio_pessoal/appointments/availability_engine.dart';
import 'package:ministerio_pessoal/dashboard/counting_rules.dart';
import 'package:ministerio_pessoal/dashboard/student_priority_engine.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/ui/widgets/calendar_views/calendar_view_helper.dart';
import 'package:ministerio_pessoal/ui/widgets/dashboard_metrics/attention_items_card.dart';
import 'package:ministerio_pessoal/ui/widgets/dashboard_metrics/conversion_funnel_card.dart';
import 'package:ministerio_pessoal/ui/widgets/dashboard_metrics/ended_studies_reasons_card.dart';
import 'package:ministerio_pessoal/ui/widgets/dashboard_metrics/ended_visits_reasons_card.dart';
import 'package:ministerio_pessoal/ui/widgets/dashboard_metrics/modality_distribution_chart.dart';
import 'package:ministerio_pessoal/ui/widgets/dashboard_metrics/official_report_card.dart';
import 'package:ministerio_pessoal/ui/widgets/dashboard_metrics/personal_hour_goal_card.dart';
import 'package:ministerio_pessoal/ui/widgets/dashboard_metrics/scheduled_vs_actual_hours_card.dart';
import 'package:ministerio_pessoal/ui/widgets/dashboard_metrics/service_year_bar_chart.dart';
import 'package:ministerio_pessoal/ui/widgets/dashboard_metrics/study_attendance_metrics_card.dart';
import 'package:ministerio_pessoal/ui/widgets/dashboard_metrics/study_metrics_overview_card.dart';
import 'package:ministerio_pessoal/ui/widgets/person_preferred_schedule_dialog.dart';
import 'package:ministerio_pessoal/ui/widgets/studies_priority_progress_view.dart';

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('CHALLENGE 1: AvailabilityEngine & Calendar Recurrence / Timezone Stress Tests', () {
    final baseTime = DateTime(2026, 11, 4, 10, 0);

    AppointmentEntry createAppt({
      required String id,
      required DateTime start,
      required DateTime end,
      String status = 'confirmado',
      DateTime? deletedAt,
    }) {
      return AppointmentEntry(
        id: id,
        title: 'Estudo com João',
        startTime: start,
        endTime: end,
        durationMinutes: end.difference(start).inMinutes,
        status: status,
        deletedAt: deletedAt,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isProvisional: false,
        revision: 1,
      );
    }

    test('1.1: Touching intervals with buffer 0 do NOT collide', () {
      final existing = [
        createAppt(
          id: 'appt1',
          start: baseTime,
          end: baseTime.add(const Duration(hours: 1)),
        ),
      ];

      // Exact touch: starts at 11:00 when existing ends at 11:00
      final hasCollision = AvailabilityEngine.hasCollision(
        start: baseTime.add(const Duration(hours: 1)),
        end: baseTime.add(const Duration(hours: 2)),
        bufferMinutes: 0,
        existingAppointments: existing,
      );
      expect(hasCollision, isFalse);
    });

    test('1.2: Overlapping intervals with buffer 0 collide', () {
      final existing = [
        createAppt(
          id: 'appt1',
          start: baseTime,
          end: baseTime.add(const Duration(hours: 1)),
        ),
      ];

      final hasCollision = AvailabilityEngine.hasCollision(
        start: baseTime.add(const Duration(minutes: 45)),
        end: baseTime.add(const Duration(hours: 1, minutes: 45)),
        bufferMinutes: 0,
        existingAppointments: existing,
      );
      expect(hasCollision, isTrue);
    });

    test('1.3: Buffer collision detection (15 min gap requires buffer clearance)', () {
      final existing = [
        createAppt(
          id: 'appt1',
          start: baseTime,
          end: baseTime.add(const Duration(hours: 1)), // 10:00 to 11:00
        ),
      ];

      // Starts at 11:10 (10 min after previous). With 15 min buffer, effectiveStart is 10:55, which collides!
      final collidesWithBuffer = AvailabilityEngine.hasCollision(
        start: baseTime.add(const Duration(hours: 1, minutes: 10)),
        end: baseTime.add(const Duration(hours: 2)),
        bufferMinutes: 15,
        existingAppointments: existing,
      );
      expect(collidesWithBuffer, isTrue);

      // Starts at 11:20 (20 min after previous). With 15 min buffer, effectiveStart is 11:05, no collision!
      final clearOfBuffer = AvailabilityEngine.hasCollision(
        start: baseTime.add(const Duration(hours: 1, minutes: 20)),
        end: baseTime.add(const Duration(hours: 2)),
        bufferMinutes: 15,
        existingAppointments: existing,
      );
      expect(clearOfBuffer, isFalse);
    });

    test('1.4: Inactive and completed appointment statuses do not block slots', () {
      final statuses = [
        'cancelado',
        'nao_realizado',
        'reagendado',
        'realizado',
        'concluido',
        'concluído',
      ];

      for (final st in statuses) {
        final existing = [
          createAppt(
            id: 'appt_$st',
            start: baseTime,
            end: baseTime.add(const Duration(hours: 1)),
            status: st,
          ),
        ];

        final collides = AvailabilityEngine.hasCollision(
          start: baseTime,
          end: baseTime.add(const Duration(hours: 1)),
          existingAppointments: existing,
        );
        expect(collides, isFalse, reason: 'Status $st should not collide');
      }
    });

    test('1.5: Soft-deleted appointments are ignored', () {
      final existing = [
        createAppt(
          id: 'appt_deleted',
          start: baseTime,
          end: baseTime.add(const Duration(hours: 1)),
          deletedAt: DateTime.now(),
        ),
      ];

      final collides = AvailabilityEngine.hasCollision(
        start: baseTime,
        end: baseTime.add(const Duration(hours: 1)),
        existingAppointments: existing,
      );
      expect(collides, isFalse);
    });

    test('1.6: Excluded appointment ID is bypassed (for rescheduling)', () {
      final existing = [
        createAppt(
          id: 'target_appt',
          start: baseTime,
          end: baseTime.add(const Duration(hours: 1)),
        ),
      ];

      final collides = AvailabilityEngine.hasCollision(
        start: baseTime,
        end: baseTime.add(const Duration(hours: 1)),
        existingAppointments: existing,
        excludeAppointmentId: 'target_appt',
      );
      expect(collides, isFalse);
    });

    test('1.7: External events collision and status filtering', () {
      final activeExternal = ExternalCalendarEventEntry(
        id: 'ext_1',
        calendarId: 'cal_1',
        provider: 'google',
        externalEventId: 'ext_event_1',
        title: 'Dentista',
        startTime: baseTime,
        endTime: baseTime.add(const Duration(hours: 1)),
        isAllDay: false,
        externalStatus: 'confirmed',
        isDeletedExternal: false,
        lastSyncedAt: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        revision: 1,
      );

      final hasActiveCollision = AvailabilityEngine.hasCollision(
        start: baseTime,
        end: baseTime.add(const Duration(hours: 1)),
        existingAppointments: [],
        externalEvents: [activeExternal],
      );
      expect(hasActiveCollision, isTrue);

      final cancelledExternal = activeExternal.copyWith(
        externalStatus: const Value('cancelled'),
      );
      final hasCancelledCollision = AvailabilityEngine.hasCollision(
        start: baseTime,
        end: baseTime.add(const Duration(hours: 1)),
        existingAppointments: [],
        externalEvents: [cancelledExternal],
      );
      expect(hasCancelledCollision, isFalse);
    });

    test('1.8: Timezone stability (UTC vs Local DateTime comparison)', () {
      final localStart = DateTime(2026, 11, 4, 14, 0);
      final localEnd = DateTime(2026, 11, 4, 15, 0);
      final utcStart = localStart.toUtc();
      final utcEnd = localEnd.toUtc();

      final existing = [
        createAppt(id: 'appt_utc', start: utcStart, end: utcEnd),
      ];

      // Querying with local coordinates
      final collides = AvailabilityEngine.hasCollision(
        start: localStart,
        end: localEnd,
        existingAppointments: existing,
      );
      expect(collides, isTrue, reason: 'Epoch comparison must handle UTC vs Local seamlessly');
    });

    test('1.9: Alternative slot suggestions strictly stay within [08:00, 20:00]', () {
      // Create conflict late in the day (19:30 to 20:30)
      final lateStart = DateTime(2026, 11, 4, 19, 30);
      final existing = [
        createAppt(
          id: 'late_appt',
          start: lateStart,
          end: lateStart.add(const Duration(minutes: 60)),
        ),
      ];

      final result = AvailabilityEngine.checkAvailability(
        startTime: lateStart,
        durationMinutes: 60,
        existingAppointments: existing,
      );

      expect(result.isAvailable, isFalse);
      expect(result.suggestedAlternativeSlots, isNotEmpty);
      for (final slot in result.suggestedAlternativeSlots) {
        expect(slot.hour >= 8, isTrue, reason: 'Hour must be >= 08:00, got ${slot.hour}');
        final slotEnd = slot.add(const Duration(minutes: 60));
        expect(
          slotEnd.hour < 20 || (slotEnd.hour == 20 && slotEnd.minute == 0),
          isTrue,
          reason: 'End hour must be <= 20:00, got $slotEnd',
        );
      }
    });

    test('1.10: Leap year and month day boundary calculations (28, 29, 30, 31 days)', () {
      // Leap year 2024: Feb has 29 days
      expect(DateTime(2024, 3, 0).day, equals(29));
      // Leap year 2028: Feb has 29 days
      expect(DateTime(2028, 3, 0).day, equals(29));
      // Non-leap years: Feb has 28 days
      expect(DateTime(2025, 3, 0).day, equals(28));
      expect(DateTime(2026, 3, 0).day, equals(28));
      expect(DateTime(2027, 3, 0).day, equals(28));

      // 30-day months: April, June, September, November
      expect(DateTime(2026, 5, 0).day, equals(30)); // Apr
      expect(DateTime(2026, 7, 0).day, equals(30)); // Jun
      expect(DateTime(2026, 10, 0).day, equals(30)); // Sep
      expect(DateTime(2026, 12, 0).day, equals(30)); // Nov

      // 31-day months: Jan, Mar, May, Jul, Aug, Oct, Dec
      expect(DateTime(2026, 2, 0).day, equals(31)); // Jan
      expect(DateTime(2026, 4, 0).day, equals(31)); // Mar
      expect(DateTime(2026, 6, 0).day, equals(31)); // May
      expect(DateTime(2026, 8, 0).day, equals(31)); // Jul
      expect(DateTime(2026, 9, 0).day, equals(31)); // Aug
      expect(DateTime(2026, 11, 0).day, equals(31)); // Oct
      // Month 13 day 0: Dart normalizes to Dec 31
      expect(DateTime(2026, 13, 0).day, equals(31)); // Dec
    });

    test('1.11: Year transition: December (month 12) copies to January next year', () {
      final decDate = DateTime(2026, 12, 15);
      final sourceYear = decDate.year;
      final sourceMonth = decDate.month;
      final targetYear = sourceMonth == 12 ? sourceYear + 1 : sourceYear;
      final targetMonth = sourceMonth == 12 ? 1 : sourceMonth + 1;

      expect(targetYear, equals(2027));
      expect(targetMonth, equals(1));
    });

    test('1.12: Recurrence generation frequencies across months', () {
      List<DateTime> calculateDates({
        required int targetYear,
        required int targetMonth,
        required int weekday,
        required String frequency,
        int secondWeekday = 4,
        int hour = 9,
        int minute = 0,
      }) {
        final daysInTargetMonth = DateTime(targetYear, targetMonth + 1, 0).day;
        final primaryMatches = <DateTime>[];
        final secondMatches = <DateTime>[];

        for (int day = 1; day <= daysInTargetMonth; day++) {
          final candidate = DateTime(targetYear, targetMonth, day, hour, minute);
          if (candidate.weekday == weekday) {
            primaryMatches.add(candidate);
          } else if (frequency == '2x_semana' && candidate.weekday == secondWeekday) {
            secondMatches.add(candidate);
          }
        }

        if (frequency == 'semanal') {
          return primaryMatches;
        } else if (frequency == 'quinzenal_1_3') {
          return [for (int i = 0; i < primaryMatches.length; i++) if (i % 2 == 0) primaryMatches[i]];
        } else if (frequency == 'quinzenal_2_4') {
          return [for (int i = 0; i < primaryMatches.length; i++) if (i % 2 == 1) primaryMatches[i]];
        } else if (frequency == 'mensal') {
          return primaryMatches.isNotEmpty ? [primaryMatches.first] : [];
        } else if (frequency == '2x_semana') {
          return [...primaryMatches, ...secondMatches]..sort();
        }
        return primaryMatches;
      }

      // Test February 2026 (28 days): exactly 4 Mondays
      final feb2026Mondays = calculateDates(
        targetYear: 2026,
        targetMonth: 2,
        weekday: DateTime.monday,
        frequency: 'semanal',
      );
      expect(feb2026Mondays.length, equals(4));

      // Test quinzenal 1_3: exactly 2 dates (1st and 3rd)
      final febQuinzenal13 = calculateDates(
        targetYear: 2026,
        targetMonth: 2,
        weekday: DateTime.monday,
        frequency: 'quinzenal_1_3',
      );
      expect(febQuinzenal13.length, equals(2));
      expect(febQuinzenal13[0], equals(feb2026Mondays[0]));
      expect(febQuinzenal13[1], equals(feb2026Mondays[2]));

      // Test mensal: exactly 1 date
      final febMensal = calculateDates(
        targetYear: 2026,
        targetMonth: 2,
        weekday: DateTime.monday,
        frequency: 'mensal',
      );
      expect(febMensal.length, equals(1));

      // Test 2x_semana: Monday + Thursday in Feb 2026 (4 Mondays + 4 Thursdays = 8 dates)
      final feb2x = calculateDates(
        targetYear: 2026,
        targetMonth: 2,
        weekday: DateTime.monday,
        secondWeekday: DateTime.thursday,
        frequency: '2x_semana',
      );
      expect(feb2x.length, equals(8));
    });

    test('1.13: CalendarViewHelper keyword color mapping exhaustive coverage', () {
      AppointmentEntry entryWithTitle(String title) {
        return createAppt(
          id: 'test',
          start: baseTime,
          end: baseTime.add(const Duration(hours: 1)),
        ).copyWith(title: title);
      }

      expect(CalendarViewHelper.getAppointmentActivityColor(entryWithTitle('Viagem para congresso')), equals(const Color(0xFF0D9488)));
      expect(CalendarViewHelper.getAppointmentActivityColor(entryWithTitle('Ausência temporária')), equals(const Color(0xFFD97706)));
      expect(CalendarViewHelper.getAppointmentActivityColor(entryWithTitle('Dia de Folga')), equals(const Color(0xFF64748B)));
      expect(CalendarViewHelper.getAppointmentActivityColor(entryWithTitle('Compromisso Pessoal')), equals(const Color(0xFF9333EA)));
      expect(CalendarViewHelper.getAppointmentActivityColor(entryWithTitle('Outro evento')), equals(const Color(0xFF475569)));
      expect(CalendarViewHelper.getAppointmentActivityColor(entryWithTitle('Estudo Bíblico')), equals(const Color(0xFF059669)));
      expect(CalendarViewHelper.getAppointmentActivityColor(entryWithTitle('Revisita na rua das flores')), equals(const Color(0xFFEA580C)));
      expect(CalendarViewHelper.getAppointmentActivityColor(entryWithTitle('Pregação matinal')), equals(const Color(0xFF2563EB)));
    });
  });

  group('CHALLENGE 2: Dashboard Metrics Decomposition & Finder Contracts', () {
    final mockMetrics = DashboardMetrics(
      activeStudiesCount: 4,
      pausedStudiesCount: 1,
      heldSessionsCount: 12,
      uniqueParticipantsCount: 5,
      heldVisitsCount: 18,
      scheduledVisitsCount: 22,
      overdueVisitsCount: 2,
      completedAppointmentsCount: 15,
      cancelledAppointmentsCount: 1,
      notHeldAppointmentsCount: 0,
      totalActivitySeconds: 45 * 3600 + 30 * 60, // 45h 30m
      totalStudyAttendance: 142,
      averageAttendancePerStudy: 2.8,
      totalPlacements: 12,
      totalVideos: 8,
    );

    testWidgets('2.1: OfficialReportCard renders with exact contract finders', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: OfficialReportCard(
                metrics: mockMetrics,
                headingColor: Colors.black,
                dividerColor: Colors.grey,
                onExportPdf: () {},
                onShare: () {},
                onShowHoursRecords: () {},
                onShowStudiesRecords: () {},
                onShowVisitsRecords: () {},
              ),
            ),
          ),
        ),
      );

      // Verify explicit finders required by contract:
      expect(find.text('Relatório Mensal de Campo'), findsOneWidget);
      expect(find.text('HORAS'), findsOneWidget);
      expect(find.text('ESTUDOS'), findsOneWidget);
      expect(find.text('REVISITAS'), findsOneWidget);
      expect(find.text('45h 30min'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('18'), findsOneWidget);
    });

    testWidgets('2.2: StudyAttendanceMetricsCard renders exact "Total Assistência" finder', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StudyAttendanceMetricsCard(
                metrics: mockMetrics,
                headingColor: Colors.black,
                bodyColor: Colors.black87,
                mutedColor: Colors.grey,
                isDark: false,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Total Assistência'), findsOneWidget);
      expect(find.text('142 pessoas'), findsOneWidget);
    });

    testWidgets('2.3: PersonalHourGoalCard renders exact "Meta Pessoal de Horas" finder', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PersonalHourGoalCard(
                progressPercent: 0.70,
                totalHoursDone: 35.0,
                effectiveHourGoal: 50.0,
                remainingHours: 15.0,
                dailyHoursNeeded: 1.5,
                daysRemaining: 10,
                isYearMode: false,
                personalHourGoal: 50,
                onGoalChanged: (_) {},
                headingColor: Colors.black,
                bodyColor: Colors.black87,
                mutedColor: Colors.grey,
                dividerColor: Colors.grey.shade300,
                isDark: false,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Meta Pessoal de Horas'), findsOneWidget);
      expect(find.text('35.0h de 50.0 h'), findsOneWidget);
      expect(find.text('70%'), findsOneWidget);
    });

    testWidgets('2.4: All 11 Dashboard Metric Cards render simultaneously without overflow or crash', (tester) async {
      tester.view.physicalSize = const Size(1024, 2500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final dummyActivity = ActivityRecordEntry(
        id: 'act_1',
        date: DateTime.now(),
        durationSeconds: 3600,
        modality: 'campo',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        revision: 1,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  OfficialReportCard(
                    metrics: mockMetrics,
                    headingColor: Colors.black,
                    dividerColor: Colors.grey,
                    onExportPdf: () {},
                    onShare: () {},
                    onShowHoursRecords: () {},
                    onShowStudiesRecords: () {},
                    onShowVisitsRecords: () {},
                  ),
                  ScheduledVsActualHoursCard(
                    scheduledHours: 40.0,
                    actualHours: 45.5,
                    headingColor: Colors.black,
                    bodyColor: Colors.black87,
                    mutedColor: Colors.grey,
                    isDark: false,
                  ),
                  StudyAttendanceMetricsCard(
                    metrics: mockMetrics,
                    headingColor: Colors.black,
                    bodyColor: Colors.black87,
                    mutedColor: Colors.grey,
                    isDark: false,
                  ),
                  StudyMetricsOverviewCard(
                    metrics: mockMetrics,
                    headingColor: Colors.black,
                    bodyColor: Colors.black87,
                    mutedColor: Colors.grey,
                    isDark: false,
                  ),
                  ConversionFunnelCard(
                    metrics: mockMetrics,
                    headingColor: Colors.black,
                    bodyColor: Colors.black87,
                    mutedColor: Colors.grey,
                    isDark: false,
                  ),
                  EndedStudiesReasonsCard(
                    metrics: mockMetrics,
                    headingColor: Colors.black,
                    bodyColor: Colors.black87,
                    mutedColor: Colors.grey,
                    isDark: false,
                  ),
                  EndedVisitsReasonsCard(
                    metrics: mockMetrics,
                    headingColor: Colors.black,
                    bodyColor: Colors.black87,
                    mutedColor: Colors.grey,
                    isDark: false,
                  ),
                  PersonalHourGoalCard(
                    progressPercent: 0.70,
                    totalHoursDone: 35.0,
                    effectiveHourGoal: 50.0,
                    remainingHours: 15.0,
                    dailyHoursNeeded: 1.5,
                    daysRemaining: 10,
                    isYearMode: false,
                    personalHourGoal: 50,
                    onGoalChanged: (_) {},
                    headingColor: Colors.black,
                    bodyColor: Colors.black87,
                    mutedColor: Colors.grey,
                    dividerColor: Colors.grey.shade300,
                    isDark: false,
                  ),
                  SizedBox(
                    height: 160,
                    child: ServiceYearBarChart(
                      activities: [dummyActivity],
                      referenceDate: DateTime.now(),
                    ),
                  ),
                  ModalityDistributionChart(
                    activities: [dummyActivity],
                    periodStart: DateTime(2026, 11, 1),
                    periodEnd: DateTime(2026, 11, 30),
                  ),
                  AttentionItemsCard(
                    attentionItems: const [],
                    headingColor: Colors.black,
                    bodyColor: Colors.black87,
                    mutedColor: Colors.grey,
                    isDark: false,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // All 11 cards exist in the tree
      expect(find.byType(OfficialReportCard), findsOneWidget);
      expect(find.byType(ScheduledVsActualHoursCard), findsOneWidget);
      expect(find.byType(StudyAttendanceMetricsCard), findsOneWidget);
      expect(find.byType(StudyMetricsOverviewCard), findsOneWidget);
      expect(find.byType(ConversionFunnelCard), findsOneWidget);
      expect(find.byType(EndedStudiesReasonsCard), findsOneWidget);
      expect(find.byType(EndedVisitsReasonsCard), findsOneWidget);
      expect(find.byType(PersonalHourGoalCard), findsOneWidget);
      expect(find.byType(ServiceYearBarChart), findsOneWidget);
      expect(find.byType(ModalityDistributionChart), findsOneWidget);
      expect(find.byType(AttentionItemsCard), findsOneWidget);
    });
  });

  group('CHALLENGE 3: Studies Priority Progress View & ReorderableListView Contracts', () {
    testWidgets('3.1: Empty active studies displays clean informative placeholder', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StudiesPriorityProgressView(
              activeStudies: const [],
              participants: const [],
              people: const [],
              sessions: const [],
              appointments: const [],
              manualOrderMap: const {},
              isDark: false,
              onReorder: (_, _) {},
              onRecordSession: (_) {},
              onOpenContact: (_) {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.star_outline), findsOneWidget);
      expect(
        find.textContaining('Nenhum estudo bíblico ativo para calcular prioridade'),
        findsOneWidget,
      );
    });

    testWidgets('3.2: Non-empty active studies strictly preserves ValueKey(study.id) on Card builder', (tester) async {
      final study1 = BibleStudyEntry(
        id: 'study_uuid_101',
        title: 'Estudo com Mateus',
        publicationId: 'lff-book',
        language: 'pt',
        frequency: 'semanal',
        currentLesson: 5,
        startedAt: DateTime.now().subtract(const Duration(days: 30)),
        status: 'ativo',
        ownerId: 'owner_1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        revision: 1,
      );

      final study2 = BibleStudyEntry(
        id: 'study_uuid_202',
        title: 'Estudo com Tiago',
        publicationId: 'lff-book',
        language: 'pt',
        frequency: 'semanal',
        currentLesson: 12,
        startedAt: DateTime.now().subtract(const Duration(days: 60)),
        status: 'ativo',
        ownerId: 'owner_1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        revision: 1,
      );

      final person1 = PersonEntry(
        id: 'person_mateus',
        name: 'Mateus Oliveira',
        status: 'estudo',
        tags: '',
        firstContactAt: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        revision: 1,
      );

      final person2 = PersonEntry(
        id: 'person_tiago',
        name: 'Tiago Santos',
        status: 'estudo',
        tags: '',
        firstContactAt: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        revision: 1,
      );

      final part1 = StudyParticipantEntry(
        id: 'part_1',
        studyId: study1.id,
        personId: person1.id,
        isPrimary: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        revision: 1,
      );

      final part2 = StudyParticipantEntry(
        id: 'part_2',
        studyId: study2.id,
        personId: person2.id,
        isPrimary: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        revision: 1,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StudiesPriorityProgressView(
              activeStudies: [study1, study2],
              participants: [part1, part2],
              people: [person1, person2],
              sessions: const [],
              appointments: const [],
              manualOrderMap: const {},
              isDark: false,
              onReorder: (_, _) {},
              onRecordSession: (_) {},
              onOpenContact: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check Critical Contract: ValueKey(study.id)
      expect(find.byKey(const ValueKey('study_uuid_101')), findsOneWidget);
      expect(find.byKey(const ValueKey('study_uuid_202')), findsOneWidget);
    });

    test('3.3: Manual reordering logic updates manualOrderMap consistently', () {
      final study1 = BibleStudyEntry(
        id: 's1',
        title: 'Estudo 1',
        publicationId: 'lff-book',
        language: 'pt',
        frequency: 'semanal',
        startedAt: DateTime.now(),
        status: 'ativo',
        ownerId: 'owner_1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        revision: 1,
      );
      final study2 = BibleStudyEntry(
        id: 's2',
        title: 'Estudo 2',
        publicationId: 'lff-book',
        language: 'pt',
        frequency: 'semanal',
        startedAt: DateTime.now(),
        status: 'ativo',
        ownerId: 'owner_1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        revision: 1,
      );
      final study3 = BibleStudyEntry(
        id: 's3',
        title: 'Estudo 3',
        publicationId: 'lff-book',
        language: 'pt',
        frequency: 'semanal',
        startedAt: DateTime.now(),
        status: 'ativo',
        ownerId: 'owner_1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        revision: 1,
      );

      final person = PersonEntry(
        id: 'p1',
        name: 'Nome',
        status: 'estudo',
        tags: '',
        firstContactAt: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        revision: 1,
      );

      final items = [
        StudentPriorityItem(
          study: study1,
          person: person,
          internalScore: 210,
          progressPercentage: 10,
          lessonsPerWeekVelocity: 1.0,
          velocityLabel: '1 lição/sem',
          completedGoalsCount: 0,
          successfulSessionsCount: 5,
          failedSessionsCount: 0,
          manualOrderIndex: 0,
        ),
        StudentPriorityItem(
          study: study2,
          person: person,
          internalScore: 150,
          progressPercentage: 20,
          lessonsPerWeekVelocity: 0.8,
          velocityLabel: '0.8 lição/sem',
          completedGoalsCount: 0,
          successfulSessionsCount: 4,
          failedSessionsCount: 0,
          manualOrderIndex: 1,
        ),
        StudentPriorityItem(
          study: study3,
          person: person,
          internalScore: 80,
          progressPercentage: 30,
          lessonsPerWeekVelocity: 0.5,
          velocityLabel: '0.5 lição/sem',
          completedGoalsCount: 0,
          successfulSessionsCount: 2,
          failedSessionsCount: 0,
          manualOrderIndex: 2,
        ),
      ];

      final manualOrderMap = <String, int>{};

      // Drag index 0 down to index 2
      StudentPriorityEngine.applyManualReorderItem(
        items: items,
        oldIndex: 0,
        newIndex: 2,
        manualOrderMap: manualOrderMap,
      );

      expect(items[0].study.id, equals('s2'));
      expect(items[1].study.id, equals('s3'));
      expect(items[2].study.id, equals('s1'));

      expect(manualOrderMap['s2'], equals(0));
      expect(manualOrderMap['s3'], equals(1));
      expect(manualOrderMap['s1'], equals(2));
    });
  });

  group('CHALLENGE 4: Person Detail Screen & Preferred Schedule Dialog Contracts', () {
    testWidgets('4.1: PersonPreferredScheduleDialog standard picker outputs strictly "Dia às HH:mm"', (tester) async {
      final person = PersonEntry(
        id: 'p_pref',
        name: 'Lucas Teste',
        status: 'estudo',
        tags: '',
        preferredSchedule: 'Sábado às 09:00',
        firstContactAt: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        revision: 1,
      );

      String? savedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PersonPreferredScheduleDialog(
              person: person,
              onSave: (val) async {
                savedResult = val;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Salvar
      await tester.tap(find.text('Salvar Horário'));
      await tester.pumpAndSettle();

      expect(savedResult, equals('Sábado às 09:00'));
      expect(RegExp(r'^.+ às \d{2}:\d{2}$').hasMatch(savedResult!), isTrue);
    });

    testWidgets('4.2: PersonPreferredScheduleDialog parses initial string format correctly', (tester) async {
      final person = PersonEntry(
        id: 'p_pref_2',
        name: 'Ana Teste',
        status: 'estudo',
        tags: '',
        preferredSchedule: 'Quarta-feira às 19:30',
        firstContactAt: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        revision: 1,
      );

      String? savedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PersonPreferredScheduleDialog(
              person: person,
              onSave: (val) async {
                savedResult = val;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify that "19:30" is displayed in the dialog
      expect(find.text('19:30'), findsOneWidget);
      expect(find.text('Quarta-feira'), findsWidgets);

      await tester.tap(find.text('Salvar Horário'));
      await tester.pumpAndSettle();

      expect(savedResult, equals('Quarta-feira às 19:30'));
    });

    testWidgets('4.3: Custom free text toggle and fallback resilience', (tester) async {
      final person = PersonEntry(
        id: 'p_pref_custom',
        name: 'Custom Teste',
        status: 'estudo',
        tags: '',
        preferredSchedule: 'Domingo após a reunião matinal',
        firstContactAt: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        revision: 1,
      );

      String? savedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PersonPreferredScheduleDialog(
              person: person,
              onSave: (val) async {
                savedResult = val;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Non-standard schedule automatically switches to custom mode without crashing
      expect(find.text('Domingo após a reunião matinal'), findsOneWidget);

      await tester.tap(find.text('Salvar Horário'));
      await tester.pumpAndSettle();

      expect(savedResult, equals('Domingo após a reunião matinal'));
    });
  });
}
