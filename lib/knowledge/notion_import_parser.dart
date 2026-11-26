import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:uuid/uuid.dart';

/// Área extraída de pastas de topo de uma exportação do Notion.
class ParsedNotionArea {
  final String id;
  final String name;
  final String colorHex;

  const ParsedNotionArea({
    required this.id,
    required this.name,
    required this.colorHex,
  });
}

/// Nota/subpágina ou registro de tabela extraído do Notion.
class ParsedNotionNote {
  final String id;
  final String title;
  final String content;
  final String category;
  final String? areaId;
  final String? parentNoteId;
  final List<String> tags;
  final Map<String, String> properties;
  final String originalPath;

  const ParsedNotionNote({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    this.areaId,
    this.parentNoteId,
    required this.tags,
    required this.properties,
    required this.originalPath,
  });

  ParsedNotionNote copyWith({String? content}) {
    return ParsedNotionNote(
      id: id,
      title: title,
      content: content ?? this.content,
      category: category,
      areaId: areaId,
      parentNoteId: parentNoteId,
      tags: tags,
      properties: properties,
      originalPath: originalPath,
    );
  }
}

/// Pré-visualização e resultado estruturado da análise de um pacote Notion (.zip/.md/.csv).
class ParsedNotionPackage {
  final List<ParsedNotionArea> areas;
  final List<ParsedNotionNote> notes;
  final int rewrittenLinksCount;
  final List<String> warnings;

  const ParsedNotionPackage({
    required this.areas,
    required this.notes,
    required this.rewrittenLinksCount,
    this.warnings = const [],
  });
}

/// Analisador puro Dart para exportações do Notion (`.zip`, `.md` e `.csv`),
/// preservando hierarquia de pastas/subpáginas, propriedades e convertendo links internos
/// para referências `app://ref/note/<uuid>`.
class NotionImportParser {
  NotionImportParser._();

  static const Uuid _uuid = Uuid();
  static final RegExp _notionIdSuffix = RegExp(r'\s+[0-9a-fA-F]{32}$');
  static final RegExp _notionShortIdSuffix = RegExp(r'\s+[0-9a-fA-F]{8,16}$');

  static const List<String> _areaPalette = [
    '#6366F1',
    '#0EA5E9',
    '#10B981',
    '#F59E0B',
    '#EC4899',
    '#8B5CF6',
  ];

  /// Desempacota arquivo `.zip` em memória (inclusive exports aninhados zip-dentro-de-zip comuns no Notion).
  static ParsedNotionPackage parseZipBytes(Uint8List zipBytes) {
    final files = <String, Uint8List>{};
    final warnings = <String>[];

    void extractArchive(Uint8List bytes, String prefix) {
      final archive = ZipDecoder().decodeBytes(bytes);
      for (final file in archive) {
        if (!file.isFile) continue;
        final name = file.name.replaceAll('\\', '/');
        final fullPath = prefix.isEmpty ? name : '$prefix/$name';
        final rawContent = file.content as List<int>;
        final rawBytes = Uint8List.fromList(rawContent);
        if (name.toLowerCase().endsWith('.zip')) {
          try {
            extractArchive(rawBytes, '');
          } catch (e) {
            warnings.add('Arquivo interno $name ignorado: $e');
          }
        } else {
          files[fullPath] = rawBytes;
        }
      }
    }

    extractArchive(zipBytes, '');
    return parseFiles(files, initialWarnings: warnings);
  }

