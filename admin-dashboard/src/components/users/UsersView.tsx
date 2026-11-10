import React, { useState } from 'react';
import { 
  Users, 
  Search, 
  Filter, 
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
  X,
  ExternalLink,
  ChevronRight,
  Plus,
  Edit2,
  Save,
  Clock,
  ArrowRight,
  Smartphone,
  Monitor,
  Globe,
  Flame,
  Activity,
  BookOpen,
  ListChecks,
  Stethoscope,
  Zap,
  UserCheck,
  UserX,
  ArrowUpDown,
  Copy,
  Check,
  Sparkles
} from 'lucide-react';
import { AdminUserItem, SubscriptionTier, PaymentItem, AdminLicenseItem, MedicalRole } from '../../types/medsina';
import { DoctorProfileModal } from './DoctorProfileModal';
import { resolveStudyYear, formatStudyYearDisplay, updateUserProfileInSupabase } from '../../services/supabase';

export type UserActivitySegment = 'all' | 'online' | 'frequent' | 'regular' | 'occasional' | 'inactive' | 'dormant';

export interface UserActivityDetail {
  segment: UserActivitySegment;
  label: string;
  sublabel: string;
  badgeClass: string;
  dotClass: string;
  daysSinceActive: number;
  isFrequent: boolean;
  isInactive: boolean;
}

export function getUserActivityInfo(user: AdminUserItem): UserActivityDetail {
  const isOnline = !!user.telemetry?.isOnline;
  const isActiveToday = !!user.telemetry?.isActiveToday;
  const streak = user.telemetry?.streakDays || 0;
  const connectionCount = user.telemetry?.connectionCount || 0;
  const qcmSolved = user.progress?.totalQcmSolved || 0;
  const coursesCompleted = user.progress?.totalCoursesCompleted || 0;
  
  const lastActiveTimestamp = user.telemetry?.lastConnectionAt || user.updatedAt || user.createdAt;
  const now = Date.now();
  let msSinceActive = 9999999999;
  if (lastActiveTimestamp) {
    const t = new Date(lastActiveTimestamp).getTime();
    if (!isNaN(t)) {
      msSinceActive = Math.max(0, now - t);
    }
  }

  const hoursSinceActive = msSinceActive / (1000 * 3600);
  const daysSinceActive = Math.floor(hoursSinceActive / 24);

  // 1. Online: actively connected within 15 min
  if (isOnline) {
    return {
      segment: 'online',
      label: 'En ligne',
      sublabel: 'Connecté maintenant',
      badgeClass: 'bg-emerald-50 text-emerald-700 dark:bg-emerald-950/80 dark:text-emerald-300 border-emerald-300 dark:border-emerald-800',
      dotClass: 'bg-emerald-500 animate-pulse',
      daysSinceActive,
      isFrequent: true,
      isInactive: false,
    };
  }

  // 2. Frequent (Daily / Heavy users)
  // Active today, active in last 48h, streak >= 2, or regular daily usage
  if (isActiveToday || hoursSinceActive < 48 || streak >= 2 || (connectionCount >= 4 && daysSinceActive <= 3)) {
    return {
      segment: 'frequent',
      label: 'Très Actif (Quotidien)',
      sublabel: streak > 1 ? `Série ${streak}j 🔥` : (isActiveToday ? "Actif aujourd'hui" : 'Actif il y a 24-48h'),
      badgeClass: 'bg-teal-50 text-teal-800 dark:bg-teal-950/80 dark:text-teal-200 border-teal-300 dark:border-teal-800',
      dotClass: 'bg-teal-500',
      daysSinceActive,
      isFrequent: true,
      isInactive: false,
    };
  }

  // 3. Regular (Weekly active: connected in last 7 days)
  if (daysSinceActive <= 7) {
    return {
      segment: 'regular',
      label: 'Régulier (Semaine)',
      sublabel: `Actif il y a ${daysSinceActive === 0 ? '1' : daysSinceActive}j`,
      badgeClass: 'bg-sky-50 text-sky-800 dark:bg-sky-950/80 dark:text-sky-200 border-sky-300 dark:border-sky-800',
      dotClass: 'bg-sky-500',
      daysSinceActive,
      isFrequent: false,
      isInactive: false,
    };
  }

  // 4. Occasional (Connected in last 8-30 days)
  if (daysSinceActive <= 30) {
    return {
      segment: 'occasional',
      label: 'Occasionnel',
      sublabel: `Actif il y a ${daysSinceActive}j`,
      badgeClass: 'bg-amber-50 text-amber-800 dark:bg-amber-950/80 dark:text-amber-200 border-amber-300 dark:border-amber-800',
      dotClass: 'bg-amber-500',
      daysSinceActive,
      isFrequent: false,
      isInactive: false,
    };
  }

  // 5. Dormant (Account created without meaningful progress or usage)
  if (connectionCount <= 1 && qcmSolved === 0 && coursesCompleted === 0) {
    return {
      segment: 'dormant',
      label: 'Dormant (Jamais actif)',
      sublabel: '0 QCM · Compte non utilisé',
      badgeClass: 'bg-rose-50 text-rose-800 dark:bg-rose-950/80 dark:text-rose-200 border-rose-300 dark:border-rose-800',
      dotClass: 'bg-rose-500',
      daysSinceActive,
      isFrequent: false,
      isInactive: true,
    };
  }

  // 6. Inactive (> 30 days without connection)
  return {
    segment: 'inactive',
    label: `Inactif (${daysSinceActive}j)`,
    sublabel: 'Praticien à relancer',
    badgeClass: 'bg-slate-100 text-slate-700 dark:bg-slate-800 dark:text-slate-400 border-slate-300 dark:border-slate-700',
    dotClass: 'bg-slate-400',
    daysSinceActive,
    isFrequent: false,
    isInactive: true,
  };
}

interface UsersViewProps {
  users: AdminUserItem[];
  payments: PaymentItem[];
  licenses: AdminLicenseItem[];
  onUpdateUser: (updatedUser: AdminUserItem) => void;
}

