import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';

import '../core/app_logger.dart';
import '../database/app_database.dart';
import '../knowledge/knowledge_manager.dart';
import '../sync/media_bytes.dart';
import 'official_doc_models.dart';
import 'official_doc_presets.dart';

/// Gerenciador offline-first + sincronizado E2EE (via `knowledge_notes` e `knowledge_documents`)
/// para Cartas Oficiais, Pautas, Atas, Modelos Personalizados e Perfis de Timbre/Assinatura.
class OfficialDocManager {
  static const String categoryDoc = 'official_doc';
  static const String categoryTemplate = 'official_template';
  static const String categoryBundle = 'official_profile_bundle';
  static const String _bundleFixedId = 'official-doc-profile-bundle-v1';

  final AppDatabase db;
  final KnowledgeManager knowledgeManager;
  final Uuid _uuid = const Uuid();

  OfficialDocManager({required this.db})
    : knowledgeManager = KnowledgeManager(db: db);

  static bool isReservedCategory(String category) {
    return category == categoryDoc ||
        category == categoryTemplate ||
        category == categoryBundle ||
        category.startsWith('official_');
  }

  // ===========================================================================
  // PERFIS DE CABEÇALHO, ANCIÃOS, ASSINATURAS E FONTES (BUNDLE)
  // ===========================================================================

