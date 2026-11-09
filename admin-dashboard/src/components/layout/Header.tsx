import React, { useState } from 'react';
import { 
  Activity, 
  Search, 
  Moon, 
  Sun, 
  PlusCircle, 
  Award, 
  CreditCard, 
  Users, 
  Key, 
  Bell, 
  X,
  ShieldCheck,
  Smartphone,
  RefreshCw,
  LogOut,
  Radio
} from 'lucide-react';
import { NavigationTab } from '../../types/medsina';

interface HeaderProps {
  currentTab: NavigationTab;
  onTabChange: (tab: NavigationTab) => void;
  isDarkMode: boolean;
  onToggleDarkMode: () => void;
  pendingPaymentsCount: number;
  onQuickAction: () => void;
  adminUser?: {
    email: string;
    fullName: string;
    medicalRole?: string;
    avatarUrl?: string;
  } | null;
  onSignOut?: () => void;
  onRefresh?: () => void;
  isRefreshing?: boolean;
}

export const Header: React.FC<HeaderProps> = ({
  currentTab,
  onTabChange,
  isDarkMode,
  onToggleDarkMode,
  pendingPaymentsCount,
  onQuickAction,
  adminUser,
  onSignOut,
  onRefresh,
  isRefreshing = false
}) => {
  const [searchQuery, setSearchQuery] = useState('');
  const [showSearchModal, setShowSearchModal] = useState(false);

  const navLinks = [
    { id: 'overview' as NavigationTab, label: 'Métriques & KPIs' },
    { id: 'users' as NavigationTab, label: 'Médecins & Comptes' },
    { 
      id: 'payments' as NavigationTab, 
      label: pendingPaymentsCount > 0 ? `Paiements (${pendingPaymentsCount})` : 'Paiements CCP' 
    },
    { id: 'pricing' as NavigationTab, label: 'Tarifs & Formules' },
    { id: 'licenses' as NavigationTab, label: 'Licences VIP' },
    { id: 'exams' as NavigationTab, label: 'Concours Blancs' },
    { id: 'announcements' as NavigationTab, label: 'Annonces & Système' },
    { id: 'ai_agents' as NavigationTab, label: 'Agents IA GitHub' }
  ];

  return (
    <>
      <header className="sticky top-0 z-40 flex items-center justify-between gap-4 md:gap-8 px-4 md:px-8 py-3.5 bg-white/95 dark:bg-slate-900/95 backdrop-blur-md border-b border-slate-200 dark:border-slate-800 transition-colors">
        {/* Zone 1: Wordmark in display face, single text element, no subtitle pill */}
        <div className="flex items-center gap-3 shrink-0">
          <div className="w-9 h-9 rounded-xl bg-teal-600 dark:bg-teal-500 text-white flex items-center justify-center shadow-xs">
            <Activity className="w-5 h-5 stroke-[2.2]" />
          </div>
          <button 
            onClick={() => onTabChange('overview')}
            className="text-left font-bold text-xl tracking-tight text-slate-900 dark:text-white hover:opacity-90 transition-opacity whitespace-nowrap cursor-pointer"
          >
            MedSina
          </button>
        </div>

        {/* Zone 2: 4-5 concise single-line text links with subtle hover underlines */}
        <nav className="hidden xl:flex items-center gap-5 text-sm font-medium text-slate-600 dark:text-slate-300">
          {navLinks.slice(0, 5).map((link) => (
            <button
              key={link.id}
              onClick={() => onTabChange(link.id)}
              className={`whitespace-nowrap shrink-0 transition-colors cursor-pointer ${
                currentTab === link.id
                  ? 'text-teal-600 dark:text-teal-400 font-semibold underline underline-offset-8 decoration-2 decoration-teal-600 dark:decoration-teal-400'
                  : 'hover:text-slate-900 dark:hover:text-white'
              }`}
            >
              {link.label}
            </button>
          ))}
        </nav>

        {/* Zone 3: Controls & Primary Action */}
        <div className="flex items-center gap-2.5 md:gap-3 shrink-0">
          {/* Quick Search */}
          <button
            onClick={() => setShowSearchModal(true)}
            aria-label="Recherche rapide"
            className="flex items-center gap-2 px-3 py-1.5 text-xs text-slate-500 dark:text-slate-400 bg-slate-100 dark:bg-slate-800 hover:bg-slate-200 dark:hover:bg-slate-700 rounded-lg border border-slate-200 dark:border-slate-700 transition-colors cursor-pointer"
          >
            <Search className="w-3.5 h-3.5" />
            <span className="hidden md:inline">Rechercher (⌘K)</span>
          </button>

          {/* Live Hosting Status */}
          <div className="hidden xl:flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-emerald-50 dark:bg-emerald-950/50 border border-emerald-200 dark:border-emerald-800 text-[11px] font-semibold text-emerald-700 dark:text-emerald-300">
            <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse" />
            <span>Octenium Hosting Live</span>
          </div>

          {/* Live Refresh Button */}
          {onRefresh && (
            <button
              onClick={onRefresh}
              disabled={isRefreshing}
              title="Rafraîchir les données Supabase"
              className="p-2 text-slate-600 dark:text-slate-300 hover:text-slate-900 dark:hover:text-white rounded-lg hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors cursor-pointer disabled:opacity-50"
            >
              <RefreshCw className={`w-4 h-4 ${isRefreshing ? 'animate-spin text-teal-600' : ''}`} />
            </button>
          )}

          {/* Theme Toggle */}
          <button
            onClick={onToggleDarkMode}
            aria-label="Changer le thème"
            className="p-2 text-slate-600 dark:text-slate-300 hover:text-slate-900 dark:hover:text-white rounded-lg hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors cursor-pointer"
          >
            {isDarkMode ? <Sun className="w-4 h-4 text-amber-400" /> : <Moon className="w-4 h-4" />}
          </button>

          {/* Primary Action Button */}
          <button
            onClick={onQuickAction}
            className="flex items-center gap-1.5 px-3.5 py-1.5 text-xs font-semibold text-white bg-teal-600 hover:bg-teal-700 dark:bg-teal-500 dark:hover:bg-teal-600 rounded-lg shadow-xs transition-colors cursor-pointer whitespace-nowrap shrink-0"
          >
            <PlusCircle className="w-3.5 h-3.5" />
            <span>Nouveau Concours Blanc</span>
          </button>

          {/* Admin User Profile & Sign Out */}
          <div className="flex items-center gap-2.5 pl-2 border-l border-slate-200 dark:border-slate-800">
            <div className="w-8 h-8 rounded-full bg-slate-200 dark:bg-slate-700 overflow-hidden ring-1 ring-teal-500/40 shrink-0">
              <img
                src={adminUser?.avatarUrl || "/src/assets/images/doctor_avatar_male_1794207754386.jpg"}
                alt={adminUser?.fullName || "Dr. Hafedh"}
                referrerPolicy="no-referrer"
                className="w-full h-full object-cover"
                onError={(e) => {
                  e.currentTarget.style.display = 'none';
                }}
              />
            </div>
            <div className="hidden lg:block text-left text-xs leading-tight">
              <p className="font-semibold text-slate-800 dark:text-slate-200">{adminUser?.fullName || 'Dr. Hafedh'}</p>
              <p className="text-[11px] text-teal-600 dark:text-teal-400 font-medium">
                {adminUser?.medicalRole || 'Administrateur'}
              </p>
            </div>
            {onSignOut && (
              <button
                onClick={onSignOut}
                title="Se déconnecter de la console"
                className="p-1.5 ml-1 text-slate-400 hover:text-red-500 hover:bg-red-50 dark:hover:bg-red-950/40 rounded-lg transition-colors cursor-pointer"
              >
                <LogOut className="w-4 h-4" />
              </button>
            )}
          </div>
        </div>
      </header>

      {/* Quick Search Shortcut Modal */}
      {showSearchModal && (
        <div className="fixed inset-0 z-50 flex items-start justify-center pt-24 px-4 bg-slate-950/50 backdrop-blur-xs">
          <div className="w-full max-w-xl bg-white dark:bg-slate-900 rounded-xl shadow-2xl border border-slate-200 dark:border-slate-800 overflow-hidden animate-in fade-in-50 duration-150">
            <div className="flex items-center px-4 py-3 border-b border-slate-200 dark:border-slate-800">
              <Search className="w-4 h-4 text-slate-400 mr-2.5 shrink-0" />
              <input
                type="text"
                autoFocus
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="Rechercher un médecin, étudiant, reçu CCP, clé de licence..."
                className="w-full bg-transparent text-sm text-slate-900 dark:text-white placeholder-slate-400 focus:outline-none"
              />
              <button
                onClick={() => setShowSearchModal(false)}
                className="p-1 text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 cursor-pointer"
              >
                <X className="w-4 h-4" />
              </button>
            </div>
            <div className="p-4 max-h-80 overflow-y-auto text-xs space-y-2.5">
              <p className="font-semibold text-slate-400 uppercase tracking-wider text-[11px]">Raccourcis Administrateur</p>
              <div 
                onClick={() => { onTabChange('payments'); setShowSearchModal(false); }}
                className="p-2.5 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-800/80 cursor-pointer flex items-center justify-between"
              >
                <div className="flex items-center gap-2">
                  <CreditCard className="w-4 h-4 text-teal-600 dark:text-teal-400" />
                  <span className="font-medium text-slate-800 dark:text-slate-200">Validation des Paiements BaridiMob & CCP</span>
                </div>
                <span className="text-slate-400 font-mono text-[11px]">{pendingPaymentsCount} en attente</span>
              </div>
              <div 
                onClick={() => { onTabChange('users'); setShowSearchModal(false); }}
                className="p-2.5 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-800/80 cursor-pointer flex items-center justify-between"
              >
                <div className="flex items-center gap-2">
                  <Users className="w-4 h-4 text-blue-600 dark:text-blue-400" />
                  <span className="font-medium text-slate-800 dark:text-slate-200">Gestion des Comptes Médecins & Étudiants</span>
                </div>
                <span className="text-slate-400 text-[11px]">4,826 inscrits</span>
              </div>
              <div 
                onClick={() => { onTabChange('exams'); setShowSearchModal(false); }}
                className="p-2.5 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-800/80 cursor-pointer flex items-center justify-between"
              >
                <div className="flex items-center gap-2">
                  <Award className="w-4 h-4 text-amber-500" />
                  <span className="font-medium text-slate-800 dark:text-slate-200">Concours Blanc National Résidanat 2027</span>
                </div>
                <span className="text-slate-400 text-[11px]">Épreuve d'Automne</span>
              </div>
              <div 
                onClick={() => { onTabChange('licenses'); setShowSearchModal(false); }}
                className="p-2.5 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-800/80 cursor-pointer flex items-center justify-between"
              >
                <div className="flex items-center gap-2">
                  <Key className="w-4 h-4 text-purple-600 dark:text-purple-400" />
                  <span className="font-medium text-slate-800 dark:text-slate-200">Générateur de Clés VIP Medsina</span>
                </div>
                <span className="text-slate-400 text-[11px]">264 disponibles</span>
              </div>
            </div>
            <div className="px-4 py-2.5 bg-slate-50 dark:bg-slate-950/50 border-t border-slate-200 dark:border-slate-800 flex items-center justify-between text-[11px] text-slate-500 dark:text-slate-400">
              <span>Appuyez sur Échap pour fermer</span>
              <span className="font-mono">Medsina Admin Core v2.8</span>
            </div>
          </div>
        </div>
      )}
    </>
  );
};