  /// Analisa múltiplos arquivos soltos (`.md` ou `.csv`) ou mapa de caminhos vindos de um ZIP.
  static ParsedNotionPackage parseFiles(
    Map<String, Uint8List> files, {
    List<String> initialWarnings = const [],
  }) {
    final warnings = <String>[...initialWarnings];
    final normalizedEntries = <String, Uint8List>{};

    for (final e in files.entries) {
      final path = e.key.replaceAll('\\', '/').replaceFirst(RegExp(r'^/+'), '');
      if (path.isEmpty) continue;
      final lower = path.toLowerCase();
      if (lower.endsWith('.md') ||
          lower.endsWith('.markdown') ||
          lower.endsWith('.csv')) {
        normalizedEntries[path] = e.value;
      }
    }

    if (normalizedEntries.isEmpty) {
      return const ParsedNotionPackage(
        areas: [],
        notes: [],
        rewrittenLinksCount: 0,
        warnings: [
          'Nenhum arquivo .md ou .csv encontrado no pacote do Notion.',
        ],
      );
    }

    final areasByKey = <String, ParsedNotionArea>{};
    final notesByNormPath = <String, ParsedNotionNote>{};
    final orderedRawNotes = <ParsedNotionNote>[];

    // Ordena por profundidade de pasta para garantir pais criados/associados corretamente.
    final sortedPaths = normalizedEntries.keys.toList()
      ..sort((a, b) {
        final depthA = a.split('/').length;
        final depthB = b.split('/').length;
        return depthA != depthB ? depthA.compareTo(depthB) : a.compareTo(b);
      });

    for (final rawPath in sortedPaths) {
      final rawBytes = normalizedEntries[rawPath]!;
      final text = _decodeUtf8BomSafe(rawBytes);
      final lower = rawPath.toLowerCase();
      final segments = rawPath
          .split('/')
          .where((s) => s.trim().isNotEmpty)
          .toList();

      String? areaId;
      if (segments.length >= 2) {
        final topFolderRaw = segments.first;
        final topAreaName = cleanNotionName(topFolderRaw);
        if (topAreaName.isNotEmpty) {
          final areaKey = topAreaName.toLowerCase();
          final existingArea = areasByKey[areaKey];
          if (existingArea != null) {
            areaId = existingArea.id;
          } else {
            final newArea = ParsedNotionArea(
              id: _uuid.v4(),
              name: topAreaName,
              colorHex: _areaPalette[areasByKey.length % _areaPalette.length],
            );
            areasByKey[areaKey] = newArea;
            areaId = newArea.id;
          }
        }
      }

      if (lower.endsWith('.csv')) {
        final dbTitle = cleanNotionName(
          segments.last.replaceFirst(
            RegExp(r'\.csv$', caseSensitive: false),
            '',
          ),
        );
        final rows = parseCsv(text);
        if (rows.length < 2) {
          warnings.add('$rawPath: CSV sem linhas de dados ignorado.');
          continue;
        }
        final headers = rows.first;
        // Se existir uma nota correspondente com mesmo nome da pasta pai ou DB, vincula como subpáginas.
        final csvParent = _resolveParentNoteId(
          segments: segments,
          notesByNormPath: notesByNormPath,
          isLeafDatabaseRow: false,
        );
        for (var r = 1; r < rows.length; r++) {
          final row = rows[r];
          if (row.every((c) => c.trim().isEmpty)) continue;
          final parsedRow = _csvRowToNote(
            headers: headers,
            row: row,
            databaseName: dbTitle,
            areaId: areaId,
            parentNoteId: csvParent,
            sourcePath: '$rawPath#row$r',
          );
          orderedRawNotes.add(parsedRow);
        }
        continue;
      }

      // Markdown (.md / .markdown)
      final fileNoExt = segments.last.replaceFirst(
        RegExp(r'\.(md|markdown)$', caseSensitive: false),
        '',
      );
      final parsedMd = parseMarkdownWithProperties(
        text,
        fallbackTitle: cleanNotionName(fileNoExt),
      );
      final parentNoteId = _resolveParentNoteId(
        segments: segments,
        notesByNormPath: notesByNormPath,
        isLeafDatabaseRow: false,
      );

      final note = ParsedNotionNote(
        id: _uuid.v4(),
        title: parsedMd.title,
        content: parsedMd.body,
        category: parsedMd.category,
        areaId: areaId,
        parentNoteId: parentNoteId,
        tags: parsedMd.tags,
        properties: parsedMd.properties,
        originalPath: rawPath,
      );
      orderedRawNotes.add(note);
      notesByNormPath[_normalizePathKey(rawPath)] = note;
      notesByNormPath[_normalizePathKey(
            '${segments.sublist(0, segments.length - 1).join('/')}/$fileNoExt',
          )] =
          note;
      notesByNormPath[cleanNotionName(fileNoExt).toLowerCase()] = note;
    }

    // Segunda passada: converte links relativos `.md` do Notion para `app://ref/note/<id>`.
    var rewritten = 0;
    final linkRegex = RegExp(
      r'\[([^\]]+)\]\(([^)]+\.(?:md|markdown)(?:#[^)]*)?)\)',
    );
    final finalNotes = <ParsedNotionNote>[];

    for (final n in orderedRawNotes) {
      final dir = _dirname(n.originalPath);
      final updatedContent = n.content.replaceAllMapped(linkRegex, (m) {
        final label = m.group(1) ?? '';
        var targetHref = m.group(2) ?? '';
        final hashIdx = targetHref.indexOf('#');
        if (hashIdx != -1) {
          targetHref = targetHref.substring(0, hashIdx);
        }
        final decoded = _safeUriDecode(targetHref);
        final resolvedPath = _resolveRelativePath(dir, decoded);
        final matched =
            notesByNormPath[_normalizePathKey(resolvedPath)] ??
            notesByNormPath[_normalizePathKey(decoded)] ??
            notesByNormPath[cleanNotionName(
              decoded
                  .split('/')
                  .last
                  .replaceFirst(
                    RegExp(r'\.(md|markdown)$', caseSensitive: false),
                    '',
                  ),
            ).toLowerCase()];

        if (matched == null) {
          return m.group(0)!;
        }
        rewritten++;
        final safeLabel = label.trim().isEmpty ? matched.title : label.trim();
        return '[$safeLabel](app://ref/note/${matched.id})';
      });
      finalNotes.add(n.copyWith(content: updatedContent));
    }

    return ParsedNotionPackage(
      areas: areasByKey.values.toList(),
      notes: finalNotes,
      rewrittenLinksCount: rewritten,
      warnings: warnings,
    );
  }

  static String cleanNotionName(String raw) {
    var name = raw.trim();
    name = name.replaceFirst(_notionIdSuffix, '').trim();
    name = name.replaceFirst(_notionShortIdSuffix, '').trim();
    return name;
  }

  static String? _resolveParentNoteId({
    required List<String> segments,
    required Map<String, ParsedNotionNote> notesByNormPath,
    required bool isLeafDatabaseRow,
  }) {
    if (segments.length < 2) return null;
    final parentDirSegments = segments.sublist(0, segments.length - 1);
    final parentFolderName = parentDirSegments.last;
    final parentMdPath = '${parentDirSegments.join('/')}.md';
    final hit =
        notesByNormPath[_normalizePathKey(parentMdPath)] ??
        notesByNormPath[_normalizePathKey(parentDirSegments.join('/'))] ??
        notesByNormPath[cleanNotionName(parentFolderName).toLowerCase()];
    if (hit != null) return hit.id;
    return null;
  }

  static String _normalizePathKey(String raw) => raw
      .replaceAll('\\', '/')
      .replaceFirst(RegExp(r'^/+'), '')
      .toLowerCase()
      .trim();

  static String _dirname(String path) {
    final idx = path.lastIndexOf('/');
    return idx == -1 ? '' : path.substring(0, idx);
  }

  static String _safeUriDecode(String value) {
    try {
      return Uri.decodeFull(value);
    } catch (_) {
      return value;
    }
  }

