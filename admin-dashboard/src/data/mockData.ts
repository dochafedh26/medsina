import { 
  AdminMetrics, 
  FinancialMetrics, 
  AdminUserItem, 
  PaymentItem, 
  PricingPlan, 
  AdminLicenseItem, 
  NationalExamModel, 
  AnnouncementItem, 
  AdminFacebookPrompt 
} from '../types/medsina';

export const INITIAL_ADMIN_METRICS: AdminMetrics = {
  totalUsers: 4826,
  freeTrials: 1420,
  etudiant: 1150,
  clinicalPro: 742,
  residentElite: 984,
  allAccess: 530,
  totalLicenses: 1250,
  redeemedLicenses: 986,
  availableLicenses: 264,
  octeniumTotalDownloads: 14890,
  octeniumApkDownloads: 9420,
  octeniumWindowsDownloads: 4110,
  octeniumWebVisits: 28450,
  octeniumLastDownloadAt: '2026-11-09T03:45:00Z',
};

export const INITIAL_PAYMENTS: PaymentItem[] = [
  {
    id: 'PAY-8841',
    userId: 'USR-101',
    userEmail: 'dr.amira.b@gmail.com',
    userName: 'Dr. Amira Boukhalfa',
    tier: 'resident_elite',
    durationDays: 365,
    amount: 24000,
    currency: 'DZD',
    paymentMethod: 'baridimob',
    receiptReference: 'BM-20261109-849102',
    receiptFileName: 'recu_baridimob_amira_residanat.pdf',
    status: 'pending',
    paymentType: 'subscription',
    bonusCredits: 50,
    adminNotes: 'Attestation de virement BaridiMob reçue. Vérification du compte CCP source.',
    isArchived: false,
    createdAt: '2026-11-09 03:15',
    updatedAt: '2026-11-09 03:20'
  },
  {
    id: 'PAY-8842',
    userId: 'USR-102',
    userEmail: 'karim.belkacem.med@univ-alger.dz',
    userName: 'Dr. Karim Belkacem',
    tier: 'all_access',
    durationDays: 365,
    amount: 32000,
    currency: 'DZD',
    paymentMethod: 'ccp',
    receiptReference: 'CCP-749103-91',
    receiptFileName: 'bon_versement_ccp_alger.jpg',
    status: 'pending',
    paymentType: 'subscription',
    bonusCredits: 100,
    adminNotes: 'Versement effectué au bureau de poste Alger-Centre Grande Poste.',
    isArchived: false,
    createdAt: '2026-11-09 02:40',
    updatedAt: '2026-11-09 02:45'
  },
  {
    id: 'PAY-8839',
    userId: 'USR-103',
    userEmail: 'sofiane.meziane@gmail.com',
    userName: 'Dr. Sofiane Meziane',
    tier: 'clinical_pro',
    durationDays: 365,
    amount: 18000,
    currency: 'DZD',
    paymentMethod: 'baridimob',
    receiptReference: 'BM-20261108-771920',
    receiptFileName: 'recu_baridimob_sofiane.png',
    status: 'approved',
    paymentType: 'subscription',
    bonusCredits: 0,
    adminNotes: 'Validé par Dr. Hafedh. Accès Clinical Pro prolongé de 365 jours.',
    isArchived: true,
    archiveDriveFolder: 'Medsina_Paiements_2026/Novembre',
    archiveDriveUrl: 'https://drive.google.com/drive/folders/medsina-receipts-2026',
    archivedAt: '2026-11-08 19:30',
    createdAt: '2026-11-08 18:20',
    updatedAt: '2026-11-08 19:30'
  },
  {
    id: 'PAY-8838',
    userId: 'USR-104',
    userEmail: 'ines.hadji@univ-blida.dz',
    userName: 'Inès Hadji',
    tier: 'etudiant',
    durationDays: 365,
    amount: 12000,
    currency: 'DZD',
    paymentMethod: 'baridimob',
    receiptReference: 'BM-20261108-662914',
    receiptFileName: 'recu_ines_externat_blida.jpg',
    status: 'approved',
    paymentType: 'subscription',
    bonusCredits: 0,
    adminNotes: 'Étudiante 5ème année Faculté de Médecine de Blida.',
    isArchived: true,
    createdAt: '2026-11-08 14:10',
    updatedAt: '2026-11-08 15:00'
  },
  {
    id: 'PAY-8835',
    userId: 'USR-105',
    userEmail: 'faycal.t@outlook.com',
    userName: 'Fayçal Touati',
    tier: 'resident_elite',
    durationDays: 365,
    amount: 24000,
    currency: 'DZD',
    paymentMethod: 'ccp',
    receiptReference: 'CCP-001928-12',
    receiptFileName: 'recu_illisible_scan.jpg',
    status: 'rejected',
    paymentType: 'subscription',
    bonusCredits: 0,
    adminNotes: 'Reçu flou et numéro de transaction tronqué. Email de relance envoyé au médecin.',
    isArchived: false,
    createdAt: '2026-11-07 11:20',
    updatedAt: '2026-11-07 14:15'
  }
];

