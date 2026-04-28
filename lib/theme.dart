import 'package:flutter/material.dart';

// ======================= 颜色系统 =======================
class AppColors {
  static const Color primary = Colors.green;
  static const Color primaryLight = Color(0xFFE8F5E9);
  static const Color primaryDark = Color(0xFF2E7D32);
  static const Color background = Colors.white;
  static const Color surface = Colors.white;
  static const Color scaffoldBackground = Colors.white;
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFF9E9E9E);
  static const Color textOnPrimary = Colors.white;
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);
  static const Color border = Color(0xFFE0E0E0);
  static const Color divider = Color(0xFFEEEEEE);
  static Color priorityHigh = error;
  static Color priorityMedium = warning;
  static Color priorityLow = info;
}

// ======================= 字体大小 =======================
class AppFontSizes {
  static const double headlineLarge = 28.0;
  static const double headlineMedium = 24.0;
  static const double headlineSmall = 20.0;
  static const double bodyLarge = 16.0;
  static const double bodyMedium = 14.0;
  static const double bodySmall = 12.0;
  static const double labelLarge = 14.0;
  static const double labelMedium = 12.0;
  static const double labelSmall = 10.0;
}

// ======================= 间距系统 =======================
class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
}

// ======================= 圆角系统 =======================
class AppBorderRadius {
  static const double small = 8.0;
  static const double medium = 12.0;
  static const double large = 16.0;
  static const double extraLarge = 24.0;
  static const double full = 999.0;
}

// ======================= 全局主题 =======================
final ThemeData classroomTheme = ThemeData(
  primarySwatch: Colors.green,
  scaffoldBackgroundColor: AppColors.scaffoldBackground,
  fontFamily: 'Roboto',

  colorScheme: ColorScheme.light(
    primary: AppColors.primary,
    secondary: AppColors.primary,
    surface: AppColors.surface,
    error: AppColors.error,
    onPrimary: AppColors.textOnPrimary,
    onSurface: AppColors.textPrimary,
  ),

  textTheme: const TextTheme(
    headlineLarge: TextStyle(fontSize: AppFontSizes.headlineLarge, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
    headlineMedium: TextStyle(fontSize: AppFontSizes.headlineMedium, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
    headlineSmall: TextStyle(fontSize: AppFontSizes.headlineSmall, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
    bodyLarge: TextStyle(fontSize: AppFontSizes.bodyLarge, color: AppColors.textPrimary),
    bodyMedium: TextStyle(fontSize: AppFontSizes.bodyMedium, color: AppColors.textSecondary),
    bodySmall: TextStyle(fontSize: AppFontSizes.bodySmall, color: AppColors.textSecondary),
    labelLarge: TextStyle(fontSize: AppFontSizes.labelLarge, fontWeight: FontWeight.w500),
    labelMedium: TextStyle(fontSize: AppFontSizes.labelMedium, color: AppColors.textSecondary),
    labelSmall: TextStyle(fontSize: AppFontSizes.labelSmall, color: AppColors.textHint),
  ),

  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.surface,
    foregroundColor: AppColors.textPrimary,
    elevation: 0,
    centerTitle: false,
    titleTextStyle: TextStyle(color: AppColors.textPrimary, fontSize: AppFontSizes.headlineSmall, fontWeight: FontWeight.w600),
    iconTheme: IconThemeData(color: AppColors.textPrimary),
  ),

  cardTheme: CardThemeData(
    elevation: 1,
    margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppBorderRadius.large),
      side: BorderSide(color: AppColors.border),
    ),
    color: AppColors.surface,
  ),

  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.textOnPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppBorderRadius.extraLarge)),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      textStyle: const TextStyle(fontSize: AppFontSizes.bodyLarge, fontWeight: FontWeight.w600),
    ),
  ),

  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(foregroundColor: AppColors.primary, textStyle: const TextStyle(fontWeight: FontWeight.w500)),
  ),

  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: AppColors.primary,
    foregroundColor: AppColors.textOnPrimary,
  ),

  inputDecorationTheme: InputDecorationTheme(
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppBorderRadius.medium), borderSide: const BorderSide(color: AppColors.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppBorderRadius.medium), borderSide: const BorderSide(color: AppColors.border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppBorderRadius.medium), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppBorderRadius.medium), borderSide: const BorderSide(color: AppColors.error)),
    contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
    hintStyle: const TextStyle(color: AppColors.textHint, fontSize: AppFontSizes.bodyMedium),
    labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: AppFontSizes.bodyMedium),
  ),

  checkboxTheme: CheckboxThemeData(
    fillColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? AppColors.primary : null),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
  ),

  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    selectedItemColor: AppColors.primary,
    unselectedItemColor: AppColors.textSecondary,
    type: BottomNavigationBarType.fixed,
    backgroundColor: AppColors.surface,
    elevation: 8,
    selectedLabelStyle: TextStyle(fontSize: AppFontSizes.labelSmall, fontWeight: FontWeight.w600),
    unselectedLabelStyle: TextStyle(fontSize: AppFontSizes.labelSmall),
  ),

  dialogTheme: DialogThemeData(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppBorderRadius.large)),
    titleTextStyle: const TextStyle(fontSize: AppFontSizes.headlineSmall, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
    contentTextStyle: const TextStyle(fontSize: AppFontSizes.bodyMedium, color: AppColors.textSecondary),
  ),

  dividerTheme: const DividerThemeData(color: AppColors.divider, thickness: 1, space: 1),

  progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.primary, linearMinHeight: 6, circularTrackColor: AppColors.divider),
);

EdgeInsets get pagePadding => const EdgeInsets.all(AppSpacing.md);
EdgeInsets get cardPadding => const EdgeInsets.all(AppSpacing.md);
EdgeInsets get listItemPadding => const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm);