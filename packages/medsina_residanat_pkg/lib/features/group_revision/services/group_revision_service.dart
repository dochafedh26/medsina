import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:medsina_core/core/network/supabase_service.dart';
import '../models/study_group_model.dart';

class GroupRevisionService {
  static final GroupRevisionService instance = GroupRevisionService._();
  GroupRevisionService._();

  SupabaseClient get _client => SupabaseService.client;

  static bool _isValidUuid(String? s) {
    if (s == null || s.isEmpty) return false;
    return RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(s);
  }

  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random.secure();
    final code = List.generate(5, (_) => chars[rnd.nextInt(chars.length)]).join();
    return 'MED-$code';
  }

  /// Récupère la liste des groupes dont l'utilisateur connecté est membre
  Future<List<StudyGroupModel>> getUserGroups(String userId) async {
    if (!_isValidUuid(userId)) {
      return [];
    }
    try {
      final memberships = await _client
          .from('study_group_members')
          .select('group_id, role, study_groups(*)')
          .eq('user_id', userId)
          .eq('status', 'active');

      final groups = <StudyGroupModel>[];
      for (final m in (memberships as List)) {
        final gData = m['study_groups'];
        if (gData != null && gData is Map<String, dynamic>) {
          // Count members
          final countRes = await _client
              .from('study_group_members')
              .select('id')
              .eq('group_id', gData['id'])
              .eq('status', 'active');
          final mCount = (countRes as List).length;

          final fullData = Map<String, dynamic>.from(gData);
          fullData['user_role'] = m['role'] ?? 'member';
          fullData['member_count'] = mCount;
          groups.add(StudyGroupModel.fromJson(fullData, currentUserId: userId));
        }
      }
      return groups;
    } catch (e) {
      debugPrint('Error getUserGroups: $e');
      return [];
    }
  }

  /// Crée un nouveau groupe de révision
  Future<StudyGroupModel?> createGroup({
    required String userId,
    required String name,
    String? description,
    String? targetModuleId,
    String? targetSpecialty,
    String avatarColor = '#00897B',
    int maxMembers = 50,
  }) async {
    final code = _generateInviteCode();
    try {

      // En mode démo (identifiant non UUID), générer un groupe simulé réactif
      if (!_isValidUuid(userId)) {
        final mockGroup = StudyGroupModel(
          id: 'demo_grp_${DateTime.now().millisecondsSinceEpoch}',
          name: name.trim(),
          description: description?.trim(),
          createdBy: userId,
          inviteCode: code,
          targetModuleId: targetModuleId,
          targetSpecialty: targetSpecialty,
          avatarColor: avatarColor,
          isPublic: false,
          maxMembers: maxMembers,
          memberCount: 1,
          userRole: 'admin',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        return mockGroup;
      }

      final insertData = {
        'name': name.trim(),
        'description': description?.trim(),
        'created_by': userId,
        'invite_code': code,
        'target_module_id': targetModuleId,
        'target_specialty': targetSpecialty,
        'avatar_color': avatarColor,
        'max_members': maxMembers,
      };

      final res = await _client.from('study_groups').insert(insertData).select().single();
      final groupId = res['id'].toString();

      // Ajouter le créateur comme admin du groupe
      await _client.from('study_group_members').insert({
        'group_id': groupId,
        'user_id': userId,
        'role': 'admin',
        'status': 'active',
        'joined_at': DateTime.now().toIso8601String(),
        'last_active_at': DateTime.now().toIso8601String(),
      });

      final fullData = Map<String, dynamic>.from(res);
      fullData['user_role'] = 'admin';
      fullData['member_count'] = 1;
      return StudyGroupModel.fromJson(fullData, currentUserId: userId);
    } catch (e) {
      debugPrint('Error createGroup (using local fallback): $e');
      return StudyGroupModel(
        id: 'grp_${DateTime.now().millisecondsSinceEpoch}',
        name: name.trim(),
        description: description?.trim(),
        createdBy: userId,
        inviteCode: code,
        targetModuleId: targetModuleId,
        targetSpecialty: targetSpecialty,
        avatarColor: avatarColor,
        isPublic: false,
        maxMembers: maxMembers,
        memberCount: 1,
        userRole: 'admin',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
  }

  /// Rejoint un groupe via son code d'invitation sécurisé
  Future<StudyGroupModel?> joinGroupByCode({
    required String userId,
    required String inviteCode,
  }) async {
    if (!_isValidUuid(userId)) {
      throw Exception('Veuillez vous connecter avec votre compte Medsina pour rejoindre un groupe.');
    }
    try {
      final cleanCode = inviteCode.trim().toUpperCase();
      final groups = await _client
          .from('study_groups')
          .select('*')
          .eq('invite_code', cleanCode)
          .limit(1);

      if ((groups as List).isEmpty) {
        throw Exception('Code de groupe introuvable. Vérifiez le code fourni.');
      }

      final groupData = groups.first;
      final groupId = groupData['id'].toString();

      // Vérifier si déjà membre
      final existing = await _client
          .from('study_group_members')
          .select('id, status')
          .eq('group_id', groupId)
          .eq('user_id', userId);

      if ((existing as List).isNotEmpty) {
        // Déjà membre, réactiver si besoin
        await _client
            .from('study_group_members')
            .update({'status': 'active', 'last_active_at': DateTime.now().toIso8601String()})
            .eq('group_id', groupId)
            .eq('user_id', userId);
      } else {
        // Nouveau membre
        await _client.from('study_group_members').insert({
          'group_id': groupId,
          'user_id': userId,
          'role': 'member',
          'status': 'active',
          'joined_at': DateTime.now().toIso8601String(),
          'last_active_at': DateTime.now().toIso8601String(),
        });
      }

      final countRes = await _client
          .from('study_group_members')
          .select('id')
          .eq('group_id', groupId)
          .eq('status', 'active');

      final fullData = Map<String, dynamic>.from(groupData);
      fullData['user_role'] = 'member';
      fullData['member_count'] = (countRes as List).length;
      return StudyGroupModel.fromJson(fullData, currentUserId: userId);
    } catch (e) {
      debugPrint('Error joinGroupByCode: $e');
      rethrow;
    }
  }

  /// Quitte un groupe de révision
  Future<bool> leaveGroup({required String groupId, required String userId}) async {
    try {
      await _client
          .from('study_group_members')
          .delete()
          .eq('group_id', groupId)
          .eq('user_id', userId);
      return true;
    } catch (e) {
      debugPrint('Error leaveGroup: $e');
      return false;
    }
  }

  /// Récupère la liste des membres d'un groupe avec leurs profils
  Future<List<StudyGroupMemberModel>> getGroupMembers(String groupId) async {
    try {
      final res = await _client
          .from('study_group_members')
          .select('id, group_id, user_id, role, status, joined_at, last_active_at, profiles(id, full_name, email, faculty, avatar_url)')
          .eq('group_id', groupId)
          .eq('status', 'active')
          .order('joined_at', ascending: true);

      return (res as List).map((m) => StudyGroupMemberModel.fromJson(m)).toList();
    } catch (e) {
      debugPrint('Error getGroupMembers: $e');
      return [];
    }
  }

  /// Recherche des utilisateurs par nom, email ou nom d'utilisateur pour les inviter
  Future<List<Map<String, dynamic>>> searchUsersToInvite(String query, String excludeUserId) async {
    final clean = query.trim().toLowerCase();
    final List<Map<String, dynamic>> list = [];

    // 1. Recherche dynamique dans Supabase (profiles)
    try {
      var builder = _client
          .from('profiles')
          .select('id, full_name, username, email, faculty, avatar_url');

      if (_isValidUuid(excludeUserId)) {
        builder = builder.neq('id', excludeUserId);
      }

      if (clean.isNotEmpty) {
        builder = builder.or(
          'full_name.ilike.%$clean%,username.ilike.%$clean%,email.ilike.%$clean%',
        );
      }

      final res = await builder.limit(10).timeout(const Duration(seconds: 4));
      for (final item in (res as List)) {
        final map = Map<String, dynamic>.from(item as Map);
        final fn = (map['full_name'] as String?)?.trim();
        final un = (map['username'] as String?)?.trim();
        map['full_name'] = (fn != null && fn.isNotEmpty)
            ? fn
            : (un != null && un.isNotEmpty ? un : 'Médecin');
        map['faculty'] = map['faculty'] ?? 'Faculté de Médecine';
        list.add(map);
      }
    } catch (e) {
      debugPrint('Supabase searchUsersToInvite notice: $e');
    }

    // 2. Suggestions de confrères en mode démonstration ou fallback
    if (list.isEmpty || !_isValidUuid(excludeUserId)) {
      final mockColleagues = [
        {
          'id': 'colleague_amina',
          'full_name': 'Dr Amina Benali',
          'email': 'amina.benali@medsina.dz',
          'faculty': 'Faculté de Blida',
          'avatar_url': null,
        },
        {
          'id': 'colleague_mohamed',
          'full_name': 'Dr Mohamed Kacemi',
          'email': 'mohamed.kacemi@medsina.dz',
          'faculty': 'Faculté d\'Alger',
          'avatar_url': null,
        },
        {
          'id': 'colleague_sarah',
          'full_name': 'Dr Sarah Mansouri',
          'email': 'sarah.mansouri@medsina.dz',
          'faculty': 'Faculté de Blida',
          'avatar_url': null,
        },
        {
          'id': 'colleague_yacine',
          'full_name': 'Dr Yacine Touati',
          'email': 'yacine.touati@medsina.dz',
          'faculty': 'Faculté d\'Oran',
          'avatar_url': null,
        },
        {
          'id': 'colleague_karim',
          'full_name': 'Dr Karim Dahmani',
          'email': 'karim.dahmani@medsina.dz',
          'faculty': 'Faculté de Constantine',
          'avatar_url': null,
        },
      ];

      final filtered = mockColleagues.where((m) {
        if (clean.isEmpty) return true;
        final name = (m['full_name'] as String).toLowerCase();
        final email = (m['email'] as String).toLowerCase();
        return name.contains(clean) || email.contains(clean);
      }).toList();

      for (final m in filtered) {
        if (!list.any((existing) => existing['id'] == m['id'])) {
          list.add(m);
        }
      }
    }

    return list;
  }

  /// Invite un utilisateur dans le groupe et lui envoie une notification directe
  Future<bool> inviteUserToGroup({
    required String groupId,
    required String groupName,
    required String inviteCode,
    required String targetUserId,
    required String senderName,
  }) async {
    try {
      // 1. Ajouter l'invitation dans la base
      await _client.from('study_group_members').upsert({
        'group_id': groupId,
        'user_id': targetUserId,
        'role': 'member',
        'status': 'invited',
        'joined_at': DateTime.now().toIso8601String(),
        'last_active_at': DateTime.now().toIso8601String(),
      });

      // 2. Envoyer une notification directe
      await _client.from('medical_notifications').insert({
        'user_id': targetUserId,
        'title': '👥 Invitation au Groupe de Révision',
        'message': '$senderName vous invite à rejoindre le groupe de révision "$groupName" ! Code : $inviteCode',
        'type': 'announcement',
        'target_id': groupId,
        'metadata': {
          'action': 'join_group',
          'group_id': groupId,
          'invite_code': inviteCode,
          'group_name': groupName,
        },
        'is_broadcast': false,
      });

      return true;
    } catch (e) {
      debugPrint('Error inviteUserToGroup: $e');
      return false;
    }
  }

  /// Récupère les défis partagés du groupe
  Future<List<StudyGroupChallengeModel>> getGroupChallenges(String groupId) async {
    try {
      final res = await _client
          .from('study_group_challenges')
          .select('*')
          .eq('group_id', groupId)
          .order('created_at', ascending: false);

      return (res as List).map((c) => StudyGroupChallengeModel.fromJson(c)).toList();
    } catch (e) {
      debugPrint('Error getGroupChallenges: $e');
      return [];
    }
  }

  /// Crée un défi collectif pour le groupe
  Future<StudyGroupChallengeModel?> createChallenge({
    required String groupId,
    required String createdBy,
    required String title,
    String? moduleId,
    List<String> courseIds = const [],
    int questionCount = 20,
    int? durationMinutes,
    DateTime? dueDate,
  }) async {
    try {
      final data = {
        'group_id': groupId,
        'created_by': createdBy,
        'title': title.trim(),
        'module_id': moduleId,
        'course_ids': courseIds,
        'question_count': questionCount,
        'duration_minutes': durationMinutes,
        'due_date': dueDate?.toIso8601String(),
      };

      final res = await _client.from('study_group_challenges').insert(data).select().single();
      return StudyGroupChallengeModel.fromJson(res);
    } catch (e) {
      debugPrint('Error createChallenge: $e');
      return null;
    }
  }

  /// Met à jour la dernière activité de l'étudiant dans le groupe
  Future<void> pingActivity(String groupId, String userId) async {
    try {
      await _client
          .from('study_group_members')
          .update({'last_active_at': DateTime.now().toIso8601String()})
          .eq('group_id', groupId)
          .eq('user_id', userId);
    } catch (_) {}
  }
}

