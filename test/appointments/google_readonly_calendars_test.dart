import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/appointments/google_calendar_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Calendários de leitura são salvos e podem ser removidos', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final provider = GoogleCalendarProvider();
    expect(await provider.getReadOnlyCalendarIds(), isEmpty);
    await provider.setReadOnlyCalendarIds({'feriados', 'outro'});
    expect(await provider.getReadOnlyCalendarIds(), {'feriados', 'outro'});
    await provider.setReadOnlyCalendarIds({'feriados'});
    expect(await provider.getReadOnlyCalendarIds(), {'feriados'});
  });
}
