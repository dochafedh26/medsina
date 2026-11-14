import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../network/supabase_service.dart';

class PlatformStats {
  final int modulesCount;
  final int qcmCount;
  final int summariesCount;
  final int protocolsCount;
  final int labValuesCount;
  final int mementosCount;
  final int drugsCount;
  final int emergencyDrugsCount;
  final DateTime? updatedAt;

  const PlatformStats({
    this.modulesCount = 53,
    this.qcmCount = 6240,
    this.summariesCount = 105,
    this.protocolsCount = 18,
    this.labValuesCount = 90,
    this.mementosCount = 51,
    this.drugsCount = 5425,
    this.emergencyDrugsCount = 67,
    this.updatedAt,
  });

  factory PlatformStats.fromJson(Map<String, dynamic> json) {
    return PlatformStats(
      modulesCount: (json['modules_count'] as num?)?.toInt() ?? 53,
      qcmCount: (json['qcm_count'] as num?)?.toInt() ?? 6240,
      summariesCount: (json['summaries_count'] as num?)?.toInt() ?? 105,
      protocolsCount: (json['protocols_count'] as num?)?.toInt() ?? 18,
      labValuesCount: (json['lab_values_count'] as num?)?.toInt() ?? 90,
      mementosCount: (json['mementos_count'] as num?)?.toInt() ?? 51,
      drugsCount: (json['drugs_count'] as num?)?.toInt() ?? 5425,
      emergencyDrugsCount: (json['emergency_drugs_count'] as num?)?.toInt() ?? 67,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'modules_count': modulesCount,
        'qcm_count': qcmCount,
        'summaries_count': summariesCount,
        'protocols_count': protocolsCount,
        'lab_values_count': labValuesCount,
        'mementos_count': mementosCount,
        'drugs_count': drugsCount,
        'emergency_drugs_count': emergencyDrugsCount,
        'updated_at': updatedAt?.toIso8601String(),
      };

  static String formatCount(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) {
        buf.write(' ');
      }
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

class PlatformStatsService {
  PlatformStatsService._();
  static final PlatformStatsService instance = PlatformStatsService._();

  static const String _cacheKey = 'medsina_platform_stats_v1';
  static const Duration _cacheTtl = Duration(minutes: 15);

  final ValueNotifier<PlatformStats> statsNotifier =
      ValueNotifier<PlatformStats>(const PlatformStats());

  bool _initialized = false;
  bool _isRefreshing = false;

  Future<void> ensureLoaded({bool forceRefresh = false}) async {
    if (!_initialized) {
      _initialized = true;
      await _loadFromCache();
    }

    final lastUpdated = statsNotifier.value.updatedAt;
    final isStale = lastUpdated == null ||
        DateTime.now().difference(lastUpdated) > _cacheTtl;

    if (forceRefresh || isStale) {
      await refresh();
    }
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        statsNotifier.value = PlatformStats.fromJson(decoded);
      }
    } catch (e) {
      debugPrint('Error loading cached platform stats: $e');
    }
  }

  Future<int> _safeExactCount(String table, int fallback) async {
    try {
      final count = await SupabaseService.client
          .from(table)
          .count(CountOption.exact)
          .timeout(const Duration(seconds: 5));
      return count > 0 ? count : fallback;
    } catch (_) {
      return fallback;
    }
  }

  Future<void> refresh() async {
    if (_isRefreshing) return;
    _isRefreshing = true;

    try {
      final current = statsNotifier.value;
      final results = await Future.wait<int>([
        _safeExactCount('medical_modules', current.modulesCount),
        _safeExactCount('qcm_questions', current.qcmCount),
        _safeExactCount('course_summaries', current.summariesCount),
        _safeExactCount('clinical_protocols', current.protocolsCount),
        _safeExactCount('lab_reference_values', current.labValuesCount),
        _safeExactCount('on_call_mementos', current.mementosCount),
        _safeExactCount('algerian_nomenclature', current.drugsCount),
        _safeExactCount('emergency_drugs', current.emergencyDrugsCount),
      ]);

      final updated = PlatformStats(
        modulesCount: results[0],
        qcmCount: results[1],
        summariesCount: results[2],
        protocolsCount: results[3],
        labValuesCount: results[4],
        mementosCount: results[5],
        drugsCount: results[6],
        emergencyDrugsCount: results[7],
        updatedAt: DateTime.now(),
      );

      statsNotifier.value = updated;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(updated.toJson()));
    } catch (e) {
      debugPrint('Error refreshing platform stats: $e');
    } finally {
      _isRefreshing = false;
    }
  }
}
