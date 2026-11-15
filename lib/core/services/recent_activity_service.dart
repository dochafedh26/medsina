import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import '../interfaces/feature_contracts.dart';

enum ActivityType {
  qcmCourse,
  qcmCustomSession,
  courseDocument,
  clinicalProtocol,
  prescriptionVidal,
  labAnalysis,
  emergencyDrug,
}

class RecentActivityItem {
  final String id;
  final ActivityType type;
  final String title;
  final String subtitle;
  final String badgeText;
  final Color badgeColor;
  final IconData icon;
  final Color iconColor;
  final DateTime timestamp;
  final double? progressPercent;
  final Map<String, dynamic> data;

  const RecentActivityItem({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.badgeColor,
    required this.icon,
    required this.iconColor,
    required this.timestamp,
    this.progressPercent,
    this.data = const {},
  });

  String get relativeTime {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inSeconds < 60) {
      return 'À l\'instant';
    } else if (diff.inMinutes < 60) {
      return 'Il y a ${diff.inMinutes} min';
    } else if (diff.inHours < 24) {
      return 'Il y a ${diff.inHours} h';
    } else if (diff.inDays == 1) {
      return 'Hier';
    } else {
      return 'Il y a ${diff.inDays} j';
    }
  }
}

class RecentActivityService {
  static final RecentActivityService instance = RecentActivityService._();
  RecentActivityService._();

  static const String _keyRecentCourse = 'medsina_recent_course';
  static const String _keyRecentProtocol = 'medsina_recent_protocol';
  static const String _keyRecentPrescription = 'medsina_recent_prescription';
  static const String _keyRecentLab = 'medsina_recent_lab';
  static const String _keyRecentDrug = 'medsina_recent_drug';

  // --- RECORD ACTIONS ---

  Future<void> recordCourseView({
    required dynamic course,
    String? moduleName,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = {
        'courseId': course.id,
        'courseName': course.name,
        'moduleId': course.moduleId,
        'moduleName': moduleName ?? 'Résidanat',
        'timestamp': DateTime.now().toIso8601String(),
      };
      await prefs.setString(_keyRecentCourse, jsonEncode(map));
    } catch (_) {}
  }

  Future<void> recordProtocolView({
    required String protocolId,
    required String title,
    String? specialty,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = {
        'protocolId': protocolId,
        'title': title,
        'specialty': specialty ?? 'Urgences',
        'timestamp': DateTime.now().toIso8601String(),
      };
      await prefs.setString(_keyRecentProtocol, jsonEncode(map));
    } catch (_) {}
  }

