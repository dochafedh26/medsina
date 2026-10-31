class MedicalComment {
  final String id;
  final String targetType; // 'course' or 'qcm'
  final String targetId;
  final String targetTitle;
  final String userId;
  final String userName;
  final String userRole; // 'student', 'resident', 'admin'
  final String content;
  final bool isPrivate;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const MedicalComment({
    required this.id,
    required this.targetType,
    required this.targetId,
    this.targetTitle = '',
    required this.userId,
    this.userName = 'Étudiant Medsina',
    this.userRole = 'student',
    required this.content,
    this.isPrivate = false,
    required this.createdAt,
    this.updatedAt,
  });

  MedicalComment copyWith({
    String? id,
    String? targetType,
    String? targetId,
    String? targetTitle,
    String? userId,
    String? userName,
    String? userRole,
    String? content,
    bool? isPrivate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MedicalComment(
      id: id ?? this.id,
      targetType: targetType ?? this.targetType,
      targetId: targetId ?? this.targetId,
      targetTitle: targetTitle ?? this.targetTitle,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userRole: userRole ?? this.userRole,
      content: content ?? this.content,
      isPrivate: isPrivate ?? this.isPrivate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'target_type': targetType,
        'target_id': targetId,
        'target_title': targetTitle,
        'user_id': userId,
        'user_name': userName,
        'user_role': userRole,
        'content': content,
        'is_private': isPrivate,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  factory MedicalComment.fromJson(Map<String, dynamic> json) {
    return MedicalComment(
      id: json['id']?.toString() ?? '',
      targetType: json['target_type']?.toString() ?? 'course',
      targetId: json['target_id']?.toString() ?? '',
      targetTitle: json['target_title']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      userName: json['user_name']?.toString() ?? 'Étudiant Medsina',
      userRole: json['user_role']?.toString() ?? 'student',
      content: json['content']?.toString() ?? '',
      isPrivate: json['is_private'] == true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }
}

