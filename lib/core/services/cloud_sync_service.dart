import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../interfaces/feature_contracts.dart';
import '../network/supabase_service.dart';

/// Central Cross-Device Cloud Sync Service for Medsina.
/// Delegates domain-specific sync to registered [CloudSyncParticipant]s
/// so `medsina_core` stays decoupled from feature packages.
class CloudSyncService extends ChangeNotifier {
  CloudSyncService._();
  static final CloudSyncService instance = CloudSyncService._();

  static const String _lastSyncKey = 'medsina_last_cloud_sync_iso';

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  DateTime? _lastSyncTime;
  DateTime? get lastSyncTime => _lastSyncTime;

  String? _lastError;
  String? get lastError => _lastError;

  /// Initializes the service and loads last known sync timestamp
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final iso = prefs.getString(_lastSyncKey);
    if (iso != null && iso.isNotEmpty) {
      _lastSyncTime = DateTime.tryParse(iso);
    }
  }

  /// Full Bidirectional Synchronization across all registered participants.
  Future<bool> syncAll({bool forceUpload = false}) async {
    final user = SupabaseService.currentUser;
    if (user == null) {
      debugPrint('[CloudSync] No authenticated user. Sync skipped.');
      return false;
    }

    if (_isSyncing) return false;
    _isSyncing = true;
    _lastError = null;
    notifyListeners();

    try {
      debugPrint('[CloudSync] Starting bidirectional sync for user: ${user.id}...');
      final remoteRecords = await SupabaseService.fetchUserSyncData(user.id);
      final remoteMap = <String, dynamic>{
        for (var r in remoteRecords) (r['data_type'] as String): r['payload'],
      };

      for (final participant in MedsinaFeatureRegistry.instance.syncParticipants) {
        await participant.sync(user.id, remoteMap, forceUpload: forceUpload);
      }

      _lastSyncTime = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastSyncKey, _lastSyncTime!.toIso8601String());

      debugPrint('[CloudSync] Full sync completed successfully at $_lastSyncTime');
      _isSyncing = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[CloudSync] Error during syncAll: $e');
      _lastError = e.toString();
      _isSyncing = false;
      notifyListeners();
      return false;
    }
  }

  /// Fire-and-forget helper to push a specific data_type asynchronously upon local modification.
  void notifyLocalChange(String dataType, dynamic payload) {
    final user = SupabaseService.currentUser;
    if (user == null) return;

    SupabaseService.upsertUserSyncData(
      userId: user.id,
      dataType: dataType,
      payload: payload,
    ).then((ok) {
      if (ok) {
        _lastSyncTime = DateTime.now();
        notifyListeners();
      }
    });
  }
}