export const INITIAL_USERS: AdminUserItem[] = [
  {
    id: 'USR-101',
    email: 'dr.amira.b@gmail.com',
    fullName: 'Dr. Amira Boukhalfa',
    medicalRole: 'Candidat Résidanat',
    faculty: 'Faculté de Médecine de Blida',
    tier: 'resident_elite',
    status: 'active',
    expiresAt: '2027-11-08',
    isAdmin: false,
    isBanned: false,
    rejectedPaymentsCount: 0,
    createdAt: '2025-10-15',
    studyYear: 7,
    referralCode: 'AMIRA-MED-09',
    avatarUrl: '/src/assets/images/doctor_avatar_female_1794207754613.jpg',
    phone: '+213 555 42 19 80',
    wilaya: 'Blida (09)',
    residencyTargetYear: '2027',
    bio: 'Médecin généraliste diplômée de Blida, préparation intensive au concours national de résidanat spécialité Pédiatrie.'
  },
  {
    id: 'USR-102',
    email: 'karim.belkacem.med@univ-alger.dz',
    fullName: 'Dr. Karim Belkacem',
    medicalRole: 'Résident en Spécialité',
    faculty: 'Faculté de Médecine d\'Alger (Ziania)',
    tier: 'all_access',
    status: 'active',
    expiresAt: '2027-10-20',
    isAdmin: false,
    isBanned: false,
    rejectedPaymentsCount: 0,
    createdAt: '2025-09-01',
    studyYear: 2,
    referralCode: 'KARIM-ALGER-16',
    avatarUrl: '/src/assets/images/doctor_avatar_male_1794207754386.jpg',
    phone: '+213 770 18 92 44',
    wilaya: 'Alger (16)',
    residencyTargetYear: '2025 (Admis)',
    bio: 'Résident en Cardiologie au CHU Mustapha Pacha, utilisateur assidu des outils d\'analyse clinique et ECG Medsina.'
  },
  {
    id: 'USR-103',
    email: 'sofiane.meziane@gmail.com',
    fullName: 'Dr. Sofiane Meziane',
    medicalRole: 'Médecin Généraliste',
    faculty: 'Faculté de Médecine de Tizi Ouzou',
    tier: 'clinical_pro',
    status: 'active',
    expiresAt: '2027-05-12',
    isAdmin: false,
    isBanned: false,
    rejectedPaymentsCount: 0,
    createdAt: '2025-11-10',
    phone: '+213 661 29 44 01',
    wilaya: 'Tizi Ouzou (15)',
    bio: 'Cabinet médical privé. Utilisation des calculateurs posologiques et modules d\'ordonnance Medsina.'
  },
  {
    id: 'USR-104',
    email: 'ines.hadji@univ-blida.dz',
    fullName: 'Inès Hadji',
    medicalRole: 'Étudiant en Médecine',
    faculty: 'Faculté de Médecine de Blida',
    tier: 'etudiant',
    status: 'active',
    expiresAt: '2027-09-30',
    isAdmin: false,
    isBanned: false,
    rejectedPaymentsCount: 0,
    createdAt: '2026-02-14',
    studyYear: 5,
    referralCode: 'INES-EXT-09',
    avatarUrl: '/src/assets/images/doctor_avatar_female_1794207754613.jpg',
    phone: '+213 540 88 12 30',
    wilaya: 'Blida (09)',
    residencyTargetYear: '2028',
    bio: 'Externe 5ème année. Révision des modules de Gastro-entérologie, Neurologie et Infectieux.'
  },
  {
    id: 'USR-105',
    email: 'faycal.t@outlook.com',
    fullName: 'Fayçal Touati',
    medicalRole: 'Candidat Résidanat',
    faculty: 'Faculté de Médecine de Constantine',
    tier: 'free',
    status: 'expired',
    expiresAt: '2026-11-01',
    isAdmin: false,
    isBanned: false,
    rejectedPaymentsCount: 1,
    createdAt: '2026-08-20',
    studyYear: 7,
    phone: '+213 552 10 39 48',
    wilaya: 'Constantine (25)',
    residencyTargetYear: '2027',
    bio: 'Essai gratuit terminé. Paiement en attente de régularisation.'
  },
  {
    id: 'USR-106',
    email: 'doc.hafedh26@gmail.com',
    fullName: 'Dr. Hafedh (CMO)',
    medicalRole: 'Spécialiste',
    faculty: 'Faculté de Médecine de Blida',
    tier: 'all_access',
    status: 'active',
    expiresAt: '2030-12-31',
    isAdmin: true,
    isBanned: false,
    rejectedPaymentsCount: 0,
    createdAt: '2024-01-01',
    phone: '+213 550 00 00 26',
    wilaya: 'Blida (09)',
    bio: 'Fondateur & Chef Médical MedSina. Administrateur principal de la plateforme.'
  }
];

