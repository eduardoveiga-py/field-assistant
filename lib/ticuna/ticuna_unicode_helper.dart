import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Utilitário central de renderização tipográfica e normalização canônica Unicode
/// para os caracteres especiais e diacríticos sobrepostos da língua Ticuna.
class TicunaUnicodeHelper {
  TicunaUnicodeHelper._();

  /// Famílias de fontes em cadeia de fallback com suporte a OpenType GPOS
  /// (posicionamento de glifos mark-to-base e mark-to-mark para múltiplos diacríticos).
  static const List<String> fontFallback = [
    'Noto Sans',
    'Charis SIL',
    'Gentium Plus',
    'Doulos SIL',
    '.AppleSystemUIFont',
    '-apple-system',
    'Helvetica Neue',
    'Arial Unicode MS',
    'Segoe UI Historic',
    'Lucida Sans Unicode',
    'DejaVu Sans',
    'Calibri',
    'Segoe UI',
    'Roboto',
    'Arial',
    'sans-serif',
  ];

  /// Linha 1 de caracteres especiais da língua Ticuna canônicos do WOL (6 minúsculas):
  /// ĩ, ü̃, ü̃́, ũ, ã́, ẽ
  static const List<String> row1 = [
    'ĩ', // U+0129 (precomposto)
    'ü\u0303', // U+00FC + U+0303 (ü com til centralizado acima)
    'ü\u0303\u0301', // U+00FC + U+0303 + U+0301 (ü com til e agudo perfeitamente empilhados como no WOL)
    'ũ', // U+0169 (precomposto)
    'ã\u0301', // U+00E3 + U+0301 (ã com acento agudo)
    'ẽ', // U+1EBD (precomposto)
  ];

  /// Linha 2 de caracteres especiais da língua Ticuna canônicos do WOL (6 maiúsculas):
  /// Ĩ, Ü̃, Ü̃́, Ũ, Ã́, Ẽ
  static const List<String> row2 = [
    'Ĩ', // U+0128 (precomposto)
    'Ü\u0303', // U+00DC + U+0303 (Ü com til)
    'Ü\u0303\u0301', // U+00DC + U+0303 + U+0301 (Ü com til e agudo perfeitamente empilhados como no WOL)
    'Ũ', // U+0168 (precomposto)
    'Ã\u0301', // U+00C3 + U+0301 (Ã com acento agudo)
    'Ẽ', // U+1EBC (precomposto)
  ];

  /// Todas as 12 vogais canônicas acentuadas da língua Ticuna presentes no WOL.
  static const List<String> canonicalVowels = [...row1, ...row2];

