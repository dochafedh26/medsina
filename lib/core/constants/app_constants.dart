import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'Medsina';
  static const String appSubtitle = 'Plateforme Médicale Globale';
  static const String appTagline = 'Pratique Clinique • Formation Résidanat • Applications Pratiques';
  static String appVersion = '1.0.9';
  static const String logoAsset = 'assets/medsina-logo.png';
  static const String logoDarkAsset = 'assets/medsina-logo-dark.png';
  static const String iconAsset = 'assets/medsina-icon.png';

  // Subscription Tiers
  static const String tierFree = 'free';
  static const String tierClinicalPro = 'clinical_pro';
  static const String tierResidentElite = 'resident_elite';
  static const String tierAllAccess = 'all_access';

  // API Configuration (Silent backend proxy)
  static const String defaultApiBaseUrl = 'https://api.medsina.com/v1';
}

enum SubscriptionTier {
  free,
  clinicalPro,
  residentElite,
  allAccess,
}

extension SubscriptionTierExtension on SubscriptionTier {
  String get id {
    switch (this) {
      case SubscriptionTier.free:
        return AppConstants.tierFree;
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

  bool hasUnlimitedExports() {
    return this == SubscriptionTier.residentElite || this == SubscriptionTier.allAccess;
  }
}
