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
import { BookletsValidationView } from './components/booklets/BookletsValidationView';
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
  supabase,
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

import { 
  BarChart2, 
  Users, 
  CreditCard, 
  Tag, 
  Key, 
  Award, 
  Megaphone, 
  Bot, 
  Menu 
} from 'lucide-react';

export default function App() {
  const [currentTab, setCurrentTab] = useState<NavigationTab>('overview');
  const [isMobileDrawerOpen, setIsMobileDrawerOpen] = useState<boolean>(false);
  const [isDarkMode, setIsDarkMode] = useState<boolean>(() => {
    if (typeof window !== 'undefined') {
      const saved = localStorage.getItem('medsina_theme');
      if (saved) return saved === 'dark';
      return window.matchMedia('(prefers-color-scheme: dark)').matches;
    }
    return false;
  });

  // Collapsible Sidebar State with localStorage persistence & responsive default
  const [isSidebarCollapsed, setIsSidebarCollapsed] = useState<boolean>(() => {
    if (typeof window !== 'undefined') {
      const saved = localStorage.getItem('medsina_sidebar_collapsed');
      if (saved !== null) return saved === 'true';
      // Default collapsed on tablet / smaller screens (< 1280px) to maximize data view
      return window.innerWidth < 1280;
    }
    return false;
  });

  const toggleSidebarCollapsed = useCallback(() => {
    setIsSidebarCollapsed(prev => {
      const next = !prev;
      localStorage.setItem('medsina_sidebar_collapsed', String(next));
      return next;
    });
  }, []);

  // Global keyboard shortcut: Ctrl+B / Cmd+B to toggle sidebar collapse
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'b') {
        e.preventDefault();
        toggleSidebarCollapsed();
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [toggleSidebarCollapsed]);

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

  // Check persistent session on startup & SSO tokens
  useEffect(() => {
    async function initAuth() {
      setIsAuthChecking(true);

      // Handle SSO Token from Medsina Desktop / Mobile App
      try {
        const searchParams = new URLSearchParams(window.location.search);
        const hashParams = new URLSearchParams(window.location.hash.replace(/^#\/?/, ''));
        const token = searchParams.get('token') || searchParams.get('access_token') || hashParams.get('access_token');
        const refreshToken = searchParams.get('refresh_token') || hashParams.get('refresh_token') || '';

        if (token) {
          const { error } = await supabase.auth.setSession({
            access_token: token,
            refresh_token: refreshToken,
          });
          if (!error) {
            // Clean sensitive tokens from URL address bar
            const cleanUrl = window.location.pathname;
            window.history.replaceState({}, document.title, cleanUrl);
          }
        }
      } catch (ssoErr) {
        console.error('SSO initialization error:', ssoErr);
      }

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
    let totalQcmSolved = 0;
    let totalCoursesCompleted = 0;
    let totalStudyHours = 0;
    let onlineNowCount = 0;
    let activeTodayCount = 0;
    const platformCounts = { mobile: 0, windows: 0, web: 0 };

    for (const u of users) {
      const t = (u.tier || 'free').toLowerCase();
      if (t === 'etudiant') etudiant++;
      else if (t === 'clinical_pro') clinicalPro++;
      else if (t === 'resident_elite') residentElite++;
      else if (t === 'all_access') allAccess++;
      else freeTrials++;

      if (u.progress?.totalQcmSolved) totalQcmSolved += u.progress.totalQcmSolved;
      if (u.progress?.totalCoursesCompleted) totalCoursesCompleted += u.progress.totalCoursesCompleted;
      if (u.progress?.totalTimeSpentSeconds) totalStudyHours += (u.progress.totalTimeSpentSeconds / 3600);
      else if (u.telemetry?.connectionCount) totalStudyHours += (u.telemetry.connectionCount * 10 / 60);

      if (u.telemetry?.isOnline) onlineNowCount++;
      if (u.telemetry?.isActiveToday) activeTodayCount++;

      const plats = u.telemetry?.platformsUsed || [];
      if (plats.includes('android') || plats.includes('mobile')) platformCounts.mobile++;
      if (plats.includes('windows')) platformCounts.windows++;
      if (plats.includes('web')) platformCounts.web++;
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
      totalQcmSolved,
      totalCoursesCompleted,
      totalStudyHours: Math.round(totalStudyHours * 10) / 10,
      onlineNowCount,
      activeTodayCount,
      platformCounts,
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

  const handleCreateManualPayment = (newPayment: PaymentItem) => {
    setPayments(prev => [newPayment, ...prev]);
    if (newPayment.status === 'approved') {
      const days = newPayment.durationDays || 365;
      const expiry = new Date(Date.now() + days * 24 * 60 * 60 * 1000).toISOString().slice(0, 10);
      setUsers(currentUsers => currentUsers.map(u => {
        if ((newPayment.userId && u.id === newPayment.userId) || u.email === newPayment.userEmail) {
          return {
            ...u,
            tier: newPayment.tier,
            status: 'active',
            expiresAt: expiry
          };
        }
        return u;
      }));
    }
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
    await toggleAnnouncementInSupabase(id, newStatus);
  };

  // Counts for Badges
  const pendingPaymentsCount = payments.filter(p => p.status === 'pending').length;
  const availableLicensesCount = licenses.filter(l => !l.isRedeemed && !l.isRevoked).length;

  // Mobile navigation tabs
  const mobileNavTabs = [
    { id: 'overview' as NavigationTab, label: 'KPIs', icon: BarChart2 },
    { id: 'users' as NavigationTab, label: 'Médecins', icon: Users, badge: users.length },
    { id: 'payments' as NavigationTab, label: 'Paiements CCP', icon: CreditCard, badge: pendingPaymentsCount > 0 ? pendingPaymentsCount : undefined },
    { id: 'pricing' as NavigationTab, label: 'Tarifs DZD', icon: Tag },
    { id: 'licenses' as NavigationTab, label: 'Licences VIP', icon: Key, badge: availableLicensesCount > 0 ? availableLicensesCount : undefined },
    { id: 'exams' as NavigationTab, label: 'Concours', icon: Award },
    { id: 'announcements' as NavigationTab, label: 'Annonces', icon: Megaphone },
    { id: 'ai_agents' as NavigationTab, label: 'IA GitHub', icon: Bot },
  ];

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
        isMobileDrawerOpen={isMobileDrawerOpen}
        onToggleMobileDrawer={() => setIsMobileDrawerOpen(!isMobileDrawerOpen)}
        onCloseMobileDrawer={() => setIsMobileDrawerOpen(false)}
        totalUsersCount={users.length}
        availableLicensesCount={availableLicensesCount}
        isSidebarCollapsed={isSidebarCollapsed}
        onToggleSidebarCollapse={toggleSidebarCollapsed}
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
          isCollapsed={isSidebarCollapsed}
          onToggleCollapse={toggleSidebarCollapsed}
        />

        {/* Content Viewport */}
        <main className="flex-1 min-w-0 p-4 sm:p-6 lg:p-8 max-w-[1720px] mx-auto w-full overflow-x-hidden pb-28 md:pb-12">
          {/* Mobile Top Horizontal Pill Nav (< md) */}
          <div className="flex md:hidden items-center gap-1.5 overflow-x-auto no-scrollbar pb-2 mb-2 px-0.5 scroll-smooth">
            {mobileNavTabs.map((tab) => {
              const Icon = tab.icon;
              const isActive = currentTab === tab.id;
              return (
                <button
                  key={tab.id}
                  onClick={() => setCurrentTab(tab.id)}
                  className={`whitespace-nowrap px-3 py-1.5 rounded-full text-xs font-medium transition-all shrink-0 cursor-pointer flex items-center gap-1.5 ${
                    isActive
                      ? 'bg-teal-600 text-white dark:bg-teal-500 font-semibold shadow-xs'
                      : 'bg-white dark:bg-slate-900 text-slate-700 dark:text-slate-300 border border-slate-200 dark:border-slate-800'
                  }`}
                >
                  <Icon className="w-3.5 h-3.5" />
                  <span>{tab.label}</span>
                  {tab.badge !== undefined && (
                    <span className={`px-1.5 py-0.2 text-[10px] rounded-full font-mono font-semibold ${
                      isActive 
                        ? 'bg-white/20 text-white' 
                        : 'bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-400'
                    }`}>
                      {tab.badge}
                    </span>
                  )}
                </button>
              );
            })}
          </div>

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
                  users={users}
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
                  users={users}
                  onApprovePayment={handleApprovePayment}
                  onRejectPayment={handleRejectPayment}
                  onArchivePayment={handleArchivePayment}
                  onCreateManualPayment={handleCreateManualPayment}
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

              {currentTab === 'booklets' && (
                <BookletsValidationView adminId={adminUser?.id} />
              )}

              {currentTab === 'ai_agents' && (
                <GitHubAgentsView />
              )}
            </>
          )}
        </main>
      </div>

      {/* Mobile Bottom Dock (Screens < 768px) */}
      <nav 
        aria-label="Navigation mobile principale"
        className="md:hidden fixed bottom-0 left-0 right-0 z-40 bg-white/95 dark:bg-slate-900/95 backdrop-blur-md border-t border-slate-200 dark:border-slate-800 px-2 py-1.5 flex items-center justify-around shadow-lg"
      >
        {/* Tab 1: Overview */}
        <button
          onClick={() => setCurrentTab('overview')}
          className={`flex flex-col items-center justify-center py-1 px-2.5 rounded-lg text-[10px] font-medium transition-colors cursor-pointer ${
            currentTab === 'overview'
              ? 'text-teal-600 dark:text-teal-400 font-bold'
              : 'text-slate-500 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white'
          }`}
        >
          <BarChart2 className="w-5 h-5 mb-0.5" />
          <span>KPIs</span>
        </button>

        {/* Tab 2: Users */}
        <button
          onClick={() => setCurrentTab('users')}
          className={`flex flex-col items-center justify-center py-1 px-2.5 rounded-lg text-[10px] font-medium transition-colors cursor-pointer ${
            currentTab === 'users'
              ? 'text-teal-600 dark:text-teal-400 font-bold'
              : 'text-slate-500 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white'
          }`}
        >
          <Users className="w-5 h-5 mb-0.5" />
          <span>Médecins</span>
        </button>

        {/* Tab 3: Payments with badge */}
        <button
          onClick={() => setCurrentTab('payments')}
          className={`relative flex flex-col items-center justify-center py-1 px-2.5 rounded-lg text-[10px] font-medium transition-colors cursor-pointer ${
            currentTab === 'payments'
              ? 'text-teal-600 dark:text-teal-400 font-bold'
              : 'text-slate-500 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white'
          }`}
        >
          <div className="relative">
            <CreditCard className="w-5 h-5 mb-0.5" />
            {pendingPaymentsCount > 0 && (
              <span className="absolute -top-1 -right-2 px-1.5 py-0.2 bg-amber-500 text-white text-[9px] font-bold rounded-full animate-pulse">
                {pendingPaymentsCount}
              </span>
            )}
          </div>
          <span>Paiements</span>
        </button>

        {/* Tab 4: Licenses */}
        <button
          onClick={() => setCurrentTab('licenses')}
          className={`flex flex-col items-center justify-center py-1 px-2.5 rounded-lg text-[10px] font-medium transition-colors cursor-pointer ${
            currentTab === 'licenses'
              ? 'text-teal-600 dark:text-teal-400 font-bold'
              : 'text-slate-500 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white'
          }`}
        >
          <Key className="w-5 h-5 mb-0.5" />
          <span>Licences</span>
        </button>

        {/* Tab 5: Menu Drawer */}
        <button
          onClick={() => setIsMobileDrawerOpen(true)}
          className="flex flex-col items-center justify-center py-1 px-2.5 rounded-lg text-[10px] font-medium text-slate-500 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white cursor-pointer"
        >
          <Menu className="w-5 h-5 mb-0.5" />
          <span>Menu</span>
        </button>
      </nav>
    </div>
  );
}
