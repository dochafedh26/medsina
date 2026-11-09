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
  Globe
} from 'lucide-react';
import { 
  AdminMetrics, 
  FinancialMetrics, 
  PaymentItem, 
  NationalExamModel, 
  NavigationTab 
} from '../../types/medsina';

interface OverviewViewProps {
  metrics: AdminMetrics;
  financialMetrics: FinancialMetrics;
  recentPayments: PaymentItem[];
  upcomingExams: NationalExamModel[];
  onNavigate: (tab: NavigationTab) => void;
  onSelectPayment: (payment: PaymentItem) => void;
}

export const OverviewView: React.FC<OverviewViewProps> = ({
  metrics,
  financialMetrics,
  recentPayments,
  upcomingExams,
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

        <div className="flex items-center gap-2">
          <button
            onClick={() => onNavigate('payments')}
            className="flex items-center gap-1.5 px-3 py-1.5 text-xs font-semibold text-white bg-teal-600 hover:bg-teal-700 dark:bg-teal-500 rounded-lg shadow-xs transition-colors cursor-pointer"
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
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {/* Card 1: Chiffre d'Affaires DZD */}
        <div className="p-4 bg-white dark:bg-slate-900 rounded-xl border border-slate-200 dark:border-slate-800 shadow-2xs">
          <div className="flex items-center justify-between text-xs text-slate-500 dark:text-slate-400">
            <span>Chiffre d'Affaires Validé</span>
            <div className="flex items-center text-emerald-600 dark:text-emerald-400 font-medium">
              <TrendingUp className="w-3.5 h-3.5 mr-0.5" />
              <span className="font-mono tabular-nums">+18.5%</span>
            </div>
          </div>
          <p className="text-2xl font-bold font-mono tabular-nums text-slate-900 dark:text-white mt-2">
            {financialMetrics.totalRevenue.toLocaleString()} <span className="text-sm font-normal text-slate-500">DZD</span>
          </p>
          <div className="flex items-center gap-2 text-xs text-slate-500 dark:text-slate-400 mt-2">
            <span>{financialMetrics.approvedCount} transactions</span>
            <span aria-hidden="true">·</span>
            <span className="text-amber-600 dark:text-amber-400 font-medium">{financialMetrics.pendingCount} en attente</span>
          </div>
        </div>

        {/* Card 2: Total Utilisateurs & Médecins */}
        <div className="p-4 bg-white dark:bg-slate-900 rounded-xl border border-slate-200 dark:border-slate-800 shadow-2xs">
          <div className="flex items-center justify-between text-xs text-slate-500 dark:text-slate-400">
            <span>Médecins & Étudiants Inscrits</span>
            <span className="text-teal-600 dark:text-teal-400 font-medium text-[11px]">Algérie</span>
          </div>
          <p className="text-2xl font-bold font-mono tabular-nums text-slate-900 dark:text-white mt-2">
            {metrics.totalUsers.toLocaleString()}
          </p>
          <div className="flex items-center gap-2 text-xs text-slate-500 dark:text-slate-400 mt-2">
            <span>Résidents : {metrics.residentElite}</span>
            <span aria-hidden="true">·</span>
            <span>VIP : {metrics.allAccess}</span>
          </div>
        </div>

        {/* Card 3: Clés de Licence VIP */}
        <div className="p-4 bg-white dark:bg-slate-900 rounded-xl border border-slate-200 dark:border-slate-800 shadow-2xs">
          <div className="flex items-center justify-between text-xs text-slate-500 dark:text-slate-400">
            <span>Licences VIP & Codes</span>
            <span className="text-teal-600 dark:text-teal-400 font-medium text-[11px]">{metrics.availableLicenses} libres</span>
          </div>
          <p className="text-2xl font-bold font-mono tabular-nums text-slate-900 dark:text-white mt-2">
            {metrics.redeemedLicenses} <span className="text-sm font-normal text-slate-500">/ {metrics.totalLicenses}</span>
          </p>
          <div className="w-full bg-slate-100 dark:bg-slate-800 rounded-full h-1.5 mt-3 overflow-hidden">
            <div 
              className="bg-teal-600 dark:bg-teal-400 h-full rounded-full transition-all"
              style={{ width: `${(metrics.redeemedLicenses / metrics.totalLicenses) * 100}%` }}
            />
          </div>
        </div>

        {/* Card 4: Téléchargements Octenium */}
        <div className="p-4 bg-white dark:bg-slate-900 rounded-xl border border-slate-200 dark:border-slate-800 shadow-2xs">
          <div className="flex items-center justify-between text-xs text-slate-500 dark:text-slate-400">
            <span>Téléchargements Octenium</span>
            <span className="text-slate-600 dark:text-slate-300 font-medium text-[11px]">Multi-OS</span>
          </div>
          <p className="text-2xl font-bold font-mono tabular-nums text-slate-900 dark:text-white mt-2">
            {metrics.octeniumTotalDownloads.toLocaleString()}
          </p>
          <div className="flex items-center gap-2 text-xs text-slate-500 dark:text-slate-400 mt-2">
            <span>APK : 9,420</span>
            <span aria-hidden="true">·</span>
            <span>Windows : 4,110</span>
          </div>
        </div>
      </div>

      {/* Tier Distribution Breakdown Strip */}
      <div className="bg-white dark:bg-slate-900 rounded-xl border border-slate-200 dark:border-slate-800 shadow-2xs p-4">
        <h2 className="text-xs font-bold uppercase tracking-wider text-slate-600 dark:text-slate-400 mb-3">
          Répartition des Comptes par Formule d'Abonnement
        </h2>
        <div className="grid grid-cols-2 sm:grid-cols-5 gap-3">
          <div className="p-3 rounded-lg bg-slate-50 dark:bg-slate-800/50 border border-slate-200 dark:border-slate-800">
            <span className="text-[11px] text-slate-500 block">Essai Gratuit</span>
            <span className="text-lg font-bold font-mono text-slate-800 dark:text-slate-200">
              {metrics.freeTrials}
            </span>
            <span className="text-[10px] text-slate-400 block mt-0.5">Accès limité</span>
          </div>

          <div className="p-3 rounded-lg bg-blue-50/60 dark:bg-blue-950/40 border border-blue-200 dark:border-blue-900/60">
            <span className="text-[11px] text-blue-700 dark:text-blue-300 font-medium block">Formule Étudiant</span>
            <span className="text-lg font-bold font-mono text-blue-900 dark:text-blue-200">
              {metrics.etudiant}
            </span>
            <span className="text-[10px] text-blue-600 dark:text-blue-400 block mt-0.5">Externat 4-6ème</span>
          </div>

          <div className="p-3 rounded-lg bg-sky-50/60 dark:bg-sky-950/40 border border-sky-200 dark:border-sky-900/60">
            <span className="text-[11px] text-sky-700 dark:text-sky-300 font-medium block">Clinical Pro</span>
            <span className="text-lg font-bold font-mono text-sky-900 dark:text-sky-200">
              {metrics.clinicalPro}
            </span>
            <span className="text-[10px] text-sky-600 dark:text-sky-400 block mt-0.5">Cabinet & Praticiens</span>
          </div>

          <div className="p-3 rounded-lg bg-purple-50/60 dark:bg-purple-950/40 border border-purple-200 dark:border-purple-900/60">
            <span className="text-[11px] text-purple-700 dark:text-purple-300 font-medium block">Résident Élite</span>
            <span className="text-lg font-bold font-mono text-purple-900 dark:text-purple-200">
              {metrics.residentElite}
            </span>
            <span className="text-[10px] text-purple-600 dark:text-purple-400 block mt-0.5">Concours Résidanat</span>
          </div>

          <div className="p-3 rounded-lg bg-amber-50/60 dark:bg-amber-950/40 border border-amber-200 dark:border-amber-900/60 col-span-2 sm:col-span-1">
            <span className="text-[11px] text-amber-700 dark:text-amber-300 font-medium block">All-Access VIP</span>
            <span className="text-lg font-bold font-mono text-amber-900 dark:text-amber-200">
              {metrics.allAccess}
            </span>
            <span className="text-[10px] text-amber-600 dark:text-amber-400 block mt-0.5">Complet + IA</span>
          </div>
        </div>
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
