import 'package:flutter/material.dart';

import 'package:app/ui/core/themes/app_colors.dart';
import 'package:app/ui/core/themes/app_typography.dart';

/// Builds the [ThemeData] for a given [AppColors] / [AppTypography] pair.
///
/// Wires the semantic tokens into both the standard Material [ColorScheme]
/// (so framework widgets — dialogs, switches, progress indicators, text
/// fields — render correctly per brightness) AND attaches [AppColors] /
/// [AppTypography] as theme extensions (so app widgets read
/// `context.colors.*` / `context.typo.*`).
ThemeData _buildTheme({
  required Brightness brightness,
  required AppColors colors,
  required AppTypography typo,
}) {
  return ThemeData(
    brightness: brightness,
    fontFamily: kSansFamily,
    fontFamilyFallback: kFontFallback,
    scaffoldBackgroundColor: colors.bg,
    colorScheme: ColorScheme(
      brightness: brightness,
      surface: colors.bg,
      onSurface: colors.text,
      primary: colors.accent,
      onPrimary: colors.onAccent,
      primaryContainer: colors.userBubble,
      onPrimaryContainer: colors.text,
      secondary: colors.muted,
      onSecondary: colors.text,
      secondaryContainer: colors.userBubble,
      onSecondaryContainer: colors.text,
      surfaceContainer: colors.surface,
      surfaceContainerHighest: colors.userBubble,
      error: colors.error,
      onError: colors.onAccent,
      outline: colors.border,
    ),
    dividerColor: colors.border,
    extensions: <ThemeExtension<dynamic>>[colors, typo],
    appBarTheme: AppBarTheme(
      backgroundColor: colors.bg,
      foregroundColor: colors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 64,
      titleTextStyle: TextStyle(
        fontFamily: kSansFamily,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: colors.text,
        letterSpacing: -0.2,
      ),
    ),
    textTheme: TextTheme(
      bodyMedium: typo.sansBody,
      bodySmall: typo.sansBody.copyWith(fontSize: 12, color: colors.muted2),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(44, 44),
        foregroundColor: colors.text,
        shape: const CircleBorder(),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(44, 48),
        shape: const StadiumBorder(),
        textStyle: typo.sansBody.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(44, 46),
        shape: const StadiumBorder(),
        side: BorderSide(color: colors.border),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.bg,
      surfaceTintColor: colors.bg,
      dragHandleColor: colors.muted.withValues(alpha: 0.5),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.inputFill,
      surfaceTintColor: colors.inputFill,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: colors.inputFill,
      surfaceTintColor: colors.inputFill,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.inputFill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide(color: colors.border.withValues(alpha: 0.55)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide(color: colors.border.withValues(alpha: 0.55)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide(color: colors.accent, width: 1.2),
      ),
      hintStyle: typo.sansBody.copyWith(color: colors.muted, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    ),
  );
}

/// Dark theme — the app's original look.
ThemeData buildDarkTheme() => _buildTheme(
  brightness: Brightness.dark,
  colors: AppColors.dark,
  typo: AppTypography.dark,
);

/// Light theme — derived palette (tune hexes in `app_colors.dart`).
ThemeData buildLightTheme() => _buildTheme(
  brightness: Brightness.light,
  colors: AppColors.light,
  typo: AppTypography.light,
);
