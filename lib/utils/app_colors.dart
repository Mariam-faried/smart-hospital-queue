import 'package:flutter/material.dart';

abstract class AppColors {
  // Brand colors
  static const Color primary = Color(0xFF00674F); // emerald
  static const Color primaryDark = Color(0xFF004D3B); // deeper emerald
  static const Color primaryLight = Color(0xFFA8D5C2); // sea-green tint

  // Accent colors (decorative, not warning/error semantics)
  static const Color accent = Color(0xFFEFBF04); // gold
  static const Color accentGold = accent;
  static const Color tertiary = Color(0xFF01796F); // pine/teal alternative

  // Semantic status colors
  static const Color success = Color(0xFF00674F); // emerald
  static const Color warning = Color(0xFFA85F00); // accessible amber
  static const Color error = Color(0xFFBE5103); // burnt orange
  static const Color info = Color(0xFF000080); // navy blue

  // Foreground tokens on semantic backgrounds
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onSuccess = Color(0xFFFFFFFF);
  static const Color onWarning = Color(0xFFFFFFFF);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color onInfo = Color(0xFFFFFFFF);

  // Surface tokens for semantic backgrounds
  static const Color successSurface = Color(0xFFE8F5EE);
  static const Color warningSurface = Color(0xFFFFF1E5);
  static const Color errorSurface = Color(0xFFFCEDE4);
  static const Color infoSurface = Color(0xFFE9EDFF);

  // Queue status
  static const Color statusWaiting = warning;
  static const Color statusInProgress = info;
  static const Color statusCompleted = success;
  static const Color statusCancelled = error;
  static const Color statusNoShow = Color(0xFF4B5563); // charcoal gray

  // Payment status
  static const Color paymentPaid = success;
  static const Color paymentPending = warning;
  static const Color paymentExpired = error;
  static const Color paymentAtHospital = info;

  // Neutral colors
  static const Color textPrimary = Color(0xFF1C2B2B);
  static const Color textSecondary = Color(0xFF4B5563);
  static const Color background = Color(0xFFF8FAFB);
  static const Color surfaceGrey = background;
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color divider = Color(0xFFE8ECEF);

  // Consistent semantic chip/badge styling
  static const double _badgeSurfaceAlpha = 0.12;
  static const double _badgeBorderAlpha = 0.28;

  static Color statusSurface(Color statusColor) {
    if (statusColor.toARGB32() == success.toARGB32()) return successSurface;
    if (statusColor.toARGB32() == warning.toARGB32()) return warningSurface;
    if (statusColor.toARGB32() == error.toARGB32()) return errorSurface;
    if (statusColor.toARGB32() == info.toARGB32()) return infoSurface;
    return statusColor.withValues(alpha: _badgeSurfaceAlpha);
  }

  static Color statusBorder(Color statusColor) {
    return statusColor.withValues(alpha: _badgeBorderAlpha);
  }
}
