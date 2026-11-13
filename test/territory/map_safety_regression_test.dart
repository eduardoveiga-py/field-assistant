import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/territory/mbtiles/mbtiles_native.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('geocodificação atrasada não sobrescreve endereço ou coordenadas editados', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = AppRepository(db);
    final person = await repo.createPerson(name: 'Pessoa', address: 'Rua antiga');
    await repo.updatePerson(person.copyWith(address: const drift.Value('Rua nova')));
    expect(await repo.applyGeocodedCoordinates(
      personId: person.id, expectedAddress: 'Rua antiga', latitude: -3, longitude: -60,
    ), isFalse);
    final edited = (await repo.getPersonById(person.id))!;
    expect(edited.address, 'Rua nova');
    expect(edited.latitude, isNull);
    await repo.updatePerson(edited.copyWith(
      latitude: const drift.Value(-4), longitude: const drift.Value(-61),
    ));
    expect(await repo.applyGeocodedCoordinates(
      personId: person.id, expectedAddress: 'Rua nova', latitude: -3, longitude: -60,
    ), isFalse);
    expect((await repo.getPersonById(person.id))!.latitude, -4);
  });

  test('MBTiles usa apenas o esquema declarado, sem trocar linha TMS por XYZ', () async {
    final dir = Directory.systemTemp.createTempSync('map_scheme_');
    final path = '${dir.path}/test.mbtiles';
    void create({required bool xyz}) {
      final db = sql.sqlite3.open(path);
      db.execute('CREATE TABLE metadata (name TEXT, value TEXT)');
      if (xyz) db.execute("INSERT INTO metadata VALUES ('scheme', 'xyz')");
      db.execute('CREATE TABLE tiles (zoom_level INTEGER, tile_column INTEGER, tile_row INTEGER, tile_data BLOB)');
      db.execute("INSERT INTO tiles VALUES (2, 1, 0, X'89504E470D0A1A0A')");
      db.close();
    }
    create(xyz: false);
    var backend = MBTilesNative(customDir: dir);
    await backend.init();
    expect(await backend.getTile(2, 1, 0), isNull); // TMS row 3 ausente
    expect(await backend.getTile(2, 1, 3), isNotNull);
    backend.dispose();
    File(path).deleteSync();
    create(xyz: true);
    backend = MBTilesNative(customDir: dir);
    await backend.init();
    expect(await backend.getTile(2, 1, 0), isNotNull);
    expect(await backend.getTile(2, 1, 3), isNull);
    backend.dispose();
    dir.deleteSync(recursive: true);
  });

  test('recupera pacote anterior quando a troca foi interrompida', () async {
    final dir = Directory.systemTemp.createTempSync('map_backup_');
    final path = '${dir.path}/test.mbtiles';
    final db = sql.sqlite3.open('$path.bak');
    db.execute('CREATE TABLE tiles (zoom_level INTEGER, tile_column INTEGER, tile_row INTEGER, tile_data BLOB)');
    db.execute("INSERT INTO tiles VALUES (2, 1, 3, X'89504E470D0A1A0A')");
    db.close();
    final backend = MBTilesNative(customDir: dir);
    await backend.init();
    expect(await backend.getTile(2, 1, 0), isNotNull);
    expect(File(path).existsSync(), isTrue);
    backend.dispose();
    dir.deleteSync(recursive: true);
  });
}
