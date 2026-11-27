import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/knowledge/note_cover_config.dart';
import 'package:ministerio_pessoal/reports/knowledge_and_email_pdf_service.dart';
import 'package:ministerio_pessoal/ui/widgets/knowledge/knowledge_ui_components.dart';

void main() {
  group('NoteCoverConfig & PDF Export with Cover', () {
    test('serializa e preserva propriedades existentes em propertiesJson sem perda', () {
      final existing = NoteCoverConfig.decodePropertiesMap(
        jsonEncode({'status': 'em_estudo', 'priority': 'alta'}),
      );
      const cover = NoteCoverConfig(presetId: 'aurora_indigo', iconId: 'bible');
      final merged = NoteCoverConfig.mergeCoverIntoPropertiesMap(
        existing,
        cover,
      );

      expect(merged['status'], equals('em_estudo'));
      expect(merged['priority'], equals('alta'));
      final decoded = NoteCoverConfig.fromPropertiesJson(jsonEncode(merged));
      expect(decoded, isNotNull);
      expect(decoded!.presetId, equals('aurora_indigo'));
      expect(decoded.iconId, equals('bible'));
      expect(decoded.resolvedPreset, isNotNull);
      expect(decoded.resolvedIconData, equals(Icons.menu_book_rounded));

      final cleared = NoteCoverConfig.mergeCoverIntoPropertiesMap(merged, null);
      expect(cleared.containsKey('cover'), isFalse);
      expect(cleared['status'], equals('em_estudo'));
    });

    test('compacta imagem de capa dentro do limite leve de 180KB', () async {
      final onePxPng = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
      );
      final encoded = await NoteCoverConfig.compressImageForCover(
        Uint8List.fromList(onePxPng),
      );
      expect(encoded, isNotNull);
      final raw = base64Decode(encoded!);
      expect(
        raw.lengthInBytes,
        lessThanOrEqualTo(NoteCoverConfig.maxCoverBytes),
      );
    });

    testWidgets(
      'KnowledgeNoteDetailPane renderiza banner de capa e acao de personalizar capa',
      (tester) async {
        var coverTapped = false;
        final now = DateTime(2026, 11, 26);
        final note = KnowledgeNoteEntry(
          id: 'note-cover-1',
          title: 'Esboço com Capa Personalizada',
          content: 'Texto principal da nota.',
          category: 'Pesquisa',
          tags: jsonEncode(['ministerio']),
          attachments: '[]',
          sources: '[]',
          isPinned: false,
          revision: 1,
          propertiesJson: jsonEncode({
            'status': 'rascunho',
            'cover': {'presetId': 'ocean_teal', 'iconId': 'auto_stories'},
          }),
          reviewLevel: 0,
          createdAt: now,
          updatedAt: now,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: KnowledgeNoteDetailPane(
                note: note,
                tags: const ['ministerio'],
                formattedDate: '26/11',
                isDark: true,
                onEdit: () {},
                onCustomizeCover: () => coverTapped = true,
                onExportPdf: () async {},
                onShare: () {},
                onTogglePin: () {},
                onTransformResearch: () {},
                onContentUpdated: (_) async {},
                onOpenLink: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Esboço com Capa Personalizada'), findsOneWidget);
        expect(
          find.byKey(const Key('btn_note_detail_customize_cover')),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const Key('btn_note_detail_customize_cover')),
        );
        await tester.pump();
        expect(coverTapped, isTrue);
      },
    );

    test('KnowledgeAndEmailPdfService gera PDF valido com capa gradiente e com foto personalizada', () async {
      final gradientPdf =
          await KnowledgeAndEmailPdfService.buildSingleItemPdfBytes(
            title: 'Nota com Capa Gradiente',
            content: 'Conteúdo completo para impressão.',
            itemType: 'Nota',
            category: 'Geral',
            tags: const ['estudo'],
            updatedAt: DateTime(2026, 11, 26),
            cover: const NoteCoverConfig(
              presetId: 'royal_purple',
              iconId: 'bible',
            ),
          );
      expect(gradientPdf.length, greaterThan(500));
      expect(utf8.decode(gradientPdf.take(5).toList()), equals('%PDF-'));

      const tinyPngB64 =
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';
      final photoPdf =
          await KnowledgeAndEmailPdfService.buildSingleItemPdfBytes(
            title: 'Nota com Foto de Capa',
            content: 'Conteúdo completo com banner fotográfico.',
            itemType: 'Nota',
            category: 'Pesquisa',
            updatedAt: DateTime(2026, 11, 26),
            cover: const NoteCoverConfig(
              presetId: 'aurora_indigo',
              imageBase64: tinyPngB64,
            ),
          );
      expect(photoPdf.length, greaterThan(500));
      expect(utf8.decode(photoPdf.take(5).toList()), equals('%PDF-'));
    });
  });
}
