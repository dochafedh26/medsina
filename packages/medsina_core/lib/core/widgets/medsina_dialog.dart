import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum MedsinaDialogType {
  error,
  success,
  warning,
  info,
  confirm,
}

class MedsinaDialog extends StatelessWidget {
  final MedsinaDialogType type;
  final String title;
  final String message;
  final String? detail;
  final String primaryLabel;
  final String? secondaryLabel;
  final VoidCallback? onPrimary;
  final VoidCallback? onSecondary;
  final bool isDestructive;
  final IconData? customIcon;

  const MedsinaDialog({
    super.key,
    required this.type,
    required this.title,
    required this.message,
    this.detail,
    required this.primaryLabel,
    this.secondaryLabel,
    this.onPrimary,
    this.onSecondary,
    this.isDestructive = false,
    this.customIcon,
  });

  static Future<void> error(
    BuildContext context, {
    String title = 'Erreur',
    required String message,
    String? detail,
    String buttonLabel = 'Compris',
    String? secondaryLabel,
    VoidCallback? onSecondary,
    bool barrierDismissible = true,
  }) {
    if (!context.mounted) return Future.value();
    return showDialog<void>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (ctx) => MedsinaDialog(
        type: MedsinaDialogType.error,
        title: title,
        message: message,
        detail: detail,
        primaryLabel: buttonLabel,
        secondaryLabel: secondaryLabel,
        onPrimary: () => Navigator.of(ctx).pop(),
        onSecondary: onSecondary == null
            ? null
            : () {
                Navigator.of(ctx).pop();
                onSecondary();
              },
      ),
    );
  }

  static Future<void> success(
    BuildContext context, {
    String title = 'Succès',
    required String message,
    String? detail,
    String buttonLabel = 'Continuer',
    String? secondaryLabel,
    VoidCallback? onSecondary,
    VoidCallback? onPrimary,
    bool barrierDismissible = true,
  }) {
    if (!context.mounted) return Future.value();
    return showDialog<void>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (ctx) => MedsinaDialog(
        type: MedsinaDialogType.success,
        title: title,
        message: message,
        detail: detail,
        primaryLabel: buttonLabel,
        secondaryLabel: secondaryLabel,
        onPrimary: () {
          Navigator.of(ctx).pop();
          onPrimary?.call();
        },
        onSecondary: onSecondary == null
            ? null
            : () {
                Navigator.of(ctx).pop();
                onSecondary();
              },
      ),
    );
  }

  static Future<void> warning(
    BuildContext context, {
    String title = 'Attention',
    required String message,
    String? detail,
    String buttonLabel = 'Compris',
    String? secondaryLabel,
    VoidCallback? onSecondary,
    VoidCallback? onPrimary,
    bool barrierDismissible = true,
  }) {
    if (!context.mounted) return Future.value();
    return showDialog<void>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (ctx) => MedsinaDialog(
        type: MedsinaDialogType.warning,
        title: title,
        message: message,
        detail: detail,
        primaryLabel: buttonLabel,
        secondaryLabel: secondaryLabel,
        onPrimary: () {
          Navigator.of(ctx).pop();
          onPrimary?.call();
        },
        onSecondary: onSecondary == null
            ? null
            : () {
                Navigator.of(ctx).pop();
                onSecondary();
              },
      ),
    );
  }

  static Future<void> info(
    BuildContext context, {
    required String title,
    required String message,
    String? detail,
    String buttonLabel = 'OK',
    String? secondaryLabel,
    VoidCallback? onSecondary,
    VoidCallback? onPrimary,
    bool barrierDismissible = true,
  }) {
    if (!context.mounted) return Future.value();
    return showDialog<void>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (ctx) => MedsinaDialog(
        type: MedsinaDialogType.info,
        title: title,
        message: message,
        detail: detail,
        primaryLabel: buttonLabel,
        secondaryLabel: secondaryLabel,
        onPrimary: () {
          Navigator.of(ctx).pop();
          onPrimary?.call();
        },
        onSecondary: onSecondary == null
            ? null
            : () {
                Navigator.of(ctx).pop();
                onSecondary();
              },
      ),
    );
  }

  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String? detail,
    String confirmLabel = 'Confirmer',
    String cancelLabel = 'Annuler',
    bool isDestructive = false,
  }) async {
    if (!context.mounted) return false;
    final res = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => MedsinaDialog(
        type: MedsinaDialogType.confirm,
        title: title,
        message: message,
        detail: detail,
        primaryLabel: confirmLabel,
        secondaryLabel: cancelLabel,
        isDestructive: isDestructive,
        onPrimary: () => Navigator.of(ctx).pop(true),
        onSecondary: () => Navigator.of(ctx).pop(false),
      ),
    );
    return res ?? false;
  }

  /// Smart helper for authentication errors with contextual titles
  static Future<void> showAuthError(
    BuildContext context,
    String message, {
    String? secondaryLabel,
    VoidCallback? onSecondary,
  }) {
    final lower = message.toLowerCase();
    String title = 'Échec de connexion';
    if (lower.contains('incorrect') || lower.contains('identifiants') || lower.contains('invalid')) {
      title = 'Identifiants incorrects';
    } else if (lower.contains('confirmer') || lower.contains('confirm')) {
      title = 'Email non confirmé';
    } else if (lower.contains('suspendu') || lower.contains('banni') || lower.contains('rejets')) {
      title = 'Compte suspendu';
    } else if (lower.contains('réseau') || lower.contains('internet') || lower.contains('network')) {
      title = 'Problème de connexion';
    } else if (lower.contains('champs') || lower.contains('remplir') || lower.contains('obligatoire')) {
      title = 'Champs incomplets';
    } else if (lower.contains('déjà utilisé') || lower.contains('already registered')) {
      title = 'Compte existant';
    }
    return error(
      context,
      title: title,
      message: message,
      secondaryLabel: secondaryLabel,
      onSecondary: onSecondary,
    );
  }

  (Color, IconData) _resolveStyle() {
    switch (type) {
      case MedsinaDialogType.error:
        return (AppTheme.medicalRed, customIcon ?? Icons.error_outline_rounded);
      case MedsinaDialogType.success:
        return (AppTheme.medicalGreen, customIcon ?? Icons.check_circle_outline_rounded);
      case MedsinaDialogType.warning:
        return (AppTheme.medicalAmber, customIcon ?? Icons.warning_amber_rounded);
      case MedsinaDialogType.info:
        return (AppTheme.accentCyan, customIcon ?? Icons.info_outline_rounded);
      case MedsinaDialogType.confirm:
        return (
          isDestructive ? AppTheme.medicalRed : AppTheme.primaryTeal,
          customIcon ?? (isDestructive ? Icons.warning_rounded : Icons.help_outline_rounded),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (accentColor, iconData) = _resolveStyle();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      elevation: 10,
      backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(iconData, color: accentColor, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 2),
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : AppTheme.clinicalNavy,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          message,
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.45,
                            color: isDark ? Colors.white70 : const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (detail != null && detail!.trim().isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTheme.darkSurfaceElevated
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    detail!,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (secondaryLabel != null) ...[
                    TextButton(
                      onPressed: onSecondary ?? () => Navigator.of(context).pop(false),
                      style: TextButton.styleFrom(
                        foregroundColor: isDark ? Colors.white70 : const Color(0xFF64748B),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                      ),
                      child: Text(
                        secondaryLabel!,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  ElevatedButton(
                    onPressed: onPrimary ?? () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      primaryLabel,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
