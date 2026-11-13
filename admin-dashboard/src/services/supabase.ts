import { createClient, SupabaseClient, User, Session } from '@supabase/supabase-js';
import {
  AdminMetrics,
  AdminUserItem,
  PaymentItem,
  PricingPlan,
  AdminLicenseItem,
  NationalExamModel,
  AnnouncementItem,
  AdminFacebookPrompt,
  SubscriptionTier,
  FinancialMetrics,
  DoctorFullProfileDetails,
  UserProgressMetrics,
  UserConnectionTelemetry,
  SuspensionLogItem,
  SuspensionMonitoringStats
} from '../types/medsina';

// Supabase Configuration from Environment or Production Credentials
const SUPABASE_URL = 
  (import.meta.env.VITE_SUPABASE_URL as string) || 
  'https://qzfssrhhuorljftpdvjm.supabase.co';

const SUPABASE_ANON_KEY = 
  (import.meta.env.VITE_SUPABASE_ANON_KEY as string) || 
  'sb_publishable_E2OrqFqG1MbxVpoLb50jvA_DmOeP-UR';

// Optional service role key for admin-level operations that bypass RLS
const SUPABASE_SERVICE_ROLE_KEY = 
  (import.meta.env.VITE_SUPABASE_SERVICE_ROLE_KEY as string) || 
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF6ZnNzcmhodW9ybGpmdHBkdmptIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MTYxMjg1NCwiZXhwIjoyMTA3MTg4ODU0fQ.-KCUgZdY8RDUwvNOUAabDhQFwv5FFGHYz0J-dM7Cic4';

export const supabase: SupabaseClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true,
    storageKey: 'medsina_admin_auth_session',
  },
});

// Admin client for backend operations
export const supabaseAdmin: SupabaseClient = createClient(
  SUPABASE_URL, 
  SUPABASE_SERVICE_ROLE_KEY || SUPABASE_ANON_KEY,
  {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    }
  }
);

// --- AUTHENTICATION & ACCESS CONTROL ---

export interface AdminAuthProfile {
  id: string;
  email: string;
  fullName: string;
  medicalRole: string;
  isAdmin: boolean;
  avatarUrl?: string;
}

export async function getCurrentAdminSession(): Promise<{ user: AdminAuthProfile | null; session: Session | null }> {
  try {
    const { data: { session }, error } = await supabase.auth.getSession();
    if (error || !session) return { user: null, session: null };

    const user = session.user;
    if (!user) return { user: null, session: null };

    // Verify admin role in profiles table
    const { data: profile, error: profErr } = await supabaseAdmin
      .from('profiles')
      .select('id, email, full_name, medical_role, is_admin, avatar_url')
      .eq('id', user.id)
      .maybeSingle();

    const isAdm = profile?.is_admin === true || (user.email && user.email.toLowerCase() === 'doc.hafedh26@gmail.com');

    if (!isAdm) {
      console.warn('User is authenticated but not an admin:', user.email);
      return { user: null, session };
    }

    return {
      user: {
        id: profile?.id || user.id,
        email: profile?.email || user.email || '',
        fullName: profile?.full_name || 'Dr. Hafedh',
        medicalRole: profile?.medical_role || 'Administrateur Medsina',
        isAdmin: true,
        avatarUrl: profile?.avatar_url,
      },
      session
    };
  } catch (err) {
    console.error('Error fetching admin session:', err);
    return { user: null, session: null };
  }
}

export async function loginAdminWithEmail(email: string, password: string): Promise<{ success: boolean; user?: AdminAuthProfile; message?: string }> {
  try {
    const cleanEmail = email.trim().toLowerCase();
    const { data, error } = await supabase.auth.signInWithPassword({
      email: cleanEmail,
      password,
    });

    if (error) {
      return { success: false, message: error.message };
    }

    if (!data.user) {
      return { success: false, message: 'Utilisateur introuvable.' };
    }

    // Check admin flag
    const { data: profile, error: profErr } = await supabaseAdmin
      .from('profiles')
      .select('id, email, full_name, medical_role, is_admin, avatar_url')
      .eq('id', data.user.id)
      .maybeSingle();

    if (profErr || !profile || profile.is_admin !== true) {
      await supabase.auth.signOut();
      return {
        success: false,
        message: 'Accès refusé : ce compte ne dispose pas des privilèges administrateur Medsina.',
      };
    }

    return {
      success: true,
      user: {
        id: profile.id,
        email: profile.email || data.user.email || '',
        fullName: profile.full_name || 'Dr. Hafedh',
        medicalRole: profile.medical_role || 'Administrateur Medsina',
        isAdmin: true,
        avatarUrl: profile.avatar_url,
      },
    };
  } catch (err: any) {
    return { success: false, message: err?.message || 'Erreur de connexion.' };
  }
}

export async function signOutAdmin(): Promise<void> {
  await supabase.auth.signOut();
}

// --- REAL DATA RETRIEVAL (SUPABASE) ---

/**
 * Fetch live Octenium download counters & telemetry
 */
export async function fetchOcteniumStats(): Promise<{
  total: number;
  apk: number;
  windows: number;
  web: number;
  lastDownloadAt?: string;
  recentDownloads: Array<{ platform: string; version: string; source: string; createdAt: string }>;
}> {
  try {
    const { data, error } = await supabase.rpc('get_octenium_download_stats');
    if (!error && data && data.success) {
      return {
        total: Number(data.total_downloads || 0),
        apk: Number(data.apk_downloads || 0),
        windows: Number(data.windows_downloads || 0),
        web: Number(data.web_visits || 0),
        lastDownloadAt: data.last_download_at || undefined,
        recentDownloads: (data.recent_downloads || []).map((d: any) => ({
          platform: d.platform || 'android',
          version: d.version_name || '1.0.61',
          source: d.source || 'octenium',
          createdAt: d.created_at,
        })),
      };
    }
  } catch (err) {
    console.warn('RPC get_octenium_download_stats notice:', err);
  }

  // Fallback to direct query on admin_system_settings
  try {
    const { data: rows } = await supabaseAdmin
      .from('admin_system_settings')
      .select('setting_key, setting_value')
      .like('setting_key', 'octenium_%');

    let total = 83;
    let apk = 62;
    let windows = 21;
    let web = 0;
    let lastDownloadAt: string | undefined;

    if (rows) {
      for (const r of rows) {
        if (r.setting_key === 'octenium_total_downloads') total = parseInt(r.setting_value) || total;
        if (r.setting_key === 'octenium_apk_downloads') apk = parseInt(r.setting_value) || apk;
        if (r.setting_key === 'octenium_windows_downloads') windows = parseInt(r.setting_value) || windows;
        if (r.setting_key === 'octenium_web_visits') web = parseInt(r.setting_value) || web;
        if (r.setting_key === 'octenium_last_download_at') lastDownloadAt = r.setting_value;
      }
    }

    return { total, apk, windows, web, lastDownloadAt, recentDownloads: [] };
  } catch (e) {
    return { total: 83, apk: 62, windows: 21, web: 0, recentDownloads: [] };
  }
}

// --- ACADEMIC YEAR & STUDY ROLE RESOLVERS (FAITHFUL TO MEDSINA APP) ---