export const UsersView: React.FC<UsersViewProps> = ({
  users,
  payments,
  licenses,
  onUpdateUser
}) => {
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedRole, setSelectedRole] = useState<string>('All');
  const [selectedTier, setSelectedTier] = useState<string>('All');
  const [selectedPlatform, setSelectedPlatform] = useState<string>('All');
  const [selectedActivitySegment, setSelectedActivitySegment] = useState<UserActivitySegment>('all');
  const [sortBy, setSortBy] = useState<string>('activity_recent');
  const [copiedContactId, setCopiedContactId] = useState<string | null>(null);
  const [selectedUserForDetails, setSelectedUserForDetails] = useState<AdminUserItem | null>(null);
  const [modalInitialTab, setModalInitialTab] = useState<'identity' | 'progress' | 'telemetry' | 'subscription' | 'payments' | 'licenses'>('identity');

  const roles = [
    'All',
    'Candidat Résidanat',
    'Médecin Généraliste',
    'Résident en Spécialité',
    'Spécialiste',
    'Étudiant en Médecine'
  ];

  const tiers = ['All', 'free', 'etudiant', 'clinical_pro', 'resident_elite', 'all_access'];

  // Global activity counts for top pills & KPI summary
  const activityCounts = {
    all: users.length,
    online: users.filter(u => getUserActivityInfo(u).segment === 'online').length,
    frequent: users.filter(u => getUserActivityInfo(u).segment === 'frequent').length,
    regular: users.filter(u => getUserActivityInfo(u).segment === 'regular').length,
    occasional: users.filter(u => getUserActivityInfo(u).segment === 'occasional').length,
    inactive: users.filter(u => getUserActivityInfo(u).segment === 'inactive').length,
    dormant: users.filter(u => getUserActivityInfo(u).segment === 'dormant').length,
  };

  const filteredUsers = users.filter((u) => {
    const matchesSearch = 
      u.fullName.toLowerCase().includes(searchQuery.toLowerCase()) ||
      u.email.toLowerCase().includes(searchQuery.toLowerCase()) ||
      u.faculty.toLowerCase().includes(searchQuery.toLowerCase()) ||
      (u.wilaya && u.wilaya.toLowerCase().includes(searchQuery.toLowerCase())) ||
      (u.phone && u.phone.includes(searchQuery));
    
    const matchesRole = selectedRole === 'All' || u.medicalRole === selectedRole;
    const matchesTier = selectedTier === 'All' || u.tier === selectedTier;

    // Platform filter
    let matchesPlatform = true;
    if (selectedPlatform !== 'All') {
      const platforms = u.telemetry?.platformsUsed || [];
      if (selectedPlatform === 'android') {
        matchesPlatform = platforms.includes('android') || platforms.includes('mobile');
      } else if (selectedPlatform === 'windows') {
        matchesPlatform = platforms.includes('windows');
      } else if (selectedPlatform === 'web') {
        matchesPlatform = platforms.includes('web');
      }
    }

    // Activity Segment filter
    if (selectedActivitySegment !== 'all') {
      const info = getUserActivityInfo(u);
      if (selectedActivitySegment === 'online' && info.segment !== 'online') return false;
      if (selectedActivitySegment === 'frequent' && info.segment !== 'frequent') return false;
      if (selectedActivitySegment === 'regular' && info.segment !== 'regular') return false;
      if (selectedActivitySegment === 'occasional' && info.segment !== 'occasional') return false;
      if (selectedActivitySegment === 'inactive' && info.segment !== 'inactive') return false;
      if (selectedActivitySegment === 'dormant' && info.segment !== 'dormant') return false;
    }

    return matchesSearch && matchesRole && matchesTier && matchesPlatform;
  });

  // Apply sorting
  const sortedUsers = [...filteredUsers].sort((a, b) => {
    if (sortBy === 'activity_recent') {
      const aOnline = a.telemetry?.isOnline ? 1 : 0;
      const bOnline = b.telemetry?.isOnline ? 1 : 0;
      if (aOnline !== bOnline) return bOnline - aOnline;
      const aTime = new Date(a.telemetry?.lastConnectionAt || a.updatedAt || a.createdAt).getTime();
      const bTime = new Date(b.telemetry?.lastConnectionAt || b.updatedAt || b.createdAt).getTime();
      return bTime - aTime;
    }
    if (sortBy === 'activity_frequent') {
      const aScore = (a.telemetry?.streakDays || 0) * 10 + (a.telemetry?.connectionCount || 0) + (a.progress?.totalQcmSolved || 0);
      const bScore = (b.telemetry?.streakDays || 0) * 10 + (b.telemetry?.connectionCount || 0) + (b.progress?.totalQcmSolved || 0);
      return bScore - aScore;
    }
    if (sortBy === 'activity_inactive') {
      const aInfo = getUserActivityInfo(a);
      const bInfo = getUserActivityInfo(b);
      return bInfo.daysSinceActive - aInfo.daysSinceActive;
    }
    if (sortBy === 'qcm_desc') {
      return (b.progress?.totalQcmSolved || 0) - (a.progress?.totalQcmSolved || 0);
    }
    if (sortBy === 'courses_desc') {
      return (b.progress?.totalCoursesCompleted || 0) - (a.progress?.totalCoursesCompleted || 0);
    }
    if (sortBy === 'name_asc') {
      return a.fullName.localeCompare(b.fullName);
    }
    return 0;
  });

  const getTierBadge = (tier: SubscriptionTier) => {
    switch (tier) {
      case 'all_access':
        return { label: 'All-Access VIP', bg: 'bg-amber-100 text-amber-800 dark:bg-amber-950/80 dark:text-amber-300 border-amber-300 dark:border-amber-800' };
      case 'resident_elite':
        return { label: 'Résident Élite', bg: 'bg-purple-100 text-purple-800 dark:bg-purple-950/80 dark:text-purple-300 border-purple-300 dark:border-purple-800' };
      case 'clinical_pro':
        return { label: 'Clinical Pro', bg: 'bg-sky-100 text-sky-800 dark:bg-sky-950/80 dark:text-sky-300 border-sky-300 dark:border-sky-800' };
      case 'etudiant':
        return { label: 'Étudiant', bg: 'bg-blue-100 text-blue-800 dark:bg-blue-950/80 dark:text-blue-300 border-blue-300 dark:border-blue-800' };
      default:
        return { label: 'Essai Gratuit', bg: 'bg-slate-100 text-slate-700 dark:bg-slate-800 dark:text-slate-400 border-slate-300 dark:border-slate-700' };
    }
  };

  const handleOpenDetails = (
    user: AdminUserItem, 
    tab: 'identity' | 'progress' | 'telemetry' | 'subscription' | 'payments' | 'licenses' = 'identity'
  ) => {
    setSelectedUserForDetails(user);
    setModalInitialTab(tab);
  };

  const handleUserUpdatedFromModal = (updated: AdminUserItem) => {
    onUpdateUser(updated);
    setSelectedUserForDetails(updated);
  };

  const [extendingUserId, setExtendingUserId] = useState<string | null>(null);

  const formatExpirationDisplay = (expiresAt?: string) => {
    if (!expiresAt) {
      return {
        formattedDate: 'Accès Illimité',
        badgeText: 'Permanent',
        status: 'lifetime' as const,
        daysLeft: 9999,
      };
    }

    try {
      const expDate = new Date(expiresAt);
      if (isNaN(expDate.getTime())) {
        return {
          formattedDate: expiresAt,
          badgeText: expiresAt,
          status: 'active' as const,
          daysLeft: 0,
        };
      }

      const formattedDate = expDate.toLocaleDateString('fr-FR', {
        day: '2-digit',
        month: 'short',
        year: 'numeric',
      });

      const now = Date.now();
      const diffMs = expDate.getTime() - now;
      const daysLeft = Math.ceil(diffMs / (1000 * 60 * 60 * 24));

      if (daysLeft < 0) {
        return {
          formattedDate,
          badgeText: `Expiré (${Math.abs(daysLeft)}j)`,
          status: 'expired' as const,
          daysLeft,
        };
      }

      if (daysLeft <= 7) {
        return {
          formattedDate,
          badgeText: daysLeft === 0 ? "Expire aujourd'hui" : `Dans ${daysLeft}j`,
          status: 'warning' as const,
          daysLeft,
        };
      }

      return {
        formattedDate,
        badgeText: `${daysLeft}j restants`,
        status: 'active' as const,
        daysLeft,
      };
    } catch {
      return {
        formattedDate: expiresAt || 'Accès Illimité',
        badgeText: 'Actif',
        status: 'active' as const,
        daysLeft: 30,
      };
    }
  };

  const handleQuickExtend = async (user: AdminUserItem, daysToAdd: number = 30) => {
    try {
      setExtendingUserId(user.id);
      const currentExpiry = user.expiresAt ? new Date(user.expiresAt) : new Date();
      const baseDate = currentExpiry.getTime() < Date.now() ? new Date() : currentExpiry;
      const newExp = new Date(baseDate.getTime() + daysToAdd * 24 * 60 * 60 * 1000);
      const newExpIso = newExp.toISOString();

      const updatedUser: AdminUserItem = {
        ...user,
        expiresAt: newExpIso,
        status: 'active',
      };

      onUpdateUser(updatedUser);

      // Persist to Supabase
      await updateUserProfileInSupabase(user.id, {
        expiresAt: newExpIso,
        status: 'active',
        tier: user.tier || 'all_access',
      });
    } catch (e) {
      console.error('Error extending subscription:', e);
    } finally {
      setExtendingUserId(null);
    }
  };

  const handleCopyContact = (user: AdminUserItem, e: React.MouseEvent) => {
    e.stopPropagation();
    const contact = user.phone ? `${user.fullName} (${user.email} - ${user.phone})` : `${user.fullName} (${user.email})`;
    navigator.clipboard.writeText(contact);
    setCopiedContactId(user.id);
    setTimeout(() => setCopiedContactId(null), 2000);
  };

  const formatRelativeTime = (isoString?: string) => {
    if (!isoString) return 'Inconnue';
    try {
      const ms = Date.now() - new Date(isoString).getTime();
      if (ms < 0) return "À l'instant";
      const mins = Math.floor(ms / (1000 * 60));
      if (mins < 2) return "À l'instant";
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

  const onlineCount = activityCounts.online;
  const activeTodayCount = users.filter(u => u.telemetry?.isActiveToday).length;

  return (
    <div className="space-y-5">
      {/* View Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-2 border-b border-slate-200 dark:border-slate-800">
        <div>
          <h1 className="text-xl md:text-2xl font-bold tracking-tight text-slate-900 dark:text-white flex items-center gap-2">
            <span>Médecins & Comptes Utilisateurs</span>
            {onlineCount > 0 && (
              <span className="flex items-center gap-1.5 px-2.5 py-0.5 text-xs font-bold bg-emerald-50 text-emerald-700 dark:bg-emerald-950/80 dark:text-emerald-300 border border-emerald-300 dark:border-emerald-800 rounded-full">
                <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse" />
                {onlineCount} en ligne
              </span>
            )}
          </h1>
          <p className="text-xs md:text-sm text-slate-500 dark:text-slate-400 mt-0.5">
            Supervision 360°, suivi de l'usage en temps réel (PDFs lus, QCMs résolus), segmentation actifs/fréquents/inactifs et accès multi-plateformes.
          </p>
        </div>

        <div className="flex items-center gap-3 text-xs font-mono text-slate-500 dark:text-slate-400">
          <span>Actifs aujourd'hui : <strong className="text-emerald-600 dark:text-emerald-400 font-bold">{activeTodayCount}</strong></span>
          <span>·</span>
          <span>Total : <strong className="text-slate-900 dark:text-white">{sortedUsers.length} / {users.length}</strong></span>
        </div>
      </div>

      {/* --- 4 INTERACTIVE ACTIVITY & ENGAGEMENT KPI CARDS --- */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-3">
        {/* Card 1: En ligne & Aujourd'hui */}
        <div 
          onClick={() => setSelectedActivitySegment(selectedActivitySegment === 'online' ? 'all' : 'online')}
          className={`p-3.5 rounded-xl border transition-all cursor-pointer relative overflow-hidden ${
            selectedActivitySegment === 'online'
              ? 'bg-emerald-50 dark:bg-emerald-950/40 border-emerald-500 ring-2 ring-emerald-500/30'
              : 'bg-white dark:bg-slate-900 border-slate-200 dark:border-slate-800 hover:border-emerald-300'
          }`}
        >
          <div className="flex items-center justify-between">
            <span className="text-[11px] font-bold text-emerald-800 dark:text-emerald-200 flex items-center gap-1.5">
              <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse" />
              <span>En Ligne Live</span>
            </span>
            <span className="text-[10px] font-bold px-1.5 py-0.2 rounded bg-emerald-100 text-emerald-800 dark:bg-emerald-900/60 dark:text-emerald-300">
              Live
            </span>
          </div>
          <p className="text-xl sm:text-2xl font-extrabold font-mono text-emerald-900 dark:text-emerald-100 mt-1.5">
            {activityCounts.online} <span className="text-xs font-normal text-slate-500">connectés</span>
          </p>
          <p className="text-[10.5px] text-emerald-700 dark:text-emerald-300 mt-1 font-medium">
            {activeTodayCount} actif(s) sur les dernières 24h
          </p>
        </div>

        {/* Card 2: Très Actifs (Quotidien & Fréquents) */}
        <div 
          onClick={() => setSelectedActivitySegment(selectedActivitySegment === 'frequent' ? 'all' : 'frequent')}
          className={`p-3.5 rounded-xl border transition-all cursor-pointer relative overflow-hidden ${
            selectedActivitySegment === 'frequent'
              ? 'bg-teal-50 dark:bg-teal-950/40 border-teal-500 ring-2 ring-teal-500/30'
              : 'bg-white dark:bg-slate-900 border-slate-200 dark:border-slate-800 hover:border-teal-300'
          }`}
        >
          <div className="flex items-center justify-between">
            <span className="text-[11px] font-bold text-teal-800 dark:text-teal-200 flex items-center gap-1.5">
              <Flame className="w-3.5 h-3.5 text-teal-600 dark:text-teal-400" />
              <span>Très Actifs (Fréquents)</span>
            </span>
            <span className="text-[10px] font-bold px-1.5 py-0.2 rounded bg-teal-100 text-teal-800 dark:bg-teal-900/60 dark:text-teal-300">
              Assidus
            </span>
          </div>
          <p className="text-xl sm:text-2xl font-extrabold font-mono text-teal-900 dark:text-teal-100 mt-1.5">
            {activityCounts.frequent} <span className="text-xs font-normal text-slate-500">médecins</span>
          </p>
          <p className="text-[10.5px] text-teal-700 dark:text-teal-300 mt-1 font-medium">
            Utilisent l'app souvent (Série & QCMs)
          </p>
        </div>

        {/* Card 3: Réguliers (Semaine) */}
        <div 
          onClick={() => setSelectedActivitySegment(selectedActivitySegment === 'regular' ? 'all' : 'regular')}
          className={`p-3.5 rounded-xl border transition-all cursor-pointer relative overflow-hidden ${
            selectedActivitySegment === 'regular'
              ? 'bg-sky-50 dark:bg-sky-950/40 border-sky-500 ring-2 ring-sky-500/30'
              : 'bg-white dark:bg-slate-900 border-slate-200 dark:border-slate-800 hover:border-sky-300'
          }`}
        >
          <div className="flex items-center justify-between">
            <span className="text-[11px] font-bold text-sky-800 dark:text-sky-200 flex items-center gap-1.5">
              <Zap className="w-3.5 h-3.5 text-sky-600 dark:text-sky-400" />
              <span>Réguliers (7 jours)</span>
            </span>
            <span className="text-[10px] font-bold px-1.5 py-0.2 rounded bg-sky-100 text-sky-800 dark:bg-sky-900/60 dark:text-sky-300">
              Hebdo
            </span>
          </div>
          <p className="text-xl sm:text-2xl font-extrabold font-mono text-sky-900 dark:text-sky-100 mt-1.5">
            {activityCounts.regular} <span className="text-xs font-normal text-slate-500">médecins</span>
          </p>
          <p className="text-[10.5px] text-sky-700 dark:text-sky-300 mt-1 font-medium">
            Connectés au cours des 7 derniers jours
          </p>
        </div>

        {/* Card 4: Inactifs & Dormants (À relancer) */}
        <div 
          onClick={() => setSelectedActivitySegment(selectedActivitySegment === 'inactive' ? 'all' : 'inactive')}
          className={`p-3.5 rounded-xl border transition-all cursor-pointer relative overflow-hidden ${
            selectedActivitySegment === 'inactive' || selectedActivitySegment === 'dormant'
              ? 'bg-slate-100 dark:bg-slate-800/80 border-slate-400 ring-2 ring-slate-400/30'
              : 'bg-white dark:bg-slate-900 border-slate-200 dark:border-slate-800 hover:border-slate-400'
          }`}
        >
          <div className="flex items-center justify-between">
            <span className="text-[11px] font-bold text-slate-700 dark:text-slate-300 flex items-center gap-1.5">
              <UserX className="w-3.5 h-3.5 text-slate-500 dark:text-slate-400" />
              <span>Inactifs & Dormants</span>
            </span>
            <span className="text-[10px] font-bold px-1.5 py-0.2 rounded bg-slate-200 dark:bg-slate-800 text-slate-700 dark:text-slate-300">
              À Relancer
            </span>
          </div>
          <p className="text-xl sm:text-2xl font-extrabold font-mono text-slate-900 dark:text-slate-100 mt-1.5">
            {activityCounts.inactive + activityCounts.dormant} <span className="text-xs font-normal text-slate-500">comptes</span>
          </p>
          <p className="text-[10.5px] text-slate-500 dark:text-slate-400 mt-1 font-medium truncate">
            {activityCounts.dormant} dormants (0 QCM) · {activityCounts.inactive} sans accès &gt;30j
          </p>
        </div>
      </div>

      {/* --- QUICK SEGMENT TABS / PILLS BAR --- */}
      <div className="flex items-center gap-1.5 overflow-x-auto pb-1 scrollbar-none">
        <button
          onClick={() => setSelectedActivitySegment('all')}
          className={`px-3 py-1.5 rounded-lg text-xs font-bold transition-all shrink-0 cursor-pointer ${
            selectedActivitySegment === 'all'
              ? 'bg-slate-900 text-white dark:bg-white dark:text-slate-900 shadow-2xs'
              : 'bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300 hover:bg-slate-200 dark:hover:bg-slate-700'
          }`}
        >
          Tous ({activityCounts.all})
        </button>

        <button
          onClick={() => setSelectedActivitySegment('online')}
          className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-bold transition-all shrink-0 cursor-pointer ${
            selectedActivitySegment === 'online'
              ? 'bg-emerald-600 text-white shadow-2xs'
              : 'bg-emerald-50 text-emerald-800 dark:bg-emerald-950/60 dark:text-emerald-300 hover:bg-emerald-100 border border-emerald-200/80 dark:border-emerald-800'
          }`}
        >
          <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse" />
          <span>En Ligne ({activityCounts.online})</span>
        </button>

        <button
          onClick={() => setSelectedActivitySegment('frequent')}
          className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-bold transition-all shrink-0 cursor-pointer ${
            selectedActivitySegment === 'frequent'
              ? 'bg-teal-600 text-white shadow-2xs'
              : 'bg-teal-50 text-teal-800 dark:bg-teal-950/60 dark:text-teal-300 hover:bg-teal-100 border border-teal-200/80 dark:border-teal-800'
          }`}
        >
          <Flame className="w-3.5 h-3.5 text-orange-500" />
          <span>Très Actifs / Fréquents ({activityCounts.frequent})</span>
        </button>

        <button
          onClick={() => setSelectedActivitySegment('regular')}
          className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-bold transition-all shrink-0 cursor-pointer ${
            selectedActivitySegment === 'regular'
              ? 'bg-sky-600 text-white shadow-2xs'
              : 'bg-sky-50 text-sky-800 dark:bg-sky-950/60 dark:text-sky-300 hover:bg-sky-100 border border-sky-200/80 dark:border-sky-800'
          }`}
        >
          <Zap className="w-3.5 h-3.5" />
          <span>Réguliers (7j) ({activityCounts.regular})</span>
        </button>

        <button
          onClick={() => setSelectedActivitySegment('occasional')}
          className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-bold transition-all shrink-0 cursor-pointer ${
            selectedActivitySegment === 'occasional'
              ? 'bg-amber-600 text-white shadow-2xs'
              : 'bg-amber-50 text-amber-800 dark:bg-amber-950/60 dark:text-amber-300 hover:bg-amber-100 border border-amber-200/80 dark:border-amber-800'
          }`}
        >
          <Clock className="w-3.5 h-3.5" />
          <span>Occasionnels ({activityCounts.occasional})</span>
        </button>

        <button
          onClick={() => setSelectedActivitySegment('inactive')}
          className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-bold transition-all shrink-0 cursor-pointer ${
            selectedActivitySegment === 'inactive'
              ? 'bg-slate-700 text-white shadow-2xs'
              : 'bg-slate-100 text-slate-700 dark:bg-slate-800 dark:text-slate-300 hover:bg-slate-200 border border-slate-200 dark:border-slate-700'
          }`}
        >
          <UserX className="w-3.5 h-3.5" />
          <span>Inactifs (&gt;30j) ({activityCounts.inactive})</span>
        </button>

        <button
          onClick={() => setSelectedActivitySegment('dormant')}
          className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-bold transition-all shrink-0 cursor-pointer ${
            selectedActivitySegment === 'dormant'
              ? 'bg-rose-600 text-white shadow-2xs'
              : 'bg-rose-50 text-rose-800 dark:bg-rose-950/60 dark:text-rose-300 hover:bg-rose-100 border border-rose-200/80 dark:border-rose-800'
          }`}
        >
          <AlertTriangle className="w-3.5 h-3.5" />
          <span>Dormants (0 session) ({activityCounts.dormant})</span>
        </button>
      </div>

      {/* Filter, Search & Sorting Bar */}
      <div className="p-3 bg-white dark:bg-slate-900 rounded-xl border border-slate-200 dark:border-slate-800 shadow-2xs flex flex-col lg:flex-row lg:items-center justify-between gap-3">
        {/* Search Input */}
        <div className="relative flex-1">
          <Search className="w-4 h-4 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Rechercher nom, email, faculté (Alger, Blida, Constantine...), wilaya, téléphone..."
            className="w-full pl-9 pr-4 py-2 text-xs bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg text-slate-900 dark:text-white placeholder-slate-400 focus:outline-none focus:ring-1 focus:ring-teal-500"
          />
        </div>

        <div className="flex flex-wrap items-center gap-2">
          {/* Sorting Dropdown */}
          <div className="flex items-center gap-1 px-2.5 py-1.5 bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg">
            <ArrowUpDown className="w-3.5 h-3.5 text-slate-400 shrink-0" />
            <select
              value={sortBy}
              onChange={(e) => setSortBy(e.target.value)}
              className="text-xs bg-transparent text-slate-700 dark:text-slate-200 focus:outline-none cursor-pointer"
            >
              <option value="activity_recent">Dernière activité (Plus récent)</option>
              <option value="activity_frequent">Fréquence d'usage (Assiduité)</option>
              <option value="activity_inactive">Inactifs d'abord (Pour relance)</option>
              <option value="qcm_desc">QCMs résolus (Décroissant)</option>
              <option value="courses_desc">Supports PDF lus (Décroissant)</option>
              <option value="name_asc">Nom alphabétique (A-Z)</option>
            </select>
          </div>

          {/* Platform Filter */}
          <select
            value={selectedPlatform}
            onChange={(e) => setSelectedPlatform(e.target.value)}
            className="px-3 py-2 text-xs bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg text-slate-700 dark:text-slate-200 focus:outline-none cursor-pointer"
          >
            <option value="All">Toutes les plateformes</option>
            <option value="android">📱 Application Mobile (Android)</option>
            <option value="windows">💻 Application PC (Windows)</option>
            <option value="web">🌐 Plateforme Web en ligne</option>
          </select>

          {/* Role Dropdown */}
          <select
            value={selectedRole}
            onChange={(e) => setSelectedRole(e.target.value)}
            className="px-3 py-2 text-xs bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg text-slate-700 dark:text-slate-200 focus:outline-none cursor-pointer"
          >
            {roles.map((r) => (
              <option key={r} value={r}>{r === 'All' ? 'Tous les rôles médicaux' : r}</option>
            ))}
          </select>

          {/* Tier Dropdown */}
          <select
            value={selectedTier}
            onChange={(e) => setSelectedTier(e.target.value)}
            className="px-3 py-2 text-xs bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg text-slate-700 dark:text-slate-200 focus:outline-none cursor-pointer"
          >
            <option value="All">Toutes les formules</option>
            <option value="all_access">All-Access VIP</option>
            <option value="resident_elite">Résident Élite</option>
            <option value="clinical_pro">Clinical Pro</option>
            <option value="etudiant">Formule Étudiant</option>
            <option value="free">Essai Gratuit</option>
          </select>
        </div>
      </div>

      {/* Mobile Card List (< md screens) */}
      <div className="block md:hidden space-y-3.5">
        {sortedUsers.length === 0 ? (
          <div className="p-6 text-center text-xs text-slate-400 bg-white dark:bg-slate-900 rounded-xl border border-slate-200 dark:border-slate-800">
            Aucun médecin trouvé pour ce filtre d'activité ou recherche.
          </div>
        ) : (
          sortedUsers.map((user) => {
            const tierInfo = getTierBadge(user.tier);
            const userActivity = getUserActivityInfo(user);
            const platforms = user.telemetry?.platformsUsed || ['android'];
            const resolvedYear = resolveStudyYear(user, user);
            const expInfo = formatExpirationDisplay(user.expiresAt);
            const isExtending = extendingUserId === user.id;

            return (
              <div
                key={user.id}
                onClick={() => handleOpenDetails(user, 'identity')}
                className={`p-4 bg-white dark:bg-slate-900 rounded-2xl border shadow-xs hover:shadow-md transition-all cursor-pointer space-y-3 ${
                  userActivity.segment === 'online'
                    ? 'border-emerald-300 dark:border-emerald-800/80 ring-1 ring-emerald-500/20'
                    : (userActivity.isInactive ? 'border-slate-200 dark:border-slate-800 opacity-90' : 'border-slate-200 dark:border-slate-800')
                }`}
              >
                {/* Header: Avatar, Name, Email, Tier Badge */}
                <div className="flex items-start justify-between gap-3">
                  <div className="flex items-center gap-3 min-w-0">
                    <div className="relative shrink-0">
                      <div className="w-11 h-11 rounded-full bg-slate-100 dark:bg-slate-800 flex items-center justify-center overflow-hidden ring-2 ring-slate-200 dark:ring-slate-700 shadow-2xs">
                        {user.avatarUrl ? (
                          <img src={user.avatarUrl} alt="" className="w-full h-full object-cover" />
                        ) : (
                          <span className="font-bold text-xs text-teal-800 dark:text-teal-200 font-mono">
                            {user.fullName.slice(0, 2).toUpperCase()}
                          </span>
                        )}
                      </div>
                      {/* Realtime presence dot */}
                      <span 
                        className={`absolute -bottom-0.5 -right-0.5 w-3.5 h-3.5 rounded-full border-2 border-white dark:border-slate-900 ${userActivity.dotClass}`}
                        title={userActivity.label}
                      />
                    </div>

                    <div className="min-w-0 flex-1">
                      <div className="flex items-center gap-1.5 flex-wrap">
                        <h3 className="font-bold text-sm text-slate-900 dark:text-white truncate">
                          {user.fullName}
                        </h3>
                        {user.isAdmin && (
                          <span className="text-[9px] font-mono font-bold text-teal-600 dark:text-teal-400 bg-teal-50 dark:bg-teal-950/80 px-1.5 py-0.5 rounded border border-teal-200 dark:border-teal-800">
                            ADMIN
                          </span>
                        )}
                        {user.isBanned && (
                          <span className="text-[9px] font-mono font-bold text-rose-600 dark:text-rose-400 bg-rose-50 dark:bg-rose-950/80 px-1.5 py-0.5 rounded border border-rose-200 dark:border-rose-800">
                            BANNI
                          </span>
                        )}
                      </div>
                      <p className="text-[11px] text-slate-500 dark:text-slate-400 font-mono truncate mt-0.5">
                        {user.email}
                      </p>
                    </div>
                  </div>

                  {/* Plan badge */}
                  <span className={`inline-flex items-center px-2 py-0.5 rounded-md text-[10.5px] font-bold border shrink-0 shadow-2xs ${tierInfo.bg}`}>
                    {tierInfo.label}
                  </span>
                </div>

                {/* Activity & Frequency Status Bar (CLEARLY HIGHLIGHTED) */}
                <div className="flex items-center justify-between text-xs p-2 rounded-xl bg-slate-50 dark:bg-slate-800/50 border border-slate-200/70 dark:border-slate-800">
                  <div className="flex items-center gap-2">
                    <span className={`inline-flex items-center gap-1.5 px-2 py-0.5 rounded-full text-[10.5px] font-bold border ${userActivity.badgeClass}`}>
                      <span className={`w-1.5 h-1.5 rounded-full ${userActivity.dotClass}`} />
                      <span>{userActivity.label}</span>
                    </span>
                    <span className="text-[11px] text-slate-600 dark:text-slate-300 font-medium truncate">
                      {userActivity.sublabel}
                    </span>
                  </div>
                  <span className="text-[10px] text-slate-400 font-mono shrink-0">
                    {formatRelativeTime(user.telemetry?.lastConnectionAt || user.createdAt)}
                  </span>
                </div>

                {/* Role & Academic Year */}
                <div className="flex items-center justify-between text-xs pt-1 border-t border-slate-100 dark:border-slate-800">
                  <div className="flex items-center gap-1.5 text-slate-800 dark:text-slate-200 font-semibold truncate">
                    <Stethoscope className="w-3.5 h-3.5 text-teal-600 dark:text-teal-400 shrink-0" />
                    <span className="truncate">{user.medicalRole || 'Médecin Praticien'}</span>
                    {resolvedYear && (
                      <span className="text-[10.5px] font-bold text-teal-700 dark:text-teal-300 shrink-0 bg-teal-50 dark:bg-teal-950/80 px-1.5 py-0.5 rounded border border-teal-200 dark:border-teal-800/80">
                        {resolvedYear}e Année
                      </span>
                    )}
                  </div>
                  {user.wilaya && (
                    <span className="text-[11px] text-slate-500 dark:text-slate-400 font-medium shrink-0">
                      📍 {user.wilaya}
                    </span>
                  )}
                </div>

                {/* Faculté de Médecine: HIGH CONTRAST & CLEARLY VISIBLE */}
                <div className="p-2.5 rounded-xl bg-slate-50 dark:bg-slate-800/60 border border-slate-200/80 dark:border-slate-800 flex items-center gap-2.5">
                  <div className="p-1.5 rounded-lg bg-teal-50 dark:bg-teal-950 text-teal-700 dark:text-teal-300 shrink-0 shadow-2xs border border-teal-200 dark:border-teal-800">
                    <GraduationCap className="w-4 h-4" />
                  </div>
                  <div className="min-w-0 flex-1">
                    <span className="text-[10px] uppercase font-bold tracking-wider text-teal-700 dark:text-teal-300 block leading-tight">
                      Faculté de rattachement
                    </span>
                    <p className="text-xs font-bold text-slate-900 dark:text-slate-100 truncate mt-0.5">
                      {user.faculty && user.faculty.trim().length > 0 ? user.faculty : 'Faculté non spécifiée'}
                    </p>
                  </div>
                </div>

                {/* Progress & Platforms Badges */}
                <div className="flex items-center justify-between text-xs pt-1 border-t border-slate-100 dark:border-slate-800/60">
                  <div className="flex items-center gap-1.5 text-slate-600 dark:text-slate-300 font-medium">
                    <span className="font-mono text-teal-600 dark:text-teal-400 font-bold bg-teal-50 dark:bg-teal-950/60 px-1.5 py-0.5 rounded text-[11px]">
                      {user.progress?.totalQcmSolved || 0} QCM
                    </span>
                    <span className="font-mono text-indigo-600 dark:text-indigo-400 font-bold bg-indigo-50 dark:bg-indigo-950/60 px-1.5 py-0.5 rounded text-[11px]">
                      {user.progress?.totalCoursesCompleted || 0} PDF
                    </span>
                    {(user.telemetry?.streakDays || 0) > 0 && (
                      <span className="text-orange-500 font-bold text-[11px] flex items-center gap-0.5">
                        <Flame className="w-3 h-3 inline" />
                        {user.telemetry?.streakDays}j
                      </span>
                    )}
                  </div>

                  {/* Platforms Icons */}
                  <div className="flex items-center gap-1">
                    {(platforms.includes('android') || platforms.includes('mobile')) && (
                      <span className="p-1 rounded bg-emerald-50 text-emerald-700 dark:bg-emerald-950/60 dark:text-emerald-300 border border-emerald-200 dark:border-emerald-800" title="Application Mobile Android">
                        <Smartphone className="w-3 h-3" />
                      </span>
                    )}
                    {platforms.includes('windows') && (
                      <span className="p-1 rounded bg-sky-50 text-sky-700 dark:bg-sky-950/60 dark:text-sky-300 border border-sky-200 dark:border-sky-800" title="Application PC Windows">
                        <Monitor className="w-3 h-3" />
                      </span>
                    )}
                    {platforms.includes('web') && (
                      <span className="p-1 rounded bg-indigo-50 text-indigo-700 dark:bg-indigo-950/60 dark:text-indigo-300 border border-indigo-200 dark:border-indigo-800" title="Plateforme Web">
                        <Globe className="w-3 h-3" />
                      </span>
                    )}
                  </div>
                </div>

                {/* Expiration Date & Actions (PROPERLY FORMATTED & HIGH CONTRAST) */}
                <div className="flex items-center justify-between pt-2 border-t border-slate-100 dark:border-slate-800 gap-2">
                  <div className="flex items-center gap-1.5 min-w-0">
                    <Calendar className="w-3.5 h-3.5 text-slate-400 shrink-0" />
                    <div className="min-w-0">
                      <div className="flex items-center gap-1.5 flex-wrap">
                        <span className="text-[11px] text-slate-500 dark:text-slate-400 font-medium">
                          Expire le :
                        </span>
                        <span className={`text-xs font-bold font-mono ${
                          expInfo.status === 'expired' 
                            ? 'text-rose-600 dark:text-rose-400' 
                            : expInfo.status === 'warning'
                              ? 'text-amber-600 dark:text-amber-400'
                              : 'text-emerald-600 dark:text-emerald-400'
                        }`}>
                          {expInfo.formattedDate}
                        </span>
                        <span className={`text-[9.5px] font-semibold px-1.5 py-0.2 rounded-full border ${
                          expInfo.status === 'expired'
                            ? 'bg-rose-50 text-rose-700 dark:bg-rose-950 dark:text-rose-300 border-rose-200 dark:border-rose-800'
                            : expInfo.status === 'warning'
                              ? 'bg-amber-50 text-amber-700 dark:bg-amber-950 dark:text-amber-300 border-amber-200 dark:border-amber-800'
                              : 'bg-emerald-50 text-emerald-700 dark:bg-emerald-950 dark:text-emerald-300 border-emerald-200 dark:border-emerald-800'
                        }`}>
                          {expInfo.badgeText}
                        </span>
                      </div>
                    </div>
                  </div>

                  {/* Action buttons: Relancer, +30j & Gérer */}
                  <div className="flex items-center gap-1.5 shrink-0">
                    {userActivity.isInactive && (
                      <button
                        onClick={(e) => handleCopyContact(user, e)}
                        title="Copier les coordonnées pour relance email / tél"
                        className="px-2 py-1 bg-amber-50 hover:bg-amber-100 dark:bg-amber-950/80 text-amber-800 dark:text-amber-200 rounded-lg text-xs font-bold transition-colors cursor-pointer border border-amber-200 dark:border-amber-800 flex items-center gap-1"
                      >
                        {copiedContactId === user.id ? <Check className="w-3 h-3 text-emerald-600" /> : <Copy className="w-3 h-3" />}
                        <span>{copiedContactId === user.id ? 'Copié' : 'Relancer'}</span>
                      </button>
                    )}
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        handleQuickExtend(user, 30);
                      }}
                      disabled={isExtending}
                      title="Prolonger l'accès VIP de 30 jours"
                      className="px-2.5 py-1 bg-slate-100 hover:bg-slate-200 dark:bg-slate-800 dark:hover:bg-slate-700 text-slate-800 dark:text-slate-200 rounded-lg text-xs font-bold transition-colors cursor-pointer border border-slate-200 dark:border-slate-700 disabled:opacity-50"
                    >
                      {isExtending ? '...' : '+30j'}
                    </button>
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        handleOpenDetails(user, 'identity');
                      }}
                      className="px-3 py-1 bg-teal-600 hover:bg-teal-700 text-white rounded-lg text-xs font-semibold transition-colors cursor-pointer shadow-2xs"
                    >
                      Gérer
                    </button>
                  </div>
                </div>
              </div>
            );
          })
        )}
      </div>

      {/* Desktop Users Table (>= md screens) */}
      <div className="hidden md:block bg-white dark:bg-slate-900 rounded-xl border border-slate-200 dark:border-slate-800 shadow-2xs overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-xs text-left">
            <thead className="bg-slate-50 dark:bg-slate-800/60 text-slate-500 dark:text-slate-400 border-b border-slate-200 dark:border-slate-800">
              <tr>
                <th className="py-3 px-4 font-semibold">Médecin / Praticien</th>
                <th className="py-3 px-4 font-semibold">Activité & Fréquence</th>
                <th className="py-3 px-4 font-semibold">Rôle & Cursus</th>
                <th className="py-3 px-4 font-semibold">Faculté & Wilaya</th>
                <th className="py-3 px-4 font-semibold">Accès Plateformes</th>
                <th className="py-3 px-4 font-semibold">Usage & Progression</th>
                <th className="py-3 px-4 font-semibold">Validité & Formule</th>
                <th className="py-3 px-4 font-semibold text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-200 dark:divide-slate-800">
              {sortedUsers.map((user) => {
                const tierInfo = getTierBadge(user.tier);
                const userActivity = getUserActivityInfo(user);
                const platforms = user.telemetry?.platformsUsed || ['android'];
                const resolvedYear = resolveStudyYear(user, user);
                const expInfo = formatExpirationDisplay(user.expiresAt);
                const isExtending = extendingUserId === user.id;

                return (
                  <tr 
                    key={user.id} 
                    className="hover:bg-slate-50/70 dark:hover:bg-slate-800/40 transition-colors cursor-pointer"
                    onClick={() => handleOpenDetails(user, 'identity')}
                  >
                    {/* User Identity Column */}
                    <td className="py-3.5 px-4">
                      <div className="flex items-center gap-3">
                        <div className="relative shrink-0">
                          <div className="w-8 h-8 rounded-full bg-slate-200 dark:bg-slate-700 overflow-hidden ring-1 ring-slate-300 dark:ring-slate-700">
                            {user.avatarUrl ? (
                              <img src={user.avatarUrl} alt="" className="w-full h-full object-cover" />
                            ) : (
                              <div className="w-full h-full flex items-center justify-center font-bold text-slate-600 dark:text-slate-300">
                                {user.fullName.slice(0, 2).toUpperCase()}
                              </div>
                            )}
                          </div>
                          {/* Live presence dot */}
                          <span 
                            className={`absolute -bottom-0.5 -right-0.5 w-2.5 h-2.5 rounded-full border border-white dark:border-slate-900 ${userActivity.dotClass}`}
                            title={userActivity.label}
                          />
                        </div>

                        <div className="min-w-0">
                          <div className="flex items-center gap-1.5">
                            <span className="font-bold text-slate-900 dark:text-white truncate">
                              {user.fullName}
                            </span>
                            {user.isAdmin && (
                              <span className="text-[10px] font-mono font-bold text-teal-600 dark:text-teal-400 bg-teal-50 dark:bg-teal-950 px-1 py-0.2 rounded">
                                ADMIN
                              </span>
                            )}
                            {user.isBanned && (
                              <span className="text-[10px] font-mono font-bold text-rose-600 dark:text-rose-400 bg-rose-50 dark:bg-rose-950 px-1 py-0.2 rounded">
                                BANNI
                              </span>
                            )}
                          </div>
                          <span className="text-[11px] text-slate-500 dark:text-slate-400 font-mono">
                            {user.email}
                          </span>
                        </div>
                      </div>
                    </td>

                    {/* NEW: Activité & Fréquence d'utilisation Column */}
                    <td className="py-3.5 px-4">
                      <div className="space-y-1">
                        <span className={`inline-flex items-center gap-1.5 px-2 py-0.5 rounded-full text-[10.5px] font-bold border ${userActivity.badgeClass}`}>
                          <span className={`w-1.5 h-1.5 rounded-full ${userActivity.dotClass}`} />
                          <span>{userActivity.label}</span>
                        </span>
                        <div className="text-[11px] text-slate-600 dark:text-slate-300 font-medium">
                          {userActivity.sublabel}
                        </div>
                        <div className="text-[10px] text-slate-400 font-mono">
                          {formatRelativeTime(user.telemetry?.lastConnectionAt || user.createdAt)}
                          <span className="mx-1">·</span>
                          {user.telemetry?.connectionCount || 1} session(s)
                        </div>
                      </div>
                    </td>

                    {/* Medical Role Column */}
                    <td className="py-3.5 px-4">
                      <p className="font-semibold text-slate-800 dark:text-slate-200">
                        {user.medicalRole}
                      </p>
                      <p className="text-[11px] text-teal-600 dark:text-teal-400 font-medium">
                        {resolvedYear ? `${resolvedYear}${resolvedYear === 1 ? 'ère' : 'ème'} Année Cursus` : (user.residencyTargetYear ? `Cible : ${user.residencyTargetYear}` : 'Diplômé / Résident')}
                      </p>
                    </td>

                    {/* Faculté & Wilaya Column (CLEARLY VISIBLE) */}
                    <td className="py-3.5 px-4">
                      <div className="flex items-center gap-1.5">
                        <GraduationCap className="w-3.5 h-3.5 text-teal-600 dark:text-teal-400 shrink-0" />
                        <span className="font-semibold text-slate-800 dark:text-slate-200 truncate max-w-[180px]">
                          {user.faculty && user.faculty.trim().length > 0 ? user.faculty : 'Faculté non spécifiée'}
                        </span>
                      </div>
                      {user.wilaya && (
                        <span className="text-[10.5px] text-slate-500 dark:text-slate-400 font-medium ml-5 block">
                          📍 {user.wilaya}
                        </span>
                      )}
                    </td>

                    {/* Platforms Used Column (Web, Windows, Mobile) */}
                    <td className="py-3.5 px-4">
                      <div className="flex items-center gap-1.5">
                        {(platforms.includes('android') || platforms.includes('mobile')) && (
                          <span 
                            className="p-1 rounded-md bg-emerald-50 text-emerald-700 dark:bg-emerald-950/60 dark:text-emerald-300 border border-emerald-200 dark:border-emerald-800"
                            title="Application Mobile Android APK"
                          >
                            <Smartphone className="w-3.5 h-3.5" />
                          </span>
                        )}
                        {platforms.includes('windows') && (
                          <span 
                            className="p-1 rounded-md bg-sky-50 text-sky-700 dark:bg-sky-950/60 dark:text-sky-300 border border-sky-200 dark:border-sky-800"
                            title="Application Bureau Windows PC"
                          >
                            <Monitor className="w-3.5 h-3.5" />
                          </span>
                        )}
                        {platforms.includes('web') && (
                          <span 
                            className="p-1 rounded-md bg-indigo-50 text-indigo-700 dark:bg-indigo-950/60 dark:text-indigo-300 border border-indigo-200 dark:border-indigo-800"
                            title="Plateforme Web en ligne"
                          >
                            <Globe className="w-3.5 h-3.5" />
                          </span>
                        )}
                      </div>
                    </td>

                    {/* Progress & Usage (QCM, PDF Read, Streak) */}
                    <td className="py-3.5 px-4">
                      <div className="space-y-0.5">
                        <div className="flex items-center gap-1.5">
                          <span className="font-mono font-bold text-teal-600 dark:text-teal-400">
                            {user.progress?.totalQcmSolved || 0} QCM
                          </span>
                          <span className="text-slate-300 dark:text-slate-700">·</span>
                          <span className="font-mono font-bold text-indigo-600 dark:text-indigo-400">
                            {user.progress?.totalCoursesCompleted || 0} PDF
                          </span>
                        </div>
                        {(user.telemetry?.streakDays || 0) > 0 ? (
                          <span className="text-[10.5px] font-bold text-orange-500 flex items-center gap-0.5">
                            <Flame className="w-3 h-3 inline" />
                            {user.telemetry?.streakDays} jours consécutifs
                          </span>
                        ) : (
                          <span className="text-[10px] text-slate-400 font-mono">
                            {user.telemetry?.connectionCount || 1} session(s)
                          </span>
                        )}
                      </div>
                    </td>

                    {/* Validité & Formule d'Accès Column */}
                    <td className="py-3.5 px-4">
                      <div className="space-y-1">
                        <span className={`inline-block px-2 py-0.5 rounded text-[10.5px] font-bold border ${tierInfo.bg}`}>
                          {tierInfo.label}
                        </span>
                        <div className="flex items-center gap-1 text-[11px] font-mono">
                          <span className="text-slate-400">Exp :</span>
                          <span className={`font-bold ${
                            expInfo.status === 'expired' 
                              ? 'text-rose-600 dark:text-rose-400' 
                              : expInfo.status === 'warning'
                                ? 'text-amber-600 dark:text-amber-400'
                                : 'text-emerald-600 dark:text-emerald-400'
                          }`}>
                            {expInfo.formattedDate}
                          </span>
                        </div>
                        <span className={`inline-block text-[9px] font-semibold px-1.5 py-0.2 rounded-full border ${
                          expInfo.status === 'expired'
                            ? 'bg-rose-50 text-rose-700 dark:bg-rose-950 dark:text-rose-300 border-rose-200'
                            : expInfo.status === 'warning'
                              ? 'bg-amber-50 text-amber-700 dark:bg-amber-950 dark:text-amber-300 border-amber-200'
                              : 'bg-emerald-50 text-emerald-700 dark:bg-emerald-950 dark:text-emerald-300 border-emerald-200'
                        }`}>
                          {expInfo.badgeText}
                        </span>
                      </div>
                    </td>

                    {/* Action Buttons */}
                    <td className="py-3.5 px-4 text-right">
                      <div className="flex items-center justify-end gap-1.5">
                        {userActivity.isInactive && (
                          <button
                            onClick={(e) => handleCopyContact(user, e)}
                            title="Copier les coordonnées pour relance email / tél"
                            className="px-2 py-1 text-xs font-semibold text-amber-800 dark:text-amber-200 bg-amber-50 dark:bg-amber-950/60 hover:bg-amber-100 rounded-md border border-amber-200 dark:border-amber-800 transition-colors cursor-pointer flex items-center gap-1"
                          >
                            {copiedContactId === user.id ? <Check className="w-3 h-3 text-emerald-600" /> : <Copy className="w-3 h-3" />}
                            <span>{copiedContactId === user.id ? 'Copié' : 'Relancer'}</span>
                          </button>
                        )}
                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            handleQuickExtend(user, 30);
                          }}
                          disabled={isExtending}
                          title="Prolonger de 30 jours"
                          className="px-2 py-1 text-xs font-bold text-slate-700 dark:text-slate-300 bg-slate-100 hover:bg-slate-200 dark:bg-slate-800 dark:hover:bg-slate-700 rounded-md border border-slate-200 dark:border-slate-700 transition-colors cursor-pointer disabled:opacity-50"
                        >
                          {isExtending ? '...' : '+30j'}
                        </button>
                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            handleOpenDetails(user, 'identity');
                          }}
                          className="px-2.5 py-1 text-xs font-semibold text-teal-700 dark:text-teal-300 bg-teal-50 dark:bg-teal-950/60 hover:bg-teal-100 dark:hover:bg-teal-900/60 rounded-md transition-colors cursor-pointer"
                        >
                          Gérer
                        </button>
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </div>

      {/* 360° Complete Doctor Profile Details Modal */}
      {selectedUserForDetails && (
        <DoctorProfileModal
          user={selectedUserForDetails}
          payments={payments}
          licenses={licenses}
          initialTab={modalInitialTab}
          onClose={() => setSelectedUserForDetails(null)}
          onUpdateUser={handleUserUpdatedFromModal}
        />
      )}
    </div>
  );
};
