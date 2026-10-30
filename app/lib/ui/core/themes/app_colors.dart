import 'package:flutter/material.dart';

/// Semantic color tokens for the whole app.
///
/// This is the SINGLE source of truth for every color used in the UI. Widgets
/// must never hardcode `Color(0x…)` or `Colors.*` — they read from here via
/// `context.colors.<token>` (see `theme_extensions.dart`).
///
/// Registered on [ThemeData.extensions] by `buildDarkTheme()` /
/// `buildLightTheme()` so `Theme.of(context).extension<AppColors>()` resolves
/// the right palette for the active brightness.
///
/// Quiet neutral palettes with Baya teal for the shell and readable chat.
/// Keep both brightness variants here so features share the same semantics.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bg,
    required this.surface,
    required this.border,
    required this.text,
    required this.muted,
    required this.muted2,
    required this.accent,
    required this.onAccent,
    required this.highlight,
    required this.success,
    required this.error,
    required this.warning,
    required this.working,
    required this.codeBg,
    required this.userBubble,
    required this.modelBadgeBg,
    required this.modelBadgeBorder,
    required this.denyBorder,
    required this.inputFill,
  });

  /// App background (scaffold). Was `kBg`.
  final Color bg;

  /// Slightly raised surface (cards, sheets). Was `kSurface`.
  final Color surface;

  /// Hairline borders / dividers. Was `kBorder`.
  final Color border;

  /// Primary foreground text. Was `kText`.
  final Color text;

  /// Secondary / de-emphasized text. Was `kMuted`.
  final Color muted;

  /// Tertiary text — slightly more prominent than [muted]. Was `kMuted2`.
  final Color muted2;

  /// Brand accent (links, active states, primary buttons). Was `kAccent`.
  final Color accent;

  /// Foreground painted on top of [accent] (e.g. filled-button label). Was the
  /// hardcoded `Colors.black` / `onPrimary`.
  final Color onAccent;

  /// Code / file paths inside agent messages. Was `kHighlight`.
  final Color highlight;

  /// Success state (✓ tool results). Was `kSuccess`.
  final Color success;

  /// Error / destructive state (✗ tool results, failed sends, delete). Was
  /// `kError` and the scattered `Colors.redAccent`.
  final Color error;

  /// Warning state (relay offline). Was the scattered `Colors.amber`.
  final Color warning;

  /// "Working" / in-progress accent (session running a turn). Was the local
  /// `kWorking = Color(0xFF3FA9F5)` duplicated in session_tile and chat_page.
  final Color working;

  /// Background of inline/he block code. Was `kCodeBg`.
  final Color codeBg;

  /// User chat bubble background. Was `kUserBubble`.
  final Color userBubble;

  /// Model badge background. Was `kModelBadgeBg`.
  final Color modelBadgeBg;

  /// Model badge border. Was `kModelBadgeBorder`.
  final Color modelBadgeBorder;

  /// Border for a denied tool-call card. Was `kDenyBorder`.
  final Color denyBorder;

  /// Text-field fill. Was the hardcoded `Color(0xFF0E0E0E)`.
  final Color inputFill;

  // Functional chrome uses these tokens; prose and code use opaque surfaces.
  bool get _isDark => bg.computeLuminance() < 0.2;
  Color get glassFill => inputFill.withValues(alpha: _isDark ? 0.91 : 0.89);
  Color get glassTint => surface.withValues(alpha: _isDark ? 0.94 : 0.90);
  Color get glassEdge => text.withValues(alpha: _isDark ? 0.18 : 0.10);
  Color get glassShadow =>
      const Color(0xFF000000).withValues(alpha: _isDark ? 0.16 : 0.06);
  Color get selection => accent.withValues(alpha: _isDark ? 0.13 : 0.09);

  /// Dark palette (default). Mirrors the original `app_theme.dart` constants.
  static const AppColors dark = AppColors(
    bg: Color(0xFF11191C),
    surface: Color(0xFF1B272B),
    border: Color(0xFF34454A),
    text: Color(0xFFEDF3F2),
    muted: Color(0xFF9EAFB2),
    muted2: Color(0xFFBDCDCE),
    accent: Color(0xFFA4D7CB),
    onAccent: Color(0xFF123B35),
    highlight: Color(0xFFB8DDD4),
    success: Color(0xFF9CBDA5),
    error: Color(0xFFE69C94),
    warning: Color(0xFFDABD85),
    working: Color(0xFFA1B7CD),
    codeBg: Color(0xFF172125),
    userBubble: Color(0xFF25363A),
    modelBadgeBg: Color(0xFF26383B),
    modelBadgeBorder: Color(0xFF3C5155),
    denyBorder: Color(0xFF554141),
    inputFill: Color(0xFF223136),
  );

  /// Light palette — derived from [dark]. Foreground tints are tuned for
  /// WCAG-AA contrast on the white [bg] (≥4.5:1 for body, ≥3:1 for large/UI):
  /// `muted`/`muted2` are dark grays (not the dark-theme mid-grays, which were
  /// washed out on white), and `accent`/`highlight` are deepened cyans so
  /// accent-colored *text* (links, "Use default" buttons) stays legible.
  static const AppColors light = AppColors(
    bg: Color(0xFFF6F8F8),
    surface: Color(0xFFEDF2F2),
    border: Color(0xFFD9E2E3),
    text: Color(0xFF19282B),
    muted: Color(0xFF637479),
    muted2: Color(0xFF4D6267),
    accent: Color(0xFF225F57),
    onAccent: Color(0xFFFFFFFF),
    highlight: Color(0xFF275F59),
    success: Color(0xFF417454),
    error: Color(0xFFAF453E),
    warning: Color(0xFF916B30),
    working: Color(0xFF4E6B86),
    codeBg: Color(0xFFEDF2F3),
    userBubble: Color(0xFFE5EEEC),
    modelBadgeBg: Color(0xFFE4EEEC),
    modelBadgeBorder: Color(0xFFD1E0DC),
    denyBorder: Color(0xFFE3D6D3),
    inputFill: Color(0xFFFFFFFF),
  );

  @override
  AppColors copyWith({
    Color? bg,
    Color? surface,
    Color? border,
    Color? text,
    Color? muted,
    Color? muted2,
    Color? accent,
    Color? onAccent,
    Color? highlight,
    Color? success,
    Color? error,
    Color? warning,
    Color? working,
    Color? codeBg,
    Color? userBubble,
    Color? modelBadgeBg,
    Color? modelBadgeBorder,
    Color? denyBorder,
    Color? inputFill,
  }) {
    return AppColors(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      border: border ?? this.border,
      text: text ?? this.text,
      muted: muted ?? this.muted,
      muted2: muted2 ?? this.muted2,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      highlight: highlight ?? this.highlight,
      success: success ?? this.success,
      error: error ?? this.error,
      warning: warning ?? this.warning,
      working: working ?? this.working,
      codeBg: codeBg ?? this.codeBg,
      userBubble: userBubble ?? this.userBubble,
      modelBadgeBg: modelBadgeBg ?? this.modelBadgeBg,
      modelBadgeBorder: modelBadgeBorder ?? this.modelBadgeBorder,
      denyBorder: denyBorder ?? this.denyBorder,
      inputFill: inputFill ?? this.inputFill,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      border: Color.lerp(border, other.border, t)!,
      text: Color.lerp(text, other.text, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      muted2: Color.lerp(muted2, other.muted2, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      highlight: Color.lerp(highlight, other.highlight, t)!,
      success: Color.lerp(success, other.success, t)!,
      error: Color.lerp(error, other.error, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      working: Color.lerp(working, other.working, t)!,
      codeBg: Color.lerp(codeBg, other.codeBg, t)!,
      userBubble: Color.lerp(userBubble, other.userBubble, t)!,
      modelBadgeBg: Color.lerp(modelBadgeBg, other.modelBadgeBg, t)!,
      modelBadgeBorder: Color.lerp(
        modelBadgeBorder,
        other.modelBadgeBorder,
        t,
      )!,
      denyBorder: Color.lerp(denyBorder, other.denyBorder, t)!,
      inputFill: Color.lerp(inputFill, other.inputFill, t)!,
    );
  }
}

/// Fixed launcher/brand tile colors, shared by light and dark presentations.
abstract final class AppBrandColors {
  static const background = Color(0xFF163D3C);
  static const foreground = Color(0xFFF6F0E4);
  static const highlight = Color(0xFFE6AD72);
}
