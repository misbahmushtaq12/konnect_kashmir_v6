import 'package:flutter/material.dart';

/// Central place for all brand colors and ThemeData.
/// Change a color here and it updates across every screen that uses the theme.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF339985);
  static const Color primaryDark = Color(0xFF1F6F61);
  static const Color primaryLight = Color(0xFF6BC4B2);
  static const Color accent = Color(0xFFE07B2E);

  static const Color lightBg = Color(0xFFF5FAFA);
  static const Color lightText = Color(0xFF10231F);

  static const Color darkBg = Color(0xFF132A2A);
  static const Color darkSurface = Color(0xFF1A3333);
  static const Color darkText = Color(0xFFEAF4F2);

  static const Color success = Color(0xFF2E9E6B);
  static const Color danger = Color(0xFFD64545);
}

class AppRadius {
  AppRadius._();
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 22;
  static const double xl = 28;
}

class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final surface = isDark ? AppColors.darkSurface : Colors.white;
    final onSurface = isDark ? AppColors.darkText : AppColors.lightText;

    final scheme = (isDark ? const ColorScheme.dark() : const ColorScheme.light())
        .copyWith(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.accent,
      onSecondary: Colors.white,
      surface: surface,
      onSurface: onSurface,
      error: AppColors.danger,
    );

    final outline = onSurface.withValues(alpha: 0.10);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: bg,
      colorScheme: scheme,

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: onSurface,
        titleTextStyle: TextStyle(
          color: onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),

      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: outline),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: onSurface.withValues(alpha: 0.2)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: onSurface.withValues(alpha: 0.05),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: onSurface.withValues(alpha: 0.06),
        selectedColor: AppColors.primary.withValues(alpha: 0.18),
        side: BorderSide(color: outline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        labelStyle: TextStyle(color: onSurface, fontWeight: FontWeight.w500),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),

      dividerTheme: DividerThemeData(color: outline, thickness: 1, space: 1),
    );
  }
}
