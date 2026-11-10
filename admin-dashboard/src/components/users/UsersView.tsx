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
  Stethoscope
} from 'lucide-react';
import { AdminUserItem, SubscriptionTier, PaymentItem, AdminLicenseItem, MedicalRole } from '../../types/medsina';
import { DoctorProfileModal } from './DoctorProfileModal';
import { resolveStudyYear, formatStudyYearDisplay, updateUserProfileInSupabase } from '../../services/supabase';

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
  const [selectedActivity, setSelectedActivity] = useState<string>('All');
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

    // Activity filter
    let matchesActivity = true;
    if (selectedActivity !== 'All') {
      if (selectedActivity === 'online') {
        matchesActivity = !!u.telemetry?.isOnline;
      } else if (selectedActivity === 'today') {
        matchesActivity = !!u.telemetry?.isActiveToday;
      } else if (selectedActivity === 'streak') {
        matchesActivity = (u.telemetry?.streakDays || 0) > 1;
      } else if (selectedActivity === 'inactive') {
        matchesActivity = !u.telemetry?.isActiveToday && !u.telemetry?.isOnline;
      }
    }

    return matchesSearch && matchesRole && matchesTier && matchesPlatform && matchesActivity;
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

      // Format date in French: "03 Déc 2026"
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

  // Activity summary counts
  const onlineCount = users.filter(u => u.telemetry?.isOnline).length;
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
            Supervision 360°, suivi de l'usage en temps réel (PDFs lus, QCMs résolus), accès multi-plateformes (Web, Windows, Mobile).
          </p>
        </div>

        <div className="flex items-center gap-3 text-xs font-mono text-slate-500 dark:text-slate-400">
          <span>Actifs aujourd'hui : <strong className="text-emerald-600 dark:text-emerald-400 font-bold">{activeTodayCount}</strong></span>
          <span>·</span>
          <span>Total : <strong className="text-slate-900 dark:text-white">{filteredUsers.length}</strong></span>
        </div>
      </div>

      {/* Filter and Search Bar */}
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

          {/* Activity / Real-time filter */}
          <select
            value={selectedActivity}
            onChange={(e) => setSelectedActivity(e.target.value)}
            className="px-3 py-2 text-xs bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg text-slate-700 dark:text-slate-200 focus:outline-none cursor-pointer"
          >
            <option value="All">Toutes les activités</option>
            <option value="online">🟢 En ligne actuellement</option>
            <option value="today">🟡 Actifs aujourd'hui</option>
            <option value="streak">🔥 Avec Série de révision</option>
            <option value="inactive">💤 Inactifs récemment</option>
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
        {filteredUsers.length === 0 ? (
          <div className="p-6 text-center text-xs text-slate-400 bg-white dark:bg-slate-900 rounded-xl border border-slate-200 dark:border-slate-800">
            Aucun médecin trouvé pour cette recherche.
          </div>
        ) : (
          filteredUsers.map((user) => {
            const tierInfo = getTierBadge(user.tier);
            const isOnline = user.telemetry?.isOnline;
            const isActiveToday = user.telemetry?.isActiveToday;
            const platforms = user.telemetry?.platformsUsed || ['android'];
            const resolvedYear = resolveStudyYear(user, user);
            const expInfo = formatExpirationDisplay(user.expiresAt);
            const isExtending = extendingUserId === user.id;

            return (
              <div
                key={user.id}
                onClick={() => handleOpenDetails(user, 'identity')}
                className="p-4 bg-white dark:bg-slate-900 rounded-2xl border border-slate-200 dark:border-slate-800 shadow-xs hover:shadow-md hover:border-teal-500/50 transition-all cursor-pointer space-y-3"
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
                      {/* Realtime Live presence dot */}
                      <span 
                        className={`absolute -bottom-0.5 -right-0.5 w-3.5 h-3.5 rounded-full border-2 border-white dark:border-slate-900 ${
                          isOnline 
                            ? 'bg-emerald-500 ring-2 ring-emerald-400/30 animate-pulse' 
                            : (isActiveToday ? 'bg-amber-500' : 'bg-slate-300 dark:bg-slate-600')
                        }`}
                        title={isOnline ? 'En ligne actuellement' : (isActiveToday ? 'Actif aujourd\'hui' : 'Hors ligne')}
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

                  {/* Action buttons: +30j & Gérer */}
                  <div className="flex items-center gap-1.5 shrink-0">
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
                <th className="py-3 px-4 font-semibold">Rôle & Cursus</th>
                <th className="py-3 px-4 font-semibold">Faculté & Wilaya</th>
                <th className="py-3 px-4 font-semibold">Accès Plateformes</th>
                <th className="py-3 px-4 font-semibold">Usage & Progression</th>
                <th className="py-3 px-4 font-semibold">Validité & Formule</th>
                <th className="py-3 px-4 font-semibold text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-200 dark:divide-slate-800">
              {filteredUsers.map((user) => {
                const tierInfo = getTierBadge(user.tier);
                const isOnline = user.telemetry?.isOnline;
                const isActiveToday = user.telemetry?.isActiveToday;
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
                            className={`absolute -bottom-0.5 -right-0.5 w-2.5 h-2.5 rounded-full border border-white dark:border-slate-900 ${
                              isOnline ? 'bg-emerald-500 animate-pulse' : (isActiveToday ? 'bg-amber-500' : 'bg-slate-400')
                            }`}
                            title={isOnline ? 'En ligne' : (isActiveToday ? 'Actif aujourd\'hui' : 'Hors ligne')}
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
                      <div className="mt-1">
                        {isOnline ? (
                          <span className="text-[10px] text-emerald-600 dark:text-emerald-400 font-bold flex items-center gap-1">
                            <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-ping" />
                            En ligne
                          </span>
                        ) : (
                          <span className="text-[10px] text-slate-400 font-mono">
                            {formatRelativeTime(user.telemetry?.lastConnectionAt || user.createdAt)}
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
