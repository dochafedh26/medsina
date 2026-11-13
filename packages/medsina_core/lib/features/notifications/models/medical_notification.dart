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
  final String targetRole; // 'all', 'admin', 'user'

  const MedicalNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    this.isRead = false,
    this.targetId,
    this.metadata,
    this.targetRole = 'all',
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
    String? targetRole,
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
      targetRole: targetRole ?? this.targetRole,
    );
  }

  /// Determines if this notification should strictly be restricted to administrators
  /// Extracts image or flyer URL from metadata or message
  String? get imageUrl {
    if (metadata != null) {
      final img = metadata!['image_url'] ??
          metadata!['imageUrl'] ??
          metadata!['banner_url'] ??
          metadata!['flyer_url'] ??
          metadata!['image'];
      if (img != null && img.toString().trim().isNotEmpty) {
        return img.toString().trim();
      }
    }
    final match = RegExp(
      r'https?://[^\s]+\.(?:jpg|jpeg|png|webp|gif)',
      caseSensitive: false,
    ).firstMatch(message);
    if (match != null) {
      return match.group(0);
    }
    return null;
  }

  /// Extracts external or resource action URL
  String? get actionUrl {
    if (metadata != null) {
      final url = metadata!['action_url'] ??
          metadata!['actionUrl'] ??
          metadata!['link'] ??
          metadata!['url'] ??
          metadata!['source_url'] ??
          metadata!['drive_url'];
      if (url != null && url.toString().trim().isNotEmpty) {
        return url.toString().trim();
      }
    }
    final imgUrl = imageUrl;
    final matches = RegExp(r'https?://[^\s]+').allMatches(message);
    for (final m in matches) {
      final url = m.group(0);
      if (url != null && url != imgUrl) {
        return url;
      }
    }
    return null;
  }

  /// Action button label
  String get actionLabel {
    if (metadata != null) {
      final lbl = metadata!['action_label'] ??
          metadata!['button_label'] ??
          metadata!['cta_label'];
      if (lbl != null && lbl.toString().trim().isNotEmpty) {
        return lbl.toString().trim();
      }
    }
    final act = actionUrl;
    if (act != null) {
      if (act.contains('drive.google.com')) return 'Consulter le Drive 📁';
      if (act.contains('t.me')) return 'Ouvrir sur Telegram ✈️';
      if (act.contains('qcm')) return 'S\'entraîner aux QCMs 🎯';
      if (act.contains('cours') || act.contains('summary')) return 'Ouvrir le Cours 📖';
      return 'Accéder à la Source 🚀';
    }
    return 'En Savoir Plus';
  }

  /// Category badge label
  String get badge {
    if (metadata != null) {
      final b = metadata!['badge'] ?? metadata!['category'] ?? metadata!['tag'];
      if (b != null && b.toString().trim().isNotEmpty) {
        return b.toString().trim();
      }
    }
    final t = title.toLowerCase();
    if (t.contains('drive')) return 'Drive Officiel 📁';
    if (t.contains('qcm') || type == NotificationType.qcm) return 'Banque QCM 🎯';
    if (t.contains('cours') || type == NotificationType.course) return 'Nouveau Cours 📚';
    if (t.contains('cat') || type == NotificationType.cat) return 'Conduite CAT 🚨';
    if (t.contains('mémento') || t.contains('memento') || type == NotificationType.memento) return 'Mémento 🌙';
    if (t.contains('promo') || t.contains('tarif') || type == NotificationType.subscription) return 'Offre Spéciale 💎';
    if (type == NotificationType.announcement) return 'Annonce Officielle 📢';
    return type.label;
  }

  /// Cleaned readable message with raw image/action URLs stripped out cleanly
  String get cleanMessage {
    String txt = message;
    final img = imageUrl;
    if (img != null) {
      txt = txt.replaceAll(img, '');
    }
    final act = actionUrl;
    if (act != null) {
      txt = txt.replaceAll(act, '');
    }
    txt = txt.replaceAll(RegExp(r'Consultez l\x27affiche officielle\s*:?', caseSensitive: false), '');
    txt = txt.replaceAll(RegExp(r'Consultez le flyer\s*:?', caseSensitive: false), '');
    txt = txt.replaceAll(RegExp(r'Lien direct\s*:?', caseSensitive: false), '');
    txt = txt.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return txt.trim();
  }

  bool get isAnnouncement =>
      type == NotificationType.announcement ||
      imageUrl != null ||
      metadata?['is_announcement'] == true;

  bool get isAdminOnly {
    if (targetRole.toLowerCase() == 'admin') return true;
    if (metadata != null) {
      if (metadata!['is_admin_only'] == true) return true;
      if (metadata!['target_role']?.toString().toLowerCase() == 'admin') return true;
    }
    final t = title.toLowerCase();
    if (t.contains('post publié sur facebook') ||
        t.contains('nouveau membre inscrit') ||
        t.contains('nouvel inscrit') ||
        t.contains('nouveau paiement soumis') ||
        t.contains('prompt ia marketing')) {
      return true;
    }
    return false;
  }

  bool get isAlert =>
      type == NotificationType.announcement ||
      type == NotificationType.quota ||
      type == NotificationType.subscription ||
      isAdminOnly ||
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
        'target_role': targetRole,
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

    final role = json['target_role']?.toString() ??
        (json['metadata'] is Map ? (json['metadata']['target_role']?.toString() ?? 'all') : 'all');

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
      targetRole: role,
    );
  }
}