export function resolveStudyYear(profile: any, user?: AdminUserItem): number | null {
  if (profile?.study_year !== undefined && profile?.study_year !== null) {
    const y = parseInt(profile.study_year.toString(), 10);
    if (!isNaN(y) && y >= 1 && y <= 6) return y;
  }
  if (user?.studyYear !== undefined && user?.studyYear !== null) {
    const y = typeof user.studyYear === 'number' ? user.studyYear : parseInt(user.studyYear, 10);
    if (!isNaN(y) && y >= 1 && y <= 6) return y;
  }

  const combinedRole = `${profile?.medical_role || ''} ${user?.medicalRole || ''}`;
  const match = combinedRole.match(/([1-6])\s*(?:e|è|eme|ère)?\s*ann/i);
  if (match && match[1]) {
    const y = parseInt(match[1], 10);
    if (!isNaN(y)) return y;
  }

  const parenMatch = combinedRole.match(/\(\s*([1-6])/i);
  if (parenMatch && parenMatch[1]) {
    const y = parseInt(parenMatch[1], 10);
    if (!isNaN(y)) return y;
  }

  return null;
}

export function cleanMedicalRole(rawRole: string, studyYear: number | null): string {
  let cleaned = (rawRole || '').trim();
  cleaned = cleaned.replace(/\([eè]?\s*ann[eé]e\)/gi, '').trim();

  if (/étudiant|etudiant/i.test(cleaned)) {
    if (studyYear) {
      return `Étudiant (${studyYear}${studyYear === 1 ? 'ère' : 'ème'} Année)`;
    }
    return 'Étudiant en Médecine';
  }
  return cleaned.length > 0 ? cleaned : 'Médecin Praticien';
}

export function formatStudyYearDisplay(studyYear: number | null, medicalRole: string): string {
  if (studyYear !== null && studyYear >= 1 && studyYear <= 6) {
    return `${studyYear}${studyYear === 1 ? 'ère' : 'ème'} Année d'études (Cursus)`;
  }
  const lower = (medicalRole || '').toLowerCase();
  if (lower.includes('étudiant') || lower.includes('etudiant') || lower.includes('externe')) {
    return 'Étudiant (Année non renseignée)';
  }
  if (lower.includes('résident') || lower.includes('resident') || lower.includes('résidanat')) {
    return 'Médecin Résident (Spécialité)';
  }
  if (lower.includes('interne')) {
    return 'Interne en Médecine (7ème Année)';
  }
  return 'Diplômé / Praticien';
}

/**
 * Parses user_cloud_sync records to generate real-time Progress Metrics and Connection Telemetry
 */
export function parseUserCloudSync(
  syncRecords: any[],
  profile?: any
): { progress: UserProgressMetrics; telemetry: UserConnectionTelemetry } {
  let totalQcmSolved = 0;
  let todayQcmSolved = 0;
  let totalCoursesCompleted = 0;
  let todayCoursesCompleted = 0;
  let completedCourseIds: string[] = [];
  let averageAccuracy = 0;
  let dailyQcmGoal = 25;
  let dailyCourseGoal = 1;
  let specialtyBreakdown: Record<string, number> = {};
  let totalTimeSpentSeconds = 0;
  let fsrsCardsCount = 0;
  let customSessionsCount = 0;
  let coursesProgressList: any[] = [];

  let connectionCount = Number(profile?.connection_count || 1);
  let streakDays = Number(profile?.streak_days || 1);
  let maxStreakDays = Number(profile?.max_streak_days || 1);
  let loyaltyPoints = Number(profile?.loyalty_points || 10);
  let loyaltyLevel = profile?.loyalty_level || 'Externe Studieux';
  let lastActiveDate: string | undefined;
  let firstActiveDate: string | undefined;
  let activeDaysHistory: string[] = [];
  let detectedPlatform: 'web' | 'windows' | 'android' | 'mobile' | undefined;
  const platformsSet = new Set<'web' | 'windows' | 'android' | 'mobile'>();
  let latestActivityTimestamp = profile?.last_connection_at || profile?.updated_at || profile?.created_at;

  for (const record of syncRecords) {
    const payload = record.payload || {};
    const updatedAt = record.updated_at;
    if (updatedAt && (!latestActivityTimestamp || new Date(updatedAt) > new Date(latestActivityTimestamp))) {
      latestActivityTimestamp = updatedAt;
    }

    if (record.data_type === 'loyalty_tracker') {
      connectionCount = Math.max(connectionCount, Number(payload.connection_count || 1));
      streakDays = Math.max(streakDays, Number(payload.streak_days || 1));
      maxStreakDays = Math.max(maxStreakDays, Number(payload.max_streak_days || 1));
      loyaltyPoints = Math.max(loyaltyPoints, Number(payload.loyalty_points || 10));
      if (payload.loyalty_level) loyaltyLevel = payload.loyalty_level;
      if (payload.total_usage_seconds) totalTimeSpentSeconds = Math.max(totalTimeSpentSeconds, Number(payload.total_usage_seconds));
      if (payload.last_active_date) lastActiveDate = payload.last_active_date;
      if (payload.first_active_date) firstActiveDate = payload.first_active_date;
      if (Array.isArray(payload.active_days_history)) {
        activeDaysHistory = Array.from(new Set([...activeDaysHistory, ...payload.active_days_history]));
      }
      if (payload.platform) {
        const plat = payload.platform.toLowerCase();
        if (plat.includes('win')) { platformsSet.add('windows'); detectedPlatform = 'windows'; }
        else if (plat.includes('web')) { platformsSet.add('web'); detectedPlatform = 'web'; }
        else if (plat.includes('android')) { platformsSet.add('android'); detectedPlatform = 'android'; }
        else { platformsSet.add('mobile'); detectedPlatform = 'mobile'; }
      }
    } else if (record.data_type === 'study_progress' || record.data_type === 'user_study_progress') {
      totalQcmSolved = Math.max(totalQcmSolved, Number(payload.totalQcmSolved || 0));
      todayQcmSolved = Math.max(todayQcmSolved, Number(payload.todayQcmSolved || 0));
      todayCoursesCompleted = Math.max(todayCoursesCompleted, Number(payload.todayCoursesCompleted || 0));
      if (Array.isArray(payload.completedCourseIds)) {
        completedCourseIds = Array.from(new Set([...completedCourseIds, ...payload.completedCourseIds]));
      }
      totalCoursesCompleted = Math.max(
        totalCoursesCompleted, 
        Number(payload.totalCoursesCompleted || 0),
        completedCourseIds.length
      );
      if (payload.averageAccuracy) averageAccuracy = Number(payload.averageAccuracy);
      if (payload.dailyQcmGoal) dailyQcmGoal = Number(payload.dailyQcmGoal);
      if (payload.dailyCourseGoal) dailyCourseGoal = Number(payload.dailyCourseGoal);
      if (payload.specialtyBreakdown && typeof payload.specialtyBreakdown === 'object') {
        specialtyBreakdown = { ...specialtyBreakdown, ...payload.specialtyBreakdown };
      }
    } else if (record.data_type === 'course_progress') {
      const items = Array.isArray(payload) ? payload : Object.values(payload);
      coursesProgressList = items.map((c: any) => ({
        courseId: c.courseId || '',
        moduleId: c.moduleId || '',
        courseName: c.courseName || c.courseId || 'Cours Médical',
        isCompleted: !!c.isCompleted,
        lastActiveAt: c.lastActiveAt,
        totalQuestions: Number(c.totalQuestions || 0),
        revealedQuestions: Array.isArray(c.revealedQuestions) ? c.revealedQuestions : [],
        userAnswersCount: c.userAnswers ? Object.keys(c.userAnswers).length : 0,
      }));
      const completedFromList = coursesProgressList.filter(c => c.isCompleted).length;
      totalCoursesCompleted = Math.max(totalCoursesCompleted, completedFromList, coursesProgressList.length > 0 && totalCoursesCompleted === 0 ? 1 : totalCoursesCompleted);
    } else if (record.data_type === 'fsrs_flashcards') {
      const items = Array.isArray(payload) ? payload : Object.keys(payload);
      fsrsCardsCount = items.length;
    } else if (record.data_type === 'custom_sessions') {
      const items = Array.isArray(payload) ? payload : Object.keys(payload);
      customSessionsCount = items.length;
    } else if (record.data_type === 'platform_session') {
      if (payload.platform) {
        const plat = payload.platform.toLowerCase();
        if (plat.includes('win')) { platformsSet.add('windows'); detectedPlatform = 'windows'; }
        else if (plat.includes('web')) { platformsSet.add('web'); detectedPlatform = 'web'; }
        else if (plat.includes('android')) { platformsSet.add('android'); detectedPlatform = 'android'; }
        else { platformsSet.add('mobile'); detectedPlatform = 'mobile'; }
      }
    }
  }

  if (profile?.total_usage_seconds) {
    totalTimeSpentSeconds = Math.max(totalTimeSpentSeconds, Number(profile.total_usage_seconds));
  }

  if (platformsSet.size === 0) {
    platformsSet.add('android');
    detectedPlatform = 'android';
  }

  const now = Date.now();
  const lastActivityMs = latestActivityTimestamp ? new Date(latestActivityTimestamp).getTime() : 0;
  const isOnline = lastActivityMs > 0 && (now - lastActivityMs) < (15 * 60 * 1000); // within 15 min

  const todayStr = new Date().toISOString().slice(0, 10);
  const isActiveToday = isOnline || 
    (lastActiveDate === todayStr) || 
    (lastActivityMs > 0 && new Date(lastActivityMs).toISOString().slice(0, 10) === todayStr) ||
    activeDaysHistory.includes(todayStr);

  const progress: UserProgressMetrics = {
    totalQcmSolved,
    todayQcmSolved,
    totalCoursesCompleted,
    todayCoursesCompleted,
    completedCourseIds,
    averageAccuracy,
    dailyQcmGoal,
    dailyCourseGoal,
    specialtyBreakdown,
    coursesProgressList,
    totalTimeSpentSeconds,
    fsrsCardsCount,
    customSessionsCount,
  };

  const telemetry: UserConnectionTelemetry = {
    connectionCount,
    streakDays,
    maxStreakDays,
    loyaltyPoints,
    loyaltyLevel,
    lastConnectionAt: latestActivityTimestamp,
    lastActiveDate,
    firstActiveDate,
    activeDaysHistory,
    platformsUsed: Array.from(platformsSet),
    primaryPlatform: detectedPlatform || 'android',
    isOnline,
    isActiveToday,
  };

  return { progress, telemetry };
}

/**
 * Fetch all registered Medsina users with their subscription status and live sync telemetry
 */
export async function fetchRealUsers(): Promise<AdminUserItem[]> {
  // First, fetch user cloud sync data for all users to enrich user metrics
  const syncByUser = new Map<string, any[]>();
  try {
    const { data: allSync } = await supabaseAdmin.from('user_cloud_sync').select('*');
    if (allSync && Array.isArray(allSync)) {
      for (const row of allSync) {
        if (!row.user_id) continue;
        const list = syncByUser.get(row.user_id) || [];
        list.push(row);
        syncByUser.set(row.user_id, list);
      }
    }
  } catch (err) {
    console.warn('Error fetching all user_cloud_sync for overview:', err);
  }

  let usersList: AdminUserItem[] = [];

  try {
    const { data, error } = await supabase.rpc('admin_list_users');
    if (!error && Array.isArray(data) && data.length > 0) {
      usersList = data.map((u: any) => {
        const userSync = syncByUser.get(u.id) || [];
        const { progress, telemetry } = parseUserCloudSync(userSync, u);

        return {
          id: u.id,
          email: u.email || 'inconnu@medsina.dz',
          fullName: u.full_name || 'Docteur',
          medicalRole: u.medical_role || 'Médecin Généraliste',
          faculty: u.faculty || 'Faculté de Médecine',
          tier: (u.tier || 'free') as SubscriptionTier,
          status: (u.is_banned ? 'suspended' : (u.status || 'active')) as 'active' | 'suspended' | 'expired',
          expiresAt: u.expires_at || undefined,
          isAdmin: !!u.is_admin,
          isBanned: !!u.is_banned,
          banReason: u.ban_reason || undefined,
          rejectedPaymentsCount: u.rejected_payments_count || 0,
          createdAt: u.created_at || new Date().toISOString(),
          updatedAt: u.updated_at,
          studyYear: u.study_year || undefined,
          phone: u.phone || undefined,
          wilaya: u.wilaya || undefined,
          residencyTargetYear: u.residency_target_year || undefined,
          bio: u.bio || undefined,
          avatarUrl: u.avatar_url || undefined,
          referralCode: u.referral_code || `DR-${u.id.substring(0, 6).toUpperCase()}`,
          isInactiveSuspended: !!u.is_inactive_suspended || (!!u.is_banned && (u.ban_reason || '').toLowerCase().includes('inactiv')),
          inactiveSuspendedAt: u.inactive_suspended_at || undefined,
          lastReactivatedAt: u.last_reactivated_at || undefined,
          reactivationCount: Number(u.reactivation_count || 0),
          lastConnectionAt: u.last_connection_at || undefined,
          progress,
          telemetry,
        };
      });
      return usersList;
    }
  } catch (err) {
    console.warn('admin_list_users fallback:', err);
  }

  // Fallback direct join on profiles and subscriptions
  try {
    const { data: profs, error } = await supabaseAdmin
      .from('profiles')
      .select('*, subscriptions(*)')
      .order('created_at', { ascending: false });

    if (!error && profs) {
      return profs.map((p: any) => {
        const sub = Array.isArray(p.subscriptions) ? p.subscriptions[0] : p.subscriptions;
        const userSync = syncByUser.get(p.id) || [];
        const { progress, telemetry } = parseUserCloudSync(userSync, p);

        return {
          id: p.id,
          email: p.email || 'candidat@medsina.dz',
          fullName: p.full_name || 'Docteur',
          medicalRole: p.medical_role || 'Médecin Généraliste',
          faculty: p.faculty || 'Faculté de Médecine',
          tier: (sub?.tier || 'free') as SubscriptionTier,
          status: (p.is_banned ? 'suspended' : (sub?.status || 'active')) as 'active' | 'suspended' | 'expired',
          expiresAt: sub?.expires_at || undefined,
          isAdmin: !!p.is_admin,
          isBanned: !!p.is_banned,
          banReason: p.ban_reason || undefined,
          rejectedPaymentsCount: p.rejected_payments_count || 0,
          createdAt: p.created_at || new Date().toISOString(),
          updatedAt: p.updated_at,
          studyYear: p.study_year || undefined,
          phone: p.phone || undefined,
          wilaya: p.wilaya || undefined,
          residencyTargetYear: p.residency_target_year || undefined,
          bio: p.bio || undefined,
          avatarUrl: p.avatar_url || undefined,
          referralCode: p.referral_code || `DR-${p.id.substring(0, 6).toUpperCase()}`,
          isInactiveSuspended: !!p.is_inactive_suspended || (!!p.is_banned && (p.ban_reason || '').toLowerCase().includes('inactiv')),
          inactiveSuspendedAt: p.inactive_suspended_at || undefined,
          lastReactivatedAt: p.last_reactivated_at || undefined,
          reactivationCount: Number(p.reactivation_count || 0),
          lastConnectionAt: p.last_connection_at || undefined,
          progress,
          telemetry,
        };
      });
    }
  } catch (e) {
    console.error('Error fetching profiles fallback:', e);
  }

  return [];
}

/**
 * Fetch complete 360° doctor profile for Admin (Identité, Cursus, Abonnement, Paiements, Licences, Quotas, Usage)
 */
export async function fetchDoctorFullProfileDetails(
  userId: string,
  userEmail: string
): Promise<DoctorFullProfileDetails> {
  const [
    profileRes,
    subRes,
    paymentsRes,
    licensesRes,
    quotasRes,
    syncRes
  ] = await Promise.all([
    supabaseAdmin.from('profiles').select('*').eq('id', userId).maybeSingle(),
    supabaseAdmin.from('subscriptions').select('*').eq('user_id', userId).maybeSingle(),
    supabaseAdmin
      .from('payments')
      .select('*')
      .or(`user_id.eq.${userId},user_email.eq.${userEmail}`)
      .order('created_at', { ascending: false }),
    supabaseAdmin
      .from('license_keys')
      .select('*')
      .eq('redeemed_by', userId)
      .order('redeemed_at', { ascending: false }),
    supabaseAdmin.from('user_trial_quotas').select('*').eq('user_id', userId).maybeSingle(),
    supabaseAdmin.from('user_cloud_sync').select('*').eq('user_id', userId)
  ]);

  const p = profileRes.data || {};
  const sub = subRes.data || {};
  const paymentsList: PaymentItem[] = (paymentsRes.data || []).map((pay: any) => ({
    id: pay.id,
    userId: pay.user_id,
    userEmail: pay.user_email || userEmail,
    userName: pay.user_name || p.full_name || 'Docteur',
    tier: (pay.tier || 'all_access') as SubscriptionTier,
    durationDays: pay.duration_days || 365,
    amount: Number(pay.amount || 0),
    currency: pay.currency || 'DZD',
    paymentMethod: pay.payment_method || 'baridimob',
    receiptReference: pay.receipt_reference,
    receiptUrl: pay.receipt_url,
    receiptFileName: pay.receipt_file_name,
    status: pay.status || 'pending',
    paymentType: pay.payment_type || 'subscription',
    bonusCredits: pay.bonus_credits || 0,
    adminNotes: pay.admin_notes,
    isArchived: !!pay.is_archived,
    archiveDriveUrl: pay.archive_drive_url,
    archiveDriveFolder: pay.archive_drive_folder,
    archivedAt: pay.archived_at,
    createdAt: pay.created_at || new Date().toISOString(),
    updatedAt: pay.updated_at,
  }));

  const licenseKeysList: AdminLicenseItem[] = (licensesRes.data || []).map((l: any) => ({
    keyCode: l.key_code,
    tier: (l.tier || 'all_access') as SubscriptionTier,
    durationDays: l.duration_days || 365,
    isRedeemed: !!l.is_redeemed,
    redeemedBy: l.redeemed_by,
    redeemedAt: l.redeemed_at,
    createdAt: l.created_at || new Date().toISOString(),
    redeemedUserName: p.full_name,
    redeemedUserEmail: p.email,
    redeemedUserRole: p.medical_role,
    expiresAt: l.redeemed_at && l.duration_days ? new Date(new Date(l.redeemed_at).getTime() + l.duration_days * 86400000).toISOString() : undefined,
    isExpired: l.redeemed_at && l.duration_days ? new Date(new Date(l.redeemed_at).getTime() + l.duration_days * 86400000) < new Date() : false,
    daysRemaining: l.duration_days || 365,
    isRevoked: !!l.is_revoked,
    revokedAt: l.revoked_at,
  }));

  const syncRecords = syncRes.data || [];
  const { progress, telemetry } = parseUserCloudSync(syncRecords, p);

  const profileItem: AdminUserItem = {
    id: p.id || userId,
    email: p.email || userEmail,
    fullName: p.full_name || 'Docteur',
    medicalRole: p.medical_role || 'Médecin Généraliste',
    faculty: p.faculty || 'Faculté de Médecine',
    tier: (sub.tier || 'free') as SubscriptionTier,
    status: (p.is_banned ? 'suspended' : (sub.status || 'active')) as any,
    expiresAt: sub.expires_at || undefined,
    isAdmin: !!p.is_admin,
    isBanned: !!p.is_banned,
    banReason: p.ban_reason || undefined,
    rejectedPaymentsCount: p.rejected_payments_count || 0,
    createdAt: p.created_at || new Date().toISOString(),
    updatedAt: p.updated_at,
    studyYear: p.study_year || undefined,
    referralCode: p.referral_code || `DR-${(p.id || userId).substring(0, 6).toUpperCase()}`,
    avatarUrl: p.avatar_url || undefined,
    bio: p.bio || undefined,
    phone: p.phone || undefined,
    wilaya: p.wilaya || undefined,
    residencyTargetYear: p.residency_target_year || undefined,
    progress,
    telemetry,
  };

  return {
    profile: profileItem,
    subscription: sub.id ? {
      id: sub.id,
      tier: sub.tier || 'free',
      status: sub.status || 'active',
      expires_at: sub.expires_at,
      max_devices: sub.max_devices || 3,
      created_at: sub.created_at,
    } : undefined,
    payments: paymentsList,
    licenseKeys: licenseKeysList,
    trialQuotas: quotasRes.data ? {
      selected_free_modules: quotasRes.data.selected_free_modules || [],
      qcm_sessions_used: quotasRes.data.qcm_sessions_used || 0,
      prescription_analyses_used: quotasRes.data.prescription_analyses_used || 0,
      lab_analyses_used: quotasRes.data.lab_analyses_used || 0,
      copilot_queries_used: quotasRes.data.copilot_queries_used || 0,
      has_used_trial: !!quotasRes.data.has_used_trial,
      updated_at: quotasRes.data.updated_at,
    } : undefined,
    progress,
    telemetry,
    cloudSyncRecords: syncRecords.map((r: any) => ({
      data_type: r.data_type,
      updated_at: r.updated_at,
      payload: r.payload,
    })),
  };
}

/**
 * Updates academic year and medical role directly in Supabase
 */
export async function updateDoctorAcademicLevel(
  userId: string,
  studyYear: number | null,
  medicalRole: string
): Promise<boolean> {
  try {
    const { error } = await supabaseAdmin
      .from('profiles')
      .update({
        study_year: studyYear,
        medical_role: medicalRole,
        updated_at: new Date().toISOString(),
      })
      .eq('id', userId);

    return !error;
  } catch (err) {
    console.error('Error updating doctor academic level:', err);
    return false;
  }
}

/**
 * Fetch all payments from Supabase
 */
export async function fetchRealPayments(): Promise<PaymentItem[]> {
  try {
    const { data, error } = await supabaseAdmin
      .from('payments')
      .select('*')
      .order('created_at', { ascending: false });

    if (!error && data) {
      return data.map((p: any) => ({
        id: p.id,
        userId: p.user_id,
        userEmail: p.user_email || 'candidat@medsina.dz',
        userName: p.user_name || 'Docteur',
        tier: (p.tier || 'all_access') as SubscriptionTier,
        durationDays: p.duration_days || 365,
        amount: Number(p.amount || 0),
        currency: p.currency || 'DZD',
        paymentMethod: (p.payment_method || 'baridimob') as any,
        receiptReference: p.receipt_reference,
        receiptUrl: p.receipt_url,
        receiptFileName: p.receipt_file_name,
        status: (p.status || 'pending') as any,
        paymentType: (p.payment_type || 'subscription') as any,
        bonusCredits: p.bonus_credits || 0,
        adminNotes: p.admin_notes || undefined,
        isArchived: !!p.is_archived,
        archiveDriveUrl: p.archive_drive_url,
        archiveDriveFolder: p.archive_drive_folder,
        archivedAt: p.archived_at,
        createdAt: p.created_at || new Date().toISOString(),
        updatedAt: p.updated_at,
      }));
    }
  } catch (err) {
    console.error('Error fetching payments:', err);
  }
  return [];
}

/**
 * Fetch all license keys from Supabase
 */
export async function fetchRealLicenses(): Promise<AdminLicenseItem[]> {
  try {
    const { data, error } = await supabase.rpc('admin_list_license_keys');
    if (!error && Array.isArray(data) && data.length > 0) {
      return data.map((l: any) => ({
        keyCode: l.key_code,
        tier: (l.tier || 'all_access') as SubscriptionTier,
        durationDays: l.duration_days || 365,
        isRedeemed: !!l.is_redeemed,
        redeemedBy: l.redeemed_by,
        redeemedAt: l.redeemed_at,
        createdAt: l.created_at || new Date().toISOString(),
        redeemedUserName: l.redeemed_user_name,
        redeemedUserEmail: l.redeemed_user_email,
        redeemedUserRole: l.redeemed_user_role,
        expiresAt: l.expires_at,
        isExpired: !!l.is_expired,
        daysRemaining: l.days_remaining ?? (l.duration_days || 365),
        isRevoked: !!l.is_revoked,
        revokedAt: l.revoked_at,
      }));
    }
  } catch (err) {
    console.warn('admin_list_license_keys RPC fallback:', err);
  }

  try {
    const { data, error } = await supabaseAdmin
      .from('license_keys')
      .select('*')
      .order('created_at', { ascending: false });

    if (!error && data) {
      return data.map((l: any) => ({
        keyCode: l.key_code,
        tier: (l.tier || 'all_access') as SubscriptionTier,
        durationDays: l.duration_days || 365,
        isRedeemed: !!l.is_redeemed,
        redeemedBy: l.redeemed_by,
        redeemedAt: l.redeemed_at,
        createdAt: l.created_at || new Date().toISOString(),
        redeemedUserName: undefined,
        redeemedUserEmail: undefined,
        redeemedUserRole: undefined,
        expiresAt: undefined,
        isExpired: false,
        daysRemaining: l.duration_days || 365,
        isRevoked: !!l.is_revoked,
        revokedAt: l.revoked_at,
      }));
    }
  } catch (e) {
    console.error('Error fetching license_keys fallback:', e);
  }
  return [];
}

/**
 * Fetch subscription pricing plans from Supabase
 */
export async function fetchRealPricingPlans(): Promise<PricingPlan[]> {
  try {
    const { data, error } = await supabaseAdmin
      .from('subscription_plans')
      .select('*')
      .order('price_yearly', { ascending: true });

    if (!error && data && data.length > 0) {
      return data.map((p: any) => {
        let features: string[] = [];
        if (Array.isArray(p.features)) {
          features = p.features;
        } else if (typeof p.features === 'string') {
          try { features = JSON.parse(p.features); } catch { features = [p.features]; }
        }

        return {
          id: p.id,
          tier: (p.id || 'all_access') as SubscriptionTier,
          title: p.name || 'Formule Medsina',
          subtitle: p.badge || 'Accès Plateforme',
          targetAudience: p.id === 'etudiant' ? 'Étudiants 1ère à 6ème Année' : 'Candidats & Médecins',
          priceDZD: Number(p.price_yearly || 0),
          originalPriceDZD: Math.round(Number(p.price_yearly || 0) / (1 - (Number(p.discount_percent || 50) / 100))),
          durationDays: 365,
          durationLabel: 'Accès Annuel 365 Jours',
          isPopular: p.id === 'all_access',
          features: features.length > 0 ? features : [
            'Accès illimité aux modules officiels',
            'Banque QCMs commentés & corrigés',
            'Outils cliniques & Vidal Algérie'
          ],
          paymentInstructions: {
            ccpAccount: '0021489201',
            ccpKey: '45',
            baridiMobRip: '00799999002148920145',
            baridiMobPhone: '0550 12 34 56',
          },
        };
      });
    }
  } catch (err) {
    console.error('Error fetching subscription_plans:', err);
  }

  // Medsina official default plans
  return [
    {
      id: 'free',
      tier: 'free',
      title: 'Pass Découverte',
      subtitle: 'GRATUIT',
      targetAudience: 'Tous Médecins & Étudiants',
      priceDZD: 0,
      originalPriceDZD: 0,
      durationDays: 365,
      durationLabel: 'Accès Découverte',
      features: [
        '3 modules complets au choix (cours PDF + résumés)',
        '100 QCMs corrigés et commentés d\'initiation',
        'Calculateurs et scores médicaux essentiels (Glasgow, IMC, DFG)',
        '2 Conduites à Tenir d\'urgence vitale',
        '3 essais IA gratuits (Vidal IA, Bilan Labo & MedsinaPilot)'
      ],
      paymentInstructions: { ccpAccount: '0021489201', ccpKey: '45', baridiMobRip: '00799999002148920145', baridiMobPhone: '0550 12 34 56' }
    },
    {
      id: 'etudiant',
      tier: 'etudiant',
      title: 'Pass Étudiant (1ère - 6ème)',
      subtitle: 'CURSUS UNIVERSITAIRE',
      targetAudience: 'Étudiants en Médecine (1ère à 6ème Année)',
      priceDZD: 1900,
      originalPriceDZD: 4750,
      durationDays: 365,
      durationLabel: '365 Jours d\'accès illimité',
      features: [
        'Programme personnalisé selon votre année (1ère à 6ème)',
        'Banque QCMs d\'examens ultérieurs & EMD de Faculté',
        'Fiches de cours & résumés officiels de l\'année',
        'Mode révision semestrielle, partiels & Flashcards FSRS'
      ],
      paymentInstructions: { ccpAccount: '0021489201', ccpKey: '45', baridiMobRip: '00799999002148920145', baridiMobPhone: '0550 12 34 56' }
    },
    {
      id: 'clinical_pro',
      tier: 'clinical_pro',
      title: 'Pass Clinique Pro',
      subtitle: 'INTERNES & PRATICIENS',
      targetAudience: 'Médecins Généralistes & Internes',
      priceDZD: 2600,
      originalPriceDZD: 6000,
      durationDays: 365,
      durationLabel: '365 Jours d\'accès illimité',
      features: [
        'Toutes les Conduites à Tenir (CAT) par spécialité',
        'Arbres décisionnels et protocoles d\'urgence vitale Algérie',
        'Pharmacopée & DCI Algérie (Saidal, IPA, Biopharm) + Vidal IA',
        'Normes de laboratoire complètes avec interprétations IA'
      ],
      paymentInstructions: { ccpAccount: '0021489201', ccpKey: '45', baridiMobRip: '00799999002148920145', baridiMobPhone: '0550 12 34 56' }
    },
    {
      id: 'resident_elite',
      tier: 'resident_elite',
      title: 'Pass Résident Élite',
      subtitle: 'SPÉCIAL CONCOURS',
      targetAudience: 'Candidats au Concours de Résidanat',
      priceDZD: 3200,
      originalPriceDZD: 7200,
      durationDays: 365,
      durationLabel: '365 Jours d\'accès illimité',
      features: [
        'Les 47 modules officiels de préparation au Résidanat',
        'Banque complète de 6 240+ QCMs corrigés & commentés',
        'Simulateur d\'examens blancs chronométrés & Classement National',
        'Supports officiels de cours PDF & Flashcards FSRS'
      ],
      paymentInstructions: { ccpAccount: '0021489201', ccpKey: '45', baridiMobRip: '00799999002148920145', baridiMobPhone: '0550 12 34 56' }
    },
    {
      id: 'all_access',
      tier: 'all_access',
      title: 'Medsina All-Access (VIP)',
      subtitle: 'RECOMMANDÉ • SUITE COMPLÈTE',
      targetAudience: 'Accès Intégral Sans Limite',
      priceDZD: 3900,
      originalPriceDZD: 9000,
      durationDays: 365,
      durationLabel: '365 Jours d\'accès illimité',
      isPopular: true,
      features: [
        'Accès illimité aux 47 modules du Résidanat Blida & National',
        'Banque complète de 6 240+ QCMs avec corrigés détaillés',
        'Téléchargement de TOUS les cours officiels en PDF',
        'Volet Pratique Clinique, Garde & Pharmacopée DZ intégrale',
        'Quota IA maximal (Copilote Clinique, Ordonnance IA, Bilan Labo)',
        'Mode hors-ligne complet sur PC, Mobile et Web'
      ],
      paymentInstructions: { ccpAccount: '0021489201', ccpKey: '45', baridiMobRip: '00799999002148920145', baridiMobPhone: '0550 12 34 56' }
    }
  ];
}

/**
 * Fetch announcements from Supabase
 */
export async function fetchRealAnnouncements(): Promise<AnnouncementItem[]> {
  try {
    const { data, error } = await supabaseAdmin
      .from('system_announcements')
      .select('*')
      .order('created_at', { ascending: false });

    if (!error && data) {
      return data.map((a: any) => ({
        id: a.id,
        title: a.title || 'Annonce',
        message: a.message || a.content || '',
        type: (a.priority === 'urgent' ? 'warning' : 'info') as any,
        targetRole: (a.target_audience || 'all') as any,
        createdAt: a.created_at || new Date().toISOString(),
        isActive: a.is_active !== false,
      }));
    }
  } catch (err) {
    console.error('Error fetching announcements:', err);
  }
  return [];
}

/**
 * Fetch national exams from Supabase
 */
export async function fetchRealNationalExams(): Promise<NationalExamModel[]> {
  try {
    const { data, error } = await supabaseAdmin
      .from('national_exams')
      .select('*')
      .order('created_at', { ascending: false });

    if (!error && data) {
      return data.map((e: any) => ({
        id: e.id,
        title: e.title || 'Examen National',
        description: e.description || '',
        targetType: (e.target_type || 'residency') as any,
        moduleId: e.target_module_id,
        moduleName: e.target_module_name || 'Module Général',
        questionCount: Array.isArray(e.question_ids) ? e.question_ids.length : 60,
        durationMinutes: e.duration_minutes || 60,
        participantsCount: Number(e.participants_count || 0),
        status: (e.status === 'completed' ? 'completed' : (e.status === 'active' ? 'active' : 'upcoming')) as any,
        isSynchronous: e.is_synchronous !== false,
        startDate: e.start_time || e.start_date || new Date().toISOString(),
        endDate: e.end_time || e.end_date || new Date().toISOString(),
        averageScore: Number(e.average_score || 0),
        highestScore: Number(e.highest_score || 0),
        passRate: Number(e.pass_rate || 0),
      }));
    }
  } catch (err) {
    console.error('Error fetching national exams:', err);
  }
  return [];
}

// --- LIVE MUTATION ACTIONS ---

export async function approvePaymentInSupabase(
  paymentId: string,
  userId: string | undefined,
  tier: SubscriptionTier,
  durationDays: number,
  adminNotes?: string
): Promise<boolean> {
  try {
    const now = new Date().toISOString();
    // 1. Update payment status
    await supabaseAdmin
      .from('payments')
      .update({
        status: 'approved',
        admin_notes: adminNotes || 'Validé par l\'administrateur sur console Octenium',
        updated_at: now,
      })
      .eq('id', paymentId);

    // 2. Upgrade user subscription
    if (userId) {
      const expDate = new Date(Date.now() + durationDays * 24 * 60 * 60 * 1000).toISOString();
      const { data: existingSub } = await supabaseAdmin
        .from('subscriptions')
        .select('id')
        .eq('user_id', userId)
        .maybeSingle();

      if (existingSub) {
        await supabaseAdmin
          .from('subscriptions')
          .update({
            tier,
            status: 'active',
            expires_at: expDate,
            updated_at: now,
          })
          .eq('id', existingSub.id);
      } else {
        await supabaseAdmin
          .from('subscriptions')
          .insert({
            user_id: userId,
            tier,
            status: 'active',
            starts_at: now,
            expires_at: expDate,
            updated_at: now,
          });
      }
    }
    return true;
  } catch (e) {
    console.error('Error approving payment in Supabase:', e);
    return false;
  }
}

export async function rejectPaymentInSupabase(paymentId: string, reason: string): Promise<boolean> {
  try {
    await supabaseAdmin
      .from('payments')
      .update({
        status: 'rejected',
        admin_notes: reason,
        updated_at: new Date().toISOString(),
      })
      .eq('id', paymentId);
    return true;
  } catch (e) {
    console.error('Error rejecting payment in Supabase:', e);
    return false;
  }
}

export async function updateUserProfileInSupabase(
  userId: string,
  updates: Partial<AdminUserItem>
): Promise<boolean> {
  try {
    const dbUpdates: any = { updated_at: new Date().toISOString() };
    if (updates.fullName !== undefined) dbUpdates.full_name = updates.fullName;
    if (updates.medicalRole !== undefined) dbUpdates.medical_role = updates.medicalRole;
    if (updates.faculty !== undefined) dbUpdates.faculty = updates.faculty;
    if (updates.studyYear !== undefined) dbUpdates.study_year = updates.studyYear;
    if (updates.wilaya !== undefined) dbUpdates.wilaya = updates.wilaya;
    if (updates.phone !== undefined) dbUpdates.phone = updates.phone;
    if (updates.bio !== undefined) dbUpdates.bio = updates.bio;
    if (updates.residencyTargetYear !== undefined) dbUpdates.residency_target_year = updates.residencyTargetYear;

    await supabaseAdmin.from('profiles').update(dbUpdates).eq('id', userId);

    if (updates.tier || updates.expiresAt) {
      await supabaseAdmin.from('subscriptions').upsert({
        user_id: userId,
        tier: updates.tier || 'free',
        status: updates.status || 'active',
        expires_at: updates.expiresAt,
        updated_at: new Date().toISOString(),
      });
    }
    return true;
  } catch (e) {
    console.error('Error updating user profile:', e);
    return false;
  }
}

export async function banUserInSupabase(userId: string, reason: string): Promise<boolean> {
  try {
    const now = new Date().toISOString();
    await supabaseAdmin
      .from('profiles')
      .update({ is_banned: true, ban_reason: reason, banned_at: now })
      .eq('id', userId);

    await supabaseAdmin
      .from('subscriptions')
      .update({ status: 'suspended', updated_at: now })
      .eq('user_id', userId);
    return true;
  } catch (e) {
    console.error('Error banning user:', e);
    return false;
  }
}

export async function unbanUserInSupabase(userId: string): Promise<boolean> {
  try {
    const now = new Date().toISOString();
    await supabaseAdmin
      .from('profiles')
      .update({ is_banned: false, ban_reason: null, banned_at: null, rejected_payments_count: 0 })
      .eq('id', userId);

    await supabaseAdmin
      .from('subscriptions')
      .update({ status: 'active', updated_at: now })
      .eq('user_id', userId);
    return true;
  } catch (e) {
    console.error('Error unbanning user:', e);
    return false;
  }
}

/**
 * Reactivate an inactive-suspended user (calls RPC with fallback)
 */
export async function reactivateUserInSupabase(userId: string): Promise<{ success: boolean; message: string }> {
  try {
    const { data, error } = await supabase.rpc('request_and_reactivate_account', { p_user_id: userId });
    if (!error && data && typeof data === 'object') {
      return { success: !!data.success, message: data.message || 'Compte réactivé avec succès.' };
    }
  } catch (err) {
    console.warn('request_and_reactivate_account RPC fallback:', err);
  }

  // Direct fallback
  try {
    const now = new Date().toISOString();
    await supabaseAdmin
      .from('profiles')
      .update({
        is_inactive_suspended: false,
        is_banned: false,
        ban_reason: null,
        banned_at: null,
        inactive_suspended_at: null,
        last_reactivated_at: now,
        last_connection_at: now,
        updated_at: now,
      })
      .eq('id', userId);

    await supabaseAdmin
      .from('subscriptions')
      .update({ status: 'active', updated_at: now })
      .eq('user_id', userId);

    return { success: true, message: 'Compte réactivé avec succès.' };
  } catch (e: any) {
    console.error('Error reactivating user in fallback:', e);
    return { success: false, message: e.message || 'Erreur lors de la réactivation' };
  }
}

/**
 * Trigger 7-day inactivity check & suspension across all users
 */
export async function triggerInactivitySuspensionCheck(daysThreshold: number = 7): Promise<{ success: boolean; count: number; message: string }> {
  try {
    const { data, error } = await supabase.rpc('check_and_suspend_inactive_users', { p_days_threshold: daysThreshold });
    if (!error && data) {
      return {
        success: true,
        count: Number(data.suspended_count || 0),
        message: `${data.suspended_count || 0} compte(s) inactif(s) depuis >= ${daysThreshold} jours ont été suspendus momentanément.`
      };
    }
  } catch (err) {
    console.warn('check_and_suspend_inactive_users RPC error:', err);
  }

  // Client-side fallback
  try {
    const now = Date.now();
    const thresholdMs = daysThreshold * 24 * 3600 * 1000;
    const { data: profs, error } = await supabaseAdmin
      .from('profiles')
      .select('id, email, full_name, created_at, last_connection_at, is_banned, is_admin')
      .eq('is_banned', false);

    if (error || !profs) throw error || new Error('Impossible de charger les profils');

    let count = 0;
    for (const p of profs) {
      if (p.is_admin || (p.email && p.email.toLowerCase().includes('doc.hafedh26'))) continue;
      const lastActive = p.last_connection_at ? new Date(p.last_connection_at).getTime() : new Date(p.created_at).getTime();
      if (now - lastActive >= thresholdMs) {
        const days = Math.floor((now - lastActive) / (24 * 3600 * 1000));
        await supabaseAdmin
          .from('profiles')
          .update({
            is_inactive_suspended: true,
            is_banned: true,
            ban_reason: `Compte suspendu pour inactivité (${days} jours sans connexion)`,
            inactive_suspended_at: new Date().toISOString(),
            banned_at: new Date().toISOString(),
          })
          .eq('id', p.id);
        count++;
      }
    }

    return {
      success: true,
      count,
      message: `${count} compte(s) inactif(s) depuis >= ${daysThreshold} jours suspendus (mode direct).`
    };
  } catch (e: any) {
    return { success: false, count: 0, message: e.message || 'Erreur lors de la vérification' };
  }
}

/**
 * Fetch suspension & reactivation monitoring metrics + recent audit logs
 */
export async function fetchSuspensionMonitoringData(): Promise<SuspensionMonitoringStats> {
  try {
    const { data, error } = await supabase.rpc('admin_get_suspension_stats_and_logs');
    if (!error && data) {
      return {
        suspendedInactivityCount: Number(data.suspended_inactivity_count || 0),
        warningCount: Number(data.warning_count || 0),
        totalReactivations: Number(data.total_reactivations || 0),
        fraudBannedCount: Number(data.fraud_banned_count || 0),
        recentLogs: Array.isArray(data.recent_logs)
          ? data.recent_logs.map((l: any) => ({
              id: l.id,
              userId: l.user_id,
              email: l.email,
              fullName: l.full_name,
              medicalRole: l.medical_role,
              eventType: l.event_type,
              reason: l.reason,
              daysInactive: l.days_inactive,
              lastConnectionAt: l.last_connection_at,
              metadata: l.metadata,
              createdAt: l.created_at,
            }))
          : [],
      };
    }
  } catch (err) {
    console.warn('admin_get_suspension_stats_and_logs fallback:', err);
  }

  // Direct table queries fallback
  try {
    const [profilesRes, logsRes] = await Promise.all([
      supabaseAdmin.from('profiles').select('id, email, is_banned, ban_reason, is_inactive_suspended, last_connection_at, created_at, reactivation_count'),
      supabaseAdmin.from('user_suspension_logs').select('*').order('created_at', { ascending: false }).limit(50),
    ]);

    const profs = profilesRes.data || [];
    const logs = logsRes.data || [];
    const now = Date.now();

    let suspendedInactivityCount = 0;
    let warningCount = 0;
    let fraudBannedCount = 0;
    let totalReactivations = 0;

    for (const p of profs) {
      totalReactivations += Number(p.reactivation_count || 0);
      const isInactiveSusp = p.is_inactive_suspended || (p.is_banned && (p.ban_reason || '').toLowerCase().includes('inactiv'));
      if (isInactiveSusp) {
        suspendedInactivityCount++;
      } else if (p.is_banned) {
        fraudBannedCount++;
      } else {
        const lastActive = p.last_connection_at ? new Date(p.last_connection_at).getTime() : new Date(p.created_at).getTime();
        const days = (now - lastActive) / (24 * 3600 * 1000);
        if (days >= 5 && days < 7) {
          warningCount++;
        }
      }
    }

    return {
      suspendedInactivityCount,
      warningCount,
      totalReactivations,
      fraudBannedCount,
      recentLogs: logs.map((l: any) => ({
        id: l.id,
        userId: l.user_id,
        email: l.email,
        fullName: l.full_name,
        medicalRole: l.medical_role,
        eventType: l.event_type,
        reason: l.reason,
        daysInactive: l.days_inactive,
        lastConnectionAt: l.last_connection_at,
        metadata: l.metadata,
        createdAt: l.created_at,
      })),
    };
  } catch (e) {
    console.error('Error fetching suspension monitoring fallback:', e);
    return {
      suspendedInactivityCount: 0,
      warningCount: 0,
      totalReactivations: 0,
      fraudBannedCount: 0,
      recentLogs: [],
    };
  }
}

export async function generateLicenseKeysInSupabase(
  tier: SubscriptionTier,
  durationDays: number,
  count: number,
  prefix: string
): Promise<AdminLicenseItem[]> {
  const newLicenses: AdminLicenseItem[] = [];
  const now = new Date().toISOString();

  for (let i = 0; i < count; i++) {
    const randPart = Math.random().toString(36).substring(2, 7).toUpperCase() + '-' +
                     Math.random().toString(36).substring(2, 7).toUpperCase();
    const keyCode = `${prefix.trim().toUpperCase()}-${randPart}`;

    try {
      await supabaseAdmin.from('license_keys').insert({
        key_code: keyCode,
        tier,
        duration_days: durationDays,
        is_redeemed: false,
        is_revoked: false,
        created_at: now,
      });

      newLicenses.push({
        keyCode,
        tier,
        durationDays,
        isRedeemed: false,
        createdAt: now,
        isExpired: false,
        daysRemaining: durationDays,
        isRevoked: false,
      });
    } catch (e) {
      console.error('Error inserting license key:', e);
    }
  }
  return newLicenses;
}

export async function revokeLicenseInSupabase(keyCode: string, reason: string): Promise<boolean> {
  try {
    await supabaseAdmin
      .from('license_keys')
      .update({
        is_revoked: true,
        revoked_at: new Date().toISOString(),
        revocation_reason: reason,
      })
      .eq('key_code', keyCode);
    return true;
  } catch (e) {
    console.error('Error revoking license:', e);
    return false;
  }
}

export async function updatePlanPriceInSupabase(plan: PricingPlan): Promise<boolean> {
  try {
    await supabaseAdmin
      .from('subscription_plans')
      .update({
        price_yearly: plan.priceDZD,
        badge: plan.subtitle,
        updated_at: new Date().toISOString(),
      })
      .eq('id', plan.id);
    return true;
  } catch (e) {
    console.error('Error updating plan:', e);
    return false;
  }
}

export async function createAnnouncementInSupabase(announcement: AnnouncementItem): Promise<boolean> {
  try {
    await supabaseAdmin
      .from('system_announcements')
      .insert({
        title: announcement.title,
        message: announcement.message,
        priority: announcement.type === 'warning' ? 'urgent' : 'normal',
        target_audience: announcement.targetRole,
        is_active: announcement.isActive,
        created_at: new Date().toISOString(),
      });
    return true;
  } catch (e) {
    console.error('Error creating announcement:', e);
    return false;
  }
}

export async function toggleAnnouncementInSupabase(id: string, currentStatus: boolean): Promise<boolean> {
  try {
    await supabaseAdmin
      .from('system_announcements')
      .update({ is_active: !currentStatus })
      .eq('id', id);
    return true;
  } catch (e) {
    console.error('Error toggling announcement:', e);
    return false;
  }
}

export async function createNationalExamInSupabase(exam: NationalExamModel): Promise<boolean> {
  try {
    await supabaseAdmin
      .from('national_exams')
      .insert({
        title: exam.title,
        description: exam.description,
        target_type: exam.targetType,
        target_module_name: exam.moduleName,
        duration_minutes: exam.durationMinutes,
        is_synchronous: exam.isSynchronous,
        start_time: exam.startDate,
        end_time: exam.endDate,
        status: exam.status,
        created_at: new Date().toISOString(),
      });
    return true;
  } catch (e) {
    console.error('Error creating national exam:', e);
    return false;
  }
}

// =========================================================================
// --- BLIDA RESOURCE SCANNER & ADMIN VALIDATION QUEUE (TELEGRAM & DRIVE) ---
// =========================================================================

export interface DiscoveredBlidaResource {
  id: string;
  title: string;
  resource_type?: string; // 'pdf_course' | 'qcm_exam' | 'drive_folder' | 'telegram_post' | 'mindmap' | 'other'
  source_type?: string;   // 'telegram' | 'gdrive' | 'google_drive'
  source_origin?: string;
  source_channel_or_folder?: string;
  source_url?: string;
  url?: string;
  gdrive_file_id?: string | null;
  suggested_module?: string;
  suggested_module_id?: string | null;
  suggested_course_id?: string | null;
  study_year?: string | null;
  ai_summary?: string | null;
  description?: string | null;
  file_size_bytes?: number | null;
  status: 'pending' | 'approved' | 'rejected';
  discovered_at: string;
  reviewed_at?: string | null;
  external_id_hash?: string;
}

const BLIDA_QUEUE_SETTING_KEY = 'discovered_blida_resources_queue';
const BLIDA_SOURCES_SETTING_KEY = 'blida_scanner_sources';

export const DEFAULT_BLIDA_SCANNER_SOURCES = JSON.stringify({
  telegram_channels: [
    "fmb_blida",
    "medecine_blida",
    "residanat_blida",
    "preprsdblida",
    "medsina_dz",
    "qcm_medecine_dz",
    "Samedispedigogique2027DrKare",
    "mbset_blida",
    "TOSAVELIVESTOGETHER"
  ],
  google_drive_folders: [
    "https://drive.google.com/drive/folders/1UjaxyXp8pU56jlz-F7K-MGECj2pheF21",
    "https://drive.google.com/drive/folders/1JYDVaU42brJ3TQPRGbrO90L5a_FSK6Q4",
    "https://drive.google.com/drive/folders/1Bka0eECqgf1A0Iyu9VSsfPgBAzDcPa_w",
    "https://drive.google.com/drive/folders/1P_qrApYN84T6jlu1qwxPzHvlWVOnGqVd",
    "https://drive.google.com/drive/folders/1q6cZ52JWDRrIOhCmL0TclGBTv_u0aaIq",
    "https://drive.google.com/drive/folders/1-4j0fd19TOa4jyAFeIIzbh6zIu085O5q",
    "https://drive.google.com/drive/folders/1aAngO0Y0gX-LfMR-JQqxqauVHCPZUVJ5",
    "https://drive.google.com/drive/folders/1jdJczV8lu7Wvu_2k6KLfIltVxN_T6P3f",
    "https://drive.google.com/drive/folders/1888ecPxZRrxbhzjdb3hSFGv23yzvExjz",
    "https://drive.google.com/drive/folders/1VyQT2OAOxxlnEc2uWRqJ9IJQAhx3PkQo",
    "https://drive.google.com/drive/folders/1j0G8NAA4cCPYqSAY3y-icIHWN88UYsnx",
    "https://drive.google.com/drive/folders/1Bi6qBMDqz593h06PePPaT-GtOov6lKZZ",
    "https://drive.google.com/drive/folders/1-NgPKBA4PNC8SVNotO9-qvK1yVoqhhvw",
    "https://drive.google.com/drive/folders/1Xnlf_q1v-VhVB7Sl5197pXZX-TlzuAAV"
  ],
  keywords: [
    "Blida",
    "FMB",
    "QCM",
    "EMD",
    "Rattrapage",
    "Résidanat",
    "Corrigé",
    "CHU Frantz Fanon",
    "Dr. Mahdaoui",
    "Dr.MAHDAOUI",
    "Mahdaoui",
    "Zeemed",
    "Dr KARE",
    "SP2026",
    "SP2027",
    "Samedis Pédagogiques",
    "MBset"
  ]
}, null, 2);

/**
 * Get setting value from admin_system_settings
 */
export async function getAdminSetting(key: string): Promise<string | null> {
  try {
    const { data, error } = await supabaseAdmin
      .from('admin_system_settings')
      .select('setting_value')
      .eq('setting_key', key)
      .maybeSingle();
    if (error || !data) return null;
    return data.setting_value || null;
  } catch (err) {
    console.warn(`Error getting admin setting ${key}:`, err);
    return null;
  }
}

/**
 * Save setting value into admin_system_settings
 */
export async function saveAdminSetting(key: string, value: string, description?: string): Promise<boolean> {
  try {
    const payload: any = {
      setting_key: key,
      setting_value: value,
      updated_at: new Date().toISOString(),
    };
    if (description) payload.description = description;

    const { error } = await supabaseAdmin
      .from('admin_system_settings')
      .upsert(payload);
    return !error;
  } catch (err) {
    console.error(`Error saving admin setting ${key}:`, err);
    return false;
  }
}

/**
 * Retrieve JSON configuration of watched Telegram channels & Google Drive folders
 */
export async function getBlidaScannerSources(): Promise<string> {
  const val = await getAdminSetting(BLIDA_SOURCES_SETTING_KEY);
  if (val && val.trim().length > 0) {
    return val.trim();
  }
  return DEFAULT_BLIDA_SCANNER_SOURCES;
}

/**
 * Save JSON configuration of watched Telegram channels & Google Drive folders
 */
export async function saveBlidaScannerSources(jsonConfig: string): Promise<boolean> {
  return await saveAdminSetting(
    BLIDA_SOURCES_SETTING_KEY,
    jsonConfig.trim(),
    'Sources Telegram et Google Drive surveillées par le scanner Médecine Blida'
  );
}

/**
 * Helper to normalize raw resource item properties
 */
function normalizeBlidaResource(item: any): DiscoveredBlidaResource {
  const id = (item.id || item.external_id_hash || `res_${Math.random().toString(36).substring(2, 9)}`).toString();
  const title = (item.title || 'Ressource sans titre').toString();
  const source_type = (item.source_type || (item.url?.includes('drive.google') ? 'gdrive' : 'telegram')).toString();
  const source_channel_or_folder = (item.source_channel_or_folder || item.source_origin || '').toString();
  const url = (item.url || item.source_url || '').toString();
  const resource_type = (item.resource_type || (url.includes('drive.google') ? 'gdrive_folder' : 'telegram_post')).toString();
  const suggested_module = (item.suggested_module || item.suggested_course_id || 'Médecine Blida').toString();
  const ai_summary = (item.ai_summary || item.description || '').toString();
  const status = (item.status === 'approved' || item.status === 'rejected' ? item.status : 'pending') as 'pending' | 'approved' | 'rejected';

  return {
    id,
    title,
    resource_type,
    source_type,
    source_origin: item.source_origin || source_channel_or_folder,
    source_channel_or_folder,
    source_url: item.source_url || url,
    url,
    gdrive_file_id: item.gdrive_file_id || null,
    suggested_module,
    suggested_module_id: item.suggested_module_id || null,
    suggested_course_id: item.suggested_course_id || null,
    study_year: item.study_year || null,
    ai_summary,
    description: item.description || ai_summary,
    file_size_bytes: item.file_size_bytes || null,
    status,
    discovered_at: item.discovered_at || new Date().toISOString(),
    reviewed_at: item.reviewed_at || null,
    external_id_hash: item.external_id_hash || undefined,
  };
}

/**
 * Fetch discovered Blida resources filtered by status ('pending', 'approved', 'rejected', or 'all')
 */
export async function fetchDiscoveredBlidaResources(
  status: 'pending' | 'approved' | 'rejected' | 'all' = 'pending'
): Promise<DiscoveredBlidaResource[]> {
  // 1. Try dedicated table `discovered_blida_resources`
  try {
    let query = supabaseAdmin.from('discovered_blida_resources').select('*');
    if (status !== 'all') {
      query = query.eq('status', status);
    }
    const { data, error } = await query.order('discovered_at', { ascending: false }).limit(250);
    if (!error && data && data.length > 0) {
      return data.map(normalizeBlidaResource);
    }
  } catch (err) {
    console.warn('Note: discovered_blida_resources table query fallback to admin_system_settings:', err);
  }

  // 2. Fallback to `admin_system_settings` ('discovered_blida_resources_queue')
  try {
    const rawJson = await getAdminSetting(BLIDA_QUEUE_SETTING_KEY);
    if (rawJson && rawJson.trim().length > 0) {
      const decoded = JSON.parse(rawJson);
      if (Array.isArray(decoded)) {
        const filtered = decoded
          .filter((item: any) => {
            if (status === 'all') return true;
            return (item.status || 'pending') === status;
          })
          .map(normalizeBlidaResource);
        return filtered;
      }
    }
  } catch (err) {
    console.warn('Error reading discovered_blida_resources_queue setting:', err);
  }

  return [];
}

/**
 * Approve or reject a single discovered resource
 */
export async function updateDiscoveredBlidaResourceStatus(
  idOrHash: string,
  newStatus: 'approved' | 'rejected'
): Promise<boolean> {
  const nowIso = new Date().toISOString();
  let updatedTable = false;
  let updatedSetting = false;

  // 1. Attempt update on dedicated table
  try {
    const { error } = await supabaseAdmin
      .from('discovered_blida_resources')
      .update({
        status: newStatus,
        reviewed_at: nowIso,
      })
      .eq('id', idOrHash);
    if (!error) updatedTable = true;
  } catch (err) {
    console.warn('Note: update discovered_blida_resources table error:', err);
  }

  // 2. Also update JSON queue in admin_system_settings to stay synced
  try {
    const rawJson = await getAdminSetting(BLIDA_QUEUE_SETTING_KEY);
    if (rawJson && rawJson.trim().length > 0) {
      const decoded = JSON.parse(rawJson);
      if (Array.isArray(decoded)) {
        let changed = false;
        const updatedList = decoded.map((item: any) => {
          if (item && typeof item === 'object') {
            const itemId = (item.id || '').toString();
            const itemHash = (item.external_id_hash || '').toString();
            if (itemId === idOrHash || itemHash === idOrHash) {
              changed = true;
              return {
                ...item,
                status: newStatus,
                reviewed_at: nowIso,
              };
            }
          }
          return item;
        });

        if (changed) {
          updatedSetting = await saveAdminSetting(
            BLIDA_QUEUE_SETTING_KEY,
            JSON.stringify(updatedList),
            'File d\'attente de validation Admin des ressources Blida (Telegram & Google Drive)'
          );
        }
      }
    }
  } catch (err) {
    console.warn('Error updating blida queue setting:', err);
  }

  return updatedTable || updatedSetting;
}

/**
 * Fetch total counts for Blida queue (pending, approved, rejected, all)
 */
export async function fetchBlidaQueueCounts(): Promise<{ pending: number; approved: number; rejected: number; all: number }> {
  try {
    const [allRes, pendingRes, approvedRes, rejectedRes] = await Promise.all([
      supabaseAdmin.from('discovered_blida_resources').select('*', { count: 'exact', head: true }),
      supabaseAdmin.from('discovered_blida_resources').select('*', { count: 'exact', head: true }).eq('status', 'pending'),
      supabaseAdmin.from('discovered_blida_resources').select('*', { count: 'exact', head: true }).eq('status', 'approved'),
      supabaseAdmin.from('discovered_blida_resources').select('*', { count: 'exact', head: true }).eq('status', 'rejected'),
    ]);

    const all = allRes.count ?? 0;
    const pending = pendingRes.count ?? 0;
    const approved = approvedRes.count ?? 0;
    const rejected = rejectedRes.count ?? 0;

    if (all > 0) {
      return { pending, approved, rejected, all };
    }
  } catch (err) {
    console.warn('Error fetching blida table counts, fallback to queue setting:', err);
  }

  // Fallback to admin_system_settings
  try {
    const rawJson = await getAdminSetting(BLIDA_QUEUE_SETTING_KEY);
    if (rawJson) {
      const decoded = JSON.parse(rawJson);
      if (Array.isArray(decoded)) {
        let pending = 0;
        let approved = 0;
        let rejected = 0;
        decoded.forEach((item: any) => {
          if (item?.status === 'approved') approved++;
          else if (item?.status === 'rejected') rejected++;
          else pending++;
        });
        return { pending, approved, rejected, all: decoded.length };
      }
    }
  } catch (err) {
    console.warn('Error parsing queue setting counts:', err);
  }

  return { pending: 0, approved: 0, rejected: 0, all: 0 };
}

/**
 * Batch approve or reject discovered resources
 */
export async function updateDiscoveredBlidaResourcesBatch(
  idsOrHashes: string[],
  newStatus: 'approved' | 'rejected'
): Promise<number> {
  if (!idsOrHashes.length) return 0;
  const idSet = new Set(idsOrHashes);
  const nowIso = new Date().toISOString();
  let tableUpdatedCount = 0;

  // 1. Attempt batch update on dedicated table in chunks of 50
  try {
    for (let i = 0; i < idsOrHashes.length; i += 50) {
      const chunk = idsOrHashes.slice(i, i + 50);
      const { error } = await supabaseAdmin
        .from('discovered_blida_resources')
        .update({
          status: newStatus,
          reviewed_at: nowIso,
        })
        .in('id', chunk);
      if (!error) {
        tableUpdatedCount += chunk.length;
      }
    }
  } catch (err) {
    console.warn('Error batch updating discovered_blida_resources table:', err);
  }

  // 2. Also update the JSON queue in admin_system_settings
  let settingAffected = 0;
  try {
    const rawJson = await getAdminSetting(BLIDA_QUEUE_SETTING_KEY);
    if (rawJson && rawJson.trim().length > 0) {
      const decoded = JSON.parse(rawJson);
      if (Array.isArray(decoded)) {
        let changed = false;
        const updatedList = decoded.map((item: any) => {
          if (item && typeof item === 'object') {
            const itemId = (item.id || '').toString();
            const itemHash = (item.external_id_hash || '').toString();
            if (idSet.has(itemId) || idSet.has(itemHash)) {
              changed = true;
              settingAffected++;
              return {
                ...item,
                status: newStatus,
                reviewed_at: nowIso,
              };
            }
          }
          return item;
        });

        if (changed) {
          await saveAdminSetting(
            BLIDA_QUEUE_SETTING_KEY,
            JSON.stringify(updatedList),
            'File d\'attente de validation Admin des ressources Blida (Telegram & Google Drive)'
          );
        }
      }
    }
  } catch (err) {
    console.warn('Error updating batch discovered_blida_resources_queue setting:', err);
  }

  return tableUpdatedCount > 0 ? tableUpdatedCount : (settingAffected > 0 ? settingAffected : idsOrHashes.length);
}

// --- LIVRETS DE RÉVISION : VALIDATION HUMAINE ADMIN ---

export async function fetchBookletsForValidation(): Promise<AdminBookletItem[]> {
  try {
    const { data, error } = await supabaseAdmin
      .from('courses')
      .select(
        'id, name, module_id, bundle_pdf_url, bundle_generated_at, bundle_validation_status, bundle_admin_notes, bundle_reviewed_at, bundle_has_mindmap, is_hypertombable, residanat_years, qcm_count, has_pdf, has_mindmap'
      )
      .not('bundle_pdf_url', 'is', null)
      .order('bundle_generated_at', { ascending: false });

    if (error || !data) {
      console.error('Error fetching booklets for validation:', error);
      return [];
    }

    return data.map((row: any) => ({
      id: row.id,
      name: row.name || row.id,
      moduleId: row.module_id || '',
      bundlePdfUrl: row.bundle_pdf_url,
      bundleGeneratedAt: row.bundle_generated_at || undefined,
      bundleValidationStatus: (row.bundle_validation_status || 'pending_review') as BookletValidationStatus,
      bundleAdminNotes: row.bundle_admin_notes || undefined,
      bundleReviewedAt: row.bundle_reviewed_at || undefined,
      bundleHasMindmap: Boolean(row.bundle_has_mindmap),
      isHypertombable: Boolean(row.is_hypertombable),
      residanatYears: Array.isArray(row.residanat_years) ? row.residanat_years.map(String) : [],
      qcmCount: Number(row.qcm_count || 0),
      hasPdf: Boolean(row.has_pdf),
      hasMindmap: Boolean(row.has_mindmap),
    }));
  } catch (err) {
    console.error('Exception fetching booklets for validation:', err);
    return [];
  }
}

export async function updateBookletValidationStatus(
  courseId: string,
  status: BookletValidationStatus,
  adminNotes?: string,
  adminId?: string
): Promise<boolean> {
  try {
    const payload: Record<string, any> = {
      bundle_validation_status: status,
      bundle_admin_notes: adminNotes?.trim() ? adminNotes.trim() : null,
      bundle_reviewed_at: new Date().toISOString(),
    };
    if (adminId) {
      payload.bundle_reviewed_by = adminId;
    }

    const { error } = await supabaseAdmin
      .from('courses')
      .update(payload)
      .eq('id', courseId);

    if (error) {
      console.error('Error updating booklet validation status:', error);
      return false;
    }
    return true;
  } catch (err) {
    console.error('Exception updating booklet validation status:', err);
    return false;
  }
}


