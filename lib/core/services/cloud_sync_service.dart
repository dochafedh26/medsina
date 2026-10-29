import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/revision/models/flashcard_fsrs_model.dart';
import '../../features/revision/models/revision_session_model.dart';
import '../../features/revision/services/revision_session_storage.dart';
import '../../features/revision/services/user_qcm_annotation_service.dart';
import '../network/supabase_service.dart';

/// Central Cross-Device Cloud Sync Service for Medsina.
/// Ensures that custom sessions, course progress, QCM bookmarks, notes,
/// Study Planner layers, and FSRS Flashcards are seamlessly synchronized
/// across Windows, Android, and other devices for the authenticated user.
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

  /// Full Bidirectional Synchronization across all 5 clinical categories.
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

      // 1. Synchronize Custom Revision Sessions
      await _syncCustomSessions(user.id, remoteMap['custom_sessions'], forceUpload: forceUpload);

      // 2. Synchronize Course Revision Progress
      await _syncCourseProgress(user.id, remoteMap['course_progress'], forceUpload: forceUpload);

      // 3. Synchronize QCM Annotations, Bookmarks & Notes
      await _syncQcmAnnotations(user.id, remoteMap['qcm_annotations'], forceUpload: forceUpload);

      // 4. Synchronize Study Planner Layers (Couche 1, 2, 3)
      await _syncStudyPlanner(user.id, remoteMap['study_planner'], forceUpload: forceUpload);

      // 5. Synchronize FSRS Flashcards
      await _syncFsrsFlashcards(user.id, remoteMap['fsrs_flashcards'], forceUpload: forceUpload);

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

  // --- 1. CUSTOM SESSIONS SYNC ---
  Future<void> _syncCustomSessions(String userId, dynamic remotePayload, {bool forceUpload = false}) async {
    final storage = RevisionSessionStorage.instance;
    final localSessions = await storage.getCustomSessions();
    final localMap = <String, CustomRevisionSession>{
      for (var s in localSessions) s.id: s,
    };

    if (remotePayload is List) {
      for (var item in remotePayload) {
        if (item is Map<String, dynamic>) {
          try {
            final remoteSession = CustomRevisionSession.fromJson(item);
            final local = localMap[remoteSession.id];
            if (local == null) {
              localMap[remoteSession.id] = remoteSession;
            } else {
              // Merge: keep the one with most recent activity
              if (remoteSession.lastActiveAt.isAfter(local.lastActiveAt)) {
                localMap[remoteSession.id] = remoteSession;
              }
            }
          } catch (_) {}
        }
      }
    }

    // Save merged result locally
    final mergedList = localMap.values.toList()
      ..sort((a, b) => b.lastActiveAt.compareTo(a.lastActiveAt));

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('medsina_rev_custom_sessions', jsonEncode(mergedList.map((s) => s.toJson()).toList()));

    // Upload merged snapshot to Supabase
    await SupabaseService.upsertUserSyncData(
      userId: userId,
      dataType: 'custom_sessions',
      payload: mergedList.map((s) => s.toJson()).toList(),
    );
  }

  // --- 2. COURSE PROGRESS SYNC ---
  Future<void> _syncCourseProgress(String userId, dynamic remotePayload, {bool forceUpload = false}) async {
    final storage = RevisionSessionStorage.instance;
    final localProgresses = await storage.getAllCourseProgress();
    final mergedMap = Map<String, CourseRevisionProgress>.from(localProgresses);

    if (remotePayload is Map<String, dynamic>) {
      remotePayload.forEach((courseId, jsonVal) {
        if (jsonVal is Map<String, dynamic>) {
          try {
            final remoteProg = CourseRevisionProgress.fromJson(jsonVal);
            final local = mergedMap[courseId];
            if (local == null) {
              mergedMap[courseId] = remoteProg;
            } else {
              if (remoteProg.lastActiveAt.isAfter(local.lastActiveAt)) {
                mergedMap[courseId] = remoteProg;
              }
            }
          } catch (_) {}
        }
      });
    }

    // Persist merged progress locally
    for (var entry in mergedMap.entries) {
      await storage.saveCourseProgress(entry.value);
    }

    // Upload to Cloud
    final cloudPayload = <String, dynamic>{
      for (var entry in mergedMap.entries) entry.key: entry.value.toJson(),
    };
    await SupabaseService.upsertUserSyncData(
      userId: userId,
      dataType: 'course_progress',
      payload: cloudPayload,
    );
  }

  // --- 3. QCM ANNOTATIONS & BOOKMARKS SYNC ---
  Future<void> _syncQcmAnnotations(String userId, dynamic remotePayload, {bool forceUpload = false}) async {
    final annotService = UserQcmAnnotationService.instance;
    await annotService.ensureInitialized();
    final localAnnots = annotService.annotations;
    final mergedMap = Map<String, UserQuestionAnnotation>.from(localAnnots);

    if (remotePayload is Map<String, dynamic>) {
      remotePayload.forEach((qId, jsonVal) {
        if (jsonVal is Map<String, dynamic>) {
          try {
            final remoteAnnot = UserQuestionAnnotation.fromJson(jsonVal);
            final local = mergedMap[qId];
            if (local == null) {
              mergedMap[qId] = remoteAnnot;
            } else {
              final remoteDate = remoteAnnot.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              final localDate = local.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              if (remoteDate.isAfter(localDate)) {
                mergedMap[qId] = remoteAnnot;
              }
            }
          } catch (_) {}
        }
      });
    }

    // Persist locally
    await annotService.importAnnotations(mergedMap);

    // Upload to Cloud
    final cloudPayload = <String, dynamic>{
      for (var entry in mergedMap.entries) entry.key: entry.value.toJson(),
    };
    await SupabaseService.upsertUserSyncData(
      userId: userId,
      dataType: 'qcm_annotations',
      payload: cloudPayload,
    );
  }

  // --- 4. STUDY PLANNER LAYERS SYNC ---
  Future<void> _syncStudyPlanner(String userId, dynamic remotePayload, {bool forceUpload = false}) async {
    final annotService = UserQcmAnnotationService.instance;
    await annotService.ensureInitialized();
    final localEntries = annotService.studyPlannerEntries;
    final mergedMap = Map<String, CourseStudyPlannerEntry>.from(localEntries);

    if (remotePayload is Map<String, dynamic>) {
      remotePayload.forEach((courseId, jsonVal) {
        if (jsonVal is Map<String, dynamic>) {
          try {
            final remoteEntry = CourseStudyPlannerEntry.fromJson(jsonVal);
            final local = mergedMap[courseId];
            if (local == null) {
              mergedMap[courseId] = remoteEntry;
            } else {
              final remoteDate = remoteEntry.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              final localDate = local.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              if (remoteDate.isAfter(localDate)) {
                mergedMap[courseId] = remoteEntry;
              }
            }
          } catch (_) {}
        }
      });
    }

    // Persist locally
    await annotService.importStudyPlannerEntries(mergedMap);

    // Upload to Cloud
    final cloudPayload = <String, dynamic>{
      for (var entry in mergedMap.entries) entry.key: entry.value.toJson(),
    };
    await SupabaseService.upsertUserSyncData(
      userId: userId,
      dataType: 'study_planner',
      payload: cloudPayload,
    );
  }

  // --- 5. FSRS FLASHCARDS SYNC ---
  Future<void> _syncFsrsFlashcards(String userId, dynamic remotePayload, {bool forceUpload = false}) async {
    final fsrs = FlashcardFsrsService.instance;
    await fsrs.ensureInitialized();
    final localCards = fsrs.cards;
    final cardMap = <String, FlashcardFsrsItem>{
      for (var c in localCards) c.id: c,
    };

    if (remotePayload is List) {
      for (var item in remotePayload) {
        if (item is Map<String, dynamic>) {
          try {
            final remoteCard = FlashcardFsrsItem.fromJson(item);
            final local = cardMap[remoteCard.id];
            if (local == null) {
              cardMap[remoteCard.id] = remoteCard;
            } else {
              final remoteDate = remoteCard.lastReviewedAt ?? remoteCard.createdAt;
              final localDate = local.lastReviewedAt ?? local.createdAt;
              if (remoteDate.isAfter(localDate)) {
                cardMap[remoteCard.id] = remoteCard;
              }
            }
          } catch (_) {}
        }
      }
    }

    final mergedList = cardMap.values.toList();
    await fsrs.importCards(mergedList);

    // Upload to Cloud
    await SupabaseService.upsertUserSyncData(
      userId: userId,
      dataType: 'fsrs_flashcards',
      payload: mergedList.map((c) => c.toJson()).toList(),
    );
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

