import 'package:equatable/equatable.dart';

/// Représente un groupe de révision collective médicale.
class StudyGroupModel extends Equatable {
  final String id;
  final String name;
  final String? description;
  final String createdBy;
  final String inviteCode;
  final String? targetModuleId;
  final String? targetSpecialty;
  final String avatarColor;
  final bool isPublic;
  final int maxMembers;
  final int memberCount;
  final String? userRole; // 'admin', 'moderator', 'member'
  final DateTime createdAt;
  final DateTime updatedAt;

  const StudyGroupModel({
    required this.id,
    required this.name,
    this.description,
    required this.createdBy,
    required this.inviteCode,
    this.targetModuleId,
    this.targetSpecialty,
    this.avatarColor = '#00897B',
    this.isPublic = false,
    this.maxMembers = 50,
    this.memberCount = 1,
    this.userRole,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isUserAdmin => userRole == 'admin' || userRole == 'creator';

  factory StudyGroupModel.fromJson(Map<String, dynamic> json, {String? currentUserId}) {
    return StudyGroupModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Groupe de révision',
      description: json['description']?.toString(),
      createdBy: json['created_by']?.toString() ?? '',
      inviteCode: json['invite_code']?.toString() ?? '',
      targetModuleId: json['target_module_id']?.toString(),
      targetSpecialty: json['target_specialty']?.toString(),
      avatarColor: json['avatar_color']?.toString() ?? '#00897B',
      isPublic: json['is_public'] == true,
      maxMembers: (json['max_members'] as num?)?.toInt() ?? 50,
      memberCount: (json['member_count'] as num?)?.toInt() ?? 1,
      userRole: json['user_role']?.toString() ?? (currentUserId == json['created_by'] ? 'admin' : 'member'),
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'].toString()) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'].toString()) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'created_by': createdBy,
        'invite_code': inviteCode,
        'target_module_id': targetModuleId,
        'target_specialty': targetSpecialty,
        'avatar_color': avatarColor,
        'is_public': isPublic,
        'max_members': maxMembers,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        createdBy,
        inviteCode,
        targetModuleId,
        targetSpecialty,
        avatarColor,
        isPublic,
        maxMembers,
        memberCount,
        userRole,
        createdAt,
        updatedAt,
      ];
}

/// Représente un membre d'un groupe de révision.
class StudyGroupMemberModel extends Equatable {
  final String id;
  final String groupId;
  final String userId;
  final String fullName;
  final String? email;
  final String? faculty;
  final String? avatarUrl;
  final String role; // 'admin', 'moderator', 'member'
  final String status; // 'active', 'invited', 'pending'
  final DateTime joinedAt;
  final DateTime lastActiveAt;

  const StudyGroupMemberModel({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.fullName,
    this.email,
    this.faculty,
    this.avatarUrl,
    this.role = 'member',
    this.status = 'active',
    required this.joinedAt,
    required this.lastActiveAt,
  });

  bool get isOnline => DateTime.now().difference(lastActiveAt).inMinutes < 15;

  factory StudyGroupMemberModel.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>? ?? {};
    return StudyGroupMemberModel(
      id: json['id']?.toString() ?? '',
      groupId: json['group_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? profile['id']?.toString() ?? '',
      fullName: profile['full_name']?.toString() ?? json['full_name']?.toString() ?? 'Médecin Medsina',
      email: profile['email']?.toString() ?? json['email']?.toString(),
      faculty: profile['faculty']?.toString() ?? json['faculty']?.toString(),
      avatarUrl: profile['avatar_url']?.toString(),
      role: json['role']?.toString() ?? 'member',
      status: json['status']?.toString() ?? 'active',
      joinedAt: json['joined_at'] != null ? DateTime.parse(json['joined_at'].toString()) : DateTime.now(),
      lastActiveAt: json['last_active_at'] != null ? DateTime.parse(json['last_active_at'].toString()) : DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [id, groupId, userId, fullName, email, faculty, avatarUrl, role, status, joinedAt, lastActiveAt];
}

/// Représente un défi partagé au sein du groupe (série de QCMs collective).
class StudyGroupChallengeModel extends Equatable {
  final String id;
  final String groupId;
  final String createdBy;
  final String title;
  final String? moduleId;
  final List<String> courseIds;
  final int questionCount;
  final int? durationMinutes;
  final DateTime? dueDate;
  final DateTime createdAt;

  const StudyGroupChallengeModel({
    required this.id,
    required this.groupId,
    required this.createdBy,
    required this.title,
    this.moduleId,
    this.courseIds = const [],
    this.questionCount = 20,
    this.durationMinutes,
    this.dueDate,
    required this.createdAt,
  });

  factory StudyGroupChallengeModel.fromJson(Map<String, dynamic> json) {
    final rawCourses = json['course_ids'];
    final courses = rawCourses is List ? rawCourses.map((e) => e.toString()).toList() : <String>[];
    return StudyGroupChallengeModel(
      id: json['id']?.toString() ?? '',
      groupId: json['group_id']?.toString() ?? '',
      createdBy: json['created_by']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Défi de révision',
      moduleId: json['module_id']?.toString(),
      courseIds: courses,
      questionCount: (json['question_count'] as num?)?.toInt() ?? 20,
      durationMinutes: (json['duration_minutes'] as num?)?.toInt(),
      dueDate: json['due_date'] != null ? DateTime.parse(json['due_date'].toString()) : null,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'].toString()) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'group_id': groupId,
        'created_by': createdBy,
        'title': title,
        'module_id': moduleId,
        'course_ids': courseIds,
        'question_count': questionCount,
        'duration_minutes': durationMinutes,
        'due_date': dueDate?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };

  @override
  List<Object?> get props => [id, groupId, createdBy, title, moduleId, courseIds, questionCount, durationMinutes, dueDate, createdAt];
}

