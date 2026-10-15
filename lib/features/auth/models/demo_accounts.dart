import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import 'user_model.dart';

class DemoAccountProfile {
  final UserModel user;
  final String description;
  final String targetExperience;
  final Color color;
  final IconData icon;
  final String samplePassword;

  const DemoAccountProfile({
    required this.user,
    required this.description,
    required this.targetExperience,
    required this.color,
    required this.icon,
    this.samplePassword = 'medsina2027',
  });
}

class DemoAccounts {
  /// 1. All-Access VIP (Dr. Hafedh)
  static final allAccess = DemoAccountProfile(
    user: UserModel(
      id: 'usr_demo_all_access',
      fullName: 'Dr. Hafedh (Blida 2027)',
      email: 'doc.hafedh26@medsina.com',
      medicalRole: 'Candidat Résidanat 2027',
      faculty: 'Faculté de Médecine de Blida',
      tier: SubscriptionTier.allAccess,
      subscriptionExpiry: DateTime(2027, 10, 31),
      token: 'token_demo_all_access',
      isAdmin: true,
    ),
    description: 'Accès total VIP illimité + Console Administrateur',
    targetExperience:
        'Tous les 47 modules Résidanat, 6 240+ QCMs, examens blancs, CAT cliniques, calculateurs, pharmacopée, exports Anki/PDF illimités et IA Gemini.',
    color: const Color(0xFF8B5CF6),
    icon: Icons.workspace_premium_rounded,
  );

  /// 2. Pass Résident Élite (Dr. Amine)
  static final residentElite = DemoAccountProfile(
    user: UserModel(
      id: 'usr_demo_resident_elite',
      fullName: 'Dr. Amine (Concours Résidanat)',
      email: 'resident.elite@medsina.com',
      medicalRole: 'Candidat Résidanat',
      faculty: 'Faculté de Médecine d\'Alger',
      tier: SubscriptionTier.residentElite,
      subscriptionExpiry: DateTime.now().add(const Duration(days: 365)),
      token: 'token_demo_resident_elite',
      isAdmin: false,
    ),
    description: 'Pass Spécial Concours Résidanat (47 modules + QCMs)',
    targetExperience:
        'Tous les 47 modules officiels, banque complète de QCMs classés, examens blancs chronométrés, téléchargement des cours PDF et exports Anki.',
    color: const Color(0xFF0D9488),
    icon: Icons.school_rounded,
  );

  /// 3. Pass Clinique Pro (Dr. Yasmine)
  static final clinicalPro = DemoAccountProfile(
    user: UserModel(
      id: 'usr_demo_clinical_pro',
      fullName: 'Dr. Yasmine (Praticienne UMC)',
      email: 'clinique.pro@medsina.com',
      medicalRole: 'Interne / Médecin Praticien',
      faculty: 'Faculté de Médecine de Constantine',
      tier: SubscriptionTier.clinicalPro,
      subscriptionExpiry: DateTime.now().add(const Duration(days: 365)),
      token: 'token_demo_clinical_pro',
      isAdmin: false,
    ),
    description: 'Pass Pratique Hospitalière & Urgences Médico-Chirurgicales',
    targetExperience:
        'Toutes les Conduites à Tenir (CAT) par spécialité, protocoles d\'urgence nationaux (MSPRH), scores cliniques interactifs, pharmacopée DCI Algérie et Copilote Clinique.',
    color: const Color(0xFF0284C7),
    icon: Icons.medical_services_rounded,
  );

  /// 4. Pass Découverte Gratuit (Dr. Sarah)
  static final freeTrial = DemoAccountProfile(
    user: UserModel(
      id: 'usr_demo_free_trial',
      fullName: 'Dr. Sarah (Compte Découverte)',
      email: 'decouverte.free@medsina.com',
      medicalRole: 'Externe en Médecine',
      faculty: 'Faculté de Médecine d\'Oran',
      tier: SubscriptionTier.free,
      subscriptionExpiry: DateTime.now().add(const Duration(days: 14)),
      token: 'token_demo_free_trial',
      isAdmin: false,
    ),
    description: 'Pass Découverte / Essai Gratuit (14 jours)',
    targetExperience:
        'Aperçu du premier module (Cardiologie), échantillon de 10 QCMs, calculateurs vitaux et découverte guidée avec invitation au paywall.',
    color: const Color(0xFF64748B),
    icon: Icons.explore_rounded,
  );

  /// 5. Compte Expiré (Dr. Karim)
  static final expired = DemoAccountProfile(
    user: UserModel(
      id: 'usr_demo_expired',
      fullName: 'Dr. Karim (Licence Expirée)',
      email: 'expire.demo@medsina.com',
      medicalRole: 'Médecin Généraliste',
      faculty: 'Faculté de Médecine de Blida',
      tier: SubscriptionTier.free,
      subscriptionExpiry: DateTime.now().subtract(const Duration(days: 5)),
      token: 'token_demo_expired',
      isAdmin: false,
    ),
    description: 'Compte avec Abonnement Expiré (Test de blocage)',
    targetExperience:
        'Expérience utilisateur avec alerte d\'expiration, accès verrouillé et incitation au renouvellement d\'abonnement via BaridiMob/Licence.',
    color: const Color(0xFFDC2626),
    icon: Icons.timer_off_rounded,
  );

  /// All demo profiles list
  static final List<DemoAccountProfile> all = [
    allAccess,
    residentElite,
    clinicalPro,
    freeTrial,
    expired,
  ];

  /// Find demo profile by exact email
  static DemoAccountProfile? findByEmail(String email) {
    final clean = email.trim().toLowerCase();
    for (final p in all) {
      if (p.user.email.toLowerCase() == clean) return p;
    }
    return null;
  }
}

