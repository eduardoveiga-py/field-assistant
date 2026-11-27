import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

/// Exibe um modal adaptativo responsivo para Tablet/iPad/Desktop e Mobile:
/// - Responde dinamicamente ao teclado virtual (`viewInsets.bottom`) mantendo área máxima
///   útil de escrita em iPhone, Android e iPad;
/// - Suporta alternância para Tela Cheia (`enableFullscreenToggle`) para foco em digitação;
/// - Suporta `bottomBarBuilder` para barra de ações fixa fora da rolagem.
Future<T?> showAdaptiveMinistrySheet<T>({
  required BuildContext context,
  required Widget Function(
    BuildContext context,
    ScrollController? scrollController,
  )
  builder,
  String? title,
  Widget? titleLeading,
  String? subtitle,
  bool isDismissible = true,
  bool enableDrag = true,
  EdgeInsetsGeometry? contentPadding,
  bool enableFullscreenToggle = true,
  Widget Function(BuildContext context)? bottomBarBuilder,
}) {
  final isTabletOrDesktop = MediaQuery.sizeOf(context).width > 600;
  final isDark = Theme.of(context).brightness == Brightness.dark;

  if (isTabletOrDesktop) {
    return showDialog<T>(
      context: context,
      barrierDismissible: isDismissible,
      builder: (dialogContext) {
        var isFullscreen = false;
        return StatefulBuilder(
          builder: (sbCtx, setModalState) {
            final mqSize = MediaQuery.sizeOf(sbCtx);
            final bottomInset = MediaQuery.viewInsetsOf(sbCtx).bottom;
            final keyboardOpen = bottomInset > 40;
            final availableHeight = (mqSize.height - bottomInset).clamp(
              240.0,
              mqSize.height,
            );
            final maxWidth = isFullscreen
                ? (mqSize.width - 16).clamp(360.0, 1280.0)
                : (keyboardOpen ? 820.0 : 720.0);
            final maxHeight = isFullscreen
                ? availableHeight * 0.98
                : availableHeight * (keyboardOpen ? 0.96 : 0.88);
            final vertPad = isFullscreen || keyboardOpen ? 8.0 : 20.0;
            final horizPad = isFullscreen ? 8.0 : 20.0;

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: EdgeInsets.fromLTRB(
                horizPad,
                vertPad,
                horizPad,
                bottomInset + vertPad,
              ),
              elevation: 0,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: maxWidth,
                    maxHeight: maxHeight,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(
                        isFullscreen ? 18 : 24,
                      ),
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
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: keyboardOpen ? 10 : 14,
                          ),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        title,
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (subtitle != null &&
                                          !keyboardOpen) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          subtitle,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.textMuted,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                )
                              else
                                const Spacer(),
                              if (enableFullscreenToggle)
                                IconButton(
                                  key: const Key('btn_sheet_fullscreen_toggle'),
                                  icon: Icon(
                                    isFullscreen
                                        ? Icons.fullscreen_exit_rounded
                                        : Icons.fullscreen_rounded,
                                    size: 20,
                                  ),
                                  tooltip: isFullscreen
                                      ? 'Sair da tela cheia'
                                      : 'Expandir espaço de digitação',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => setModalState(
                                    () => isFullscreen = !isFullscreen,
                                  ),
                                ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                tooltip: 'Fechar',
                                visualDensity: VisualDensity.compact,
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(),
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
                        if (bottomBarBuilder != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF0F172A)
                                        .withValues(alpha: 0.45)
                                  : const Color(0xFFF8FAFC),
                              border: Border(
                                top: BorderSide(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.black.withValues(alpha: 0.06),
                                ),
                              ),
                            ),
                            child: bottomBarBuilder(dialogContext),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
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
      var isFullscreen = false;
      return StatefulBuilder(
        builder: (sbCtx, setModalState) {
          final mqSize = MediaQuery.sizeOf(sbCtx);
          final bottomInset = MediaQuery.viewInsetsOf(sbCtx).bottom;
          final keyboardOpen = bottomInset > 40;
          final availableHeight = (mqSize.height - bottomInset).clamp(
            220.0,
            mqSize.height,
          );
          final maxHeight = (isFullscreen || keyboardOpen)
              ? availableHeight * 0.96
              : availableHeight * 0.90;

          return AnimatedPadding(
            padding: EdgeInsets.only(bottom: bottomInset),
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(22),
                  ),
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
                    if (!keyboardOpen) ...[
                      const SizedBox(height: 8),
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[700] : Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                    if (title != null) ...[
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: keyboardOpen ? 4 : 6,
                        ),
                        child: Row(
                          children: [
                            if (titleLeading != null) ...[
                              titleLeading,
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (enableFullscreenToggle)
                              IconButton(
                                key: const Key('btn_sheet_fullscreen_toggle'),
                                icon: Icon(
                                  isFullscreen
                                      ? Icons.fullscreen_exit_rounded
                                      : Icons.fullscreen_rounded,
                                  size: 20,
                                ),
                                tooltip: isFullscreen
                                    ? 'Reduzir modal'
                                    : 'Expandir espaço de digitação',
                                visualDensity: VisualDensity.compact,
                                onPressed: () => setModalState(
                                  () => isFullscreen = !isFullscreen,
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
                    if (bottomBarBuilder != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF0F172A).withValues(alpha: 0.45)
                              : const Color(0xFFF8FAFC),
                          border: Border(
                            top: BorderSide(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.06),
                            ),
                          ),
                        ),
                        child: bottomBarBuilder(sheetContext),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

/// Painel recolhível padronizado para propriedades/metadados secundários em modais de edição,
/// priorizando Título + Área de Digitação no topo em telas pequenas (iPhone, iPad, Android).
class CollapsibleMetadataSection extends StatelessWidget {
  final String title;
  final String summary;
  final bool initiallyExpanded;
  final List<Widget> children;

  const CollapsibleMetadataSection({
    super.key,
    this.title = 'Propriedades & Organização',
    this.summary = '',
    this.initiallyExpanded = false,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark
          ? const Color(0xFF0F172A).withValues(alpha: 0.42)
          : const Color(0xFFF8FAFC),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE2E8F0),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          dense: true,
          visualDensity: VisualDensity.compact,
          leading: const Icon(
            Icons.tune_rounded,
            size: 18,
            color: AppTheme.primaryBlue,
          ),
          title: Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          subtitle: summary.isNotEmpty
              ? Text(
                  summary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : AppTheme.textMuted,
                  ),
                )
              : null,
          children: children,
        ),
      ),
    );
  }
}
