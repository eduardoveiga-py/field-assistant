import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/ui/providers.dart';
import 'package:ministerio_pessoal/ui/screens/appointments_screen.dart';
import 'package:ministerio_pessoal/ui/widgets/appointments/appointment_detail_pane.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(
    'AppointmentsScreen Adaptive Layout & Master-Detail Tests (FA-UX-02)',
    () {
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
    },
  );
}
