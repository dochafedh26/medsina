import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../network/supabase_service.dart';

/// Centralized launcher for the Medsina Admin Dashboard.
///
/// Reliably opens the production web dashboard on Octenium with
/// fallback support for platformDefault and in-app browser.
class AdminDashboardLauncher {
  static const String adminUrl = 'https://medsina.medevsync.com/admin/';

  static Future<void> openAdminDashboard(BuildContext context) async {
    final session = SupabaseService.client.auth.currentSession;
    final token = session?.accessToken;
    final refreshToken = session?.refreshToken;

    final fullUrl = (token != null && token.isNotEmpty)
        ? '$adminUrl?token=${Uri.encodeComponent(token)}&refresh_token=${Uri.encodeComponent(refreshToken ?? '')}'
        : adminUrl;

    final uri = Uri.parse(fullUrl);
    bool launched = false;

    // Web environment: open directly in new browser tab without popup blocker delay
    if (kIsWeb) {
      try {
        launched = await launchUrl(uri, webOnlyWindowName: '_blank');
      } catch (_) {
        launched = false;
      }
    } else {
      // 1. Attempt launching with external application (preferred browser)
      try {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        launched = false;
      }

      // 2. Fallback to platformDefault mode
      if (!launched) {
        try {
          launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
        } catch (_) {
          launched = false;
        }
      }

      // 3. Fallback to inAppBrowserView
      if (!launched) {
        try {
          launched = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
        } catch (_) {
          launched = false;
        }
      }
    }

    // 4. If all external launchers fail, provide copy snackbar
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFDC2626),
          content: const Text(
            'Impossible d\'ouvrir le navigateur. URL : $adminUrl',
          ),
          action: SnackBarAction(
            label: 'Copier',
            textColor: Colors.white,
            onPressed: () {
              Clipboard.setData(const ClipboardData(text: adminUrl));
            },
          ),
        ),
      );
    }
  }
}
