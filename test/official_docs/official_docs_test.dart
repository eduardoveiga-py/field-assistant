import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ministerio_pessoal/core/feature_registry.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/knowledge/knowledge_manager.dart';
import 'package:ministerio_pessoal/official_docs/official_doc_docx_generator.dart';
import 'package:ministerio_pessoal/official_docs/official_doc_fonts.dart';
import 'package:ministerio_pessoal/official_docs/official_doc_manager.dart';
import 'package:ministerio_pessoal/official_docs/official_doc_models.dart';
import 'package:ministerio_pessoal/official_docs/official_doc_pdf_generator.dart';
import 'package:ministerio_pessoal/official_docs/official_doc_presets.dart';
import 'package:ministerio_pessoal/official_docs/official_markup_parser.dart';
import 'package:ministerio_pessoal/settings/app_settings_manager.dart';
import 'package:ministerio_pessoal/ui/providers.dart';
import 'package:ministerio_pessoal/ui/screens/knowledge_base_screen.dart';
import 'package:ministerio_pessoal/ui/screens/official_documents_screen.dart';
import 'package:ministerio_pessoal/ui/widgets/official_docs/official_doc_preview_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // PNG válido 1x1 transparente sintético para testar assinaturas desenhadas em PDF e DOCX
  const String synthetic1x1PngBase64 =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

  group('OfficialDocFonts & OfficialMarkupParser', () {
    test('Mantém fontes padrão do PDF original e normaliza aliases', () {
      const spec = OfficialFontSpec();
      expect(spec.headerFontId, 'pt_sans');
      expect(spec.metaFontId, 'pt_sans');
      expect(spec.bodyFontId, 'pt_serif');
      expect(spec.signatureFontId, 'sacramento');
      expect(spec.bodyFontSizePt, 10.0);

      expect(OfficialDocFonts.textFonts.length, 5);
      expect(OfficialDocFonts.signatureFonts.length, 5);
      expect(OfficialDocFonts.normalizeFontId('Pristina'), 'sacramento');
      expect(OfficialDocFonts.normalizeFontId('Lora'), 'pt_serif');
      expect(OfficialDocFonts.normalizeFontId('Carlito'), 'lato');

      final compat = OfficialFontSpec.fromJson({
        'headerFontFamily': 'Caladea',
        'metaFontFamily': 'Lato',
        'bodyFontFamily': 'Crimson Text',
        'signatureFontFamily': 'Great Vibes',
        'bodyFontSizePt': 11.5,
        'justifyBody': true,
      });
      expect(compat.headerFontId, 'caladea');
      expect(compat.metaFontId, 'lato');
      expect(compat.bodyFontId, 'crimson_text');
      expect(compat.signatureFontId, 'great_vibes');
      expect(compat.bodyFontSizePt, 11.5);
      expect(compat.justifyBody, isTrue);
    });

    test('Parser limpa links app:// e preserva estilos inline e blocos', () {
      const markup =
          '## Decisões da Reunião\n'
          'Considere **atenção especial** para [João 13:34, 35](app://bible/43/13/34) e *amor cristão* com <u>prazo</u> ~~antigo~~.\n'
          '- Primeiro tópico\n'
          '1. Item numerado\n'
          '> Nota citada';

      final blocks = OfficialMarkupParser.parseBlocks(markup);
      expect(blocks.length, 5);
      expect(blocks[0].kind, OfficialBlockKind.heading);
      expect(blocks[0].headingLevel, 2);

      final paraText = blocks[1].plainText;
      expect(paraText, contains('João 13:34, 35'));
      expect(paraText, isNot(contains('app://')));
      expect(
        blocks[1].runs.any((r) => r.bold && r.text == 'atenção especial'),
        isTrue,
      );
      expect(
        blocks[1].runs.any((r) => r.italic && r.text == 'amor cristão'),
        isTrue,
      );
      expect(
        blocks[1].runs.any((r) => r.underline && r.text == 'prazo'),
        isTrue,
      );
      expect(
        blocks[1].runs.any((r) => r.strikethrough && r.text == 'antigo'),
        isTrue,
      );
      expect(blocks[2].kind, OfficialBlockKind.bulletItem);
      expect(blocks[3].kind, OfficialBlockKind.numberedItem);
      expect(blocks[4].kind, OfficialBlockKind.quote);
    });
  });

  group('Exportação Offline PDF & DOCX (todos os 7 estilos)', () {
    const header = OfficialHeaderProfile(
      id: 'hdr-synth',
      label: 'Congregação Sintética',
      topSubtitle: 'CONGREGAÇÃO EXEMPLO NORTE (999001)',
      mainTitle: 'Cidade Exemplo - SP',
      addressLine1: 'Rua das Acácias, 100 · Centro',
      addressLine2: 'CEP 01000-000 · Cidade Exemplo - SP',
      contactEmail: 'cong999001@jwpub.org',
      footerNote: 'Secretaria da Congregação · Documento interno',
      showPageNumbers: true,
    );

    final signers = [
      const SignerSlot(
        elderId: 'elder-1',
        name: 'Carlos Silva',
        role: 'Coordenador',
        signatureFontIdOverride: 'sacramento',
      ),
      const SignerSlot(
        elderId: 'elder-2',
        name: 'Marcos Souza',
        role: 'Secretário',
        signatureFontIdOverride: 'courgette',
        signaturePngBase64Override: synthetic1x1PngBase64,
      ),
      const SignerSlot(
        elderId: 'elder-3',
        name: 'André Lima',
        role: 'Sup. de Serviço',
        signatureFontIdOverride: 'great_vibes',
      ),
    ];

    OfficialDocumentRecord buildDoc(
      String styleId, {
      bool includeHeader = true,
      bool includeSignature = true,
      OfficialDocType docType = OfficialDocType.presentationLetter,
    }) {
      final now = DateTime(2026, 11, 25);
      return OfficialDocumentRecord(
        id: 'doc-$styleId',
        title: 'Carta de Apresentação Teste',
        docType: docType,
        layoutStyleId: styleId,
        headerProfileId: header.id,
        includeHeader: includeHeader,
        includeSignature: includeSignature,
        fontSpec: const OfficialFontSpec(justifyBody: true),
        locationDate: 'Cidade Exemplo - SP, 25 de novembro de 2026',
        referenceSubject: 'Carta de apresentação',
        recipientLine: 'Corpo de Anciãos da Congregação Destino',
        bodyMarkup:
            '*Queridos Irmãos,*\n\n'
            'Escrevemos sobre **irmão exemplo** conforme [Romanos 16:1, 2](app://bible/45/16/1).\n\n'
            'Seus irmãos e amigos,',
        createdAt: now,
        updatedAt: now,
      );
    }

    test('Gera PDF válido (%PDF-) para todos os 7 estilos visuais + sem cabeçalho/assinatura', () async {
      expect(OfficialDocLayoutStyle.values.length, 7);
      expect(
        OfficialDocLayoutStyle.values.first,
        OfficialDocLayoutStyle.original,
      );

      for (final style in OfficialDocLayoutStyle.values) {
        final pdfBytes = await OfficialDocPdfGenerator.generatePdfBytes(
          doc: buildDoc(style.id),
          header: header,
          signatureGroupTitle: 'A Comissão de Serviço',
          signers: signers,
        );
        expect(
          pdfBytes.length,
          greaterThan(500),
          reason: 'PDF vazio em ${style.id}',
        );
        expect(
          utf8.decode(pdfBytes.take(5).toList(), allowMalformed: true),
          startsWith('%PDF-'),
          reason: 'Cabeçalho %PDF ausente em ${style.id}',
        );
      }

      // Modo sem cabeçalho e sem assinatura (pauta interna)
      final minimalPdf = await OfficialDocPdfGenerator.generatePdfBytes(
        doc: buildDoc(
          'contemporary_panel',
          includeHeader: false,
          includeSignature: false,
          docType: OfficialDocType.meetingAgenda,
        ),
        header: header,
        signatureGroupTitle: '',
        signers: const [],
      );
      expect(
        utf8.decode(minimalPdf.take(5).toList(), allowMalformed: true),
        startsWith('%PDF-'),
      );
    });

    test('Gera DOCX OOXML válido com cabeçalho, estilos inline e PNG de assinatura embutido', () {
      final doc = buildDoc('classic_refined');
      final docxBytes = OfficialDocDocxGenerator.generateDocxBytes(
        doc: doc,
        header: header,
        signatureGroupTitle: 'A Comissão de Serviço',
        signers: signers,
      );

      final archive = ZipDecoder().decodeBytes(docxBytes);
      final fileNames = archive.files.map((f) => f.name).toList();
      expect(fileNames, contains('[Content_Types].xml'));
      expect(fileNames, contains('word/document.xml'));
      expect(fileNames, contains('word/header1.xml'));
      expect(fileNames, contains('word/footer1.xml'));
      expect(fileNames, contains('word/_rels/document.xml.rels'));
      expect(
        fileNames.any(
          (n) => n.startsWith('word/media/sig_') && n.endsWith('.png'),
        ),
        isTrue,
      );

      final docXml = utf8.decode(
        archive.findFile('word/document.xml')!.content as List<int>,
      );
      final hdrXml = utf8.decode(
        archive.findFile('word/header1.xml')!.content as List<int>,
      );

      expect(hdrXml, contains('CONGREGAÇÃO EXEMPLO NORTE'));
      expect(docXml, contains('Carta de apresentação'));
      expect(docXml, contains('irmão exemplo'));
      expect(docXml, contains('Romanos 16:1, 2'));
      expect(docXml, contains('Carlos Silva'));
      expect(docXml, contains('<w:b/>'));
      expect(docXml, contains('<w:i/>'));
      expect(docXml, isNot(contains('app://')));
      expect(docXml, isNot(contains('**')));
    });
  });

  group('OfficialDocManager, Importação JSON Drive, Modelos & Isolamento', () {
    late AppDatabase db;
    late KnowledgeManager km;
    late OfficialDocManager manager;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      km = KnowledgeManager(db: db);
      manager = OfficialDocManager(db: db);
    });

    tearDown(() async {
      await db.close();
    });

    test('Bundle padrão usa Original + genéricos e importa/mescla JSON preservando PNG local', () async {
      final initial = await manager.loadBundle();
      expect(initial.defaultStyleId, 'original');
      expect(initial.defaultFonts.bodyFontId, 'pt_serif');
      expect(initial.defaultFonts.signatureFontId, 'sacramento');

      // Simula JSON exportado/importado do Google Drive
      const driveBundleJson = '''
      {
        "schemaVersion": 1,
        "bundleName": "Perfil Congregação Teste",
        "defaultStyleId": "original",
        "defaultFonts": {
          "headerFontId": "pt_sans",
          "metaFontId": "pt_sans",
          "bodyFontId": "pt_serif",
          "signatureFontId": "sacramento",
          "bodyFontSizePt": 10.5,
          "justifyBody": false
        },
        "headers": [
          {
            "id": "hdr-drive-real",
            "label": "Congregação Drive (888123)",
            "topSubtitle": "CONGREGAÇÃO TESTE (888123)",
            "mainTitle": "Manaus · AM",
            "contactEmail": "cong888123@jwpub.org",
            "isDefault": true
          }
        ],
        "elders": [
          {
            "id": "elder-alpha",
            "name": "Fulano de Tal",
            "defaultRole": "Coordenador",
            "alternateRoles": [],
            "signatureFontId": "sacramento"
          },
          {
            "id": "elder-beta",
            "name": "Sicrano de Tal",
            "defaultRole": "Secretário",
            "alternateRoles": ["Sup. de Serviço"],
            "signatureFontId": "courgette"
          }
        ],
        "signatureBlocks": [
          {
            "id": "sig-comissao-drive",
            "label": "Comissão Drive",
            "groupTitle": "A Comissão de Serviço",
            "isDefault": true,
            "signers": [
              {"elderId": "elder-alpha", "name": "Fulano de Tal", "role": "Coordenador"},
              {"elderId": "elder-beta", "name": "Sicrano de Tal", "role": "Secretário"}
            ]
          }
        ],
        "customTemplates": [
          {
            "id": "tpl-drive-1",
            "name": "Carta de Circuito",
            "docType": "general_letter",
            "defaultRef": "Relatório ao SC",
            "defaultBodyMarkup": "*Querido irmão,*"
          }
        ]
      }
      ''';

      final res = await manager.importBundleFromJson(driveBundleJson);
      expect(res.importedTemplates, 1);
      expect(
        res.bundle.headers.any((h) => h.id == 'hdr-drive-real' && h.isDefault),
        isTrue,
      );
      expect(res.bundle.headers.any((h) => h.id == 'hdr-cong-padrao'), isFalse);

      // Adiciona assinatura PNG desenhada localmente ao elder-alpha
      final updatedElders = res.bundle.elders
          .map(
            (e) => e.id == 'elder-alpha'
                ? e.copyWith(signaturePngBase64: synthetic1x1PngBase64)
                : e,
          )
          .toList();
      await manager.saveBundle(res.bundle.copyWith(elders: updatedElders));

      // Reimportar JSON sem PNG NÃO pode apagar a assinatura PNG local existente
      final res2 = await manager.importBundleFromJson(driveBundleJson);
      final alpha = res2.bundle.elders.firstWhere((e) => e.id == 'elder-alpha');
      expect(alpha.signaturePngBase64, synthetic1x1PngBase64);

      // Exportação JSON round-trip válida
      final exportedStr = await manager.exportBundleToJsonString();
      final redecoded = OfficialDocProfileBundle.fromJson(
        jsonDecode(exportedStr) as Map<String, dynamic>,
      );
      expect(redecoded.elders.any((e) => e.id == 'elder-alpha'), isTrue);

      // Verifica registro de sync_queue sem vazamentos para notas pessoais
      final queueRows = await db.select(db.syncQueue).get();
      expect(queueRows.any((q) => q.entityType == 'knowledge_notes'), isTrue);
    });

    test('CRUD de documentos, conversão Pauta -> Ata, novos modelos e isolamento no KnowledgeManager', () async {
      await km.createNote(
        title: 'Nota pessoal comum',
        content: 'Texto pessoal',
      );

      final pautaTpl = OfficialDocPresets.builtInTemplates.firstWhere(
        (t) => t.docType == OfficialDocType.meetingAgenda,
      );
      final pauta = await manager.createFromTemplate(pautaTpl);
      expect(pauta.docType, OfficialDocType.meetingAgenda);
      expect(pauta.includeSignature, isFalse);

      final ata = await manager.convertAgendaToMinutes(pauta);
      expect(ata.docType, OfficialDocType.meetingMinutes);
      expect(ata.includeSignature, isTrue);
      expect(ata.bodyMarkup, contains('Decisões & Responsáveis'));

      final savedCustomTpl = await manager.saveDocumentAsTemplate(
        ata,
        templateName: 'Ata Padrão Trimestral',
      );
      final customList = await manager.getCustomTemplates();
      expect(customList.any((t) => t.id == savedCustomTpl.id), isTrue);

      // Isolamento: watchNotes() normal NÃO deve expor docs/templates/bundle oficiais!
      final visiblePersonalNotes = await km.watchNotes().first;
      expect(visiblePersonalNotes.length, 1);
      expect(visiblePersonalNotes.first.title, 'Nota pessoal comum');

      // Busca unificada não vaza JSON bruto nem expõe templates/bundle
      final searchHits = await km.searchKnowledge('Ata');
      expect(searchHits.any((h) => h.category == 'official_template'), isFalse);
      expect(
        searchHits.any((h) => h.category == 'official_profile_bundle'),
        isFalse,
      );
      final docHit = searchHits.firstWhere((h) => h.category == 'official_doc');
      expect(docHit.snippet, isNot(contains('"docType"')));

      // Arquivamento em Documentos (appKvStore + knowledge_documents)
      final docEntry = await manager.archiveExportedFile(
        title: ata.title,
        fileName: 'Ata_Reuniao.pdf',
        fileType: 'pdf',
        bytes: Uint8List.fromList([37, 80, 68, 70, 45, 49]),
      );
      final kvRow = await (db.select(
        db.appKvStore,
      )..where((t) => t.key.equals('doc_bytes_${docEntry.id}'))).getSingle();
      expect(kvRow.value, isNotEmpty);
    });
  });

  group('UI Widget & Feature Toggle', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets(
      'Feature toggle preserva dados ao desabilitar e OfficialDocumentsScreen cria doc e renderiza preview',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 860);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final manager = OfficialDocManager(db: db);
        final created = await manager.createFromTemplate(
          OfficialDocPresets.builtInTemplates.first,
        );

        final container = ProviderContainer(
          overrides: [databaseProvider.overrideWithValue(db)],
        );
        addTearDown(container.dispose);
        await container.read(appSettingsManagerProvider).init();

        expect(
          container.read(
            isFeatureEnabledProvider(AppFeature.officialDocuments),
          ),
          isTrue,
        );
        await container
            .read(appSettingsNotifierProvider.notifier)
            .setString(
              FeatureRegistry.settingKey(AppFeature.officialDocuments),
              'false',
            );
        expect(
          container.read(
            isFeatureEnabledProvider(AppFeature.officialDocuments),
          ),
          isFalse,
        );
        // Desativar recurso preserva todos os dados locais
        final preserved = await manager.getDocumentById(created.id);
        expect(preserved, isNotNull);
        await container
            .read(appSettingsNotifierProvider.notifier)
            .setString(
              FeatureRegistry.settingKey(AppFeature.officialDocuments),
              'true',
            );
        expect(
          container.read(
            isFeatureEnabledProvider(AppFeature.officialDocuments),
          ),
          isTrue,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [databaseProvider.overrideWithValue(db)],
            child: const MaterialApp(home: OfficialDocumentsScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('btn_new_official_doc')), findsOneWidget);
        expect(
          find.byKey(const Key('btn_official_doc_profiles')),
          findsOneWidget,
        );
        expect(find.text(created.title), findsOneWidget);

        // Seleciona o documento criado na lista -> abre Editor + Prévia A4 em tempo real
        await tester.tap(find.text(created.title));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('dropdown_official_style')),
          findsOneWidget,
        );
        expect(find.byType(OfficialDocPreviewWidget), findsOneWidget);
        expect(
          find.byKey(const Key('btn_official_doc_send_email')),
          findsOneWidget,
        );

        // Desmonta árvore antes do tearDown fechar o banco SQLite
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );

    testWidgets('KnowledgeBaseScreen possui 5 abas incluindo Cartas & Atas', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: const MaterialApp(
            home: KnowledgeBaseScreen(initialTabIndex: 4),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('✉️ Cartas & Atas'), findsOneWidget);
      expect(find.byType(OfficialDocumentsScreen), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  });
}