  static String _resolveRelativePath(String baseDir, String relative) {
    final parts = baseDir.isEmpty
        ? <String>[]
        : baseDir.split('/').where((p) => p.isNotEmpty).toList();
    for (final seg in relative.replaceAll('\\', '/').split('/')) {
      if (seg.isEmpty || seg == '.') continue;
      if (seg == '..') {
        if (parts.isNotEmpty) parts.removeLast();
      } else {
        parts.add(seg);
      }
    }
    return parts.join('/');
  }

  static String _decodeUtf8BomSafe(Uint8List bytes) {
    var s = utf8.decode(bytes, allowMalformed: true);
    if (s.startsWith('\uFEFF')) {
      s = s.substring(1);
    }
    return s.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  }

  /// Extrai título H1, YAML frontmatter (`--- ... ---`) e bloco inicial `Chave: Valor` do Notion.
  static ({
    String title,
    String body,
    String category,
    List<String> tags,
    Map<String, String> properties,
  })
  parseMarkdownWithProperties(String raw, {required String fallbackTitle}) {
    final lines = raw.split('\n');
    var idx = 0;
    final props = <String, String>{};
    final tags = <String>{};
    var title = fallbackTitle;
    var category = 'general';

    // 1. YAML frontmatter
    if (lines.isNotEmpty && lines.first.trim() == '---') {
      idx = 1;
      while (idx < lines.length && lines[idx].trim() != '---') {
        final line = lines[idx];
        final colon = line.indexOf(':');
        if (colon > 0) {
          final k = line.substring(0, colon).trim();
          final v = line.substring(colon + 1).trim();
          _ingestProperty(k, v, props, tags);
        }
        idx++;
      }
      if (idx < lines.length && lines[idx].trim() == '---') {
        idx++;
      }
    }

    while (idx < lines.length && lines[idx].trim().isEmpty) {
      idx++;
    }

    // 2. Título H1 inicial do Notion
    if (idx < lines.length && lines[idx].startsWith('# ')) {
      final h1 = lines[idx].substring(2).trim();
      if (h1.isNotEmpty) title = h1;
      idx++;
      while (idx < lines.length && lines[idx].trim().isEmpty) {
        idx++;
      }
    }

    // 3. Bloco de propriedades exportadas no topo pelo Notion (`Status: ...`, `Tags: ...`)
    var propLinesRead = 0;
    while (idx < lines.length && propLinesRead < 15) {
      final l = lines[idx].trim();
      if (l.isEmpty) {
        idx++;
        break;
      }
      final match = RegExp(r'^([A-Za-zÀ-ÿ0-9 _\-]{2,32}):\s+(.+)$')
          .firstMatch(l);
      if (match == null ||
          l.startsWith('http://') ||
          l.startsWith('https://') ||
          l.startsWith('>') ||
          l.startsWith('-') ||
          l.startsWith('*') ||
          l.startsWith('#')) {
        break;
      }
      _ingestProperty(match.group(1)!, match.group(2)!, props, tags);
      idx++;
      propLinesRead++;
    }

    final catRaw = (props['category'] ?? props['categoria'] ?? '')
        .toLowerCase();
    if (catRaw.contains('minist')) {
      category = 'ministry';
    } else if (catRaw.contains('pesq') || catRaw.contains('research')) {
      category = 'research';
    } else if (catRaw.contains('pastor')) {
      category = 'pastoral';
    }

    final titleFromProp = props['title'] ?? props['título'] ?? props['nome'];
    if ((title.isEmpty || title == fallbackTitle) &&
        titleFromProp != null &&
        titleFromProp.isNotEmpty) {
      title = titleFromProp;
    }
    if (title.isEmpty) title = 'Nota do Notion';

    final body = lines.sublist(idx).join('\n').trim();
    return (
      title: title,
      body: body.isNotEmpty ? body : title,
      category: category,
      tags: tags.toList(),
      properties: props,
    );
  }

