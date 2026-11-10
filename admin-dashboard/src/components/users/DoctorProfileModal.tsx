import React, { useState, useEffect } from 'react';
import {
  X,
  User,
  ShieldCheck,
  Ban,
  Calendar,
  Phone,
  Mail,
  GraduationCap,
  CreditCard,
  Key,
  CheckCircle2,
  AlertTriangle,
  ExternalLink,
  Edit2,
  Save,
  Clock,
  Sparkles,
  Smartphone,
  Monitor,
  Globe,
  Copy,
  BookOpen,
  ListChecks,
  Award,
  Flame,
  Activity,
  MapPin,
  FileText,
  HelpCircle,
  TrendingUp,
  RefreshCw,
  Search,
  Lock,
  Unlock,
  ChevronRight
} from 'lucide-react';
import { 
  AdminUserItem, 
  DoctorFullProfileDetails, 
  SubscriptionTier, 
  PaymentItem, 
  AdminLicenseItem, 
  MedicalRole 
} from '../../types/medsina';
import { 
  fetchDoctorFullProfileDetails, 
  updateUserProfileInSupabase, 
  updateDoctorAcademicLevel,
  resolveStudyYear, 
  cleanMedicalRole, 
  formatStudyYearDisplay 
} from '../../services/supabase';

interface DoctorProfileModalProps {
  user: AdminUserItem;
  payments: PaymentItem[];
  licenses: AdminLicenseItem[];
  onClose: () => void;
  onUpdateUser: (updatedUser: AdminUserItem) => void;
  initialTab?: 'identity' | 'progress' | 'telemetry' | 'subscription' | 'payments' | 'licenses';
}

