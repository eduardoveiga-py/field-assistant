import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/core/sync_timestamp.dart';

void main() {
  group('SyncTimestamp Contract & Resiliency Tests (C4)', () {
    test('Interpreta instâncias DateTime mantendo UTC', () {
      final now = DateTime.utc(2026, 11, 8, 20, 30, 0);
      expect(SyncTimestamp.parse(now), equals(now));
      expect(SyncTimestamp.toIso8601String(now), equals('2026-11-08T20:30:00.000Z'));
    });

    test('Interpreta inteiros em milissegundos da época', () {
      const millis = 1731112233000;
      final parsed = SyncTimestamp.parse(millis);
      expect(parsed, isNotNull);
      expect(parsed!.millisecondsSinceEpoch, equals(millis));
      expect(parsed.isUtc, isTrue);
    });

    test('Interpreta inteiros em segundos da época', () {
      const seconds = 1731112233;
      final parsed = SyncTimestamp.parse(seconds);
      expect(parsed, isNotNull);
      expect(parsed!.millisecondsSinceEpoch, equals(seconds * 1000));
    });

    test('Interpreta strings com milissegundos numéricos (eliminando falha de DateTime.tryParse)', () {
      const raw = '1731112233000';
      // DateTime.tryParse tradicional falharia retornando null:
      expect(DateTime.tryParse(raw), isNull);

      // SyncTimestamp interpreta com perfeição:
      final parsed = SyncTimestamp.parse(raw);
      expect(parsed, isNotNull);
      expect(parsed!.millisecondsSinceEpoch, equals(1731112233000));
    });

    test('Interpreta strings com ISO-8601 válidos', () {
      const iso = '2026-11-08T18:45:30.123Z';
      final parsed = SyncTimestamp.parse(iso);
      expect(parsed, isNotNull);
      expect(parsed!.toIso8601String(), equals(iso));
    });

    test('Retorna nulo para valores vazios, inválidos ou nulos sem lançar exceções', () {
      expect(SyncTimestamp.parse(null), isNull);
      expect(SyncTimestamp.parse(''), isNull);
      expect(SyncTimestamp.parse('   '), isNull);
      expect(SyncTimestamp.parse('não-data'), isNull);
      expect(SyncTimestamp.toIso8601String(null), isNull);
      expect(SyncTimestamp.toIso8601String('invalido'), isNull);
    });
  });
}
