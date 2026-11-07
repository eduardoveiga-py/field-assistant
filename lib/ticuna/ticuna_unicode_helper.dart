import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Utilitário central de renderização tipográfica e normalização canônica Unicode
/// para os caracteres especiais e diacríticos sobrepostos da língua Ticuna.
class TicunaUnicodeHelper {
  TicunaUnicodeHelper._();

  /// Famílias de fontes em cadeia de fallback com suporte a OpenType GPOS
  /// (posicionamento de glifos mark-to-base e mark-to-mark para múltiplos diacríticos).
  static const List<String> fontFallback = [
    'Gentium Plus',
    'Charis SIL',
    'Doulos SIL',
    'Noto Sans',
    'Segoe UI Historic',
    'Lucida Sans Unicode',
    'Arial Unicode MS',
    'DejaVu Sans',
    'Calibri',
    'Segoe UI',
    'Roboto',
    'Arial',
    'sans-serif',
  ];

  /// Linha 1 de caracteres especiais da língua Ticuna (9 teclas):
  /// ĩ, ü̃, ǘ̃, ũ, ã́, ẽ, Ĩ, Ü̃, Ǘ̃
  static const List<String> row1 = [
    'ĩ', // U+0129 (precomposto)
    'ü\u0303', // U+00FC + U+0303 (ü com til centralizado acima)
    'ǘ\u0303', // U+01D8 + U+0303 (ǘ com til centralizado acima)
    'ũ', // U+0169 (precomposto)
    'ã\u0301', // U+00E3 + U+0301 (ã com acento agudo)
    'ẽ', // U+1EBD (precomposto)
    'Ĩ', // U+0128 (precomposto)
    'Ü\u0303', // U+00DC + U+0303 (Ü com til)
    'Ǘ\u0303', // U+01D7 + U+0303 (Ǘ com til)
  ];

  /// Linha 2 de caracteres especiais da língua Ticuna (3 teclas):
  /// Ũ, Ã́, Ẽ
  static const List<String> row2 = [
    'Ũ', // U+0168 (precomposto)
    'Ã\u0301', // U+00C3 + U+0301 (Ã com acento agudo)
    'Ẽ', // U+1EBC (precomposto)
  ];

  /// Normaliza texto para a forma canônica estável do Ticuna,
  /// garantindo que qualquer variação de entrada (teclado virtual, digitação manual,
  /// diacríticos soltos/espaçados como ~ ou ´, copiar e colar) seja convertida
  /// fielmente para a sequência Unicode correta com acentos centralizados.
  static String normalize(String input) {
    if (input.isEmpty) return input;
    var result = input;

    // 1. Converte diacríticos soltos/espaçados (~, ˜, ´, ¨) colados na vogal
    // que causam o defeito "diacrítico separado ao lado da letra"
    result = result
        // Variações de ǘ̃ (u com trema + agudo + til)
        .replaceAll('ǘ~', 'ǘ\u0303')
        .replaceAll('ǘ˜', 'ǘ\u0303')
        .replaceAll('Ǘ~', 'Ǘ\u0303')
        .replaceAll('Ǘ˜', 'Ǘ\u0303')
        .replaceAll('ü\u0301~', 'ǘ\u0303')
        .replaceAll('ü\u0301˜', 'ǘ\u0303')
        .replaceAll('Ü\u0301~', 'Ǘ\u0303')
        .replaceAll('Ü\u0301˜', 'Ǘ\u0303')
        .replaceAll('ü~\u0301', 'ǘ\u0303')
        .replaceAll('Ü~\u0301', 'Ǘ\u0303')
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

    // 2. Normaliza variações decompostas e permutações de combining characters
    result = result
        // Permutações triplas para ǘ̃ e Ǘ̃
        .replaceAll('u\u0308\u0301\u0303', 'ǘ\u0303')
        .replaceAll('u\u0308\u0303\u0301', 'ǘ\u0303')
        .replaceAll('u\u0303\u0308\u0301', 'ǘ\u0303')
        .replaceAll('u\u0301\u0308\u0303', 'ǘ\u0303')
        .replaceAll('ü\u0301\u0303', 'ǘ\u0303')
        .replaceAll('ü\u0303\u0301', 'ǘ\u0303')
        .replaceAll('U\u0308\u0301\u0303', 'Ǘ\u0303')
        .replaceAll('U\u0308\u0303\u0301', 'Ǘ\u0303')
        .replaceAll('U\u0303\u0308\u0301', 'Ǘ\u0303')
        .replaceAll('U\u0301\u0308\u0303', 'Ǘ\u0303')
        .replaceAll('Ü\u0301\u0303', 'Ǘ\u0303')
        .replaceAll('Ü\u0303\u0301', 'Ǘ\u0303')
        // Permutações duplas para ü̃ e Ü̃
        .replaceAll('u\u0308\u0303', 'ü\u0303')
        .replaceAll('u\u0303\u0308', 'ü\u0303')
        .replaceAll('U\u0308\u0303', 'Ü\u0303')
        .replaceAll('U\u0303\u0308', 'Ü\u0303')
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
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      fontStyle: fontStyle,
      decoration: decoration,
      height: height,
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

