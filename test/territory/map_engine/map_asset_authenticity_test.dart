import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

({int value, int nextPos}) _readVarint(Uint8List buf, int pos) {
  var value = 0;
  var shift = 0;
  var i = pos;
  while (true) {
    final b = buf[i++];
    value |= (b & 0x7f) << shift;
    if ((b & 0x80) == 0) {
      return (value: value, nextPos: i);
    }
    shift += 7;
  }
}

void main() {
  group('Map Asset Authenticity & Forensic Integrity Tests (FAES M3)', () {
    final fontFile = File('assets/map/fonts/Noto Sans Regular/0-255.pbf');
    final spriteFile = File('assets/map/sprites/sprite.png');
    final sprite2xFile = File('assets/map/sprites/sprite@2x.png');
    final spriteJsonFile = File('assets/map/sprites/sprite.json');
    final sprite2xJsonFile = File('assets/map/sprites/sprite@2x.json');
    final pubspecFile = File('pubspec.yaml');

    test('Font PBF is authentic MapLibre SDF Protobuf (> 40 KB, valid fontstack header & unique (w+6)*(h+6) SDF glyphs)', () {
      expect(fontFile.existsSync(), isTrue, reason: 'Font PBF file must exist');
      final bytes = fontFile.readAsBytesSync();
      expect(
        bytes.length,
        greaterThan(40000),
        reason: 'Authentic 0-255 font PBF must be > 40 KB',
      );

      // Byte 0: 0x0A (tag 1, wire type 2 for repeated fontstack)
      expect(bytes[0], equals(0x0A));
      final outerLen = _readVarint(bytes, 1);
      expect(outerLen.nextPos + outerLen.value, equals(bytes.length));

      final fsEnd = bytes.length;
      var pos = outerLen.nextPos;
      String? fontName;
      String? fontRange;
      var glyphCount = 0;
      var visibleGlyphCount = 0;
      final uniqueBitmaps = <String>{};

      while (pos < fsEnd) {
        final tag = _readVarint(bytes, pos);
        pos = tag.nextPos;
        final fieldNum = tag.value >> 3;
        final wireType = tag.value & 7;
        if (wireType == 2) {
          final len = _readVarint(bytes, pos);
          pos = len.nextPos;
          final slice = bytes.sublist(pos, pos + len.value);
          pos += len.value;
          if (fieldNum == 1) {
            fontName = utf8.decode(slice);
          } else if (fieldNum == 2) {
            fontRange = utf8.decode(slice);
          } else if (fieldNum == 3) {
            glyphCount++;
            var gp = 0;
            var width = 0;
            var height = 0;
            Uint8List bitmap = Uint8List(0);
            while (gp < slice.length) {
              final gt = _readVarint(slice, gp);
              gp = gt.nextPos;
              final gf = gt.value >> 3;
              final gw = gt.value & 7;
              if (gw == 0) {
                final gv = _readVarint(slice, gp);
                gp = gv.nextPos;
                if (gf == 3) width = gv.value;
                if (gf == 4) height = gv.value;
              } else if (gw == 2) {
                final gl = _readVarint(slice, gp);
                gp = gl.nextPos;
                final gval = slice.sublist(gp, gp + gl.value);
                gp += gl.value;
                if (gf == 2) bitmap = gval;
              }
            }
            if (width > 0 && height > 0) {
              visibleGlyphCount++;
              // MapLibre Native SDF specification requires 3px buffer on all 4 sides
              expect(
                bitmap.length,
                equals((width + 6) * (height + 6)),
                reason: 'Every visible SDF glyph must have (width + 6) * (height + 6) bytes',
              );
              uniqueBitmaps.add(base64Encode(bitmap));
            }
          }
        } else if (wireType == 0) {
          final v = _readVarint(bytes, pos);
          pos = v.nextPos;
        }
      }

      expect(fontName, equals('Noto Sans Regular'));
      expect(fontRange, equals('0-255'));
      expect(glyphCount, greaterThanOrEqualTo(180));
      expect(visibleGlyphCount, greaterThanOrEqualTo(180));
      expect(
        uniqueBitmaps.length,
        greaterThanOrEqualTo(150),
        reason: 'Font PBF must contain distinct authentic SDF glyph bitmaps, not repeated dummy boxes',
      );
    });

    test('Sprite PNG 1x is valid RGBA image with dimensions >= 32x16', () {
      expect(spriteFile.existsSync(), isTrue);
      final bytes = spriteFile.readAsBytesSync();
      expect(bytes.length, greaterThan(100));

      // Check PNG signature: 0x89, 'P', 'N', 'G', 0x0D, 0x0A, 0x1A, 0x0A
      expect(
        bytes.sublist(0, 8),
        equals([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
      );

      // IHDR dimensions (bytes 16-23: width (4 bytes big-endian), height (4 bytes big-endian))
      final byteData = ByteData.sublistView(bytes);
      final width = byteData.getUint32(16, Endian.big);
      final height = byteData.getUint32(20, Endian.big);

      expect(width, greaterThanOrEqualTo(32));
      expect(height, greaterThanOrEqualTo(16));
    });

    test('Sprite PNG 2x is valid RGBA image with dimensions >= 64x32', () {
      expect(sprite2xFile.existsSync(), isTrue);
      final bytes = sprite2xFile.readAsBytesSync();
      expect(bytes.length, greaterThan(120));

      final byteData = ByteData.sublistView(bytes);
      final width = byteData.getUint32(16, Endian.big);
      final height = byteData.getUint32(20, Endian.big);

      expect(width, greaterThanOrEqualTo(64));
      expect(height, greaterThanOrEqualTo(32));
    });

    test('Sprite JSON manifests define non-overlapping bounds within atlas dimensions', () {
      expect(spriteJsonFile.existsSync(), isTrue);
      final json1x =
          jsonDecode(spriteJsonFile.readAsStringSync()) as Map<String, dynamic>;
      expect(json1x.containsKey('marker-15'), isTrue);
      expect(json1x.containsKey('landmark-15'), isTrue);

      final m15 = json1x['marker-15'] as Map<String, dynamic>;
      final l15 = json1x['landmark-15'] as Map<String, dynamic>;

      expect(m15['x'] + m15['width'], lessThanOrEqualTo(32));
      expect(m15['y'] + m15['height'], lessThanOrEqualTo(16));
      expect(l15['x'] + l15['width'], lessThanOrEqualTo(32));
      expect(l15['y'] + l15['height'], lessThanOrEqualTo(16));

      // No collision between marker and landmark
      expect(m15['x'] + m15['width'], lessThanOrEqualTo(l15['x']));

      final json2x = jsonDecode(
        sprite2xJsonFile.readAsStringSync(),
      ) as Map<String, dynamic>;
      final m30 = json2x['marker-15'] as Map<String, dynamic>;
      final l30 = json2x['landmark-15'] as Map<String, dynamic>;

      expect(m30['x'] + m30['width'], lessThanOrEqualTo(64));
      expect(m30['y'] + m30['height'], lessThanOrEqualTo(32));
      expect(l30['x'] + l30['width'], lessThanOrEqualTo(64));
      expect(l30['y'] + l30['height'], lessThanOrEqualTo(32));
      expect(m30['x'] + m30['width'], lessThanOrEqualTo(l30['x']));
    });

    test(
      'pubspec.yaml explicitly declares all font and sprite directories',
      () {
        final pubspecContent = pubspecFile.readAsStringSync();
        expect(pubspecContent, contains('assets/map/'));
        expect(pubspecContent, contains('assets/map/fonts/'));
        expect(pubspecContent, contains('assets/map/fonts/Noto Sans Regular/'));
        expect(pubspecContent, contains('assets/map/sprites/'));
      },
    );
  });
}
