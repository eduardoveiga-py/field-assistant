import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/appointments/calendar_provider.dart';

void main() {
  test('Resolve o apelido primary para o calendário principal do Google', () {
    final calendars = [
      ExternalCalendarItem(id: 'conta@gmail.com', name: 'Principal', isPrimary: true),
      ExternalCalendarItem(id: 'outro', name: 'Outro'),
    ];
    expect(resolveCalendarSelection(calendars, 'primary', google: true), 'conta@gmail.com');
    expect(resolveCalendarSelection(calendars, 'outro', google: true), 'outro');
  });

  test('Não escolhe outro calendário quando a seleção salva não existe', () {
    final calendars = [ExternalCalendarItem(id: 'outro', name: 'Outro')];
    expect(resolveCalendarSelection(calendars, 'excluido', google: true), isNull);
    expect(resolveCalendarSelection(calendars, 'primary', google: true), isNull);
    expect(resolveCalendarSelection(calendars, null), isNull);
  });

  test('Remove IDs vazios e duplicados antes de construir o seletor', () {
    final calendars = uniqueCalendarItems([
      ExternalCalendarItem(id: 'a', name: 'A'),
      ExternalCalendarItem(id: 'a', name: 'Duplicado'),
      ExternalCalendarItem(id: '', name: 'Inválido'),
      ExternalCalendarItem(id: 'b', name: 'B'),
    ]);
    expect(calendars.map((calendar) => calendar.id), ['a', 'b']);
  });
}
