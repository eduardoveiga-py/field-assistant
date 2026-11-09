import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../ticuna_unicode_helper.dart';

/// Barra de botões virtuais de toque rápido com caracteres e acentuações
/// especiais da língua Ticuna (ideal para digitação rápida no iPad, iPhone e Android).
class TicunaDiacriticsBar extends StatelessWidget {
  /// Controlador de texto ativo para inserção direta na posição do cursor.
  final TextEditingController? controller;

  /// Callback opcional chamado quando qualquer caractere é selecionado.
  final ValueChanged<String>? onCharacterInserted;

  /// Título opcional da barra (ex: 'Acentuação Especial Ticuna')
  final String? label;

  /// Se deve exibir borda e fundo estilizados de teclado virtual.
  final bool compact;

  /// Lista dinâmica de diacríticos do idioma ativo. Se vazia, a barra é ocultada.
  final List<String>? diacritics;

  const TicunaDiacriticsBar({
    super.key,
    this.controller,
    this.onCharacterInserted,
    this.label,
    this.compact = false,
    this.diacritics,
  });

  /// Linha 1 de caracteres especiais canônicos do WOL (6 minúsculas):
  /// ĩ, ü̃, ü̃́, ũ, ã́, ẽ
  static const List<String> row1 = TicunaUnicodeHelper.row1;

  /// Linha 2 de caracteres especiais canônicos do WOL (6 maiúsculas):
  /// Ĩ, Ü̃, Ü̃́, Ũ, Ã́, Ẽ
  static const List<String> row2 = TicunaUnicodeHelper.row2;

  /// Insere o caractere na posição exata da seleção ou cursor do TextEditingController.
  static void insertCharacter(TextEditingController controller, String char) {
    final text = controller.text;
    final selection = controller.selection;

    int start = selection.start;
    int end = selection.end;

    if (start < 0 || end < 0) {
      start = text.length;
      end = text.length;
    }

    final newText = text.replaceRange(start, end, char);
    final newCursorPosition = start + char.length;

    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursorPosition),
    );
  }

  void _handleTap(String char) {
    HapticFeedback.lightImpact();
    if (controller != null) {
      insertCharacter(controller!, char);
    }
    onCharacterInserted?.call(char);
  }

  @override
  Widget build(BuildContext context) {
    final effectiveDiacritics = diacritics;
    if (effectiveDiacritics != null && effectiveDiacritics.isEmpty) {
      return const SizedBox.shrink();
    }

    final List<String> displayRow1;
    final List<String> displayRow2;
    if (effectiveDiacritics != null) {
      final mid = (effectiveDiacritics.length / 2).ceil();
      displayRow1 = effectiveDiacritics.sublist(0, mid);
      displayRow2 = effectiveDiacritics.sublist(mid);
    } else {
      displayRow1 = row1;
      displayRow2 = row2;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final keyBgColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFF1F5F9);
    final keyBorderColor = isDark
        ? const Color(0xFF475569)
        : const Color(0xFFCBD5E1);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 10,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : AppTheme.primaryBlue.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label != null) ...[
            Row(
              children: [
                const Icon(
                  Icons.keyboard_outlined,
                  size: 14,
                  color: AppTheme.primaryBlue,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryBlue,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          // Linha 1 de teclas rápidas
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: displayRow1.map((char) {
                return _buildKeyButton(
                  char: char,
                  bgColor: keyBgColor,
                  borderColor: keyBorderColor,
                  textColor: textColor,
                );
              }).toList(),
            ),
          ),
          if (displayRow2.isNotEmpty) ...[
            const SizedBox(height: 6),
            // Linha 2 de teclas rápidas
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: displayRow2.map((char) {
                  return _buildKeyButton(
                    char: char,
                    bgColor: keyBgColor,
                    borderColor: keyBorderColor,
                    textColor: textColor,
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String getCharDescription(String char) {
    switch (char) {
      case 'ĩ':
        return 'ĩ (i com til)';
      case 'ü\u0303':
        return 'ü̃ (ü com til)';
      case 'ü\u0303\u0301':
        return 'ü̃́ (ü com til e agudo)';
      case 'ũ':
        return 'ũ (u com til)';
      case 'ã\u0301':
        return 'ã́ (ã com agudo)';
      case 'ẽ':
        return 'ẽ (e com til)';
      case 'Ĩ':
        return 'Ĩ (I maiúsculo com til)';
      case 'Ü\u0303':
        return 'Ü̃ (Ü maiúsculo com til)';
      case 'Ü\u0303\u0301':
        return 'Ü̃́ (Ü maiúsculo com til e agudo)';
      case 'Ũ':
        return 'Ũ (U maiúsculo com til)';
      case 'Ã\u0301':
        return 'Ã́ (Ã maiúsculo com agudo)';
      case 'Ẽ':
        return 'Ẽ (E maiúsculo com til)';
      default:
        return char;
    }
  }

  Widget _buildKeyButton({
    required String char,
    required Color bgColor,
    required Color borderColor,
    required Color textColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Tooltip(
        message: getCharDescription(char),
        child: Material(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _handleTap(char),
            child: Container(
              constraints: const BoxConstraints(
                minWidth: 46,
                minHeight: 48,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 1,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                char,
                style: TicunaUnicodeHelper.textStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
