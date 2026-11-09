import React, { useState, useEffect, useCallback, useMemo } from 'react';
import { Header } from './components/layout/Header';
import { Sidebar } from './components/layout/Sidebar';
import { OverviewView } from './components/dashboard/OverviewView';
import { UsersView } from './components/users/UsersView';
import { PaymentsView } from './components/payments/PaymentsView';
import { PricingPlansView } from './components/pricing/PricingPlansView';
import { LicensesView } from './components/licenses/LicensesView';
import { NationalExamsView } from './components/exams/NationalExamsView';
import { AnnouncementsView } from './components/announcements/AnnouncementsView';
import { GitHubAgentsView } from './components/agents/GitHubAgentsView';
import { LoginView } from './components/auth/LoginView';

import { 
  NavigationTab, 
  AdminUserItem, 
  PaymentItem, 
  PricingPlan, 
  AdminLicenseItem, 
  NationalExamModel, 
  AnnouncementItem, 
  AdminFacebookPrompt,
  SubscriptionTier,
  FinancialMetrics,
  AdminMetrics
} from './types/medsina';

import { INITIAL_FACEBOOK_PROMPTS } from './data/mockData';

import {
  getCurrentAdminSession,
  signOutAdmin,
  AdminAuthProfile,
  fetchRealUsers,
  fetchRealPayments,
  fetchRealLicenses,
  fetchRealPricingPlans,
  fetchRealAnnouncements,
  fetchRealNationalExams,
  fetchOcteniumStats,
  approvePaymentInSupabase,
  rejectPaymentInSupabase,
  updateUserProfileInSupabase,
  banUserInSupabase,
  unbanUserInSupabase,
  generateLicenseKeysInSupabase,
  revokeLicenseInSupabase,
  updatePlanPriceInSupabase,
  createAnnouncementInSupabase,
  toggleAnnouncementInSupabase,
  createNationalExamInSupabase
} from './services/supabase';

