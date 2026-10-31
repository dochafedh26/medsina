import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/supabase_service.dart';
import '../models/medical_comment.dart';

class MedicalCommentService {
  static final MedicalCommentService instance = MedicalCommentService._internal();
  MedicalCommentService._internal();

  final Map<String, List<MedicalComment>> _cache = {};
  final Map<String, ValueNotifier<List<MedicalComment>>> _notifiers = {};

  String? _cachedUserId;
  String? _cachedUserName;

  Future<String> _getUserId() async {
    if (_cachedUserId != null && _cachedUserId!.isNotEmpty) {
      return _cachedUserId!;
    }
    final supabaseUser = SupabaseService.currentSession?.user;
    if (supabaseUser != null && supabaseUser.id.isNotEmpty) {
      _cachedUserId = supabaseUser.id;
      return _cachedUserId!;
    }

    final prefs = await SharedPreferences.getInstance();
    String? localId = prefs.getString('medsina_anonymous_user_id');
    if (localId == null || localId.isEmpty) {
      localId = 'user_${DateTime.now().millisecondsSinceEpoch}_${(1000 + DateTime.now().microsecond % 9000)}';
      await prefs.setString('medsina_anonymous_user_id', localId);
    }
    _cachedUserId = localId;
    return _cachedUserId!;
  }

  Future<String> _getUserName() async {
    if (_cachedUserName != null && _cachedUserName!.isNotEmpty) {
      return _cachedUserName!;
    }
    final supabaseUser = SupabaseService.currentSession?.user;
    final metadataName = supabaseUser?.userMetadata?['name']?.toString() ??
        supabaseUser?.userMetadata?['full_name']?.toString();
    if (metadataName != null && metadataName.trim().isNotEmpty) {
      _cachedUserName = metadataName.trim();
      return _cachedUserName!;
    }

    final prefs = await SharedPreferences.getInstance();
    final localName = prefs.getString('medsina_user_display_name');
    if (localName != null && localName.trim().isNotEmpty) {
      _cachedUserName = localName.trim();
      return _cachedUserName!;
    }

    return 'Étudiant Medsina';
  }

  void setUserInfo({String? userId, String? userName}) {
    if (userId != null && userId.isNotEmpty) _cachedUserId = userId;
    if (userName != null && userName.isNotEmpty) _cachedUserName = userName;
  }

  ValueNotifier<List<MedicalComment>> getCommentsNotifier(String targetId) {
    if (!_notifiers.containsKey(targetId)) {
      _notifiers[targetId] = ValueNotifier<List<MedicalComment>>(_cache[targetId] ?? []);
    }
    return _notifiers[targetId]!;
  }

  String _cloudKey(String targetType, String targetId) =>
      'comments_${targetType}_$targetId';

  String _privateLocalKey(String targetId) =>
      'private_comments_$targetId';

  /// Fetches comments for a specific course or QCM.
  /// Combines community public comments with current user's private comments.
  Future<List<MedicalComment>> fetchComments(
    String targetType,
    String targetId, {
    bool forceRefresh = false,
  }) async {
    final currentUserId = await _getUserId();
    final prefs = await SharedPreferences.getInstance();

    // 1. Load private comments from local storage (always private to this device/user)
    List<MedicalComment> privateComments = [];
    final privateRaw = prefs.getString(_privateLocalKey(targetId));
    if (privateRaw != null && privateRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(privateRaw);
        if (decoded is List) {
          privateComments = decoded
              .map((x) => MedicalComment.fromJson(Map<String, dynamic>.from(x)))
              .where((c) => c.userId == currentUserId || c.isPrivate)
              .toList();
        }
      } catch (e) {
        debugPrint('Error decoding local private comments: $e');
      }
    }

