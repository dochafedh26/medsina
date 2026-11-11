import React from 'react';
import { 
  BarChart2, 
  Users, 
  CreditCard, 
  Tag, 
  Key, 
  Award, 
  Megaphone, 
  Bot, 
  DownloadCloud, 
  CheckCircle2, 
  Database,
  PanelLeftClose,
  PanelLeftOpen
} from 'lucide-react';
import { NavigationTab } from '../../types/medsina';
import iconEmblem from '../../assets/images/medsina-icon.png';

interface SidebarProps {
  currentTab: NavigationTab;
  onTabChange: (tab: NavigationTab) => void;
  pendingPaymentsCount: number;
  availableLicensesCount: number;
  totalUsersCount?: number;
  isCollapsed?: boolean;
  onToggleCollapse?: () => void;
}

export const Sidebar: React.FC<SidebarProps> = ({
  currentTab,
  onTabChange,
  pendingPaymentsCount,
  availableLicensesCount,
  totalUsersCount = 43,
  isCollapsed = false,
  onToggleCollapse
}) => {
  const primaryNavItems = [
    {
      id: 'overview' as NavigationTab,
      label: 'Métriques & KPIs',
      icon: BarChart2,
      badge: undefined
    },
    {
      id: 'users' as NavigationTab,
      label: 'Médecins & Comptes',
      icon: Users,
      badge: totalUsersCount.toLocaleString('fr-FR'),
      badgeColor: 'text-slate-500 dark:text-slate-400 font-mono'
    },
    {
      id: 'payments' as NavigationTab,
      label: 'Paiements & Facturation',
      icon: CreditCard,
      badge: pendingPaymentsCount > 0 ? `${pendingPaymentsCount} Attente` : undefined,
      badgeColor: 'text-amber-600 dark:text-amber-400 font-bold',
      hasAlert: pendingPaymentsCount > 0
    },
    {
      id: 'pricing' as NavigationTab,
      label: 'Tarifs & Formules',
      icon: Tag,
      badge: 'DZD'
    },
    {
      id: 'licenses' as NavigationTab,
      label: 'Clés de Licence VIP',
      icon: Key,
      badge: availableLicensesCount > 0 ? `${availableLicensesCount} Libres` : undefined,
      badgeColor: 'text-teal-600 dark:text-teal-400 font-semibold'
    }
  ];

  const secondaryNavItems = [
    {
      id: 'exams' as NavigationTab,
      label: 'Concours Blancs & Examens',
      icon: Award,
      badge: 'Actif'
    },
    {
      id: 'announcements' as NavigationTab,
      label: 'Annonces & Système',
      icon: Megaphone,
      badge: undefined
    },
    {
      id: 'ai_agents' as NavigationTab,
      label: 'Agents IA GitHub',
      icon: Bot,
      badge: '18 Actifs'
    }
  ];

  return (
    <aside
      className={`shrink-0 hidden md:flex flex-col justify-between bg-slate-50 dark:bg-slate-900/60 border-r border-slate-200 dark:border-slate-800 transition-all duration-300 ease-in-out sticky top-14 md:top-16 h-[calc(100vh-3.5rem)] md:h-[calc(100vh-4rem)] overflow-y-auto no-scrollbar z-30 ${
        isCollapsed ? 'w-[72px] px-2.5 py-3' : 'w-64 p-4'
      }`}
    >
      <div className="space-y-4">
        {/* Collapse / Expand Header Toggle */}
        <div
          className={`flex items-center ${
            isCollapsed ? 'justify-center' : 'justify-between'
          } pb-3 border-b border-slate-200/80 dark:border-slate-800 transition-all`}
        >
          {!isCollapsed && (
            <span className="text-[10px] font-bold uppercase tracking-wider text-slate-400 dark:text-slate-500 pl-1 select-none">
              Menu Navigation
            </span>
          )}
          {onToggleCollapse && (
            <button
              type="button"
              onClick={onToggleCollapse}
              aria-label={isCollapsed ? 'Agrandir le menu' : 'Réduire le menu'}
              title={isCollapsed ? 'Agrandir le menu latéral (Ctrl+B)' : 'Réduire le menu latéral (Ctrl+B)'}
              className="p-1.5 text-slate-400 hover:text-slate-700 dark:hover:text-slate-200 rounded-lg hover:bg-slate-200/70 dark:hover:bg-slate-800/70 transition-colors cursor-pointer shrink-0"
            >
              {isCollapsed ? (
                <PanelLeftOpen className="w-4 h-4 text-teal-600 dark:text-teal-400" />
              ) : (
                <PanelLeftClose className="w-4 h-4" />
              )}
            </button>
          )}
        </div>

        {/* Module 1: Plateforme & Finance */}
        <div>
          {!isCollapsed ? (
            <p className="px-3 text-[11px] font-semibold uppercase tracking-wider text-slate-400 dark:text-slate-500 mb-2 select-none">
              Gestion & Souscriptions
            </p>
          ) : (
            <div className="my-2 border-t border-slate-200/70 dark:border-slate-800/70" />
          )}
          <nav className="space-y-1">
            {primaryNavItems.map((item) => {
              const Icon = item.icon;
              const isActive = currentTab === item.id;
              return (
                <div key={item.id} className="relative group">
                  <button
                    type="button"
                    onClick={() => onTabChange(item.id)}
                    title={isCollapsed ? item.label : undefined}
                    className={`w-full flex items-center rounded-xl text-xs font-medium transition-all cursor-pointer ${
                      isCollapsed
                        ? `justify-center p-2.5 ${
                            isActive
                              ? 'bg-teal-600 text-white shadow-xs'
                              : 'text-slate-600 dark:text-slate-400 hover:bg-slate-200/70 dark:hover:bg-slate-800/70 hover:text-slate-900 dark:hover:text-white'
                          }`
                        : `justify-between px-3 py-2.5 ${
                            isActive
                              ? 'bg-teal-50/90 dark:bg-teal-950/60 text-teal-800 dark:text-teal-200 border-l-4 border-teal-500 font-bold shadow-2xs'
                              : 'text-slate-700 dark:text-slate-300 hover:bg-slate-200/60 dark:hover:bg-slate-800/60'
                          }`
                    }`}
                  >
                    <div className="flex items-center gap-2.5 min-w-0">
                      <Icon
                        className={`w-4 h-4 shrink-0 ${
                          isActive
                            ? isCollapsed
                              ? 'text-white'
                              : 'text-teal-600 dark:text-teal-400'
                            : 'text-slate-400 dark:text-slate-500 group-hover:text-teal-600 dark:group-hover:text-teal-400 transition-colors'
                        }`}
                      />
                      {!isCollapsed && <span className="truncate">{item.label}</span>}
                    </div>

                    {!isCollapsed && item.badge && (
                      <span
                        className={`text-[11px] tabular-nums whitespace-nowrap pl-2 ${
                          item.badgeColor || 'text-slate-500 dark:text-slate-400 font-mono'
                        }`}
                      >
                        {item.badge}
                      </span>
                    )}

                    {/* Collapsed Alert Dot */}
                    {isCollapsed && item.hasAlert && (
                      <span className="absolute top-1.5 right-1.5 w-2 h-2 rounded-full bg-amber-500 ring-2 ring-white dark:ring-slate-900 animate-pulse" />
                    )}
                  </button>

                  {/* Sleek Floating Flyout Tooltip when Collapsed */}
                  {isCollapsed && (
                    <div className="opacity-0 pointer-events-none group-hover:opacity-100 group-hover:pointer-events-auto transition-all duration-150 ease-out absolute left-full top-1/2 -translate-y-1/2 ml-3 z-50 flex items-center">
                      <div className="px-3 py-1.5 bg-slate-900 dark:bg-slate-800 text-white text-xs font-semibold rounded-lg shadow-xl whitespace-nowrap flex items-center gap-2 border border-slate-700">
                        <span>{item.label}</span>
                        {item.badge && (
                          <span className="text-[10px] font-mono px-1.5 py-0.2 rounded bg-teal-500/20 text-teal-300 border border-teal-400/30">
                            {item.badge}
                          </span>
                        )}
                      </div>
                    </div>
                  )}
                </div>
              );
            })}
          </nav>
        </div>

        {/* Module 2: Pédagogie & IA */}
        <div>
          {!isCollapsed ? (
            <p className="px-3 text-[11px] font-semibold uppercase tracking-wider text-slate-400 dark:text-slate-500 mb-2 select-none">
              Examens & Automatisation
            </p>
          ) : (
            <div className="my-2 border-t border-slate-200/70 dark:border-slate-800/70" />
          )}
          <nav className="space-y-1">
            {secondaryNavItems.map((item) => {
              const Icon = item.icon;
              const isActive = currentTab === item.id;
              return (
                <div key={item.id} className="relative group">
                  <button
                    type="button"
                    onClick={() => onTabChange(item.id)}
                    title={isCollapsed ? item.label : undefined}
                    className={`w-full flex items-center rounded-xl text-xs font-medium transition-all cursor-pointer ${
                      isCollapsed
                        ? `justify-center p-2.5 ${
                            isActive
                              ? 'bg-teal-600 text-white shadow-xs'
                              : 'text-slate-600 dark:text-slate-400 hover:bg-slate-200/70 dark:hover:bg-slate-800/70 hover:text-slate-900 dark:hover:text-white'
                          }`
                        : `justify-between px-3 py-2.5 ${
                            isActive
                              ? 'bg-teal-50/90 dark:bg-teal-950/60 text-teal-800 dark:text-teal-200 border-l-4 border-teal-500 font-bold shadow-2xs'
                              : 'text-slate-700 dark:text-slate-300 hover:bg-slate-200/60 dark:hover:bg-slate-800/60'
                          }`
                    }`}
                  >
                    <div className="flex items-center gap-2.5 min-w-0">
                      <Icon
                        className={`w-4 h-4 shrink-0 ${
                          isActive
                            ? isCollapsed
                              ? 'text-white'
                              : 'text-teal-600 dark:text-teal-400'
                            : 'text-slate-400 dark:text-slate-500 group-hover:text-teal-600 dark:group-hover:text-teal-400 transition-colors'
                        }`}
                      />
                      {!isCollapsed && <span className="truncate">{item.label}</span>}
                    </div>

                    {!isCollapsed && item.badge && (
                      <span className="text-[11px] font-mono text-slate-400 whitespace-nowrap pl-2">
                        {item.badge}
                      </span>
                    )}
                  </button>

                  {/* Sleek Floating Flyout Tooltip when Collapsed */}
                  {isCollapsed && (
                    <div className="opacity-0 pointer-events-none group-hover:opacity-100 group-hover:pointer-events-auto transition-all duration-150 ease-out absolute left-full top-1/2 -translate-y-1/2 ml-3 z-50 flex items-center">
                      <div className="px-3 py-1.5 bg-slate-900 dark:bg-slate-800 text-white text-xs font-semibold rounded-lg shadow-xl whitespace-nowrap flex items-center gap-2 border border-slate-700">
                        <span>{item.label}</span>
                        {item.badge && (
                          <span className="text-[10px] font-mono px-1.5 py-0.2 rounded bg-teal-500/20 text-teal-300 border border-teal-400/30">
                            {item.badge}
                          </span>
                        )}
                      </div>
                    </div>
                  )}
                </div>
              );
            })}
          </nav>
        </div>
      </div>

      {/* Supabase & Octenium Connection Status Footer */}
      <div className="pt-3 border-t border-slate-200 dark:border-slate-800 space-y-2 text-xs">
        {!isCollapsed ? (
          <>
            <div className="flex items-center justify-between text-slate-500 dark:text-slate-400">
              <span className="flex items-center gap-1.5 font-medium">
                <Database className="w-3.5 h-3.5 text-teal-600 dark:text-teal-400" />
                Supabase DB
              </span>
              <span className="text-[11px] font-mono tabular-nums text-emerald-600 dark:text-emerald-400">Connecté</span>
            </div>
            <div className="flex items-center justify-between text-slate-500 dark:text-slate-400">
              <span className="flex items-center gap-1.5 font-medium">
                <DownloadCloud className="w-3.5 h-3.5 text-slate-400" />
                Octenium Sync
              </span>
              <span className="text-[11px] font-mono tabular-nums">v2.8.4 OK</span>
            </div>
            <div className="flex items-center gap-2 pt-1 text-slate-400 dark:text-slate-500">
              <img src={iconEmblem} alt="" className="w-3.5 h-3.5 rounded-xs object-contain" />
              <span className="text-[11px]">Medsina Medical Suite · Blida, DZ</span>
            </div>
          </>
        ) : (
          <div className="flex flex-col items-center gap-2.5 py-1">
            <div
              className="p-1.5 rounded-lg bg-slate-200/50 dark:bg-slate-800/50 text-teal-600 dark:text-teal-400 relative cursor-pointer"
              title="Supabase DB Connecté"
            >
              <Database className="w-4 h-4" />
              <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 absolute -top-0.5 -right-0.5" />
            </div>
            <div
              className="p-1.5 rounded-lg bg-slate-200/50 dark:bg-slate-800/50 text-slate-500 dark:text-slate-400 relative cursor-pointer"
              title="Octenium Cloud Sync Actif"
            >
              <DownloadCloud className="w-4 h-4" />
              <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 absolute -top-0.5 -right-0.5" />
            </div>
          </div>
        )}
      </div>
    </aside>
  );
};
