import 'package:flutter/material.dart';

enum NotificationType {
  cat,
  course,
  qcm,
  pearl,
  drug,
  memento,
  quota,
  subscription,
  announcement,
}

extension NotificationTypeExtension on NotificationType {
  String get label {
    switch (this) {
      case NotificationType.cat:
        return 'Conduite à Tenir (CAT)';
      case NotificationType.course:
        return 'Nouveau Cours & Résumé';
      case NotificationType.qcm:
        return 'Nouveau QCM';
      case NotificationType.pearl:
        return 'Perle du Jour';
      case NotificationType.drug:
        return 'Médicament & Urgence';
      case NotificationType.memento:
        return 'Mémento Clinique';
      case NotificationType.quota:
        return 'Alerte Quota IA';
      case NotificationType.subscription:
        return 'Abonnement Medsina';
      case NotificationType.announcement:
        return 'Annonce Système';
    }
  }

  IconData get icon {
    switch (this) {
      case NotificationType.cat:
        return Icons.emergency_rounded;
      case NotificationType.course:
        return Icons.menu_book_rounded;
      case NotificationType.qcm:
        return Icons.quiz_rounded;
      case NotificationType.pearl:
        return Icons.tips_and_updates_rounded;
      case NotificationType.drug:
        return Icons.medication_rounded;
      case NotificationType.memento:
        return Icons.nightlight_round;
      case NotificationType.quota:
        return Icons.bolt_rounded;
      case NotificationType.subscription:
        return Icons.workspace_premium_rounded;
      case NotificationType.announcement:
        return Icons.campaign_rounded;
    }
  }

  Color get color {
    switch (this) {
      case NotificationType.cat:
        return const Color(0xFFEF4444);
      case NotificationType.course:
        return const Color(0xFF0284C7);
      case NotificationType.qcm:
        return const Color(0xFF8B5CF6);
      case NotificationType.pearl:
        return const Color(0xFFF59E0B);
      case NotificationType.drug:
        return const Color(0xFF10B981);
      case NotificationType.memento:
        return const Color(0xFFEC4899);
      case NotificationType.quota:
        return const Color(0xFFF97316);
      case NotificationType.subscription:
        return const Color(0xFF6366F1);
      case NotificationType.announcement:
        return const Color(0xFF14B8A6);
    }
  }
}

class MedicalNotification {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final DateTime createdAt;
  final bool isRead;
  final String? targetId; // Course ID, Protocol ID, or Pearl ID
  final Map<String, dynamic>? metadata;

  const MedicalNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    this.isRead = false,
    this.targetId,
    this.metadata,
  });

  MedicalNotification copyWith({
    String? id,
    String? title,
    String? message,
    NotificationType? type,
    DateTime? createdAt,
    bool? isRead,
    String? targetId,
    Map<String, dynamic>? metadata,
  }) {
    return MedicalNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      targetId: targetId ?? this.targetId,
      metadata: metadata ?? this.metadata,
    );
  }

  bool get isAlert =>
      type == NotificationType.announcement ||
      type == NotificationType.quota ||
      type == NotificationType.subscription ||
      title.toLowerCase().contains('quota') ||
      title.toLowerCase().contains('abonnement') ||
      title.toLowerCase().contains('expiration') ||
      title.toLowerCase().contains('ban') ||
      title.toLowerCase().contains('maintenance') ||
      title.toLowerCase().contains('alerte');

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'message': message,
        'type': type.name,
        'created_at': createdAt.toIso8601String(),
        'is_read': isRead,
        'target_id': targetId,
        'metadata': metadata,
      };

  factory MedicalNotification.fromJson(Map<String, dynamic> json) {
    NotificationType parsedType = NotificationType.announcement;
    final typeStr = (json['type'] ?? '').toString().toLowerCase();
    if (typeStr == 'cat' || typeStr.contains('protocol')) {
      parsedType = NotificationType.cat;
    } else if (typeStr == 'course' || typeStr.contains('cours') || typeStr.contains('summary') || typeStr.contains('resume')) {
      parsedType = NotificationType.course;
    } else if (typeStr == 'qcm') {
      parsedType = NotificationType.qcm;
    } else if (typeStr == 'pearl' || typeStr.contains('perle')) {
      parsedType = NotificationType.pearl;
    } else if (typeStr == 'drug' || typeStr.contains('medicament') || typeStr.contains('dci')) {
      parsedType = NotificationType.drug;
    } else if (typeStr == 'memento' || typeStr.contains('mnemo')) {
      parsedType = NotificationType.memento;
    } else if (typeStr == 'quota') {
      parsedType = NotificationType.quota;
    } else if (typeStr == 'subscription' || typeStr.contains('abonnement')) {
      parsedType = NotificationType.subscription;
    }

    return MedicalNotification(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? 'Notification Medsina',
      message: json['message'] ?? '',
      type: parsedType,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isRead: json['is_read'] == true,
      targetId: json['target_id']?.toString(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

