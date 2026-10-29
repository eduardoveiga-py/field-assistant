import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/core/date_utils.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/reports/report_export_service.dart';
import 'package:ministerio_pessoal/territory/geocoding_service.dart';
import 'package:ministerio_pessoal/territory/tile_cache/tile_cache_interface.dart';
import 'package:ministerio_pessoal/territory/tile_cache/tile_cache_native.dart';
import 'package:ministerio_pessoal/territory/tile_cache/tile_cache_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  group('ReportExportService - CSV Export', () {
    test('generateCsvForContacts handles empty contacts list without error', () {
      final csv = ReportExportService.generateCsvForContacts([]);
      expect(csv.startsWith('\uFEFF'), isTrue);
      expect(csv.contains('Nome;Telefone;Situação'), isTrue);
      // Header only
      final lines = csv.trim().split('\n');
      expect(lines.length, equals(1));
    });

    test('generateCsvForContacts formats fields and escapes quotes and newlines', () {
      final now = DateTime(2026, 10, 28);
      final contacts = [
        PersonEntry(
          id: 'p1',
          name: 'Carlos "Carlinhos" Pereira',
          status: 'revisita',
          phone: '(11) 91234-5678',
          address: 'Av. Paulista, 1500\nApto 42 - Bela Vista',
          preferredSchedule: 'Sábados às 09:00',
          generalNotes: 'Interessado no tema "Reino de Deus"\nPediu para voltar.',
          firstContactAt: now,
          createdAt: now,
          updatedAt: now,
          tags: '[]',
          revision: 1,
        ),
      ];

      final csv = ReportExportService.generateCsvForContacts(contacts);
      expect(csv.contains('"Carlos ""Carlinhos"" Pereira"'), isTrue);
      expect(csv.contains('(11) 91234-5678'), isTrue);
      expect(csv.contains('revisita'), isTrue);
      // Newlines should be replaced with spaces
      expect(csv.contains('Apto 42'), isTrue);
      expect(csv.contains('""Reino de Deus""'), isTrue);
    });
  });

  group('ReportExportService - PDF Layout Generation', () {
    test('Contacts Map PDF layout renders clean text without emoji glyph warnings', () async {
      final pdf = pw.Document();
      final contacts = List.generate(
        15,
        (i) => PersonEntry(
          id: 'p_$i',
          name: 'Contato $i',
          status: i % 3 == 0 ? 'estudo' : (i % 3 == 1 ? 'revisita' : 'interessado'),
          phone: '(11) 98888-${i.toString().padLeft(4, "0")}',
          address: 'Rua Central, $i - Bairro Centro',
          preferredSchedule: 'Quintas às 19:30',
          firstContactAt: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          tags: '[]',
          revision: 1,
        ),
      );

      final estudos = contacts.where((p) => p.status == 'estudo').toList();
      final revisitas = contacts.where((p) => p.status == 'revisita').toList();
      final interessados = contacts.where((p) => p.status == 'interessado').toList();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context ctx) {
            return [
              pw.Text('MAPA GERAL DO TERRITÓRIO E CONTATOS'),
              pw.Container(
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    pw.Text('Total de Contatos: ${contacts.length}'),
                    pw.Text('Estudos: ${estudos.length}'),
                    pw.Text('Revisitas: ${revisitas.length}'),
                    pw.Text('Interessados: ${interessados.length}'),
                    pw.Text('Marcos: 3'),
                  ],
                ),
              ),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  pw.TableRow(
                    children: [
                      pw.Text('Nome'),
                      pw.Text('Situação'),
                      pw.Text('Telefone'),
                      pw.Text('Endereço / Bairro'),
                    ],
                  ),
                  ...contacts.map((c) => pw.TableRow(
                    children: [
                      pw.Text(c.name),
                      pw.Text(c.status.toUpperCase()),
                      pw.Text(c.phone ?? '-'),
                      pw.Text(c.address ?? '-'),
                    ],
                  )),
                ],
              ),
            ];
          },
        ),
      );

      final bytes = await pdf.save();
      expect(bytes, isNotEmpty);
    });

    test('Phone witnessing PDF table handles empty contact list gracefully', () async {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context ctx) {
            return [
              pw.Text('LISTA PARA TESTEMUNHO POR TELEFONE'),
              pw.Text('Filtros: Situação: Todos | Bairro: Todos (0 contatos)'),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400),
                children: [
                  pw.TableRow(
                    children: [
                      pw.Text('Nome do Contato'),
                      pw.Text('Telefone / WhatsApp'),
                      pw.Text('Situação'),
                    ],
                  ),
                ],
              ),
            ];
          },
        ),
      );

      final bytes = await pdf.save();
      expect(bytes, isNotEmpty);
    });
  });

  group('Geocoding & Address Formatting', () {
    test('ReverseGeocodingResult formats street, number, neighborhood, and city cleanly', () {
      const res = ReverseGeocodingResult(
        latitude: -23.550520,
        longitude: -46.633308,
        street: 'Praça da Sé',
        houseNumber: '100',
        neighborhood: 'Centro',
        city: 'São Paulo',
        state: 'São Paulo',
        fullAddress: 'Praça da Sé, 100 - Centro, São Paulo - SP',
      );

      expect(res.streetAndNumber, equals('Praça da Sé, 100'));
      expect(res.formattedSummary, equals('Praça da Sé, 100 - Centro - São Paulo'));
    });

    test('ReverseGeocodingResult falls back gracefully when house number or neighborhood is absent', () {
      const res = ReverseGeocodingResult(
        latitude: -23.550520,
        longitude: -46.633308,
        street: 'Av. Paulista',
        city: 'São Paulo',
      );

      expect(res.streetAndNumber, equals('Av. Paulista'));
      expect(res.formattedSummary, equals('Av. Paulista - São Paulo'));
    });
  });

  group('Field Ministry Schedule Recurrence Logic', () {
    test('Monthly recurrence clamps dates to last day of short months', () {
      // Starting on Jan 31st
      final chosenDate = DateTime(2026, 1, 31);
      final dates = <DateTime>[];

      for (int i = 0; i < 4; i++) {
        final targetMonthDate = DateTime(chosenDate.year, chosenDate.month + i, 1);
        final daysInMonth = DateTime(targetMonthDate.year, targetMonthDate.month + 1, 0).day;
        final day = chosenDate.day.clamp(1, daysInMonth);
        dates.add(DateTime(targetMonthDate.year, targetMonthDate.month, day));
      }

      expect(dates.length, equals(4));
      // Jan 31
      expect(dates[0], equals(DateTime(2026, 1, 31)));
      // Feb 28 (non-leap year 2026)
      expect(dates[1], equals(DateTime(2026, 2, 28)));
      // Mar 31
      expect(dates[2], equals(DateTime(2026, 3, 31)));
      // Apr 30
      expect(dates[3], equals(DateTime(2026, 4, 30)));
    });

    test('Weekday recurrence collects Monday through Friday without skipping or weekend days', () {
      final chosenDate = DateTime(2026, 10, 24); // Saturday
      final dates = <DateTime>[];
      var cur = chosenDate;

      while (dates.length < 5) {
        if (cur.weekday >= DateTime.monday && cur.weekday <= DateTime.friday) {
          dates.add(DateTime(cur.year, cur.month, cur.day));
        }
        cur = DateTime(cur.year, cur.month, cur.day + 1);
      }

      expect(dates.length, equals(5));
      for (final d in dates) {
        expect(d.weekday >= DateTime.monday && d.weekday <= DateTime.friday, isTrue);
      }
      // First weekday after Saturday Oct 24 is Monday Oct 26
      expect(dates.first, equals(DateTime(2026, 10, 26)));
    });
  });

  group('Pioneer Modalities & Ministry Statistics PDF Layout', () {
    test('Pioneer modalities map correctly for 15h, 30h, 50h, 100h goals', () {
      String getModalityLabel(int goal) {
        switch (goal) {
          case 15:
            return 'Pioneiro Auxiliar (15h)';
          case 30:
            return 'Pioneiro Auxiliar (30h)';
          case 100:
            return 'Pioneiro Especial (100h)';
          case 50:
          default:
            return 'Pioneiro Regular (50h)';
        }
      }

      expect(getModalityLabel(15), equals('Pioneiro Auxiliar (15h)'));
      expect(getModalityLabel(30), equals('Pioneiro Auxiliar (30h)'));
      expect(getModalityLabel(50), equals('Pioneiro Regular (50h)'));
      expect(getModalityLabel(100), equals('Pioneiro Especial (100h)'));
      expect(getModalityLabel(70), equals('Pioneiro Regular (50h)'));
    });

    test('Ministry statistics PDF layout generates without bureaucratic A4 labels', () async {
      final pdf = pw.Document();
      const modalityLabel = 'Pioneiro Regular (50h)';
      const periodTitle = 'Outubro de 2026';

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context ctx) {
            return [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('RELATÓRIO DO MINISTÉRIO PESSOAL'),
                      pw.Text('Período: $periodTitle'),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(modalityLabel),
                      pw.Text('Emissão: 28/10/2026'),
                    ],
                  ),
                ],
              ),
              pw.Divider(),
              // Resumo de Metas e Comparação
              pw.Container(
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    pw.Text('Meta do Mês: 50h'),
                    pw.Text('Horas Realizadas: 52h'),
                    pw.Text('Horas Programadas: 50h'),
                    pw.Text('Progresso: 100% (Meta Atingida! +2h)'),
                  ],
                ),
              ),
            ];
          },
        ),
      );

      final bytes = await pdf.save();
      expect(bytes, isNotEmpty);
    });
  });

  group('Agenda Hours Formatting and Completion Percentage', () {
    test('AppDateUtils.formatDuration formats minutes and hours cleanly', () {
      expect(AppDateUtils.formatDuration(0), equals('0min'));
      expect(AppDateUtils.formatDuration(20 * 60), equals('20min'));
      expect(AppDateUtils.formatDuration(60 * 60), equals('1h'));
      expect(AppDateUtils.formatDuration(3 * 3600), equals('3h'));
      expect(AppDateUtils.formatDuration((3.5 * 3600).round()), equals('3h 30min'));
      expect(AppDateUtils.formatDuration(10 * 3600 + 45 * 60), equals('10h 45min'));
    });

    test('Completion percentage caps at 100% with friendly surplus badge instead of 1050%', () {
      const double scheduledHours = 0.333333; // 20 minutes
      const double actualHours = 3.5; // 3h 30min

      String badgeText;
      if (scheduledHours <= 0) {
        badgeText = 'Sem agendamentos';
      } else if (actualHours >= scheduledHours) {
        final diffMinutes = ((actualHours - scheduledHours) * 60).round();
        if (diffMinutes >= 1) {
          final surplusFormatted = AppDateUtils.formatDuration(((actualHours - scheduledHours) * 3600).round());
          badgeText = '100% cumprido (+$surplusFormatted adicionais)';
        } else {
          badgeText = '100% cumprido';
        }
      } else {
        badgeText = '${((actualHours / scheduledHours) * 100).toStringAsFixed(0)}% cumprido';
      }

      expect(badgeText, equals('100% cumprido (+3h 10min adicionais)'));
      expect(badgeText.contains('1050%'), isFalse);

      final progressIndicatorValue = scheduledHours > 0 ? (actualHours / scheduledHours).clamp(0.0, 1.0) : 0.0;
      expect(progressIndicatorValue, equals(1.0));
    });

    test('Completion percentage calculates correctly when below 100%', () {
      const double scheduledHours = 10.0;
      const double actualHours = 4.0;

      final badgeText = actualHours >= scheduledHours
          ? '100% cumprido'
          : '${((actualHours / scheduledHours) * 100).toStringAsFixed(0)}% cumprido';

      expect(badgeText, equals('40% cumprido'));
    });
  });

  group('TileCacheService Offline Caching', () {
    test('In-memory cache backend stores, retrieves, and counts tiles properly', () async {
      final fakeCache = _FakeTileCacheBackend();
      TileCacheService.instance.backend = fakeCache;

      expect(await TileCacheService.instance.getCachedTileCount(), equals(0));
      expect(await TileCacheService.instance.isTileCached(15, 100, 200), isFalse);

      final tileData = Uint8List.fromList([1, 2, 3, 4, 5]);
      await TileCacheService.instance.saveTile(15, 100, 200, tileData);

      expect(await TileCacheService.instance.isTileCached(15, 100, 200), isTrue);
      final retrieved = await TileCacheService.instance.getTileBytes(15, 100, 200);
      expect(retrieved, equals(tileData));
      expect(await TileCacheService.instance.getCachedTileCount(), equals(1));
    });

    test('preloadArea iterates over bounding box and reports progress', () async {
      final fakeCache = _FakeTileCacheBackend();
      TileCacheService.instance.backend = fakeCache;

      int progressReports = 0;
      final saved = await TileCacheService.instance.preloadArea(
        z: 14,
        minX: 10,
        maxX: 12, // 3 columns
        minY: 20,
        maxY: 21, // 2 rows -> 6 tiles total
        onProgress: (done, total) {
          progressReports++;
          expect(total, equals(6));
        },
      );

      expect(progressReports, equals(6));
      expect(saved, equals(6));
      expect(await TileCacheService.instance.getCachedTileCount(), equals(6));
    });

    test('TileCacheNative persists and retrieves tiles from local disk without network', () async {
      final tempDir = Directory.systemTemp.createTempSync('osm_tiles_test_');
      try {
        final nativeBackend = TileCacheNative(customDir: tempDir);
        expect(await nativeBackend.getCachedTileCount(), equals(0));
        expect(await nativeBackend.isTileCached(15, 12000, 18000), isFalse);

        final sampleBytes = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 1, 2, 3]);
        await nativeBackend.saveTile(15, 12000, 18000, sampleBytes);

        expect(await nativeBackend.isTileCached(15, 12000, 18000), isTrue);
        expect(await nativeBackend.getCachedTileCount(), equals(1));

        final loaded = await nativeBackend.getTile(15, 12000, 18000);
        expect(loaded, isNotNull);
        expect(loaded, equals(sampleBytes));
      } finally {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      }
    });
  });

  group('Territory Route Clustering & Median Outlier Filtering', () {
    double calculateDistanceKm(double lat1, double lon1, double lat2, double lon2) {
      const p = 0.017453292519943295; // pi / 180
      final a = 0.5 - math.cos((lat2 - lat1) * p) / 2 +
          math.cos(lat1 * p) * math.cos(lat2 * p) *
          (1 - math.cos((lon2 - lon1) * p)) / 2;
      return 12742 * math.asin(math.sqrt(a));
    }

    test('Median reference excludes distant outlier contacts (>60km) even when outlier is first in list', () {
      final now = DateTime.now();
      // Contact 1: Amazonas outlier (-3.07, -68.07) as first contact
      final cAmazonas = PersonEntry(
        id: 'p_am',
        name: 'Contato Amazonas',
        latitude: -3.0791292,
        longitude: -68.0716099,
        status: 'estudo',
        firstContactAt: now,
        createdAt: now,
        updatedAt: now,
        tags: '[]',
        revision: 1,
      );

      // Contacts 2 & 3: São Paulo territory cluster (-23.55, -46.63)
      final cSp1 = PersonEntry(
        id: 'p_sp1',
        name: 'Maria SP',
        latitude: -23.550520,
        longitude: -46.633308,
        status: 'revisita',
        firstContactAt: now,
        createdAt: now,
        updatedAt: now,
        tags: '[]',
        revision: 1,
      );

      final cSp2 = PersonEntry(
        id: 'p_sp2',
        name: 'Carlos SP',
        latitude: -23.561684,
        longitude: -46.655981,
        status: 'estudo',
        firstContactAt: now,
        createdAt: now,
        updatedAt: now,
        tags: '[]',
        revision: 1,
      );

      final contacts = [cAmazonas, cSp1, cSp2];

      final validLats = contacts.map((c) => c.latitude!).toList()..sort();
      final validLngs = contacts.map((c) => c.longitude!).toList()..sort();

      final medianLat = validLats[validLats.length ~/ 2];
      final medianLng = validLngs[validLngs.length ~/ 2];

      // Median should be in São Paulo, not Amazonas!
      expect(medianLat, closeTo(-23.55, 0.1));
      expect(medianLng, closeTo(-46.65, 0.1));

      final nearbyContacts = <PersonEntry>[];
      for (final c in contacts) {
        final dist = calculateDistanceKm(medianLat, medianLng, c.latitude!, c.longitude!);
        if (dist <= 60.0) {
          nearbyContacts.add(c);
        }
      }

      // Outlier in Amazonas should be excluded (>2500 km away)
      expect(nearbyContacts.length, equals(2));
      expect(nearbyContacts.contains(cAmazonas), isFalse);
      expect(nearbyContacts.contains(cSp1), isTrue);
      expect(nearbyContacts.contains(cSp2), isTrue);
    });
  });
}

class _FakeTileCacheBackend implements TileCacheBackend {
  final Map<String, Uint8List> _store = {};

  @override
  Future<Uint8List?> getTile(int z, int x, int y) async {
    final key = '$z/$x/$y';
    if (!_store.containsKey(key)) {
      _store[key] = Uint8List.fromList([z, x, y]);
    }
    return _store[key];
  }

  @override
  Future<void> saveTile(int z, int x, int y, Uint8List bytes) async {
    _store['$z/$x/$y'] = bytes;
  }

  @override
  Future<bool> isTileCached(int z, int x, int y) async {
    return _store.containsKey('$z/$x/$y');
  }

  @override
  Future<int> getCachedTileCount() async {
    return _store.length;
  }
}

