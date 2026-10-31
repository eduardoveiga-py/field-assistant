import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/settings/app_settings_manager.dart';

void main() {
  test('AppSettingsManager can set and get values without hanging', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final settings = AppSettingsManager(db);

    await settings.setString('test_key', 'test_value');
    final val = await settings.getString('test_key');
    expect(val, equals('test_value'));

    await db.close();
  });
}
