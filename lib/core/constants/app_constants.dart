import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'Medsina';
  static const String appSubtitle = 'Plateforme Médicale Globale';
  static const String appTagline = 'Pratique Clinique • Formation Résidanat • Applications Pratiques';
  static String appVersion = '1.0.29';
  static const String logoAsset = 'assets/medsina-logo.png';
  static const String logoDarkAsset = 'assets/medsina-logo-dark.png';
  static const String iconAsset = 'assets/medsina-icon.png';

  // Subscription Tiers
  static const String tierFree = 'free';
  static const String tierEtudiant = 'etudiant';
  static const String tierClinicalPro = 'clinical_pro';
  static const String tierResidentElite = 'resident_elite';
  static const String tierAllAccess = 'all_access';

  // API Configuration (Silent backend proxy)
  static const String defaultApiBaseUrl = 'https://api.medsina.com/v1';

  // App Download Links
  static const String androidDownloadUrl = 'https://medsina.medevsync.com/download/medsina.apk';
  static const String windowsDownloadUrl = 'https://medsina.medevsync.com/download/medsina-setup.exe';
  static const String webAppUrl = 'https://medsina.medevsync.com';
  static const String releasesUrl = 'https://github.com/dochafedh26/medsina/releases/latest';
}

enum SubscriptionTier {
  free,
  etudiant,
  clinicalPro,
  residentElite,
  allAccess,
}

extension SubscriptionTierExtension on SubscriptionTier {
  String get id {
    switch (this) {
      case SubscriptionTier.free:
        return AppConstants.tierFree;
      case SubscriptionTier.etudiant:
        return AppConstants.tierEtudiant;
      case SubscriptionTier.clinicalPro:
        return AppConstants.tierClinicalPro;
      case SubscriptionTier.residentElite:
        return AppConstants.tierResidentElite;
      case SubscriptionTier.allAccess:
        return AppConstants.tierAllAccess;
    }
  }

  String get label {
    switch (this) {
      case SubscriptionTier.free:
        return 'Pass Découverte';
      case SubscriptionTier.etudiant:
        return 'Pass Étudiant';
      case SubscriptionTier.clinicalPro:
        return 'Pass Clinique Pro';
      case SubscriptionTier.residentElite:
        return 'Pass Résident Élite';
      case SubscriptionTier.allAccess:
        return 'Medsina All-Access';
    }
  }

  String get badgeText {
    switch (this) {
      case SubscriptionTier.free:
        return 'GRATUIT';
      case SubscriptionTier.etudiant:
        return 'ÉTUDIANT';
      case SubscriptionTier.clinicalPro:
        return 'CLINIQUE PRO';
      case SubscriptionTier.residentElite:
        return 'RÉSIDENT ÉLITE';
      case SubscriptionTier.allAccess:
        return 'ALL-ACCESS VIP';
    }
  }

  Color get color {
    switch (this) {
      case SubscriptionTier.free:
        return const Color(0xFF64748B);
      case SubscriptionTier.etudiant:
        return const Color(0xFF2563EB); // Royal Blue for students
      case SubscriptionTier.clinicalPro:
        return const Color(0xFF0284C7);
      case SubscriptionTier.residentElite:
        return const Color(0xFF0D9488);
      case SubscriptionTier.allAccess:
        return const Color(0xFF8B5CF6);
    }
  }

  bool canAccessClinical() {
    return this == SubscriptionTier.clinicalPro || this == SubscriptionTier.allAccess;
  }

  bool canAccessResident() {
    return this == SubscriptionTier.residentElite || this == SubscriptionTier.allAccess;
  }

  bool canAccessEtudiant() {
    return this == SubscriptionTier.etudiant || this == SubscriptionTier.residentElite || this == SubscriptionTier.allAccess;
  }

  bool hasUnlimitedExports() {
    return this == SubscriptionTier.residentElite || this == SubscriptionTier.allAccess;
  }
}
