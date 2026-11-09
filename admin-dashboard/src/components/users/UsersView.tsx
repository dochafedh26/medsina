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
  ArrowRight
} from 'lucide-react';
import { AdminUserItem, SubscriptionTier, PaymentItem, AdminLicenseItem, MedicalRole } from '../../types/medsina';

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
  const [selectedUserForDetails, setSelectedUserForDetails] = useState<AdminUserItem | null>(null);
  const [detailsTab, setDetailsTab] = useState<'identity' | 'subscription' | 'payments' | 'licenses'>('identity');
  const [banReasonInput, setBanReasonInput] = useState('');
  const [showBanModal, setShowBanModal] = useState(false);

  // Edit user profile state
  const [isEditingProfile, setIsEditingProfile] = useState(false);
  const [editFullName, setEditFullName] = useState('');
  const [editPhone, setEditPhone] = useState('');
  const [editFaculty, setEditFaculty] = useState('');
  const [editWilaya, setEditWilaya] = useState('');
  const [editMedicalRole, setEditMedicalRole] = useState<MedicalRole>('Candidat Résidanat');

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
      (u.wilaya && u.wilaya.toLowerCase().includes(searchQuery.toLowerCase()));
    
    const matchesRole = selectedRole === 'All' || u.medicalRole === selectedRole;
    const matchesTier = selectedTier === 'All' || u.tier === selectedTier;

    return matchesSearch && matchesRole && matchesTier;
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

  const handleOpenDetails = (user: AdminUserItem, tab: 'identity' | 'subscription' = 'identity') => {
    setSelectedUserForDetails(user);
    setDetailsTab(tab);
    setIsEditingProfile(false);
    setEditFullName(user.fullName);
    setEditPhone(user.phone || '');
    setEditFaculty(user.faculty || '');
    setEditWilaya(user.wilaya || '');
    setEditMedicalRole(user.medicalRole || 'Candidat Résidanat');
  };

  const handleSaveProfile = () => {
    if (!selectedUserForDetails) return;
    const updated: AdminUserItem = {
      ...selectedUserForDetails,
      fullName: editFullName,
      phone: editPhone,
      faculty: editFaculty,
      wilaya: editWilaya,
      medicalRole: editMedicalRole
    };
    onUpdateUser(updated);
    setSelectedUserForDetails(updated);
    setIsEditingProfile(false);
  };

  const handleExtendSubscription = (user: AdminUserItem, daysToAdd: number) => {
    const currentExpiry = user.expiresAt ? new Date(user.expiresAt) : new Date();
    const newExpiry = new Date(currentExpiry.getTime() + daysToAdd * 24 * 60 * 60 * 1000);
    const updated = {
      ...user,
      status: 'active' as const,
      expiresAt: newExpiry.toISOString().slice(0, 10)
    };
    onUpdateUser(updated);
    if (selectedUserForDetails?.id === user.id) {
      setSelectedUserForDetails(updated);
    }
  };

  const handleChangeTier = (user: AdminUserItem, newTier: SubscriptionTier) => {
    const updated = {
      ...user,
      tier: newTier,
      status: 'active' as const
    };
    onUpdateUser(updated);
    if (selectedUserForDetails?.id === user.id) {
      setSelectedUserForDetails(updated);
    }
  };

  const handleToggleBan = (user: AdminUserItem) => {
    const updated = {
      ...user,
      isBanned: !user.isBanned,
      status: (!user.isBanned ? 'suspended' : 'active') as 'suspended' | 'active',
      banReason: !user.isBanned ? banReasonInput || 'Non-respect des conditions d\'utilisation' : undefined
    };
    onUpdateUser(updated);
    setShowBanModal(false);
    if (selectedUserForDetails?.id === user.id) {
      setSelectedUserForDetails(updated);
    }
  };

  const userPayments = selectedUserForDetails 
    ? payments.filter(p => p.userEmail === selectedUserForDetails.email || p.userId === selectedUserForDetails.id)
    : [];

  const userLicenses = selectedUserForDetails
    ? licenses.filter(l => l.redeemedUserEmail === selectedUserForDetails.email || l.redeemedBy === selectedUserForDetails.id)
    : [];

  return (
    <div className="space-y-5">
      {/* View Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-2 border-b border-slate-200 dark:border-slate-800">
        <div>
          <h1 className="text-xl md:text-2xl font-bold tracking-tight text-slate-900 dark:text-white">
            Médecins & Comptes Utilisateurs
          </h1>
          <p className="text-xs md:text-sm text-slate-500 dark:text-slate-400 mt-0.5">
            Gestion 360° des praticiens, candidats résidanat, externes, abonnements et quotas.
          </p>
        </div>

        <div className="text-xs font-mono text-slate-500 dark:text-slate-400">
          Total : <strong className="text-slate-900 dark:text-white">{filteredUsers.length}</strong> comptes
        </div>
      </div>

      {/* Filter and Search Bar */}
      <div className="p-3 bg-white dark:bg-slate-900 rounded-xl border border-slate-200 dark:border-slate-800 shadow-2xs flex flex-col md:flex-row md:items-center justify-between gap-3">
        {/* Search Input */}
        <div className="relative flex-1">
          <Search className="w-4 h-4 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Rechercher nom, email, faculté (Alger, Blida, Constantine...), wilaya..."
            className="w-full pl-9 pr-4 py-2 text-xs bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg text-slate-900 dark:text-white placeholder-slate-400 focus:outline-none focus:ring-1 focus:ring-teal-500"
          />
        </div>

        <div className="flex flex-wrap items-center gap-2">
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
      <div className="block md:hidden space-y-3">
        {filteredUsers.length === 0 ? (
          <div className="p-6 text-center text-xs text-slate-400 bg-white dark:bg-slate-900 rounded-xl border border-slate-200 dark:border-slate-800">
            Aucun médecin trouvé pour cette recherche.
          </div>
        ) : (
          filteredUsers.map((user) => {
            const tierInfo = getTierBadge(user.tier);
            return (
              <div
                key={user.id}
                onClick={() => handleOpenDetails(user, 'identity')}
                className="p-3.5 bg-white dark:bg-slate-900 rounded-xl border border-slate-200 dark:border-slate-800 shadow-2xs space-y-2.5 cursor-pointer hover:border-teal-500/50 transition-colors"
              >
                <div className="flex items-start justify-between gap-2.5">
                  <div className="flex items-center gap-2.5 min-w-0">
                    <div className="w-9 h-9 rounded-full bg-slate-200 dark:bg-slate-700 overflow-hidden ring-1 ring-slate-300 dark:ring-slate-700 shrink-0">
                      {user.avatarUrl ? (
                        <img src={user.avatarUrl} alt="" className="w-full h-full object-cover" />
                      ) : (
                        <div className="w-full h-full flex items-center justify-center font-bold text-xs text-slate-600 dark:text-slate-300">
                          {user.fullName.slice(0, 2).toUpperCase()}
                        </div>
                      )}
                    </div>
                    <div className="min-w-0">
                      <div className="flex items-center gap-1.5 flex-wrap">
                        <span className="font-bold text-sm text-slate-900 dark:text-white truncate">
                          {user.fullName}
                        </span>
                        {user.isAdmin && (
                          <span className="text-[9px] font-mono font-bold text-teal-600 dark:text-teal-400 bg-teal-50 dark:bg-teal-950 px-1 py-0.2 rounded">
                            ADMIN
                          </span>
                        )}
                        {user.isBanned && (
                          <span className="text-[9px] font-mono font-bold text-rose-600 dark:text-rose-400 bg-rose-50 dark:bg-rose-950 px-1 py-0.2 rounded">
                            BANNI
                          </span>
                        )}
                      </div>
                      <p className="text-[11px] text-slate-400 font-mono truncate">
                        {user.email}
                      </p>
                    </div>
                  </div>

                  <span className={`inline-block px-2 py-0.5 rounded text-[10px] font-bold border shrink-0 ${tierInfo.bg}`}>
                    {tierInfo.label}
                  </span>
                </div>

                <div className="flex items-center justify-between text-xs pt-1 border-t border-slate-100 dark:border-slate-800 text-slate-600 dark:text-slate-300">
                  <span className="font-medium truncate max-w-[170px]">
                    {user.medicalRole}
                  </span>
                  <span className="text-slate-400 text-[11px] font-mono truncate max-w-[130px]">
                    {user.faculty || 'Faculté non spécifiée'}
                  </span>
                </div>

                <div className="flex items-center justify-between text-xs pt-1 text-slate-400">
                  <span className="font-mono text-[11px]">
                    Validité : <strong className={user.status === 'active' ? 'text-emerald-600 dark:text-emerald-400' : 'text-slate-400'}>{user.expiresAt || 'Illimité'}</strong>
                  </span>
                  <div className="flex items-center gap-1.5">
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        handleExtendSubscription(user, 30);
                      }}
                      className="px-2 py-1 bg-slate-100 dark:bg-slate-800 text-slate-700 dark:text-slate-300 hover:bg-slate-200 rounded text-[11px] font-medium"
                    >
                      +30j
                    </button>
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        handleOpenDetails(user, 'subscription');
                      }}
                      className="px-2.5 py-1 bg-teal-50 dark:bg-teal-950 text-teal-700 dark:text-teal-300 hover:bg-teal-100 rounded text-[11px] font-semibold"
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
                <th className="py-3 px-4 font-semibold">Médecin / Étudiant</th>
                <th className="py-3 px-4 font-semibold">Rôle Médical & Cursus</th>
                <th className="py-3 px-4 font-semibold">Faculté & Wilaya</th>
                <th className="py-3 px-4 font-semibold">Formule d'Accès</th>
                <th className="py-3 px-4 font-semibold">Validité</th>
                <th className="py-3 px-4 font-semibold text-right">Actions 360°</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-200 dark:divide-slate-800">
              {filteredUsers.map((user) => {
                const tierInfo = getTierBadge(user.tier);
                return (
                  <tr 
                    key={user.id} 
                    className="hover:bg-slate-50/70 dark:hover:bg-slate-800/40 transition-colors cursor-pointer"
                    onClick={() => handleOpenDetails(user, 'identity')}
                  >
                    {/* User Identity Column */}
                    <td className="py-3.5 px-4">
                      <div className="flex items-center gap-3">
                        <div className="w-8 h-8 rounded-full bg-slate-200 dark:bg-slate-700 overflow-hidden ring-1 ring-slate-300 dark:ring-slate-700 shrink-0">
                          {user.avatarUrl ? (
                            <img src={user.avatarUrl} alt="" className="w-full h-full object-cover" />
                          ) : (
                            <div className="w-full h-full flex items-center justify-center font-bold text-slate-600 dark:text-slate-300">
                              {user.fullName.slice(0, 2).toUpperCase()}
                            </div>
                          )}
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
                      <p className="text-[11px] text-slate-400">
                        {user.studyYear ? `${user.studyYear}ème Année` : user.residencyTargetYear ? `Cible : ${user.residencyTargetYear}` : 'Diplômé'}
                      </p>
                    </td>

                    {/* Faculty & Wilaya */}
                    <td className="py-3.5 px-4">
                      <p className="text-slate-800 dark:text-slate-200 truncate max-w-[200px]">
                        {user.faculty}
                      </p>
                      <p className="text-[11px] text-slate-400 font-mono">
                        {user.wilaya || 'Algérie'}
                      </p>
                    </td>

                    {/* Subscription Tier */}
                    <td className="py-3.5 px-4">
                      <span className={`inline-block px-2 py-0.5 rounded text-[11px] font-bold border ${tierInfo.bg}`}>
                        {tierInfo.label}
                      </span>
                    </td>

                    {/* Validity & Expiration */}
                    <td className="py-3.5 px-4 font-mono tabular-nums">
                      <p className="text-slate-800 dark:text-slate-200">
                        {user.expiresAt || 'Illimité'}
                      </p>
                      <span className={`text-[10px] font-semibold ${
                        user.status === 'active' ? 'text-emerald-600 dark:text-emerald-400' : 'text-slate-400'
                      }`}>
                        {user.status === 'active' ? 'Actif' : 'Expiré'}
                      </span>
                    </td>

                    {/* Action Button */}
                    <td className="py-3.5 px-4 text-right">
                      <button
                        onClick={(e) => {
                          e.stopPropagation();
                          handleOpenDetails(user, 'subscription');
                        }}
                        className="px-2.5 py-1 text-xs font-semibold text-teal-700 dark:text-teal-300 bg-teal-50 dark:bg-teal-950/60 hover:bg-teal-100 rounded-md transition-colors cursor-pointer"
                      >
                        Gérer Compte
                      </button>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </div>

      {/* 360° Doctor Profile Details Modal */}
      {selectedUserForDetails && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-4 bg-slate-950/60 backdrop-blur-xs">
          <div className="w-full max-w-2xl bg-white dark:bg-slate-900 rounded-2xl shadow-2xl border border-slate-200 dark:border-slate-800 max-h-[90vh] flex flex-col overflow-hidden animate-in fade-in-50 duration-150">
            {/* Modal Header */}
            <div className="p-4 bg-slate-900 text-white flex items-center justify-between border-b border-slate-800 shrink-0">
              <div className="flex items-center gap-3 min-w-0">
                <div className="w-10 h-10 rounded-full bg-slate-800 overflow-hidden ring-2 ring-teal-500 shrink-0">
                  {selectedUserForDetails.avatarUrl ? (
                    <img src={selectedUserForDetails.avatarUrl} alt="" className="w-full h-full object-cover" />
                  ) : (
                    <div className="w-full h-full flex items-center justify-center font-bold">
                      {selectedUserForDetails.fullName.slice(0, 2).toUpperCase()}
                    </div>
                  )}
                </div>
                <div className="min-w-0">
                  <h2 className="text-sm font-bold text-white flex items-center gap-2">
                    <span className="truncate">{selectedUserForDetails.fullName}</span>
                    <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-teal-600/80 text-white shrink-0">
                      {selectedUserForDetails.tier.toUpperCase()}
                    </span>
                  </h2>
                  <p className="text-xs text-slate-400 font-mono truncate">
                    {selectedUserForDetails.email} · {selectedUserForDetails.phone || 'Pas de tél'}
                  </p>
                </div>
              </div>

              <button
                onClick={() => setSelectedUserForDetails(null)}
                className="p-1 text-slate-400 hover:text-white cursor-pointer shrink-0"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {/* 4 Tabs Menu (Identité, Abonnement, Paiements, Licences) */}
            <div className="flex items-center border-b border-slate-200 dark:border-slate-800 bg-slate-50 dark:bg-slate-900/50 px-4 text-xs font-medium overflow-x-auto no-scrollbar whitespace-nowrap shrink-0">
              <button
                onClick={() => setDetailsTab('identity')}
                className={`py-2.5 px-3 border-b-2 cursor-pointer transition-colors shrink-0 ${
                  detailsTab === 'identity'
                    ? 'border-teal-600 text-teal-600 dark:text-teal-400 font-bold'
                    : 'border-transparent text-slate-500 hover:text-slate-800 dark:hover:text-slate-200'
                }`}
              >
                Identité & Cursus
              </button>
              <button
                onClick={() => setDetailsTab('subscription')}
                className={`py-2.5 px-3 border-b-2 cursor-pointer transition-colors shrink-0 ${
                  detailsTab === 'subscription'
                    ? 'border-teal-600 text-teal-600 dark:text-teal-400 font-bold'
                    : 'border-transparent text-slate-500 hover:text-slate-800 dark:hover:text-slate-200'
                }`}
              >
                Gestion Abonnement
              </button>
              <button
                onClick={() => setDetailsTab('payments')}
                className={`py-2.5 px-3 border-b-2 cursor-pointer transition-colors shrink-0 ${
                  detailsTab === 'payments'
                    ? 'border-teal-600 text-teal-600 dark:text-teal-400 font-bold'
                    : 'border-transparent text-slate-500 hover:text-slate-800 dark:hover:text-slate-200'
                }`}
              >
                Paiements CCP ({userPayments.length})
              </button>
              <button
                onClick={() => setDetailsTab('licenses')}
                className={`py-2.5 px-3 border-b-2 cursor-pointer transition-colors shrink-0 ${
                  detailsTab === 'licenses'
                    ? 'border-teal-600 text-teal-600 dark:text-teal-400 font-bold'
                    : 'border-transparent text-slate-500 hover:text-slate-800 dark:hover:text-slate-200'
                }`}
              >
                Licences & Quotas ({userLicenses.length})
              </button>
            </div>

            {/* Modal Body Container */}
            <div className="flex-1 overflow-y-auto p-4 sm:p-5">
              {/* Tab 1: Identité & Cursus */}
              {detailsTab === 'identity' && (
                <div className="space-y-4 text-xs">
                  <div className="flex items-center justify-between pb-2 border-b border-slate-100 dark:border-slate-800">
                    <span className="font-bold text-slate-800 dark:text-slate-200 uppercase tracking-wide text-[11px]">
                      Profil Médical du Praticien
                    </span>
                    <button
                      onClick={() => setIsEditingProfile(!isEditingProfile)}
                      className="flex items-center gap-1 px-2.5 py-1 text-xs font-semibold text-teal-600 dark:text-teal-400 hover:bg-teal-50 dark:hover:bg-teal-950/40 rounded-lg cursor-pointer"
                    >
                      <Edit2 className="w-3.5 h-3.5" />
                      <span>{isEditingProfile ? 'Annuler' : 'Modifier les informations'}</span>
                    </button>
                  </div>

                  {isEditingProfile ? (
                    <div className="space-y-3 p-3 bg-slate-50 dark:bg-slate-800/40 rounded-xl border border-slate-200 dark:border-slate-800">
                      <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                        <div>
                          <label className="font-semibold block mb-1 text-slate-700 dark:text-slate-300">Nom Complet :</label>
                          <input
                            type="text"
                            value={editFullName}
                            onChange={(e) => setEditFullName(e.target.value)}
                            className="w-full p-2 bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-700 rounded-lg text-slate-900 dark:text-white"
                          />
                        </div>
                        <div>
                          <label className="font-semibold block mb-1 text-slate-700 dark:text-slate-300">Numéro Téléphone :</label>
                          <input
                            type="text"
                            value={editPhone}
                            onChange={(e) => setEditPhone(e.target.value)}
                            placeholder="0550 12 34 56"
                            className="w-full p-2 bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-700 rounded-lg text-slate-900 dark:text-white"
                          />
                        </div>
                      </div>

                      <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                        <div>
                          <label className="font-semibold block mb-1 text-slate-700 dark:text-slate-300">Rôle Médical :</label>
                          <select
                            value={editMedicalRole}
                            onChange={(e) => setEditMedicalRole(e.target.value as any)}
                            className="w-full p-2 bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-700 rounded-lg text-slate-900 dark:text-white"
                          >
                            {roles.filter(r => r !== 'All').map(r => (
                              <option key={r} value={r}>{r}</option>
                            ))}
                          </select>
                        </div>
                        <div>
                          <label className="font-semibold block mb-1 text-slate-700 dark:text-slate-300">Faculté :</label>
                          <input
                            type="text"
                            value={editFaculty}
                            onChange={(e) => setEditFaculty(e.target.value)}
                            className="w-full p-2 bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-700 rounded-lg text-slate-900 dark:text-white"
                          />
                        </div>
                        <div>
                          <label className="font-semibold block mb-1 text-slate-700 dark:text-slate-300">Wilaya :</label>
                          <input
                            type="text"
                            value={editWilaya}
                            onChange={(e) => setEditWilaya(e.target.value)}
                            className="w-full p-2 bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-700 rounded-lg text-slate-900 dark:text-white"
                          />
                        </div>
                      </div>

                      <div className="flex justify-end pt-2">
                        <button
                          onClick={handleSaveProfile}
                          className="flex items-center gap-1.5 px-4 py-2 bg-teal-600 hover:bg-teal-700 text-white font-semibold rounded-lg shadow-xs cursor-pointer"
                        >
                          <Save className="w-3.5 h-3.5" />
                          <span>Enregistrer les modifications</span>
                        </button>
                      </div>
                    </div>
                  ) : (
                    <div className="grid grid-cols-1 sm:grid-cols-2 gap-3.5">
                      <div className="p-3 bg-slate-50 dark:bg-slate-800/50 rounded-lg border border-slate-200 dark:border-slate-800">
                        <span className="text-[10px] text-slate-400 uppercase font-semibold block">Rôle Médical</span>
                        <span className="font-bold text-slate-900 dark:text-white">{selectedUserForDetails.medicalRole}</span>
                      </div>
                      <div className="p-3 bg-slate-50 dark:bg-slate-800/50 rounded-lg border border-slate-200 dark:border-slate-800">
                        <span className="text-[10px] text-slate-400 uppercase font-semibold block">Faculté de Médecine</span>
                        <span className="font-bold text-slate-900 dark:text-white truncate block">{selectedUserForDetails.faculty}</span>
                      </div>
                      <div className="p-3 bg-slate-50 dark:bg-slate-800/50 rounded-lg border border-slate-200 dark:border-slate-800">
                        <span className="text-[10px] text-slate-400 uppercase font-semibold block">Wilaya de Résidence</span>
                        <span className="font-bold text-slate-900 dark:text-white">{selectedUserForDetails.wilaya || 'Non renseigné'}</span>
                      </div>
                      <div className="p-3 bg-slate-50 dark:bg-slate-800/50 rounded-lg border border-slate-200 dark:border-slate-800">
                        <span className="text-[10px] text-slate-400 uppercase font-semibold block">Code Parrainage</span>
                        <span className="font-mono font-bold text-teal-600 dark:text-teal-400">{selectedUserForDetails.referralCode || 'Aucun'}</span>
                      </div>
                    </div>
                  )}

                  {selectedUserForDetails.bio && (
                    <div className="p-3 bg-slate-50 dark:bg-slate-800/50 rounded-lg border border-slate-200 dark:border-slate-800">
                      <span className="text-[10px] text-slate-400 uppercase font-semibold block mb-1">Biographie / Objectif</span>
                      <p className="text-slate-700 dark:text-slate-300">{selectedUserForDetails.bio}</p>
                    </div>
                  )}
                </div>
              )}

              {/* Tab 2: Gestion Abonnement */}
              {detailsTab === 'subscription' && (
                <div className="space-y-4 text-xs">
                  <div className="p-3.5 bg-slate-50 dark:bg-slate-800/50 rounded-xl border border-slate-200 dark:border-slate-800 flex flex-col sm:flex-row sm:items-center justify-between gap-3">
                    <div>
                      <span className="text-[11px] text-slate-400 font-semibold uppercase">Formule Actuelle</span>
                      <p className="text-sm font-bold text-slate-900 dark:text-white">
                        {getTierBadge(selectedUserForDetails.tier).label}
                      </p>
                      <p className="text-[11px] text-slate-500 font-mono mt-0.5">
                        Expire le : {selectedUserForDetails.expiresAt || 'Non spécifié'}
                      </p>
                    </div>

                    {/* Fast Tier Changer */}
                    <select
                      value={selectedUserForDetails.tier}
                      onChange={(e) => handleChangeTier(selectedUserForDetails, e.target.value as SubscriptionTier)}
                      className="px-3 py-2 text-xs bg-white dark:bg-slate-900 border border-slate-300 dark:border-slate-700 rounded-lg text-slate-800 dark:text-slate-200 font-semibold cursor-pointer"
                    >
                      <option value="free">Passer en Gratuit</option>
                      <option value="etudiant">Étudiant (4 500 DZD)</option>
                      <option value="clinical_pro">Clinical Pro (9 000 DZD)</option>
                      <option value="resident_elite">Résident Élite (12 000 DZD)</option>
                      <option value="all_access">All-Access VIP (18 000 DZD)</option>
                    </select>
                  </div>

                  {/* Quick Extension Buttons */}
                  <div className="space-y-2">
                    <span className="font-semibold text-slate-700 dark:text-slate-300">Prolongation Rapide de Validité</span>
                    <div className="grid grid-cols-3 gap-2">
                      <button
                        onClick={() => handleExtendSubscription(selectedUserForDetails, 30)}
                        className="py-2.5 px-3 bg-slate-100 dark:bg-slate-800 hover:bg-slate-200 text-slate-800 dark:text-slate-200 rounded-lg font-semibold cursor-pointer text-center"
                      >
                        +30 Jours
                      </button>
                      <button
                        onClick={() => handleExtendSubscription(selectedUserForDetails, 180)}
                        className="py-2.5 px-3 bg-slate-100 dark:bg-slate-800 hover:bg-slate-200 text-slate-800 dark:text-slate-200 rounded-lg font-semibold cursor-pointer text-center"
                      >
                        +180 Jours
                      </button>
                      <button
                        onClick={() => handleExtendSubscription(selectedUserForDetails, 365)}
                        className="py-2.5 px-3 bg-teal-600 hover:bg-teal-700 text-white rounded-lg font-semibold cursor-pointer text-center shadow-xs"
                      >
                        +365 Jours (1 An)
                      </button>
                    </div>
                  </div>

                  {/* Account Status / Ban Toggle */}
                  <div className="pt-3 border-t border-slate-200 dark:border-slate-800 flex items-center justify-between">
                    <div>
                      <span className="font-semibold text-slate-800 dark:text-slate-200">Statut du Compte</span>
                      <p className="text-[11px] text-slate-500">
                        {selectedUserForDetails.isBanned ? 'Le compte est suspendu.' : 'Le compte est actif sans restriction.'}
                      </p>
                    </div>

                    <button
                      onClick={() => setShowBanModal(true)}
                      className={`px-3 py-1.5 rounded-lg font-semibold text-xs transition-colors cursor-pointer ${
                        selectedUserForDetails.isBanned
                          ? 'bg-emerald-50 text-emerald-700 dark:bg-emerald-950 dark:text-emerald-300 hover:bg-emerald-100'
                          : 'bg-rose-50 text-rose-700 dark:bg-rose-950 dark:text-rose-300 hover:bg-rose-100 border border-rose-200 dark:border-rose-900'
                      }`}
                    >
                      {selectedUserForDetails.isBanned ? 'Débloquer le Compte' : 'Suspendre / Bannir'}
                    </button>
                  </div>
                </div>
              )}

              {/* Tab 3: Paiements CCP */}
              {detailsTab === 'payments' && (
                <div className="space-y-3 text-xs">
                  {userPayments.length === 0 ? (
                    <p className="text-slate-500 text-center py-6">Aucun paiement enregistré pour ce médecin.</p>
                  ) : (
                    userPayments.map((p) => (
                      <div key={p.id} className="p-3 bg-slate-50 dark:bg-slate-800/50 rounded-lg border border-slate-200 dark:border-slate-800 flex items-center justify-between">
                        <div>
                          <div className="flex items-center gap-2">
                            <span className="font-bold text-slate-900 dark:text-white font-mono">{p.amount.toLocaleString()} DZD</span>
                            <span className="text-[10px] uppercase font-mono text-slate-400">({p.paymentMethod})</span>
                          </div>
                          <p className="text-[11px] text-slate-500 font-mono mt-0.5">Réf : {p.receiptReference || 'Non spécifiée'}</p>
                        </div>
                        <span className={`text-[10px] font-bold uppercase px-2 py-0.5 rounded ${
                          p.status === 'approved' ? 'bg-emerald-100 text-emerald-800 dark:bg-emerald-950 dark:text-emerald-300' : 'bg-amber-100 text-amber-800 dark:bg-amber-950 dark:text-amber-300'
                        }`}>
                          {p.status}
                        </span>
                      </div>
                    ))
                  )}
                </div>
              )}

              {/* Tab 4: Licences & Quotas */}
              {detailsTab === 'licenses' && (
                <div className="space-y-3 text-xs">
                  {userLicenses.length === 0 ? (
                    <p className="text-slate-500 text-center py-6">Aucune clé de licence VIP activée pour ce compte.</p>
                  ) : (
                    userLicenses.map((l, i) => (
                      <div key={i} className="p-3 bg-slate-50 dark:bg-slate-800/50 rounded-lg border border-slate-200 dark:border-slate-800 flex items-center justify-between">
                        <div>
                          <span className="font-bold font-mono text-teal-600 dark:text-teal-400">{l.keyCode}</span>
                          <p className="text-[11px] text-slate-400">Activée le : {l.redeemedAt} · Durée : {l.durationDays}j</p>
                        </div>
                        <span className="text-[10px] font-mono text-emerald-600 font-semibold">Active</span>
                      </div>
                    ))
                  )}
                </div>
              )}
            </div>
          </div>
        </div>
      )}

      {/* Ban / Suspension Confirmation Modal */}
      {showBanModal && selectedUserForDetails && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/60 backdrop-blur-xs">
          <div className="w-full max-w-md bg-white dark:bg-slate-900 rounded-xl shadow-2xl border border-slate-200 dark:border-slate-800 p-5 space-y-4">
            <h3 className="text-sm font-bold text-slate-900 dark:text-white">
              {selectedUserForDetails.isBanned ? 'Débloquer le compte ?' : 'Confirmer la suspension du médecin'}
            </h3>
            {!selectedUserForDetails.isBanned && (
              <div>
                <label className="block text-xs font-semibold text-slate-700 dark:text-slate-300 mb-1">
                  Motif de la suspension (notifié au médecin)
                </label>
                <textarea
                  rows={2}
                  value={banReasonInput}
                  onChange={(e) => setBanReasonInput(e.target.value)}
                  placeholder="e.g. Faux bordereau de paiement CCP, partage de compte..."
                  className="w-full p-2 bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg text-xs text-slate-900 dark:text-white"
                />
              </div>
            )}
            <div className="flex items-center justify-end gap-2 pt-2">
              <button
                onClick={() => setShowBanModal(false)}
                className="px-3 py-1.5 text-xs text-slate-500 hover:text-slate-800 cursor-pointer"
              >
                Annuler
              </button>
              <button
                onClick={() => handleToggleBan(selectedUserForDetails)}
                className="px-4 py-1.5 text-xs font-semibold text-white bg-rose-600 hover:bg-rose-700 rounded-lg cursor-pointer"
              >
                Confirmer l'action
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