  Future<OfficialDocProfileBundle> loadBundle() async {
    final row =
        await (db.select(db.knowledgeNotes)..where(
              (t) =>
                  (t.id.equals(_bundleFixedId) |
                      t.category.equals(categoryBundle)) &
                  t.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (row == null || row.content.trim().isEmpty) {
      return OfficialDocPresets.createDefaultBundle();
    }
    try {
      final map = jsonDecode(row.content) as Map<String, dynamic>;
      final parsed = OfficialDocProfileBundle.fromJson(map);
      if (parsed.headers.isEmpty) {
        return parsed.copyWith(headers: OfficialDocPresets.defaultHeaders);
      }
      return parsed;
    } catch (e, st) {
      AppLogger.warning(
        'Falha ao decodificar bundle de perfis oficiais',
        e,
        st,
      );
      return OfficialDocPresets.createDefaultBundle();
    }
  }

  Stream<OfficialDocProfileBundle> watchBundle() {
    return (db.select(db.knowledgeNotes)
          ..where(
            (t) =>
                (t.id.equals(_bundleFixedId) |
                    t.category.equals(categoryBundle)) &
                t.deletedAt.isNull(),
          )
          ..limit(1))
        .watchSingleOrNull()
        .map((row) {
          if (row == null || row.content.trim().isEmpty) {
            return OfficialDocPresets.createDefaultBundle();
          }
          try {
            final parsed = OfficialDocProfileBundle.fromJson(
              jsonDecode(row.content) as Map<String, dynamic>,
            );
            return parsed.headers.isEmpty
                ? parsed.copyWith(headers: OfficialDocPresets.defaultHeaders)
                : parsed;
          } catch (_) {
            return OfficialDocPresets.createDefaultBundle();
          }
        });
  }

  Future<void> saveBundle(OfficialDocProfileBundle bundle) async {
    final now = DateTime.now();
    final jsonContent = jsonEncode(bundle.toJson());
    final existing = await (db.select(
      db.knowledgeNotes,
    )..where((t) => t.id.equals(_bundleFixedId))).getSingleOrNull();

    if (existing == null) {
      await knowledgeManager.createNote(
        id: _bundleFixedId,
        title: bundle.bundleName,
        content: jsonContent,
        category: categoryBundle,
        tags: const ['official_bundle'],
      );
    } else {
      await (db.update(
        db.knowledgeNotes,
      )..where((t) => t.id.equals(_bundleFixedId))).write(
        KnowledgeNotesCompanion(
          title: drift.Value(bundle.bundleName),
          content: drift.Value(jsonContent),
          category: const drift.Value(categoryBundle),
          deletedAt: const drift.Value(null),
          updatedAt: drift.Value(now),
        ),
      );
      await knowledgeManager.updateNote(
        _bundleFixedId,
        title: bundle.bundleName,
        content: jsonContent,
        category: categoryBundle,
      );
    }
  }

  /// Importa pacote JSON (ex.: `Perfil_Congregacao.json` do Google Drive)
  /// mesclando com segurança no banco local offline sem apagar dados existentes.
  Future<({OfficialDocProfileBundle bundle, int importedTemplates})>
  importBundleFromJson(String rawJson) async {
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Arquivo JSON inválido: esperado objeto de perfis na raiz.',
      );
    }
    final incoming = OfficialDocProfileBundle.fromJson(decoded);
    final current = await loadBundle();

    // Mescla cabeçalhos (substituindo se mesmo id; removendo placeholder genérico só se veio padrão real)
    final hasRealDefaultHeader = incoming.headers.any(
      (h) => h.isDefault && !h.isEmptyHeader,
    );
    final mergedHeaders = <OfficialHeaderProfile>[];
    for (final existing in current.headers) {
      if (hasRealDefaultHeader && existing.id == 'hdr-cong-padrao') continue;
      final override = incoming.headers
          .where((h) => h.id == existing.id)
          .firstOrNull;
      if (override == null) {
        mergedHeaders.add(
          hasRealDefaultHeader ? existing.copyWith(isDefault: false) : existing,
        );
      }
    }
    for (final inc in incoming.headers) {
      if (inc.id.trim().isEmpty) continue;
      mergedHeaders.removeWhere((h) => h.id == inc.id);
      mergedHeaders.add(inc);
    }

    // Mescla anciãos preservando assinaturas PNG desenhadas localmente caso o JSON não traga PNG
    final elderMap = <String, ElderSignerProfile>{
      for (final e in current.elders)
        if (e.id != 'elder-coordenador' && e.id != 'elder-secretario' ||
            incoming.elders.isEmpty)
          e.id: e,
    };
    for (final inc in incoming.elders) {
      if (inc.id.trim().isEmpty) continue;
      final prev = elderMap[inc.id];
      elderMap[inc.id] =
          (prev != null && prev.hasDrawnSignature && !inc.hasDrawnSignature)
          ? inc.copyWith(signaturePngBase64: prev.signaturePngBase64)
          : inc;
    }

    // Mescla blocos de assinatura resolvendo assinatura PNG dos anciãos por elderId
    final sigMap = <String, OfficialSignatureBlock>{
      for (final s in current.signatureBlocks) s.id: s,
    };
    for (final inc in incoming.signatureBlocks) {
      if (inc.id.trim().isEmpty) continue;
      if (inc.isDefault) {
        for (final k in sigMap.keys.toList()) {
          sigMap[k] = sigMap[k]!.copyWith(isDefault: false);
        }
      }
      sigMap[inc.id] = inc;
    }

    final mergedBundle = OfficialDocProfileBundle(
      schemaVersion: incoming.schemaVersion,
      bundleName: incoming.bundleName,
      defaultStyleId: decoded.containsKey('defaultStyleId')
          ? incoming.defaultStyleId
          : current.defaultStyleId,
      defaultFonts: decoded.containsKey('defaultFonts')
          ? incoming.defaultFonts
          : current.defaultFonts,
      headers: mergedHeaders.isEmpty
          ? OfficialDocPresets.defaultHeaders
          : mergedHeaders,
      elders: elderMap.values.toList(),
      signatureBlocks: sigMap.values.toList(),
    );

    await saveBundle(mergedBundle);

    var importedTplCount = 0;
    for (final tpl in incoming.customTemplates) {
      await saveCustomTemplate(tpl.copyWith(isBuiltIn: false));
      importedTplCount++;
    }

    return (bundle: mergedBundle, importedTemplates: importedTplCount);
  }

  Future<String> exportBundleToJsonString() async {
    final bundle = await loadBundle();
    final customTemplates = await getCustomTemplates();
    return bundle
        .copyWith(customTemplates: customTemplates)
        .toPrettyJsonString();
  }

  // ===========================================================================
  // MODELOS PERSONALIZADOS (4 NATIVOS + ILIMITADOS CRIADOS PELO USUÁRIO)
  // ===========================================================================

