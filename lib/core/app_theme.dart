import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../ticuna/ticuna_unicode_helper.dart';

class AppTheme {
  // Cores de alto contraste e legibilidade profissional (estilo Linear / Apple HIG)
  static const Color primaryBlue = Color(
    0xFF2563EB,
  ); // Cor primária de destaque (Light: #2563EB, Dark: #3B82F6)
  static const Color accentTeal = Color(0xFF0D9488);
  static const Color primaryTeal = accentTeal;
  static const Color surfaceLight = Color(0xFFF8FAFC);
  static const Color cardLight = Colors.white;
  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextMuted = Color(0xFF94A3B8);
  static const Color alertAmber = Color(0xFFD97706);
  static const Color alertRed = Color(0xFFDC2626);
  static const Color successGreen = Color(0xFF16A34A);

  // Constantes do design system minimalista
  static const Color darkScaffoldBg = Color(0xFF0B0F17);
  static const Color darkRailSurface = Color(0xFF0E131F);
  static const Color darkCardSurface = Color(0xFF131A29);
  static const Color darkPrimary = Color(0xFF3B82F6);
  static const Color lightScaffoldBg = Color(0xFFF8FAFC);
  static const Color lightRailSurface = Color(0xFFF1F5F9);
  static const Color lightCardSurface = Color(0xFFFFFFFF);
  static const Color lightPrimary = Color(0xFF2563EB);