    // 2. Load public comments from Supabase Cloud (admin_system_settings)
    List<MedicalComment> publicComments = [];
    try {
      final cloudJson = await SupabaseService.getAdminSetting(_cloudKey(targetType, targetId));
      if (cloudJson != null && cloudJson.trim().isNotEmpty) {
        final decoded = jsonDecode(cloudJson);
        if (decoded is List) {
          publicComments = decoded
              .map((x) => MedicalComment.fromJson(Map<String, dynamic>.from(x)))
              .where((c) => !c.isPrivate)
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Error fetching public comments from Supabase: $e');
    }

    // 3. Merge and sort newest first
    final all = [...privateComments, ...publicComments];
    all.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    _cache[targetId] = all;
    getCommentsNotifier(targetId).value = List.unmodifiable(all);

    return all;
  }

  /// Adds a new comment (private or public).
  Future<MedicalComment> addComment({
    required String targetType,
    required String targetId,
    required String targetTitle,
    required String content,
    required bool isPrivate,
    String? customUserName,
  }) async {
    final userId = await _getUserId();
    final userName = customUserName ?? await _getUserName();
    final prefs = await SharedPreferences.getInstance();

    final newComment = MedicalComment(
      id: 'comm_${DateTime.now().millisecondsSinceEpoch}_${(100 + DateTime.now().microsecond % 900)}',
      targetType: targetType,
      targetId: targetId,
      targetTitle: targetTitle,
      userId: userId,
      userName: userName,
      userRole: 'student',
      content: content.trim(),
      isPrivate: isPrivate,
      createdAt: DateTime.now(),
    );

    if (isPrivate) {
      // Save locally only
      final privateList = <MedicalComment>[];
      final privateRaw = prefs.getString(_privateLocalKey(targetId));
      if (privateRaw != null && privateRaw.isNotEmpty) {
        try {
          final decoded = jsonDecode(privateRaw);
          if (decoded is List) {
            privateList.addAll(
              decoded.map((x) => MedicalComment.fromJson(Map<String, dynamic>.from(x))),
            );
          }
        } catch (_) {}
      }
      privateList.insert(0, newComment);
      await prefs.setString(
        _privateLocalKey(targetId),
        jsonEncode(privateList.map((c) => c.toJson()).toList()),
      );
    } else {
      // Save to public cloud
      try {
        final existingCloudJson =
            await SupabaseService.getAdminSetting(_cloudKey(targetType, targetId));
        final cloudList = <MedicalComment>[];
        if (existingCloudJson != null && existingCloudJson.trim().isNotEmpty) {
          final decoded = jsonDecode(existingCloudJson);
          if (decoded is List) {
            cloudList.addAll(
              decoded.map((x) => MedicalComment.fromJson(Map<String, dynamic>.from(x))),
            );
          }
        }
        cloudList.insert(0, newComment);
        await SupabaseService.saveAdminSetting(
          _cloudKey(targetType, targetId),
          jsonEncode(cloudList.map((c) => c.toJson()).toList()),
          description: 'Commentaires publics pour $targetType : $targetTitle',
        );
      } catch (e) {
        debugPrint('Error saving public comment to Supabase: $e');
      }
    }

    // Refresh cache and notify listeners
    final currentList = _cache[targetId] ?? [];
    final updatedList = [newComment, ...currentList];
    updatedList.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _cache[targetId] = updatedList;
    getCommentsNotifier(targetId).value = List.unmodifiable(updatedList);

    return newComment;
  }

  /// Deletes a comment.
  Future<bool> deleteComment({
    required String commentId,
    required String targetType,
    required String targetId,
    required bool isPrivate,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (isPrivate) {
      final privateRaw = prefs.getString(_privateLocalKey(targetId));
      if (privateRaw != null && privateRaw.isNotEmpty) {
        try {
          final decoded = jsonDecode(privateRaw);
          if (decoded is List) {
            final updated = decoded
                .map((x) => MedicalComment.fromJson(Map<String, dynamic>.from(x)))
                .where((c) => c.id != commentId)
                .toList();
            await prefs.setString(
              _privateLocalKey(targetId),
              jsonEncode(updated.map((c) => c.toJson()).toList()),
            );
          }
        } catch (_) {}
      }
    } else {
      try {
        final cloudJson = await SupabaseService.getAdminSetting(_cloudKey(targetType, targetId));
        if (cloudJson != null && cloudJson.trim().isNotEmpty) {
          final decoded = jsonDecode(cloudJson);
          if (decoded is List) {
            final updated = decoded
                .map((x) => MedicalComment.fromJson(Map<String, dynamic>.from(x)))
                .where((c) => c.id != commentId)
                .toList();
            await SupabaseService.saveAdminSetting(
              _cloudKey(targetType, targetId),
              jsonEncode(updated.map((c) => c.toJson()).toList()),
            );
          }
        }
      } catch (e) {
        debugPrint('Error deleting public comment from Supabase: $e');
      }
    }

    // Update in-memory cache
    if (_cache.containsKey(targetId)) {
      _cache[targetId] = _cache[targetId]!.where((c) => c.id != commentId).toList();
      getCommentsNotifier(targetId).value = List.unmodifiable(_cache[targetId]!);
    }

    return true;
  }
}
