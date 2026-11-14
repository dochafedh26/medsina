import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../interfaces/feature_contracts.dart';
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

  /// Normalizes build number to handle Flutter split APK offsets (1000 for armv7, 2000 for arm64, 3000 for x86_64)
  static int normalizeBuildNumber(int build) {
    if (build >= 1000) {
      return build % 1000;
    }
    return build;
  }

  /// Compares semantic versions (e.g. "1.0.77" > "1.0.76")
  static bool isVersionNewer(String remoteVer, String currentVer) {
    try {
      final cleanRemote = remoteVer.replaceAll(RegExp(r'^[^\d]*'), '');
      final cleanCurrent = currentVer.replaceAll(RegExp(r'^[^\d]*'), '');
      final rParts = cleanRemote.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final cParts = cleanCurrent.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final len = rParts.length > cParts.length ? rParts.length : cParts.length;
      for (int i = 0; i < len; i++) {
        final r = i < rParts.length ? rParts[i] : 0;
        final c = i < cParts.length ? cParts[i] : 0;
        if (r > c) return true;
        if (r < c) return false;
      }
    } catch (_) {}
    return false;
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
      final releaseData = await SupabaseService.fetchLatestRelease(
        platformStr,
        appId: MedsinaFeatureRegistry.instance.appId,
      );

      if (releaseData == null) {
        return UpdateCheckResult(
          status: UpdateCheckStatus.upToDate,
          currentVersion: currentVersion,
          currentBuildNumber: currentBuild,
        );
      }

      final release = AppReleaseModel.fromJson(releaseData);

      final normRemote = normalizeBuildNumber(release.buildNumber);
      final normCurrent = normalizeBuildNumber(currentBuild);

      final isNewerVer = isVersionNewer(release.versionName, currentVersion);
      final isOlderVer = isVersionNewer(currentVersion, release.versionName);
      final isNewerBuild = !isOlderVer && normRemote > normCurrent;

      // Check if remote version or normalized build is strictly newer than current app
      if (isNewerVer || isNewerBuild) {
        // If not ignoring dismissed builds, check if user chose to skip this optional build
        if (!ignoreDismissed && !release.isMandatory) {
          final prefs = await SharedPreferences.getInstance();
          final dismissedBuild = prefs.getInt(_keyLastDismissedBuild) ?? 0;
          if (dismissedBuild >= release.buildNumber ||
              (dismissedBuild >= 1000 && normalizeBuildNumber(dismissedBuild) >= normRemote)) {
            return UpdateCheckResult(
              status: UpdateCheckStatus.upToDate,
              latestRelease: release,
              currentVersion: currentVersion,
              currentBuildNumber: currentBuild,
            );
          }
        }

        final isMandatory = release.isMandatory ||
            normCurrent < normalizeBuildNumber(release.minSupportedBuild);

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

  /// Resolves the available high-speed download mirrors in priority order
  /// scoped to the current app (`medsina_residanat`, `medsina_externat`,
  /// `medsina_clinique`, or `medsina_all`).
  static List<String> resolveDownloadMirrors(AppReleaseModel release) {
    final mirrors = <String>[];
    final ver = release.versionName;
    final appId = MedsinaFeatureRegistry.instance.appId;

    final (tagPrefix, fileLabel, octeniumSlug) = switch (appId) {
      'medsina_residanat' => ('residanat', 'Medsina_Residanat', 'medsina-residanat'),
      'medsina_externat' => ('externat', 'Medsina_Externat', 'medsina-externat'),
      'medsina_clinique' => ('clinique', 'Medsina_Clinique', 'medsina-clinique'),
      _ => ('all', 'Medsina', 'medsina'),
    };

    // 1. Registered Supabase downloadUrl first (if valid)
    final raw = release.downloadUrl.trim();
    if (raw.isNotEmpty && !raw.contains('None')) {
      mirrors.add(raw);
    }

    if (currentPlatform == 'android') {
      // 2. App-specific GitHub Releases CDN
      final ghUrl =
          'https://github.com/dochafedh26/medsina/releases/download/$tagPrefix-v$ver/${fileLabel}_v${ver}_Android.apk';
      if (!mirrors.contains(ghUrl)) mirrors.add(ghUrl);

      // 3. App-specific Octenium mirrors
      final octVerUrl =
          'https://medsina.medevsync.com/releases/${fileLabel}_v${ver}_Android.apk';
      final octLatestUrl =
          'https://medsina.medevsync.com/download/$octeniumSlug.apk';
      if (!mirrors.contains(octVerUrl)) mirrors.add(octVerUrl);
      if (!mirrors.contains(octLatestUrl)) mirrors.add(octLatestUrl);
    } else {
      // Windows Desktop mirrors
      final ghWinUrl =
          'https://github.com/dochafedh26/medsina/releases/download/$tagPrefix-v$ver/${fileLabel}_v${ver}_Windows_Portable.zip';
      if (!mirrors.contains(ghWinUrl)) mirrors.add(ghWinUrl);

      final octWinUrl =
          'https://medsina.medevsync.com/releases/${fileLabel}_v${ver}_Windows_Portable.zip';
      final octLatestWinUrl =
          'https://medsina.medevsync.com/download/$octeniumSlug-windows.zip';
      if (!mirrors.contains(octWinUrl)) mirrors.add(octWinUrl);
      if (!mirrors.contains(octLatestWinUrl)) mirrors.add(octLatestWinUrl);
    }

    return mirrors;
  }

  /// Returns a valid, non-corrupted download URL fallback if the registered one contains invalid values
  static String sanitizeDownloadUrl(AppReleaseModel release) {
    final mirrors = resolveDownloadMirrors(release);
    return mirrors.isNotEmpty ? mirrors.first : release.downloadUrl.trim();
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
    final mirrors = resolveDownloadMirrors(release);
    final primaryUrl = mirrors.isNotEmpty ? mirrors.first : sanitizeDownloadUrl(release);

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
      final uri = Uri.parse(primaryUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      }
      return false;
    }

    // Android Direct APK download and in-app prompt
    final tempDir = await getTemporaryDirectory();
    final apkPath = '${tempDir.path}/medsina_update_${release.versionName}_${release.buildNumber}.apk';
    final file = File(apkPath);

    bool downloadSucceeded = false;

    for (int i = 0; i < mirrors.length; i++) {
      final mirrorUrl = mirrors[i];
      try {
        if (await file.exists()) {
          try {
            await file.delete();
          } catch (_) {}
        }

        final mirrorLabel = i == 0 ? 'CDN Haute Vitesse' : 'Serveur Miroir ${i}';
        onStatusChange('Téléchargement ($mirrorLabel)...');

        await _dio.download(
          mirrorUrl,
          apkPath,
          options: Options(
            followRedirects: true,
            maxRedirects: 8,
            receiveTimeout: const Duration(minutes: 5),
            sendTimeout: const Duration(seconds: 30),
          ),
          onReceiveProgress: (received, total) {
            if (total > 0) {
              final progress = received / total;
              onProgress(progress);
            }
          },
        );

        if (await file.exists() && await file.length() > 5 * 1024 * 1024) {
          final raf = await file.open();
          final header = await raf.read(2);
          await raf.close();
          if (header.length == 2 && header[0] == 0x50 && header[1] == 0x4B) {
            downloadSucceeded = true;
            break;
          } else {
            debugPrint('Mirror $mirrorUrl returned non-APK content (invalid magic bytes).');
            try {
              await file.delete();
            } catch (_) {}
          }
        }
      } catch (e) {
        debugPrint('Mirror $mirrorUrl failed: $e');
        if (i == mirrors.length - 1 && !downloadSucceeded) {
          // All mirrors failed, try direct browser fallback
          onStatusChange('Téléchargement direct via navigateur...');
          try {
            final uri = Uri.parse(primaryUrl);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
              return true;
            }
          } catch (_) {}
          return false;
        }
      }
    }

    if (!downloadSucceeded) {
      return false;
    }

    try {
      onStatusChange('Lancement de l\'installation...');
      final result = await OpenFilex.open(
        apkPath,
        type: 'application/vnd.android.package-archive',
      );

      debugPrint('OpenFilex install result: ${result.type} - ${result.message}');

      // If package installer didn't trigger cleanly, fallback to browser
      if (result.type != ResultType.done) {
        debugPrint('OpenFilex non-done result (${result.message}), launching browser fallback...');
        onStatusChange('Ouverture du navigateur pour installer...');
        final uri = Uri.parse(primaryUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return true;
        }
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('Error triggering APK installer: $e');
      onStatusChange('Téléchargement direct via navigateur...');
      try {
        final uri = Uri.parse(primaryUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return true;
        }
      } catch (_) {}
      return false;
    }
  }
}
