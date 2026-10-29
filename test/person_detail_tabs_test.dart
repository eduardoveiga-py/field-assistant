import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:ministerio_pessoal/core/date_utils.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';

void main() {
  group('Aba 3 & 4: Persistência de Necessidades, Alvos Espirituais e Horário Habitual', () {
    late AppDatabase db;
    late AppRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = AppRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('AppDateUtils.formatDateTimeWithAt formata com "às" no formato brasileiro', () {
      final dt = DateTime(2026, 10, 28, 14, 35);
      final formatted = AppDateUtils.formatDateTimeWithAt(dt);
      expect(formatted, equals('28/10/2026 às 14:35'));

      expect(AppDateUtils.formatDateTimeWithAt(null), isEmpty);
    });

    test('Persistência e parsing de Necessidades & Observações em generalNotes com data e hora exata', () async {
      final person = await repo.createPerson(
        name: 'Maria Madalena',
        phone: '11999998888',
        status: 'interessado',
      );

      final createdAt1 = DateTime(2026, 10, 28, 14, 35);
      final notes = [
        {
          'id': 'note-1',
          'text': 'Passou por cirurgia recente. Pediu oração e textos de encorajamento.',
          'createdAt': createdAt1.toIso8601String(),
        },
      ];

      // Salva no banco via repository
      await repo.updatePerson(person.copyWith(generalNotes: Value(jsonEncode(notes))));

      // Lê do banco e valida integridade estruturada
      final savedPerson = await repo.getPersonById(person.id);
      expect(savedPerson, isNotNull);
      expect(savedPerson!.generalNotes, isNotNull);

      final decoded = jsonDecode(savedPerson.generalNotes!) as List;
      expect(decoded.length, equals(1));
      expect(decoded[0]['text'], contains('Passou por cirurgia recente'));
      expect(decoded[0]['createdAt'], equals(createdAt1.toIso8601String()));

      final parsedDt = DateTime.parse(decoded[0]['createdAt'] as String);
      expect(AppDateUtils.formatDateTimeWithAt(parsedDt), equals('28/10/2026 às 14:35'));
    });

    test('Migração e compatibilidade reversa para notas e alvos em texto puro legado ou primitivos', () {
      List<Map<String, dynamic>> parseNotes(String? raw) {
        if (raw == null) return [];
        final trimmed = raw.trim();
        if (trimmed.isEmpty || trimmed == '[]') return [];
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is List) {
            if (decoded.isEmpty) return [];
            final list = <Map<String, dynamic>>[];
            for (final item in decoded) {
              if (item is Map) {
                list.add(Map<String, dynamic>.from(item));
              }
            }
            if (list.isNotEmpty) return list;
          }
        } catch (_) {}

        return [
          {
            'id': 'legacy-note',
            'text': trimmed,
            'createdAt': DateTime(2026, 10, 28, 10, 0).toIso8601String(),
          }
        ];
      }

      // 1. Texto puro normal
      final parsedText = parseNotes('Anotação simples legada sem formatação JSON');
      expect(parsedText.length, equals(1));
      expect(parsedText[0]['text'], equals('Anotação simples legada sem formatação JSON'));
      expect(parsedText[0]['id'], equals('legacy-note'));

      // 2. Primitivo número que não deve sumir (ex: "123")
      final parsedNumber = parseNotes('123');
      expect(parsedNumber.length, equals(1));
      expect(parsedNumber[0]['text'], equals('123'));

      // 3. Primitivo booleano que não deve sumir (ex: "true")
      final parsedBool = parseNotes('true');
      expect(parsedBool.length, equals(1));
      expect(parsedBool[0]['text'], equals('true'));

      // 4. Lista vazia '[]' deve retornar vazia sem criar legacy note fantasma
      expect(parseNotes('[]'), isEmpty);
      expect(parseNotes('  []  '), isEmpty);
      expect(parseNotes(''), isEmpty);
      expect(parseNotes(null), isEmpty);

      // 5. Lista com tipos corrompidos não-Map deve fazer fallback para legacy
      final parsedCorrupt = parseNotes('[1, 2, 3]');
      expect(parsedCorrupt.length, equals(1));
      expect(parsedCorrupt[0]['text'], equals('[1, 2, 3]'));
    });

    test('Persistência e ciclo de vida de Alvos & Tarefas em contactRestrictions (Checkbox, Criado em, Concluído em)', () async {
      final person = await repo.createPerson(
        name: 'Roberto Souza',
        status: 'revisita',
      );

      final createdTime = DateTime(2026, 10, 28, 15, 0);
      final targets = [
        {
          'id': 'target-1',
          'title': 'Ler o capítulo 1 de João até terça-feira',
          'isCompleted': false,
          'createdAt': createdTime.toIso8601String(),
          'completedAt': null,
        },
      ];

      // Salva alvo pendente
      await repo.updatePerson(person.copyWith(contactRestrictions: Value(jsonEncode(targets))));

      var current = await repo.getPersonById(person.id);
      var currentTargets = (jsonDecode(current!.contactRestrictions!) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      expect(currentTargets.first['isCompleted'], isFalse);
      expect(currentTargets.first['completedAt'], isNull);

      // Marca como Concluído
      final completedTime = DateTime(2026, 10, 28, 16, 30);
      currentTargets[0]['isCompleted'] = true;
      currentTargets[0]['completedAt'] = completedTime.toIso8601String();

      await repo.updatePerson(current.copyWith(contactRestrictions: Value(jsonEncode(currentTargets))));

      // Valida que foi salvo como concluído com data e hora
      final finished = await repo.getPersonById(person.id);
      final finishedTargets = (jsonDecode(finished!.contactRestrictions!) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      expect(finishedTargets.first['isCompleted'], isTrue);
      expect(finishedTargets.first['completedAt'], equals(completedTime.toIso8601String()));
      expect(
        AppDateUtils.formatDateTimeWithAt(DateTime.parse(finishedTargets.first['completedAt'] as String)),
        equals('28/10/2026 às 16:30'),
      );
    });

    test('Persistência de Horário Habitual específico (ex: "Sábado às 09:00")', () async {
      final person = await repo.createPerson(
        name: 'Ana Carolina',
        status: 'estudo',
      );

      const habitualSchedule = 'Sábado às 09:00';
      await repo.updatePerson(person.copyWith(preferredSchedule: const Value(habitualSchedule)));

      final updated = await repo.getPersonById(person.id);
      expect(updated!.preferredSchedule, equals('Sábado às 09:00'));
    });

    test('Lógica de Throttle e Clamping do Zoom por Roda do Mouse (PointerScrollEvent)', () {
      int zoom = 15;
      DateTime? lastZoomChangeTime;

      bool handleScroll(double deltaY, DateTime now) {
        if (lastZoomChangeTime == null || now.difference(lastZoomChangeTime!).inMilliseconds > 200) {
          lastZoomChangeTime = now;
          if (deltaY < 0 && zoom < 18) {
            zoom++;
            return true;
          } else if (deltaY > 0 && zoom > 12) {
            zoom--;
            return true;
          }
        }
        return false;
      }

      final t0 = DateTime(2026, 10, 28, 12, 0, 0, 0);

      // 1. Scroll Up aproxima o zoom
      expect(handleScroll(-10.0, t0), isTrue);
      expect(zoom, equals(16));

      // 2. Scroll imediato (<200ms) é bloqueado pelo throttle
      final t1 = t0.add(const Duration(milliseconds: 50));
      expect(handleScroll(-10.0, t1), isFalse);
      expect(zoom, equals(16));

      // 3. Scroll após 250ms é aceito
      final t2 = t0.add(const Duration(milliseconds: 250));
      expect(handleScroll(-10.0, t2), isTrue);
      expect(zoom, equals(17));

      // 4. Chegando a 18 (limite máximo), scroll adicional é limitado (clamped)
      final t3 = t0.add(const Duration(milliseconds: 500));
      expect(handleScroll(-10.0, t3), isTrue);
      expect(zoom, equals(18));

      final t4 = t0.add(const Duration(milliseconds: 750));
      expect(handleScroll(-10.0, t4), isFalse);
      expect(zoom, equals(18)); // Não ultrapassa 18

      // 5. Scroll Down diminui zoom respeitando limite mínimo 12
      final t5 = t0.add(const Duration(milliseconds: 1000));
      expect(handleScroll(10.0, t5), isTrue);
      expect(zoom, equals(17));
    });
  });
}
