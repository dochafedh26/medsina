import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/auth/models/user_model.dart';
import '../../features/subscription/presentation/subscription_paywall_screen.dart';
import '../constants/app_constants.dart';
import '../network/supabase_service.dart';
import '../theme/app_theme.dart';

class FreeTrialQuotaService {
  FreeTrialQuotaService._();
  static final FreeTrialQuotaService instance = FreeTrialQuotaService._();

  static const String _prefsKeyPrefix = 'medsina_trial_quotas_';

  List<String> _selectedFreeModules = [];
  int _qcmSessionsUsed = 0;
  int _prescriptionAnalysesUsed = 0;
  int _labAnalysesUsed = 0;
  int _copilotQueriesUsed = 0;
  bool _hasUsedTrial = false;

  List<String> get selectedFreeModules => List.unmodifiable(_selectedFreeModules);
  int get qcmSessionsUsed => _qcmSessionsUsed;
  int get prescriptionAnalysesUsed => _prescriptionAnalysesUsed;
  int get labAnalysesUsed => _labAnalysesUsed;
  int get copilotQueriesUsed => _copilotQueriesUsed;
  bool get hasUsedTrial => _hasUsedTrial;

  /// Load quotas from Supabase database with local cache fallback
  Future<void> loadQuotas(String? userId) async {
    if (userId == null || userId.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final localDataStr = prefs.getString('$_prefsKeyPrefix$userId');
    if (localDataStr != null) {
      try {
        final localData = jsonDecode(localDataStr) as Map<String, dynamic>;
        _applyData(localData);
      } catch (_) {}
    }

    // Fetch from Supabase Cloud
    try {
      final cloudData = await SupabaseService.fetchUserTrialQuotas(userId);
      if (cloudData != null) {
        _applyData(cloudData);
        await prefs.setString('$_prefsKeyPrefix$userId', jsonEncode(cloudData));
      }
    } catch (e) {
      debugPrint('Error syncing trial quotas from Cloud: $e');
    }
  }

  void _applyData(Map<String, dynamic> data) {
    if (data['selected_free_modules'] is List) {
      _selectedFreeModules = (data['selected_free_modules'] as List)
          .map((e) => e.toString().trim())
          .toList();
    }
    _qcmSessionsUsed = (data['qcm_sessions_used'] as num?)?.toInt() ?? _qcmSessionsUsed;
    _prescriptionAnalysesUsed = (data['prescription_analyses_used'] as num?)?.toInt() ?? _prescriptionAnalysesUsed;
    _labAnalysesUsed = (data['lab_analyses_used'] as num?)?.toInt() ?? _labAnalysesUsed;
    _copilotQueriesUsed = (data['copilot_queries_used'] as num?)?.toInt() ?? _copilotQueriesUsed;
    _hasUsedTrial = data['has_used_trial'] == true || _hasUsedTrial;
  }

  /// Save the 2 chosen specialty modules for Pass Découverte
  Future<bool> selectFreeModules(String userId, List<String> moduleNames) async {
    if (moduleNames.isEmpty) return false;
    final limited = moduleNames.take(2).toList();
    _selectedFreeModules = limited;

    // Cache locally
    final prefs = await SharedPreferences.getInstance();
    final map = {
      'selected_free_modules': _selectedFreeModules,
      'qcm_sessions_used': _qcmSessionsUsed,
      'prescription_analyses_used': _prescriptionAnalysesUsed,
      'lab_analyses_used': _labAnalysesUsed,
      'copilot_queries_used': _copilotQueriesUsed,
      'has_used_trial': true,
    };
    await prefs.setString('$_prefsKeyPrefix$userId', jsonEncode(map));

    // Save to Supabase Cloud
    return await SupabaseService.saveSelectedFreeModules(userId, limited);
  }

  /// Normalize module name for matching
  String normalizeModuleName(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[àâä]'), 'a')
        .replaceAll(RegExp(r'[îï]'), 'i')
        .replaceAll(RegExp(r'[ôö]'), 'o')
        .replaceAll(RegExp(r'[ùûü]'), 'u')
        .replaceAll(RegExp(r'[^a-z0-9]'), '')
        .trim();
  }

  /// Determines whether a course is unlocked based on tier and selected modules
  bool isCourseUnlocked(UserModel? user, String moduleName, int courseIndexInModule) {
    if (user == null) return false;
    if (user.isAdmin) return true;
    if (!user.isSubscriptionActive) return false;

    // Full access tiers
    if (user.tier == SubscriptionTier.allAccess || user.tier == SubscriptionTier.residentElite) {
      return true;
    }

    // Pass Découverte (free) & ClinicalPro (preview)
    // Only unlocked if module matches one of the 2 chosen free modules AND course index is 0 or 1
    if (_selectedFreeModules.isEmpty) return false;

    final targetNorm = normalizeModuleName(moduleName);
    final isChosen = _selectedFreeModules.any((m) {
      final chosenNorm = normalizeModuleName(m);
      return targetNorm.contains(chosenNorm) || chosenNorm.contains(targetNorm);
    });

    if (isChosen && courseIndexInModule < 2) {
      return true;
    }

    return false;
  }

  /// QCM Revision Session Quota Check (Max 1 for free tier)
  bool canStartQcmSession(UserModel? user) {
    if (user == null) return false;
    if (user.isAdmin || user.tier != SubscriptionTier.free) return true;
    return _qcmSessionsUsed < 1;
  }

  Future<void> consumeQcmSession(UserModel? user) async {
    if (user == null || user.tier != SubscriptionTier.free) return;
    _qcmSessionsUsed += 1;
    _hasUsedTrial = true;
    await _saveQuotaLocallyAndCloud(user.id, 'qcm_session');
  }

  /// Prescription Analysis Quota Check (Max 1 for free tier)
  bool canAnalyzePrescription(UserModel? user) {
    if (user == null) return false;
    if (user.isAdmin || user.tier != SubscriptionTier.free) return true;
    return _prescriptionAnalysesUsed < 1;
  }

  Future<void> consumePrescriptionAnalysis(UserModel? user) async {
    if (user == null || user.tier != SubscriptionTier.free) return;
    _prescriptionAnalysesUsed += 1;
    _hasUsedTrial = true;
    await _saveQuotaLocallyAndCloud(user.id, 'prescription_analysis');
  }

  /// Lab Analysis Quota Check (Max 1 for free tier)
  bool canAnalyzeLab(UserModel? user) {
    if (user == null) return false;
    if (user.isAdmin || user.tier != SubscriptionTier.free) return true;
    return _labAnalysesUsed < 1;
  }

  Future<void> consumeLabAnalysis(UserModel? user) async {
    if (user == null || user.tier != SubscriptionTier.free) return;
    _labAnalysesUsed += 1;
    _hasUsedTrial = true;
    await _saveQuotaLocallyAndCloud(user.id, 'lab_analysis');
  }

  /// MedsinaPilot Copilot Quota Check (Max 1 for free tier)
  bool canUseCopilot(UserModel? user) {
    if (user == null) return false;
    if (user.isAdmin || user.tier != SubscriptionTier.free) return true;
    return _copilotQueriesUsed < 1;
  }

  Future<void> consumeCopilotQuery(UserModel? user) async {
    if (user == null || user.tier != SubscriptionTier.free) return;
    _copilotQueriesUsed += 1;
    _hasUsedTrial = true;
    await _saveQuotaLocallyAndCloud(user.id, 'copilot_query');
  }

  Future<void> _saveQuotaLocallyAndCloud(String userId, String quotaType) async {
    final prefs = await SharedPreferences.getInstance();
    final map = {
      'selected_free_modules': _selectedFreeModules,
      'qcm_sessions_used': _qcmSessionsUsed,
      'prescription_analyses_used': _prescriptionAnalysesUsed,
      'lab_analyses_used': _labAnalysesUsed,
      'copilot_queries_used': _copilotQueriesUsed,
      'has_used_trial': true,
    };
    await prefs.setString('$_prefsKeyPrefix$userId', jsonEncode(map));

    try {
      await SupabaseService.consumeTrialQuota(userId, quotaType);
    } catch (_) {}
  }

  /// Display a professional quota limit dialog
  static void showQuotaLimitDialog(
    BuildContext context, {
    required String featureTitle,
    required String message,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.workspace_premium_rounded, color: Colors.amber.shade900, size: 24),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                featureTitle,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: const TextStyle(fontSize: 13, height: 1.45),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryTeal.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.primaryTeal.withValues(alpha: 0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock_clock_rounded, size: 18, color: AppTheme.primaryTeal),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Passez à la vitesse supérieure sans limites d\'usage.',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.primaryTeal),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Plus tard'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryTeal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
            label: const Text('Découvrir les Abonnements', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubscriptionPaywallScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}

