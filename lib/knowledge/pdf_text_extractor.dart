import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Extrator puro Dart de texto embutido em arquivos PDF (camada de texto padrão / FlateDecode).
/// Compatível com todas as plataformas (iOS, Android, Windows e Web PWA) sem dependências nativas.
/// Nota: PDFs digitalizados exclusivamente como imagem (scan sem camada textual) retornam string vazia.
class PdfTextExtractor {
  PdfTextExtractor._();

  static const int maxPdfBytes = 20 * 1024 * 1024;
  static const int maxExtractedChars = 120000;

  /// Extrai texto pesquisável dos bytes de um PDF, respeitando limites de memória e tamanho.
  static String extractText(Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > maxPdfBytes) return '';

    final rawLatin = latin1.decode(bytes, allowInvalid: true);
    if (!rawLatin.contains('%PDF-')) return '';

    final out = StringBuffer();
    var cursor = 0;

    while (cursor < rawLatin.length && out.length < maxExtractedChars) {
      final streamIdx = rawLatin.indexOf('stream', cursor);
      if (streamIdx == -1) break;

      // Confirma delimitador exato de token `stream` seguido de \r\n, \n ou \r
      var contentStart = streamIdx + 6;
      if (contentStart >= rawLatin.length) break;
      if (rawLatin.codeUnitAt(contentStart) == 0x0D &&
          contentStart + 1 < rawLatin.length &&
          rawLatin.codeUnitAt(contentStart + 1) == 0x0A) {
        contentStart += 2;
      } else if (rawLatin.codeUnitAt(contentStart) == 0x0A ||
          rawLatin.codeUnitAt(contentStart) == 0x0D) {
        contentStart += 1;
      } else {
        cursor = streamIdx + 6;
        continue;
      }

      final endIdx = rawLatin.indexOf('endstream', contentStart);
      if (endIdx == -1) break;

      var contentEnd = endIdx;
      while (contentEnd > contentStart &&
          (rawLatin.codeUnitAt(contentEnd - 1) == 0x0A ||
              rawLatin.codeUnitAt(contentEnd - 1) == 0x0D)) {
        contentEnd--;
      }

      final dictStart = (streamIdx - 512) < 0 ? 0 : streamIdx - 512;
      final preceding = rawLatin.substring(dictStart, streamIdx);
      final isFlate = preceding.contains('/FlateDecode');

      String streamText = '';
      if (contentEnd > contentStart) {
        final slice = bytes.sublist(contentStart, contentEnd);
        if (isFlate) {
          try {
            final inflated = const ZLibDecoder().decodeBytes(slice);
            streamText = latin1.decode(inflated, allowInvalid: true);
          } catch (_) {
            // Stream comprimido com algoritmo alternativo ou criptografado; ignora sem falhar.
            streamText = '';
          }
        } else {
          streamText = latin1.decode(slice, allowInvalid: true);
        }
      }

      if (streamText.isNotEmpty && streamText.contains('BT')) {
        _extractTextOperators(streamText, out);
      }

      cursor = endIdx + 9;
    }

    // Fallback: alguns PDFs gerados simples colocam `BT ... ET` fora de `stream`.
    if (out.isEmpty && rawLatin.contains('BT') && rawLatin.contains('Tj')) {
      _extractTextOperators(rawLatin, out);
    }

