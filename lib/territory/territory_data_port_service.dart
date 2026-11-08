import 'dart:convert';
import '../database/app_database.dart';

/// Item genérico exportado ou importado de territórios
class ImportedTerritoryContact {
  final String name;
  final String? phone;
  final String? address;
  final String? neighborhood;
  final String status;
  final double? latitude;
  final double? longitude;
  final String? notes;

  const ImportedTerritoryContact({
    required this.name,
    this.phone,
    this.address,
    this.neighborhood,
    this.status = 'interessado',
    this.latitude,
    this.longitude,
    this.notes,
  });
}

/// Serviço de Importação e Exportação de Territórios nos formatos KML, GeoJSON e CSV
class TerritoryDataPortService {
  TerritoryDataPortService._();

  // ===========================================================================
  // 1. FORMATO KML (Keyhole Markup Language - Google Earth / Organic Maps)
  // ===========================================================================

  /// Exporta contatos do território para o formato padrão KML 2.2
  static String exportToKml({
    required List<PersonEntry> people,
    String territoryName = 'Território Ministerial',
  }) {
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<kml xmlns="http://www.opengis.net/kml/2.2">');
    buffer.writeln('  <Document>');
    buffer.writeln('    <name>${_xmlEscape(territoryName)}</name>');
    buffer.writeln('    <description>Exportado do aplicativo Ministério Pessoal</description>');

    for (final p in people) {
      if (p.deletedAt != null) continue;
      final lat = p.latitude;
      final lng = p.longitude;

      buffer.writeln('    <Placemark>');
      buffer.writeln('      <name>${_xmlEscape(p.name)}</name>');
      final desc = StringBuffer();
      if (p.address != null && p.address!.isNotEmpty) {
        desc.write('Endereço: ${p.address}\n');
      }
      if (p.phone != null && p.phone!.isNotEmpty) {
        desc.write('Telefone: ${p.phone}\n');
      }
      desc.write('Situação: ${p.status}\n');
      if (p.generalNotes != null && p.generalNotes!.isNotEmpty) {
        desc.write('Notas: ${p.generalNotes}');
      }
      buffer.writeln('      <description>${_xmlEscape(desc.toString())}</description>');

      if (lat != null && lng != null) {
        buffer.writeln('      <Point>');
        buffer.writeln('        <coordinates>$lng,$lat,0</coordinates>');
        buffer.writeln('      </Point>');
      }
      buffer.writeln('    </Placemark>');
    }

    buffer.writeln('  </Document>');
    buffer.writeln('</kml>');
    return buffer.toString();
  }

  /// Importa contatos de uma string KML
  static List<ImportedTerritoryContact> importFromKml(String kmlContent) {
    final results = <ImportedTerritoryContact>[];
    final placemarkRegex = RegExp(r'<Placemark\b[^>]*>([\s\S]*?)<\/Placemark>', caseSensitive: false);
    final nameRegex = RegExp(r'<name\b[^>]*>([\s\S]*?)<\/name>', caseSensitive: false);
    final descRegex = RegExp(r'<description\b[^>]*>([\s\S]*?)<\/description>', caseSensitive: false);
    final coordRegex = RegExp(r'<coordinates\b[^>]*>([\s\S]*?)<\/coordinates>', caseSensitive: false);

    for (final match in placemarkRegex.allMatches(kmlContent)) {
      final block = match.group(1) ?? '';
      final nameMatch = nameRegex.firstMatch(block);
      final descMatch = descRegex.firstMatch(block);
      final coordMatch = coordRegex.firstMatch(block);

      final name = nameMatch?.group(1)?.trim() ?? 'Contato Importado';
      final desc = descMatch?.group(1)?.trim() ?? '';

      double? lat;
      double? lng;
      if (coordMatch != null) {
        final raw = coordMatch.group(1)?.trim() ?? '';
        final parts = raw.split(',');
        if (parts.length >= 2) {
          lng = double.tryParse(parts[0].trim());
          lat = double.tryParse(parts[1].trim());
        }
      }

      results.add(
        ImportedTerritoryContact(
          name: _xmlUnescape(name),
          address: _extractFieldFromDesc(desc, 'Endereço:'),
          phone: _extractFieldFromDesc(desc, 'Telefone:'),
          status: _extractFieldFromDesc(desc, 'Situação:') ?? 'interessado',
          notes: _xmlUnescape(desc),
          latitude: lat,
          longitude: lng,
        ),
      );
    }

    return results;
  }