  Future<void> recordPrescriptionAnalysis({int drugCount = 0}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = {
        'drugCount': drugCount,
        'timestamp': DateTime.now().toIso8601String(),
      };
      await prefs.setString(_keyRecentPrescription, jsonEncode(map));
    } catch (_) {}
  }

  Future<void> recordLabAnalysis({String? presetName}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = {
        'presetName': presetName ?? 'Bilan standard',
        'timestamp': DateTime.now().toIso8601String(),
      };
      await prefs.setString(_keyRecentLab, jsonEncode(map));
    } catch (_) {}
  }

  Future<void> recordDrugView(String drugName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = {
        'drugName': drugName,
        'timestamp': DateTime.now().toIso8601String(),
      };
      await prefs.setString(_keyRecentDrug, jsonEncode(map));
    } catch (_) {}
  }

  // --- GET PRIORITIZED ACTIVITIES ---

  Future<List<RecentActivityItem>> getRecentActivities({
    SubscriptionTier tier = SubscriptionTier.allAccess,
  }) async {
    final list = <RecentActivityItem>[];
    final prefs = await SharedPreferences.getInstance();

    // 1 & 2. Check in-progress QCM courses & Custom Sessions via injected provider
    if (revisionActivitiesProvider != null) {
      try {
        final studyItems = await revisionActivitiesProvider!();
        list.addAll(studyItems);
      } catch (_) {}
    }

    // 3. Check recent course reading
    final courseStr = prefs.getString(_keyRecentCourse);
    if (courseStr != null && courseStr.isNotEmpty) {
      try {
        final map = jsonDecode(courseStr) as Map<String, dynamic>;
        final ts = DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now();
        final courseId = map['courseId'] ?? '';
        final courseName = map['courseName'] ?? 'Fiche de cours';
        final moduleName = map['moduleName'] ?? 'Résidanat';

        // Don't duplicate if this course already has an active QCM card shown
        if (!list.any((item) => item.data['courseId'] == courseId)) {
          list.add(RecentActivityItem(
            id: 'course_$courseId',
            type: ActivityType.courseDocument,
            title: 'Cours : $courseName',
            subtitle: 'Module $moduleName • Reprendre la fiche de cours',
            badgeText: 'Dernier cours consulté',
            badgeColor: const Color(0xFF2563EB),
            icon: Icons.picture_as_pdf_rounded,
            iconColor: const Color(0xFF2563EB),
            timestamp: ts,
            data: map,
          ));
        }
      } catch (_) {}
    }

    // 4. Check recent CAT Protocol
    final protoStr = prefs.getString(_keyRecentProtocol);
    if (protoStr != null && protoStr.isNotEmpty) {
      try {
        final map = jsonDecode(protoStr) as Map<String, dynamic>;
        final ts = DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now();
        final protoId = map['protocolId'] ?? '';
        final title = map['title'] ?? 'Protocole d\'urgence';
        final spec = map['specialty'] ?? 'Urgences';

        list.add(RecentActivityItem(
          id: 'proto_$protoId',
          type: ActivityType.clinicalProtocol,
          title: 'CAT Urgence : $title',
          subtitle: 'Spécialité : $spec • Consulter l\'arbre décisionnel',
          badgeText: 'Dernière CAT consultée',
          badgeColor: const Color(0xFFEF4444),
          icon: Icons.emergency_rounded,
          iconColor: const Color(0xFFEF4444),
          timestamp: ts,
          data: map,
        ));
      } catch (_) {}
    }

    // 5. Check recent Prescription Vidal analysis
    final prescStr = prefs.getString(_keyRecentPrescription);
    if (prescStr != null && prescStr.isNotEmpty) {
      try {
        final map = jsonDecode(prescStr) as Map<String, dynamic>;
        final ts = DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now();
        final count = (map['drugCount'] as num?)?.toInt() ?? 0;

        list.add(RecentActivityItem(
          id: 'presc_recent',
          type: ActivityType.prescriptionVidal,
          title: 'Analyse d\'Ordonnance (Vidal Algérie)',
          subtitle: count > 0
              ? 'Dernière ordonnance analysée ($count spécialités) • Reprendre l\'audit'
              : 'Interactions & contre-indications terrain • Reprendre',
          badgeText: 'Dernière analyse Vidal',
          badgeColor: const Color(0xFFD97706),
          icon: Icons.fact_check_rounded,
          iconColor: const Color(0xFFD97706),
          timestamp: ts,
          data: map,
        ));
      } catch (_) {}
    }

    // 6. Check recent Lab Analysis
    final labStr = prefs.getString(_keyRecentLab);
    if (labStr != null && labStr.isNotEmpty) {
      try {
        final map = jsonDecode(labStr) as Map<String, dynamic>;
        final ts = DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now();
        final preset = map['presetName'] ?? 'Bilan standard';

        list.add(RecentActivityItem(
          id: 'lab_recent',
          type: ActivityType.labAnalysis,
          title: 'Analyse Bilan Biologique ($preset)',
          subtitle: 'Calculs métaboliques & audit syndromique • Reprendre',
          badgeText: 'Dernier bilan biologique',
          badgeColor: const Color(0xFF0D9488),
          icon: Icons.biotech_rounded,
          iconColor: const Color(0xFF0D9488),
          timestamp: ts,
          data: map,
        ));
      } catch (_) {}
    }

    // Sort all accumulated activities by timestamp descending
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // 7. Contextual Fallbacks if fewer than 2 activities
    if (list.length < 2) {
      if (tier == SubscriptionTier.clinicalPro) {
        if (!list.any((i) => i.type == ActivityType.prescriptionVidal)) {
          list.add(RecentActivityItem(
            id: 'default_presc',
            type: ActivityType.prescriptionVidal,
            title: 'Analyse d\'Ordonnance (Moteur Vidal)',
            subtitle: '5 425+ Spécialités MSPRH • Interactions, terrain & audit IA',
            badgeText: 'Outil Vidal Pro',
            badgeColor: const Color(0xFFD97706),
            icon: Icons.fact_check_rounded,
            iconColor: const Color(0xFFD97706),
            timestamp: DateTime.now(),
          ));
        }
        if (!list.any((i) => i.type == ActivityType.clinicalProtocol)) {
          list.add(RecentActivityItem(
            id: 'default_proto_sca',
            type: ActivityType.clinicalProtocol,
            title: 'CAT Urgence : Prise en charge SCA ST+ (IDM)',
            subtitle: 'Arbre décisionnel reperfusion < 120 min • Posologies urgentes',
            badgeText: 'Urgence Vitale',
            badgeColor: const Color(0xFFEF4444),
            icon: Icons.emergency_rounded,
            iconColor: const Color(0xFFEF4444),
            timestamp: DateTime.now(),
            data: {'protocolId': 'cat_sca_st_plus'},
          ));
        }
      } else if (tier == SubscriptionTier.residentElite) {
        if (!list.any((i) => i.type == ActivityType.qcmCourse)) {
          list.add(RecentActivityItem(
            id: 'default_qcm_hta',
            type: ActivityType.qcmCourse,
            title: 'Entraînement QCM : Cardiologie & HTA',
            subtitle: '340 questions classées • Annales nationales Résidanat',
            badgeText: 'Démarrage Concours 2027',
            badgeColor: const Color(0xFF0D9488),
            icon: Icons.quiz_rounded,
            iconColor: const Color(0xFF0D9488),
            timestamp: DateTime.now(),
            data: {'courseId': 'c_cardio_hta'},
          ));
        }
        if (!list.any((i) => i.type == ActivityType.courseDocument)) {
          list.add(RecentActivityItem(
            id: 'default_course_sca',
            type: ActivityType.courseDocument,
            title: 'Fiche de Cours : Syndromes Coronariens Aigus',
            subtitle: 'Module Cardiologie • Synthèse officielle & pièges',
            badgeText: 'Cours Haute Fréquence',
            badgeColor: const Color(0xFF2563EB),
            icon: Icons.picture_as_pdf_rounded,
            iconColor: const Color(0xFF2563EB),
            timestamp: DateTime.now(),
            data: {'courseId': 'c_cardio_sca', 'moduleName': 'Cardiologie'},
          ));
        }
      } else {
        // All-Access / Discovery
        if (!list.any((i) => i.type == ActivityType.qcmCourse)) {
          list.add(RecentActivityItem(
            id: 'default_qcm_hta',
            type: ActivityType.qcmCourse,
            title: 'Entraînement QCM : Cardiologie & HTA',
            subtitle: '340 questions classées • Annales nationales Résidanat',
            badgeText: 'Session recommandée',
            badgeColor: const Color(0xFF0D9488),
            icon: Icons.quiz_rounded,
            iconColor: const Color(0xFF0D9488),
            timestamp: DateTime.now(),
            data: {'courseId': 'c_cardio_hta'},
          ));
        }
        if (!list.any((i) => i.type == ActivityType.clinicalProtocol)) {
          list.add(RecentActivityItem(
            id: 'default_proto_sca',
            type: ActivityType.clinicalProtocol,
            title: 'CAT Urgence : Prise en charge SCA ST+ (IDM)',
            subtitle: 'Arbre de décision reperfusion < 120 min • Posologies antithrombotiques',
            badgeText: 'Protocole d\'urgence',
            badgeColor: const Color(0xFFEF4444),
            icon: Icons.emergency_rounded,
            iconColor: const Color(0xFFEF4444),
            timestamp: DateTime.now(),
            data: {'protocolId': 'cat_sca_st_plus'},
          ));
        }
      }
    }

    return list.take(3).toList();
  }

  /// Optional provider injected by `medsina_study_engine` for QCM/custom session activities.
  static Future<List<RecentActivityItem>> Function()? revisionActivitiesProvider;

  // --- LAUNCH ACTION SPECIFICALLY ---

  Future<void> launchActivity(BuildContext context, RecentActivityItem item) async {
    await MedsinaFeatureRegistry.instance.dispatchRoute(
      context,
      'activity:${item.type.name}',
      item.data,
    );
  }
}
