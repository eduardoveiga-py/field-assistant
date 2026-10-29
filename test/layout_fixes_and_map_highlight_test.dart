import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/ui/main_navigation_shell.dart';
import 'package:ministerio_pessoal/ui/providers.dart';
import 'package:ministerio_pessoal/ui/screens/contacts_map_screen.dart';
import 'package:ministerio_pessoal/ui/screens/experiences_screen.dart';
import 'package:ministerio_pessoal/ui/screens/research_screen.dart';
import 'package:ministerio_pessoal/appointments/ics_picker_helper.dart';

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('Layout & Overflow Fixes', () {
    testWidgets('NavigationRail does not overflow even on short screens (height: 500px)', (tester) async {
      // Configura tela baixa (1024x500) onde ocorria o overflow de 61px
      tester.view.physicalSize = const Size(1024, 500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final testDb = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(testDb.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(testDb),
          ],
          child: const MaterialApp(
            home: MainNavigationShell(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verifica que o NavigationRail foi renderizado sem exceção de overflow
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.descendant(of: find.byType(NavigationRail), matching: find.text('Hoje')), findsOneWidget);
      expect(find.descendant(of: find.byType(NavigationRail), matching: find.text('Ajustes')), findsOneWidget);

      // Não houve nenhum erro de RenderFlex overflow
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Experiências modal with photos renders without RenderViewport intrinsic dimensions exception', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final testDb = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(testDb.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(testDb),
          ],
          child: const MaterialApp(
            home: ExperiencesScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Abre modal de nova experiência
      final addBtn = find.text('+ Relatar Experiência');
      expect(addBtn, findsOneWidget);
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      expect(find.text('Relatar Nova Experiência'), findsOneWidget);

      // Verifica presença do botão de foto e Wrap
      expect(find.byIcon(Icons.add_photo_alternate), findsOneWidget);

      // Não há exceção durante o layout do modal
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Pesquisas modal with attachments renders without RenderViewport exception', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final testDb = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(testDb.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(testDb),
          ],
          child: const MaterialApp(
            home: ResearchScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final addBtn = find.text('+ Nova Pesquisa');
      expect(addBtn, findsOneWidget);
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      expect(find.text('Nova Pesquisa para o Ministério'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });

  group('Interactive Map & Contact Highlight', () {
    testWidgets('ContactsMapScreen with highlightPersonId centers and displays highlighted star pin', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final testDb = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(testDb.close);

      // Insere duas pessoas: uma destacada e uma vizinha
      await testDb.into(testDb.people).insert(
        PeopleCompanion.insert(
          id: 'person_highlight',
          name: 'João Silva',
          status: const Value('estudo'),
          address: const Value('Rua das Flores, 100'),
          latitude: const Value(-23.550000),
          longitude: const Value(-46.633000),
          firstContactAt: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      await testDb.into(testDb.people).insert(
        PeopleCompanion.insert(
          id: 'person_neighbor',
          name: 'Maria Oliveira',
          status: const Value('revisita'),
          address: const Value('Rua das Flores, 120'),
          latitude: const Value(-23.550100),
          longitude: const Value(-46.633100),
          firstContactAt: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(testDb),
          ],
          child: const MaterialApp(
            home: ContactsMapScreen(highlightPersonId: 'person_highlight'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verifica presença dos pinos
      expect(find.text('João'), findsAtLeast(1));
      expect(find.text('Maria'), findsAtLeast(1));

      // Verifica que João possui o ícone de estrela / destaque
      expect(find.byIcon(Icons.stars), findsOneWidget);
      // E o banner de destaque superior
      expect(find.text('Destacado: João'), findsOneWidget);

      // Tocar no botão de fechar destaque do banner limpa o foco
      await tester.tap(find.text('Destacado: João'));
      await tester.pumpAndSettle();

      // Banner desaparece e João volta ao pino normal
      expect(find.text('Destacado: João'), findsNothing);
      expect(find.byIcon(Icons.stars), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('ContactsMapScreen pinch gesture and mouse wheel zoom do not throw', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final testDb = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(testDb.close);

      await testDb.into(testDb.people).insert(
        PeopleCompanion.insert(
          id: 'person_test',
          name: 'Pedro Santos',
          status: const Value('interessado'),
          address: const Value('Av. Central, 50'),
          latitude: const Value(-23.555000),
          longitude: const Value(-46.635000),
          firstContactAt: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(testDb),
          ],
          child: const MaterialApp(
            home: ContactsMapScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Simula gesto de scroll de roda do mouse (zoom in)
      final mapFinder = find.byType(InteractiveViewer);
      expect(mapFinder, findsOneWidget);

      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: const Offset(400, 300),
          scrollDelta: const Offset(0, -20),
        ),
      );
      await tester.pumpAndSettle();

      // Zoom deve ter mudado de Z: 15 para Z: 16
      expect(find.text('Z: 16'), findsOneWidget);

      // Simula múltiplos scrolls de zoom out até o nível da cidade (Z: 10)
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 150));
        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: const Offset(400, 300),
            scrollDelta: const Offset(0, 30),
          ),
        );
        await tester.pumpAndSettle();
      }

      // Confirma que atingiu o nível de zoom da cidade inteira (Z: 10)
      expect(find.text('Z: 10'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('ContactsMapScreen auto-geocodes highlighted contact without GPS coordinates', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final testDb = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(testDb.close);

      // Insere pessoa com endereço mas SEM latitude/longitude
      await testDb.into(testDb.people).insert(
        PeopleCompanion.insert(
          id: 'person_no_coords',
          name: 'Carlos Mendes',
          status: const Value('interessado'),
          address: const Value('Av. Paulista, 1000, São Paulo'),
          firstContactAt: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(testDb),
          ],
          child: const MaterialApp(
            home: ContactsMapScreen(highlightPersonId: 'person_no_coords'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // O banner do contato destacado aparece imediatamente
      expect(find.text('Destacado: Carlos'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });

  group('ICS Calendar Picker Helper', () {
    test('IcsPickerHelper stub returns null safely without exceptions', () async {
      final res = await IcsPickerHelper.pickIcsFile();
      expect(res, isNull);
    });
  });
}

