import React, { useEffect, useMemo, useState } from 'react';
import {
  AlertTriangle,
  BadgeDollarSign,
  CalendarCheck,
  CheckCircle2,
  Clock,
  Coins,
  Loader2,
  RefreshCw,
  Settings2,
  TrendingUp,
  Users,
  Wallet,
  XCircle,
} from 'lucide-react';
import {
  TeacherLedgerRow,
  TeacherPayoutRequest,
  TeacherPayoutStatus,
  TeacherRevenuePeriod,
  TeacherRevenueSettings,
} from '../../types/medsina';
import {
  closeTeacherRevenuePeriod,
  fetchTeacherEarningsLedger,
  fetchTeacherPayoutRequests,
  fetchTeacherRevenuePeriods,
  fetchTeacherRevenueSettings,
  updateTeacherPayoutRequest,
} from '../../services/supabase';

interface TeacherRevenueViewProps {
  adminId?: string;
}

const DZD = (value: number): string =>
  `${Math.round(value).toLocaleString('fr-FR').replace(/\u202f/g, ' ')} DZD`;

const MONTH_LABEL = (value?: string): string => {
  if (!value) return '—';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value;
  return date.toLocaleDateString('fr-FR', { month: 'long', year: 'numeric' });
};

const PAYOUT_STATUS_META: Record<
  TeacherPayoutStatus,
  { label: string; badgeClass: string; icon: React.FC<{ className?: string }> }
> = {
  requested: {
    label: 'À traiter',
    badgeClass:
      'bg-amber-100 text-amber-800 dark:bg-amber-900/40 dark:text-amber-300 border-amber-200 dark:border-amber-800',
    icon: Clock,
  },
  approved: {
    label: 'Approuvé',
    badgeClass:
      'bg-sky-100 text-sky-800 dark:bg-sky-900/40 dark:text-sky-300 border-sky-200 dark:border-sky-800',
    icon: CheckCircle2,
  },
  paid: {
    label: 'Payé',
    badgeClass:
      'bg-emerald-100 text-emerald-800 dark:bg-emerald-900/40 dark:text-emerald-300 border-emerald-200 dark:border-emerald-800',
    icon: BadgeDollarSign,
  },
  rejected: {
    label: 'Refusé',
    badgeClass:
      'bg-rose-100 text-rose-800 dark:bg-rose-900/40 dark:text-rose-300 border-rose-200 dark:border-rose-800',
    icon: XCircle,
  },
  cancelled: {
    label: 'Annulé',
    badgeClass:
      'bg-slate-100 text-slate-600 dark:bg-slate-800 dark:text-slate-300 border-slate-200 dark:border-slate-700',
    icon: XCircle,
  },
};

const METHOD_LABEL: Record<string, string> = {
  ccp: 'CCP BaridiMob',
  baridimob: 'BaridiMob',
  virement: 'Virement bancaire',
};

const LEDGER_STATUS_LABEL: Record<string, string> = {
  accrued: 'Sous rétention',
  available: 'Disponible',
  clawed_back: 'Annulé',
};

