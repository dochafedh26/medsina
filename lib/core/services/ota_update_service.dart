import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_release_model.dart';
import '../network/supabase_service.dart';

enum UpdateCheckStatus {
  upToDate,
  updateAvailable,
  mandatoryUpdateAvailable,
  error,
}

class UpdateCheckResult {
  final UpdateCheckStatus status;
  final AppReleaseModel? latestRelease;
  final String currentVersion;
  final int currentBuildNumber;
  final String? errorMessage;

  const UpdateCheckResult({
    required this.status,
    this.latestRelease,
    required this.currentVersion,
    required this.currentBuildNumber,
    this.errorMessage,
  });

  bool get hasUpdate =>
      status == UpdateCheckStatus.updateAvailable ||
      status == UpdateCheckStatus.mandatoryUpdateAvailable;

  bool get isMandatory => status == UpdateCheckStatus.mandatoryUpdateAvailable;
}

class OtaUpdateService {
  static final Dio _dio = Dio();
  static const String _keyLastDismissedBuild = 'ota_last_dismissed_build';

  /// Detect the current operating platform string
  static String get currentPlatform {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isWindows) return 'windows';
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }

  /// Checks if an OTA update is available for the current app
  static Future<UpdateCheckResult> checkForUpdates({
    bool ignoreDismissed = false,
  }) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 1;

      final platformStr = currentPlatform;
      final releaseData = await SupabaseService.fetchLatestRelease(platformStr);

      if (releaseData == null) {
        return UpdateCheckResult(
          status: UpdateCheckStatus.upToDate,
          currentVersion: currentVersion,
          currentBuildNumber: currentBuild,
        );
      }

      final release = AppReleaseModel.fromJson(releaseData);

      // Check if remote build is strictly newer than current app build
      if (release.buildNumber > currentBuild) {
        // If not ignoring dismissed builds, check if user chose to skip this optional build
        if (!ignoreDismissed && !release.isMandatory) {
          final prefs = await SharedPreferences.getInstance();
          final dismissedBuild = prefs.getInt(_keyLastDismissedBuild) ?? 0;
          if (dismissedBuild >= release.buildNumber) {
            return UpdateCheckResult(
              status: UpdateCheckStatus.upToDate,
              latestRelease: release,
              currentVersion: currentVersion,
              currentBuildNumber: currentBuild,
            );
          }
        }

        final isMandatory = release.isMandatory || currentBuild < release.minSupportedBuild;

        return UpdateCheckResult(
          status: isMandatory
              ? UpdateCheckStatus.mandatoryUpdateAvailable
              : UpdateCheckStatus.updateAvailable,
          latestRelease: release,
          currentVersion: currentVersion,
          currentBuildNumber: currentBuild,
        );
      }

      return UpdateCheckResult(
        status: UpdateCheckStatus.upToDate,
        latestRelease: release,
        currentVersion: currentVersion,
        currentBuildNumber: currentBuild,
      );
    } catch (e) {
      debugPrint('Error checking for OTA updates: $e');
      return UpdateCheckResult(
        status: UpdateCheckStatus.error,
        currentVersion: '1.0.0',
        currentBuildNumber: 1,
        errorMessage: e.toString(),
      );
    }
  }

  /// Saves the user's choice to skip this optional build reminder
  static Future<void> dismissBuild(int buildNumber) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLastDismissedBuild, buildNumber);
  }

  /// Returns a valid, non-corrupted download URL fallback if the registered one contains invalid values
  static String sanitizeDownloadUrl(AppReleaseModel release) {
    final raw = release.downloadUrl.trim();
    if (raw.isEmpty || raw.contains('None')) {
      if (currentPlatform == 'android') {
        return 'https://github.com/dochafedh26/medsina/releases/download/v${release.versionName}/Medsina_v${release.versionName}_Android.apk';
      } else {
        return 'https://github.com/dochafedh26/medsina/releases/download/v${release.versionName}/Medsina_v${release.versionName}_Windows_Setup.exe';
      }
    }
    return raw;
  }

  /// Downloads the update file and triggers the installation
  /// On Android: Downloads APK and prompts system package installer.
  /// If package installer fails or is blocked, seamlessly falls back to external browser download.
  /// On Windows/Web: Launches direct download URL in default browser.
  static Future<bool> startUpdateProcess(
    AppReleaseModel release, {
    required void Function(double progress) onProgress,
    required void Function(String statusMessage) onStatusChange,
  }) async {
    final effectiveUrl = sanitizeDownloadUrl(release);

    // Record download telemetry on Supabase
    try {
      SupabaseService.recordOcteniumDownload(
        platform: currentPlatform,
        source: 'in_app_ota',
        version: release.versionName,
      );
    } catch (_) {}

    if (kIsWeb || !Platform.isAndroid) {
      // Windows / Web / Desktop: open official download or web release page
      final uri = Uri.parse(effectiveUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      }
      return false;
    }

    // Android Direct APK download and in-app prompt
    try {
      onStatusChange('Préparation du téléchargement...');
      final tempDir = await getTemporaryDirectory();
      final apkPath = '${tempDir.path}/medsina_update_${release.versionName}_${release.buildNumber}.apk';
      final file = File(apkPath);

      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }

      onStatusChange('Téléchargement de la mise à jour...');
      await _dio.download(
        effectiveUrl,
        apkPath,
        options: Options(
          followRedirects: true,
          maxRedirects: 5,
        ),
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = received / total;
            onProgress(progress);
          }
        },
      );

      onStatusChange('Lancement de l\'installation...');
      final result = await OpenFilex.open(
        apkPath,
        type: 'application/vnd.android.package-archive',
      );

      debugPrint('OpenFilex install result: ${result.type} - ${result.message}');

      // If package installer didn't trigger cleanly (e.g. unknown sources blocked on Android), fallback to browser
      if (result.type != ResultType.done) {
        debugPrint('OpenFilex non-done result (${result.message}), launching browser fallback...');
        onStatusChange('Ouverture du navigateur pour installer...');
        final uri = Uri.parse(effectiveUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return true;
        }
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('Error downloading or installing APK: $e');
      onStatusChange('Téléchargement direct via navigateur...');
      try {
        final uri = Uri.parse(effectiveUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return true;
        }
      } catch (_) {}
      return false;
    }
  }
}
