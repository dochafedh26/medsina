import 'package:flutter/material.dart';

/// Semantic design tokens for Medsina across Light, Dark, and Night Shift (AMOLED + Amber) modes.
/// Access anywhere via `context.mc`.
@immutable
class MedsinaColors extends ThemeExtension<MedsinaColors> {
  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;
  final Color accentSoft;
  final Color success;
  final Color warning;
  final Color error;
  final Color info;
  final Color cardShadow;
  final bool isNightShift;

  const MedsinaColors({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.accentSoft,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.cardShadow,
    this.isNightShift = false,
  });

  static const MedsinaColors light = MedsinaColors(
    background: Color(0xFFF3F6FA),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFEFF4F9),
    border: Color(0xFFE2E8F0),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF64748B),
    accent: Color(0xFF0D9488),
    accentSoft: Color(0xFFE6FFFA),
    success: Color(0xFF10B981),
    warning: Color(0xFFF59E0B),
    error: Color(0xFFEF4444),
    info: Color(0xFF0284C7),
    cardShadow: Color(0x120B2545),
    isNightShift: false,
  );

  static const MedsinaColors dark = MedsinaColors(
    background: Color(0xFF090D16),
    surface: Color(0xFF131C2E),
    surfaceElevated: Color(0xFF1E293B),
    border: Color(0xFF26354D),
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFF94A3B8),
    accent: Color(0xFF14B8A6),
    accentSoft: Color(0xFF112A2E),
    success: Color(0xFF10B981),
    warning: Color(0xFFF59E0B),
    error: Color(0xFFEF4444),
    info: Color(0xFF38BDF8),
    cardShadow: Color(0x47000000),
    isNightShift: false,
  );

  /// Mode "Garde de Nuit" : Noir pur AMOLED (#000000) + Ambre doux anti-fatigue oculaire.
  static const MedsinaColors nightShift = MedsinaColors(
    background: Color(0xFF000000),
    surface: Color(0xFF0B0B0D),
    surfaceElevated: Color(0xFF16161A),
    border: Color(0xFF27221B),
    textPrimary: Color(0xFFF5ECE0),
    textSecondary: Color(0xFFA89984),
    accent: Color(0xFFF59E0B),
    accentSoft: Color(0xFF241A08),
    success: Color(0xFF34D399),
    warning: Color(0xFFFBBF24),
    error: Color(0xFFF87171),
    info: Color(0xFFFCD34D),
    cardShadow: Color(0x66000000),
    isNightShift: true,
  );

  @override
  MedsinaColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? accent,
    Color? accentSoft,
    Color? success,
    Color? warning,
    Color? error,
    Color? info,
    Color? cardShadow,
    bool? isNightShift,
  }) {
    return MedsinaColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      info: info ?? this.info,
      cardShadow: cardShadow ?? this.cardShadow,
      isNightShift: isNightShift ?? this.isNightShift,
    );
  }

  @override
  MedsinaColors lerp(ThemeExtension<MedsinaColors>? other, double t) {
    if (other is! MedsinaColors) return this;
    return MedsinaColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      info: Color.lerp(info, other.info, t)!,
      cardShadow: Color.lerp(cardShadow, other.cardShadow, t)!,
      isNightShift: t < 0.5 ? isNightShift : other.isNightShift,
    );
  }
}

extension MedsinaColorsContext on BuildContext {
  MedsinaColors get mc {
    final ext = Theme.of(this).extension<MedsinaColors>();
    if (ext != null) return ext;
    return Theme.of(this).brightness == Brightness.dark
        ? MedsinaColors.dark
        : MedsinaColors.light;
  }
}
