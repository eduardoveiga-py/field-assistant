import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:ministerio_pessoal/dashboard/pioneer_pace_calculator.dart';
import 'package:ministerio_pessoal/ui/widgets/pioneer_pace_card.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/settings/app_settings_manager.dart';
import 'package:ministerio_pessoal/ui/providers.dart';
class _TestSunModeNotifier extends SunModeNotifier {
  final bool initial;
  _TestSunModeNotifier(this.initial);
  @override
  bool build() => initial;
}

class FakeAppSettingsManager extends AppSettingsManager {
  final Map<String, String> _storage = {};

  FakeAppSettingsManager(super.db);

  @override
  Future<String?> getString(String key) async {
    return _storage[key];
  }

  @override
  Future<void> setString(String key, String value) async {
    _storage[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    _storage.remove(key);
  }
}

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('PioneerPaceCalculator (Unit Tests - R2)', () {
    test('Calcula ritmo com precisão quando há saídas restantes (50h, 32h feitas, 5 saídas)', () {
      // Maio de 2026: sábados nos dias 2, 9, 16, 23, 30 (5 sábados)
      final date = DateTime(2026, 5, 2);
      final result = PioneerPaceCalculator.calculate(
        goalHours: 50.0,
        designatedWeekdays: [6], // Sábado
        completedHours: 32.0,
        currentDate: date,
      );

      expect(result.goalHours, equals(50.0));
      expect(result.completedHours, equals(32.0));
      expect(result.remainingHours, equals(18.0));
      expect(result.isGoalReached, isFalse);
      expect(result.remainingOutings, equals(5));
      expect(result.idealPacePerOuting, equals(const Duration(hours: 3, minutes: 36)));
      expect(result.idealPaceFormatted, equals('3h36m'));
      expect(
        result.formattedPaceText,
        equals('Faltam 18h em 5 saídas. Seu ritmo ideal é de 3h36m por saída'),
      );
    });

    test('Calcula ritmo para pioneiro auxiliar (30h, 10h feitas, 8 saídas -> 2h30m)', () {
      // Outubro 2026 a partir do dia 6 com Terças e Quintas: dias 6, 8, 13, 15, 20, 22, 27, 29 (8 saídas)
      final date = DateTime(2026, 10, 6);
      final result = PioneerPaceCalculator.calculate(
        goalHours: 30.0,
        designatedWeekdays: [2, 4],
        completedHours: 10.0,
        currentDate: date,
      );

      expect(result.goalHours, equals(30.0));
      expect(result.remainingHours, equals(20.0));
      expect(result.remainingOutings, equals(8));
      expect(result.idealPacePerOuting, equals(const Duration(hours: 2, minutes: 30)));
      expect(result.idealPaceFormatted, equals('2h30m'));
      expect(
        result.formattedPaceText,
        equals('Faltam 20h em 8 saídas. Seu ritmo ideal é de 2h30m por saída'),
      );
    });

    test('Meta atingida exatamente exibe string canônica sem horas restantes', () {
      final date = DateTime(2026, 10, 25);
      final result = PioneerPaceCalculator.calculate(
        goalHours: 50.0,
        designatedWeekdays: [2, 4, 6],
        completedHours: 50.0,
        currentDate: date,
      );

      expect(result.isGoalReached, isTrue);
      expect(result.remainingHours, equals(0.0));
      expect(result.idealPacePerOuting, equals(Duration.zero));
      expect(
        result.formattedPaceText,
        equals('Meta atingida! Parabéns pelo empenho no ministério.'),
      );
    });

    test('Meta superada evita horas negativas e mantém mensagem comemorativa', () {
      final date = DateTime(2026, 10, 25);
      final result = PioneerPaceCalculator.calculate(
        goalHours: 50.0,
        designatedWeekdays: [2, 4, 6],
        completedHours: 55.5,
        currentDate: date,
      );

      expect(result.isGoalReached, isTrue);
      expect(result.remainingHours, equals(0.0));
      expect(
        result.formattedPaceText,
        equals('Meta atingida! Parabéns pelo empenho no ministério.'),
      );
    });

    test('0 saídas restantes com horas pendentes calcula duração total e mensagem canônica', () {
      // 31 de Outubro de 2026 é Sábado (6). Se apenas Segundas (1) estiverem configuradas:
      final date = DateTime(2026, 10, 31);
      final result = PioneerPaceCalculator.calculate(
        goalHours: 50.0,
        designatedWeekdays: [1],
        completedHours: 45.0,
        currentDate: date,
      );

      expect(result.remainingOutings, equals(0));
      expect(result.remainingHours, equals(5.0));
      expect(result.isGoalReached, isFalse);
      expect(result.idealPacePerOuting, equals(const Duration(hours: 5)));
      expect(
        result.formattedPaceText,
        equals('Faltam 5h em 0 saídas. Seu ritmo ideal é de 5h00m por saída'),
      );
    });

    test('Lista vazia de dias habituais ([]) retorna 0 saídas com segurança', () {
      final date = DateTime(2026, 10, 10);
      final result = PioneerPaceCalculator.calculate(
        goalHours: 50.0,
        designatedWeekdays: [],
        completedHours: 30.0,
        currentDate: date,
      );

      expect(result.remainingOutings, equals(0));
      expect(result.remainingHours, equals(20.0));
      expect(result.isGoalReached, isFalse);
      expect(
        result.formattedPaceText,
        equals('Faltam 20h em 0 saídas. Seu ritmo ideal é de 20h00m por saída'),
      );
    });

    test('Lida com anos bissextos (Fev/2028: 29 dias) vs ano comum (Fev/2027: 28 dias)', () {
      // Fev 2028: Terças nos dias 1, 8, 15, 22, 29 (5 terças)
      final leapResult = PioneerPaceCalculator.calculate(
        goalHours: 30.0,
        designatedWeekdays: [2],
        completedHours: 0.0,
        currentDate: DateTime(2028, 2, 1),
      );
      expect(leapResult.remainingOutings, equals(5));

      // Fev 2027: Segundas nos dias 1, 8, 15, 22 (4 segundas)
      final regularResult = PioneerPaceCalculator.calculate(
        goalHours: 30.0,
        designatedWeekdays: [1],
        completedHours: 0.0,
        currentDate: DateTime(2027, 2, 1),
      );
      expect(regularResult.remainingOutings, equals(4));
    });

    test('Formata horas decimais fracionárias (ex: 18.5h restantes em 5 saídas -> 3h42m)', () {
      final date = DateTime(2026, 5, 2);
      final result = PioneerPaceCalculator.calculate(
        goalHours: 50.0,
        designatedWeekdays: [6], // 5 sábados em maio/2026
        completedHours: 31.5,
        currentDate: date,
      );

      expect(result.remainingHours, equals(18.5));
      expect(result.remainingOutings, equals(5));
      // 18.5 * 60 / 5 = 1110 / 5 = 222 min = 3h42m
      expect(result.idealPacePerOuting, equals(const Duration(hours: 3, minutes: 42)));
      expect(result.idealPaceFormatted, equals('3h42m'));
      expect(
        result.formattedPaceText,
        equals('Faltam 18.5h em 5 saídas. Seu ritmo ideal é de 3h42m por saída'),
      );
    });

    test('Protege contra valores negativos de entrada via math.max(0.0, ...)', () {
      final date = DateTime(2026, 10, 1);
      final result = PioneerPaceCalculator.calculate(
        goalHours: -20.0,
        designatedWeekdays: [1],
        completedHours: -10.0,
        currentDate: date,
      );

      expect(result.goalHours, equals(0.0));
      expect(result.completedHours, equals(0.0));
      expect(result.remainingHours, equals(0.0));
    });

    test('Rollover de final de ano (Dezembro) calcula corretamente até o dia 31', () {
      final date = DateTime(2026, 12, 28); // Segunda
      // Dias restantes em dez/2026: 28(Seg), 29(Ter), 30(Qua), 31(Qui)
      final result = PioneerPaceCalculator.calculate(
        goalHours: 50.0,
        designatedWeekdays: [4], // Quinta-feira (dia 31)
        completedHours: 46.0,
        currentDate: date,
      );

      expect(result.remainingOutings, equals(1));
      expect(result.remainingHours, equals(4.0));
      expect(result.idealPacePerOuting, equals(const Duration(hours: 4)));
    });
  });

