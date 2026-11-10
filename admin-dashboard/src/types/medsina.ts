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
  totalQcmSolved?: number;
  totalCoursesCompleted?: number;
  totalStudyHours?: number;
  onlineNowCount?: number;
  activeTodayCount?: number;
  platformCounts?: {
    mobile: number;
    windows: number;
    web: number;
  };
}

export interface FinancialMetrics {
  totalRevenue: number; // in DZD
  pendingRevenue: number; // in DZD
  totalTransactions: number;
  approvedCount: number;
  pendingCount: number;
  rejectedCount: number;
}

export interface UserProgressMetrics {
  totalQcmSolved: number;
  todayQcmSolved: number;
  totalCoursesCompleted: number; // PDF courses read / finished
  todayCoursesCompleted: number;
  completedCourseIds: string[];
  averageAccuracy: number;
  dailyQcmGoal: number;
  dailyCourseGoal: number;
  specialtyBreakdown: Record<string, number>;
  coursesProgressList?: Array<{
    courseId: string;
    moduleId: string;
    courseName: string;
    isCompleted: boolean;
    lastActiveAt?: string;
    totalQuestions: number;
    revealedQuestions: string[];
    userAnswersCount?: number;
  }>;
  totalTimeSpentSeconds: number;
  fsrsCardsCount?: number;
  customSessionsCount?: number;
}

export interface UserConnectionTelemetry {
  connectionCount: number;
  streakDays: number;
  maxStreakDays: number;
  loyaltyPoints: number;
  loyaltyLevel: string;
  lastConnectionAt?: string;
  lastActiveDate?: string;
  firstActiveDate?: string;
  activeDaysHistory: string[];
  platformsUsed: Array<'web' | 'windows' | 'android' | 'mobile'>;
  primaryPlatform: 'web' | 'windows' | 'android' | 'mobile';
  isOnline: boolean; // Active within last 15 mins
  isActiveToday: boolean;
  appVersion?: string;
}

export interface AdminUserItem {
  id: string;
  email: string;
  fullName: string;
  medicalRole: MedicalRole | string;
  faculty: string;
  tier: SubscriptionTier;
  status: 'active' | 'suspended' | 'expired';
  expiresAt?: string;
  isAdmin: boolean;
  isBanned: boolean;
  banReason?: string;
  rejectedPaymentsCount: number;
  createdAt: string;
  updatedAt?: string;
  studyYear?: number;
  referralCode?: string;
  avatarUrl?: string;
  bio?: string;
  phone?: string;
  wilaya?: string;
  residencyTargetYear?: string;
  isInactiveSuspended?: boolean;
  inactiveSuspendedAt?: string;
  lastReactivatedAt?: string;
  reactivationCount?: number;
  lastConnectionAt?: string;
  progress?: UserProgressMetrics;
  telemetry?: UserConnectionTelemetry;
}

export interface SuspensionLogItem {
  id: string;
  userId: string;
  email?: string;
  fullName?: string;
  medicalRole?: string;
  eventType: 'inactivity_suspended' | 'reactivation_requested' | 'reactivation_validated' | 'admin_override' | string;
  reason?: string;
  daysInactive?: number;
  lastConnectionAt?: string;
  metadata?: Record<string, any>;
  createdAt: string;
}

export interface SuspensionMonitoringStats {
  suspendedInactivityCount: number;
  warningCount: number;
  totalReactivations: number;
  fraudBannedCount: number;
  recentLogs: SuspensionLogItem[];
}

export interface DoctorFullProfileDetails {
  profile: AdminUserItem;
  subscription?: {
    id?: string;
    tier: SubscriptionTier;
    status: string;
    expires_at?: string;
    max_devices?: number;
    created_at?: string;
  };
  payments: PaymentItem[];
  licenseKeys: AdminLicenseItem[];
  trialQuotas?: {
    selected_free_modules?: string[];
    qcm_sessions_used?: number;
    prescription_analyses_used?: number;
    lab_analyses_used?: number;
    copilot_queries_used?: number;
    has_used_trial?: boolean;
    updated_at?: string;
  };
  progress: UserProgressMetrics;
  telemetry: UserConnectionTelemetry;
  cloudSyncRecords?: Array<{
    data_type: string;
    updated_at: string;
    payload: any;
  }>;
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
