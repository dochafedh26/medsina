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
  Menu,
  BarChart2,
  Tag,
  Megaphone,
  Bot,
  ShieldCheck,
  Smartphone,
  RefreshCw,
  LogOut,
  Radio,
  ExternalLink,
  ChevronRight
} from 'lucide-react';
import { NavigationTab } from '../../types/medsina';
import logoLight from '../../assets/images/medsina-logo.png';
import logoDark from '../../assets/images/medsina-logo-dark.png';
import iconEmblem from '../../assets/images/medsina-icon.png';
import defaultDoctorAvatar from '../../assets/images/doctor_avatar_male_1794207754386.jpg';

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
  isMobileDrawerOpen?: boolean;
  onToggleMobileDrawer?: () => void;
  onCloseMobileDrawer?: () => void;
  totalUsersCount?: number;
  availableLicensesCount?: number;
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
  isRefreshing = false,
  isMobileDrawerOpen,
  onToggleMobileDrawer,
  onCloseMobileDrawer,
  totalUsersCount = 43,
  availableLicensesCount = 264
}) => {
  const [searchQuery, setSearchQuery] = useState('');
  const [showSearchModal, setShowSearchModal] = useState(false);
  const [localDrawerOpen, setLocalDrawerOpen] = useState(false);

  const drawerIsOpen = isMobileDrawerOpen !== undefined ? isMobileDrawerOpen : localDrawerOpen;
  const toggleDrawer = onToggleMobileDrawer || (() => setLocalDrawerOpen(!localDrawerOpen));
  const closeDrawer = onCloseMobileDrawer || (() => setLocalDrawerOpen(false));

  const allNavLinks = [
    { 
      id: 'overview' as NavigationTab, 
      label: 'Métriques & KPIs',
      icon: BarChart2
    },
    { 
      id: 'users' as NavigationTab, 
      label: 'Médecins & Comptes',
      icon: Users,
      badge: totalUsersCount > 0 ? `${totalUsersCount}` : undefined
    },
    { 
      id: 'payments' as NavigationTab, 
      label: 'Paiements CCP & BaridiMob',
      icon: CreditCard,
      badge: pendingPaymentsCount > 0 ? `${pendingPaymentsCount} En attente` : undefined,
      badgeColor: 'bg-amber-100 text-amber-800 dark:bg-amber-950 dark:text-amber-300'
    },
    { 
      id: 'pricing' as NavigationTab, 
      label: 'Tarifs & Formules',
      icon: Tag,
      badge: 'DZD'
    },
    { 
      id: 'licenses' as NavigationTab, 
      label: 'Licences VIP & Codes',
      icon: Key,
      badge: availableLicensesCount > 0 ? `${availableLicensesCount} Libres` : undefined,
      badgeColor: 'bg-teal-100 text-teal-800 dark:bg-teal-950 dark:text-teal-300'
    },
    { 
      id: 'exams' as NavigationTab, 
      label: 'Concours Blancs Nationaux',
      icon: Award,
      badge: 'Actif'
    },
    { 
      id: 'announcements' as NavigationTab, 
      label: 'Annonces & Diffusion',
      icon: Megaphone
    },
    { 
      id: 'ai_agents' as NavigationTab, 
      label: 'Agents IA GitHub',
      icon: Bot,
      badge: 'Octenium'
    }
  ];

  const handleSelectTab = (tab: NavigationTab) => {
    onTabChange(tab);
    closeDrawer();
  };

  return (
    <>
      <header className="sticky top-0 z-40 flex items-center justify-between gap-2 sm:gap-6 md:gap-8 px-2.5 sm:px-6 md:px-8 py-2.5 sm:py-3 bg-white/95 dark:bg-slate-900/95 backdrop-blur-md border-b border-slate-200 dark:border-slate-800 transition-colors">
        {/* Zone 1: Mobile Hamburger & Wordmark */}
        <div className="flex items-center gap-1.5 sm:gap-3 shrink-0">
          {/* Mobile Hamburger Toggle Button */}
          <button
            onClick={toggleDrawer}
            aria-label="Ouvrir le menu de navigation"
            className="md:hidden p-1.5 sm:p-2 -ml-0.5 text-slate-700 dark:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-800 rounded-lg transition-colors cursor-pointer"
          >
            <Menu className="w-5 h-5" />
          </button>

          <button 
            onClick={() => handleSelectTab('overview')}
            className="flex items-center gap-2 text-left hover:opacity-90 transition-opacity whitespace-nowrap cursor-pointer"
            title="MedSina — Console Administrateur"
          >
            {/* Mobile emblem + title (compact, crisp, no overflow) */}
            <div className="flex sm:hidden items-center gap-1.5">
              <img 
                src={iconEmblem} 
                alt="MedSina" 
                className="h-7 w-7 object-contain"
              />
              <span className="font-bold text-slate-900 dark:text-white text-base tracking-tight">MedSina</span>
            </div>
            {/* Tablet & Desktop full horizontal banner logo */}
            <img 
              src={isDarkMode ? logoDark : logoLight} 
              alt="Medsina" 
              className="hidden sm:block h-8 sm:h-9 w-auto object-contain max-w-[130px] sm:max-w-[160px]"
            />
            <span className="hidden sm:inline-block text-[10px] font-mono font-bold uppercase px-1.5 py-0.5 rounded bg-teal-50 dark:bg-teal-950 text-teal-700 dark:text-teal-300 border border-teal-200/60 dark:border-teal-800">
              Admin
            </span>
          </button>
        </div>

        {/* Zone 2: Desktop 5 concise single-line text links with subtle hover underlines */}
        <nav className="hidden xl:flex items-center gap-5 text-sm font-medium text-slate-600 dark:text-slate-300">
          {allNavLinks.slice(0, 5).map((link) => (
            <button
              key={link.id}
              onClick={() => handleSelectTab(link.id)}
              className={`whitespace-nowrap shrink-0 transition-colors cursor-pointer flex items-center gap-1.5 ${
                currentTab === link.id
                  ? 'text-teal-600 dark:text-teal-400 font-semibold underline underline-offset-8 decoration-2 decoration-teal-600 dark:decoration-teal-400'
                  : 'hover:text-slate-900 dark:hover:text-white'
              }`}
            >
              <span>{link.label}</span>
              {link.id === 'payments' && pendingPaymentsCount > 0 && (
                <span className="px-1.5 py-0.2 rounded-full text-[10px] bg-amber-500 text-white font-bold animate-pulse">
                  {pendingPaymentsCount}
                </span>
              )}
            </button>
          ))}
        </nav>

        {/* Zone 3: Controls & Primary Action */}
        <div className="flex items-center gap-1 sm:gap-2 md:gap-3 shrink-0">
          {/* Quick Search - hidden on mobile header, accessible via drawer */}
          <button
            onClick={() => setShowSearchModal(true)}
            aria-label="Recherche rapide"
            className="hidden sm:flex items-center gap-1.5 px-2.5 sm:px-3 py-1.5 text-xs text-slate-500 dark:text-slate-400 bg-slate-100 dark:bg-slate-800 hover:bg-slate-200 dark:hover:bg-slate-700 rounded-lg border border-slate-200 dark:border-slate-700 transition-colors cursor-pointer"
          >
            <Search className="w-3.5 h-3.5" />
            <span className="hidden sm:inline">Rechercher</span>
            <kbd className="hidden lg:inline text-[10px] font-mono text-slate-400 dark:text-slate-500 bg-white dark:bg-slate-900 px-1 rounded border border-slate-200 dark:border-slate-700">⌘K</kbd>
          </button>

          {/* Live Hosting Status */}
          <div className="hidden xl:flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-emerald-50 dark:bg-emerald-950/50 border border-emerald-200 dark:border-emerald-800 text-[11px] font-semibold text-emerald-700 dark:text-emerald-300">
            <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse" />
            <span>Octenium Live</span>
          </div>

          {/* Live Refresh Button */}
          {onRefresh && (
            <button
              onClick={onRefresh}
              disabled={isRefreshing}
              title="Rafraîchir les données Supabase"
              className="p-1.5 text-slate-600 dark:text-slate-300 hover:text-slate-900 dark:hover:text-white rounded-lg hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors cursor-pointer disabled:opacity-50 shrink-0"
            >
              <RefreshCw className={`w-4 h-4 ${isRefreshing ? 'animate-spin text-teal-600' : ''}`} />
            </button>
          )}

          {/* Theme Toggle */}
          <button
            onClick={onToggleDarkMode}
            aria-label="Changer le thème"
            className="p-1.5 text-slate-600 dark:text-slate-300 hover:text-slate-900 dark:hover:text-white rounded-lg hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors cursor-pointer shrink-0"
          >
            {isDarkMode ? <Sun className="w-4 h-4 text-amber-400" /> : <Moon className="w-4 h-4" />}
          </button>

          {/* Primary Action Button (Desktop & Tablet) */}
          <button
            onClick={onQuickAction}
            className="hidden sm:flex items-center gap-1.5 px-3 py-1.5 text-xs font-semibold text-white bg-teal-600 hover:bg-teal-700 dark:bg-teal-500 dark:hover:bg-teal-600 rounded-lg shadow-xs transition-colors cursor-pointer whitespace-nowrap shrink-0"
          >
            <PlusCircle className="w-3.5 h-3.5" />
            <span>Nouveau Concours</span>
          </button>

          {/* Admin User Profile & Sign Out */}
          <div className="flex items-center gap-1 sm:gap-2 pl-1 sm:pl-2 sm:border-l border-slate-200 dark:border-slate-800 shrink-0">
            <div className="w-7 h-7 sm:w-8 sm:h-8 rounded-full bg-teal-600 text-white font-bold flex items-center justify-center overflow-hidden ring-1 ring-teal-500/40 shrink-0 text-xs shadow-xs">
              <img
                src={adminUser?.avatarUrl || defaultDoctorAvatar}
                alt={adminUser?.fullName || "Dr. Hafedh"}
                referrerPolicy="no-referrer"
                className="w-full h-full object-cover"
                onError={(e) => {
                  e.currentTarget.style.display = 'none';
                }}
              />
              <span className="select-none">
                {(adminUser?.fullName || 'DH').split(' ').map(n => n[0]).join('').slice(0, 2).toUpperCase()}
              </span>
            </div>
            <div className="hidden lg:block text-left text-xs leading-tight">
              <p className="font-semibold text-slate-800 dark:text-slate-200 truncate max-w-[120px]">
                {adminUser?.fullName || 'Dr. Hafedh'}
              </p>
              <p className="text-[11px] text-teal-600 dark:text-teal-400 font-medium">
                {adminUser?.medicalRole || 'Administrateur'}
              </p>
            </div>
            {onSignOut && (
              <button
                onClick={onSignOut}
                title="Se déconnecter de la console"
                className="p-1.5 text-slate-400 hover:text-red-500 hover:bg-red-50 dark:hover:bg-red-950/40 rounded-lg transition-colors cursor-pointer shrink-0"
              >
                <LogOut className="w-4 h-4" />
              </button>
            )}
          </div>
        </div>
      </header>

      {/* Mobile Slide-Over Navigation Drawer */}
      {drawerIsOpen && (
        <div className="fixed inset-0 z-50 md:hidden">
          {/* Backdrop */}
          <div 
            onClick={closeDrawer}
            className="fixed inset-0 bg-slate-950/60 backdrop-blur-xs transition-opacity animate-in fade-in-50 duration-200"
          />

          {/* Drawer Sheet */}
          <div className="fixed inset-y-0 left-0 w-full max-w-xs sm:max-w-sm bg-white dark:bg-slate-900 shadow-2xl flex flex-col border-r border-slate-200 dark:border-slate-800 animate-in slide-in-from-left duration-250">
            {/* Drawer Header */}
            <div className="p-4 border-b border-slate-200 dark:border-slate-800 flex items-center justify-between bg-slate-50 dark:bg-slate-950/50">
              <div className="flex items-center gap-2">
                <img 
                  src={isDarkMode ? logoDark : logoLight} 
                  alt="Medsina Admin" 
                  className="h-7 w-auto object-contain max-w-[130px]"
                />
                <span className="text-[10px] font-mono font-bold uppercase px-1.5 py-0.5 rounded bg-teal-50 dark:bg-teal-950 text-teal-700 dark:text-teal-300 border border-teal-200/60 dark:border-teal-800">
                  Admin
                </span>
              </div>

              <button
                onClick={closeDrawer}
                aria-label="Fermer le menu"
                className="p-1.5 text-slate-400 hover:text-slate-700 dark:hover:text-slate-200 rounded-lg cursor-pointer"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {/* Admin Profile Banner in Drawer */}
            <div className="p-4 border-b border-slate-200 dark:border-slate-800 bg-slate-50/50 dark:bg-slate-900/50">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-full bg-teal-600 text-white font-bold flex items-center justify-center overflow-hidden ring-2 ring-teal-500/50 shrink-0 text-sm shadow-xs">
                  <img
                    src={adminUser?.avatarUrl || defaultDoctorAvatar}
                    alt={adminUser?.fullName || "Dr. Hafedh"}
                    className="w-full h-full object-cover"
                    onError={(e) => { e.currentTarget.style.display = 'none'; }}
                  />
                  <span className="select-none">
                    {(adminUser?.fullName || 'DH').split(' ').map(n => n[0]).join('').slice(0, 2).toUpperCase()}
                  </span>
                </div>
                <div className="min-w-0 flex-1">
                  <p className="font-bold text-sm text-slate-900 dark:text-white truncate">
                    {adminUser?.fullName || 'Dr. Hafedh'}
                  </p>
                  <p className="text-xs text-teal-600 dark:text-teal-400 font-medium">
                    {adminUser?.medicalRole || 'Administrateur MedSina'}
                  </p>
                  <p className="text-[11px] text-slate-400 font-mono truncate">
                    {adminUser?.email}
                  </p>
                </div>
              </div>

              <div className="mt-2.5 flex items-center gap-2">
                <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-semibold bg-emerald-100 text-emerald-800 dark:bg-emerald-950 dark:text-emerald-300">
                  <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse" />
                  Octenium Cloud Live
                </span>
                <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-mono font-semibold bg-teal-100 text-teal-800 dark:bg-teal-950 dark:text-teal-300">
                  Super-Admin
                </span>
              </div>
            </div>

            {/* Module Navigation List */}
            <div className="flex-1 overflow-y-auto p-3 space-y-1">
              <p className="px-3 py-1 text-[10px] font-bold uppercase tracking-wider text-slate-400 dark:text-slate-500">
                Modules de Gestion
              </p>
              {allNavLinks.map((item) => {
                const Icon = item.icon;
                const isActive = currentTab === item.id;
                return (
                  <button
                    key={item.id}
                    onClick={() => handleSelectTab(item.id)}
                    className={`w-full flex items-center justify-between px-3 py-2.5 rounded-xl text-xs font-medium transition-all cursor-pointer ${
                      isActive
                        ? 'bg-teal-600 text-white font-semibold shadow-xs'
                        : 'text-slate-700 dark:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-800'
                    }`}
                  >
                    <div className="flex items-center gap-3 min-w-0">
                      <Icon className={`w-4 h-4 shrink-0 ${isActive ? 'text-white' : 'text-slate-400'}`} />
                      <span className="truncate">{item.label}</span>
                    </div>
                    {item.badge && (
                      <span className={`text-[10px] px-2 py-0.5 rounded-full font-mono font-semibold whitespace-nowrap ${
                        isActive 
                          ? 'bg-white/20 text-white' 
                          : item.badgeColor || 'bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300'
                      }`}>
                        {item.badge}
                      </span>
                    )}
                  </button>
                );
              })}
            </div>

            {/* Drawer Bottom Actions */}
            <div className="p-3 border-t border-slate-200 dark:border-slate-800 space-y-2 bg-slate-50/50 dark:bg-slate-950/50">
              <button
                onClick={() => {
                  onQuickAction();
                  closeDrawer();
                }}
                className="w-full flex items-center justify-center gap-2 py-2 px-3 text-xs font-semibold text-white bg-teal-600 hover:bg-teal-700 rounded-lg shadow-xs cursor-pointer"
              >
                <PlusCircle className="w-4 h-4" />
                <span>Nouveau Concours Blanc</span>
              </button>

              <div className="flex items-center gap-2">
                {onRefresh && (
                  <button
                    onClick={() => {
                      onRefresh();
                      closeDrawer();
                    }}
                    className="flex-1 flex items-center justify-center gap-1.5 py-2 px-3 text-xs font-medium text-slate-700 dark:text-slate-200 bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg hover:bg-slate-50 cursor-pointer"
                  >
                    <RefreshCw className="w-3.5 h-3.5 text-teal-600" />
                    <span>Rafraîchir</span>
                  </button>
                )}

                <button
                  onClick={onToggleDarkMode}
                  className="flex-1 flex items-center justify-center gap-1.5 py-2 px-3 text-xs font-medium text-slate-700 dark:text-slate-200 bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg hover:bg-slate-50 cursor-pointer"
                >
                  {isDarkMode ? <Sun className="w-3.5 h-3.5 text-amber-400" /> : <Moon className="w-3.5 h-3.5" />}
                  <span>{isDarkMode ? 'Clair' : 'Sombre'}</span>
                </button>
              </div>

              {onSignOut && (
                <button
                  onClick={() => {
                    closeDrawer();
                    onSignOut();
                  }}
                  className="w-full flex items-center justify-center gap-2 py-2 px-3 text-xs font-semibold text-rose-600 dark:text-rose-400 hover:bg-rose-50 dark:hover:bg-rose-950/40 rounded-lg border border-rose-200 dark:border-rose-900/60 transition-colors cursor-pointer"
                >
                  <LogOut className="w-4 h-4" />
                  <span>Se déconnecter de la console</span>
                </button>
              )}
            </div>
          </div>
        </div>
      )}

      {/* Quick Search Shortcut Modal */}
      {showSearchModal && (
        <div className="fixed inset-0 z-50 flex items-start justify-center pt-16 sm:pt-24 px-4 bg-slate-950/60 backdrop-blur-xs">
          <div className="w-full max-w-xl bg-white dark:bg-slate-900 rounded-xl shadow-2xl border border-slate-200 dark:border-slate-800 overflow-hidden animate-in fade-in-50 duration-150">
            <div className="flex items-center px-4 py-3 border-b border-slate-200 dark:border-slate-800">
              <Search className="w-4 h-4 text-slate-400 mr-2.5 shrink-0" />
              <input
                type="text"
                autoFocus
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="Rechercher un médecin, reçu CCP, clé de licence..."
                className="w-full bg-transparent text-sm text-slate-900 dark:text-white placeholder-slate-400 focus:outline-none"
              />
              <button
                onClick={() => setShowSearchModal(false)}
                className="p-1 text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 cursor-pointer"
              >
                <X className="w-4 h-4" />
              </button>
            </div>
            <div className="p-3 sm:p-4 max-h-80 overflow-y-auto text-xs space-y-2">
              <p className="font-semibold text-slate-400 uppercase tracking-wider text-[10px]">Raccourcis Administrateur</p>
              <div 
                onClick={() => { handleSelectTab('payments'); setShowSearchModal(false); }}
                className="p-2.5 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-800/80 cursor-pointer flex items-center justify-between"
              >
                <div className="flex items-center gap-2">
                  <CreditCard className="w-4 h-4 text-teal-600 dark:text-teal-400" />
                  <span className="font-medium text-slate-800 dark:text-slate-200">Validation des Paiements BaridiMob & CCP</span>
                </div>
                <span className="text-slate-400 font-mono text-[11px]">{pendingPaymentsCount} en attente</span>
              </div>
              <div 
                onClick={() => { handleSelectTab('users'); setShowSearchModal(false); }}
                className="p-2.5 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-800/80 cursor-pointer flex items-center justify-between"
              >
                <div className="flex items-center gap-2">
                  <Users className="w-4 h-4 text-blue-600 dark:text-blue-400" />
                  <span className="font-medium text-slate-800 dark:text-slate-200">Gestion des Comptes Médecins & Étudiants</span>
                </div>
                <span className="text-slate-400 text-[11px]">{totalUsersCount} inscrits</span>
              </div>
              <div 
                onClick={() => { handleSelectTab('exams'); setShowSearchModal(false); }}
                className="p-2.5 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-800/80 cursor-pointer flex items-center justify-between"
              >
                <div className="flex items-center gap-2">
                  <Award className="w-4 h-4 text-amber-500" />
                  <span className="font-medium text-slate-800 dark:text-slate-200">Concours Blanc National Résidanat 2027</span>
                </div>
                <span className="text-slate-400 text-[11px]">Épreuve Nationale</span>
              </div>
              <div 
                onClick={() => { handleSelectTab('licenses'); setShowSearchModal(false); }}
                className="p-2.5 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-800/80 cursor-pointer flex items-center justify-between"
              >
                <div className="flex items-center gap-2">
                  <Key className="w-4 h-4 text-purple-600 dark:text-purple-400" />
                  <span className="font-medium text-slate-800 dark:text-slate-200">Générateur de Clés VIP Medsina</span>
                </div>
                <span className="text-slate-400 text-[11px]">{availableLicensesCount} disponibles</span>
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
