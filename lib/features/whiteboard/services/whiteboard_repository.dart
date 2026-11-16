import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/supabase_service.dart';
import '../models/whiteboard_model.dart';

class WhiteboardRepository {
  static const String _localKeyPrefix = 'medsina_user_whiteboards_';
  static const String _tableName = 'user_whiteboards';

  static String _storageKeyForUser(String? userId) {
    final suffix = (userId != null && userId.isNotEmpty) ? userId : 'guest';
    return '$_localKeyPrefix$suffix';
  }

  static String? _safeCurrentUserId() {
    try {
      return SupabaseService.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  static bool _safeIsAuthenticated() {
    try {
      return SupabaseService.isAuthenticated &&
          SupabaseService.currentUser != null;
    } catch (_) {
      return false;
    }
  }

  /// Loads boards from local cache and merges with Supabase cloud when online.
  static Future<List<WhiteboardModel>> fetchBoards({
    String? courseId,
    bool syncCloud = true,
  }) async {
    final userId = _safeCurrentUserId();
    final localBoards = await _loadLocalBoards(userId);
    final Map<String, WhiteboardModel> merged = {
      for (final b in localBoards) b.id: b,
    };

    if (syncCloud && _safeIsAuthenticated() && userId != null) {
      try {
        final rows = await SupabaseService.client
            .from(_tableName)
            .select()
            .eq('user_id', userId)
            .order('updated_at', ascending: false);

        for (final row in (rows as List)) {
          if (row is Map) {
            final cloudBoard = WhiteboardModel.fromJson(
              Map<String, dynamic>.from(row),
            ).copyWith(isSynced: true);
            final existing = merged[cloudBoard.id];
            if (existing == null ||
                cloudBoard.updatedAt.isAfter(existing.updatedAt)) {
              merged[cloudBoard.id] = cloudBoard;
            }
          }
        }
        await _saveLocalBoards(userId, merged.values.toList());
      } catch (_) {
        // Offline or table not migrated yet: keep local boards seamlessly
      }
    }

    var result = merged.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    if (courseId != null && courseId.isNotEmpty) {
      result = result.where((b) => b.courseId == courseId).toList();
    }
    return result;
  }

  /// Saves a board locally immediately, then syncs to Supabase if authenticated.
  static Future<WhiteboardModel> saveBoard(WhiteboardModel board) async {
    final userId = _safeCurrentUserId();
    final updated = board.copyWith(
      updatedAt: DateTime.now(),
      isSynced: false,
    );

    final local = await _loadLocalBoards(userId);
    final idx = local.indexWhere((b) => b.id == updated.id);
    if (idx >= 0) {
      local[idx] = updated;
    } else {
      local.insert(0, updated);
    }
    await _saveLocalBoards(userId, local);

    if (_safeIsAuthenticated() && userId != null) {
      try {
        await SupabaseService.client.from(_tableName).upsert({
          'id': updated.id,
          'user_id': userId,
          'course_id': updated.courseId,
          'module_name': updated.moduleName,
          'title': updated.title,
          'board_data': updated.data.toJson(),
          'created_at': updated.createdAt.toIso8601String(),
          'updated_at': updated.updatedAt.toIso8601String(),
        });
        final synced = updated.copyWith(isSynced: true);
        final syncedIdx = local.indexWhere((b) => b.id == synced.id);
        if (syncedIdx >= 0) {
          local[syncedIdx] = synced;
          await _saveLocalBoards(userId, local);
        }
        return synced;
      } catch (_) {
        // Keep local unsynced copy; will sync on next save/fetch
      }
    }

    return updated;
  }

  /// Deletes a board from both local cache and Supabase cloud.
  static Future<void> deleteBoard(String boardId) async {
    final userId = _safeCurrentUserId();
    final local = await _loadLocalBoards(userId);
    local.removeWhere((b) => b.id == boardId);
    await _saveLocalBoards(userId, local);

    if (_safeIsAuthenticated() && userId != null) {
      try {
        await SupabaseService.client
            .from(_tableName)
            .delete()
            .eq('id', boardId)
            .eq('user_id', userId);
      } catch (_) {}
    }
  }

  static Future<List<WhiteboardModel>> _loadLocalBoards(String? userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKeyForUser(userId));
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => WhiteboardModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<void> _saveLocalBoards(
    String? userId,
    List<WhiteboardModel> boards,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(boards.map((b) => b.toJson()).toList());
    await prefs.setString(_storageKeyForUser(userId), encoded);
  }
}
