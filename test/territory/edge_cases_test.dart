import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/appointments/doorstep_proximity_engine.dart';
import 'package:ministerio_pessoal/territory/territory_data_port_service.dart';
import 'package:ministerio_pessoal/ticuna/services/multilingual_assistant_service.dart';

void main() {
  final baseDate = DateTime(2026, 11, 8, 10, 0); // Sunday

  group('DoorstepProximityEngine Edge Cases & Duplicates', () {
    test('DOORSTEP-01: No duplicate slots when preferredSchedule matches fallback Saturday 10h', () {
      final person = PersonEntry(
        id: 'target-1',
        name: 'Carlos Oliveira',
        firstContactAt: baseDate,
        status: 'interessado',
        tags: '[]',
        createdAt: baseDate,
        updatedAt: baseDate,
        revision: 1,
        preferredSchedule: 'Sábado de manhã',
      );

      final slots = DoorstepProximityEngine.suggestSlots(
        targetPerson: person,
        allPeople: [person],
        existingAppointments: [],
        referenceNow: baseDate,
      );

      // Verify that every slot has a unique startTime
      final startTimes = slots.map((s) => s.startTime).toSet();
      expect(startTimes.length, equals(slots.length),
          reason: 'All recommended slots must have distinct start times; no duplicate slots allowed');
    });

    test('DOORSTEP-02: Handles complex and irregular preferredSchedule strings', () {
      final person = PersonEntry(
        id: 'target-2',
        name: 'Maria Lima',
        firstContactAt: baseDate,
        status: 'revisita',
        tags: '[]',
        createdAt: baseDate,
        updatedAt: baseDate,
        revision: 1,
        preferredSchedule: 'quarta à tarde ou sábado de manhã',
      );

      final slots = DoorstepProximityEngine.suggestSlots(
        targetPerson: person,
        allPeople: [person],
        existingAppointments: [],
        referenceNow: baseDate,
      );

      expect(slots, isNotEmpty);
      final startTimes = slots.map((s) => s.startTime).toSet();
      expect(startTimes.length, equals(slots.length));
    });
  });

  group('TerritoryDataPortService Edge Cases & Malformed Inputs', () {
    test('DATA-PORT-01: Malformed GeoJSON should not crash with FormatException', () {
      expect(
        () => TerritoryDataPortService.importFromGeoJson('{ malformed json ::: '),
        returnsNormally,
      );
      final results = TerritoryDataPortService.importFromGeoJson('{ malformed json ::: ');
      expect(results, isEmpty);
    });

    test('DATA-PORT-02: KML with Placemark XML attributes parses properly', () {
      const kmlWithAttrs = '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <name>Exportação Google Earth</name>
    <Placemark id="place_101" class="ministerial">
      <name>João da Silva</name>
      <description>Endereço: Rua Central, 50
Telefone: 92988887777
Situação: revisita</description>
      <Point>
        <coordinates>-65.8500,-3.4200,0</coordinates>
      </Point>
    </Placemark>
    <Placemark id="place_102">
      <name>Elena Torres</name>
      <Point>
        <coordinates>-65.8510,-3.4210,0</coordinates>
      </Point>
    </Placemark>
  </Document>
</kml>''';

      final results = TerritoryDataPortService.importFromKml(kmlWithAttrs);
      expect(results.length, equals(2),
          reason: 'Placemark tags with attributes like id="..." must be correctly captured');
      expect(results.first.name, equals('João da Silva'));
      expect(results.first.phone, equals('92988887777'));
    });

    test('DATA-PORT-03: CSV with multi-line cells inside quotes preserves rows', () {
      const csvWithNewlines = '''Nome,Telefone,Endereço,Situação,Latitude,Longitude,Notas
"Roberto Rocha","97981112222","Rua Amazonas, 10
Bairro Novo","estudo",-3.425,-65.855,"Primeira linha de nota
Segunda linha de nota"
"Lucia Pereira","","Av. Brasil, 200","interessado",-3.426,-65.856,""''';

      final results = TerritoryDataPortService.importFromCsv(csvWithNewlines);
      expect(results.length, equals(2),
          reason: 'CSV with embedded newlines in quoted cells must yield exactly 2 records');
      expect(results.first.name, equals('Roberto Rocha'));
      expect(results.first.address, contains('Bairro Novo'));
      expect(results.first.notes, contains('Segunda linha'));
      expect(results.last.name, equals('Lucia Pereira'));
    });
  });

  group('MultilingualAssistantService SM-2 Edge Cases', () {
    test('SM2-01: Next interval is always at least 1 day for success (q >= 3)', () {
      final res = MultilingualAssistantService.calculateSm2(
        quality: 4,
        repetitions: 3,
        previousIntervalDays: 0,
        previousEasinessFactor: 2.5,
      );
      expect(res.nextIntervalDays, greaterThanOrEqualTo(1));
    });
  });
}