  Stream<List<OfficialDocTemplate>> watchAllTemplates() {
    return knowledgeManager.watchNotes(category: categoryTemplate).map((rows) {
      final customs = <OfficialDocTemplate>[];
      for (final r in rows) {
        try {
          final tpl = OfficialDocTemplate.fromJson(
            jsonDecode(r.content) as Map<String, dynamic>,
          );
          customs.add(tpl.copyWith(id: r.id, isBuiltIn: false));
        } catch (e, st) {
          AppLogger.warning(
            'Ignorando template oficial inválido (${r.id})',
            e,
            st,
          );
        }
      }
      return [...OfficialDocPresets.builtInTemplates, ...customs];
    });
  }

  Future<List<OfficialDocTemplate>> getCustomTemplates() async {
    final rows =
        await (db.select(db.knowledgeNotes)..where(
              (t) => t.category.equals(categoryTemplate) & t.deletedAt.isNull(),
            ))
            .get();
    final customs = <OfficialDocTemplate>[];
    for (final r in rows) {
      try {
        customs.add(
          OfficialDocTemplate.fromJson(
            jsonDecode(r.content) as Map<String, dynamic>,
          ).copyWith(id: r.id, isBuiltIn: false),
        );
      } catch (_) {}
    }
    return customs;
  }

  Future<OfficialDocTemplate> saveCustomTemplate(
    OfficialDocTemplate template,
  ) async {
    final id = template.id.trim().isEmpty || template.isBuiltIn
        ? _uuid.v4()
        : template.id;
    final clean = template.copyWith(
      id: id,
      isBuiltIn: false,
      updatedAt: DateTime.now(),
    );
    final payload = jsonEncode(clean.toJson());
    final existing = await knowledgeManager.getNoteById(id);

    if (existing == null) {
      await knowledgeManager.createNote(
        id: id,
        title: clean.name,
        content: payload,
        category: categoryTemplate,
        tags: [clean.docType.id],
      );
    } else {
      await knowledgeManager.updateNote(
        id,
        title: clean.name,
        content: payload,
        category: categoryTemplate,
        tags: [clean.docType.id],
      );
    }
    return clean;
  }

  Future<void> deleteCustomTemplate(String templateId) async {
    await knowledgeManager.softDeleteNote(templateId);
  }

  Future<OfficialDocTemplate> saveDocumentAsTemplate(
    OfficialDocumentRecord doc, {
    required String templateName,
    String description = '',
  }) async {
    return saveCustomTemplate(
      OfficialDocTemplate(
        id: _uuid.v4(),
        name: templateName.trim(),
        description: description.trim().isEmpty
            ? 'Modelo salvo a partir de "${doc.title}"'
            : description.trim(),
        docType: doc.docType,
        isBuiltIn: false,
        defaultHeaderId: doc.includeHeader ? doc.headerProfileId : null,
        defaultSignatureBlockId: doc.includeSignature
            ? doc.signatureBlockId
            : null,
        defaultLayoutId: doc.layoutStyleId,
        defaultRef: doc.referenceSubject,
        defaultRecipient: doc.recipientLine,
        defaultBodyMarkup: doc.bodyMarkup,
        defaultMeetingLocation: doc.meetingLocation,
        updatedAt: DateTime.now(),
      ),
    );
  }

  // ===========================================================================
  // DOCUMENTOS (CARTAS, PAUTAS & ATAS)
  // ===========================================================================

  Stream<List<OfficialDocumentRecord>> watchDocuments({
    OfficialDocType? filterType,
    String? query,
  }) {
    return knowledgeManager.watchNotes(category: categoryDoc).map((rows) {
      final list = <OfficialDocumentRecord>[];
      final q = query?.trim().toLowerCase() ?? '';
      for (final row in rows) {
        try {
          final doc = OfficialDocumentRecord.fromJson(
            jsonDecode(row.content) as Map<String, dynamic>,
          ).copyWith(id: row.id, isPinned: row.isPinned);
          if (filterType != null && doc.docType != filterType) continue;
          if (q.isNotEmpty) {
            final haystack =
                '${doc.title}\n${doc.referenceSubject}\n${doc.recipientLine}\n${doc.bodyMarkup}'
                    .toLowerCase();
            if (!haystack.contains(q)) continue;
          }
          list.add(doc);
        } catch (e, st) {
          AppLogger.warning(
            'Ignorando documento oficial inválido (${row.id})',
            e,
            st,
          );
        }
      }
      return list;
    });
  }

