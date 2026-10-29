import 'package:flutter/material.dart';

class AppTheme {
  // Cores de alto contraste e legibilidade sob sol intenso
  static const Color primaryBlue = Color(0xFF1E3A8A); // Azul profundo elegante
  static const Color accentTeal = Color(0xFF0D9488);
  static const Color surfaceLight = Color(0xFFF8FAFC);
  static const Color cardLight = Colors.white;
  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF475569);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextMuted = Color(0xFFCBD5E1);
  static const Color alertAmber = Color(0xFFD97706);
  static const Color alertRed = Color(0xFFDC2626);
  static const Color successGreen = Color(0xFF16A34A);

  // Helpers contextuais para alto contraste (Tema Claro x Escuro)
  static bool isDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;
  static Color textPrimary(BuildContext context) => isDark(context) ? const Color(0xFFF8FAFC) : textDark;
  static Color textSecondary(BuildContext context) => isDark(context) ? const Color(0xFFCBD5E1) : textMuted;
  static Color surfaceColor(BuildContext context) => isDark(context) ? const Color(0xFF0F172A) : surfaceLight;
  static Color cardColor(BuildContext context) => isDark(context) ? const Color(0xFF1E293B) : cardLight;
  static Color primaryColor(BuildContext context) => isDark(context) ? const Color(0xFF60A5FA) : primaryBlue;
  static Color subtleBorder(BuildContext context) => isDark(context) ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
  static Color subtleContainer(BuildContext context) => isDark(context) ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        brightness: Brightness.light,
        surface: surfaceLight,
        onSurface: textDark,
        primary: primaryBlue,
        secondary: accentTeal,
      ),
      scaffoldBackgroundColor: surfaceLight,
      cardTheme: CardThemeData(
        color: cardLight,
        elevation: 1.5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        centerTitle: false,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 48), // Mínimo 48dp para toque de campo
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryBlue,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          side: const BorderSide(color: primaryBlue, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryBlue, width: 2),
        ),
        labelStyle: const TextStyle(color: textMuted, fontWeight: FontWeight.w500),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        brightness: Brightness.dark,
        surface: const Color(0xFF0F172A),
        onSurface: const Color(0xFFF8FAFC),
        primary: const Color(0xFF60A5FA),
        secondary: const Color(0xFF2DD4BF),
      ),
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E293B),
        elevation: 1.5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF334155)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0F172A),
        foregroundColor: Colors.white,
        centerTitle: false,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF3B82F6),
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF93C5FD),
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          side: const BorderSide(color: Color(0xFF60A5FA), width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E293B),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF475569), width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF475569), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF60A5FA), width: 2),
        ),
        labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        contentTextStyle: const TextStyle(color: Color(0xFFF1F5F9), fontSize: 14),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF1E293B),
        modalBackgroundColor: Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF334155),
        thickness: 1,
      ),
      listTileTheme: const ListTileThemeData(
        textColor: Color(0xFFF8FAFC),
        iconColor: Color(0xFFCBD5E1),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Color(0xFFF8FAFC)),
        bodyMedium: TextStyle(color: Color(0xFFF1F5F9)),
        bodySmall: TextStyle(color: Color(0xFFCBD5E1)),
        titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        titleMedium: TextStyle(color: Color(0xFFF8FAFC), fontWeight: FontWeight.w600),
        titleSmall: TextStyle(color: Color(0xFFE2E8F0)),
        labelLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        labelMedium: TextStyle(color: Color(0xFFCBD5E1)),
        labelSmall: TextStyle(color: Color(0xFFCBD5E1)),
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
        labelStyle: const TextStyle(color: Color(0xFF000000), fontWeight: FontWeight.w800),
        secondaryLabelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
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
        labelStyle: TextStyle(color: Color(0xFF000000), fontWeight: FontWeight.w800),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF000000),
        thickness: 2,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Color(0xFF000000), fontWeight: FontWeight.w700),
        bodyMedium: TextStyle(color: Color(0xFF000000), fontWeight: FontWeight.w600),
        bodySmall: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w600),
        titleLarge: TextStyle(color: Color(0xFF000000), fontWeight: FontWeight.w900),
        titleMedium: TextStyle(color: Color(0xFF000000), fontWeight: FontWeight.w800),
        titleSmall: TextStyle(color: Color(0xFF000000), fontWeight: FontWeight.w800),
        labelLarge: TextStyle(color: Color(0xFF000000), fontWeight: FontWeight.w800),
        labelMedium: TextStyle(color: Color(0xFF000000), fontWeight: FontWeight.w700),
        labelSmall: TextStyle(color: Color(0xFF000000), fontWeight: FontWeight.w700),
      ),
    );
  }
}