  static void _ingestProperty(
    String rawKey,
    String rawVal,
    Map<String, String> props,
    Set<String> tags,
  ) {
    final k = rawKey.trim().toLowerCase();
    var v = rawVal.trim();
    if (v.isEmpty) return;

    if (k == 'tags' || k == 'tag' || k == 'etiquetas' || k == 'tópicos') {
      v = v.replaceAll('[', '').replaceAll(']', '');
      for (final part in v.split(',')) {
        final t = part.trim().replaceAll('"', '').replaceAll("'", '');
        if (t.isNotEmpty) tags.add(t);
      }
      return;
    }
    props[k] = v;
  }

  static ParsedNotionNote _csvRowToNote({
    required List<String> headers,
    required List<String> row,
    required String databaseName,
    required String? areaId,
    required String? parentNoteId,
    required String sourcePath,
  }) {
    final props = <String, String>{};
    final tags = <String>{databaseName.isNotEmpty ? databaseName : 'notion-db'};
    var title = '';
    var body = '';

    for (var i = 0; i < headers.length && i < row.length; i++) {
      final h = headers[i].trim();
      final val = row[i].trim();
      if (h.isEmpty || val.isEmpty) continue;
      final lower = h.toLowerCase();
      if (title.isEmpty &&
          (lower == 'name' ||
              lower == 'nome' ||
              lower == 'title' ||
              lower == 'título' ||
              lower == 'titulo')) {
        title = val;
      } else if (body.isEmpty &&
          (lower == 'content' ||
              lower == 'conteúdo' ||
              lower == 'conteudo' ||
              lower == 'notes' ||
              lower == 'notas' ||
              lower == 'summary' ||
              lower == 'resumo')) {
        body = val;
      } else if (lower.contains('tag') || lower.contains('etiqueta')) {
        for (final t in val.split(',')) {
          final clean = t.trim();
          if (clean.isNotEmpty) tags.add(clean);
        }
      } else {
        props[lower] = val;
      }
    }

    if (title.isEmpty) {
      title = row.firstWhere(
        (c) => c.trim().isNotEmpty,
        orElse: () => databaseName,
      );
    }

    final mdBuf = StringBuffer();
    if (body.isNotEmpty) {
      mdBuf.writeln(body);
      mdBuf.writeln();
    }
    if (props.isNotEmpty) {
      mdBuf.writeln('| Campo | Valor |');
      mdBuf.writeln('| --- | --- |');
      for (final e in props.entries) {
        mdBuf.writeln(
          '| ${e.key.replaceAll('|', '/')} | ${e.value.replaceAll('|', '/')} |',
        );
      }
    }

    return ParsedNotionNote(
      id: _uuid.v4(),
      title: title,
      content: mdBuf.toString().trim().isNotEmpty
          ? mdBuf.toString().trim()
          : title,
      category: 'research',
      areaId: areaId,
      parentNoteId: parentNoteId,
      tags: tags.toList(),
      properties: props,
      originalPath: sourcePath,
    );
  }

  /// Parser CSV compatível com RFC-4180 (suporta aspas, aspas escapadas e quebras de linha em células).
  static List<List<String>> parseCsv(String raw) {
    final rows = <List<String>>[];
    var currentRow = <String>[];
    var currentField = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < raw.length; i++) {
      final ch = raw[i];
      if (inQuotes) {
        if (ch == '"') {
          if (i + 1 < raw.length && raw[i + 1] == '"') {
            currentField.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          currentField.write(ch);
        }
      } else {
        if (ch == '"') {
          inQuotes = true;
        } else if (ch == ',') {
          currentRow.add(currentField.toString());
          currentField.clear();
        } else if (ch == '\n') {
          currentRow.add(currentField.toString());
          rows.add(currentRow);
          currentRow = <String>[];
          currentField.clear();
        } else {
          currentField.write(ch);
        }
      }
    }
    if (currentField.isNotEmpty || currentRow.isNotEmpty) {
      currentRow.add(currentField.toString());
      rows.add(currentRow);
    }
    return rows;
  }
}