  // ===========================================================================
  // 2. FORMATO GeoJSON (RFC 7946)
  // ===========================================================================

  /// Exporta contatos para formato padrão GeoJSON FeatureCollection
  static String exportToGeoJson({
    required List<PersonEntry> people,
    String territoryName = 'Território',
  }) {
    final features = <Map<String, dynamic>>[];

    for (final p in people) {
      if (p.deletedAt != null) continue;

      final geometry = (p.latitude != null && p.longitude != null)
          ? {
              'type': 'Point',
              'coordinates': [p.longitude, p.latitude],
            }
          : null;

      features.add({
        'type': 'Feature',
        'geometry': geometry,
        'properties': {
          'id': p.id,
          'name': p.name,
          'phone': p.phone,
          'address': p.address,
          'status': p.status,
          'notes': p.generalNotes,
          'tags': p.tags,
        },
      });
    }

    final root = {
      'type': 'FeatureCollection',
      'name': territoryName,
      'features': features,
    };

    return const JsonEncoder.withIndent('  ').convert(root);
  }

  /// Importa contatos a partir de uma string GeoJSON
  static List<ImportedTerritoryContact> importFromGeoJson(String geoJsonContent) {
    final results = <ImportedTerritoryContact>[];
    try {
      final dynamic data = jsonDecode(geoJsonContent);

      if (data is! Map<String, dynamic>) return results;

      final features = data['features'] as List<dynamic>? ?? [];
      for (final feat in features) {
        if (feat is! Map<String, dynamic>) continue;
        final props = feat['properties'] as Map<String, dynamic>? ?? {};
        final geom = feat['geometry'] as Map<String, dynamic>?;

        double? lat;
        double? lng;
        if (geom != null && geom['type'] == 'Point') {
          final coords = geom['coordinates'] as List<dynamic>?;
          if (coords != null && coords.length >= 2) {
            lng = (coords[0] as num?)?.toDouble();
            lat = (coords[1] as num?)?.toDouble();
          }
        }

        final name = props['name'] as String? ?? 'Contato Sem Nome';
        results.add(
          ImportedTerritoryContact(
            name: name,
            phone: props['phone'] as String?,
            address: props['address'] as String?,
            status: props['status'] as String? ?? 'interessado',
            notes: props['notes'] as String?,
            latitude: lat,
            longitude: lng,
          ),
        );
      }
    } catch (_) {
      // Retorna graciosamente em caso de JSON malformado
    }

    return results;
  }

  // ===========================================================================
  // 3. FORMATO CSV (Planilhas / Excel)
  // ===========================================================================

  /// Exporta contatos para arquivo CSV delimitado por vírgula
  static String exportToCsv(List<PersonEntry> people) {
    final buffer = StringBuffer();
    buffer.writeln('Nome,Telefone,Endereço,Situação,Latitude,Longitude,Notas');

    for (final p in people) {
      if (p.deletedAt != null) continue;
      buffer.writeln([
        _csvEscape(p.name),
        _csvEscape(p.phone ?? ''),
        _csvEscape(p.address ?? ''),
        _csvEscape(p.status),
        p.latitude?.toString() ?? '',
        p.longitude?.toString() ?? '',
        _csvEscape(p.generalNotes ?? ''),
      ].join(','));
    }

    return buffer.toString();
  }

