import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

/// Exibe um modal adaptativo em conformidade com a Regra 10 do projeto:
/// - Em telas > 600pt (iPads, tablets, navegadores desktop): renderiza como [Dialog]
///   flutuante centralizado com maxWidth 720, maxHeight 0.85 * viewportHeight,
///   cantos 100% arredondados (24pt), sombra suave e botão de fechamento explícito.
/// - Em telas mobile (<= 600pt): renderiza como folha inferior ([showModalBottomSheet])
///   com limites estritos de altura (maxHeight 0.88 * viewportHeight).
Future<T?> showAdaptiveMinistrySheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext context, ScrollController? scrollController) builder,
  String? title,
  Widget? titleLeading,
  String? subtitle,
  bool isDismissible = true,
  bool enableDrag = true,
  EdgeInsetsGeometry? contentPadding,
}) {
  final mediaQuery = MediaQuery.of(context);
  final isTabletOrDesktop = mediaQuery.size.width > 600;
  final isDark = Theme.of(context).brightness == Brightness.dark;

  if (isTabletOrDesktop) {
    return showDialog<T>(
      context: context,
      barrierDismissible: isDismissible,
      builder: (dialogContext) {
        final maxHeight = mediaQuery.size.height * 0.85;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          elevation: 0,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 720,
                maxHeight: maxHeight,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Cabeçalho institucional com botão "✕" de fechar no topo
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF0F172A).withValues(alpha: 0.6)
                            : const Color(0xFFF8FAFC),
                        border: Border(
                          bottom: BorderSide(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.06),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          if (titleLeading != null) ...[
                            titleLeading,
                            const SizedBox(width: 12),
                          ],
                          if (title != null)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    title,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (subtitle != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      subtitle,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textMuted,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            )
                          else
                            const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: 'Fechar',
                            visualDensity: VisualDensity.compact,
                            onPressed: () => Navigator.of(dialogContext).pop(),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: Padding(
                        padding: contentPadding ?? EdgeInsets.zero,
                        child: builder(dialogContext, null),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Modo Mobile (<= 600pt)
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final bottomInset = MediaQuery.viewInsetsOf(sheetContext).bottom;
      final maxHeight = mediaQuery.size.height * 0.88;

      return AnimatedPadding(
        padding: EdgeInsets.only(bottom: bottomInset),
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: maxHeight,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Barra de arrasto superior
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[700] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                if (title != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      children: [
                        if (titleLeading != null) ...[
                          titleLeading,
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => Navigator.of(sheetContext).pop(),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                ],
                Flexible(
                  child: Padding(
                    padding: contentPadding ?? EdgeInsets.zero,
                    child: builder(sheetContext, null),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
