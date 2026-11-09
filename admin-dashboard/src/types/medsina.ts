/**
 * MedSina Platform Types & Models
 * Faithful to dochafedh26/medsina Flutter & Supabase schema
 */

export type NavigationTab = 
  | 'overview' 
  | 'users' 
  | 'payments' 
  | 'pricing' 
  | 'licenses' 
  | 'exams' 
  | 'announcements' 
  | 'ai_agents';

export type SubscriptionTier = 
  | 'free' 
  | 'etudiant' 
  | 'clinical_pro' 
  | 'resident_elite' 
  | 'all_access';

export type MedicalRole = 
  | 'Candidat Résidanat'
  | 'Médecin Généraliste'
  | 'Résident en Spécialité'
  | 'Spécialiste'
  | 'Interne'
  | 'Étudiant en Médecine';

export interface AdminMetrics {
  totalUsers: number;
  freeTrials: number;
  etudiant: number;
  clinicalPro: number;
  residentElite: number;
  allAccess: number;
  totalLicenses: number;
  redeemedLicenses: number;
  availableLicenses: number;
  octeniumTotalDownloads: number;
  octeniumApkDownloads: number;
  octeniumWindowsDownloads: number;
  octeniumWebVisits: number;
  octeniumLastDownloadAt?: string;
}

export interface FinancialMetrics {
  totalRevenue: number; // in DZD
  pendingRevenue: number; // in DZD
  totalTransactions: number;
  approvedCount: number;
  pendingCount: number;
  rejectedCount: number;
}

export interface AdminUserItem {
  id: string;
  email: string;
  fullName: string;
  medicalRole: MedicalRole;
  faculty: string;
  tier: SubscriptionTier;
  status: 'active' | 'suspended' | 'expired';
  expiresAt?: string;
  isAdmin: boolean;
  isBanned: boolean;
  banReason?: string;
  rejectedPaymentsCount: number;
  createdAt: string;
  studyYear?: number;
  referralCode?: string;
  avatarUrl?: string;
  bio?: string;
  phone?: string;
  wilaya?: string;
  residencyTargetYear?: string;
}

export interface PaymentItem {
  id: string;
  userId?: string;
  userEmail: string;
  userName: string;
  tier: SubscriptionTier;
  durationDays: number;
  amount: number;
  currency: string; // 'DZD'
  paymentMethod: 'baridimob' | 'ccp' | 'cib' | 'cash';
  receiptReference?: string;
  receiptUrl?: string;
  receiptFileName?: string;
  status: 'pending' | 'approved' | 'rejected' | 'archived';
  paymentType: 'subscription' | 'exam_pass' | 'qcm_bundle';
  bonusCredits: number;
  adminNotes?: string;
  isArchived: boolean;
  archiveDriveUrl?: string;
  archiveDriveFolder?: string;
  archivedAt?: string;
  createdAt: string;
  updatedAt?: string;
}

export interface PricingPlan {
  id: string;
  tier: SubscriptionTier;
  title: string;
  subtitle: string;
  targetAudience: string;
  priceDZD: number;
  originalPriceDZD?: number;
  durationDays: number;
  durationLabel: string;
  isPopular?: boolean;
  features: string[];
  paymentInstructions: {
    ccpAccount: string;
    ccpKey: string;
    baridiMobRip: string;
    baridiMobPhone: string;
  };
}

export interface AdminLicenseItem {
  keyCode: string;
  tier: SubscriptionTier;
  durationDays: number;
  isRedeemed: boolean;
  redeemedBy?: string;
  redeemedAt?: string;
  createdAt: string;
  redeemedUserName?: string;
  redeemedUserEmail?: string;
  redeemedUserRole?: string;
  expiresAt?: string;
  isExpired: boolean;
  daysRemaining: number;
  isRevoked: boolean;
  revokedAt?: string;
  revocationReason?: string;
}

export interface NationalExamModel {
  id: string;
  title: string;
  description: string;
  targetType: 'residency' | 'externat' | 'clinical';
  moduleId?: string;
  moduleName?: string;
  questionCount: number;
  durationMinutes: number;
  startDate: string;
  endDate: string;
  isSynchronous: boolean;
  participantsCount: number;
  averageScore: number;
  highestScore: number;
  passRate: number;
  status: 'upcoming' | 'active' | 'completed';
}

export interface AnnouncementItem {
  id: string;
  title: string;
  message: string;
  type: 'info' | 'warning' | 'urgent' | 'success';
  targetRole: 'all' | 'students' | 'residents' | 'doctors';
  isActive: boolean;
  createdAt: string;
}

export interface AdminFacebookPrompt {
  id: string;
  topic: string;
  postType: 'commercial' | 'medical' | 'auto';
  title: string;
  summary: string;
  fullPrompt: string;
  suggestedMockup: 'desktop' | 'mobile' | 'dual';
  theme: string;
  status: 'pending' | 'published' | 'draft';
  createdAt: string;
}