  /// Importa contatos de arquivo CSV com suporte completo a células multilinha entre aspas
  static List<ImportedTerritoryContact> importFromCsv(String csvContent) {
    final results = <ImportedTerritoryContact>[];
    if (csvContent.trim().isEmpty) return results;

    // Detecta delimitador (, ou ;)
    final firstNewline = csvContent.indexOf('\n');
    final headerSnippet = firstNewline == -1 ? csvContent : csvContent.substring(0, firstNewline);
    final separator = headerSnippet.contains(';') ? ';' : ',';

    final rows = _parseCsvRows(csvContent, separator);
    if (rows.isEmpty) return results;

    final firstRow = rows.first;
    final startIndex = (firstRow.isNotEmpty &&
            (firstRow[0].toLowerCase().contains('nome') || firstRow[0].toLowerCase().contains('name')))
        ? 1
        : 0;

    for (int i = startIndex; i < rows.length; i++) {
      final columns = rows[i];
      if (columns.isEmpty || columns.every((c) => c.trim().isEmpty)) continue;

      final name = columns.isNotEmpty ? columns[0].trim() : 'Contato Importado';
      final phone = columns.length > 1 ? columns[1].trim() : null;
      final address = columns.length > 2 ? columns[2].trim() : null;
      final status = columns.length > 3 && columns[3].trim().isNotEmpty
          ? columns[3].trim().toLowerCase()
          : 'interessado';
      final lat = columns.length > 4 ? double.tryParse(columns[4].trim()) : null;
      final lng = columns.length > 5 ? double.tryParse(columns[5].trim()) : null;
      final notes = columns.length > 6 ? columns[6].trim() : null;

      if (name.isNotEmpty) {
        results.add(
          ImportedTerritoryContact(
            name: name,
            phone: phone?.isEmpty == true ? null : phone,
            address: address?.isEmpty == true ? null : address,
            status: status,
            latitude: lat,
            longitude: lng,
            notes: notes?.isEmpty == true ? null : notes,
          ),
        );
      }
    }

    return results;
  }

  // ===========================================================================
  // HELPERS INTERNOS DE PARSE E ESCAPE
  // ===========================================================================

  static String _xmlEscape(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static String _xmlUnescape(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'");
  }

  static String? _extractFieldFromDesc(String desc, String prefix) {
    final idx = desc.indexOf(prefix);
    if (idx == -1) return null;
    final start = idx + prefix.length;
    final end = desc.indexOf('\n', start);
    final val = (end == -1 ? desc.substring(start) : desc.substring(start, end)).trim();
    return val.isEmpty ? null : _xmlUnescape(val);
  }

  static String _csvEscape(String text) {
    if (text.contains(',') || text.contains(';') || text.contains('"') || text.contains('\n')) {
      return '"${text.replaceAll('"', '""')}"';
    }
    return text;
  }

  static List<List<String>> _parseCsvRows(String content, String separator) {
    final rows = <List<String>>[];
    final currentRow = <String>[];
    final currentCell = StringBuffer();
    bool insideQuotes = false;

    for (int i = 0; i < content.length; i++) {
      final char = content[i];

      if (char == '"') {
        if (insideQuotes && i + 1 < content.length && content[i + 1] == '"') {
          currentCell.write('"');
          i++;
        } else {
          insideQuotes = !insideQuotes;
        }
      } else if (char == separator && !insideQuotes) {
        currentRow.add(currentCell.toString().trim());
        currentCell.clear();
      } else if ((char == '\n' || char == '\r') && !insideQuotes) {
        if (char == '\r' && i + 1 < content.length && content[i + 1] == '\n') {
          i++; // trata CRLF
        }
        currentRow.add(currentCell.toString().trim());
        currentCell.clear();
        if (currentRow.any((c) => c.isNotEmpty)) {
          rows.add(List.from(currentRow));
        }
        currentRow.clear();
      } else {
        currentCell.write(char);
      }
    }

    if (currentCell.isNotEmpty || currentRow.isNotEmpty) {
      currentRow.add(currentCell.toString().trim());
      if (currentRow.any((c) => c.isNotEmpty)) {
        rows.add(currentRow);
      }
    }

    return rows;
  }
}