  Future<OfficialDocumentRecord?> getDocumentById(String id) async {
    final row = await knowledgeManager.getNoteById(id);
    if (row == null || row.deletedAt != null || row.category != categoryDoc) {
      return null;
    }
    return OfficialDocumentRecord.fromJson(
      jsonDecode(row.content) as Map<String, dynamic>,
    ).copyWith(id: row.id, isPinned: row.isPinned);
  }

  Future<OfficialDocumentRecord> createFromTemplate(
    OfficialDocTemplate template,
  ) async {
    final bundle = await loadBundle();
    final defaultHeader = bundle.headers.firstWhere(
      (h) => h.id == template.defaultHeaderId,
      orElse: () => bundle.headers.firstWhere(
        (h) => h.isDefault,
        orElse: () => bundle.headers.first,
      ),
    );
    final defaultSig = bundle.signatureBlocks.firstWhere(
      (s) => s.id == template.defaultSignatureBlockId,
      orElse: () => bundle.signatureBlocks.firstWhere(
        (s) => s.isDefault,
        orElse: () => bundle.signatureBlocks.first,
      ),
    );

    final now = DateTime.now();
    final cityPrefix = defaultHeader.mainTitle.isNotEmpty
        ? defaultHeader.mainTitle
        : 'Local';
    final locDate = OfficialDocPresets.formatPortugueseDate(
      now,
      cityPrefix: cityPrefix,
    );

    final record = OfficialDocumentRecord(
      id: _uuid.v4(),
      title: template.defaultRef.isNotEmpty
          ? template.defaultRef
          : template.name,
      docType: template.docType,
      layoutStyleId: bundle.defaultStyleId.isNotEmpty
          ? bundle.defaultStyleId
          : template.defaultLayoutId,
      headerProfileId: defaultHeader.id,
      signatureBlockId: template.docType == OfficialDocType.meetingAgenda
          ? (bundle.signatureBlocks
                    .where((s) => s.isEmptySignature)
                    .firstOrNull
                    ?.id ??
                defaultSig.id)
          : defaultSig.id,
      includeHeader: !defaultHeader.isEmptyHeader,
      includeSignature: template.docType != OfficialDocType.meetingAgenda,
      fontSpec: bundle.defaultFonts,
      locationDate: locDate,
      referenceSubject: template.defaultRef,
      recipientLine: template.defaultRecipient,
      meetingDateTime: template.docType.isMeeting ? locDate : '',
      meetingLocation: template.defaultMeetingLocation,
      bodyMarkup: template.defaultBodyMarkup,
      createdAt: now,
      updatedAt: now,
    );
    return saveDocument(record);
  }

  Future<OfficialDocumentRecord> saveDocument(
    OfficialDocumentRecord doc,
  ) async {
    final now = DateTime.now();
    final id = doc.id.trim().isEmpty ? _uuid.v4() : doc.id;
    final updated = doc.copyWith(id: id, updatedAt: now);
    final payload = jsonEncode(updated.toJson());
    final existing = await knowledgeManager.getNoteById(id);

    if (existing == null) {
      await knowledgeManager.createNote(
        id: id,
        title: updated.title,
        content: payload,
        category: categoryDoc,
        isPinned: updated.isPinned,
        tags: [updated.docType.id],
      );
    } else {
      await knowledgeManager.updateNote(
        id,
        title: updated.title,
        content: payload,
        category: categoryDoc,
        tags: [updated.docType.id],
      );
    }
    return updated;
  }

  Future<void> togglePinDocument(String id) =>
      knowledgeManager.togglePinNote(id);

  Future<void> deleteDocument(String id) => knowledgeManager.softDeleteNote(id);

