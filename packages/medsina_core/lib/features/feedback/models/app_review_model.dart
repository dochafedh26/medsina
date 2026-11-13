import 'package:flutter/material.dart';

enum ReviewCategory {
  general(
    id: 'general',
    label: 'Expérience Globale',
    shortLabel: 'Général',
    icon: Icons.star_rounded,
    color: Color(0xFF0F766E),
  ),
  qcmResidanat(
    id: 'qcm_residanat',
    label: 'Banque QCM & Résidanat',
    shortLabel: 'QCMs & Résidanat',
    icon: Icons.school_rounded,
    color: Color(0xFF8B5CF6),
  ),
  cliniqueCat(
    id: 'clinique_cat',
    label: 'Urgences & Protocoles CAT',
    shortLabel: 'Urgences & CAT',
    icon: Icons.medical_services_rounded,
    color: Color(0xFFEF4444),
  ),
  vidalOrdonnance(
    id: 'vidal_ordonnance',
    label: 'Vidal & Analyse Ordonnance',
    shortLabel: 'Vidal & Ordo',
    icon: Icons.fact_check_rounded,
    color: Color(0xFF0D9488),
  ),
  iaOmnisearch(
    id: 'ia_omnisearch',
    label: 'Omnisearch & Copilote IA',
    shortLabel: 'IA & Omnisearch',
    icon: Icons.psychology_rounded,
    color: Color(0xFF0284C7),
  ),
  suggestion(
    id: 'suggestion',
    label: 'Idée & Suggestion',
    shortLabel: 'Suggestion',
    icon: Icons.lightbulb_rounded,
    color: Color(0xFFF59E0B),
  );

  final String id;
  final String label;
  final String shortLabel;
  final IconData icon;
  final Color color;

  const ReviewCategory({
    required this.id,
    required this.label,
    required this.shortLabel,
    required this.icon,
    required this.color,
  });

  static ReviewCategory fromId(String? id) {
    for (final c in ReviewCategory.values) {
      if (c.id == id) return c;
    }
    return ReviewCategory.general;
  }

  static const List<String> availableQuickTags = [
    'Explications QCM claires',
    'Indispensable en garde',
    'Recherche Ctrl+K ultra-rapide',
    'Mode hors-ligne fluide',
    'Vidal & Interactions top',
    'Fiches synthétiques',
    'Gain de temps énorme',
    'Interface moderne',
  ];
}

class AppReviewModel {
  final String id;
  final String? userId;
  final String userName;
  final String userRole;
  final String userFaculty;
  final String userTier;
  final int rating;
  final ReviewCategory category;
  final List<String> quickTags;
  final String? title;
  final String comment;
  final int helpfulCount;
  final bool isApproved;
  final bool isFeatured;
  final String? adminReply;
  final DateTime? adminRepliedAt;
  final String appVersion;
  final DateTime createdAt;

  const AppReviewModel({
    required this.id,
    this.userId,
    required this.userName,
    required this.userRole,
    required this.userFaculty,
    this.userTier = 'free',
    required this.rating,
    required this.category,
    this.quickTags = const [],
    this.title,
    required this.comment,
    this.helpfulCount = 0,
    this.isApproved = true,
    this.isFeatured = false,
    this.adminReply,
    this.adminRepliedAt,
    this.appVersion = '1.0.19',
    required this.createdAt,
  });