export const INITIAL_PRICING_PLANS: PricingPlan[] = [
  {
    id: 'plan_etudiant',
    tier: 'etudiant',
    title: 'Formule Étudiant',
    subtitle: 'Externat & Révision Modules Médicaux',
    targetAudience: 'Pour externes 4ème, 5ème, 6ème année médecine',
    priceDZD: 12000,
    originalPriceDZD: 16000,
    durationDays: 365,
    durationLabel: '1 An d\'accès illimité (365 Jours)',
    isPopular: false,
    features: [
      'Accès complet aux QCMs et Cas Cliniques par module',
      'Fiches de synthèse anatomie, physiopathologie et sémiologie',
      'Mode entraînement hors-ligne via application Octenium',
      'Calculateur de scores et statistiques de révision',
      'Support d\'assistance pédagogique'
    ],
    paymentInstructions: {
      ccpAccount: '0021489012 Clé 45',
      ccpKey: '45',
      baridiMobRip: '00799999002148901245',
      baridiMobPhone: '+213 550 26 26 26'
    }
  },
  {
    id: 'plan_clinical_pro',
    tier: 'clinical_pro',
    title: 'Formule Clinical Pro',
    subtitle: 'Pratique Clinique & Cabinets Médicaux',
    targetAudience: 'Pour médecins généralistes & spécialistes en exercice',
    priceDZD: 18000,
    originalPriceDZD: 22000,
    durationDays: 365,
    durationLabel: '1 An d\'accès illimité (365 Jours)',
    isPopular: false,
    features: [
      'Générateur et vérificateur d\'ordonnances médicales',
      'Nomenclature nationale des médicaments algériens & Vidal',
      'Analyseur d\'interactions médicamenteuses et contre-indications',
      'Assistant interprétation radiologique et bilans de laboratoire',
      'Fiches de conduite à tenir en urgence (CAT)'
    ],
    paymentInstructions: {
      ccpAccount: '0021489012 Clé 45',
      ccpKey: '45',
      baridiMobRip: '00799999002148901245',
      baridiMobPhone: '+213 550 26 26 26'
    }
  },
  {
    id: 'plan_resident_elite',
    tier: 'resident_elite',
    title: 'Formule Résident Élite',
    subtitle: 'Préparation Concours Résidanat Algérie',
    targetAudience: 'Pour candidats au concours national de résidanat',
    priceDZD: 24000,
    originalPriceDZD: 30000,
    durationDays: 365,
    durationLabel: '1 An d\'accès illimité (365 Jours)',
    isPopular: true,
    features: [
      'Banque officielle QCMs d\'annales Résidanat (Alger, Blida, Constantine, Oran)',
      'Accès exclusif aux Concours Blancs Nationaux Synchronisés',
      'Classement national en temps réel & percentile comparatif',
      'Dossiers progressifs et cas cliniques tombables 2027',
      'Générateur d\'examens blancs sur mesure par spécialité'
    ],
    paymentInstructions: {
      ccpAccount: '0021489012 Clé 45',
      ccpKey: '45',
      baridiMobRip: '00799999002148901245',
      baridiMobPhone: '+213 550 26 26 26'
    }
  },
  {
    id: 'plan_all_access',
    tier: 'all_access',
    title: 'Medsina All-Access VIP',
    subtitle: 'La Suite Médicale Complète & Illimitée',
    targetAudience: 'Pour une couverture médicale et académique totale',
    priceDZD: 32000,
    originalPriceDZD: 42000,
    durationDays: 365,
    durationLabel: '1 An d\'accès illimité (365 Jours)',
    isPopular: false,
    features: [
      'Tout le contenu Étudiant + Clinical Pro + Résident Élite inclus',
      'Agent IA Médical MedSina illimité (Diagnostics, Triage, Synthèses)',
      'Accès prioritaire à toutes les versions mobiles (Android APK, Windows, Web)',
      'Badge VIP Médecin Vérifié sur le profil public Medsina',
      'Recommandations personnalisées par intelligence artificielle'
    ],
    paymentInstructions: {
      ccpAccount: '0021489012 Clé 45',
      ccpKey: '45',
      baridiMobRip: '00799999002148901245',
      baridiMobPhone: '+213 550 26 26 26'
    }
  }
];