  /// Converte uma Pauta de Reunião em Ata preservando participantes, local e tópicos.
  Future<OfficialDocumentRecord> convertAgendaToMinutes(
    OfficialDocumentRecord agenda,
  ) async {
    final now = DateTime.now();
    final bundle = await loadBundle();
    final minutesSig =
        bundle.signatureBlocks
            .where((s) => s.id == 'sig-corpo-anciaos' || !s.isEmptySignature)
            .firstOrNull ??
        bundle.signatureBlocks.first;

    final ref = agenda.referenceSubject.replaceFirst(
      RegExp(r'^Pauta', caseSensitive: false),
      'Ata',
    );
    final newDoc = agenda.copyWith(
      id: _uuid.v4(),
      title: ref.trim().isEmpty ? 'Ata de Reunião' : ref,
      docType: OfficialDocType.meetingMinutes,
      referenceSubject: ref,
      includeSignature: true,
      signatureBlockId: agenda.signatureBlockId ?? minutesSig.id,
      bodyMarkup:
          '${agenda.bodyMarkup.trim()}\n\n---\n\n'
          '## Decisões & Responsáveis\n'
          '- **Decisão 1:** Descrever deliberação, responsável e prazo.\n',
      createdAt: now,
      updatedAt: now,
    );
    return saveDocument(newDoc);
  }

  /// Resolve a lista efetiva de assinantes mesclando overrides do documento e PNG/fonte do perfil do ancião.
  List<SignerSlot> resolveEffectiveSigners(
    OfficialDocumentRecord doc,
    OfficialDocProfileBundle bundle,
  ) {
    final block = bundle.signatureBlocks
        .where((s) => s.id == doc.signatureBlockId)
        .firstOrNull;
    final rawSlots = doc.customSigners ?? block?.signers ?? const [];
    final elderById = {for (final e in bundle.elders) e.id: e};

    return rawSlots.map((slot) {
      final elder = slot.elderId != null ? elderById[slot.elderId!] : null;
      return SignerSlot(
        elderId: slot.elderId,
        name: slot.name,
        role: slot.role,
        signatureFontIdOverride:
            slot.signatureFontIdOverride ?? elder?.signatureFontId,
        signaturePngBase64Override:
            slot.signaturePngBase64Override ?? elder?.signaturePngBase64,
      );
    }).toList();
  }

  String resolveGroupTitle(
    OfficialDocumentRecord doc,
    OfficialDocProfileBundle bundle,
  ) {
    if (doc.customGroupTitle != null) return doc.customGroupTitle!;
    final block = bundle.signatureBlocks
        .where((s) => s.id == doc.signatureBlockId)
        .firstOrNull;
    return block?.groupTitle ?? '';
  }

  /// Arquiva um PDF/PNG/DOCX exportado também em `Documentos` da Base de Conhecimento (Web + Nativo).
  Future<KnowledgeDocumentEntry> archiveExportedFile({
    required String title,
    required String fileName,
    required String fileType,
    required Uint8List bytes,
    String? description,
  }) async {
    String? baseDir;
    try {
      baseDir = await resolveDefaultDocumentsDir();
    } catch (_) {
      baseDir = null;
    }
    String savedPath = fileName;
    if (baseDir != null && baseDir.isNotEmpty) {
      try {
        savedPath =
            await saveMediaBytes(
              baseDir: baseDir,
              subDir: 'documents',
              fileName: fileName,
              bytes: bytes,
              mimeType: fileType == 'pdf'
                  ? 'application/pdf'
                  : (fileType == 'png'
                        ? 'image/png'
                        : 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'),
            ) ??
            fileName;
      } catch (_) {
        savedPath = fileName;
      }
    }

    final checksum = crypto.sha256.convert(bytes).toString();
    final entry = await knowledgeManager.registerDocument(
      title: title,
      fileName: fileName,
      fileType: fileType,
      fileSize: bytes.length,
      filePath: savedPath,
      sha256Checksum: checksum,
      description: description ?? 'Documento oficial gerado pelo aplicativo',
      category: 'official_letter',
      tags: ['Cartas & Atas', fileType.toUpperCase()],
    );

    await db
        .into(db.appKvStore)
        .insertOnConflictUpdate(
          AppKvStoreCompanion.insert(
            key: 'doc_bytes_${entry.id}',
            value: base64Encode(bytes),
            updatedAt: drift.Value(DateTime.now()),
          ),
        );
    return entry;
  }
}
