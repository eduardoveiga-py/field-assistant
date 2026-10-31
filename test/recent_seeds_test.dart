import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:ministerio_pessoal/contacts/recent_seeds_helper.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/ui/widgets/recent_seed_badge.dart';
import 'package:ministerio_pessoal/ui/screens/people_screen.dart';
import 'package:ministerio_pessoal/ui/providers.dart';
import 'package:ministerio_pessoal/core/app_theme.dart';

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('RecentSeedsHelper (R3 - Destaque de Sementes Recentes)', () {
    final baseNow = DateTime(2026, 10, 20, 10, 0);

    PersonEntry makePerson({
      required String id,
      required String name,
      required String status,
      DateTime? firstContactAt,
      DateTime? createdAt,
      DateTime? deletedAt,
    }) {
      return PersonEntry(
        id: id,
        name: name,
        status: status,
        tags: '[]',
        firstContactAt: firstContactAt ?? createdAt ?? baseNow,
        createdAt: createdAt ?? firstContactAt ?? baseNow,
        updatedAt: baseNow,
        deletedAt: deletedAt,
        revision: 1,
      );
    }

    VisitEntry makeVisit({
      required String id,
      required String personId,
      required String contactType,
      required String result,
      DateTime? deletedAt,
    }) {
      return VisitEntry(
        id: id,
        personId: personId,
        dateTimeField: baseNow,
        contactType: contactType,
        result: result,
        revision: 1,
        createdAt: baseNow,
        updatedAt: baseNow,
        deletedAt: deletedAt,
      );
    }

    test('Pessoa registrada há 3 dias sem revisitas é Semente Recente', () {
      final person = makePerson(
        id: 'p1',
        name: 'Carlos Silva',
        status: 'potencial',
        firstContactAt: baseNow.subtract(const Duration(days: 3)),
      );

      final isSeed = RecentSeedsHelper.isRecentSeed(
        person: person,
        visits: [],
        nowOverride: baseNow,
      );

      expect(isSeed, isTrue);
      final text = RecentSeedsHelper.getElapsedText(
        firstContactAt: person.firstContactAt,
        nowOverride: baseNow,
      );
      expect(text, contains('há 3 dias'));
      expect(text, contains('faltam 4 dias'));
    });

    test('Pessoa encontrada hoje é Semente Recente no dia 0', () {
      final person = makePerson(
        id: 'p2',
        name: 'Ana Pereira',
        status: 'revisita',
        firstContactAt: baseNow,
      );

      final isSeed = RecentSeedsHelper.isRecentSeed(
        person: person,
        visits: [],
        nowOverride: baseNow,
      );

      expect(isSeed, isTrue);
      final text = RecentSeedsHelper.getElapsedText(
        firstContactAt: person.firstContactAt,
        nowOverride: baseNow,
      );
      expect(text, contains('encontrada hoje'));
      expect(
        RecentSeedsHelper.getBadgeLabel(firstContactAt: person.firstContactAt, nowOverride: baseNow),
        equals('🌱 Recente (Hoje)'),
      );
    });

    test('Pessoa com primeiro contato há mais de 7 dias NÃO é Semente Recente', () {
      final person = makePerson(
        id: 'p3',
        name: 'Roberto Souza',
        status: 'revisita',
        firstContactAt: baseNow.subtract(const Duration(days: 8)),
      );

      final isSeed = RecentSeedsHelper.isRecentSeed(
        person: person,
        visits: [],
        nowOverride: baseNow,
      );

      expect(isSeed, isFalse);
    });

    test('Pessoa que já recebeu uma revisita realizada NÃO é mais Semente Recente', () {
      final person = makePerson(
        id: 'p4',
        name: 'Marcos Lima',
        status: 'revisita',
        firstContactAt: baseNow.subtract(const Duration(days: 2)),
      );

      final visit = makeVisit(
        id: 'v1',
        personId: 'p4',
        contactType: 'revisita',
        result: 'encontrado',
      );

      final isSeed = RecentSeedsHelper.isRecentSeed(
        person: person,
        visits: [visit],
        nowOverride: baseNow,
      );

      expect(isSeed, isFalse);
    });

    test('Visitas canceladas ou com pessoa não encontrada não anulam status de Semente Recente', () {
      final person = makePerson(
        id: 'p5',
        name: 'Fernanda Dias',
        status: 'revisita',
        firstContactAt: baseNow.subtract(const Duration(days: 2)),
      );

      final visitNotHome = makeVisit(
        id: 'v2',
        personId: 'p5',
        contactType: 'revisita',
        result: 'nao_encontrado',
      );

      final visitDeleted = makeVisit(
        id: 'v3',
        personId: 'p5',
        contactType: 'revisita',
        result: 'encontrado',
        deletedAt: baseNow,
      );

      final isSeed = RecentSeedsHelper.isRecentSeed(
        person: person,
        visits: [visitNotHome, visitDeleted],
        nowOverride: baseNow,
      );

      expect(isSeed, isTrue);
    });

    test('Estudante bíblico ou pessoa arquivada/excluída NÃO é Semente Recente', () {
      final student = makePerson(
        id: 'p6',
        name: 'Estudante Ativo',
        status: 'estudo',
        firstContactAt: baseNow.subtract(const Duration(days: 2)),
      );

      final deletedPerson = makePerson(
        id: 'p7',
        name: 'Excluído',
        status: 'revisita',
        firstContactAt: baseNow.subtract(const Duration(days: 2)),
        deletedAt: baseNow,
      );

      expect(RecentSeedsHelper.isRecentSeed(person: student, visits: [], nowOverride: baseNow), isFalse);
      expect(RecentSeedsHelper.isRecentSeed(person: deletedPerson, visits: [], nowOverride: baseNow), isFalse);
    });

    test('Texto no limite exato de 7 dias alerta urgência de visita', () {
      final contactDate = baseNow.subtract(const Duration(days: 7));
      final text = RecentSeedsHelper.getElapsedText(firstContactAt: contactDate, nowOverride: baseNow);
      expect(text, contains('no Limite'));
      expect(text, contains('revisite hoje'));
    });

    test('getFriendlyElapsedLabel gera os rótulos amigáveis especificados para cada intervalo (R3)', () {
      // 0 dias: 'Plantada hoje — Revisitar logo'
      expect(
        RecentSeedsHelper.getFriendlyElapsedLabel(firstContactAt: baseNow, nowOverride: baseNow),
        equals('Plantada hoje — Revisitar logo'),
      );

      // Data futura / skew seguro: 'Plantada hoje — Revisitar logo'
      expect(
        RecentSeedsHelper.getFriendlyElapsedLabel(
          firstContactAt: baseNow.add(const Duration(hours: 3)),
          nowOverride: baseNow,
        ),
        equals('Plantada hoje — Revisitar logo'),
      );

      // 1 dia: 'Plantada há 1 dia — Revisitar logo'
      expect(
        RecentSeedsHelper.getFriendlyElapsedLabel(
          firstContactAt: baseNow.subtract(const Duration(days: 1)),
          nowOverride: baseNow,
        ),
        equals('Plantada há 1 dia — Revisitar logo'),
      );

      // 2 a 6 dias: 'Plantada há $diffDays dias — Revisitar logo'
      for (int days = 2; days <= 6; days++) {
        expect(
          RecentSeedsHelper.getFriendlyElapsedLabel(
            firstContactAt: baseNow.subtract(Duration(days: days)),
            nowOverride: baseNow,
          ),
          equals('Plantada há $days dias — Revisitar logo'),
        );
      }

      // 7 dias: 'Plantada há 7 dias — Limite para revisita!'
      expect(
        RecentSeedsHelper.getFriendlyElapsedLabel(
          firstContactAt: baseNow.subtract(const Duration(days: 7)),
          nowOverride: baseNow,
        ),
        equals('Plantada há 7 dias — Limite para revisita!'),
      );
    });
  });

  group('RecentSeedBadge Widget Tests (R3)', () {
    final baseNow = DateTime(2026, 10, 20, 10, 0);

    Widget buildBadgeTestApp({
      required Widget badge,
      ThemeData? theme,
    }) {
      return MaterialApp(
        theme: theme ?? AppTheme.lightTheme,
        home: Scaffold(
          body: Center(child: badge),
        ),
      );
    }

    testWidgets('TC-W01: Renderiza ícone eco e label "Plantada hoje" no dia 0 com Semantics', (tester) async {
      await tester.pumpWidget(buildBadgeTestApp(
        badge: RecentSeedBadge(
          firstContactAt: baseNow,
          nowOverride: baseNow,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.eco), findsOneWidget);
      expect(find.text('Plantada hoje — Revisitar logo'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Semente Recente: Plantada hoje — Revisitar logo',
        ),
        findsOneWidget,
      );
    });

    testWidgets('TC-W02: Renderiza label "Plantada há 3 dias — Revisitar logo" após 3 dias', (tester) async {
      await tester.pumpWidget(buildBadgeTestApp(
        badge: RecentSeedBadge(
          firstContactAt: baseNow.subtract(const Duration(days: 3)),
          nowOverride: baseNow,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.eco), findsOneWidget);
      expect(find.text('Plantada há 3 dias — Revisitar logo'), findsOneWidget);
    });

    testWidgets('TC-W03: Renderiza label "Plantada há 7 dias — Limite para revisita!" no limite de 7 dias', (tester) async {
      await tester.pumpWidget(buildBadgeTestApp(
        badge: RecentSeedBadge(
          firstContactAt: baseNow.subtract(const Duration(days: 7)),
          nowOverride: baseNow,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.eco), findsOneWidget);
      expect(find.text('Plantada há 7 dias — Limite para revisita!'), findsOneWidget);
    });

    testWidgets('TC-W04: Estilo Light Mode aplica fundo verde-100, borda verde-600 e texto verde-900', (tester) async {
      await tester.pumpWidget(buildBadgeTestApp(
        theme: AppTheme.lightTheme,
        badge: RecentSeedBadge(
          firstContactAt: baseNow.subtract(const Duration(days: 2)),
          nowOverride: baseNow,
        ),
      ));
      await tester.pumpAndSettle();

      final containerFinder = find.byType(Container).first;
      final container = tester.widget<Container>(containerFinder);
      final decoration = container.decoration as BoxDecoration;

      expect(decoration.color, equals(const Color(0xFFDCFCE7))); // green-100
      expect(decoration.border?.top.color, equals(const Color(0xFF16A34A))); // green-600

      final text = tester.widget<Text>(find.text('Plantada há 2 dias — Revisitar logo'));
      expect(text.style?.color, equals(const Color(0xFF14532D))); // green-900

      final icon = tester.widget<Icon>(find.byIcon(Icons.eco));
      expect(icon.color, equals(const Color(0xFF14532D)));
    });

    testWidgets('TC-W05: Estilo Dark Mode aplica container esmeralda, borda menta e texto menta', (tester) async {
      await tester.pumpWidget(buildBadgeTestApp(
        theme: AppTheme.darkTheme,
        badge: RecentSeedBadge(
          firstContactAt: baseNow.subtract(const Duration(days: 4)),
          nowOverride: baseNow,
        ),
      ));
      await tester.pumpAndSettle();

      final containerFinder = find.byType(Container).first;
      final container = tester.widget<Container>(containerFinder);
      final decoration = container.decoration as BoxDecoration;

      expect(decoration.color, equals(const Color(0xFF064E3B).withValues(alpha: 0.35)));
      expect(decoration.border?.top.color, equals(const Color(0xFF34D399)));

      final text = tester.widget<Text>(find.text('Plantada há 4 dias — Revisitar logo'));
      expect(text.style?.color, equals(const Color(0xFFA7F3D0)));

      final icon = tester.widget<Icon>(find.byIcon(Icons.eco));
      expect(icon.color, equals(const Color(0xFFA7F3D0)));
    });

    testWidgets('TC-W06: Estilo Sun Mode aplica container branco, borda preta sólida 2.0dp e texto FontWeight.w900', (tester) async {
      await tester.pumpWidget(buildBadgeTestApp(
        theme: AppTheme.sunModeTheme,
        badge: RecentSeedBadge(
          firstContactAt: baseNow.subtract(const Duration(days: 1)),
          nowOverride: baseNow,
        ),
      ));
      await tester.pumpAndSettle();

      final containerFinder = find.byType(Container).first;
      final container = tester.widget<Container>(containerFinder);
      final decoration = container.decoration as BoxDecoration;

      expect(decoration.color, equals(Colors.white));
      expect(decoration.border?.top.color, equals(const Color(0xFF000000)));
      expect(decoration.border?.top.width, greaterThanOrEqualTo(2.0));

      final text = tester.widget<Text>(find.text('Plantada há 1 dia — Revisitar logo'));
      expect(text.style?.color, equals(const Color(0xFF000000)));
      expect(text.style?.fontWeight, equals(FontWeight.w900));

      final icon = tester.widget<Icon>(find.byIcon(Icons.eco));
      expect(icon.color, equals(const Color(0xFF000000)));
    });

    testWidgets('TC-W07: Tocar no badge dispara callback onTap e exibe Tooltip de acessibilidade', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(buildBadgeTestApp(
        badge: RecentSeedBadge(
          firstContactAt: baseNow,
          nowOverride: baseNow,
          onTap: () => tapped = true,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(Tooltip), findsOneWidget);
      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.message, contains('Primeiro contato nos últimos 7 dias aguardando 1ª revisita'));

      await tester.tap(find.byType(RecentSeedBadge));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });
  });

  group('PeopleScreen Recent Seeds Integration Widget Tests (R3)', () {
    final testNow = DateTime.now();

    testWidgets('TC-W08: PeopleScreen exibe RecentSeedBadge no card de semente recente e oculta em contato antigo', (tester) async {
      final testDb = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(testDb.close);
      final testRepo = AppRepository(testDb);

      // 1. Contato semente recente (< 7 dias sem revisita)
      await testRepo.createPerson(
        name: 'Interessado Recente',
        status: 'interessado',
        firstContactAt: testNow.subtract(const Duration(days: 2)),
      );

      // 2. Contato antigo (> 7 dias)
      await testDb.into(testDb.people).insert(
        PeopleCompanion.insert(
          id: 'old-1',
          name: 'Contato Antigo',
          firstContactAt: testNow.subtract(const Duration(days: 15)),
          status: const Value('revisita'),
          createdAt: testNow.subtract(const Duration(days: 15)),
          updatedAt: testNow.subtract(const Duration(days: 15)),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(testDb),
            repositoryProvider.overrideWithValue(testRepo),
          ],
          child: const MaterialApp(
            home: PeopleScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Interessado Recente'), findsOneWidget);
      expect(find.text('Contato Antigo'), findsOneWidget);

      // O badge RecentSeedBadge deve estar presente apenas no card da semente recente
      expect(find.byType(RecentSeedBadge), findsOneWidget);
      expect(find.text('Plantada há 2 dias — Revisitar logo'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });

    testWidgets('TC-W09: FilterChip "Sementes Recentes" possui avatar eco e filtra a lista', (tester) async {
      final testDb = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(testDb.close);
      final testRepo = AppRepository(testDb);

      await testRepo.createPerson(
        name: 'Lucas Semente',
        status: 'interessado',
        firstContactAt: testNow.subtract(const Duration(days: 1)),
      );

      await testDb.into(testDb.people).insert(
        PeopleCompanion.insert(
          id: 'old-2',
          name: 'Mateus Veterano',
          firstContactAt: testNow.subtract(const Duration(days: 20)),
          status: const Value('revisita'),
          createdAt: testNow.subtract(const Duration(days: 20)),
          updatedAt: testNow.subtract(const Duration(days: 20)),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(testDb),
            repositoryProvider.overrideWithValue(testRepo),
          ],
          child: const MaterialApp(
            home: PeopleScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Lucas Semente'), findsOneWidget);
      expect(find.text('Mateus Veterano'), findsOneWidget);

      // Encontra FilterChip 'Sementes Recentes'
      final chipFinder = find.widgetWithText(FilterChip, 'Sementes Recentes');
      expect(chipFinder, findsOneWidget);

      // Toca no FilterChip de Sementes Recentes
      await tester.tap(chipFinder);
      await tester.pumpAndSettle();

      // Somente Lucas Semente permanece visível
      expect(find.text('Lucas Semente'), findsOneWidget);
      expect(find.text('Mateus Veterano'), findsNothing);

      // Toca em 'Todos' para restaurar lista
      final allChipFinder = find.widgetWithText(FilterChip, 'Todos');
      await tester.tap(allChipFinder);
      await tester.pumpAndSettle();

      expect(find.text('Lucas Semente'), findsOneWidget);
      expect(find.text('Mateus Veterano'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });

    testWidgets('TC-W10: Estado vazio com filtro "Sementes Recentes" exibe mensagem amigável', (tester) async {
      final testDb = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(testDb.close);

      // Nenhum contato é semente recente (apenas contato com > 7 dias)
      await testDb.into(testDb.people).insert(
        PeopleCompanion.insert(
          id: 'old-3',
          name: 'Pessoa Antiga',
          firstContactAt: testNow.subtract(const Duration(days: 30)),
          status: const Value('revisita'),
          createdAt: testNow.subtract(const Duration(days: 30)),
          updatedAt: testNow.subtract(const Duration(days: 30)),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(testDb),
            repositoryProvider.overrideWithValue(AppRepository(testDb)),
          ],
          child: const MaterialApp(
            home: PeopleScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pessoa Antiga'), findsOneWidget);

      // Seleciona o filtro 'Sementes Recentes'
      final chipFinder = find.widgetWithText(FilterChip, 'Sementes Recentes');
      await tester.tap(chipFinder);
      await tester.pumpAndSettle();

      // Deve exibir mensagem específica de sementes recentes vazias
      expect(
        find.text('Nenhuma semente recente pendente de revisita no momento.'),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });

    testWidgets('TC-W11: Alvos de toque no card de contato atendem padrão mínimo de 48x48 dp', (tester) async {
      final testDb = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(testDb.close);
      final testRepo = AppRepository(testDb);

      await testRepo.createPerson(
        name: 'Contato Teste Acessibilidade',
        status: 'interessado',
        phone: '11999999999',
        address: 'Rua das Flores, 123',
        tags: ['novo'],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(testDb),
            repositoryProvider.overrideWithValue(testRepo),
          ],
          child: const MaterialApp(
            home: PeopleScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verifica botão de adicionar etiqueta (48x48 dp)
      final addTagFinder = find.bySemanticsLabel('Adicionar etiqueta');
      expect(addTagFinder, findsOneWidget);
      final tagSize = tester.getSize(addTagFinder);
      expect(tagSize.width, greaterThanOrEqualTo(48.0));
      expect(tagSize.height, greaterThanOrEqualTo(48.0));

      // Verifica PopupMenuButton de status (48x48 dp)
      final statusPopupFinder = find.byTooltip('Alterar situação com 1 toque');
      expect(statusPopupFinder, findsOneWidget);
      final popupSize = tester.getSize(statusPopupFinder);
      expect(popupSize.width, greaterThanOrEqualTo(48.0));
      expect(popupSize.height, greaterThanOrEqualTo(48.0));

      // Verifica botões de ação rápida (Phone, WhatsApp, Maps, Perfil)
      final phoneBtnFinder = find.byTooltip('Ligar');
      expect(phoneBtnFinder, findsOneWidget);
      final phoneSize = tester.getSize(phoneBtnFinder);
      expect(phoneSize.width, greaterThanOrEqualTo(48.0));
      expect(phoneSize.height, greaterThanOrEqualTo(48.0));

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  });
}
