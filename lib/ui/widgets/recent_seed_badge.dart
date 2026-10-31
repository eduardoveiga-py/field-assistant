import 'package:flutter/material.dart';
import '../../contacts/recent_seeds_helper.dart';

/// Badge visual de alto contraste e acessibilidade para contatos identificados
/// como "Sementes Recentes" (cadastrados há até 7 dias sem revisita realizada - R3).
class RecentSeedBadge extends StatelessWidget {
  final DateTime firstContactAt;
  final DateTime? nowOverride;
  final VoidCallback? onTap;

  const RecentSeedBadge({
    super.key,
    required this.firstContactAt,
    this.nowOverride,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Detecção de Modo Sol Intenso (AppTheme.sunModeTheme)
    final cardShape = theme.cardTheme.shape;
    final BorderSide? borderSide = cardShape is RoundedRectangleBorder
        ? cardShape.side
        : null;
    final isSunMode = (borderSide?.color == const Color(0xFF000000) &&
            (borderSide?.width ?? 0) >= 2.0) ||
        (theme.colorScheme.primary == const Color(0xFF000000) &&
            theme.scaffoldBackgroundColor == Colors.white &&
            theme.brightness == Brightness.light);

    final label = RecentSeedsHelper.getFriendlyElapsedLabel(
      firstContactAt: firstContactAt,
      nowOverride: nowOverride,
    );

    // Cores adaptativas por tema
    final Color bgColor;
    final Color borderColor;
    final double borderWidth;
    final Color contentColor;

    if (isSunMode) {
      // Alto Contraste Solar Extremo
      bgColor = Colors.white;
      borderColor = const Color(0xFF000000);
      borderWidth = 2.0;
      contentColor = const Color(0xFF000000);
    } else if (isDark) {
      // Dark Mode Elegante
      bgColor = const Color(0xFF064E3B).withValues(alpha: 0.35);
      borderColor = const Color(0xFF34D399);
      borderWidth = 1.2;
      contentColor = const Color(0xFFA7F3D0);
    } else {
      // Light Mode Padrão (WCAG AAA >= 7.5:1)
      bgColor = const Color(0xFFDCFCE7); // green-100
      borderColor = const Color(0xFF16A34A); // green-600
      borderWidth = 1.2;
      contentColor = const Color(0xFF14532D); // green-900
    }

    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.eco,
            size: 14,
            color: contentColor,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSunMode ? FontWeight.w900 : FontWeight.bold,
                color: contentColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    return Semantics(
      label: 'Semente Recente: $label',
      child: Tooltip(
        message: 'Semente Recente: Primeiro contato nos últimos 7 dias aguardando 1ª revisita',
        child: onTap != null
            ? InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(6),
                child: badge,
              )
            : badge,
      ),
    );
  }
}
