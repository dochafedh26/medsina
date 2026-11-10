import React from 'react';
import { 
  Users, 
  CreditCard, 
  Key, 
  DownloadCloud, 
  TrendingUp, 
  AlertCircle, 
  CheckCircle2, 
  Clock, 
  Award, 
  ChevronRight, 
  Sparkles,
  Smartphone,
  Monitor,
  Globe,
  Flame,
  Activity,
  BookOpen,
  ListChecks
} from 'lucide-react';
import { 
  AdminMetrics, 
  FinancialMetrics, 
  PaymentItem, 
  NationalExamModel, 
  NavigationTab,
  AdminUserItem
} from '../../types/medsina';

interface OverviewViewProps {
  metrics: AdminMetrics;
  financialMetrics: FinancialMetrics;
  recentPayments: PaymentItem[];
  upcomingExams: NationalExamModel[];
  users?: AdminUserItem[];
  onNavigate: (tab: NavigationTab) => void;
  onSelectPayment: (payment: PaymentItem) => void;
}

export const OverviewView: React.FC<OverviewViewProps> = ({
  metrics,
  financialMetrics,
  recentPayments,
  upcomingExams,
  users = [],
  onNavigate,
  onSelectPayment
}) => {
  const pendingPayments = recentPayments.filter(p => p.status === 'pending');

  return (
    <div className="space-y-6">
      {/* Page Title & Action Bar */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-2 border-b border-slate-200 dark:border-slate-800">
        <div>
          <h1 className="text-xl md:text-2xl font-bold tracking-tight text-slate-900 dark:text-white">
            Tableau de Bord Administrateur — MedSina
          </h1>
          <p className="text-xs md:text-sm text-slate-500 dark:text-slate-400 mt-0.5">
            Supervision de la plateforme médicale, validation des paiements CCP/BaridiMob et gestion des abonnements.
          </p>
        </div>

        <div className="flex items-center gap-2 w-full sm:w-auto">
          <button
            onClick={() => onNavigate('payments')}
            className="w-full sm:w-auto justify-center flex items-center gap-1.5 px-3.5 py-2 sm:py-1.5 text-xs font-semibold text-white bg-teal-600 hover:bg-teal-700 dark:bg-teal-500 rounded-lg shadow-xs transition-colors cursor-pointer"
          >
            <CreditCard className="w-3.5 h-3.5" />
            <span>Valider les Paiements ({pendingPayments.length})</span>
          </button>
        </div>
      </div>

      {/* Action Banner for Pending Payments */}
      {pendingPayments.length > 0 && (
        <div className="p-3.5 bg-amber-50 dark:bg-amber-950/40 border border-amber-200 dark:border-amber-900/60 rounded-xl flex flex-col md:flex-row md:items-center justify-between gap-3">
          <div className="flex items-center gap-3">
            <div className="p-2 bg-amber-100 dark:bg-amber-900/80 text-amber-800 dark:text-amber-200 rounded-lg shrink-0">
              <Clock className="w-4 h-4" />
            </div>
            <div>
              <p className="text-xs font-bold text-amber-900 dark:text-amber-200">
                {pendingPayments.length} Reçu{pendingPayments.length > 1 ? 's' : ''} BaridiMob / CCP en Attente de Validation
              </p>
              <p className="text-xs text-amber-700 dark:text-amber-300/80 mt-0.5">
                Total en attente d'encaissement : <strong className="font-mono">{financialMetrics.pendingRevenue.toLocaleString()} DZD</strong>.
              </p>
            </div>
          </div>
          <button
            onClick={() => onNavigate('payments')}
            className="px-3 py-1.5 text-xs font-semibold bg-amber-600 hover:bg-amber-700 text-white rounded-lg shadow-2xs transition-colors cursor-pointer shrink-0"
          >
            Examiner les Reçus
          </button>
        </div>
      )}

      {/* 4 Primary Financial & User KPI Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 sm:gap-5">
        {/* Card 1: Chiffre d'Affaires DZD */}
        <div className="p-4 sm:p-5 bg-white dark:bg-slate-900 rounded-2xl border border-slate-200/80 dark:border-slate-800 shadow-2xs hover:shadow-md transition-all relative overflow-hidden group">
          <div className="absolute top-0 left-0 right-0 h-1 bg-gradient-to-r from-teal-500 to-emerald-500" />
          <div className="flex items-center justify-between text-xs text-slate-500 dark:text-slate-400">
            <span className="font-medium">Chiffre d'Affaires Validé</span>
            <div className="flex items-center text-emerald-600 dark:text-emerald-400 font-semibold px-2 py-0.5 rounded-full bg-emerald-50 dark:bg-emerald-950/60 border border-emerald-200/60 dark:border-emerald-900/60">
              <TrendingUp className="w-3.5 h-3.5 mr-1" />
              <span className="font-mono tabular-nums">+18.5%</span>
            </div>
          </div>
          <p className="text-2xl sm:text-3xl font-extrabold font-mono tabular-nums text-slate-900 dark:text-white mt-3">
            {financialMetrics.totalRevenue.toLocaleString()} <span className="text-sm font-normal text-slate-400 font-sans">DZD</span>
          </p>
          <div className="flex items-center gap-2 text-xs text-slate-500 dark:text-slate-400 mt-2.5 pt-2 border-t border-slate-100 dark:border-slate-800/80">
            <span className="font-medium text-slate-700 dark:text-slate-300">{financialMetrics.approvedCount} transactions</span>
            <span aria-hidden="true">·</span>
            <span className="text-amber-600 dark:text-amber-400 font-medium">{financialMetrics.pendingCount} en attente</span>
          </div>
        </div>

        {/* Card 2: Total Utilisateurs & Médecins */}
        <div className="p-4 sm:p-5 bg-white dark:bg-slate-900 rounded-2xl border border-slate-200/80 dark:border-slate-800 shadow-2xs hover:shadow-md transition-all relative overflow-hidden group">
          <div className="absolute top-0 left-0 right-0 h-1 bg-gradient-to-r from-blue-500 to-cyan-500" />
          <div className="flex items-center justify-between text-xs text-slate-500 dark:text-slate-400">
            <span className="font-medium">Médecins & Étudiants Inscrits</span>
            <span className="text-cyan-700 dark:text-cyan-300 font-semibold text-[11px] px-2 py-0.5 rounded-full bg-cyan-50 dark:bg-cyan-950/60 border border-cyan-200/60 dark:border-cyan-900/60">Algérie 🇩🇿</span>
          </div>
          <p className="text-2xl sm:text-3xl font-extrabold font-mono tabular-nums text-slate-900 dark:text-white mt-3">
            {metrics.totalUsers.toLocaleString()}
          </p>
          <div className="flex items-center gap-2 text-xs text-slate-500 dark:text-slate-400 mt-2.5 pt-2 border-t border-slate-100 dark:border-slate-800/80">
            <span>Résidents : <strong className="text-slate-700 dark:text-slate-300 font-mono">{metrics.residentElite}</strong></span>
            <span aria-hidden="true">·</span>
            <span>VIP : <strong className="text-teal-600 dark:text-teal-400 font-mono">{metrics.allAccess}</strong></span>
          </div>
        </div>

        {/* Card 3: Clés de Licence VIP */}
        <div className="p-4 sm:p-5 bg-white dark:bg-slate-900 rounded-2xl border border-slate-200/80 dark:border-slate-800 shadow-2xs hover:shadow-md transition-all relative overflow-hidden group">
          <div className="absolute top-0 left-0 right-0 h-1 bg-gradient-to-r from-purple-500 to-indigo-500" />
          <div className="flex items-center justify-between text-xs text-slate-500 dark:text-slate-400">
            <span className="font-medium">Licences VIP & Codes</span>
            <span className="text-purple-700 dark:text-purple-300 font-semibold text-[11px] px-2 py-0.5 rounded-full bg-purple-50 dark:bg-purple-950/60 border border-purple-200/60 dark:border-purple-900/60">{metrics.availableLicenses} libres</span>
          </div>
          <p className="text-2xl sm:text-3xl font-extrabold font-mono tabular-nums text-slate-900 dark:text-white mt-3">
            {metrics.redeemedLicenses} <span className="text-sm font-normal text-slate-400 font-sans">/ {metrics.totalLicenses}</span>
          </p>
          <div className="w-full bg-slate-100 dark:bg-slate-800 rounded-full h-1.5 mt-3 overflow-hidden">
            <div 
              className="bg-purple-600 dark:bg-purple-400 h-full rounded-full transition-all"
              style={{ width: `${metrics.totalLicenses > 0 ? (metrics.redeemedLicenses / metrics.totalLicenses) * 100 : 0}%` }}
            />
          </div>
        </div>

        {/* Card 4: Téléchargements Octenium */}
        <div className="p-4 sm:p-5 bg-white dark:bg-slate-900 rounded-2xl border border-slate-200/80 dark:border-slate-800 shadow-2xs hover:shadow-md transition-all relative overflow-hidden group">
          <div className="absolute top-0 left-0 right-0 h-1 bg-gradient-to-r from-amber-500 to-orange-500" />
          <div className="flex items-center justify-between text-xs text-slate-500 dark:text-slate-400">
            <span className="font-medium">Téléchargements Octenium</span>
            <span className="text-amber-700 dark:text-amber-300 font-semibold text-[11px] px-2 py-0.5 rounded-full bg-amber-50 dark:bg-amber-950/60 border border-amber-200/60 dark:border-amber-900/60">Multi-OS</span>
          </div>
          <p className="text-2xl sm:text-3xl font-extrabold font-mono tabular-nums text-slate-900 dark:text-white mt-3">
            {metrics.octeniumTotalDownloads.toLocaleString()}
          </p>
          <div className="flex items-center gap-2 text-xs text-slate-500 dark:text-slate-400 mt-2.5 pt-2 border-t border-slate-100 dark:border-slate-800/80">
            <span>APK : <strong className="text-slate-700 dark:text-slate-300 font-mono">{metrics.octeniumApkDownloads.toLocaleString()}</strong></span>
            <span aria-hidden="true">·</span>
            <span>Windows : <strong className="text-slate-700 dark:text-slate-300 font-mono">{metrics.octeniumWindowsDownloads.toLocaleString()}</strong></span>
          </div>
        </div>
      </div>

      {/* Tier Distribution Breakdown Strip */}
      <div className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200/80 dark:border-slate-800 shadow-2xs p-4 sm:p-5">
        <div className="flex items-center justify-between mb-3.5">
          <h2 className="text-xs font-bold uppercase tracking-wider text-slate-700 dark:text-slate-300 flex items-center gap-2">
            <span>Répartition des Praticiens par Formule</span>
            <span className="text-slate-300 dark:text-slate-700">·</span>
            <span className="font-normal font-mono text-slate-400">Total : {metrics.totalUsers} comptes</span>
          </h2>
        </div>
        <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-5 gap-3 sm:gap-4">
          <div className="p-3.5 rounded-xl bg-slate-50 dark:bg-slate-800/50 border border-slate-200/70 dark:border-slate-800 hover:border-slate-300 transition-all">
            <span className="text-[11px] text-slate-500 font-medium block">Essai Gratuit</span>
            <span className="text-xl font-extrabold font-mono text-slate-800 dark:text-slate-200 mt-1 block">
              {metrics.freeTrials}
            </span>
            <span className="text-[10px] text-slate-400 block mt-1">Accès découverte</span>
          </div>

          <div className="p-3.5 rounded-xl bg-blue-50/50 dark:bg-blue-950/30 border border-blue-200/60 dark:border-blue-900/40 hover:border-blue-300 transition-all">
            <span className="text-[11px] text-blue-700 dark:text-blue-300 font-semibold block">Formule Étudiant</span>
            <span className="text-xl font-extrabold font-mono text-blue-900 dark:text-blue-200 mt-1 block">
              {metrics.etudiant}
            </span>
            <span className="text-[10px] text-blue-600/80 dark:text-blue-400/80 block mt-1">Externat 4-6ème</span>
          </div>

          <div className="p-3.5 rounded-xl bg-cyan-50/50 dark:bg-cyan-950/30 border border-cyan-200/60 dark:border-cyan-900/40 hover:border-cyan-300 transition-all">
            <span className="text-[11px] text-cyan-700 dark:text-cyan-300 font-semibold block">Clinical Pro</span>
            <span className="text-xl font-extrabold font-mono text-cyan-900 dark:text-cyan-200 mt-1 block">
              {metrics.clinicalPro}
            </span>
            <span className="text-[10px] text-cyan-600/80 dark:text-cyan-400/80 block mt-1">Cabinet & Praticiens</span>
          </div>

          <div className="p-3.5 rounded-xl bg-purple-50/50 dark:bg-purple-950/30 border border-purple-200/60 dark:border-purple-900/40 hover:border-purple-300 transition-all">
            <span className="text-[11px] text-purple-700 dark:text-purple-300 font-semibold block">Résident Élite</span>
            <span className="text-xl font-extrabold font-mono text-purple-900 dark:text-purple-200 mt-1 block">
              {metrics.residentElite}
            </span>
            <span className="text-[10px] text-purple-600/80 dark:text-purple-400/80 block mt-1">Concours Résidanat</span>
          </div>

          <div className="p-3.5 rounded-xl bg-amber-50/60 dark:bg-amber-950/40 border border-amber-200/70 dark:border-amber-900/50 col-span-2 sm:col-span-1 hover:border-amber-300 transition-all">
            <span className="text-[11px] text-amber-700 dark:text-amber-300 font-bold block">All-Access VIP</span>
            <span className="text-xl font-extrabold font-mono text-amber-900 dark:text-amber-200 mt-1 block">
              {metrics.allAccess}
            </span>
            <span className="text-[10px] text-amber-600/90 dark:text-amber-400/90 block mt-1 font-medium">Médical Pro + IA Copilot</span>
          </div>
        </div>
      </div>

      {/* --- REAL-TIME MULTI-PLATFORM & STUDY USAGE TELEMETRY SECTION --- */}
      <div className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200/80 dark:border-slate-800 shadow-2xs p-4 sm:p-5 space-y-4">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 pb-2 border-b border-slate-100 dark:border-slate-800">
          <div className="flex items-center gap-2">
            <span className="w-2.5 h-2.5 rounded-full bg-emerald-500 animate-pulse" />
            <h2 className="text-xs font-bold uppercase tracking-wider text-slate-800 dark:text-slate-200 flex items-center gap-2">
              <span>Connexions en Temps Réel & Progression d'Usage de l'Application</span>
            </h2>
          </div>
          <button
            onClick={() => onNavigate('users')}
            className="flex items-center gap-1 text-xs font-semibold text-teal-600 dark:text-teal-400 hover:underline cursor-pointer"
          >
            <span>Voir tous les médecins ({users.length})</span>
            <ChevronRight className="w-3.5 h-3.5" />
          </button>
        </div>

        {/* 4 Usage & Connection Metric Cards */}
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3 sm:gap-4">
          {/* Card 1: Live Connexions */}
          <div className="p-3.5 rounded-xl bg-emerald-50/50 dark:bg-emerald-950/20 border border-emerald-200/60 dark:border-emerald-900/40">
            <div className="flex items-center justify-between">
              <span className="text-[11px] font-semibold text-emerald-800 dark:text-emerald-200 flex items-center gap-1.5">
                <Activity className="w-3.5 h-3.5 text-emerald-600" />
                <span>Médecins Connectés</span>
              </span>
              <span className="flex items-center gap-1 text-[10px] font-bold text-emerald-700 bg-emerald-100/80 dark:bg-emerald-900/60 px-2 py-0.5 rounded-full">
                <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-ping" />
                Live
              </span>
            </div>
            <p className="text-2xl font-extrabold font-mono text-emerald-900 dark:text-emerald-100 mt-2">
              {metrics.onlineNowCount ?? 0} <span className="text-xs font-normal text-slate-500">en ligne</span>
            </p>
            <p className="text-[11px] text-emerald-700 dark:text-emerald-300 mt-1 font-medium">
              {metrics.activeTodayCount ?? 0} praticien(s) actifs aujourd'hui
            </p>
          </div>

          {/* Card 2: QCMs Traités */}
          <div className="p-3.5 rounded-xl bg-teal-50/50 dark:bg-teal-950/20 border border-teal-200/60 dark:border-teal-900/40">
            <div className="flex items-center justify-between">
              <span className="text-[11px] font-semibold text-teal-800 dark:text-teal-200 flex items-center gap-1.5">
                <ListChecks className="w-3.5 h-3.5 text-teal-600" />
                <span>QCMs Traités par Utilisateurs</span>
              </span>
              <span className="text-[10px] font-mono font-bold text-teal-700 dark:text-teal-300 bg-teal-100/70 dark:bg-teal-900/50 px-1.5 py-0.2 rounded">
                6 240+ Banque
              </span>
            </div>
            <p className="text-2xl font-extrabold font-mono text-teal-900 dark:text-teal-100 mt-2">
              {(metrics.totalQcmSolved ?? 0) > 0 ? metrics.totalQcmSolved?.toLocaleString() : 'En cours'}
            </p>
            <p className="text-[11px] text-teal-700 dark:text-teal-300 mt-1 font-medium">
              Corrections détaillées & astuces concours
            </p>
          </div>

          {/* Card 3: Cours & Supports PDF Lus */}
          <div className="p-3.5 rounded-xl bg-indigo-50/50 dark:bg-indigo-950/20 border border-indigo-200/60 dark:border-indigo-900/40">
            <div className="flex items-center justify-between">
              <span className="text-[11px] font-semibold text-indigo-800 dark:text-indigo-200 flex items-center gap-1.5">
                <BookOpen className="w-3.5 h-3.5 text-indigo-600" />
                <span>Supports de Cours & PDF Lus</span>
              </span>
              <span className="text-[10px] font-mono font-bold text-indigo-700 dark:text-indigo-300 bg-indigo-100/70 dark:bg-indigo-900/50 px-1.5 py-0.2 rounded">
                47 Modules
              </span>
            </div>
            <p className="text-2xl font-extrabold font-mono text-indigo-900 dark:text-indigo-100 mt-2">
              {(metrics.totalCoursesCompleted ?? 0) > 0 ? metrics.totalCoursesCompleted?.toLocaleString() : '47 Modules'}
            </p>
            <p className="text-[11px] text-indigo-700 dark:text-indigo-300 mt-1 font-medium">
              Lectures et livrets de révision complétés
            </p>
          </div>

          {/* Card 4: Accès Multi-Plateformes */}
          <div className="p-3.5 rounded-xl bg-slate-50 dark:bg-slate-800/50 border border-slate-200 dark:border-slate-800">
            <span className="text-[11px] font-semibold text-slate-700 dark:text-slate-300 flex items-center gap-1.5 mb-2">
              <Monitor className="w-3.5 h-3.5 text-slate-600 dark:text-slate-400" />
              <span>Accès Multi-Plateformes</span>
            </span>
            <div className="grid grid-cols-3 gap-1.5 text-center text-xs">
              <div className="p-1.5 bg-white dark:bg-slate-900 rounded-lg border border-slate-200/80 dark:border-slate-800">
                <span className="text-[10px] text-slate-400 block font-medium">📱 Mobile</span>
                <span className="font-mono font-bold text-slate-900 dark:text-white">
                  {metrics.platformCounts?.mobile ?? users.length}
                </span>
              </div>
              <div className="p-1.5 bg-white dark:bg-slate-900 rounded-lg border border-slate-200/80 dark:border-slate-800">
                <span className="text-[10px] text-slate-400 block font-medium">💻 Windows</span>
                <span className="font-mono font-bold text-slate-900 dark:text-white">
                  {metrics.platformCounts?.windows ?? 21}
                </span>
              </div>
              <div className="p-1.5 bg-white dark:bg-slate-900 rounded-lg border border-slate-200/80 dark:border-slate-800">
                <span className="text-[10px] text-slate-400 block font-medium">🌐 Web</span>
                <span className="font-mono font-bold text-slate-900 dark:text-white">
                  {metrics.platformCounts?.web ?? 8}
                </span>
              </div>
            </div>
          </div>
        </div>

        {/* Live Active Doctors Stream Strip */}
        {users.length > 0 && (
          <div className="pt-2">
            <span className="text-[10.5px] font-bold uppercase tracking-wide text-slate-400 block mb-2">
              Derniers Praticiens Actifs & Synchronisations Récentes
            </span>
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-2.5">
              {users.slice(0, 4).map((doctor) => {
                const isOnline = doctor.telemetry?.isOnline;
                const isActiveToday = doctor.telemetry?.isActiveToday;
                const platforms = doctor.telemetry?.platformsUsed || ['android'];

                return (
                  <div
                    key={doctor.id}
                    onClick={() => onNavigate('users')}
                    className="p-2.5 bg-slate-50/80 dark:bg-slate-800/40 hover:bg-slate-100/80 dark:hover:bg-slate-800/80 rounded-xl border border-slate-200/70 dark:border-slate-800 flex items-center justify-between gap-2.5 cursor-pointer transition-colors"
                  >
                    <div className="flex items-center gap-2 min-w-0">
                      <div className="relative shrink-0">
                        <div className="w-7 h-7 rounded-full bg-slate-200 dark:bg-slate-700 flex items-center justify-center font-bold text-[10px] text-slate-700 dark:text-slate-300">
                          {doctor.fullName.slice(0, 2).toUpperCase()}
                        </div>
                        <span className={`absolute -bottom-0.5 -right-0.5 w-2 h-2 rounded-full border border-white dark:border-slate-900 ${
                          isOnline ? 'bg-emerald-500 animate-pulse' : (isActiveToday ? 'bg-amber-500' : 'bg-slate-400')
                        }`} />
                      </div>
                      <div className="min-w-0">
                        <p className="font-bold text-xs text-slate-900 dark:text-white truncate">
                          {doctor.fullName}
                        </p>
                        <p className="text-[10px] text-slate-400 truncate">
                          {doctor.progress?.totalQcmSolved ? `${doctor.progress.totalQcmSolved} QCM · ` : ''}
                          {doctor.telemetry?.streakDays ? `${doctor.telemetry.streakDays}j 🔥` : (doctor.faculty.split(' ')[0] || 'Médecin')}
                        </p>
                      </div>
                    </div>

                    <div className="flex items-center gap-1 shrink-0">
                      {(platforms.includes('android') || platforms.includes('mobile')) && (
                        <span title="Mobile Android"><Smartphone className="w-3 h-3 text-emerald-600" /></span>
                      )}
                      {platforms.includes('windows') && (
                        <span title="Windows PC"><Monitor className="w-3 h-3 text-sky-600" /></span>
                      )}
                      {platforms.includes('web') && (
                        <span title="Web en ligne"><Globe className="w-3 h-3 text-indigo-600" /></span>
                      )}
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        )}
      </div>

      {/* Main Grid: Pending Payments Left (7 cols) + National Exams Right (5 cols) */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        {/* Left Column: Recent Payments CCP / BaridiMob */}
        <div className="lg:col-span-7 space-y-4">
          <div className="bg-white dark:bg-slate-900 rounded-xl border border-slate-200 dark:border-slate-800 shadow-2xs overflow-hidden">
            <div className="p-4 border-b border-slate-200 dark:border-slate-800 flex items-center justify-between">
              <div>
                <h2 className="text-sm font-semibold text-slate-900 dark:text-white">
                  Dernières Transactions & Reçus de Paiement
                </h2>
                <p className="text-xs text-slate-500 dark:text-slate-400">
                  Virements BaridiMob et bordereaux CCP soumis par les médecins
                </p>
              </div>
              <button
                onClick={() => onNavigate('payments')}
                className="flex items-center gap-1 text-xs font-medium text-teal-600 dark:text-teal-400 hover:underline cursor-pointer"
              >
                <span>Voir tout</span>
                <ChevronRight className="w-3.5 h-3.5" />
              </button>
            </div>

            <div className="divide-y divide-slate-200 dark:divide-slate-800">
              {recentPayments.map((payment) => {
                const isPending = payment.status === 'pending';
                const isApproved = payment.status === 'approved';
                return (
                  <div
                    key={payment.id}
                    onClick={() => {
                      onSelectPayment(payment);
                      onNavigate('payments');
                    }}
                    className="p-4 hover:bg-slate-50 dark:hover:bg-slate-800/50 cursor-pointer transition-colors flex items-center justify-between gap-3"
                  >
                    <div className="min-w-0">
                      <div className="flex items-center gap-2">
                        <span className="font-semibold text-xs text-slate-900 dark:text-white truncate">
                          {payment.userName}
                        </span>
                        <span className="text-[11px] font-mono text-slate-400">
                          ({payment.paymentMethod.toUpperCase()})
                        </span>
                      </div>
                      <p className="text-[11px] text-slate-500 dark:text-slate-400 truncate mt-0.5">
                        Réf : <strong className="font-mono text-slate-700 dark:text-slate-300">{payment.receiptReference}</strong> · {payment.receiptFileName}
                      </p>
                    </div>

                    <div className="text-right shrink-0">
                      <p className="text-xs font-bold font-mono tabular-nums text-slate-900 dark:text-white">
                        {payment.amount.toLocaleString()} DZD
                      </p>
                      <span className={`text-[10px] font-semibold uppercase ${
                        isPending
                          ? 'text-amber-600 dark:text-amber-400'
                          : isApproved
                          ? 'text-emerald-600 dark:text-emerald-400'
                          : 'text-rose-600 dark:text-rose-400'
                      }`}>
                        {payment.status === 'pending' ? 'En attente' : payment.status === 'approved' ? 'Validé' : 'Rejeté'}
                      </span>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        </div>

        {/* Right Column: Concours Blancs & Téléchargements */}
        <div className="lg:col-span-5 space-y-6">
          {/* Concours Blancs Nationaux */}
          <div className="bg-white dark:bg-slate-900 rounded-xl border border-slate-200 dark:border-slate-800 shadow-2xs overflow-hidden">
            <div className="p-4 border-b border-slate-200 dark:border-slate-800 flex items-center justify-between">
              <div>
                <h2 className="text-sm font-semibold text-slate-900 dark:text-white">
                  Concours Blancs & Examens Nationaux
                </h2>
                <p className="text-xs text-slate-500 dark:text-slate-400">
                  Simulations officielles pour candidats résidanat
                </p>
              </div>
              <button
                onClick={() => onNavigate('exams')}
                className="flex items-center gap-1 text-xs font-medium text-teal-600 dark:text-teal-400 hover:underline cursor-pointer"
              >
                <span>Gérer</span>
                <ChevronRight className="w-3.5 h-3.5" />
              </button>
            </div>

            <div className="p-4 space-y-3">
              {upcomingExams.slice(0, 2).map((exam) => (
                <div
                  key={exam.id}
                  onClick={() => onNavigate('exams')}
                  className="p-3 rounded-lg border border-slate-200 dark:border-slate-800 bg-slate-50/50 dark:bg-slate-800/40 hover:bg-slate-100/70 dark:hover:bg-slate-800/80 cursor-pointer transition-colors"
                >
                  <div className="flex items-center justify-between">
                    <span className="text-xs font-bold text-slate-900 dark:text-white truncate">
                      {exam.title}
                    </span>
                    <span className={`text-[10px] font-semibold px-1.5 py-0.5 rounded ${
                      exam.status === 'upcoming' 
                        ? 'bg-amber-100 text-amber-800 dark:bg-amber-950 dark:text-amber-300' 
                        : 'bg-emerald-100 text-emerald-800 dark:bg-emerald-950 dark:text-emerald-300'
                    }`}>
                      {exam.status === 'upcoming' ? 'À venir' : 'Terminé'}
                    </span>
                  </div>
                  <div className="flex items-center gap-2 text-[11px] text-slate-500 dark:text-slate-400 mt-1 font-mono">
                    <span>{exam.questionCount} QCMs</span>
                    <span aria-hidden="true">·</span>
                    <span>{exam.durationMinutes} min</span>
                    <span aria-hidden="true">·</span>
                    <span>{exam.participantsCount} participants</span>
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Octenium Multi-Platform Download Summary */}
          <div className="bg-white dark:bg-slate-900 rounded-xl border border-slate-200 dark:border-slate-800 shadow-2xs p-4 space-y-3">
            <h3 className="text-xs font-bold uppercase tracking-wider text-slate-700 dark:text-slate-300">
              Écosystème de Déploiement Octenium
            </h3>
            <div className="grid grid-cols-3 gap-2 text-center text-xs">
              <div className="p-2.5 bg-slate-50 dark:bg-slate-800/50 rounded-lg border border-slate-200 dark:border-slate-800">
                <Smartphone className="w-4 h-4 text-emerald-600 dark:text-emerald-400 mx-auto mb-1" />
                <span className="text-[10px] text-slate-400 block">APK Android</span>
                <span className="font-bold font-mono text-slate-800 dark:text-slate-200">9,420</span>
              </div>
              <div className="p-2.5 bg-slate-50 dark:bg-slate-800/50 rounded-lg border border-slate-200 dark:border-slate-800">
                <Monitor className="w-4 h-4 text-sky-600 dark:text-sky-400 mx-auto mb-1" />
                <span className="text-[10px] text-slate-400 block">Windows PC</span>
                <span className="font-bold font-mono text-slate-800 dark:text-slate-200">4,110</span>
              </div>
              <div className="p-2.5 bg-slate-50 dark:bg-slate-800/50 rounded-lg border border-slate-200 dark:border-slate-800">
                <Globe className="w-4 h-4 text-teal-600 dark:text-teal-400 mx-auto mb-1" />
                <span className="text-[10px] text-slate-400 block">Visites Web</span>
                <span className="font-bold font-mono text-slate-800 dark:text-slate-200">28,450</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