  factory AppReviewModel.fromJson(Map<String, dynamic> json) {
    final rawTags = json['quick_tags'];
    List<String> parsedTags = [];
    if (rawTags is List) {
      parsedTags = rawTags.map((e) => e.toString()).toList();
    }

    return AppReviewModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString(),
      userName: json['user_name']?.toString() ?? 'Médecin',
      userRole: json['user_role']?.toString() ?? 'Candidat Résidanat',
      userFaculty: json['user_faculty']?.toString() ?? 'Faculté de Médecine de Blida',
      userTier: json['user_tier']?.toString() ?? 'free',
      rating: ((json['rating'] as num?)?.toInt() ?? 5).clamp(1, 5),
      category: ReviewCategory.fromId(json['category']?.toString()),
      quickTags: parsedTags,
      title: json['title']?.toString(),
      comment: json['comment']?.toString() ?? '',
      helpfulCount: (json['helpful_count'] as num?)?.toInt() ?? 0,
      isApproved: json['is_approved'] != false,
      isFeatured: json['is_featured'] == true,
      adminReply: json['admin_reply']?.toString(),
      adminRepliedAt: json['admin_replied_at'] != null
          ? DateTime.tryParse(json['admin_replied_at'].toString())
          : null,
      appVersion: json['app_version']?.toString() ?? '1.0.19',
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'user_name': userName,
      'user_role': userRole,
      'user_faculty': userFaculty,
      'user_tier': userTier,
      'rating': rating,
      'category': category.id,
      'quick_tags': quickTags,
      'title': title,
      'comment': comment,
      'helpful_count': helpfulCount,
      'is_approved': isApproved,
      'is_featured': isFeatured,
      'admin_reply': adminReply,
      'admin_replied_at': adminRepliedAt?.toIso8601String(),
      'app_version': appVersion,
      'created_at': createdAt.toIso8601String(),
    };
  }

  AppReviewModel copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userRole,
    String? userFaculty,
    String? userTier,
    int? rating,
    ReviewCategory? category,
    List<String>? quickTags,
    String? title,
    String? comment,
    int? helpfulCount,
    bool? isApproved,
    bool? isFeatured,
    String? adminReply,
    DateTime? adminRepliedAt,
    String? appVersion,
    DateTime? createdAt,
  }) {
    return AppReviewModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userRole: userRole ?? this.userRole,
      userFaculty: userFaculty ?? this.userFaculty,
      userTier: userTier ?? this.userTier,
      rating: rating ?? this.rating,
      category: category ?? this.category,
      quickTags: quickTags ?? this.quickTags,
      title: title ?? this.title,
      comment: comment ?? this.comment,
      helpfulCount: helpfulCount ?? this.helpfulCount,
      isApproved: isApproved ?? this.isApproved,
      isFeatured: isFeatured ?? this.isFeatured,
      adminReply: adminReply ?? this.adminReply,
      adminRepliedAt: adminRepliedAt ?? this.adminRepliedAt,
      appVersion: appVersion ?? this.appVersion,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static List<AppReviewModel> get defaultSeedReviews => [
        AppReviewModel(
          id: 'a1111111-1111-4111-8111-111111111101',
          userName: 'Dr. Amine K.',
          userRole: 'Candidat Résidanat',
          userFaculty: 'Faculté de Médecine de Blida',
          userTier: 'resident_elite',
          rating: 5,
          category: ReviewCategory.qcmResidanat,
          quickTags: const [
            'Explications QCM claires',
            'Recherche Ctrl+K ultra-rapide',
            'Mode hors-ligne fluide',
          ],
          title: 'La meilleure plateforme pour préparer le concours de Blida !',
          comment:
              'Les 47 modules sont parfaitement structurés avec les cours officiels et une banque de QCMs ultra complète. Les corrigés détaillés font gagner un temps précieux pendant les révisions.',
          helpfulCount: 24,
          isApproved: true,
          isFeatured: true,
          adminReply:
              'Merci beaucoup Dr. Amine ! Toute l\'équipe Medsina vous souhaite une excellente réussite au concours du Résidanat 2027.',
          adminRepliedAt: DateTime.now().subtract(const Duration(days: 4)),
          appVersion: '1.0.18',
          createdAt: DateTime.now().subtract(const Duration(days: 5)),
        ),
        AppReviewModel(
          id: 'a1111111-1111-4111-8111-111111111102',
          userName: 'Dr. Yasmine B.',
          userRole: 'Médecin Interne',
          userFaculty: 'Faculté de Médecine d\'Alger',
          userTier: 'all_access',
          rating: 5,
          category: ReviewCategory.cliniqueCat,
          quickTags: const [
            'Indispensable en garde',
            'Vidal & Interactions top',
            'Gain de temps énorme',
          ],
          title: 'Mon compagnon indispensable pendant les gardes aux urgences',
          comment:
              'Les protocoles CAT d\'urgence, les posologies d\'urgence et le vérificateur d\'ordonnance Vidal Algérie m\'ont sauvé la mise plusieurs fois en garde de nuit. Le mode hors-ligne fonctionne sans aucune latence.',
          helpfulCount: 19,
          isApproved: true,
          isFeatured: true,
          appVersion: '1.0.18',
          createdAt: DateTime.now().subtract(const Duration(days: 3)),
        ),
        AppReviewModel(
          id: 'a1111111-1111-4111-8111-111111111103',
          userName: 'Rayan M.',
          userRole: 'Externe (6ème année)',
          userFaculty: 'Faculté de Médecine de Blida',
          userTier: 'etudiant',
          rating: 5,
          category: ReviewCategory.iaOmnisearch,
          quickTags: const [
            'Recherche Ctrl+K ultra-rapide',
            'Interface moderne',
            'Fiches synthétiques',
          ],
          title: 'Omnisearch et les résumés de cours sont incroyables',
          comment:
              'Avec Ctrl+K sur PC ou la barre Omnisearch sur Android, je retrouve n\'importe quelle valeur biologique, triade clinique ou cours PDF en une seconde.',
          helpfulCount: 14,
          isApproved: true,
          isFeatured: false,
          appVersion: '1.0.18',
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
        AppReviewModel(
          id: 'a1111111-1111-4111-8111-111111111104',
          userName: 'Dr. Mehdi S.',
          userRole: 'Médecin Généraliste',
          userFaculty: 'Faculté de Médecine d\'Oran',
          userTier: 'clinical_pro',
          rating: 5,
          category: ReviewCategory.vidalOrdonnance,
          quickTags: const [
            'Vidal & Interactions top',
            'Indispensable en garde',
          ],
          title: 'Analyseur d\'ordonnance et nomenclature MSPRH au top',
          comment:
              'Très pratique en consultation quotidienne pour vérifier rapidement les contre-indications liées au terrain (insuffisance rénale, grossesse) et les équivalents commerciaux algériens.',
          helpfulCount: 11,
          isApproved: true,
          isFeatured: false,
          appVersion: '1.0.18',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ];
}

class ReviewStatsSummary {
  final double averageRating;
  final int totalReviews;
  final Map<int, int> starCounts;

  const ReviewStatsSummary({
    required this.averageRating,
    required this.totalReviews,
    required this.starCounts,
  });

  factory ReviewStatsSummary.fromReviews(List<AppReviewModel> reviews) {
    final approved = reviews.where((r) => r.isApproved).toList();
    if (approved.isEmpty) {
      return const ReviewStatsSummary(
        averageRating: 5.0,
        totalReviews: 0,
        starCounts: {5: 0, 4: 0, 3: 0, 2: 0, 1: 0},
      );
    }

    final counts = <int, int>{5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    var sum = 0;
    for (final r in approved) {
      final star = r.rating.clamp(1, 5);
      counts[star] = (counts[star] ?? 0) + 1;
      sum += star;
    }

    return ReviewStatsSummary(
      averageRating: sum / approved.length,
      totalReviews: approved.length,
      starCounts: counts,
    );
  }

  double ratioForStar(int star) {
    if (totalReviews == 0) return 0.0;
    return (starCounts[star] ?? 0) / totalReviews;
  }
}