export default function App() {
  const [currentTab, setCurrentTab] = useState<NavigationTab>('overview');
  const [isDarkMode, setIsDarkMode] = useState<boolean>(() => {
    if (typeof window !== 'undefined') {
      const saved = localStorage.getItem('medsina_theme');
      if (saved) return saved === 'dark';
      return window.matchMedia('(prefers-color-scheme: dark)').matches;
    }
    return false;
  });

  // Authentication State
  const [adminUser, setAdminUser] = useState<AdminAuthProfile | null>(null);
  const [isAuthChecking, setIsAuthChecking] = useState<boolean>(true);

  // Live Medsina Data State
  const [isLoadingData, setIsLoadingData] = useState<boolean>(false);
  const [isRefreshing, setIsRefreshing] = useState<boolean>(false);
  const [users, setUsers] = useState<AdminUserItem[]>([]);
  const [payments, setPayments] = useState<PaymentItem[]>([]);
  const [pricingPlans, setPricingPlans] = useState<PricingPlan[]>([]);
  const [licenses, setLicenses] = useState<AdminLicenseItem[]>([]);
  const [exams, setExams] = useState<NationalExamModel[]>([]);
  const [announcements, setAnnouncements] = useState<AnnouncementItem[]>([]);
  const [facebookPrompts] = useState<AdminFacebookPrompt[]>(INITIAL_FACEBOOK_PROMPTS);
  const [octeniumStats, setOcteniumStats] = useState<{
    total: number;
    apk: number;
    windows: number;
    web: number;
    lastDownloadAt?: string;
    recentDownloads?: any[];
  }>({
    total: 83,
    apk: 62,
    windows: 21,
    web: 0,
    lastDownloadAt: '2026-11-09T08:14:51.096Z',
    recentDownloads: []
  });

  // Synchronize Dark Mode on <html> root
  useEffect(() => {
    if (isDarkMode) {
      document.documentElement.classList.add('dark');
      localStorage.setItem('medsina_theme', 'dark');
    } else {
      document.documentElement.classList.remove('dark');
      localStorage.setItem('medsina_theme', 'light');
    }
  }, [isDarkMode]);

  // Check persistent session on startup
  useEffect(() => {
    async function initAuth() {
      setIsAuthChecking(true);
      const { user } = await getCurrentAdminSession();
      if (user) {
        setAdminUser(user);
      }
      setIsAuthChecking(false);
    }
    initAuth();
  }, []);

  // Fetch all real Medsina data from Supabase
  const loadAllRealData = useCallback(async (isRefresh = false) => {
    if (isRefresh) setIsRefreshing(true);
    else setIsLoadingData(true);

    try {
      const [
        realUsers,
        realPayments,
        realLicenses,
        realPlans,
        realAnnouncements,
        realExams,
        realOctenium
      ] = await Promise.all([
        fetchRealUsers(),
        fetchRealPayments(),
        fetchRealLicenses(),
        fetchRealPricingPlans(),
        fetchRealAnnouncements(),
        fetchRealNationalExams(),
        fetchOcteniumStats()
      ]);

      setUsers(realUsers);
      setPayments(realPayments);
      setLicenses(realLicenses);
      setPricingPlans(realPlans);
      setAnnouncements(realAnnouncements);
      setExams(realExams);
      setOcteniumStats(realOctenium);
    } catch (err) {
      console.error('Error loading real Medsina data:', err);
    } finally {
      setIsLoadingData(false);
      setIsRefreshing(false);
    }
  }, []);

  // Load data as soon as admin logs in
  useEffect(() => {
    if (adminUser) {
      loadAllRealData();
    }
  }, [adminUser, loadAllRealData]);

  // Handle Logout
  const handleSignOut = async () => {
    await signOutAdmin();
    setAdminUser(null);
  };

  // Compute live Financial Metrics from real payments
  const financialMetrics: FinancialMetrics = useMemo(() => {
    let total = 0;
    let pending = 0;
    let approved = 0;
    let pend = 0;
    let rej = 0;

    for (const p of payments) {
      if (p.status === 'approved') {
        total += p.amount;
        approved++;
      } else if (p.status === 'pending') {
        pending += p.amount;
        pend++;
      } else if (p.status === 'rejected') {
        rej++;
      }
    }

    return {
      totalRevenue: total,
      pendingRevenue: pending,
      totalTransactions: payments.length,
      approvedCount: approved,
      pendingCount: pend,
      rejectedCount: rej,
    };
  }, [payments]);

  // Compute live Admin Metrics from real data
  const metrics: AdminMetrics = useMemo(() => {
    let freeTrials = 0;
    let etudiant = 0;
    let clinicalPro = 0;
    let residentElite = 0;
    let allAccess = 0;

    for (const u of users) {
      const t = (u.tier || 'free').toLowerCase();
      if (t === 'etudiant') etudiant++;
      else if (t === 'clinical_pro') clinicalPro++;
      else if (t === 'resident_elite') residentElite++;
      else if (t === 'all_access') allAccess++;
      else freeTrials++;
    }

    const totalLicenses = licenses.length;
    const redeemedLicenses = licenses.filter(l => l.isRedeemed).length;
    const availableLicenses = licenses.filter(l => !l.isRedeemed && !l.isRevoked).length;

    return {
      totalUsers: users.length,
      freeTrials,
      etudiant,
      clinicalPro,
      residentElite,
      allAccess,
      totalLicenses,
      redeemedLicenses,
      availableLicenses,
      octeniumTotalDownloads: octeniumStats.total,
      octeniumApkDownloads: octeniumStats.apk,
      octeniumWindowsDownloads: octeniumStats.windows,
      octeniumWebVisits: octeniumStats.web,
      octeniumLastDownloadAt: octeniumStats.lastDownloadAt,
    };
  }, [users, licenses, octeniumStats]);

  // --- ACTIONS & MUTATIONS ---

  const handleApprovePayment = async (paymentId: string, bonusCredits: number, adminNotes?: string) => {
    const payment = payments.find(p => p.id === paymentId);
    if (!payment) return;

    // Optimistic UI update
    setPayments(prev => prev.map(p => {
      if (p.id === paymentId) {
        return {
          ...p,
          status: 'approved' as const,
          bonusCredits,
          adminNotes: adminNotes || 'Validé par l\'administrateur sur console Octenium'
        };
      }
      return p;
    }));

    if (payment.userId) {
      setUsers(currentUsers => currentUsers.map(u => {
        if (u.id === payment.userId || u.email === payment.userEmail) {
          const currentExp = u.expiresAt ? new Date(u.expiresAt) : new Date();
          const newExp = new Date(currentExp.getTime() + payment.durationDays * 24 * 60 * 60 * 1000);
          return {
            ...u,
            tier: payment.tier,
            status: 'active' as const,
            expiresAt: newExp.toISOString().slice(0, 10)
          };
        }
        return u;
      }));
    }

    // Persist to Supabase
    await approvePaymentInSupabase(
      paymentId, 
      payment.userId, 
      payment.tier, 
      payment.durationDays, 
      adminNotes
    );
  };

  const handleRejectPayment = async (paymentId: string, reason: string) => {
    const payment = payments.find(p => p.id === paymentId);
    if (!payment) return;

    setPayments(prev => prev.map(p => {
      if (p.id === paymentId) {
        return {
          ...p,
          status: 'rejected' as const,
          adminNotes: reason
        };
      }
      return p;
    }));

    if (payment.userId) {
      setUsers(currentUsers => currentUsers.map(u => {
        if (u.id === payment.userId || u.email === payment.userEmail) {
          return {
            ...u,
            rejectedPaymentsCount: (u.rejectedPaymentsCount || 0) + 1
          };
        }
        return u;
      }));
    }

    // Persist to Supabase
    await rejectPaymentInSupabase(paymentId, reason);
  };

  const handleArchivePayment = (paymentId: string) => {
    setPayments(prev => prev.map(p => {
      if (p.id === paymentId) {
        return {
          ...p,
          isArchived: true,
          archiveDriveUrl: 'https://drive.google.com/drive/folders/medsina-receipts-2026',
          archiveDriveFolder: 'Medsina_Paiements_2026',
          archivedAt: new Date().toISOString()
        };
      }
      return p;
    }));
  };

  // User Actions
  const handleUpdateUser = async (updatedUser: AdminUserItem) => {
    setUsers(prev => prev.map(u => u.id === updatedUser.id ? updatedUser : u));
    await updateUserProfileInSupabase(updatedUser.id, updatedUser);
  };

  // Pricing Plan Actions
  const handleUpdatePlan = async (updatedPlan: PricingPlan) => {
    setPricingPlans(prev => prev.map(pl => pl.id === updatedPlan.id ? updatedPlan : pl));
    await updatePlanPriceInSupabase(updatedPlan);
  };

  // License Actions
  const handleGenerateLicenses = async (tier: SubscriptionTier, durationDays: number, count: number, prefix: string) => {
    const created = await generateLicenseKeysInSupabase(tier, durationDays, count, prefix);
    if (created.length > 0) {
      setLicenses(prev => [...created, ...prev]);
    }
  };

  const handleRevokeLicense = async (keyCode: string, reason: string) => {
    setLicenses(prev => prev.map(l => {
      if (l.keyCode === keyCode) {
        return {
          ...l,
          isRevoked: true,
          revokedAt: new Date().toISOString().slice(0, 10),
          revocationReason: reason
        };
      }
      return l;
    }));
    await revokeLicenseInSupabase(keyCode, reason);
  };

  // Exam Actions
  const handleCreateExam = async (newExam: NationalExamModel) => {
    setExams(prev => [newExam, ...prev]);
    await createNationalExamInSupabase(newExam);
  };

  // Announcement Actions
  const handleAddAnnouncement = async (newAnn: AnnouncementItem) => {
    setAnnouncements(prev => [newAnn, ...prev]);
    await createAnnouncementInSupabase(newAnn);
  };

  const handleToggleAnnouncement = async (id: string) => {
    const current = announcements.find(a => a.id === id);
    const newStatus = !current?.isActive;
    setAnnouncements(prev => prev.map(a => a.id === id ? { ...a, isActive: newStatus } : a));
    await toggleAnnouncementInSupabase(id, !newStatus);
  };

  // Counts for Badges
  const pendingPaymentsCount = payments.filter(p => p.status === 'pending').length;
  const availableLicensesCount = licenses.filter(l => !l.isRedeemed && !l.isRevoked).length;

  // 1. Loading Splash
  if (isAuthChecking) {
    return (
      <div className="min-h-screen bg-slate-950 flex flex-col items-center justify-center text-white">
        <div className="w-10 h-10 border-3 border-teal-500 border-t-transparent rounded-full animate-spin mb-4" />
        <p className="text-sm font-medium text-slate-300">Vérification des privilèges Medsina...</p>
      </div>
    );
  }

  // 2. Unauthenticated -> Show Login Screen
  if (!adminUser) {
    return <LoginView onLoginSuccess={setAdminUser} />;
  }

  // 3. Authenticated -> Full Dashboard
  return (
    <div className="min-h-screen bg-slate-100/70 dark:bg-slate-950 text-slate-900 dark:text-slate-100 flex flex-col font-sans transition-colors selection:bg-teal-500 selection:text-white">
      {/* Top Header */}
      <Header
        currentTab={currentTab}
        onTabChange={setCurrentTab}
        isDarkMode={isDarkMode}
        onToggleDarkMode={() => setIsDarkMode(!isDarkMode)}
        pendingPaymentsCount={pendingPaymentsCount}
        onQuickAction={() => setCurrentTab('exams')}
        adminUser={adminUser}
        onSignOut={handleSignOut}
        onRefresh={() => loadAllRealData(true)}
        isRefreshing={isRefreshing}
      />

      {/* Main Layout */}
      <div className="flex-1 flex w-full">
        {/* Sidebar Navigation */}
        <Sidebar
          currentTab={currentTab}
          onTabChange={setCurrentTab}
          pendingPaymentsCount={pendingPaymentsCount}
          availableLicensesCount={availableLicensesCount}
          totalUsersCount={users.length}
        />

        {/* Content Viewport */}
        <main className="flex-1 p-4 md:p-6 lg:p-8 max-w-7xl mx-auto w-full overflow-x-hidden">
          {isLoadingData ? (
            <div className="flex flex-col items-center justify-center py-24 text-slate-500 dark:text-slate-400">
              <div className="w-8 h-8 border-3 border-teal-500 border-t-transparent rounded-full animate-spin mb-3" />
              <p className="text-sm">Chargement des données réelles Medsina...</p>
            </div>
          ) : (
            <>
              {currentTab === 'overview' && (
                <OverviewView
                  metrics={metrics}
                  financialMetrics={financialMetrics}
                  recentPayments={payments.slice(0, 5)}
                  upcomingExams={exams}
                  onNavigate={setCurrentTab}
                  onSelectPayment={() => setCurrentTab('payments')}
                />
              )}

              {currentTab === 'users' && (
                <UsersView
                  users={users}
                  payments={payments}
                  licenses={licenses}
                  onUpdateUser={handleUpdateUser}
                />
              )}

              {currentTab === 'payments' && (
                <PaymentsView
                  payments={payments}
                  financialMetrics={financialMetrics}
                  onApprovePayment={handleApprovePayment}
                  onRejectPayment={handleRejectPayment}
                  onArchivePayment={handleArchivePayment}
                />
              )}

              {currentTab === 'pricing' && (
                <PricingPlansView
                  plans={pricingPlans}
                  onUpdatePlan={handleUpdatePlan}
                />
              )}

              {currentTab === 'licenses' && (
                <LicensesView
                  licenses={licenses}
                  onGenerateLicenses={handleGenerateLicenses}
                  onRevokeLicense={handleRevokeLicense}
                />
              )}

              {currentTab === 'exams' && (
                <NationalExamsView
                  exams={exams}
                  onCreateExam={handleCreateExam}
                />
              )}

              {currentTab === 'announcements' && (
                <AnnouncementsView
                  announcements={announcements}
                  facebookPrompts={facebookPrompts}
                  onAddAnnouncement={handleAddAnnouncement}
                  onToggleAnnouncement={handleToggleAnnouncement}
                />
              )}

              {currentTab === 'ai_agents' && (
                <GitHubAgentsView />
              )}
            </>
          )}
        </main>
      </div>
    </div>
  );
}