  /// Normaliza texto para a forma canônica estável do Ticuna (idêntica ao WOL jw.org),
  /// garantindo que qualquer variação de entrada (teclado virtual, digitação manual,
  /// diacríticos soltos/espaçados como ~ ou ´, copiar e colar) seja convertida
  /// fielmente para a sequência Unicode correta com acentos centralizados.
  static String normalize(String input) {
    if (input.isEmpty) return input;
    var result = input;

    // 1. Converte diacríticos soltos/espaçados (~, ˜, ´, ¨) colados na vogal
    // que causam o defeito "diacrítico separado ao lado da letra"
    result = result
        // Variações de ü̃́ (u com trema + til + agudo canônico do WOL)
        .replaceAll('ǘ\u0303', 'ü\u0303\u0301')
        .replaceAll('ǘ~', 'ü\u0303\u0301')
        .replaceAll('ǘ˜', 'ü\u0303\u0301')
        .replaceAll('ǘ´', 'ü\u0303\u0301')
        .replaceAll('Ǘ\u0303', 'Ü\u0303\u0301')
        .replaceAll('Ǘ~', 'Ü\u0303\u0301')
        .replaceAll('Ǘ˜', 'Ü\u0303\u0301')
        .replaceAll('Ǘ´', 'Ü\u0303\u0301')
        .replaceAll('ü\u0301~', 'ü\u0303\u0301')
        .replaceAll('ü\u0301˜', 'ü\u0303\u0301')
        .replaceAll('Ü\u0301~', 'Ü\u0303\u0301')
        .replaceAll('Ü\u0301˜', 'Ü\u0303\u0301')
        .replaceAll('ü~\u0301', 'ü\u0303\u0301')
        .replaceAll('Ü~\u0301', 'Ü\u0303\u0301')
        .replaceAll('ü~´', 'ü\u0303\u0301')
        .replaceAll('Ü~´', 'Ü\u0303\u0301')
        .replaceAll('ü´~', 'ü\u0303\u0301')
        .replaceAll('Ü´~', 'Ü\u0303\u0301')
        .replaceAll('ü\u0303´', 'ü\u0303\u0301')
        .replaceAll('Ü\u0303´', 'Ü\u0303\u0301')
        .replaceAll('ü\u0303\'', 'ü\u0303\u0301')
        .replaceAll('Ü\u0303\'', 'Ü\u0303\u0301')
        // Variações de ü̃ (u com trema + til)
        .replaceAll('ü~', 'ü\u0303')
        .replaceAll('ü˜', 'ü\u0303')
        .replaceAll('Ü~', 'Ü\u0303')
        .replaceAll('Ü˜', 'Ü\u0303')
        // Variações de ã́ (a com til + agudo)
        .replaceAll('ã´', 'ã\u0301')
        .replaceAll('ã\'', 'ã\u0301')
        .replaceAll('ãˊ', 'ã\u0301')
        .replaceAll('Ã´', 'Ã\u0301')
        .replaceAll('Ã\'', 'Ã\u0301')
        .replaceAll('Ãˊ', 'Ã\u0301')
        .replaceAll('á~', 'ã\u0301')
        .replaceAll('á˜', 'ã\u0301')
        .replaceAll('Á~', 'Ã\u0301')
        .replaceAll('Á˜', 'Ã\u0301')
        // Variações simples com til solto (~ ou ˜)
        .replaceAll('i~', 'ĩ')
        .replaceAll('i˜', 'ĩ')
        .replaceAll('I~', 'Ĩ')
        .replaceAll('I˜', 'Ĩ')
        .replaceAll('u~', 'ũ')
        .replaceAll('u˜', 'ũ')
        .replaceAll('U~', 'Ũ')
        .replaceAll('U˜', 'Ũ')
        .replaceAll('e~', 'ẽ')
        .replaceAll('e˜', 'ẽ')
        .replaceAll('E~', 'Ẽ')
        .replaceAll('E˜', 'Ẽ')
        .replaceAll('a~', 'ã')
        .replaceAll('a˜', 'ã')
        .replaceAll('A~', 'Ã')
        .replaceAll('A˜', 'Ã')
        .replaceAll('o~', 'õ')
        .replaceAll('o˜', 'õ')
        .replaceAll('O~', 'Õ')
        .replaceAll('O˜', 'Õ');

    // 2. Normaliza variações decompostas e permutações de combining characters para a forma exata do WOL
    result = result
        // Permutações triplas para ü̃́ e Ü̃́ (ü\u0303\u0301 e Ü\u0303\u0301)
        .replaceAll('u\u0308\u0301\u0303', 'ü\u0303\u0301')
        .replaceAll('u\u0308\u0303\u0301', 'ü\u0303\u0301')
        .replaceAll('u\u0303\u0308\u0301', 'ü\u0303\u0301')
        .replaceAll('u\u0301\u0308\u0303', 'ü\u0303\u0301')
        .replaceAll('ü\u0301\u0303', 'ü\u0303\u0301')
        .replaceAll('ü\u0303\u0301', 'ü\u0303\u0301')
        .replaceAll('U\u0308\u0301\u0303', 'Ü\u0303\u0301')
        .replaceAll('U\u0308\u0303\u0301', 'Ü\u0303\u0301')
        .replaceAll('U\u0303\u0308\u0301', 'Ü\u0303\u0301')
        .replaceAll('U\u0301\u0308\u0303', 'Ü\u0303\u0301')
        .replaceAll('Ü\u0301\u0303', 'Ü\u0303\u0301')
        .replaceAll('Ü\u0303\u0301', 'Ü\u0303\u0301')
        // Permutações duplas para ü̃ e Ü̃
        .replaceAll('u\u0308\u0303', 'ü\u0303')
        .replaceAll('u\u0303\u0308', 'ü\u0303')
        .replaceAll('U\u0308\u0303', 'Ü\u0303')
        .replaceAll('U\u0303\u0308', 'Ü\u0303')
        // Variações onde trema foi colado sobre ũ/Ũ
        .replaceAll('ũ\u0308\u0301', 'ü\u0303\u0301')
        .replaceAll('ũ\u0301\u0308', 'ü\u0303\u0301')
        .replaceAll('Ũ\u0308\u0301', 'Ü\u0303\u0301')
        .replaceAll('Ũ\u0301\u0308', 'Ü\u0303\u0301')
        .replaceAll('ũ\u0308', 'ü\u0303')
        .replaceAll('Ũ\u0308', 'Ü\u0303')
        .replaceAll('ũ¨', 'ü\u0303')
        .replaceAll('Ũ¨', 'Ü\u0303')
        // Correção defensiva para o termo canônico "Duü̃" (pessoa/gente) caso digitado como Duũũ ou Duũ
        .replaceAll('Duũũ', 'Duü\u0303')
        .replaceAll('duũũ', 'duü\u0303')
        .replaceAll('Duũ', 'Duü\u0303')
        .replaceAll('duũ', 'duü\u0303')
        // Permutações para ã́ e Ã́
        .replaceAll('a\u0303\u0301', 'ã\u0301')
        .replaceAll('a\u0301\u0303', 'ã\u0301')
        .replaceAll('A\u0303\u0301', 'Ã\u0301')
        .replaceAll('A\u0301\u0303', 'Ã\u0301')
        .replaceAll('\u00E1\u0303', 'ã\u0301') // á + tilde
        .replaceAll('\u00C1\u0303', 'Ã\u0301') // Á + tilde
        // Vogais simples com til
        .replaceAll('i\u0303', 'ĩ')
        .replaceAll('I\u0303', 'Ĩ')
        .replaceAll('u\u0303', 'ũ')
        .replaceAll('U\u0303', 'Ũ')
        .replaceAll('e\u0303', 'ẽ')
        .replaceAll('E\u0303', 'Ẽ')
        .replaceAll('a\u0303', 'ã')
        .replaceAll('A\u0303', 'Ã')
        .replaceAll('o\u0303', 'õ')
        .replaceAll('O\u0303', 'Õ');

    return result;
  }

