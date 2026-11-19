import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/ui/providers.dart';
import 'package:ministerio_pessoal/ui/screens/appointments_screen.dart';
import 'package:ministerio_pessoal/ui/widgets/appointments/appointment_detail_pane.dart';
import 'package:ministerio_pessoal/ui/widgets/appointments/appointments_controls_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppointmentsScreen Adaptive Layout & Master-Detail Tests (FA-UX-02)', () {
    final now = DateTime.now();

    testWidgets(
      'TC-APPTS-01: Layout móvel (<900px) exibe lista única sem divider de split',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final repo = AppRepository(db);

        await repo.createAppointment(
          title: 'Revisita com Carlos',
          startTime: now.add(const Duration(hours: 1)),
          endTime: now.add(const Duration(hours: 2)),
          durationMinutes: 60,
        );

        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              repositoryProvider.overrideWithValue(repo),
            ],
            child: const MaterialApp(home: AppointmentsScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Mudar para o modo Lista
        await tester.tap(find.text('Lista'));
        await tester.pumpAndSettle();

        expect(find.text('Revisita com Carlos'), findsOneWidget);

        // No modo móvel, não existe VerticalDivider de split nem placeholder de detalhe
        expect(find.byType(VerticalDivider), findsNothing);
        expect(find.byType(AppointmentDetailPane), findsNothing);
        expect(
          find.text('Selecione um compromisso para visualizar detalhes'),
          findsNothing,
        );

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'TC-APPTS-02: Layout iPad (>=900px) em modo Lista exibe Split View com placeholder',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final repo = AppRepository(db);

        await repo.createAppointment(
          title: 'Revisita com Carlos',
          startTime: now.add(const Duration(hours: 1)),
          endTime: now.add(const Duration(hours: 2)),
          durationMinutes: 60,
        );

        tester.view.physicalSize = const Size(1024, 768);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              repositoryProvider.overrideWithValue(repo),
            ],
            child: const MaterialApp(home: AppointmentsScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Mudar para o modo Lista
        await tester.tap(find.text('Lista'));
        await tester.pumpAndSettle();

        // No modo iPad, VerticalDivider e placeholder estão visíveis
        expect(find.byType(VerticalDivider), findsOneWidget);
        expect(
          find.text('Selecione um compromisso para visualizar detalhes'),
          findsOneWidget,
        );
        expect(find.byType(AppointmentDetailPane), findsNothing);

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'TC-APPTS-03: Tocar no compromisso seleciona e renderiza AppointmentDetailPane com ações',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final repo = AppRepository(db);

        await repo.createAppointment(
          title: 'Revisita com Carlos',
          startTime: now.add(const Duration(hours: 1)),
          endTime: now.add(const Duration(hours: 2)),
          durationMinutes: 60,
        );

        tester.view.physicalSize = const Size(1024, 768);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              repositoryProvider.overrideWithValue(repo),
            ],
            child: const MaterialApp(home: AppointmentsScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Mudar para o modo Lista
        await tester.tap(find.text('Lista'));
        await tester.pumpAndSettle();

        // Tocar no card do compromisso para selecioná-lo
        await tester.tap(find.text('Revisita com Carlos'));
        await tester.pumpAndSettle();

        // Agora o AppointmentDetailPane deve estar renderizado
        expect(find.byType(AppointmentDetailPane), findsOneWidget);
        expect(
          find.text('Selecione um compromisso para visualizar detalhes'),
          findsNothing,
        );
        expect(find.text('Marcar Realizado'), findsOneWidget);
        expect(find.text('Reagendar'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'TC-APPTS-04: iPad multitasking split (678px) empilha barra de controles sem overflow',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final repo = AppRepository(db);

        // Largura típica de multitasking 1/2 split em iPad (678px)
        tester.view.physicalSize = const Size(678, 1024);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              repositoryProvider.overrideWithValue(repo),
            ],
            child: const MaterialApp(home: AppointmentsScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Sem exceção de RenderFlex e controles renderizados
        expect(tester.takeException(), isNull);
        expect(find.text('Mês'), findsOneWidget);
        expect(find.text('Semana'), findsOneWidget);
        expect(find.text('Dia'), findsOneWidget);
        expect(find.text('Lista'), findsOneWidget);

        // Desmonta tela exercitando _timeScrollController.dispose()
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'TC-APPTS-05: AppointmentDetailPane contact row does not overflow at 399px width under 2.0x dynamic text scaling',
      (tester) async {
        tester.view.physicalSize = const Size(399, 800);
        tester.view.devicePixelRatio = 1.0;
        tester.platformDispatcher.textScaleFactorTestValue = 2.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        final testAppt = AppointmentEntry(
          id: 'appt-adaptive-01',
          title: 'Visita de Estudo Bíblico Semanal',
          startTime: now.add(const Duration(hours: 2)),
          endTime: now.add(const Duration(hours: 3)),
          durationMinutes: 60,
          status: 'planejado',
          personId: 'person-long-name-01',
          createdAt: now,
          updatedAt: now,
          revision: 1,
          isProvisional: false,
        );

        final testPerson = PersonEntry(
          id: 'person-long-name-01',
          name: 'Carlos Eduardo Silva de Alcântara',
          status: 'revisita',
          tags: '[]',
          firstContactAt: now,
          createdAt: now,
          updatedAt: now,
          revision: 1,
        );

        bool profileOpened = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 399,
                child: AppointmentDetailPane(
                  appt: testAppt,
                  person: testPerson,
                  onOpenPersonProfile: () => profileOpened = true,
                  onReschedule: () {},
                  onMarkDone: () {},
                  onCancelPlanB: () {},
                  onAddToGoogleCalendar: () {},
                  onDelete: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Sem exceção de RenderFlex e texto adaptado com empilhamento
        expect(tester.takeException(), isNull);
        expect(find.text('Ver Perfil'), findsOneWidget);
        expect(
          find.text('Contato: Carlos Eduardo Silva de Alcântara'),
          findsOneWidget,
        );

        // Toca no botão adaptativo e confirma callback
        await tester.ensureVisible(find.text('Ver Perfil'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ver Perfil'));
        await tester.pumpAndSettle();
        expect(profileOpened, isTrue);

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'TC-APPTS-06: AppointmentsScreen week view headers do not overflow at 375px width under 2.0x dynamic text scaling',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final repo = AppRepository(db);

        await repo.createAppointment(
          title: 'Revisita com Carlos',
          startTime: now.add(const Duration(hours: 1)),
          endTime: now.add(const Duration(hours: 2)),
          durationMinutes: 60,
        );

        // Simula iPhone SE / tela estreita (375px) com fonte 200% (2.0x)
        tester.view.physicalSize = const Size(375, 800);
        tester.view.devicePixelRatio = 1.0;
        tester.platformDispatcher.textScaleFactorTestValue = 2.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              repositoryProvider.overrideWithValue(repo),
            ],
            child: const MaterialApp(home: AppointmentsScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Muda para visualização Semana
        await tester.tap(find.text('Semana'));
        await tester.pumpAndSettle();

        // Sem exceção de RenderFlex overflow nos headers da semana
        expect(tester.takeException(), isNull);
        expect(find.textContaining('compromisso(s)'), findsWidgets);

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'TC-APPTS-07: AppointmentsControlsBar does not overflow at 768px (iPad portrait) and 1024px (iPad landscape) under 2.0x and 2.5x text scaling across all view modes',
      (tester) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        final viewports = [
          const Size(375, 800),
          const Size(768, 1024),
          const Size(1024, 768),
        ];
        final textScales = [2.0, 2.5];
        final viewModes = ['Mês', 'Semana', 'Dia', 'Lista'];

        for (final viewport in viewports) {
          for (final scale in textScales) {
            for (final mode in viewModes) {
              tester.view.physicalSize = viewport;
              tester.view.devicePixelRatio = 1.0;
              tester.platformDispatcher.textScaleFactorTestValue = scale;

              String currentMode = mode;
              bool todayPressed = false;

              await tester.pumpWidget(
                MaterialApp(
                  home: Scaffold(
                    body: AppointmentsControlsBar(
                      viewMode: currentMode,
                      selectedDate: DateTime(2026, 11, 18),
                      isDark: false,
                      onViewModeChanged: (val) => currentMode = val,
                      onPreviousDate: () {},
                      onNextDate: () {},
                      onTodayPressed: () => todayPressed = true,
                    ),
                  ),
                ),
              );
              await tester.pumpAndSettle();

              // Sem exceção de RenderFlex overflow
              expect(
                tester.takeException(),
                isNull,
                reason:
                    'Overflow detected at viewport $viewport with scale ${scale}x in mode $mode',
              );

              // Botão "Hoje" deve estar presente e interativo
              final todayBtn = find.byTooltip('Hoje');
              expect(todayBtn, findsOneWidget);
              await tester.tap(todayBtn);
              await tester.pumpAndSettle();
              expect(todayPressed, isTrue);

              // Todos os segmentos de visualização devem estar visíveis
              for (final m in viewModes) {
                expect(find.text(m), findsWidgets);
              }

              await tester.pumpWidget(const SizedBox());
              await tester.pumpAndSettle();
            }
          }
        }
      },
    );

    testWidgets(
      'TC-APPTS-08: Month view cells with 2+ appointments do not overflow vertically under 2.0x and 2.5x text scaling across mobile and tablet viewports',
      (tester) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final repo = AppRepository(db);

        final today = DateTime.now();

        // Criar 3 compromissos com títulos longos no mesmo dia
        await repo.createAppointment(
          title: 'Estudo Bíblico com Marcos Pereira da Silva',
          startTime: DateTime(today.year, today.month, today.day, 9, 0),
          endTime: DateTime(today.year, today.month, today.day, 10, 0),
          durationMinutes: 60,
        );
        await repo.createAppointment(
          title: 'Revisita de Campo na Comunidade Betânia',
          startTime: DateTime(today.year, today.month, today.day, 14, 0),
          endTime: DateTime(today.year, today.month, today.day, 15, 0),
          durationMinutes: 60,
        );
        await repo.createAppointment(
          title: 'Reunião de Preparação e Serviço',
          startTime: DateTime(today.year, today.month, today.day, 17, 0),
          endTime: DateTime(today.year, today.month, today.day, 18, 0),
          durationMinutes: 60,
        );

        final viewports = [
          const Size(320, 568),
          const Size(375, 800),
          const Size(768, 1024),
          const Size(1024, 768),
        ];
        final textScales = [2.0, 2.5];

        for (final viewport in viewports) {
          for (final scale in textScales) {
            tester.view.physicalSize = viewport;
            tester.view.devicePixelRatio = 1.0;
            tester.platformDispatcher.textScaleFactorTestValue = scale;

            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  databaseProvider.overrideWithValue(db),
                  repositoryProvider.overrideWithValue(repo),
                ],
                child: const MaterialApp(home: AppointmentsScreen()),
              ),
            );
            await tester.pumpAndSettle();

            // Sem exceção de RenderFlex vertical overflow nas células mensais
            expect(
              tester.takeException(),
              isNull,
              reason:
                  'Vertical overflow detected in month view at $viewport under ${scale}x scale',
            );

            // Tocar no número do dia para verificar o painel inferior de detalhes
            final dayFinder = find.text('${today.day}');
            expect(dayFinder, findsWidgets);
            await tester.tap(dayFinder.first);
            await tester.pumpAndSettle();

            // No painel inferior de compromissos do dia, os títulos devem estar renderizados
            expect(find.textContaining('Estudo Bíblico'), findsWidgets);

            await tester.pumpWidget(const SizedBox());
            await tester.pumpAndSettle();
          }
        }
      },
    );
  });
}