export const DoctorProfileModal: React.FC<DoctorProfileModalProps> = ({
  user,
  payments: globalPayments,
  licenses: globalLicenses,
  onClose,
  onUpdateUser,
  initialTab = 'identity'
}) => {
  const [detailsTab, setDetailsTab] = useState<'identity' | 'progress' | 'telemetry' | 'subscription' | 'payments' | 'licenses'>(initialTab);
  const [isLoading, setIsLoading] = useState<boolean>(true);
  const [deepDetails, setDeepDetails] = useState<DoctorFullProfileDetails | null>(null);
  const [copyFeedback, setCopyFeedback] = useState<string | null>(null);

  // Edit Study Year modal state
  const [showEditStudyYearModal, setShowEditStudyYearModal] = useState<boolean>(false);
  const [selectedStudyYearInput, setSelectedStudyYearInput] = useState<number | null>(null);
  const [isSavingStudyYear, setIsSavingStudyYear] = useState<boolean>(false);

  // Edit Profile modal state
  const [showEditProfileModal, setShowEditProfileModal] = useState<boolean>(false);
  const [editFullName, setEditFullName] = useState<string>('');
  const [editMedicalRole, setEditMedicalRole] = useState<string>('');
  const [editFaculty, setEditFaculty] = useState<string>('');
  const [editStudyYear, setEditStudyYear] = useState<number | null>(null);
  const [editWilaya, setEditWilaya] = useState<string>('');
  const [editPhone, setEditPhone] = useState<string>('');
  const [editResidencyYear, setEditResidencyYear] = useState<string>('');
  const [editBio, setEditBio] = useState<string>('');
  const [isSavingProfile, setIsSavingProfile] = useState<boolean>(false);

  // Ban/Unban modal state
  const [showBanModal, setShowBanModal] = useState<boolean>(false);
  const [banReasonInput, setBanReasonInput] = useState<string>('');
  const [isTogglingBan, setIsTogglingBan] = useState<boolean>(false);

  // Receipt preview modal state
  const [receiptPreviewUrl, setReceiptPreviewUrl] = useState<string | null>(null);

  // Fetch complete 360° deep details from Supabase on open
  useEffect(() => {
    let isMounted = true;
    async function loadData() {
      setIsLoading(true);
      try {
        const details = await fetchDoctorFullProfileDetails(user.id, user.email);
        if (isMounted) {
          setDeepDetails(details);
          setIsLoading(false);
        }
      } catch (err) {
        console.error('Error fetching deep profile details:', err);
        if (isMounted) setIsLoading(false);
      }
    }
    loadData();
    return () => {
      isMounted = false;
    };
  }, [user.id, user.email]);

  const activeUser = deepDetails?.profile || user;
  const activeProfile = deepDetails?.profile || user;
  const activeSub = deepDetails?.subscription;
  const activePayments = deepDetails?.payments || globalPayments.filter(p => p.userId === user.id || p.userEmail === user.email);
  const activeLicenses = deepDetails?.licenseKeys || globalLicenses.filter(l => l.redeemedBy === user.id || l.redeemedUserEmail === user.email);
  const activeProgress = deepDetails?.progress || user.progress || {
    totalQcmSolved: 0,
    todayQcmSolved: 0,
    totalCoursesCompleted: 0,
    todayCoursesCompleted: 0,
    completedCourseIds: [],
    averageAccuracy: 0,
    dailyQcmGoal: 25,
    dailyCourseGoal: 1,
    specialtyBreakdown: {},
    totalTimeSpentSeconds: 0,
  };
  const activeTelemetry = deepDetails?.telemetry || user.telemetry || {
    connectionCount: 1,
    streakDays: 1,
    maxStreakDays: 1,
    loyaltyPoints: 10,
    loyaltyLevel: 'Externe Studieux',
    activeDaysHistory: [],
    platformsUsed: ['android'],
    primaryPlatform: 'android',
    isOnline: false,
    isActiveToday: false,
  };

  const resolvedStudyYear = resolveStudyYear(activeProfile, activeUser);
  const resolvedMedicalRole = cleanMedicalRole(activeProfile.medicalRole || activeUser.medicalRole || 'Médecin Généraliste', resolvedStudyYear);
  const studyYearDisplay = formatStudyYearDisplay(resolvedStudyYear, resolvedMedicalRole);

  const rawDoctorName = (activeProfile.fullName || activeUser.fullName || activeUser.email.split('@')[0]).trim();
  const displayDoctorName = rawDoctorName.toLowerCase().startsWith('dr') ? rawDoctorName : `Dr. ${rawDoctorName}`;
  const referralCode = activeProfile.referralCode || `DR-${activeUser.id.substring(0, 6).toUpperCase()}`;

  const effectiveExpiry = activeSub?.expires_at || activeUser.expiresAt;
  const isExpired = effectiveExpiry ? new Date(effectiveExpiry).getTime() < Date.now() : false;
  const daysRemaining = effectiveExpiry ? Math.max(0, Math.ceil((new Date(effectiveExpiry).getTime() - Date.now()) / (1000 * 60 * 60 * 24))) : null;

  const copyToClipboard = (text: string, label: string) => {
    navigator.clipboard.writeText(text);
    setCopyFeedback(`${label} copié !`);
    setTimeout(() => setCopyFeedback(null), 2500);
  };

  const getTierBadge = (tier: SubscriptionTier) => {
    switch (tier) {
      case 'all_access':
        return { label: 'All-Access VIP', bg: 'bg-amber-100 text-amber-800 dark:bg-amber-950/80 dark:text-amber-300 border-amber-300 dark:border-amber-800' };
      case 'resident_elite':
        return { label: 'Pass Résident Élite', bg: 'bg-purple-100 text-purple-800 dark:bg-purple-950/80 dark:text-purple-300 border-purple-300 dark:border-purple-800' };
      case 'clinical_pro':
        return { label: 'Pass Clinique Pro', bg: 'bg-sky-100 text-sky-800 dark:bg-sky-950/80 dark:text-sky-300 border-sky-300 dark:border-sky-800' };
      case 'etudiant':
        return { label: 'Pass Étudiant Cursus', bg: 'bg-blue-100 text-blue-800 dark:bg-blue-950/80 dark:text-blue-300 border-blue-300 dark:border-blue-800' };
      default:
        return { label: 'Pass Découverte (Gratuit)', bg: 'bg-slate-100 text-slate-700 dark:bg-slate-800 dark:text-slate-400 border-slate-300 dark:border-slate-700' };
    }
  };

  const handleOpenEditStudyYear = () => {
    setSelectedStudyYearInput(resolvedStudyYear);
    setShowEditStudyYearModal(true);
  };

  const handleSaveStudyYear = async () => {
    setIsSavingStudyYear(true);
    const newRole = selectedStudyYearInput !== null
      ? `Étudiant (${selectedStudyYearInput}${selectedStudyYearInput === 1 ? 'ère' : 'ème'} Année)`
      : (activeUser.medicalRole.toLowerCase().includes('étudiant') ? 'Médecin Généraliste' : activeUser.medicalRole);

    const ok = await updateDoctorAcademicLevel(activeUser.id, selectedStudyYearInput, newRole);
    setIsSavingStudyYear(false);
    setShowEditStudyYearModal(false);

    if (ok) {
      const updated: AdminUserItem = {
        ...activeUser,
        studyYear: selectedStudyYearInput ?? undefined,
        medicalRole: newRole
      };
      onUpdateUser(updated);
      if (deepDetails) {
        setDeepDetails({
          ...deepDetails,
          profile: updated
        });
      }
    }
  };

  const handleOpenEditProfile = () => {
    setEditFullName(activeProfile.fullName || '');
    setEditMedicalRole(activeProfile.medicalRole || '');
    setEditFaculty(activeProfile.faculty || '');
    setEditStudyYear(resolvedStudyYear);
    setEditWilaya(activeProfile.wilaya || '');
    setEditPhone(activeProfile.phone || '');
    setEditResidencyYear(activeProfile.residencyTargetYear || '');
    setEditBio(activeProfile.bio || '');
    setShowEditProfileModal(true);
  };

  const handleSaveProfile = async () => {
    setIsSavingProfile(true);
    const ok = await updateUserProfileInSupabase(activeUser.id, {
      fullName: editFullName,
      medicalRole: editMedicalRole,
      faculty: editFaculty,
      studyYear: editStudyYear ?? undefined,
      wilaya: editWilaya || undefined,
      phone: editPhone || undefined,
      residencyTargetYear: editResidencyYear || undefined,
      bio: editBio || undefined,
    });
    setIsSavingProfile(false);
    setShowEditProfileModal(false);

    if (ok) {
      const updated: AdminUserItem = {
        ...activeUser,
        fullName: editFullName,
        medicalRole: editMedicalRole,
        faculty: editFaculty,
        studyYear: editStudyYear ?? undefined,
        wilaya: editWilaya || undefined,
        phone: editPhone || undefined,
        residencyTargetYear: editResidencyYear || undefined,
        bio: editBio || undefined,
      };
      onUpdateUser(updated);
      if (deepDetails) {
        setDeepDetails({
          ...deepDetails,
          profile: updated
        });
      }
    }
  };

  const handleChangeTier = async (newTier: SubscriptionTier) => {
    const ok = await updateUserProfileInSupabase(activeUser.id, {
      tier: newTier,
      status: 'active'
    });
    if (ok) {
      const updated: AdminUserItem = {
        ...activeUser,
        tier: newTier,
        status: 'active'
      };
      onUpdateUser(updated);
      if (deepDetails) {
        setDeepDetails({
          ...deepDetails,
          profile: updated,
          subscription: {
            ...deepDetails.subscription,
            tier: newTier,
            status: 'active'
          }
        });
      }
    }
  };

  const handleExtendSubscription = async (daysToAdd: number) => {
    const currentBase = effectiveExpiry ? new Date(effectiveExpiry) : new Date();
    const newDate = new Date(Math.max(Date.now(), currentBase.getTime()) + daysToAdd * 86400000);
    const dateStr = newDate.toISOString();

    const ok = await updateUserProfileInSupabase(activeUser.id, {
      expiresAt: dateStr,
      status: 'active'
    });

    if (ok) {
      const updated: AdminUserItem = {
        ...activeUser,
        expiresAt: dateStr,
        status: 'active'
      };
      onUpdateUser(updated);
      if (deepDetails) {
        setDeepDetails({
          ...deepDetails,
          profile: updated,
          subscription: {
            ...deepDetails.subscription,
            tier: deepDetails.subscription?.tier || activeUser.tier,
            status: 'active',
            expires_at: dateStr
          }
        });
      }
    }
  };

  const handleToggleBan = async () => {
    setIsTogglingBan(true);
    const newBannedState = !activeUser.isBanned;
    const updates: Partial<AdminUserItem> = {
      isBanned: newBannedState,
      status: newBannedState ? 'suspended' : 'active',
      banReason: newBannedState ? (banReasonInput || 'Non-respect des conditions d\'utilisation') : undefined,
    };

    const ok = await updateUserProfileInSupabase(activeUser.id, updates);
    setIsTogglingBan(false);
    setShowBanModal(false);

    if (ok) {
      const updated: AdminUserItem = {
        ...activeUser,
        ...updates
      };
      onUpdateUser(updated);
      if (deepDetails) {
        setDeepDetails({
          ...deepDetails,
          profile: updated
        });
      }
    }
  };

  const formatSecondsToHours = (totalSec: number) => {
    if (!totalSec || totalSec <= 0) return '0 min';
    const hours = Math.floor(totalSec / 3600);
    const minutes = Math.floor((totalSec % 3600) / 60);
    if (hours === 0) return `${minutes} min`;
    return `${hours}h ${minutes}m`;
  };

  const formatRelativeTime = (isoString?: string) => {
    if (!isoString) return 'Inconnue';
    try {
      const ms = Date.now() - new Date(isoString).getTime();
      if (ms < 0) return 'À l\'instant';
      const mins = Math.floor(ms / (1000 * 60));
      if (mins < 2) return 'À l\'instant';
      if (mins < 60) return `Il y a ${mins} min`;
      const hours = Math.floor(mins / 60);
      if (hours < 24) return `Il y a ${hours}h`;
      const days = Math.floor(hours / 24);
      if (days < 30) return `Il y a ${days}j`;
      return new Date(isoString).toLocaleDateString('fr-FR', { day: '2-digit', month: 'short' });
    } catch {
      return isoString;
    }
  };

  const tierBadge = getTierBadge(activeUser.tier);

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-5 bg-black/60 backdrop-blur-xs animate-in fade-in duration-150">
      <div 
        className="w-full max-w-4xl max-h-[92vh] flex flex-col bg-white dark:bg-slate-900 rounded-2xl border border-slate-200 dark:border-slate-800 shadow-2xl overflow-hidden"
        onClick={(e) => e.stopPropagation()}
      >
        {/* --- HEADER: DOCTOR IDENTITY & STATUS --- */}
        <div className="p-4 sm:p-5 bg-slate-50/90 dark:bg-slate-800/80 border-b border-slate-200 dark:border-slate-800 shrink-0">
          <div className="flex items-start justify-between gap-3">
            <div className="flex items-start gap-3 sm:gap-4 min-w-0">
              {/* Doctor Avatar with Real-Time Online Status Ring */}
              <div className="relative shrink-0">
                <div className="w-14 h-14 sm:w-16 sm:h-16 rounded-2xl bg-teal-500/10 border-2 border-teal-500/30 flex items-center justify-center text-teal-700 dark:text-teal-300 font-bold text-xl uppercase overflow-hidden shadow-xs">
                  {activeUser.avatarUrl ? (
                    <img src={activeUser.avatarUrl} alt="" className="w-full h-full object-cover" />
                  ) : (
                    <span>{rawDoctorName.slice(0, 2).toUpperCase()}</span>
                  )}
                </div>
                {/* Status Dot */}
                <div 
                  className={`absolute -bottom-1 -right-1 w-4 h-4 rounded-full border-2 border-white dark:border-slate-900 flex items-center justify-center ${
                    activeUser.isBanned 
                      ? 'bg-rose-600' 
                      : (activeTelemetry.isOnline ? 'bg-emerald-500 animate-pulse' : (activeTelemetry.isActiveToday ? 'bg-amber-500' : 'bg-slate-400'))
                  }`}
                  title={
                    activeUser.isBanned
                      ? 'Compte suspendu'
                      : (activeTelemetry.isOnline ? 'En ligne maintenant' : (activeTelemetry.isActiveToday ? 'Actif aujourd\'hui' : 'Hors-ligne'))
                  }
                />
              </div>

              {/* Doctor Credentials */}
              <div className="min-w-0 space-y-1">
                <div className="flex flex-wrap items-center gap-2">
                  <h2 className="text-base sm:text-lg font-bold text-slate-900 dark:text-white truncate">
                    {displayDoctorName}
                  </h2>
                  <span className={`px-2 py-0.5 text-[10.5px] font-bold rounded-md border uppercase tracking-wide ${tierBadge.bg}`}>
                    {tierBadge.label}
                  </span>
                  {activeTelemetry.isOnline && (
                    <span className="flex items-center gap-1 px-2 py-0.5 text-[10px] font-bold bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 border border-emerald-500/30 rounded-md">
                      <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-ping" />
                      En ligne
                    </span>
                  )}
                  {activeUser.isAdmin && (
                    <span className="px-2 py-0.5 text-[10px] font-bold bg-purple-50 text-purple-700 dark:bg-purple-950 dark:text-purple-300 border border-purple-200 dark:border-purple-800 rounded-md">
                      👑 Admin
                    </span>
                  )}
                </div>

                <p className="text-xs text-slate-600 dark:text-slate-300 font-medium truncate">
                  {resolvedMedicalRole} • {activeUser.faculty}
                </p>

                {/* Identification & Fast Copy Chips */}
                <div className="flex flex-wrap items-center gap-2 text-[11px] text-slate-500 dark:text-slate-400 pt-0.5">
                  <button
                    onClick={() => copyToClipboard(activeUser.email, 'Email')}
                    className="flex items-center gap-1 hover:text-teal-600 dark:hover:text-teal-400 cursor-pointer"
                    title="Copier l'email"
                  >
                    <Mail className="w-3 h-3 text-slate-400" />
                    <span className="truncate max-w-[180px] sm:max-w-none">{activeUser.email}</span>
                    <Copy className="w-2.5 h-2.5 opacity-60" />
                  </button>
                  <span className="text-slate-300 dark:text-slate-700">|</span>
                  <button
                    onClick={() => copyToClipboard(activeUser.id, 'UUID')}
                    className="flex items-center gap-1 font-mono hover:text-teal-600 dark:hover:text-teal-400 cursor-pointer"
                    title="Copier l'identifiant UUID"
                  >
                    <span>ID: {activeUser.id.substring(0, 8)}...</span>
                    <Copy className="w-2.5 h-2.5 opacity-60" />
                  </button>
                  <span className="text-slate-300 dark:text-slate-700">|</span>
                  <button
                    onClick={() => copyToClipboard(referralCode, 'Code Parrainage')}
                    className="flex items-center gap-1 font-mono font-bold text-teal-600 dark:text-teal-400 cursor-pointer"
                    title="Copier le code parrainage"
                  >
                    <span>{referralCode}</span>
                    <Copy className="w-2.5 h-2.5 opacity-60" />
                  </button>
                </div>
              </div>
            </div>

            {/* Close Button */}
            <button
              onClick={onClose}
              className="p-1.5 text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 hover:bg-slate-200/50 dark:hover:bg-slate-700/50 rounded-lg cursor-pointer transition-colors"
            >
              <X className="w-5 h-5" />
            </button>
          </div>

          {/* Feedback Toast */}
          {copyFeedback && (
            <div className="mt-2 text-xs font-semibold text-emerald-600 dark:text-emerald-400 bg-emerald-50 dark:bg-emerald-950/60 px-2.5 py-1 rounded-md border border-emerald-200 dark:border-emerald-800 animate-in fade-in duration-100 flex items-center gap-1.5">
              <CheckCircle2 className="w-3.5 h-3.5" />
              <span>{copyFeedback}</span>
            </div>
          )}

          {/* Warning Banners */}
          {activeUser.isBanned && (
            <div className="mt-3 p-2.5 bg-rose-50 dark:bg-rose-950/40 border border-rose-200 dark:border-rose-900 rounded-lg flex items-center justify-between text-xs text-rose-800 dark:text-rose-200">
              <div className="flex items-center gap-2">
                <Ban className="w-4 h-4 text-rose-600 shrink-0" />
                <span><strong>COMPTE SUSPENDU :</strong> {activeUser.banReason || 'Motif administratif'}</span>
              </div>
              <button
                onClick={() => setShowBanModal(true)}
                className="underline font-bold hover:text-rose-900 cursor-pointer text-[11px]"
              >
                Débloquer
              </button>
            </div>
          )}

          {activeUser.rejectedPaymentsCount > 0 && !activeUser.isBanned && (
            <div className="mt-2.5 p-2 bg-amber-50 dark:bg-amber-950/40 border border-amber-200 dark:border-amber-900/60 rounded-lg flex items-center gap-2 text-xs text-amber-800 dark:text-amber-200">
              <AlertTriangle className="w-3.5 h-3.5 text-amber-600 shrink-0" />
              <span>{activeUser.rejectedPaymentsCount} reçu(s) CCP/BaridiMob rejeté(s) pour ce médecin.</span>
            </div>
          )}
        </div>

        {/* --- NAVIGATION TAB BAR --- */}
        <div className="flex items-center overflow-x-auto border-b border-slate-200 dark:border-slate-800 px-3 bg-white dark:bg-slate-900 text-xs font-semibold shrink-0">
          <button
            onClick={() => setDetailsTab('identity')}
            className={`py-3 px-3.5 border-b-2 flex items-center gap-1.5 cursor-pointer whitespace-nowrap transition-colors ${
              detailsTab === 'identity'
                ? 'border-teal-600 text-teal-600 dark:text-teal-400 font-bold'
                : 'border-transparent text-slate-500 hover:text-slate-800 dark:hover:text-slate-200'
            }`}
          >
            <User className="w-3.5 h-3.5" />
            <span>Identité & Cursus</span>
          </button>

          <button
            onClick={() => setDetailsTab('progress')}
            className={`py-3 px-3.5 border-b-2 flex items-center gap-1.5 cursor-pointer whitespace-nowrap transition-colors ${
              detailsTab === 'progress'
                ? 'border-teal-600 text-teal-600 dark:text-teal-400 font-bold'
                : 'border-transparent text-slate-500 hover:text-slate-800 dark:hover:text-slate-200'
            }`}
          >
            <TrendingUp className="w-3.5 h-3.5" />
            <span>Progression & Usage</span>
            {activeProgress.totalQcmSolved > 0 && (
              <span className="ml-1 px-1.5 py-0.2 text-[10px] bg-teal-100 dark:bg-teal-950 text-teal-700 dark:text-teal-300 rounded-full font-mono">
                {activeProgress.totalQcmSolved} QCM
              </span>
            )}
          </button>

          <button
            onClick={() => setDetailsTab('telemetry')}
            className={`py-3 px-3.5 border-b-2 flex items-center gap-1.5 cursor-pointer whitespace-nowrap transition-colors ${
              detailsTab === 'telemetry'
                ? 'border-teal-600 text-teal-600 dark:text-teal-400 font-bold'
                : 'border-transparent text-slate-500 hover:text-slate-800 dark:hover:text-slate-200'
            }`}
          >
            <Activity className="w-3.5 h-3.5" />
            <span>Connexions & Appareils</span>
            {activeTelemetry.isOnline && (
              <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse ml-0.5" />
            )}
          </button>

          <button
            onClick={() => setDetailsTab('subscription')}
            className={`py-3 px-3.5 border-b-2 flex items-center gap-1.5 cursor-pointer whitespace-nowrap transition-colors ${
              detailsTab === 'subscription'
                ? 'border-teal-600 text-teal-600 dark:text-teal-400 font-bold'
                : 'border-transparent text-slate-500 hover:text-slate-800 dark:hover:text-slate-200'
            }`}
          >
            <ShieldCheck className="w-3.5 h-3.5" />
            <span>Abonnement</span>
          </button>

          <button
            onClick={() => setDetailsTab('payments')}
            className={`py-3 px-3.5 border-b-2 flex items-center gap-1.5 cursor-pointer whitespace-nowrap transition-colors ${
              detailsTab === 'payments'
                ? 'border-teal-600 text-teal-600 dark:text-teal-400 font-bold'
                : 'border-transparent text-slate-500 hover:text-slate-800 dark:hover:text-slate-200'
            }`}
          >
            <CreditCard className="w-3.5 h-3.5" />
            <span>Paiements CCP ({activePayments.length})</span>
          </button>

          <button
            onClick={() => setDetailsTab('licenses')}
            className={`py-3 px-3.5 border-b-2 flex items-center gap-1.5 cursor-pointer whitespace-nowrap transition-colors ${
              detailsTab === 'licenses'
                ? 'border-teal-600 text-teal-600 dark:text-teal-400 font-bold'
                : 'border-transparent text-slate-500 hover:text-slate-800 dark:hover:text-slate-200'
            }`}
          >
            <Key className="w-3.5 h-3.5" />
            <span>Licences & Quotas ({activeLicenses.length})</span>
          </button>
        </div>

        {/* --- MODAL BODY CONTENT --- */}
        <div className="flex-1 overflow-y-auto p-4 sm:p-6 space-y-6">
          {isLoading ? (
            <div className="py-12 flex flex-col items-center justify-center text-slate-400 space-y-3">
              <RefreshCw className="w-6 h-6 animate-spin text-teal-600" />
              <p className="text-xs">Chargement du profil complet et de l'historique de synchronisation...</p>
            </div>
          ) : (
            <>
              {/* TAB 1: IDENTITÉ & CURSUS */}
              {detailsTab === 'identity' && (
                <div className="space-y-6 text-xs">
                  {/* Section A: Profil Médical & Académique */}
                  <div>
                    <div className="flex items-center justify-between pb-2 border-b border-slate-200 dark:border-slate-800 mb-3">
                      <div className="flex items-center gap-1.5 font-bold text-slate-800 dark:text-slate-200 uppercase tracking-wide text-[11px]">
                        <GraduationCap className="w-4 h-4 text-teal-600" />
                        <span>Profil Médical & Académique</span>
                      </div>
                      <button
                        onClick={handleOpenEditProfile}
                        className="flex items-center gap-1 px-2.5 py-1 text-xs font-semibold text-teal-600 dark:text-teal-400 hover:bg-teal-50 dark:hover:bg-teal-950/40 rounded-lg cursor-pointer transition-colors"
                      >
                        <Edit2 className="w-3 h-3" />
                        <span>Éditer le profil</span>
                      </button>
                    </div>

                    <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
                      <div className="p-3 bg-slate-50 dark:bg-slate-800/40 rounded-xl border border-slate-200/80 dark:border-slate-800">
                        <span className="text-[10px] font-semibold uppercase text-slate-400 block mb-0.5">Nom Complet</span>
                        <div className="flex items-center justify-between">
                          <span className="font-bold text-slate-900 dark:text-white text-sm">{displayDoctorName}</span>
                          <button onClick={() => copyToClipboard(displayDoctorName, 'Nom')} className="text-slate-400 hover:text-slate-600 cursor-pointer">
                            <Copy className="w-3 h-3" />
                          </button>
                        </div>
                      </div>

                      <div className="p-3 bg-slate-50 dark:bg-slate-800/40 rounded-xl border border-slate-200/80 dark:border-slate-800">
                        <span className="text-[10px] font-semibold uppercase text-slate-400 block mb-0.5">Rôle Médical</span>
                        <span className="font-bold text-slate-900 dark:text-white">{resolvedMedicalRole}</span>
                      </div>

                      <div className="p-3 bg-slate-50 dark:bg-slate-800/40 rounded-xl border border-slate-200/80 dark:border-slate-800">
                        <span className="text-[10px] font-semibold uppercase text-slate-400 block mb-0.5">Faculté de Médecine</span>
                        <span className="font-bold text-slate-900 dark:text-white truncate block">
                          {activeProfile.faculty || activeUser.faculty || 'Faculté non renseignée'}
                        </span>
                      </div>

                      <div className="p-3 bg-slate-50 dark:bg-slate-800/40 rounded-xl border border-slate-200/80 dark:border-slate-800 sm:col-span-2">
                        <span className="text-[10px] font-semibold uppercase text-slate-400 block mb-0.5">Niveau / Année Universitaire</span>
                        <div className="flex items-center justify-between">
                          <span className="font-bold text-teal-600 dark:text-teal-400 text-xs sm:text-sm">
                            {studyYearDisplay}
                          </span>
                          <button
                            onClick={handleOpenEditStudyYear}
                            className="flex items-center gap-1 text-[11px] font-semibold text-teal-600 hover:underline cursor-pointer ml-2 shrink-0"
                          >
                            <Edit2 className="w-3 h-3" />
                            <span>Modifier Niveau</span>
                          </button>
                        </div>
                      </div>

                      <div className="p-3 bg-slate-50 dark:bg-slate-800/40 rounded-xl border border-slate-200/80 dark:border-slate-800">
                        <span className="text-[10px] font-semibold uppercase text-slate-400 block mb-0.5">Code Parrainage</span>
                        <div className="flex items-center justify-between">
                          <span className="font-mono font-bold text-teal-600 dark:text-teal-400">{referralCode}</span>
                          <button onClick={() => copyToClipboard(referralCode, 'Code Parrainage')} className="text-slate-400 hover:text-slate-600 cursor-pointer">
                            <Copy className="w-3 h-3" />
                          </button>
                        </div>
                      </div>
                    </div>
                  </div>

                  {/* Section B: Coordonnées & Préparation Résidanat */}
                  <div>
                    <div className="flex items-center gap-1.5 pb-2 border-b border-slate-200 dark:border-slate-800 mb-3 font-bold text-slate-800 dark:text-slate-200 uppercase tracking-wide text-[11px]">
                      <MapPin className="w-4 h-4 text-teal-600" />
                      <span>Coordonnées & Préparation Résidanat</span>
                    </div>

                    <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
                      <div className="p-3 bg-slate-50 dark:bg-slate-800/40 rounded-xl border border-slate-200/80 dark:border-slate-800">
                        <span className="text-[10px] font-semibold uppercase text-slate-400 block mb-0.5">Wilaya de Résidence</span>
                        <span className="font-bold text-slate-900 dark:text-white">
                          {activeProfile.wilaya || 'Non spécifiée'}
                        </span>
                      </div>

                      <div className="p-3 bg-slate-50 dark:bg-slate-800/40 rounded-xl border border-slate-200/80 dark:border-slate-800">
                        <span className="text-[10px] font-semibold uppercase text-slate-400 block mb-0.5">Numéro Téléphone</span>
                        <div className="flex items-center justify-between">
                          <span className="font-bold text-slate-900 dark:text-white font-mono">
                            {activeProfile.phone || 'Non renseigné'}
                          </span>
                          {activeProfile.phone && (
                            <button onClick={() => copyToClipboard(activeProfile.phone!, 'Téléphone')} className="text-slate-400 hover:text-slate-600 cursor-pointer">
                              <Copy className="w-3 h-3" />
                            </button>
                          )}
                        </div>
                      </div>

                      <div className="p-3 bg-slate-50 dark:bg-slate-800/40 rounded-xl border border-slate-200/80 dark:border-slate-800">
                        <span className="text-[10px] font-semibold uppercase text-slate-400 block mb-0.5">Session Cible Résidanat</span>
                        <span className="font-bold text-slate-900 dark:text-white">
                          {activeProfile.residencyTargetYear ? `Session ${activeProfile.residencyTargetYear}` : 'Non définie'}
                        </span>
                      </div>

                      {activeProfile.bio && (
                        <div className="p-3 bg-slate-50 dark:bg-slate-800/40 rounded-xl border border-slate-200/80 dark:border-slate-800 sm:col-span-3">
                          <span className="text-[10px] font-semibold uppercase text-slate-400 block mb-1">Biographie / Objectif Médical</span>
                          <p className="text-slate-700 dark:text-slate-300 leading-relaxed">{activeProfile.bio}</p>
                        </div>
                      )}
                    </div>
                  </div>

                  {/* Section C: Compte & Métadonnées Sécurité */}
                  <div>
                    <div className="flex items-center gap-1.5 pb-2 border-b border-slate-200 dark:border-slate-800 mb-3 font-bold text-slate-800 dark:text-slate-200 uppercase tracking-wide text-[11px]">
                      <Lock className="w-4 h-4 text-teal-600" />
                      <span>Détails du Compte & Sécurité</span>
                    </div>

                    <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
                      <div className="p-3 bg-slate-50 dark:bg-slate-800/40 rounded-xl border border-slate-200/80 dark:border-slate-800">
                        <span className="text-[10px] font-semibold uppercase text-slate-400 block mb-0.5">Email Officiel</span>
                        <div className="flex items-center justify-between">
                          <span className="font-mono text-slate-900 dark:text-white truncate">{activeUser.email}</span>
                          <button onClick={() => copyToClipboard(activeUser.email, 'Email')} className="text-slate-400 hover:text-slate-600 cursor-pointer ml-1">
                            <Copy className="w-3 h-3" />
                          </button>
                        </div>
                      </div>

                      <div className="p-3 bg-slate-50 dark:bg-slate-800/40 rounded-xl border border-slate-200/80 dark:border-slate-800">
                        <span className="text-[10px] font-semibold uppercase text-slate-400 block mb-0.5">Identifiant Unique (UUID)</span>
                        <div className="flex items-center justify-between">
                          <span className="font-mono text-slate-900 dark:text-white truncate">{activeUser.id}</span>
                          <button onClick={() => copyToClipboard(activeUser.id, 'UUID')} className="text-slate-400 hover:text-slate-600 cursor-pointer ml-1">
                            <Copy className="w-3 h-3" />
                          </button>
                        </div>
                      </div>

                      <div className="p-3 bg-slate-50 dark:bg-slate-800/40 rounded-xl border border-slate-200/80 dark:border-slate-800">
                        <span className="text-[10px] font-semibold uppercase text-slate-400 block mb-0.5">Date d'Inscription</span>
                        <span className="text-slate-900 dark:text-white">
                          {new Date(activeUser.createdAt).toLocaleDateString('fr-FR', { day: '2-digit', month: 'long', year: 'numeric' })}
                        </span>
                      </div>

                      <div className="p-3 bg-slate-50 dark:bg-slate-800/40 rounded-xl border border-slate-200/80 dark:border-slate-800">
                        <span className="text-[10px] font-semibold uppercase text-slate-400 block mb-0.5">Dernière Synchronisation</span>
                        <span className="text-slate-900 dark:text-white">
                          {activeProfile.updatedAt ? new Date(activeProfile.updatedAt).toLocaleString('fr-FR', { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' }) : 'À la création'}
                        </span>
                      </div>

                      <div className="p-3 bg-slate-50 dark:bg-slate-800/40 rounded-xl border border-slate-200/80 dark:border-slate-800">
                        <span className="text-[10px] font-semibold uppercase text-slate-400 block mb-0.5">Rôle Système</span>
                        <span className="font-bold text-slate-900 dark:text-white">
                          {activeUser.isAdmin ? '👑 ADMINISTRATEUR' : 'Utilisateur Médecin'}
                        </span>
                      </div>

                      <div className="p-3 bg-slate-50 dark:bg-slate-800/40 rounded-xl border border-slate-200/80 dark:border-slate-800">
                        <span className="text-[10px] font-semibold uppercase text-slate-400 block mb-0.5">Historique Rejets CCP</span>
                        <span className={`font-bold ${activeUser.rejectedPaymentsCount > 0 ? 'text-amber-600' : 'text-slate-900 dark:text-white'}`}>
                          {activeUser.rejectedPaymentsCount} rejet(s) enregistré(s)
                        </span>
                      </div>
                    </div>
                  </div>
                </div>
              )}

              {/* TAB 2: PROGRESSION & USAGE RÉVISION */}
              {detailsTab === 'progress' && (
                <div className="space-y-6 text-xs">
                  {/* Hero 4-Stat Metric Bento */}
                  <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
                    <div className="p-3.5 bg-gradient-to-br from-teal-50 to-emerald-50 dark:from-teal-950/40 dark:to-emerald-950/20 rounded-xl border border-teal-200/60 dark:border-teal-900/60">
                      <div className="flex items-center gap-1.5 text-teal-700 dark:text-teal-300 font-semibold text-[11px] mb-1">
                        <ListChecks className="w-3.5 h-3.5" />
                        <span>QCMs Traités</span>
                      </div>
                      <p className="text-xl sm:text-2xl font-extrabold font-mono text-teal-900 dark:text-teal-100">
                        {activeProgress.totalQcmSolved}
                      </p>
                      <p className="text-[10.5px] text-teal-600 dark:text-teal-400 mt-0.5 font-medium">
                        +{activeProgress.todayQcmSolved} aujourd'hui
                      </p>
                    </div>

                    <div className="p-3.5 bg-gradient-to-br from-indigo-50 to-blue-50 dark:from-indigo-950/40 dark:to-blue-950/20 rounded-xl border border-indigo-200/60 dark:border-indigo-900/60">
                      <div className="flex items-center gap-1.5 text-indigo-700 dark:text-indigo-300 font-semibold text-[11px] mb-1">
                        <BookOpen className="w-3.5 h-3.5" />
                        <span>Supports PDF Lus</span>
                      </div>
                      <p className="text-xl sm:text-2xl font-extrabold font-mono text-indigo-900 dark:text-indigo-100">
                        {activeProgress.totalCoursesCompleted}
                      </p>
                      <p className="text-[10.5px] text-indigo-600 dark:text-indigo-400 mt-0.5 font-medium">
                        {activeProgress.completedCourseIds?.length || activeProgress.totalCoursesCompleted} cours complétés
                      </p>
                    </div>

                    <div className="p-3.5 bg-gradient-to-br from-amber-50 to-orange-50 dark:from-amber-950/40 dark:to-orange-950/20 rounded-xl border border-amber-200/60 dark:border-amber-900/60">
                      <div className="flex items-center gap-1.5 text-amber-700 dark:text-amber-300 font-semibold text-[11px] mb-1">
                        <Flame className="w-3.5 h-3.5 text-orange-500" />
                        <span>Série de Révision</span>
                      </div>
                      <p className="text-xl sm:text-2xl font-extrabold font-mono text-amber-900 dark:text-amber-100">
                        {activeTelemetry.streakDays} j
                      </p>
                      <p className="text-[10.5px] text-amber-600 dark:text-amber-400 mt-0.5 font-medium">
                        Record : {activeTelemetry.maxStreakDays} jours 🔥
                      </p>
                    </div>

                    <div className="p-3.5 bg-gradient-to-br from-purple-50 to-fuchsia-50 dark:from-purple-950/40 dark:to-fuchsia-950/20 rounded-xl border border-purple-200/60 dark:border-purple-900/60">
                      <div className="flex items-center gap-1.5 text-purple-700 dark:text-purple-300 font-semibold text-[11px] mb-1">
                        <Clock className="w-3.5 h-3.5" />
                        <span>Temps d'Étude</span>
                      </div>
                      <p className="text-xl sm:text-2xl font-extrabold font-mono text-purple-900 dark:text-purple-100">
                        {formatSecondsToHours(activeProgress.totalTimeSpentSeconds || activeTelemetry.connectionCount * 600)}
                      </p>
                      <p className="text-[10.5px] text-purple-600 dark:text-purple-400 mt-0.5 font-medium">
                        {activeTelemetry.connectionCount} session(s)
                      </p>
                    </div>
                  </div>

                  {/* Section: Courses & PDF Reading Detailed List */}
                  <div>
                    <div className="flex items-center justify-between pb-2 border-b border-slate-200 dark:border-slate-800 mb-3">
                      <div className="flex items-center gap-1.5 font-bold text-slate-800 dark:text-slate-200 uppercase tracking-wide text-[11px]">
                        <BookOpen className="w-4 h-4 text-teal-600" />
                        <span>Supports PDF & Cours Officiels Lus ({activeProgress.coursesProgressList?.length || activeProgress.totalCoursesCompleted})</span>
                      </div>
                      <span className="text-[11px] text-slate-500">
                        Objectif : {activeProgress.dailyCourseGoal} cours / jour
                      </span>
                    </div>

                    {activeProgress.coursesProgressList && activeProgress.coursesProgressList.length > 0 ? (
                      <div className="space-y-2">
                        {activeProgress.coursesProgressList.map((course, idx) => (
                          <div 
                            key={idx}
                            className="p-3 bg-slate-50 dark:bg-slate-800/40 rounded-xl border border-slate-200/80 dark:border-slate-800 flex flex-col sm:flex-row sm:items-center justify-between gap-2"
                          >
                            <div className="space-y-0.5 min-w-0">
                              <div className="flex items-center gap-2">
                                <span className="font-bold text-slate-900 dark:text-white truncate">
                                  {course.courseName}
                                </span>
                                {course.isCompleted && (
                                  <span className="px-1.5 py-0.2 text-[9.5px] bg-emerald-100 text-emerald-700 dark:bg-emerald-950 dark:text-emerald-300 font-bold rounded">
                                    Complété ✓
                                  </span>
                                )}
                              </div>
                              <p className="text-[11px] text-slate-500 font-medium">
                                Module : {course.moduleId || 'Tronc Commun'} • {course.revealedQuestions?.length || 0}/{course.totalQuestions || 0} questions répondues
                              </p>
                            </div>

                            <div className="flex items-center gap-3 shrink-0 text-[11px]">
                              {course.lastActiveAt && (
                                <span className="text-slate-400 font-mono">
                                  Dernière lecture : {formatRelativeTime(course.lastActiveAt)}
                                </span>
                              )}
                              <div className="w-16 bg-slate-200 dark:bg-slate-700 h-2 rounded-full overflow-hidden">
                                <div 
                                  className="bg-teal-500 h-full rounded-full"
                                  style={{
                                    width: course.totalQuestions > 0 
                                      ? `${Math.min(100, Math.round(((course.revealedQuestions?.length || 0) / course.totalQuestions) * 100))}%`
                                      : (course.isCompleted ? '100%' : '50%')
                                  }}
                                />
                              </div>
                            </div>
                          </div>
                        ))}
                      </div>
                    ) : (
                      <div className="p-6 bg-slate-50 dark:bg-slate-800/30 rounded-xl border border-slate-200/80 dark:border-slate-800 text-center text-slate-400">
                        <BookOpen className="w-8 h-8 mx-auto mb-1.5 opacity-50" />
                        <p className="text-xs">Aucun cours PDF marqué comme complété pour le moment.</p>
                      </div>
                    )}
                  </div>

                  {/* Section: Specialty Breakdown */}
                  {Object.keys(activeProgress.specialtyBreakdown || {}).length > 0 && (
                    <div>
                      <div className="flex items-center gap-1.5 pb-2 border-b border-slate-200 dark:border-slate-800 mb-3 font-bold text-slate-800 dark:text-slate-200 uppercase tracking-wide text-[11px]">
                        <ListChecks className="w-4 h-4 text-teal-600" />
                        <span>Répartition des QCMs par Spécialité Médicale</span>
                      </div>

                      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-2.5">
                        {Object.entries(activeProgress.specialtyBreakdown).map(([spec, count]) => (
                          <div key={spec} className="p-2.5 bg-slate-50 dark:bg-slate-800/40 rounded-lg border border-slate-200/80 dark:border-slate-800 flex items-center justify-between">
                            <span className="font-semibold text-slate-800 dark:text-slate-200 truncate">{spec}</span>
                            <span className="font-mono font-bold text-teal-600 dark:text-teal-400 bg-teal-50 dark:bg-teal-950/60 px-2 py-0.5 rounded text-[11px]">
                              {count} QCMs
                            </span>
                          </div>
                        ))}
                      </div>
                    </div>
                  )}

                  {/* Section: Other Tools Usage (FSRS, Sessions) */}
                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 pt-2">
                    <div className="p-3 bg-slate-50 dark:bg-slate-800/40 rounded-xl border border-slate-200/80 dark:border-slate-800 flex items-center justify-between">
                      <div>
                        <span className="text-[10px] uppercase font-semibold text-slate-400">Flashcards FSRS (Répétition Espacée)</span>
                        <p className="font-bold text-slate-900 dark:text-white text-sm mt-0.5">
                          {activeProgress.fsrsCardsCount || 0} carte(s) active(s)
                        </p>
                      </div>
                      <Sparkles className="w-5 h-5 text-amber-500" />
                    </div>

                    <div className="p-3 bg-slate-50 dark:bg-slate-800/40 rounded-xl border border-slate-200/80 dark:border-slate-800 flex items-center justify-between">
                      <div>
                        <span className="text-[10px] uppercase font-semibold text-slate-400">Sessions Personnalisées Créées</span>
                        <p className="font-bold text-slate-900 dark:text-white text-sm mt-0.5">
                          {activeProgress.customSessionsCount || 0} session(s)
                        </p>
                      </div>
                      <Calendar className="w-5 h-5 text-indigo-500" />
                    </div>
                  </div>
                </div>
              )}

              {/* TAB 3: CONNEXIONS & ACCÈS PLATEFORMES (TEMPS RÉEL) */}
              {detailsTab === 'telemetry' && (
                <div className="space-y-6 text-xs">
                  {/* Real-Time Telemetry Hero Card */}
                  <div className="p-4 bg-gradient-to-r from-slate-900 to-slate-800 text-white rounded-2xl border border-slate-700 shadow-md">
                    <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
                      <div className="space-y-1">
                        <div className="flex items-center gap-2">
                          <span className={`w-3 h-3 rounded-full ${activeTelemetry.isOnline ? 'bg-emerald-400 animate-ping' : 'bg-slate-400'}`} />
                          <span className="font-bold text-sm tracking-wide">
                            {activeTelemetry.isOnline 
                              ? '🟢 EN LIGNE ACTUELLEMENT' 
                              : (activeTelemetry.isActiveToday ? '🟡 ACTIF AUJOURD\'HUI' : '⚪ HORS-LIGNE')}
                          </span>
                        </div>
                        <p className="text-xs text-slate-300">
                          Dernière activité enregistrée : <strong className="text-white">{formatRelativeTime(activeTelemetry.lastConnectionAt)}</strong>
                          {activeTelemetry.lastConnectionAt && ` (${new Date(activeTelemetry.lastConnectionAt).toLocaleString('fr-FR')})`}
                        </p>
                      </div>

                      <div className="flex items-center gap-2">
                        <span className="px-3 py-1 bg-white/10 rounded-lg text-xs font-mono font-bold">
                          {activeTelemetry.connectionCount} Sessions au total
                        </span>
                      </div>
                    </div>
                  </div>

                  {/* Multi-Platform Access Breakdown */}
                  <div>
                    <div className="flex items-center gap-1.5 pb-2 border-b border-slate-200 dark:border-slate-800 mb-3 font-bold text-slate-800 dark:text-slate-200 uppercase tracking-wide text-[11px]">
                      <Monitor className="w-4 h-4 text-teal-600" />
                      <span>Appareils & Plateformes d'Accès Autorisées</span>
                    </div>

                    <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                      {/* Mobile Android */}
                      <div className={`p-4 rounded-xl border flex items-start gap-3 transition-all ${
                        activeTelemetry.platformsUsed.includes('android') || activeTelemetry.platformsUsed.includes('mobile')
                          ? 'bg-emerald-50/60 dark:bg-emerald-950/20 border-emerald-300 dark:border-emerald-800'
                          : 'bg-slate-50 dark:bg-slate-800/40 border-slate-200 dark:border-slate-800 opacity-60'
                      }`}>
                        <div className="p-2.5 bg-emerald-500/10 text-emerald-600 rounded-lg shrink-0">
                          <Smartphone className="w-5 h-5" />
                        </div>
                        <div className="space-y-1 min-w-0">
                          <p className="font-bold text-slate-900 dark:text-white text-xs">Application Mobile Android</p>
                          <p className="text-[11px] text-slate-500">
                            {activeTelemetry.platformsUsed.includes('android') || activeTelemetry.platformsUsed.includes('mobile')
                              ? 'Package APK Octenium connecté'
                              : 'Non utilisé'}
                          </p>
                          <span className="inline-block text-[10px] font-bold text-emerald-600 dark:text-emerald-400">
                            Mode Hors-Ligne 100%
                          </span>
                        </div>
                      </div>

                      {/* PC Windows */}
                      <div className={`p-4 rounded-xl border flex items-start gap-3 transition-all ${
                        activeTelemetry.platformsUsed.includes('windows')
                          ? 'bg-sky-50/60 dark:bg-sky-950/20 border-sky-300 dark:border-sky-800'
                          : 'bg-slate-50 dark:bg-slate-800/40 border-slate-200 dark:border-slate-800 opacity-60'
                      }`}>
                        <div className="p-2.5 bg-sky-500/10 text-sky-600 rounded-lg shrink-0">
                          <Monitor className="w-5 h-5" />
                        </div>
                        <div className="space-y-1 min-w-0">
                          <p className="font-bold text-slate-900 dark:text-white text-xs">Application PC Windows</p>
                          <p className="text-[11px] text-slate-500">
                            {activeTelemetry.platformsUsed.includes('windows')
                              ? 'Client Bureau PC actif'
                              : 'Installateur disponible'}
                          </p>
                          <span className="inline-block text-[10px] font-bold text-sky-600 dark:text-sky-400">
                            Grand Écran & Raccourcis
                          </span>
                        </div>
                      </div>

                      {/* Web */}
                      <div className={`p-4 rounded-xl border flex items-start gap-3 transition-all ${
                        activeTelemetry.platformsUsed.includes('web')
                          ? 'bg-indigo-50/60 dark:bg-indigo-950/20 border-indigo-300 dark:border-indigo-800'
                          : 'bg-slate-50 dark:bg-slate-800/40 border-slate-200 dark:border-slate-800 opacity-60'
                      }`}>
                        <div className="p-2.5 bg-indigo-500/10 text-indigo-600 rounded-lg shrink-0">
                          <Globe className="w-5 h-5" />
                        </div>
                        <div className="space-y-1 min-w-0">
                          <p className="font-bold text-slate-900 dark:text-white text-xs">Plateforme Web en Ligne</p>
                          <p className="text-[11px] text-slate-500">
                            {activeTelemetry.platformsUsed.includes('web')
                              ? 'Navigateur Chrome/Firefox'
                              : 'Accès sans installation'}
                          </p>
                          <span className="inline-block text-[10px] font-bold text-indigo-600 dark:text-indigo-400">
                            Cloud Sync instantané
                          </span>
                        </div>
                      </div>
                    </div>
                  </div>

                  {/* Loyalty XP & Active Streak Tracker */}
                  <div>
                    <div className="flex items-center gap-1.5 pb-2 border-b border-slate-200 dark:border-slate-800 mb-3 font-bold text-slate-800 dark:text-slate-200 uppercase tracking-wide text-[11px]">
                      <Flame className="w-4 h-4 text-orange-500" />
                      <span>Programme de Fidélité, XP & Habitudes de Révision</span>
                    </div>

                    <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3">
                      <div className="p-3 bg-slate-50 dark:bg-slate-800/40 rounded-xl border border-slate-200/80 dark:border-slate-800">
                        <span className="text-[10px] uppercase font-semibold text-slate-400 block mb-0.5">Niveau & Rang Médical</span>
                        <span className="font-bold text-slate-900 dark:text-white">{activeTelemetry.loyaltyLevel}</span>
                        <p className="text-[10.5px] text-teal-600 font-mono mt-0.5 font-bold">
                          {activeTelemetry.loyaltyPoints} XP accumulés
                        </p>
                      </div>

                      <div className="p-3 bg-slate-50 dark:bg-slate-800/40 rounded-xl border border-slate-200/80 dark:border-slate-800">
                        <span className="text-[10px] uppercase font-semibold text-slate-400 block mb-0.5">Série Active (Streak)</span>
                        <span className="font-bold text-orange-600 font-mono text-base">
                          {activeTelemetry.streakDays} jour(s) 🔥
                        </span>
                      </div>

                      <div className="p-3 bg-slate-50 dark:bg-slate-800/40 rounded-xl border border-slate-200/80 dark:border-slate-800">
                        <span className="text-[10px] uppercase font-semibold text-slate-400 block mb-0.5">Record Historique de Série</span>
                        <span className="font-bold text-slate-900 dark:text-white font-mono text-base">
                          {activeTelemetry.maxStreakDays} jour(s) ininterrompus
                        </span>
                      </div>

                      <div className="p-3 bg-slate-50 dark:bg-slate-800/40 rounded-xl border border-slate-200/80 dark:border-slate-800">
                        <span className="text-[10px] uppercase font-semibold text-slate-400 block mb-0.5">Première Connexion</span>
                        <span className="font-bold text-slate-900 dark:text-white">
                          {activeTelemetry.firstActiveDate || 'Inconnue'}
                        </span>
                      </div>
                    </div>
                  </div>

                  {/* Active Days Calendar / Pastilles */}
                  {activeTelemetry.activeDaysHistory.length > 0 && (
                    <div className="p-3.5 bg-slate-50 dark:bg-slate-800/40 rounded-xl border border-slate-200/80 dark:border-slate-800">
                      <span className="text-[10px] uppercase font-semibold text-slate-400 block mb-2">
                        Historique des Jours Actifs Enregistrés ({activeTelemetry.activeDaysHistory.length} dates)
                      </span>
                      <div className="flex flex-wrap gap-1.5">
                        {activeTelemetry.activeDaysHistory.slice(-21).map((dateStr) => (
                          <span 
                            key={dateStr}
                            className="px-2 py-0.5 text-[10.5px] font-mono bg-teal-50 dark:bg-teal-950/70 border border-teal-200 dark:border-teal-800 text-teal-800 dark:text-teal-200 rounded-md font-semibold"
                          >
                            ✓ {dateStr}
                          </span>
                        ))}
                      </div>
                    </div>
                  )}
                </div>
              )}

              {/* TAB 4: ABONNEMENT & DROITS D'ACCÈS */}
              {detailsTab === 'subscription' && (
                <div className="space-y-6 text-xs">
                  {/* Current Subscription Highlight Banner */}
                  <div className="p-4 bg-slate-50 dark:bg-slate-800/50 rounded-2xl border border-slate-200 dark:border-slate-800 flex flex-col sm:flex-row sm:items-center justify-between gap-4">
                    <div className="space-y-1">
                      <span className="text-[10px] uppercase font-semibold text-slate-400">Formule Active</span>
                      <div className="flex items-center gap-2">
                        <span className="text-base font-bold text-slate-900 dark:text-white">
                          {tierBadge.label}
                        </span>
                        <span className={`px-2 py-0.5 rounded-full text-[10px] font-bold uppercase ${
                          activeUser.isBanned 
                            ? 'bg-rose-100 text-rose-800 dark:bg-rose-950 dark:text-rose-300'
                            : (isExpired ? 'bg-slate-200 text-slate-700' : 'bg-emerald-100 text-emerald-800 dark:bg-emerald-950 dark:text-emerald-300')
                        }`}>
                          {activeUser.isBanned ? 'Suspendu' : (isExpired ? 'Expiré' : 'Actif')}
                        </span>
                      </div>
                      <p className="text-[11px] text-slate-500 font-mono">
                        Échéance : <strong>{effectiveExpiry ? new Date(effectiveExpiry).toLocaleDateString('fr-FR', { day: '2-digit', month: 'long', year: 'numeric' }) : 'Accès illimité'}</strong>
                        {daysRemaining !== null && ` (${daysRemaining > 0 ? `${daysRemaining} jour(s) restants` : 'Abonnement expiré'})`}
                      </p>
                    </div>

                    {/* Fast Tier Switcher */}
                    <div className="flex flex-col gap-1 sm:items-end">
                      <span className="text-[10px] uppercase font-semibold text-slate-400">Changer de Formule</span>
                      <select
                        value={activeUser.tier}
                        onChange={(e) => handleChangeTier(e.target.value as SubscriptionTier)}
                        className="px-3 py-1.5 text-xs bg-white dark:bg-slate-900 border border-slate-300 dark:border-slate-700 rounded-lg text-slate-800 dark:text-slate-200 font-semibold cursor-pointer focus:ring-1 focus:ring-teal-500"
                      >
                        <option value="free">Pass Découverte (Gratuit)</option>
                        <option value="etudiant">Pass Étudiant Cursus (4 500 DZD)</option>
                        <option value="clinical_pro">Pass Clinique Pro (9 000 DZD)</option>
                        <option value="resident_elite">Pass Résident Élite (12 000 DZD)</option>
                        <option value="all_access">Medsina All-Access VIP (18 000 DZD)</option>
                      </select>
                    </div>
                  </div>

                  {/* Entitlements Details */}
                  <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                    <div className="p-3 bg-slate-50 dark:bg-slate-800/40 rounded-xl border border-slate-200/80 dark:border-slate-800">
                      <span className="text-[10px] uppercase font-semibold text-slate-400 block mb-0.5">Appareils Simultanés</span>
                      <span className="font-bold text-slate-900 dark:text-white">
                        {activeSub?.max_devices || 3} écrans autorisés (Mode Hors-Ligne)
                      </span>
                    </div>

                    <div className="p-3 bg-slate-50 dark:bg-slate-800/40 rounded-xl border border-slate-200/80 dark:border-slate-800">
                      <span className="text-[10px] uppercase font-semibold text-slate-400 block mb-0.5">Tuteurs IA Medsina</span>
                      <span className="font-bold text-slate-900 dark:text-white">
                        {activeUser.tier === 'all_access' ? '6 Agents IA Dédiés (Illimités)' : (activeUser.tier === 'free' ? 'Requête test limitée' : 'Tuteurs selon niveau')}
                      </span>
                    </div>

                    <div className="p-3 bg-slate-50 dark:bg-slate-800/40 rounded-xl border border-slate-200/80 dark:border-slate-800">
                      <span className="text-[10px] uppercase font-semibold text-slate-400 block mb-0.5">Supports PDF Téléchargeables</span>
                      <span className="font-bold text-slate-900 dark:text-white">
                        {activeUser.tier === 'free' ? '3 Modules Découverte' : '47 Modules & Livrets Illimités'}
                      </span>
                    </div>
                  </div>

                  {/* Quick Validity Extensions */}
                  <div className="space-y-2">
                    <span className="font-bold text-slate-800 dark:text-slate-200 uppercase tracking-wide text-[11px] block">
                      Prolongation Rapide de la Validité
                    </span>
                    <div className="grid grid-cols-3 gap-2.5">
                      <button
                        onClick={() => handleExtendSubscription(30)}
                        className="py-2.5 px-3 bg-slate-100 hover:bg-slate-200 dark:bg-slate-800 dark:hover:bg-slate-700 text-slate-800 dark:text-slate-200 rounded-xl font-bold cursor-pointer text-center transition-colors"
                      >
                        +30 Jours
                      </button>
                      <button
                        onClick={() => handleExtendSubscription(180)}
                        className="py-2.5 px-3 bg-slate-100 hover:bg-slate-200 dark:bg-slate-800 dark:hover:bg-slate-700 text-slate-800 dark:text-slate-200 rounded-xl font-bold cursor-pointer text-center transition-colors"
                      >
                        +180 Jours (6 Mois)
                      </button>
                      <button
                        onClick={() => handleExtendSubscription(365)}
                        className="py-2.5 px-3 bg-teal-600 hover:bg-teal-700 text-white rounded-xl font-bold cursor-pointer text-center shadow-xs transition-colors"
                      >
                        +365 Jours (1 An)
                      </button>
                    </div>
                  </div>

                  {/* Account Ban / Suspension Action */}
                  <div className="pt-3 border-t border-slate-200 dark:border-slate-800 flex items-center justify-between">
                    <div>
                      <span className="font-semibold text-slate-800 dark:text-slate-200 block">Statut Administratif du Compte</span>
                      <p className="text-[11px] text-slate-500">
                        {activeUser.isBanned 
                          ? 'Le compte est suspendu. L\'accès est révoqué.' 
                          : 'Le compte est actif sans aucune restriction.'}
                      </p>
                    </div>

                    <button
                      onClick={() => setShowBanModal(true)}
                      className={`px-3.5 py-1.5 rounded-lg font-bold text-xs transition-colors cursor-pointer ${
                        activeUser.isBanned
                          ? 'bg-emerald-50 text-emerald-700 dark:bg-emerald-950 dark:text-emerald-300 hover:bg-emerald-100'
                          : 'bg-rose-50 text-rose-700 dark:bg-rose-950 dark:text-rose-300 hover:bg-rose-100 border border-rose-200 dark:border-rose-900'
                      }`}
                    >
                      {activeUser.isBanned ? 'Débloquer le Compte' : 'Suspendre / Bannir'}
                    </button>
                  </div>
                </div>
              )}

              {/* TAB 5: PAIEMENTS CCP & BARIDIMOB */}
              {detailsTab === 'payments' && (
                <div className="space-y-4 text-xs">
                  {activePayments.length === 0 ? (
                    <div className="py-10 text-center text-slate-400 space-y-2">
                      <CreditCard className="w-8 h-8 mx-auto opacity-50" />
                      <p>Aucune transaction ou reçu soumis par ce médecin pour le moment.</p>
                    </div>
                  ) : (
                    activePayments.map((p) => (
                      <div 
                        key={p.id}
                        className="p-3.5 bg-slate-50 dark:bg-slate-800/40 rounded-xl border border-slate-200/80 dark:border-slate-800 space-y-2"
                      >
                        <div className="flex items-center justify-between">
                          <div className="flex items-center gap-2">
                            <span className="font-mono font-bold text-sm text-slate-900 dark:text-white">
                              {p.amount.toLocaleString()} DZD
                            </span>
                            <span className="text-[10px] uppercase font-mono px-2 py-0.5 rounded bg-slate-200 dark:bg-slate-700 text-slate-700 dark:text-slate-300">
                              {p.paymentMethod}
                            </span>
                            <span className={`text-[10px] font-bold uppercase px-2 py-0.5 rounded ${
                              p.status === 'approved' 
                                ? 'bg-emerald-100 text-emerald-800 dark:bg-emerald-950 dark:text-emerald-300'
                                : (p.status === 'rejected' ? 'bg-rose-100 text-rose-800 dark:bg-rose-950 dark:text-rose-300' : 'bg-amber-100 text-amber-800 dark:bg-amber-950 dark:text-amber-300')
                            }`}>
                              {p.status === 'approved' ? 'Validé ✓' : (p.status === 'rejected' ? 'Rejeté ✗' : 'En attente ⏳')}
                            </span>
                          </div>

                          <span className="text-slate-400 font-mono text-[11px]">
                            {new Date(p.createdAt).toLocaleString('fr-FR', { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' })}
                          </span>
                        </div>

                        <div className="flex flex-wrap items-center justify-between gap-2 text-[11px] text-slate-500">
                          <span>Réf : <strong className="font-mono text-slate-700 dark:text-slate-300">{p.receiptReference || 'Non spécifiée'}</strong></span>
                          {p.adminNotes && (
                            <span className="italic text-amber-600 dark:text-amber-400">
                              Note admin : {p.adminNotes}
                            </span>
                          )}
                          {p.receiptUrl && (
                            <button
                              onClick={() => setReceiptPreviewUrl(p.receiptUrl!)}
                              className="flex items-center gap-1 text-teal-600 hover:underline cursor-pointer font-semibold ml-auto"
                            >
                              <ExternalLink className="w-3 h-3" />
                              <span>Voir le Reçu</span>
                            </button>
                          )}
                        </div>
                      </div>
                    ))
                  )}
                </div>
              )}

              {/* TAB 6: LICENCES & QUOTAS */}
              {detailsTab === 'licenses' && (
                <div className="space-y-6 text-xs">
                  {/* Redeemed License Keys */}
                  <div>
                    <div className="flex items-center gap-1.5 pb-2 border-b border-slate-200 dark:border-slate-800 mb-3 font-bold text-slate-800 dark:text-slate-200 uppercase tracking-wide text-[11px]">
                      <Key className="w-4 h-4 text-teal-600" />
                      <span>Clés d'Activation & Licences Physiques ({activeLicenses.length})</span>
                    </div>

                    {activeLicenses.length === 0 ? (
                      <p className="text-slate-400 text-center py-6 bg-slate-50 dark:bg-slate-800/30 rounded-xl border border-slate-200/80 dark:border-slate-800">
                        Aucune clé de licence physique utilisée pour ce compte.
                      </p>
                    ) : (
                      <div className="space-y-2">
                        {activeLicenses.map((l, i) => (
                          <div 
                            key={i}
                            className="p-3 bg-slate-50 dark:bg-slate-800/40 rounded-xl border border-slate-200/80 dark:border-slate-800 flex items-center justify-between"
                          >
                            <div className="space-y-0.5">
                              <span className="font-mono font-bold text-teal-600 dark:text-teal-400 text-xs sm:text-sm block">
                                {l.keyCode}
                              </span>
                              <span className="text-[11px] text-slate-500">
                                Formule : {l.tier} • Durée : {l.durationDays} jours
                              </span>
                            </div>
                            <div className="text-right">
                              <span className="text-[10.5px] font-bold text-emerald-600">Active</span>
                              <p className="text-[10.5px] text-slate-400">
                                {l.redeemedAt ? new Date(l.redeemedAt).toLocaleDateString('fr-FR') : ''}
                              </p>
                            </div>
                          </div>
                        ))}
                      </div>
                    )}
                  </div>

                  {/* Quotas & Trial Limits */}
                  <div>
                    <div className="flex items-center gap-1.5 pb-2 border-b border-slate-200 dark:border-slate-800 mb-3 font-bold text-slate-800 dark:text-slate-200 uppercase tracking-wide text-[11px]">
                      <Sparkles className="w-4 h-4 text-teal-600" />
                      <span>Quotas Outils Spécialisés & Assistant IA</span>
                    </div>

                    <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
                      <div className="p-3 bg-slate-50 dark:bg-slate-800/40 rounded-xl border border-slate-200/80 dark:border-slate-800">
                        <span className="text-[10px] uppercase font-semibold text-slate-400 block mb-0.5">Analyses Vidal Ordonnances</span>
                        <span className="font-bold text-slate-900 dark:text-white text-sm">
                          {deepDetails?.trialQuotas?.prescription_analyses_used || 0} requête(s)
                        </span>
                      </div>

                      <div className="p-3 bg-slate-50 dark:bg-slate-800/40 rounded-xl border border-slate-200/80 dark:border-slate-800">
                        <span className="text-[10px] uppercase font-semibold text-slate-400 block mb-0.5">Requêtes Assistant Copilot IA</span>
                        <span className="font-bold text-slate-900 dark:text-white text-sm">
                          {deepDetails?.trialQuotas?.copilot_queries_used || 0} échange(s)
                        </span>
                      </div>

                      <div className="p-3 bg-slate-50 dark:bg-slate-800/40 rounded-xl border border-slate-200/80 dark:border-slate-800">
                        <span className="text-[10px] uppercase font-semibold text-slate-400 block mb-0.5">Modules Gratuits Sélectionnés</span>
                        <span className="font-bold text-slate-900 dark:text-white">
                          {deepDetails?.trialQuotas?.selected_free_modules?.length 
                            ? deepDetails.trialQuotas.selected_free_modules.join(', ')
                            : 'Aucun (Accès standard)'}
                        </span>
                      </div>
                    </div>
                  </div>
                </div>
              )}
            </>
          )}
        </div>

        {/* --- FOOTER: QUICK SHORTCUTS --- */}
        <div className="p-3 sm:p-4 bg-slate-50/90 dark:bg-slate-800/80 border-t border-slate-200 dark:border-slate-800 flex items-center justify-between gap-3 shrink-0">
          <button
            onClick={() => setShowBanModal(true)}
            className={`px-3 py-1.5 rounded-lg text-xs font-bold transition-colors cursor-pointer ${
              activeUser.isBanned 
                ? 'bg-emerald-600 text-white hover:bg-emerald-700' 
                : 'bg-rose-50 text-rose-700 dark:bg-rose-950 dark:text-rose-300 hover:bg-rose-100 border border-rose-200 dark:border-rose-900'
            }`}
          >
            {activeUser.isBanned ? 'Débloquer' : 'Suspendre le Compte'}
          </button>

          <div className="flex items-center gap-2">
            <button
              onClick={() => handleExtendSubscription(30)}
              className="px-3 py-1.5 text-xs font-semibold text-teal-600 dark:text-teal-400 hover:bg-teal-50 dark:hover:bg-teal-950/40 rounded-lg cursor-pointer transition-colors"
            >
              +30 Jours
            </button>
            <button
              onClick={onClose}
              className="px-4 py-1.5 text-xs font-semibold bg-slate-200 hover:bg-slate-300 dark:bg-slate-700 dark:hover:bg-slate-600 text-slate-800 dark:text-white rounded-lg cursor-pointer transition-colors"
            >
              Fermer
            </button>
          </div>
        </div>
      </div>

      {/* --- SUB-MODAL 1: MODIFIER NIVEAU ACADÉMIQUE / ANNÉE --- */}
      {showEditStudyYearModal && (
        <div className="fixed inset-0 z-60 flex items-center justify-center p-4 bg-black/60 backdrop-blur-2xs">
          <div className="w-full max-w-md bg-white dark:bg-slate-900 rounded-2xl p-5 border border-slate-200 dark:border-slate-800 shadow-xl space-y-4">
            <div className="flex items-center justify-between">
              <h3 className="font-bold text-sm text-slate-900 dark:text-white flex items-center gap-2">
                <GraduationCap className="w-4 h-4 text-teal-600" />
                <span>Modifier Niveau / Année Universitaire</span>
              </h3>
              <button onClick={() => setShowEditStudyYearModal(false)} className="text-slate-400 hover:text-slate-600">
                <X className="w-4 h-4" />
              </button>
            </div>

            <p className="text-xs text-slate-500">
              Affecter le niveau académique officiel pour <strong>{displayDoctorName}</strong> dans Supabase :
            </p>

            <div className="space-y-1">
              <label className="text-xs font-semibold text-slate-700 dark:text-slate-300">Année d'Études :</label>
              <select
                value={selectedStudyYearInput ?? ''}
                onChange={(e) => setSelectedStudyYearInput(e.target.value === '' ? null : parseInt(e.target.value, 10))}
                className="w-full p-2.5 text-xs bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg text-slate-900 dark:text-white focus:ring-1 focus:ring-teal-500 cursor-pointer"
              >
                <option value="1">1ère Année (Sciences Fondamentales I)</option>
                <option value="2">2ème Année (Sciences Fondamentales II)</option>
                <option value="3">3ème Année (Pré-Clinique & Sémiologie)</option>
                <option value="4">4ème Année (Externat - Pathologie I)</option>
                <option value="5">5ème Année (Externat - Pathologie II)</option>
                <option value="6">6ème Année (Externat - Thérapeutique)</option>
                <option value="">Diplômé / Résident / Praticien</option>
              </select>
            </div>

            <div className="flex justify-end gap-2 pt-2">
              <button
                onClick={() => setShowEditStudyYearModal(false)}
                className="px-3.5 py-1.5 text-xs text-slate-600 dark:text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-800 rounded-lg"
              >
                Annuler
              </button>
              <button
                disabled={isSavingStudyYear}
                onClick={handleSaveStudyYear}
                className="px-4 py-1.5 text-xs font-bold text-white bg-teal-600 hover:bg-teal-700 rounded-lg shadow-xs flex items-center gap-1.5"
              >
                {isSavingStudyYear && <RefreshCw className="w-3 h-3 animate-spin" />}
                <span>Enregistrer</span>
              </button>
            </div>
          </div>
        </div>
      )}

      {/* --- SUB-MODAL 2: ÉDITION ADMINISTRATIVE DU PROFIL --- */}
      {showEditProfileModal && (
        <div className="fixed inset-0 z-60 flex items-center justify-center p-4 bg-black/60 backdrop-blur-2xs">
          <div className="w-full max-w-xl max-h-[90vh] overflow-y-auto bg-white dark:bg-slate-900 rounded-2xl p-5 border border-slate-200 dark:border-slate-800 shadow-xl space-y-4">
            <div className="flex items-center justify-between">
              <h3 className="font-bold text-sm text-slate-900 dark:text-white flex items-center gap-2">
                <Edit2 className="w-4 h-4 text-teal-600" />
                <span>Édition Administrative du Profil Médecin</span>
              </h3>
              <button onClick={() => setShowEditProfileModal(false)} className="text-slate-400 hover:text-slate-600">
                <X className="w-4 h-4" />
              </button>
            </div>

            <div className="space-y-3 text-xs">
              <div>
                <label className="font-semibold block mb-1 text-slate-700 dark:text-slate-300">Nom Complet du Médecin * :</label>
                <input
                  type="text"
                  value={editFullName}
                  onChange={(e) => setEditFullName(e.target.value)}
                  className="w-full p-2 bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg text-slate-900 dark:text-white"
                />
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label className="font-semibold block mb-1 text-slate-700 dark:text-slate-300">Rôle Médical * :</label>
                  <input
                    type="text"
                    value={editMedicalRole}
                    onChange={(e) => setEditMedicalRole(e.target.value)}
                    className="w-full p-2 bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg text-slate-900 dark:text-white"
                  />
                </div>
                <div>
                  <label className="font-semibold block mb-1 text-slate-700 dark:text-slate-300">Année Cursus (1..6) :</label>
                  <select
                    value={editStudyYear ?? ''}
                    onChange={(e) => setEditStudyYear(e.target.value === '' ? null : parseInt(e.target.value, 10))}
                    className="w-full p-2 bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg text-slate-900 dark:text-white"
                  >
                    <option value="">Diplômé / Résident / Spécialiste</option>
                    <option value="1">1ère Année</option>
                    <option value="2">2ème Année</option>
                    <option value="3">3ème Année</option>
                    <option value="4">4ème Année (Externat I)</option>
                    <option value="5">5ème Année (Externat II)</option>
                    <option value="6">6ème Année (Thérapeutique)</option>
                  </select>
                </div>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label className="font-semibold block mb-1 text-slate-700 dark:text-slate-300">Faculté de Médecine * :</label>
                  <input
                    type="text"
                    value={editFaculty}
                    onChange={(e) => setEditFaculty(e.target.value)}
                    className="w-full p-2 bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg text-slate-900 dark:text-white"
                  />
                </div>
                <div>
                  <label className="font-semibold block mb-1 text-slate-700 dark:text-slate-300">Wilaya :</label>
                  <input
                    type="text"
                    value={editWilaya}
                    onChange={(e) => setEditWilaya(e.target.value)}
                    placeholder="Alger, Blida, Oran..."
                    className="w-full p-2 bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg text-slate-900 dark:text-white"
                  />
                </div>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label className="font-semibold block mb-1 text-slate-700 dark:text-slate-300">Numéro Téléphone :</label>
                  <input
                    type="text"
                    value={editPhone}
                    onChange={(e) => setEditPhone(e.target.value)}
                    placeholder="0550 12 34 56"
                    className="w-full p-2 bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg text-slate-900 dark:text-white"
                  />
                </div>
                <div>
                  <label className="font-semibold block mb-1 text-slate-700 dark:text-slate-300">Session Cible Résidanat :</label>
                  <input
                    type="text"
                    value={editResidencyYear}
                    onChange={(e) => setEditResidencyYear(e.target.value)}
                    placeholder="2026, 2027..."
                    className="w-full p-2 bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg text-slate-900 dark:text-white"
                  />
                </div>
              </div>

              <div>
                <label className="font-semibold block mb-1 text-slate-700 dark:text-slate-300">Biographie & Statut :</label>
                <textarea
                  rows={2}
                  value={editBio}
                  onChange={(e) => setEditBio(e.target.value)}
                  placeholder="Objectif de révision, statut clinique..."
                  className="w-full p-2 bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg text-slate-900 dark:text-white"
                />
              </div>
            </div>

            <div className="flex justify-end gap-2 pt-2 border-t border-slate-200 dark:border-slate-800">
              <button
                onClick={() => setShowEditProfileModal(false)}
                className="px-3.5 py-1.5 text-xs text-slate-600 dark:text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-800 rounded-lg"
              >
                Annuler
              </button>
              <button
                disabled={isSavingProfile}
                onClick={handleSaveProfile}
                className="px-4 py-1.5 text-xs font-bold text-white bg-teal-600 hover:bg-teal-700 rounded-lg shadow-xs flex items-center gap-1.5"
              >
                {isSavingProfile && <RefreshCw className="w-3 h-3 animate-spin" />}
                <span>Enregistrer les modifications</span>
              </button>
            </div>
          </div>
        </div>
      )}

      {/* --- SUB-MODAL 3: BAN / SUSPEND CONFIRMATION --- */}
      {showBanModal && (
        <div className="fixed inset-0 z-60 flex items-center justify-center p-4 bg-black/60 backdrop-blur-2xs">
          <div className="w-full max-w-md bg-white dark:bg-slate-900 rounded-2xl p-5 border border-slate-200 dark:border-slate-800 shadow-xl space-y-4">
            <div className="flex items-center justify-between">
              <h3 className="font-bold text-sm text-slate-900 dark:text-white flex items-center gap-2">
                <Ban className="w-4 h-4 text-rose-600" />
                <span>{activeUser.isBanned ? 'Débloquer le Compte' : 'Suspendre le Compte Médecin'}</span>
              </h3>
              <button onClick={() => setShowBanModal(false)} className="text-slate-400 hover:text-slate-600">
                <X className="w-4 h-4" />
              </button>
            </div>

            <p className="text-xs text-slate-500">
              {activeUser.isBanned
                ? `Souhaitez-vous lever la suspension du compte de ${displayDoctorName} ? Ses accès seront immédiatement restaurés.`
                : `Voulez-vous suspendre l'accès de ${displayDoctorName} ? Le médecin ne pourra plus se connecter.`}
            </p>

            {!activeUser.isBanned && (
              <div className="space-y-1">
                <label className="text-xs font-semibold text-slate-700 dark:text-slate-300">Motif de Suspension :</label>
                <input
                  type="text"
                  value={banReasonInput}
                  onChange={(e) => setBanReasonInput(e.target.value)}
                  placeholder="Reçus falsifiés, partage de compte..."
                  className="w-full p-2.5 text-xs bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg text-slate-900 dark:text-white"
                />
              </div>
            )}

            <div className="flex justify-end gap-2 pt-2">
              <button
                onClick={() => setShowBanModal(false)}
                className="px-3.5 py-1.5 text-xs text-slate-600 dark:text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-800 rounded-lg"
              >
                Annuler
              </button>
              <button
                disabled={isTogglingBan}
                onClick={handleToggleBan}
                className={`px-4 py-1.5 text-xs font-bold text-white rounded-lg shadow-xs flex items-center gap-1.5 ${
                  activeUser.isBanned ? 'bg-emerald-600 hover:bg-emerald-700' : 'bg-rose-600 hover:bg-rose-700'
                }`}
              >
                {isTogglingBan && <RefreshCw className="w-3 h-3 animate-spin" />}
                <span>{activeUser.isBanned ? 'Confirmer Déblocage' : 'Confirmer Suspension'}</span>
              </button>
            </div>
          </div>
        </div>
      )}

      {/* --- SUB-MODAL 4: RECEIPT PREVIEW MODAL --- */}
      {receiptPreviewUrl && (
        <div className="fixed inset-0 z-70 flex items-center justify-center p-4 bg-black/80 backdrop-blur-xs">
          <div className="w-full max-w-2xl max-h-[85vh] bg-white dark:bg-slate-900 rounded-2xl overflow-hidden border border-slate-200 dark:border-slate-800 flex flex-col">
            <div className="p-3 bg-slate-100 dark:bg-slate-800 flex items-center justify-between border-b border-slate-200 dark:border-slate-700">
              <span className="font-bold text-xs text-slate-800 dark:text-slate-200">Reçu de Paiement</span>
              <div className="flex items-center gap-2">
                <a 
                  href={receiptPreviewUrl} 
                  target="_blank" 
                  rel="noreferrer" 
                  className="text-xs text-teal-600 hover:underline flex items-center gap-1"
                >
                  <ExternalLink className="w-3 h-3" />
                  <span>Ouvrir dans un nouvel onglet</span>
                </a>
                <button onClick={() => setReceiptPreviewUrl(null)} className="text-slate-400 hover:text-slate-600">
                  <X className="w-4 h-4" />
                </button>
              </div>
            </div>
            <div className="p-4 flex-1 overflow-auto flex items-center justify-center bg-slate-50 dark:bg-slate-950">
              {receiptPreviewUrl.toLowerCase().endsWith('.pdf') ? (
                <iframe src={receiptPreviewUrl} className="w-full h-[60vh] rounded-lg" title="Reçu PDF" />
              ) : (
                <img src={receiptPreviewUrl} alt="Reçu CCP" className="max-w-full max-h-[65vh] object-contain rounded-lg" />
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