  group('PioneerPaceCard (Widget Tests - R2)', () {
    late AppDatabase db;
    late FakeAppSettingsManager settings;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      settings = FakeAppSettingsManager(db);
    });

    tearDown(() async {
      await db.close();
    });


    Widget createTestWidget({
      double? completedHours = 20.0,
      DateTime? dateOverride,
      bool isDark = false,
      bool isSunMode = false,
    }) {
      return ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appSettingsManagerProvider.overrideWithValue(settings),
          sunModeProvider.overrideWith(() => _TestSunModeNotifier(isSunMode)),
        ],
        child: MaterialApp(
          theme: ThemeData(brightness: isDark ? Brightness.dark : Brightness.light),
          home: Scaffold(
            body: SingleChildScrollView(
              child: PioneerPaceCard(
                currentMonthCompletedHours: completedHours,
                currentDateOverride: dateOverride ?? DateTime(2026, 10, 15),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('Renderiza card de ritmo com barra de progresso, percentual e saídas restantes', (tester) async {
      await tester.pumpWidget(createTestWidget(
        completedHours: 20.0,
        dateOverride: DateTime(2026, 10, 15),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Ritmo Real de Campo'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      // 20h de 50h = 40%
      expect(find.text('Feitas: 20h de 50h (40%)'), findsOneWidget);
      expect(find.textContaining('saída(s) restante(s)'), findsOneWidget);
      expect(find.byIcon(Icons.tune), findsOneWidget);
      expect(find.textContaining('Faltam 30h'), findsOneWidget);
    });

    testWidgets('Renderiza visual comemorativo quando meta é atingida', (tester) async {
      await tester.pumpWidget(createTestWidget(
        completedHours: 50.0,
        dateOverride: DateTime(2026, 10, 20),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Feitas: 50h de 50h (100%)'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byIcon(Icons.celebration), findsOneWidget);
      expect(find.text('Meta atingida! Parabéns pelo empenho no ministério.'), findsOneWidget);
    });

    testWidgets('Alvo de toque do botão de configurações respeita >= 48x48 dp', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final tuneFinder = find.byTooltip('Configurar Meta e Dias de Campo');
      expect(tuneFinder, findsOneWidget);
      final size = tester.getSize(tuneFinder);
      expect(size.width, greaterThanOrEqualTo(48.0));
      expect(size.height, greaterThanOrEqualTo(48.0));
    });

    testWidgets('Abre diálogo modal de configuração rápida ao tocar no ícone tune', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();

      expect(find.text('Configurar Ritmo de Campo'), findsOneWidget);
      expect(find.text('Meta Mensal de Horas:'), findsOneWidget);
      expect(find.text('50h (Regular)'), findsOneWidget);
      expect(find.text('30h (Auxiliar)'), findsOneWidget);
      expect(find.text('15h (Reduzida)'), findsOneWidget);
      expect(find.text('Dias habituais de campo na semana:'), findsOneWidget);
      expect(find.text('Seg'), findsOneWidget);
      expect(find.text('Sáb'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Salvar'), findsOneWidget);
    });

    testWidgets('Seleciona preset 30h, alterna dias e salva com dual-write no AppSettingsManager', (tester) async {
      await tester.pumpWidget(createTestWidget(
        completedHours: 10.0,
        dateOverride: DateTime(2026, 10, 6),
      ));
      await tester.pumpAndSettle();

      // Abre diálogo
      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();

      // Seleciona 30h (Auxiliar)
      await tester.tap(find.text('30h (Auxiliar)'));
      await tester.pumpAndSettle();

      // Salva
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      // Verifica dual-write em AppSettingsManager
      final goal1 = await settings.getString('pioneer_goal_hours');
      final goal2 = await settings.getString('pioneer_monthly_goal_hours');
      final days1 = await settings.getString('pioneer_weekdays');
      final days2 = await settings.getString('pioneer_designated_weekdays');

      expect(goal1, equals('30.0'));
      expect(goal2, equals('30.0'));
      expect(days1, isNotNull);
      expect(days2, isNotNull);
      expect(days1, equals(days2));

      // Verifica atualização reativa no card (10h de 30h = 33%)
      expect(find.text('Feitas: 10h de 30h (33%)'), findsOneWidget);
    });

    testWidgets('Adaptação ao SunMode aplica borda sólida preta de 2.0dp e alto contraste', (tester) async {
      await tester.pumpWidget(createTestWidget(
        completedHours: 15.0,
        isSunMode: true,
      ));
      await tester.pumpAndSettle();

      // Localiza o Container do card principal
      final containerFinder = find.byType(Container).first;
      final containerWidget = tester.widget<Container>(containerFinder);
      final decoration = containerWidget.decoration as BoxDecoration;

      expect(decoration.color, equals(Colors.white));
      expect(decoration.border, isNotNull);
      final border = decoration.border as Border;
      expect(border.top.color, equals(Colors.black));
      expect(border.top.width, equals(2.0));
    });

    testWidgets('Adaptação ao Dark Mode renderiza sem erros', (tester) async {
      await tester.pumpWidget(createTestWidget(
        completedHours: 25.0,
        isDark: true,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Ritmo Real de Campo'), findsOneWidget);
      expect(find.text('Feitas: 25h de 50h (50%)'), findsOneWidget);
    });
  });
}
