import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../theme/app_theme.dart';

/// Reusable widget for Medsina brand logo and emblem icon.
class MedsinaLogo extends StatelessWidget {
  final double? height;
  final double? width;
  final BoxFit fit;
  final bool isIconOnly;
  final double? iconSize;
  final bool forceLight;

  const MedsinaLogo({
    super.key,
    this.height = 38,
    this.width,
    this.fit = BoxFit.contain,
    this.forceLight = false,
  })  : isIconOnly = false,
        iconSize = null;

  const MedsinaLogo.icon({
    super.key,
    double size = 32,
    this.fit = BoxFit.contain,
    this.forceLight = false,
  })  : height = size,
        width = size,
        iconSize = size,
        isIconOnly = true;

  @override
  Widget build(BuildContext context) {
    if (isIconOnly) {
      final size = iconSize ?? 32;
      return Image.asset(
        AppConstants.iconAsset,
        width: size,
        height: size,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primaryTeal, AppTheme.accentCyan],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(size * 0.25),
          ),
          child: Icon(
            Icons.local_hospital_rounded,
            color: Colors.white,
            size: size * 0.6,
          ),
        ),
      );
    }

    final isDark = !forceLight && Theme.of(context).brightness == Brightness.dark;
    final assetPath = isDark ? AppConstants.logoDarkAsset : AppConstants.logoAsset;

    return Image.asset(
      assetPath,
      height: height,
      width: width,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primaryTeal, AppTheme.accentCyan],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.local_hospital_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 8),
          const Text(
            AppConstants.appName,
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
          ),
        ],
      ),
    );
  }
}

