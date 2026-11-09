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
  Database
} from 'lucide-react';
import { NavigationTab } from '../../types/medsina';

interface SidebarProps {
  currentTab: NavigationTab;
  onTabChange: (tab: NavigationTab) => void;
  pendingPaymentsCount: number;
  availableLicensesCount: number;
  totalUsersCount?: number;
}

export const Sidebar: React.FC<SidebarProps> = ({
  currentTab,
  onTabChange,
  pendingPaymentsCount,
  availableLicensesCount,
  totalUsersCount = 43
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
      badge: totalUsersCount.toLocaleString('fr-FR')
    },
    {
      id: 'payments' as NavigationTab,
      label: 'Paiements & Facturation',
      icon: CreditCard,
      badge: pendingPaymentsCount > 0 ? `${pendingPaymentsCount} Attente` : undefined,
      badgeColor: 'text-amber-600 dark:text-amber-400 font-bold'
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
      badge: 'Octenium'
    }
  ];

  return (
    <aside className="w-64 shrink-0 hidden md:flex flex-col justify-between bg-slate-50 dark:bg-slate-900/60 border-r border-slate-200 dark:border-slate-800 p-4 transition-colors">
      <div className="space-y-6">
        {/* Module 1: Plateforme & Finance */}
        <div>
          <p className="px-3 text-[11px] font-semibold uppercase tracking-wider text-slate-400 dark:text-slate-500 mb-2">
            Gestion & Souscriptions
          </p>
          <nav className="space-y-1">
            {primaryNavItems.map((item) => {
              const Icon = item.icon;
              const isActive = currentTab === item.id;
              return (
                <button
                  key={item.id}
                  onClick={() => onTabChange(item.id)}
                  className={`w-full flex items-center justify-between px-3 py-2.5 rounded-lg text-xs font-medium transition-colors cursor-pointer ${
                    isActive
                      ? 'bg-teal-50 dark:bg-teal-950/50 text-teal-700 dark:text-teal-300 border border-teal-200/60 dark:border-teal-800/50 font-semibold'
                      : 'text-slate-700 dark:text-slate-300 hover:bg-slate-200/60 dark:hover:bg-slate-800/60'
                  }`}
                >
                  <div className="flex items-center gap-2.5 min-w-0">
                    <Icon className={`w-4 h-4 shrink-0 ${isActive ? 'text-teal-600 dark:text-teal-400' : 'text-slate-400 dark:text-slate-500'}`} />
                    <span className="truncate">{item.label}</span>
                  </div>
                  {item.badge && (
                    <span className={`text-[11px] tabular-nums whitespace-nowrap pl-2 ${item.badgeColor || 'text-slate-500 dark:text-slate-400 font-mono'}`}>
                      {item.badge}
                    </span>
                  )}
                </button>
              );
            })}
          </nav>
        </div>

        {/* Module 2: Pédagogie & IA */}
        <div>
          <p className="px-3 text-[11px] font-semibold uppercase tracking-wider text-slate-400 dark:text-slate-500 mb-2">
            Examens & Automatisation
          </p>
          <nav className="space-y-1">
            {secondaryNavItems.map((item) => {
              const Icon = item.icon;
              const isActive = currentTab === item.id;
              return (
                <button
                  key={item.id}
                  onClick={() => onTabChange(item.id)}
                  className={`w-full flex items-center justify-between px-3 py-2.5 rounded-lg text-xs font-medium transition-colors cursor-pointer ${
                    isActive
                      ? 'bg-teal-50 dark:bg-teal-950/50 text-teal-700 dark:text-teal-300 border border-teal-200/60 dark:border-teal-800/50 font-semibold'
                      : 'text-slate-700 dark:text-slate-300 hover:bg-slate-200/60 dark:hover:bg-slate-800/60'
                  }`}
                >
                  <div className="flex items-center gap-2.5 min-w-0">
                    <Icon className={`w-4 h-4 shrink-0 ${isActive ? 'text-teal-600 dark:text-teal-400' : 'text-slate-400 dark:text-slate-500'}`} />
                    <span className="truncate">{item.label}</span>
                  </div>
                  {item.badge && (
                    <span className="text-[11px] font-mono text-slate-400 whitespace-nowrap pl-2">
                      {item.badge}
                    </span>
                  )}
                </button>
              );
            })}
          </nav>
        </div>
      </div>

      {/* Supabase & Octenium Connection Card */}
      <div className="pt-4 border-t border-slate-200 dark:border-slate-800 space-y-2 text-xs">
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
        <p className="text-[11px] text-slate-400 dark:text-slate-500 pt-1">
          Medsina Medical Suite · Blida, DZ
        </p>
      </div>
    </aside>
  );
};
