import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/module_model.dart';

enum OfflineDownloadStatus {
  notDownloaded,
  downloading,
  downloaded,
  failed,
}

class DownloadedCourseInfo {
  final CourseModel course;
  final MedicalModuleModel module;
  final int fileSizeBytes;
  final String formattedSize;

  const DownloadedCourseInfo({
    required this.course,
    required this.module,
    required this.fileSizeBytes,
    required this.formattedSize,
  });
}

/// Central offline storage and download manager for Medsina courses.
/// Allows medical students and doctors to cache course PDFs and materials
/// for 100% offline access anywhere without mobile data.
class OfflineCourseManager extends ChangeNotifier {
  OfflineCourseManager._();
  static final OfflineCourseManager instance = OfflineCourseManager._();

  static const String _wifiOnlyKey = 'medsina_offline_wifi_only';
  final Dio _dio = Dio();

  bool _isWifiOnly = false;
  bool get isWifiOnly => _isWifiOnly;

  final Map<String, double> _downloadProgress = {};
  double getProgress(String courseId) => _downloadProgress[courseId] ?? 0.0;

  final Map<String, CancelToken> _cancelTokens = {};

  bool _initialized = false;
  Directory? _cacheDir;

  Future<void> initialize() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _isWifiOnly = prefs.getBool(_wifiOnlyKey) ?? false;