export const INITIAL_LICENSES: AdminLicenseItem[] = [
  {
    keyCode: 'MEDSINA-VIP-2027-BLIDA-8841',
    tier: 'all_access',
    durationDays: 365,
    isRedeemed: true,
    redeemedBy: 'USR-102',
    redeemedUserName: 'Dr. Karim Belkacem',
    redeemedUserEmail: 'karim.belkacem.med@univ-alger.dz',
    redeemedUserRole: 'Résident en Spécialité',
    redeemedAt: '2026-10-20',
    createdAt: '2026-10-18',
    expiresAt: '2027-10-20',
    isExpired: false,
    daysRemaining: 345,
    isRevoked: false
  },
  {
    keyCode: 'MEDSINA-RES-2027-ALGER-9920',
    tier: 'resident_elite',
    durationDays: 365,
    isRedeemed: true,
    redeemedBy: 'USR-101',
    redeemedUserName: 'Dr. Amira Boukhalfa',
    redeemedUserEmail: 'dr.amira.b@gmail.com',
    redeemedUserRole: 'Candidat Résidanat',
    redeemedAt: '2026-11-08',
    createdAt: '2026-11-01',
    expiresAt: '2027-11-08',
    isExpired: false,
    daysRemaining: 364,
    isRevoked: false
  },
  {
    keyCode: 'MEDSINA-PRO-2027-CONSTANTINE-4412',
    tier: 'clinical_pro',
    durationDays: 365,
    isRedeemed: false,
    createdAt: '2026-11-05',
    isExpired: false,
    daysRemaining: 365,
    isRevoked: false
  },
  {
    keyCode: 'MEDSINA-EXT-2027-ORAN-1109',
    tier: 'etudiant',
    durationDays: 180,
    isRedeemed: false,
    createdAt: '2026-11-06',
    isExpired: false,
    daysRemaining: 180,
    isRevoked: false
  },
  {
    keyCode: 'MEDSINA-VIP-TEST-REVOKED-0012',
    tier: 'all_access',
    durationDays: 90,
    isRedeemed: true,
    redeemedUserName: 'Compte Test Suspendu',
    redeemedUserEmail: 'test.fraud@spam.dz',
    redeemedAt: '2026-09-10',
    createdAt: '2026-09-01',
    isExpired: true,
    daysRemaining: 0,
    isRevoked: true,
    revokedAt: '2026-09-22',
    revocationReason: 'Preuve de paiement falsifiée via faux bordereau CCP.'
  }
];

export const INITIAL_EXAMS: NationalExamModel[] = [
  {
    id: 'EXAM-2027-01',
    title: 'Concours Blanc National Résidanat 2027 — Épreuve d\'Automne',
    description: 'Épreuve officielle nationale simulant le concours de résidanat algérien. 60 QCMs cliniques transversaux. Classement national par note et rapidité.',
    targetType: 'residency',
    moduleId: 'MOD-TRANSV',
    moduleName: 'Épreuve Transversale Nationale',
    questionCount: 60,
    durationMinutes: 60,
    startDate: '2026-11-15 14:00',
    endDate: '2026-11-15 17:00',
    isSynchronous: true,
    participantsCount: 842,
    averageScore: 12.4,
    highestScore: 18.25,
    passRate: 64.8,
    status: 'upcoming'
  },
  {
    id: 'EXAM-2026-04',
    title: 'Examen Blanc National — Module Cardiologie & Vasculaire',
    description: 'Concours blanc d\'externat et résidanat ciblé sur l\'insuffisance cardiaque, syndromes coronariens aigus et pharmacologie cardio-vasculaire.',
    targetType: 'externat',
    moduleId: 'MOD-CARDIO',
    moduleName: 'Cardiologie & Vasculaire',
    questionCount: 40,
    durationMinutes: 45,
    startDate: '2026-11-02 10:00',
    endDate: '2026-11-02 18:00',
    isSynchronous: false,
    participantsCount: 1120,
    averageScore: 13.8,
    highestScore: 19.5,
    passRate: 72.1,
    status: 'completed'
  },
  {
    id: 'EXAM-2026-05',
    title: 'Grand Concours Blanc National — Pédiatrie & Néonatologie',
    description: 'Cas cliniques pédiatriques, urgences néonatales, calendrier vaccinal national algérien et pathologies infectieuses infantiles.',
    targetType: 'residency',
    moduleId: 'MOD-PED',
    moduleName: 'Pédiatrie & Urgences',
    questionCount: 50,
    durationMinutes: 50,
    startDate: '2026-10-25 14:00',
    endDate: '2026-10-25 16:00',
    isSynchronous: true,
    participantsCount: 960,
    averageScore: 11.9,
    highestScore: 17.8,
    passRate: 58.4,
    status: 'completed'
  }
];

