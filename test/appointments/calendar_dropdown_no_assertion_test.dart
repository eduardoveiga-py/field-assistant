import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/appointments/calendar_provider.dart';

void main() {
  group('Resolução de Seleção de Calendário Google e Dropdown Seguro', () {
    test('resolveCalendarSelection converte apelido primary para o ID real do calendário principal', () {
      final calendars = [
        ExternalCalendarItem(
          id: 'irmao.campo@gmail.com',
          name: 'Agenda Pessoal',
          isPrimary: true,
          isReadOnly: false,
        ),
        ExternalCalendarItem(
          id: 'feriados.brasil@group.calendar.google.com',
          name: 'Feriados no Brasil',
          isPrimary: false,
          isReadOnly: true,
        ),
      ];

      // Quando salvo é 'primary', resolve para o calendário principal
      final resolved = resolveCalendarSelection(calendars, 'primary', google: true);
      expect(resolved, 'irmao.campo@gmail.com');

      // Quando salvo é um ID específico existente
      final resolvedDirect = resolveCalendarSelection(calendars, 'irmao.campo@gmail.com', google: true);
      expect(resolvedDirect, 'irmao.campo@gmail.com');
    });

    test('resolveCalendarSelection retorna nulo se seleção salva não existe na lista', () {
      final calendars = [
        ExternalCalendarItem(
          id: 'outro@gmail.com',
          name: 'Outra Agenda',
          isPrimary: false,
          isReadOnly: false,
        ),
      ];

      final resolved = resolveCalendarSelection(calendars, 'antigo_deletado@gmail.com', google: true);
      expect(resolved, isNull);

      final resolvedPrimary = resolveCalendarSelection(calendars, 'primary', google: true);
      expect(resolvedPrimary, isNull);
    });

    test('resolveCalendarSelection casa ID "primary" literal se constar na lista', () {
      final calendars = [
        ExternalCalendarItem(
          id: 'primary',
          name: 'Principal Fallback',
          isPrimary: false,
          isReadOnly: false,
        ),
      ];

      final resolved = resolveCalendarSelection(calendars, 'primary', google: true);
      expect(resolved, 'primary');
    });

    test('uniqueCalendarItems remove duplicados e strings vazias', () {
      final items = [
        ExternalCalendarItem(id: 'cal-1', name: 'Cal 1'),
        ExternalCalendarItem(id: 'cal-1', name: 'Cal 1 Duplicado'),
        ExternalCalendarItem(id: '', name: 'Vazio'),
        ExternalCalendarItem(id: 'cal-2', name: 'Cal 2'),
      ];

      final unique = uniqueCalendarItems(items);
      expect(unique.length, 2);
      expect(unique.map((c) => c.id), ['cal-1', 'cal-2']);
    });

    testWidgets('DropdownButtonFormField não lança assertion error quando valor inicial é primary e nenhum item possui ID primary', (tester) async {
      // Simula o cenário que causava o erro relatado pelo usuário:
      // O ID salvo no storage era 'primary', mas os calendários da conta têm IDs como 'vanessa@gmail.com'.
      final googleCalendars = [
        ExternalCalendarItem(
          id: 'vanessa@gmail.com',
          name: 'Agenda Principal (vanessa@gmail.com)',
          isPrimary: true,
          isReadOnly: false,
        ),
      ];

      // Usando a lógica de resolução segura implementada
      final rawSelectedId = 'primary';
      final safeSelectedId = resolveCalendarSelection(
        googleCalendars.where((c) => !c.isReadOnly).toList(),
        rawSelectedId,
        google: true,
      );

      expect(safeSelectedId, 'vanessa@gmail.com');

      // Renderiza o DropdownButtonFormField com a lógica segura
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return DropdownButtonFormField<String>(
                  key: ValueKey('google-${safeSelectedId ?? "none"}'),
                  initialValue: googleCalendars
                          .where((c) => !c.isReadOnly)
                          .any((c) => c.id == safeSelectedId)
                      ? safeSelectedId
                      : null,
                  hint: const Text('Selecione um calendário disponível'),
                  isExpanded: true,
                  items: googleCalendars.where((c) => !c.isReadOnly).map((c) {
                    return DropdownMenuItem<String>(
                      value: c.id,
                      child: Text(c.name),
                    );
                  }).toList(),
                  onChanged: (_) {},
                );
              },
            ),
          ),
        ),
      );

      // Não deve lançar Assertion failed
      expect(tester.takeException(), isNull);
      expect(find.text('Agenda Principal (vanessa@gmail.com)'), findsOneWidget);
    });

    testWidgets('DropdownButtonFormField renderiza com hint e sem erro quando selectedId é nulo ou inexistente', (tester) async {
      final googleCalendars = [
        ExternalCalendarItem(
          id: 'conta@gmail.com',
          name: 'Minha Agenda',
          isPrimary: false,
          isReadOnly: false,
        ),
      ];

      const String nonExistentId = 'calendario_inexistente';
      final safeSelectedId = resolveCalendarSelection(
        googleCalendars.where((c) => !c.isReadOnly).toList(),
        nonExistentId,
        google: true,
      );

      expect(safeSelectedId, isNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DropdownButtonFormField<String>(
              key: ValueKey('google-${safeSelectedId ?? "none"}'),
              initialValue: googleCalendars
                      .where((c) => !c.isReadOnly)
                      .any((c) => c.id == safeSelectedId)
                  ? safeSelectedId
                  : null,
              hint: const Text('Selecione um calendário disponível'),
              isExpanded: true,
              items: googleCalendars.where((c) => !c.isReadOnly).map((c) {
                return DropdownMenuItem<String>(
                  value: c.id,
                  child: Text(c.name),
                );
              }).toList(),
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Selecione um calendário disponível'), findsOneWidget);
    });
  });
}