export const TeacherRevenueView: React.FC<TeacherRevenueViewProps> = ({ adminId }) => {
  const [settings, setSettings] = useState<TeacherRevenueSettings | null>(null);
  const [periods, setPeriods] = useState<TeacherRevenuePeriod[]>([]);
  const [ledger, setLedger] = useState<TeacherLedgerRow[]>([]);
  const [payouts, setPayouts] = useState<TeacherPayoutRequest[]>([]);
  const [isLoading, setIsLoading] = useState<boolean>(true);
  const [isClosing, setIsClosing] = useState<boolean>(false);
  const [closingMonth, setClosingMonth] = useState<string>(() => {
    const d = new Date();
    d.setMonth(d.getMonth() - 1);
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
  });
  const [notice, setNotice] = useState<{ kind: 'ok' | 'error'; text: string } | null>(null);
  const [busyPayoutId, setBusyPayoutId] = useState<string | null>(null);
  const [noteDrafts, setNoteDrafts] = useState<Record<string, string>>({});
  const [statusFilter, setStatusFilter] = useState<TeacherPayoutStatus | 'all'>('requested');

  const loadAll = async () => {
    setIsLoading(true);
    const [nextSettings, nextPeriods, nextLedger, nextPayouts] = await Promise.all([
      fetchTeacherRevenueSettings(),
      fetchTeacherRevenuePeriods(),
      fetchTeacherEarningsLedger(),
      fetchTeacherPayoutRequests(),
    ]);
    setSettings(nextSettings);
    setPeriods(nextPeriods);
    setLedger(nextLedger);
    setPayouts(nextPayouts);
    setIsLoading(false);
  };

  useEffect(() => {
    void loadAll();
  }, []);

  const pendingPayouts = useMemo(
    () => payouts.filter((p) => p.status === 'requested' || p.status === 'approved'),
    [payouts]
  );
  const pendingAmount = useMemo(
    () => pendingPayouts.reduce((sum, p) => sum + p.amount, 0),
    [pendingPayouts]
  );
  const latestPeriod = periods[0];
  const heldBalance = useMemo(
    () => ledger.filter((l) => l.status === 'accrued').reduce((sum, l) => sum + l.authorEarnings, 0),
    [ledger]
  );

  const filteredPayouts = useMemo(
    () => (statusFilter === 'all' ? payouts : payouts.filter((p) => p.status === statusFilter)),
    [payouts, statusFilter]
  );

  const handleCloseMonth = async () => {
    const [year, month] = closingMonth.split('-').map(Number);
    if (!year || !month) {
      setNotice({ kind: 'error', text: 'Choisissez un mois valide à clôturer.' });
      return;
    }
    setIsClosing(true);
    setNotice(null);
    const result = await closeTeacherRevenuePeriod(`${closingMonth}-01`);
    setIsClosing(false);
    if (result.ok) {
      setNotice({ kind: 'ok', text: `Mois de ${MONTH_LABEL(`${closingMonth}-01`)} clôturé.` });
      await loadAll();
    } else {
      setNotice({ kind: 'error', text: `Clôture impossible : ${result.error || 'erreur inconnue'}` });
    }
  };

  const handlePayoutAction = async (
    payout: TeacherPayoutRequest,
    status: 'approved' | 'paid' | 'rejected'
  ) => {
    setBusyPayoutId(payout.id);
    const ok = await updateTeacherPayoutRequest(
      payout.id,
      status,
      noteDrafts[payout.id],
      adminId
    );
    setBusyPayoutId(null);
    if (ok) {
      setNotice({ kind: 'ok', text: `Demande de ${payout.teacherName || 'enseignant'} mise à jour.` });
      await loadAll();
    } else {
      setNotice({ kind: 'error', text: 'Impossible de mettre à jour la demande de retrait.' });
    }
  };

  return (
    <div className="space-y-5">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
        <div>
          <h1 className="text-xl sm:text-2xl font-bold text-slate-900 dark:text-white flex items-center gap-2">
            <Coins className="w-6 h-6 text-teal-600 dark:text-teal-400" />
            Revenus Espace Prof
          </h1>
          <p className="text-xs sm:text-sm text-slate-500 dark:text-slate-400 mt-1">
            Partage des revenus des publications et examens des enseignants vérifiés.
          </p>
        </div>
        <button
          type="button"
          onClick={() => void loadAll()}
          disabled={isLoading}
          className="inline-flex items-center gap-2 px-3 py-2 rounded-xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 text-xs font-semibold text-slate-700 dark:text-slate-200 hover:bg-slate-50 dark:hover:bg-slate-800 transition-colors disabled:opacity-50 cursor-pointer"
        >
          <RefreshCw className={`w-4 h-4 ${isLoading ? 'animate-spin' : ''}`} />
          Actualiser
        </button>
      </div>

      {notice && (
        <div
          className={`flex items-start gap-2 rounded-xl border px-3 py-2.5 text-xs font-medium ${
            notice.kind === 'ok'
              ? 'bg-emerald-50 border-emerald-200 text-emerald-800 dark:bg-emerald-950/40 dark:border-emerald-800 dark:text-emerald-300'
              : 'bg-rose-50 border-rose-200 text-rose-800 dark:bg-rose-950/40 dark:border-rose-800 dark:text-rose-300'
          }`}
        >
          {notice.kind === 'ok' ? (
            <CheckCircle2 className="w-4 h-4 shrink-0" />
          ) : (
            <AlertTriangle className="w-4 h-4 shrink-0" />
          )}
          <span>{notice.text}</span>
        </div>
      )}

      {/* KPI cards */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-3">
        <MetricCard
          label="Dernier mois clôturé"
          value={latestPeriod ? MONTH_LABEL(latestPeriod.periodMonth) : 'Aucun'}
          hint={latestPeriod ? `Net ${DZD(latestPeriod.netRevenue)}` : 'Clôturez un mois pour démarrer'}
          icon={CalendarCheck}
          tone="teal"
        />
        <MetricCard
          label="Pool auteurs"
          value={latestPeriod ? DZD(latestPeriod.authorPool) : '—'}
          hint={settings ? `${settings.authorSharePct} % du net` : undefined}
          icon={Users}
          tone="sky"
        />
        <MetricCard
          label="Part plateforme"
          value={latestPeriod ? DZD(latestPeriod.platformShare) : '—'}
          hint={settings ? `${100 - settings.authorSharePct} % du net` : undefined}
          icon={TrendingUp}
          tone="indigo"
        />
        <MetricCard
          label="Retraits en attente"
          value={DZD(pendingAmount)}
          hint={`${pendingPayouts.length} demande(s)`}
          icon={Wallet}
          tone="amber"
        />
      </div>

      {/* Settings + close month */}
      <div className="grid grid-cols-1 xl:grid-cols-3 gap-4">
        <div className="xl:col-span-2 rounded-2xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 p-4">
          <div className="flex items-center gap-2 mb-3">
            <Settings2 className="w-4 h-4 text-slate-400" />
            <h2 className="text-sm font-bold text-slate-900 dark:text-white">Règles de partage</h2>
            <span className="ml-auto text-[10px] font-mono text-slate-400">
              {settings?.isEnabled === false ? 'Désactivé' : 'Actif'}
            </span>
          </div>
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 text-xs">
            <SettingCell label="Part auteurs" value={settings ? `${settings.authorSharePct} %` : '—'} />
            <SettingCell label="Lecteurs min." value={settings ? `${settings.minUniqueReaders}` : '—'} hint="par contenu / mois" />
            <SettingCell label="Retrait min." value={settings ? DZD(settings.minPayoutAmount) : '—'} />
            <SettingCell label="Rétention" value={settings ? `${settings.holdbackDays} j` : '—'} />
            <SettingCell
              label="Plafond / auteur"
              value={settings ? `${settings.maxAuthorPoolPct} %` : '—'}
              hint={settings ? `dès ${settings.minAuthorsForCap} auteurs` : undefined}
            />
            <SettingCell label="Frais store" value={settings ? `${settings.storeFeePct} %` : '—'} />
            <SettingCell label="Solde sous rétention" value={DZD(heldBalance)} />
            <SettingCell label="Mois clôturés" value={`${periods.length}`} />
          </div>
        </div>

        <div className="rounded-2xl bg-teal-50 dark:bg-teal-950/40 border border-teal-200 dark:border-teal-900 p-4">
          <h2 className="text-sm font-bold text-teal-900 dark:text-teal-100">Clôturer un mois</h2>
          <p className="text-[11px] text-teal-800/80 dark:text-teal-300/80 mt-1 leading-relaxed">
            Calcule le pool auteurs à partir des paiements approuvés, applique la règle des lecteurs
            uniques et génère le grand livre des gains.
          </p>
          <div className="mt-3 space-y-2">
            <input
              type="month"
              value={closingMonth}
              onChange={(e) => setClosingMonth(e.target.value)}
              className="w-full rounded-lg border border-teal-300/60 dark:border-teal-800 bg-white dark:bg-slate-900 px-2.5 py-1.5 text-xs text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-teal-500"
            />
            <button
              type="button"
              onClick={() => void handleCloseMonth()}
              disabled={isClosing}
              className="w-full inline-flex items-center justify-center gap-2 px-3 py-2 rounded-lg bg-teal-600 hover:bg-teal-700 text-white text-xs font-bold transition-colors disabled:opacity-60 cursor-pointer"
            >
              {isClosing ? <Loader2 className="w-4 h-4 animate-spin" /> : <CalendarCheck className="w-4 h-4" />}
              Clôturer le mois
            </button>
          </div>
        </div>
      </div>

      {/* Payout requests */}
      <section className="rounded-2xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 overflow-hidden">
        <div className="flex flex-wrap items-center gap-2 px-4 py-3 border-b border-slate-100 dark:border-slate-800">
          <h2 className="text-sm font-bold text-slate-900 dark:text-white">Demandes de retrait</h2>
          <div className="ml-auto flex items-center gap-1">
            {(['requested', 'approved', 'paid', 'rejected', 'all'] as const).map((status) => (
              <button
                key={status}
                type="button"
                onClick={() => setStatusFilter(status)}
                className={`px-2 py-1 rounded-md text-[11px] font-semibold transition-colors cursor-pointer ${
                  statusFilter === status
                    ? 'bg-teal-600 text-white'
                    : 'bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300 hover:bg-slate-200 dark:hover:bg-slate-700'
                }`}
              >
                {status === 'all' ? 'Toutes' : PAYOUT_STATUS_META[status].label}
              </button>
            ))}
          </div>
        </div>

        {isLoading ? (
          <div className="flex items-center justify-center gap-2 py-10 text-xs text-slate-500 dark:text-slate-400">
            <Loader2 className="w-4 h-4 animate-spin" /> Chargement…
          </div>
        ) : filteredPayouts.length === 0 ? (
          <div className="py-10 text-center text-xs text-slate-500 dark:text-slate-400">
            Aucune demande de retrait dans ce filtre.
          </div>
        ) : (
          <div className="divide-y divide-slate-100 dark:divide-slate-800">
            {filteredPayouts.map((payout) => {
              const meta = PAYOUT_STATUS_META[payout.status];
              const StatusIcon = meta.icon;
              const isBusy = busyPayoutId === payout.id;
              return (
                <div key={payout.id} className="px-4 py-3 space-y-2">
                  <div className="flex flex-wrap items-center gap-2">
                    <span className="text-sm font-semibold text-slate-900 dark:text-white">
                      {payout.teacherName}
                    </span>
                    <span
                      className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full border text-[10px] font-bold ${meta.badgeClass}`}
                    >
                      <StatusIcon className="w-3 h-3" />
                      {meta.label}
                    </span>
                    <span className="ml-auto text-sm font-bold font-mono text-slate-900 dark:text-white">
                      {DZD(payout.amount)}
                    </span>
                  </div>

                  <div className="flex flex-wrap gap-x-4 gap-y-1 text-[11px] text-slate-500 dark:text-slate-400">
                    <span>{METHOD_LABEL[payout.method] || payout.method}</span>
                    <span>Titulaire : {payout.accountHolder}</span>
                    {payout.accountDetails && <span className="font-mono">{payout.accountDetails}</span>}
                    <span>
                      Demandé le {new Date(payout.requestedAt).toLocaleDateString('fr-FR')}
                    </span>
                    {payout.paidAt && (
                      <span>Payé le {new Date(payout.paidAt).toLocaleDateString('fr-FR')}</span>
                    )}
                  </div>

                  {payout.adminNote && (
                    <p className="text-[11px] italic text-slate-500 dark:text-slate-400">
                      Note : {payout.adminNote}
                    </p>
                  )}

                  {(payout.status === 'requested' || payout.status === 'approved') && (
                    <div className="flex flex-wrap items-center gap-2 pt-1">
                      <input
                        type="text"
                        placeholder="Note interne / référence de paiement (optionnel)"
                        value={noteDrafts[payout.id] ?? ''}
                        onChange={(e) =>
                          setNoteDrafts((prev) => ({ ...prev, [payout.id]: e.target.value }))
                        }
                        className="flex-1 min-w-[200px] rounded-lg border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-950 px-2.5 py-1.5 text-[11px] text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-teal-500"
                      />
                      {payout.status === 'requested' && (
                        <button
                          type="button"
                          disabled={isBusy}
                          onClick={() => void handlePayoutAction(payout, 'approved')}
                          className="px-2.5 py-1.5 rounded-lg bg-sky-600 hover:bg-sky-700 text-white text-[11px] font-bold disabled:opacity-50 cursor-pointer"
                        >
                          Approuver
                        </button>
                      )}
                      <button
                        type="button"
                        disabled={isBusy}
                        onClick={() => void handlePayoutAction(payout, 'paid')}
                        className="px-2.5 py-1.5 rounded-lg bg-emerald-600 hover:bg-emerald-700 text-white text-[11px] font-bold disabled:opacity-50 cursor-pointer"
                      >
                        Marquer payé
                      </button>
                      <button
                        type="button"
                        disabled={isBusy}
                        onClick={() => void handlePayoutAction(payout, 'rejected')}
                        className="px-2.5 py-1.5 rounded-lg bg-rose-600 hover:bg-rose-700 text-white text-[11px] font-bold disabled:opacity-50 cursor-pointer"
                      >
                        Refuser
                      </button>
                      {isBusy && <Loader2 className="w-4 h-4 animate-spin text-slate-400" />}
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        )}
      </section>

      {/* Periods + ledger */}
      <div className="grid grid-cols-1 xl:grid-cols-2 gap-4">
        <section className="rounded-2xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 overflow-hidden">
          <div className="px-4 py-3 border-b border-slate-100 dark:border-slate-800">
            <h2 className="text-sm font-bold text-slate-900 dark:text-white">Mois clôturés</h2>
          </div>
          {periods.length === 0 ? (
            <div className="py-10 text-center text-xs text-slate-500 dark:text-slate-400">
              Aucun mois clôturé pour le moment.
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-[11px]">
                <thead className="bg-slate-50 dark:bg-slate-950/60 text-slate-500 dark:text-slate-400">
                  <tr>
                    <th className="text-left font-semibold px-3 py-2">Mois</th>
                    <th className="text-right font-semibold px-3 py-2">Net</th>
                    <th className="text-right font-semibold px-3 py-2">Pool</th>
                    <th className="text-right font-semibold px-3 py-2">Plateforme</th>
                    <th className="text-right font-semibold px-3 py-2">Auteurs</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100 dark:divide-slate-800">
                  {periods.map((period) => (
                    <tr key={period.id} className="text-slate-700 dark:text-slate-300">
                      <td className="px-3 py-2 font-semibold text-slate-900 dark:text-white">
                        {MONTH_LABEL(period.periodMonth)}
                      </td>
                      <td className="px-3 py-2 text-right font-mono">{DZD(period.netRevenue)}</td>
                      <td className="px-3 py-2 text-right font-mono text-teal-700 dark:text-teal-300">
                        {DZD(period.authorPool)}
                      </td>
                      <td className="px-3 py-2 text-right font-mono">{DZD(period.platformShare)}</td>
                      <td className="px-3 py-2 text-right font-mono">
                        {String(period.details?.author_count ?? '—')}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </section>

        <section className="rounded-2xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 overflow-hidden">
          <div className="px-4 py-3 border-b border-slate-100 dark:border-slate-800">
            <h2 className="text-sm font-bold text-slate-900 dark:text-white">Grand livre des gains</h2>
          </div>
          {ledger.length === 0 ? (
            <div className="py-10 text-center text-xs text-slate-500 dark:text-slate-400">
              Aucun gain enregistré.
            </div>
          ) : (
            <div className="overflow-x-auto max-h-[380px]">
              <table className="w-full text-[11px]">
                <thead className="bg-slate-50 dark:bg-slate-950/60 text-slate-500 dark:text-slate-400 sticky top-0">
                  <tr>
                    <th className="text-left font-semibold px-3 py-2">Enseignant</th>
                    <th className="text-left font-semibold px-3 py-2">Mois</th>
                    <th className="text-right font-semibold px-3 py-2">Unités</th>
                    <th className="text-right font-semibold px-3 py-2">Gain</th>
                    <th className="text-left font-semibold px-3 py-2">Statut</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100 dark:divide-slate-800">
                  {ledger.map((row) => (
                    <tr key={row.id} className="text-slate-700 dark:text-slate-300">
                      <td className="px-3 py-2 font-medium text-slate-900 dark:text-white">
                        {row.authorName}
                      </td>
                      <td className="px-3 py-2">{MONTH_LABEL(row.periodMonth)}</td>
                      <td className="px-3 py-2 text-right font-mono">{row.units}</td>
                      <td className="px-3 py-2 text-right font-mono text-teal-700 dark:text-teal-300">
                        {DZD(row.authorEarnings)}
                      </td>
                      <td className="px-3 py-2">
                        <span
                          className={`inline-flex px-1.5 py-0.5 rounded border text-[10px] font-semibold ${
                            row.status === 'available'
                              ? 'bg-emerald-50 border-emerald-200 text-emerald-700 dark:bg-emerald-950/40 dark:border-emerald-800 dark:text-emerald-300'
                              : row.status === 'clawed_back'
                                ? 'bg-rose-50 border-rose-200 text-rose-700 dark:bg-rose-950/40 dark:border-rose-800 dark:text-rose-300'
                                : 'bg-slate-100 border-slate-200 text-slate-600 dark:bg-slate-800 dark:border-slate-700 dark:text-slate-300'
                          }`}
                        >
                          {LEDGER_STATUS_LABEL[row.status] || row.status}
                        </span>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </section>
      </div>
    </div>
  );
};

interface MetricCardProps {
  label: string;
  value: string;
  hint?: string;
  icon: React.FC<{ className?: string }>;
  tone: 'teal' | 'sky' | 'indigo' | 'amber';
}

const TONE_CLASSES: Record<MetricCardProps['tone'], string> = {
  teal: 'bg-teal-50 text-teal-700 dark:bg-teal-950/40 dark:text-teal-300',
  sky: 'bg-sky-50 text-sky-700 dark:bg-sky-950/40 dark:text-sky-300',
  indigo: 'bg-indigo-50 text-indigo-700 dark:bg-indigo-950/40 dark:text-indigo-300',
  amber: 'bg-amber-50 text-amber-700 dark:bg-amber-950/40 dark:text-amber-300',
};

const MetricCard: React.FC<MetricCardProps> = ({ label, value, hint, icon: Icon, tone }) => (
  <div className="rounded-2xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 p-3.5">
    <div className="flex items-center justify-between">
      <span className="text-[10px] uppercase tracking-wider font-bold text-slate-400 dark:text-slate-500">
        {label}
      </span>
      <span className={`p-1.5 rounded-lg ${TONE_CLASSES[tone]}`}>
        <Icon className="w-3.5 h-3.5" />
      </span>
    </div>
    <p className="mt-1.5 text-base font-bold text-slate-900 dark:text-white leading-tight">{value}</p>
    {hint && <p className="text-[10px] text-slate-400 dark:text-slate-500 mt-0.5">{hint}</p>}
  </div>
);

const SettingCell: React.FC<{ label: string; value: string; hint?: string }> = ({
  label,
  value,
  hint,
}) => (
  <div className="rounded-lg bg-slate-50 dark:bg-slate-950/60 border border-slate-100 dark:border-slate-800 px-2.5 py-2">
    <p className="text-[10px] text-slate-400 dark:text-slate-500">{label}</p>
    <p className="text-xs font-bold text-slate-900 dark:text-white mt-0.5">{value}</p>
    {hint && <p className="text-[9px] text-slate-400 dark:text-slate-600">{hint}</p>}
  </div>
);