    final text = out
        .toString()
        .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    if (text.length > maxExtractedChars) {
      return text.substring(0, maxExtractedChars);
    }
    return text;
  }

  static void _extractTextOperators(String streamText, StringBuffer out) {
    final len = streamText.length;
    var i = 0;

    while (i < len && out.length < maxExtractedChars) {
      final ch = streamText.codeUnitAt(i);
      // Literal string `( ... )` seguida possivelmente de Tj / ' / "
      if (ch == 0x28 /* ( */ ) {
        final parsed = _readLiteralString(streamText, i);
        i = parsed.nextIndex;
        final op = _peekOperator(streamText, i);
        if (op == 'Tj' || op == "'" || op == '"') {
          if (parsed.text.isNotEmpty) {
            out.write(parsed.text);
            if (op == "'" || op == '"') {
              out.write('\n');
            } else {
              out.write(' ');
            }
          }
        }
        continue;
      }

      // Hex string `< ... >` seguida de Tj / ' / "
      if (ch == 0x3C /* < */ &&
          i + 1 < len &&
          streamText.codeUnitAt(i + 1) != 0x3C /* << */ ) {
        final closeIdx = streamText.indexOf('>', i + 1);
        if (closeIdx != -1) {
          final hexBody = streamText.substring(i + 1, closeIdx);
          i = closeIdx + 1;
          final op = _peekOperator(streamText, i);
          if (op == 'Tj' || op == "'" || op == '"') {
            final decoded = _decodeHexPdfString(hexBody);
            if (decoded.isNotEmpty) {
              out.write(decoded);
              out.write(' ');
            }
          }
          continue;
        }
      }

      // Array `[ ... ] TJ`
      if (ch == 0x5B /* [ */ ) {
        final arrParsed = _readTextArray(streamText, i);
        i = arrParsed.nextIndex;
        final op = _peekOperator(streamText, i);
        if (op == 'TJ' && arrParsed.text.isNotEmpty) {
          out.write(arrParsed.text);
          out.write(' ');
        }
        continue;
      }

      // Quebras de linha por operador Td/TD/T*
      if (ch == 0x54 /* T */ && i + 1 < len) {
        final next = streamText.codeUnitAt(i + 1);
        if ((next == 0x2A /* * */ ||
                next == 0x64 /* d */ ||
                next == 0x44 /* D */ ) &&
            (i == 0 || _isPdfDelimiterOrSpace(streamText.codeUnitAt(i - 1)))) {
          if (out.isNotEmpty && !out.toString().endsWith('\n')) {
            out.write('\n');
          }
        }
      }

      i++;
    }
  }

  static bool _isPdfDelimiterOrSpace(int c) =>
      c <= 0x20 || c == 0x29 /* ) */ || c == 0x5D /* ] */ || c == 0x3E /* > */;

  static String _peekOperator(String src, int from) {
    var j = from;
    while (j < src.length && src.codeUnitAt(j) <= 0x20) {
      j++;
    }
    if (j >= src.length) return '';
    final ch = src.codeUnitAt(j);
    if (ch == 0x27 /* ' */ || ch == 0x22 /* " */ ) {
      return String.fromCharCode(ch);
    }
    if (j + 2 <= src.length) {
      final two = src.substring(j, j + 2);
      if (two == 'Tj' || two == 'TJ') return two;
    }
    return '';
  }

  static ({String text, int nextIndex}) _readLiteralString(
    String src,
    int openParenIdx,
  ) {
    final buf = StringBuffer();
    var depth = 1;
    var i = openParenIdx + 1;
    while (i < src.length && depth > 0) {
      final c = src.codeUnitAt(i);
      if (c == 0x5C /* \ */ && i + 1 < src.length) {
        final esc = src.codeUnitAt(i + 1);
        switch (esc) {
          case 0x6E: // \n
            buf.write('\n');
            i += 2;
            continue;
          case 0x72: // \r
            buf.write('\n');
            i += 2;
            continue;
          case 0x74: // \t
            buf.write('\t');
            i += 2;
            continue;
          case 0x62: // \b
          case 0x66: // \f
            i += 2;
            continue;
          case 0x28: // \(
          case 0x29: // \)
          case 0x5C: // \\
            buf.writeCharCode(esc);
            i += 2;
            continue;
          default:
            if (esc >= 0x30 && esc <= 0x37) {
              var oct = '';
              var k = i + 1;
              while (k < src.length &&
                  oct.length < 3 &&
                  src.codeUnitAt(k) >= 0x30 &&
                  src.codeUnitAt(k) <= 0x37) {
                oct += src[k];
                k++;
              }
              final code = int.tryParse(oct, radix: 8);
              if (code != null && code >= 0x20) {
                buf.writeCharCode(code);
              }
              i = k;
              continue;
            }
            buf.writeCharCode(esc);
            i += 2;
            continue;
        }
      } else if (c == 0x28 /* ( */ ) {
        depth++;
        buf.writeCharCode(c);
        i++;
      } else if (c == 0x29 /* ) */ ) {
        depth--;
        if (depth > 0) buf.writeCharCode(c);
        i++;
      } else {
        buf.writeCharCode(c);
        i++;
      }
    }
    return (text: buf.toString(), nextIndex: i);
  }

  static ({String text, int nextIndex}) _readTextArray(
    String src,
    int openBracketIdx,
  ) {
    final buf = StringBuffer();
    var i = openBracketIdx + 1;
    while (i < src.length) {
      final c = src.codeUnitAt(i);
      if (c == 0x5D /* ] */ ) {
        return (text: buf.toString(), nextIndex: i + 1);
      }
      if (c == 0x28 /* ( */ ) {
        final lit = _readLiteralString(src, i);
        buf.write(lit.text);
        i = lit.nextIndex;
        continue;
      }
      if (c == 0x3C /* < */ &&
          i + 1 < src.length &&
          src.codeUnitAt(i + 1) != 0x3C) {
        final close = src.indexOf('>', i + 1);
        if (close != -1) {
          buf.write(_decodeHexPdfString(src.substring(i + 1, close)));
          i = close + 1;
          continue;
        }
      }
      // Kerning negativo grande indica espaçamento entre palavras no array TJ
      if (c == 0x2D /* - */ || (c >= 0x30 && c <= 0x39)) {
        var j = i + 1;
        while (j < src.length &&
            ((src.codeUnitAt(j) >= 0x30 && src.codeUnitAt(j) <= 0x39) ||
                src.codeUnitAt(j) == 0x2E)) {
          j++;
        }
        final val = double.tryParse(src.substring(i, j));
        if (val != null && val < -120 && buf.isNotEmpty) {
          buf.write(' ');
        }
        i = j;
        continue;
      }
      i++;
    }
    return (text: buf.toString(), nextIndex: i);
  }

  static String _decodeHexPdfString(String rawHex) {
    final clean = rawHex.replaceAll(RegExp(r'\s+'), '');
    if (clean.length < 2) return '';
    final padded = clean.length.isOdd ? '${clean}0' : clean;
    final bytes = <int>[];
    for (var i = 0; i + 1 < padded.length; i += 2) {
      final b = int.tryParse(padded.substring(i, i + 2), radix: 16);
      if (b == null) return '';
      bytes.add(b);
    }
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      final units = <int>[];
      for (var i = 2; i + 1 < bytes.length; i += 2) {
        units.add((bytes[i] << 8) | bytes[i + 1]);
      }
      return String.fromCharCodes(units);
    }
    return latin1.decode(bytes, allowInvalid: true);
  }
}