  /// Estilização tipográfica otimizada para textos em língua Ticuna,
  /// evitando cortes de altura (height clipping) em vogais com acentos múltiplos
  /// e injetando as fontes adequadas para suporte Unicode avançado (GPOS).
  static TextStyle textStyle({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    FontStyle? fontStyle,
    TextDecoration? decoration,
    double? height,
  }) {
    TextStyle style;
    if (GoogleFonts.config.allowRuntimeFetching) {
      style = GoogleFonts.notoSans(
        textStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          letterSpacing: letterSpacing,
          fontStyle: fontStyle,
          decoration: decoration,
          height: height,
        ),
      );
    } else {
      style = TextStyle(
        fontFamily: 'Noto Sans',
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        fontStyle: fontStyle,
        decoration: decoration,
        height: height,
      );
    }
    return style.copyWith(
      fontFamilyFallback: fontFallback,
    );
  }
}

/// Formatter de texto para TextFields que normaliza diacríticos Ticuna em tempo real.
class TicunaInputFormatter extends TextInputFormatter {
  const TicunaInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final normalized = TicunaUnicodeHelper.normalize(newValue.text);
    if (normalized == newValue.text) return newValue;

    final diff = normalized.length - newValue.text.length;
    final newOffset =
        (newValue.selection.baseOffset + diff).clamp(0, normalized.length);
    return TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: newOffset),
    );
  }
}