  // Helpers contextuais para alto contraste (Tema Claro x Escuro)
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;
  static Color textPrimary(BuildContext context) =>
      isDark(context) ? darkTextPrimary : textDark;
  static Color textSecondary(BuildContext context) =>
      isDark(context) ? darkTextMuted : textMuted;
  static Color surfaceColor(BuildContext context) =>
      isDark(context) ? darkScaffoldBg : surfaceLight;
  static Color cardColor(BuildContext context) =>
      isDark(context) ? darkCardSurface : cardLight;
  static Color primaryColor(BuildContext context) =>
      isDark(context) ? darkPrimary : lightPrimary;
  static Color subtleBorder(BuildContext context) => isDark(context)
      ? Colors.white.withValues(alpha: 0.07)
      : const Color(0xFFE2E8F0);
  static Color subtleContainer(BuildContext context) =>
      isDark(context) ? darkRailSurface : lightRailSurface;
  static Color railSurface(BuildContext context) =>
      isDark(context) ? darkRailSurface : lightRailSurface;

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: GoogleFonts.config.allowRuntimeFetching
          ? GoogleFonts.notoSans().fontFamily
          : 'Noto Sans',
      fontFamilyFallback: TicunaUnicodeHelper.fontFallback,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: lightPrimary,
        onPrimary: Colors.white,
        secondary: accentTeal,
        onSecondary: Colors.white,
        error: alertRed,
        onError: Colors.white,
        surface: lightCardSurface,
        onSurface: textDark,
        surfaceContainer: lightCardSurface,
        surfaceContainerLow: lightRailSurface,
        onSurfaceVariant: textMuted,
        outlineVariant: Color(0xFFE2E8F0),
        outline: Color(0xFFCBD5E1),
      ),
      scaffoldBackgroundColor: lightScaffoldBg,
      cardColor: lightCardSurface,
      cardTheme: CardThemeData(
        color: lightCardSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: lightRailSurface,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: lightRailSurface,
        indicatorColor: Colors.transparent,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightScaffoldBg,
        foregroundColor: textDark,
        centerTitle: false,
        elevation: 0,
        titleSpacing: 8,
        titleTextStyle: TextStyle(
          color: textDark,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: textMuted, size: 22),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: lightPrimary,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lightPrimary,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 48), // Mínimo 48dp para toque de campo
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: lightPrimary,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          side: const BorderSide(color: lightPrimary, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: lightPrimary, width: 1.5),
        ),
        labelStyle: const TextStyle(
          color: textMuted,
          fontWeight: FontWeight.w500,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE2E8F0),
        thickness: 1,
      ),
      listTileTheme: const ListTileThemeData(
        textColor: textDark,
        iconColor: textMuted,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: textDark),
        bodyMedium: TextStyle(color: Color(0xFF334155)),
        bodySmall: TextStyle(color: textMuted),
        titleLarge: TextStyle(color: textDark, fontWeight: FontWeight.bold),
        titleMedium: TextStyle(color: textDark, fontWeight: FontWeight.w600),
        titleSmall: TextStyle(color: Color(0xFF475569)),
        labelLarge: TextStyle(color: textDark, fontWeight: FontWeight.w600),
        labelMedium: TextStyle(color: textMuted),
        labelSmall: TextStyle(color: textMuted),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: GoogleFonts.config.allowRuntimeFetching
          ? GoogleFonts.notoSans().fontFamily
          : 'Noto Sans',
      fontFamilyFallback: TicunaUnicodeHelper.fontFallback,
      colorScheme: ColorScheme(
        brightness: Brightness.dark,
        primary: darkPrimary,
        onPrimary: Colors.white,
        secondary: const Color(0xFF2DD4BF),
        onSecondary: Colors.white,
        error: alertRed,
        onError: Colors.white,
        surface: darkCardSurface,
        onSurface: darkTextPrimary,
        surfaceContainer: darkCardSurface,
        surfaceContainerLow: darkRailSurface,
        onSurfaceVariant: darkTextMuted,
        outlineVariant: Colors.white.withValues(alpha: 0.07),
        outline: const Color(0xFF334155),
      ),
      scaffoldBackgroundColor: darkScaffoldBg,
      cardColor: darkCardSurface,
      cardTheme: CardThemeData(
        color: darkCardSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.07),
            width: 1,
          ),
        ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: darkRailSurface,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: darkRailSurface,
        indicatorColor: Colors.transparent,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkScaffoldBg,
        foregroundColor: darkTextPrimary,
        centerTitle: false,
        elevation: 0,
        titleSpacing: 8,
        titleTextStyle: TextStyle(
          color: darkTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: darkTextMuted, size: 22),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: darkPrimary,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkPrimary,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF93C5FD),
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          side: const BorderSide(color: darkPrimary, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkCardSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.07),
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.07),
            width: 1,
          ),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: darkPrimary, width: 1.5),
        ),
        labelStyle: const TextStyle(
          color: darkTextMuted,
          fontWeight: FontWeight.w500,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkCardSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.07),
            width: 1,
          ),
        ),
        titleTextStyle: const TextStyle(
          color: darkTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: const TextStyle(color: darkTextMuted, fontSize: 14),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkCardSurface,
        modalBackgroundColor: darkCardSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.07),
        thickness: 1,
      ),
      listTileTheme: const ListTileThemeData(
        textColor: darkTextPrimary,
        iconColor: darkTextMuted,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: darkTextPrimary),
        bodyMedium: TextStyle(color: Color(0xFFCBD5E1)),
        bodySmall: TextStyle(color: darkTextMuted),
        titleLarge: TextStyle(
          color: darkTextPrimary,
          fontWeight: FontWeight.bold,
        ),
        titleMedium: TextStyle(
          color: darkTextPrimary,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: TextStyle(color: darkTextMuted),
        labelLarge: TextStyle(
          color: darkTextPrimary,
          fontWeight: FontWeight.w600,
        ),
        labelMedium: TextStyle(color: darkTextMuted),
        labelSmall: TextStyle(color: darkTextMuted),
      ),
    );
  }

  /// Tema de Alto Contraste para Luz Solar Extrema (Modo Sol Intenso)
  static ThemeData get sunModeTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: Color(0xFF000000),
        onPrimary: Colors.white,
        secondary: Color(0xFF000000),
        onSecondary: Colors.white,
        error: Color(0xFFDC2626),
        onError: Colors.white,
        surface: Colors.white,
        onSurface: Color(0xFF000000),
      ),
      scaffoldBackgroundColor: Colors.white,
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF000000), width: 2.0),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF000000),
        foregroundColor: Colors.white,
        centerTitle: false,
        elevation: 4,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
        iconTheme: IconThemeData(color: Colors.white, size: 26),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF000000),
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Color(0xFF000000), width: 2),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF000000),
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          side: const BorderSide(color: Color(0xFF000000), width: 2.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        disabledColor: Colors.grey.shade300,
        selectedColor: const Color(0xFF000000),
        secondarySelectedColor: const Color(0xFF000000),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        labelStyle: const TextStyle(
          color: Color(0xFF000000),
          fontWeight: FontWeight.w800,
        ),
        secondaryLabelStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
        side: const BorderSide(color: Color(0xFF000000), width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: Color(0xFF000000), width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: Color(0xFF000000), width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: Color(0xFF000000), width: 3),
        ),
        labelStyle: TextStyle(
          color: Color(0xFF000000),
          fontWeight: FontWeight.w800,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF000000),
        thickness: 2,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(
          color: Color(0xFF000000),
          fontWeight: FontWeight.w700,
        ),
        bodyMedium: TextStyle(
          color: Color(0xFF000000),
          fontWeight: FontWeight.w600,
        ),
        bodySmall: TextStyle(
          color: Color(0xFF1E293B),
          fontWeight: FontWeight.w600,
        ),
        titleLarge: TextStyle(
          color: Color(0xFF000000),
          fontWeight: FontWeight.w900,
        ),
        titleMedium: TextStyle(
          color: Color(0xFF000000),
          fontWeight: FontWeight.w800,
        ),
        titleSmall: TextStyle(
          color: Color(0xFF000000),
          fontWeight: FontWeight.w800,
        ),
        labelLarge: TextStyle(
          color: Color(0xFF000000),
          fontWeight: FontWeight.w800,
        ),
        labelMedium: TextStyle(
          color: Color(0xFF000000),
          fontWeight: FontWeight.w700,
        ),
        labelSmall: TextStyle(
          color: Color(0xFF000000),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
