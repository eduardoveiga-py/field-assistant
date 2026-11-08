import 'package:flutter/material.dart';

/// Barra de destaque cromático superior para telas secundárias.
/// Proporciona conexão e continuidade visual com os cards da tela inicial (Home/Hoje).
class ScreenHeroAccentBand extends StatelessWidget implements PreferredSizeWidget {
  final Color primaryColor;
  final Color? secondaryColor;
  final double height;

  const ScreenHeroAccentBand({
    super.key,
    required this.primaryColor,
    this.secondaryColor,
    this.height = 3.5,
  });

  /// Factory para Estudos Bíblicos (Púrpura vibrante)
  factory ScreenHeroAccentBand.studies() => const ScreenHeroAccentBand(
        primaryColor: Color(0xFF7C3AED),
        secondaryColor: Color(0xFFA855F7),
      );

  /// Factory para Pessoas e Contatos (Azul teocrático)
  factory ScreenHeroAccentBand.people() => const ScreenHeroAccentBand(
        primaryColor: Color(0xFF2563EB),
        secondaryColor: Color(0xFF60A5FA),
      );

  /// Factory para Agenda e Compromissos (Âmbar / Laranja)
  factory ScreenHeroAccentBand.agenda() => const ScreenHeroAccentBand(
        primaryColor: Color(0xFFD97706),
        secondaryColor: Color(0xFFF59E0B),
      );

  /// Factory para Assistente de Idiomas & Tradução (Esmeralda / Menta)
  factory ScreenHeroAccentBand.languages() => const ScreenHeroAccentBand(
        primaryColor: Color(0xFF059669),
        secondaryColor: Color(0xFF10B981),
      );

  /// Factory para Territórios e Mapas (Índigo Profundo)
  factory ScreenHeroAccentBand.territory() => const ScreenHeroAccentBand(
        primaryColor: Color(0xFF4338CA),
        secondaryColor: Color(0xFF6366F1),
      );

  @override
  Widget build(BuildContext context) {
    final secColor = secondaryColor ?? primaryColor.withValues(alpha: 0.85);

    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, secColor],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.35),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(height);
}