export const INITIAL_ANNOUNCEMENTS: AnnouncementItem[] = [
  {
    id: 'ANN-01',
    title: 'Ouverture des Inscriptions : Concours Blanc National Résidanat 2027',
    message: 'L\'épreuve nationale aura lieu ce dimanche 15 Novembre 2026 à 14h00. Tous les abonnés Résident Élite et All-Access VIP sont automatiquement pré-inscrits avec calcul automatique du classement.',
    type: 'urgent',
    targetRole: 'residents',
    isActive: true,
    createdAt: '2026-11-08'
  },
  {
    id: 'ANN-02',
    title: 'Mise à Jour de la Nomenclature Nationale des Médicaments 2026',
    message: 'Le module Prescription & Vidal intègre désormais la dernière mise à jour du Ministère de la Santé (DCI, princeps et génériques disponibles en pharmacie en Algérie).',
    type: 'success',
    targetRole: 'doctors',
    isActive: true,
    createdAt: '2026-11-05'
  },
  {
    id: 'ANN-03',
    title: 'Nouvelle Version Android APK Octenium (v2.8.4) Disponible',
    message: 'Optimisation du mode hors-ligne pour les QCMs et réduction de l\'utilisation de données mobiles. Téléchargez la mise à jour depuis la section Téléchargements.',
    type: 'info',
    targetRole: 'all',
    isActive: true,
    createdAt: '2026-11-01'
  }
];

export const INITIAL_FACEBOOK_PROMPTS: AdminFacebookPrompt[] = [
  {
    id: 'FB-PRM-01',
    topic: 'Concours Blanc Résidanat 2027',
    postType: 'commercial',
    title: 'Rejoignez plus de 1,000 médecins algériens au Concours Blanc National',
    summary: 'Publication Facebook avec visuel BaridiMob et simulation de classement national.',
    fullPrompt: `🇩🇿 MÉDECINS D'ALGÉRIE : ÊTES-VOUS PRÊTS POUR LE RÉSIDANAT 2027 ? 🩺

Le Concours Blanc National Medsina ouvre ses portes ce Dimanche 15 Novembre !
🔹 60 QCMs exclusifs conformes aux comités pédagogiques nationaux (Alger, Blida, Constantine, Oran).
🔹 Correction détaillée interactive et explications physiopathologiques.
🔹 Classement national immédiat en direct par percentile.

💳 Inscription rapide via BaridiMob ou CCP en quelques minutes avec validation instantanée.
👉 Téléchargez l'application Medsina ou connectez-vous sur medsina.health`,
    suggestedMockup: 'desktop',
    theme: 'teal',
    status: 'pending',
    createdAt: '2026-11-09 01:20'
  },
  {
    id: 'FB-PRM-02',
    topic: 'Cas Clinique interactif du jour : Douleur thoracique chez le sujet jeune',
    postType: 'medical',
    title: 'Cas Clinique Résidanat : Myocardite vs Péricardite aiguë',
    summary: 'Publication scientifique pour stimuler l\'engagement des étudiants en médecine.',
    fullPrompt: `🧠 CAS CLINIQUE DU JOUR — SPÉCIALITÉ CARDIOLOGIE 🫀

Un jeune homme de 24 ans consulte aux urgences pour une douleur rétrosternale constrictive soulagée par l'antéflexion du tronc, survenant après un épisode grippal il y a 8 jours.
Tracé ECG : Sus-décalage du segment ST concave vers le haut dans toutes les dérivations avec sous-décalage du segment PR en DII.

Quelle est votre hypothèse diagnostique principale et la conduite à tenir immédiate ?
Répondez en commentaire ! La correction complète est disponible sur votre espace Medsina.`,
    suggestedMockup: 'mobile',
    theme: 'blue',
    status: 'published',
    createdAt: '2026-11-08 17:40'
  }
];