    final appDocDir = await getApplicationDocumentsDirectory();
    _cacheDir = Directory('${appDocDir.path}/medsina_secure_cache');
    if (!await _cacheDir!.exists()) {
      await _cacheDir!.create(recursive: true);
    }
    _initialized = true;
  }

  Future<void> setWifiOnly(bool value) async {
    _isWifiOnly = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_wifiOnlyKey, value);
    notifyListeners();
  }

  String _getSafeFileName(String courseId) {
    final sanitized = courseId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    return 'c_$sanitized.dat';
  }

  Future<File> getCourseFile(String courseId) async => _getFile(courseId);

  Future<File> _getFile(String courseId) async {
    await initialize();
    final primary = File('${_cacheDir!.path}/${_getSafeFileName(courseId)}');
    if (primary.existsSync() && primary.lengthSync() > 1024) {
      return primary;
    }
    try {
      final supportDir = await getApplicationSupportDirectory();
      final alt = File('${supportDir.path}/medsina_secure_cache/${_getSafeFileName(courseId)}');
      if (alt.existsSync() && alt.lengthSync() > 1024) {
        return alt;
      }
    } catch (_) {}
    return primary;
  }

  /// Checks if a course is downloaded and valid in local sandbox
  Future<bool> isCourseAvailableOffline(String courseId) async {
    try {
      final file = await _getFile(courseId);
      if (await file.exists()) {
        final len = await file.length();
        return len > 1024;
      }
    } catch (_) {}
    return false;
  }

  /// Synchronous fast-check if cacheDir is initialized
  bool isCourseAvailableOfflineSync(String courseId) {
    if (_cacheDir == null) return false;
    try {
      final file = File('${_cacheDir!.path}/${_getSafeFileName(courseId)}');
      return file.existsSync() && file.lengthSync() > 1024;
    } catch (_) {
      return false;
    }
  }

  /// Returns human-readable size of a downloaded course file
  Future<String?> getCourseFileSizeFormatted(String courseId) async {
    try {
      final file = await _getFile(courseId);
      if (await file.exists()) {
        final bytes = await file.length();
        return formatBytes(bytes);
      }
    } catch (_) {}
    return null;
  }

  String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} Ko';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} Mo';
  }

  /// Resolves direct stream download URL from Google Drive ID
  String _getStreamUrl(CourseModel course) {
    final driveId = course.pdfDriveId ?? '';
    if (driveId.isNotEmpty && driveId.length > 10) {
      return 'https://drive.google.com/uc?export=download&id=$driveId';
    }
    final rawUrl = course.pdfDownloadUrl ?? '';
    if (rawUrl.contains('/d/')) {
      final parts = rawUrl.split('/d/');
      if (parts.length > 1) {
        final id = parts[1].split('/')[0];
        return 'https://drive.google.com/uc?export=download&id=$id';
      }
    }
    return rawUrl;
  }

  /// Downloads a single course for permanent offline reading
  Future<bool> downloadCourse(
    CourseModel course, {
    Function(double progress)? onProgress,
  }) async {
    await initialize();

    final streamUrl = _getStreamUrl(course);
    if (streamUrl.isEmpty) {
      debugPrint('[OfflineManager] Empty stream URL for course: ${course.name}');
      return false;
    }

    final targetFile = await _getFile(course.id);
    final tempFile = File('${targetFile.path}.tmp');

    final cancelToken = CancelToken();
    _cancelTokens[course.id] = cancelToken;
    _downloadProgress[course.id] = 0.01;
    notifyListeners();

    try {
      await _dio.download(
        streamUrl,
        tempFile.path,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final p = received / total;
            _downloadProgress[course.id] = p;
            onProgress?.call(p);
            notifyListeners();
          }
        },
      );

      // Verify file size
      if (await tempFile.exists() && await tempFile.length() > 1024) {
        if (await targetFile.exists()) {
          await targetFile.delete();
        }
        await tempFile.rename(targetFile.path);
        _downloadProgress.remove(course.id);
        _cancelTokens.remove(course.id);
        notifyListeners();
        debugPrint('[OfflineManager] Successfully downloaded course: ${course.name}');
        return true;
      } else {
        throw Exception('Downloaded file is empty or corrupted');
      }
    } catch (e) {
      debugPrint('[OfflineManager] Error downloading course ${course.name}: $e');
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
      _downloadProgress.remove(course.id);
      _cancelTokens.remove(course.id);
      notifyListeners();
      return false;
    }
  }

  /// Cancels an in-progress download
  void cancelDownload(String courseId) {
    if (_cancelTokens.containsKey(courseId)) {
      _cancelTokens[courseId]?.cancel();
      _cancelTokens.remove(courseId);
      _downloadProgress.remove(courseId);
      notifyListeners();
    }
  }

  /// Deletes a cached course file to free space
  Future<void> deleteCourse(String courseId) async {
    try {
      final file = await _getFile(courseId);
      if (await file.exists()) {
        await file.delete();
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[OfflineManager] Error deleting course file: $e');
    }
  }

  /// Deletes all cached courses of a module
  Future<void> deleteModule(MedicalModuleModel module) async {
    for (final c in module.courses) {
      await deleteCourse(c.id);
    }
    notifyListeners();
  }

  /// Batch downloads an entire module for offline use
  Future<void> downloadEntireModule(
    MedicalModuleModel module, {
    Function(int current, int total, String courseName)? onOverallProgress,
  }) async {
    final courses = module.courses;
    final total = courses.length;

    for (int i = 0; i < total; i++) {
      final c = courses[i];
      final isAlready = await isCourseAvailableOffline(c.id);
      if (!isAlready) {
        onOverallProgress?.call(i + 1, total, c.name);
        await downloadCourse(c);
      } else {
        onOverallProgress?.call(i + 1, total, c.name);
      }
    }
    notifyListeners();
  }

  /// Total offline cache size across all downloaded courses
  Future<int> getTotalOfflineBytes() async {
    await initialize();
    int total = 0;
    try {
      if (await _cacheDir!.exists()) {
        final list = _cacheDir!.listSync();
        for (var f in list) {
          if (f is File) {
            total += f.lengthSync();
          }
        }
      }
    } catch (_) {}
    return total;
  }

  /// Formatted total storage used
  Future<String> getTotalOfflineFormatted() async {
    final bytes = await getTotalOfflineBytes();
    return formatBytes(bytes);
  }

  /// Clears all offline cache files
  Future<void> clearAllStorage() async {
    await initialize();
    try {
      if (await _cacheDir!.exists()) {
        final list = _cacheDir!.listSync();
        for (var f in list) {
          if (f is File) {
            try {
              f.deleteSync();
            } catch (_) {}
          }
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[OfflineManager] Error clearing storage: $e');
    }
  }

  /// Scans modules and returns list of all courses currently downloaded locally
  Future<List<DownloadedCourseInfo>> getDownloadedCoursesInfo(List<MedicalModuleModel> allModules) async {
    await initialize();
    final list = <DownloadedCourseInfo>[];
    for (final mod in allModules) {
      for (final c in mod.courses) {
        final file = await _getFile(c.id);
        if (await file.exists()) {
          final len = await file.length();
          if (len > 1024) {
            list.add(DownloadedCourseInfo(
              course: c,
              module: mod,
              fileSizeBytes: len,
              formattedSize: formatBytes(len),
            ));
          }
        }
      }
    }
    return list;
  }
}
