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

  const TicunaDiacriticsBar({
    super.key,
    this.controller,
    this.onCharacterInserted,
    this.label,
    this.compact = false,
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
              children: row1.map((char) {
                return _buildKeyButton(
                  char: char,
                  bgColor: keyBgColor,
                  borderColor: keyBorderColor,
                  textColor: textColor,
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 6),
          // Linha 2 de teclas rápidas
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: row2.map((char) {
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
      ),
    );
  }

  Widget _buildKeyButton({
    required String char,
    required Color bgColor,
    required Color borderColor,
    required Color textColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _handleTap(char),
          child: Container(
            constraints: const BoxConstraints(
              minWidth: 44,
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
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
