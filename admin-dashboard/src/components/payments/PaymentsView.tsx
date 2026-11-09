import React, { useState } from 'react';
import { 
  CreditCard, 
  Search, 
  CheckCircle2, 
  XCircle, 
  Clock, 
  Archive, 
  FileText, 
  ExternalLink, 
  Check, 
  X, 
  Download, 
  AlertCircle,
  FileCheck,
  ShieldCheck,
  Building2,
  Plus,
  Eye,
  Calendar,
  User,
  ArrowRight
} from 'lucide-react';
import { PaymentItem, FinancialMetrics, AdminUserItem, SubscriptionTier } from '../../types/medsina';

interface PaymentsViewProps {
  payments: PaymentItem[];
  financialMetrics: FinancialMetrics;
  users?: AdminUserItem[];
  onApprovePayment: (paymentId: string, bonusCredits: number, adminNotes?: string) => void;
  onRejectPayment: (paymentId: string, reason: string) => void;
  onArchivePayment: (paymentId: string) => void;
  onCreateManualPayment?: (newPayment: PaymentItem) => void;
}

export const PaymentsView: React.FC<PaymentsViewProps> = ({
  payments,
  financialMetrics,
  users = [],
  onApprovePayment,
  onRejectPayment,
  onArchivePayment,
  onCreateManualPayment
}) => {
  const [selectedStatus, setSelectedStatus] = useState<string>('all');
  const [searchQuery, setSearchQuery] = useState<string>('');
  const [inspectingPayment, setInspectingPayment] = useState<PaymentItem | null>(payments[0] || null);
  const [rejectReason, setRejectReason] = useState<string>('');
  const [showRejectModal, setShowRejectModal] = useState<boolean>(false);
  const [showMobileInspector, setShowMobileInspector] = useState<boolean>(false);
  const [showManualModal, setShowManualModal] = useState<boolean>(false);
  const [bonusCreditsInput, setBonusCreditsInput] = useState<number>(0);
  const [approvalNotes, setApprovalNotes] = useState<string>('Validé par Dr. Hafedh. Attestation CCP vérifiée.');

  // Manual payment state
  const [manualUserEmail, setManualUserEmail] = useState('');
  const [manualUserName, setManualUserName] = useState('');
  const [manualTier, setManualTier] = useState<SubscriptionTier>('resident_elite');
  const [manualDurationDays, setManualDurationDays] = useState<number>(365);
  const [manualAmount, setManualAmount] = useState<number>(12000);
  const [manualMethod, setManualMethod] = useState<'baridimob' | 'ccp' | 'cib' | 'cash'>('cash');
  const [manualRef, setManualRef] = useState(`MANUAL-${Math.floor(100000 + Math.random() * 900000)}`);
  const [manualNotes, setManualNotes] = useState('Paiement régularisé en direct.');
  const [manualAutoApprove, setManualAutoApprove] = useState(true);

  const filteredPayments = payments.filter((p) => {
    const matchesStatus = selectedStatus === 'all' || p.status === selectedStatus;
    const matchesQuery = 
      p.userName.toLowerCase().includes(searchQuery.toLowerCase()) ||
      p.userEmail.toLowerCase().includes(searchQuery.toLowerCase()) ||
      (p.receiptReference && p.receiptReference.toLowerCase().includes(searchQuery.toLowerCase())) ||
      (p.receiptFileName && p.receiptFileName.toLowerCase().includes(searchQuery.toLowerCase()));

    return matchesStatus && matchesQuery;
  });

  const handleApprove = (payment: PaymentItem) => {
    onApprovePayment(payment.id, bonusCreditsInput, approvalNotes);
    if (inspectingPayment?.id === payment.id) {
      setInspectingPayment({ ...payment, status: 'approved', bonusCredits: bonusCreditsInput });
    }
  };

  const handleConfirmReject = () => {
    if (!inspectingPayment) return;
    onRejectPayment(inspectingPayment.id, rejectReason || 'Bordereau ou reçu invalide');
    setShowRejectModal(false);
    setInspectingPayment({ ...inspectingPayment, status: 'rejected', adminNotes: rejectReason });
  };

  const handleSelectPaymentMobile = (p: PaymentItem) => {
    setInspectingPayment(p);
    setShowMobileInspector(true);
  };

  const handleSelectUserForManual = (userId: string) => {
    const found = users.find(u => u.id === userId);
    if (found) {
      setManualUserEmail(found.email);
      setManualUserName(found.fullName);
    }
  };

  const handleConfirmManualPayment = (e: React.FormEvent) => {
    e.preventDefault();
    if (!manualUserEmail || !manualUserName) return;

    const matchedUser = users.find(u => u.email.toLowerCase() === manualUserEmail.toLowerCase());

    const newPayment: PaymentItem = {
      id: `PAY-MANUAL-${Math.floor(1000 + Math.random() * 9000)}`,
      userId: matchedUser?.id || undefined,
      userEmail: manualUserEmail,
      userName: manualUserName,
      tier: manualTier,
      durationDays: manualDurationDays,
      amount: Number(manualAmount) || 0,
      currency: 'DZD',
      paymentMethod: manualMethod,
      receiptReference: manualRef,
      receiptFileName: `attestation_manuelle_${manualRef}.pdf`,
      status: manualAutoApprove ? 'approved' : 'pending',
      paymentType: 'subscription',
      bonusCredits: 0,
      adminNotes: manualNotes,
      isArchived: false,
      createdAt: new Date().toISOString().slice(0, 19).replace('T', ' ')
    };

    if (onCreateManualPayment) {
      onCreateManualPayment(newPayment);
    }
    setInspectingPayment(newPayment);
    setShowManualModal(false);
  };

  return (
    <div className="space-y-5">
      {/* View Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-2 border-b border-slate-200 dark:border-slate-800">
        <div>
          <h1 className="text-xl md:text-2xl font-bold tracking-tight text-slate-900 dark:text-white flex items-center gap-2">
            <span>Paiements CCP & BaridiMob</span>
            <span className="text-sm">💳</span>
          </h1>
          <p className="text-xs md:text-sm text-slate-500 dark:text-slate-400 mt-0.5">
            Validation manuelle des reçus, encaissements et régularisation des abonnements.
          </p>
        </div>

        <div className="flex items-center gap-2">
          <span className="text-xs font-mono px-3 py-1.5 rounded-lg bg-teal-50 dark:bg-teal-950/60 text-teal-700 dark:text-teal-300 border border-teal-200 dark:border-teal-800 font-bold whitespace-nowrap">
            Validé : {financialMetrics.totalRevenue.toLocaleString()} DZD
          </span>
          <button
            onClick={() => setShowManualModal(true)}
            className="flex items-center gap-1.5 px-3 py-1.5 text-xs font-semibold text-white bg-teal-600 hover:bg-teal-700 dark:bg-teal-500 rounded-lg shadow-2xs transition-colors cursor-pointer whitespace-nowrap"
          >
            <Plus className="w-3.5 h-3.5" />
            <span>Paiement Manuel</span>
          </button>
        </div>
      </div>

      {/* 4 Financial Metric Cards */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
        <div className="p-3 bg-white dark:bg-slate-900 rounded-xl border border-slate-200 dark:border-slate-800 shadow-2xs">
          <span className="text-[10px] sm:text-[11px] text-slate-400 font-semibold uppercase block">Total Encaissé</span>
          <p className="text-lg sm:text-xl font-bold font-mono text-emerald-600 dark:text-emerald-400 tabular-nums mt-0.5">
            {financialMetrics.totalRevenue.toLocaleString()} <span className="text-xs font-normal">DZD</span>
          </p>
          <span className="text-[10px] text-slate-400">{financialMetrics.approvedCount} validés</span>
        </div>

        <div className="p-3 bg-white dark:bg-slate-900 rounded-xl border border-slate-200 dark:border-slate-800 shadow-2xs">
          <span className="text-[10px] sm:text-[11px] text-slate-400 font-semibold uppercase block">En Attente</span>
          <p className="text-lg sm:text-xl font-bold font-mono text-amber-600 dark:text-amber-400 tabular-nums mt-0.5">
            {financialMetrics.pendingRevenue.toLocaleString()} <span className="text-xs font-normal">DZD</span>
          </p>
          <span className="text-[10px] text-amber-600 font-semibold">{financialMetrics.pendingCount} à traiter</span>
        </div>

        <div className="p-3 bg-white dark:bg-slate-900 rounded-xl border border-slate-200 dark:border-slate-800 shadow-2xs">
          <span className="text-[10px] sm:text-[11px] text-slate-400 font-semibold uppercase block">Volume Total</span>
          <p className="text-lg sm:text-xl font-bold font-mono text-slate-900 dark:text-white tabular-nums mt-0.5">
            {financialMetrics.totalTransactions}
          </p>
          <span className="text-[10px] text-slate-400">Reçus enregistrés</span>
        </div>

        <div className="p-3 bg-white dark:bg-slate-900 rounded-xl border border-slate-200 dark:border-slate-800 shadow-2xs">
          <span className="text-[10px] sm:text-[11px] text-slate-400 font-semibold uppercase block">Reçus Rejetés</span>
          <p className="text-lg sm:text-xl font-bold font-mono text-rose-600 dark:text-rose-400 tabular-nums mt-0.5">
            {financialMetrics.rejectedCount}
          </p>
          <span className="text-[10px] text-slate-400">Non confirmés</span>
        </div>
      </div>

      {/* Filter Tabs & Search Bar */}
      <div className="p-3 bg-white dark:bg-slate-900 rounded-xl border border-slate-200 dark:border-slate-800 shadow-2xs flex flex-col md:flex-row md:items-center justify-between gap-3">
        {/* Status Segmented Buttons */}
        <div className="flex items-center gap-1.5 overflow-x-auto no-scrollbar text-xs">
          {[
            { id: 'all', label: 'Toutes les Transactions' },
            { id: 'pending', label: `En Attente (${financialMetrics.pendingCount})` },
            { id: 'approved', label: 'Validées' },
            { id: 'rejected', label: 'Rejetées' },
            { id: 'archived', label: 'Archivées' }
          ].map((tab) => (
            <button
              key={tab.id}
              onClick={() => setSelectedStatus(tab.id)}
              className={`px-3 py-1.5 rounded-lg whitespace-nowrap transition-colors cursor-pointer font-medium ${
                selectedStatus === tab.id
                  ? 'bg-teal-600 text-white dark:bg-teal-500 font-semibold shadow-2xs'
                  : 'bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-400 hover:bg-slate-200 dark:hover:bg-slate-700'
              }`}
            >
              {tab.label}
            </button>
          ))}
        </div>

        {/* Search */}
        <div className="relative w-full md:w-72">
          <Search className="w-4 h-4 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Rechercher réf, médecin, email..."
            className="w-full pl-9 pr-3 py-1.5 text-xs bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg text-slate-900 dark:text-white placeholder-slate-400 focus:outline-none"
          />
        </div>
      </div>

      {/* Mobile Card List (< lg screens) */}
      <div className="block lg:hidden space-y-3">
        {filteredPayments.length === 0 ? (
          <div className="p-6 text-center text-xs text-slate-400 bg-white dark:bg-slate-900 rounded-xl border border-slate-200 dark:border-slate-800">
            Aucune transaction trouvée pour ce filtre.
          </div>
        ) : (
          filteredPayments.map((p) => {
            const isPending = p.status === 'pending';
            const isApproved = p.status === 'approved';
            return (
              <div
                key={p.id}
                onClick={() => handleSelectPaymentMobile(p)}
                className="p-3.5 bg-white dark:bg-slate-900 rounded-xl border border-slate-200 dark:border-slate-800 shadow-2xs space-y-2.5 cursor-pointer hover:border-teal-500/50 transition-colors"
              >
                <div className="flex items-start justify-between gap-2">
                  <div className="min-w-0">
                    <p className="font-bold text-sm text-slate-900 dark:text-white truncate">
                      {p.userName}
                    </p>
                    <p className="text-[11px] text-slate-400 font-mono truncate">
                      {p.userEmail}
                    </p>
                  </div>
                  <span className={`px-2 py-0.5 rounded text-[10px] font-bold uppercase shrink-0 ${
                    isPending
                      ? 'bg-amber-100 text-amber-800 dark:bg-amber-950 dark:text-amber-300'
                      : isApproved
                      ? 'bg-emerald-100 text-emerald-800 dark:bg-emerald-950 dark:text-emerald-300'
                      : 'bg-rose-100 text-rose-800 dark:bg-rose-950 dark:text-rose-300'
                  }`}>
                    {p.status === 'pending' ? 'En attente' : p.status === 'approved' ? 'Validé' : 'Rejeté'}
                  </span>
                </div>

                <div className="flex items-center justify-between text-xs pt-1 border-t border-slate-100 dark:border-slate-800">
                  <div className="flex items-center gap-2">
                    <span className="font-mono font-bold text-teal-600 dark:text-teal-400 uppercase text-[11px]">
                      {p.paymentMethod}
                    </span>
                    <span className="text-slate-300 dark:text-slate-700">·</span>
                    <span className="font-mono text-slate-400 text-[11px]">
                      {p.createdAt.split(' ')[0]}
                    </span>
                  </div>

                  <span className="font-mono font-bold text-slate-900 dark:text-white">
                    {p.amount.toLocaleString()} DZD
                  </span>
                </div>

                <div className="flex items-center justify-between text-xs text-slate-400 pt-1">
                  <span className="font-mono text-[10px] truncate max-w-[180px]">
                    Réf : {p.receiptReference || 'Non spécifié'}
                  </span>
                  <button
                    onClick={(e) => {
                      e.stopPropagation();
                      handleSelectPaymentMobile(p);
                    }}
                    className="flex items-center gap-1 text-[11px] font-semibold text-teal-600 dark:text-teal-400 hover:underline"
                  >
                    <span>Inspecter</span>
                    <ArrowRight className="w-3 h-3" />
                  </button>
                </div>
              </div>
            );
          })
        )}
      </div>

      {/* Desktop Main Content: Payments Table Left (7 cols) + Receipt Inspector Right (5 cols) */}
      <div className="hidden lg:grid grid-cols-12 gap-5">
        {/* Left: Table */}
        <div className="col-span-7 bg-white dark:bg-slate-900 rounded-xl border border-slate-200 dark:border-slate-800 shadow-2xs overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full text-xs text-left">
              <thead className="bg-slate-50 dark:bg-slate-800/60 text-slate-500 dark:text-slate-400 border-b border-slate-200 dark:border-slate-800">
                <tr>
                  <th className="py-3 px-3.5 font-semibold">Médecin / Client</th>
                  <th className="py-3 px-3.5 font-semibold">Mode & Réf</th>
                  <th className="py-3 px-3.5 font-semibold">Montant DZD</th>
                  <th className="py-3 px-3.5 font-semibold">Statut</th>
                  <th className="py-3 px-3.5 font-semibold text-right">Date</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-200 dark:divide-slate-800">
                {filteredPayments.map((p) => {
                  const isSelected = inspectingPayment?.id === p.id;
                  const isPending = p.status === 'pending';
                  const isApproved = p.status === 'approved';
                  return (
                    <tr
                      key={p.id}
                      onClick={() => setInspectingPayment(p)}
                      className={`cursor-pointer transition-colors ${
                        isSelected
                          ? 'bg-teal-50/70 dark:bg-teal-950/40 font-medium'
                          : 'hover:bg-slate-50 dark:hover:bg-slate-800/50'
                      }`}
                    >
                      <td className="py-3 px-3.5">
                        <p className="font-bold text-slate-900 dark:text-white truncate max-w-[150px]">
                          {p.userName}
                        </p>
                        <p className="text-[11px] text-slate-400 truncate max-w-[150px]">
                          {p.userEmail}
                        </p>
                      </td>

                      <td className="py-3 px-3.5">
                        <span className="font-mono font-bold text-teal-600 dark:text-teal-400 uppercase">
                          {p.paymentMethod}
                        </span>
                        <p className="text-[11px] text-slate-400 font-mono truncate max-w-[130px]">
                          {p.receiptReference || 'Non spécifié'}
                        </p>
                      </td>

                      <td className="py-3 px-3.5 font-mono font-bold tabular-nums text-slate-900 dark:text-white">
                        {p.amount.toLocaleString()} DZD
                      </td>

                      <td className="py-3 px-3.5">
                        <span className={`inline-block px-2 py-0.5 rounded text-[10px] font-bold uppercase ${
                          isPending
                            ? 'bg-amber-100 text-amber-800 dark:bg-amber-950 dark:text-amber-300'
                            : isApproved
                            ? 'bg-emerald-100 text-emerald-800 dark:bg-emerald-950 dark:text-emerald-300'
                            : 'bg-rose-100 text-rose-800 dark:bg-rose-950 dark:text-rose-300'
                        }`}>
                          {p.status === 'pending' ? 'En attente' : p.status === 'approved' ? 'Validé' : 'Rejeté'}
                        </span>
                      </td>

                      <td className="py-3 px-3.5 text-right font-mono text-slate-400 text-[11px]">
                        {p.createdAt.split(' ')[0]}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>

        {/* Right: Detailed Receipt Inspector & Action Console */}
        <div className="col-span-5 space-y-4">
          {inspectingPayment ? (
            <div className="bg-white dark:bg-slate-900 rounded-xl border border-slate-200 dark:border-slate-800 shadow-2xs p-5 space-y-4">
              <div className="flex items-center justify-between pb-3 border-b border-slate-200 dark:border-slate-800">
                <div>
                  <h3 className="text-sm font-bold text-slate-900 dark:text-white">
                    Inspection du Reçu #{inspectingPayment.id}
                  </h3>
                  <p className="text-xs text-slate-400">
                    Déposé par {inspectingPayment.userName}
                  </p>
                </div>
                <span className={`px-2 py-0.5 rounded text-[10px] font-mono font-bold uppercase ${
                  inspectingPayment.status === 'approved'
                    ? 'bg-emerald-100 text-emerald-800 dark:bg-emerald-950 dark:text-emerald-300'
                    : inspectingPayment.status === 'pending'
                    ? 'bg-amber-100 text-amber-800 dark:bg-amber-950 dark:text-amber-300'
                    : 'bg-rose-100 text-rose-800 dark:bg-rose-950 dark:text-rose-300'
                }`}>
                  {inspectingPayment.status}
                </span>
              </div>

              {/* Transaction Key Info */}
              <div className="grid grid-cols-2 gap-3 text-xs">
                <div className="p-3 bg-slate-50 dark:bg-slate-800/50 rounded-lg border border-slate-200 dark:border-slate-800">
                  <span className="text-[10px] text-slate-400 uppercase font-semibold block">Montant Déclaré</span>
                  <span className="text-base font-bold font-mono text-teal-600 dark:text-teal-400 tabular-nums">
                    {inspectingPayment.amount.toLocaleString()} DZD
                  </span>
                </div>

                <div className="p-3 bg-slate-50 dark:bg-slate-800/50 rounded-lg border border-slate-200 dark:border-slate-800">
                  <span className="text-[10px] text-slate-400 uppercase font-semibold block">Formule Demandée</span>
                  <span className="text-sm font-bold text-slate-900 dark:text-white uppercase">
                    {inspectingPayment.tier.replace('_', ' ')} ({inspectingPayment.durationDays || 365}j)
                  </span>
                </div>
              </div>

              {/* Receipt File Preview Canvas */}
              <div className="p-4 bg-slate-950 rounded-xl border border-slate-800 text-white space-y-2">
                <div className="flex items-center justify-between text-xs pb-2 border-b border-slate-800">
                  <div className="flex items-center gap-1.5 font-semibold text-slate-200">
                    <FileText className="w-4 h-4 text-teal-400" />
                    <span className="truncate max-w-[200px]">{inspectingPayment.receiptFileName || 'recu_officiel_virement.pdf'}</span>
                  </div>
                  <span className="text-[10px] font-mono text-slate-400">PDF / Image</span>
                </div>

                {/* Simulated Receipt Voucher */}
                <div className="p-3 bg-slate-900/90 rounded-lg border border-slate-700/60 font-mono text-[11px] space-y-1 text-slate-300">
                  <p className="text-teal-400 font-bold">ALGERIE POSTE · BARIDIMOB / CCP</p>
                  <p>Réf Transaction : <strong className="text-white">{inspectingPayment.receiptReference}</strong></p>
                  <p>Bénéficiaire : MedSina Medical (CCP 0021489012 45)</p>
                  <p>Émetteur : {inspectingPayment.userName}</p>
                  <p>Montant : {inspectingPayment.amount.toLocaleString()} DZD · Validé Guichet</p>
                </div>
              </div>

              {/* Admin Note if already approved or rejected */}
              {inspectingPayment.adminNotes && (
                <div className="p-3 bg-slate-50 dark:bg-slate-800/50 rounded-lg border border-slate-200 dark:border-slate-800 text-xs text-slate-600 dark:text-slate-300">
                  <span className="font-semibold block mb-0.5">Notes Administrateur :</span>
                  <p>{inspectingPayment.adminNotes}</p>
                </div>
              )}

              {/* Direct Actions: Approve / Reject / Archive */}
              <div className="pt-2 border-t border-slate-200 dark:border-slate-800 flex flex-col gap-2">
                {inspectingPayment.status === 'pending' ? (
                  <div className="flex items-center gap-2">
                    <button
                      onClick={() => handleApprove(inspectingPayment)}
                      className="flex-1 flex items-center justify-center gap-1.5 py-2.5 px-3 bg-teal-600 hover:bg-teal-700 dark:bg-teal-500 text-white rounded-lg font-semibold text-xs shadow-xs transition-colors cursor-pointer"
                    >
                      <CheckCircle2 className="w-4 h-4" />
                      <span>Valider & Activer Compte</span>
                    </button>
                    <button
                      onClick={() => setShowRejectModal(true)}
                      className="flex items-center justify-center gap-1.5 py-2.5 px-3 bg-rose-50 text-rose-700 dark:bg-rose-950 dark:text-rose-300 hover:bg-rose-100 rounded-lg font-semibold text-xs border border-rose-200 dark:border-rose-900 transition-colors cursor-pointer"
                    >
                      <XCircle className="w-4 h-4" />
                      <span>Rejeter</span>
                    </button>
                  </div>
                ) : (
                  <div className="flex items-center justify-between text-xs">
                    <span className="text-emerald-600 dark:text-emerald-400 font-semibold flex items-center gap-1">
                      <CheckCircle2 className="w-4 h-4" />
                      Paiement régularisé
                    </span>
                    {!inspectingPayment.isArchived && (
                      <button
                        onClick={() => onArchivePayment(inspectingPayment.id)}
                        className="flex items-center gap-1 text-teal-600 dark:text-teal-400 hover:underline cursor-pointer"
                      >
                        <Archive className="w-3.5 h-3.5" />
                        <span>Archiver Google Drive</span>
                      </button>
                    )}
                  </div>
                )}
              </div>
            </div>
          ) : (
            <div className="p-8 text-center bg-white dark:bg-slate-900 rounded-xl border border-slate-200 dark:border-slate-800 text-xs text-slate-500">
              Sélectionnez un reçu dans la table pour inspecter les détails.
            </div>
          )}
        </div>
      </div>

      {/* Mobile Receipt Inspection Modal Sheet */}
      {showMobileInspector && inspectingPayment && (
        <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center p-0 sm:p-4 bg-slate-950/60 backdrop-blur-xs lg:hidden">
          <div className="w-full sm:max-w-lg bg-white dark:bg-slate-900 rounded-t-2xl sm:rounded-2xl shadow-2xl border border-slate-200 dark:border-slate-800 max-h-[90vh] flex flex-col overflow-hidden animate-in slide-in-from-bottom sm:zoom-in-95 duration-200">
            {/* Modal Header */}
            <div className="p-4 border-b border-slate-200 dark:border-slate-800 flex items-center justify-between bg-slate-50 dark:bg-slate-950/50">
              <div>
                <h3 className="text-sm font-bold text-slate-900 dark:text-white">
                  Inspection Reçu #{inspectingPayment.id}
                </h3>
                <p className="text-xs text-slate-400">
                  {inspectingPayment.userName}
                </p>
              </div>
              <button
                onClick={() => setShowMobileInspector(false)}
                className="p-1 text-slate-400 hover:text-slate-600 dark:hover:text-slate-200"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {/* Modal Body */}
            <div className="p-4 overflow-y-auto space-y-3.5 text-xs">
              <div className="grid grid-cols-2 gap-2.5">
                <div className="p-2.5 bg-slate-50 dark:bg-slate-800/50 rounded-lg border border-slate-200 dark:border-slate-800">
                  <span className="text-[10px] text-slate-400 uppercase font-semibold block">Montant</span>
                  <span className="text-base font-bold font-mono text-teal-600 dark:text-teal-400">
                    {inspectingPayment.amount.toLocaleString()} DZD
                  </span>
                </div>
                <div className="p-2.5 bg-slate-50 dark:bg-slate-800/50 rounded-lg border border-slate-200 dark:border-slate-800">
                  <span className="text-[10px] text-slate-400 uppercase font-semibold block">Formule</span>
                  <span className="text-sm font-bold text-slate-900 dark:text-white uppercase">
                    {inspectingPayment.tier.replace('_', ' ')}
                  </span>
                </div>
              </div>

              {/* Receipt Preview */}
              <div className="p-3 bg-slate-950 rounded-xl border border-slate-800 text-white space-y-1.5 font-mono text-[11px]">
                <p className="text-teal-400 font-bold">ALGERIE POSTE · BARIDIMOB / CCP</p>
                <p>Réf : <strong className="text-white">{inspectingPayment.receiptReference}</strong></p>
                <p>Médecin : {inspectingPayment.userName}</p>
                <p>Email : {inspectingPayment.userEmail}</p>
                <p>Mode : {inspectingPayment.paymentMethod.toUpperCase()}</p>
              </div>

              {inspectingPayment.adminNotes && (
                <div className="p-2.5 bg-slate-50 dark:bg-slate-800/50 rounded-lg border border-slate-200 dark:border-slate-800 text-xs">
                  <span className="font-semibold block mb-0.5">Notes :</span>
                  <p className="text-slate-600 dark:text-slate-300">{inspectingPayment.adminNotes}</p>
                </div>
              )}
            </div>

            {/* Modal Footer Actions */}
            <div className="p-4 border-t border-slate-200 dark:border-slate-800 bg-slate-50/50 dark:bg-slate-950/50">
              {inspectingPayment.status === 'pending' ? (
                <div className="flex items-center gap-2">
                  <button
                    onClick={() => {
                      handleApprove(inspectingPayment);
                      setShowMobileInspector(false);
                    }}
                    className="flex-1 py-2.5 px-3 bg-teal-600 hover:bg-teal-700 text-white rounded-lg font-semibold text-xs shadow-xs"
                  >
                    Valider & Activer
                  </button>
                  <button
                    onClick={() => {
                      setShowMobileInspector(false);
                      setShowRejectModal(true);
                    }}
                    className="py-2.5 px-3 bg-rose-50 text-rose-700 dark:bg-rose-950 dark:text-rose-300 rounded-lg font-semibold text-xs border border-rose-200 dark:border-rose-900"
                  >
                    Rejeter
                  </button>
                </div>
              ) : (
                <div className="flex items-center justify-between">
                  <span className="text-emerald-600 font-semibold flex items-center gap-1 text-xs">
                    <CheckCircle2 className="w-4 h-4" />
                    Paiement régularisé
                  </span>
                  <button
                    onClick={() => setShowMobileInspector(false)}
                    className="px-3 py-1.5 bg-slate-200 dark:bg-slate-700 rounded-lg text-xs"
                  >
                    Fermer
                  </button>
                </div>
              )}
            </div>
          </div>
        </div>
      )}

      {/* Manual Payment Creation Modal */}
      {showManualModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/60 backdrop-blur-xs">
          <div className="w-full max-w-lg bg-white dark:bg-slate-900 rounded-2xl shadow-2xl border border-slate-200 dark:border-slate-800 max-h-[90vh] flex flex-col overflow-hidden animate-in fade-in-50 duration-150">
            <div className="p-4 border-b border-slate-200 dark:border-slate-800 flex items-center justify-between bg-slate-50 dark:bg-slate-950/50">
              <div className="flex items-center gap-2">
                <CreditCard className="w-4 h-4 text-teal-600" />
                <h3 className="text-sm font-bold text-slate-900 dark:text-white">
                  Enregistrer un Paiement Manuel
                </h3>
              </div>
              <button
                onClick={() => setShowManualModal(false)}
                className="p-1 text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 cursor-pointer"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            <form onSubmit={handleConfirmManualPayment} className="p-4 sm:p-5 overflow-y-auto space-y-3.5 text-xs">
              {/* Select from existing users */}
              {users.length > 0 && (
                <div>
                  <label className="font-semibold block mb-1 text-slate-700 dark:text-slate-300">
                    Choisir un médecin inscrit (optionnel) :
                  </label>
                  <select
                    onChange={(e) => handleSelectUserForManual(e.target.value)}
                    className="w-full p-2 bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg text-slate-900 dark:text-white"
                  >
                    <option value="">Sélectionner un praticien dans la liste...</option>
                    {users.map((u) => (
                      <option key={u.id} value={u.id}>
                        {u.fullName} ({u.email}) - {u.tier}
                      </option>
                    ))}
                  </select>
                </div>
              )}

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label className="font-semibold block mb-1 text-slate-700 dark:text-slate-300">
                    Nom Complet du Médecin * :
                  </label>
                  <input
                    type="text"
                    required
                    value={manualUserName}
                    onChange={(e) => setManualUserName(e.target.value)}
                    placeholder="Dr. Amina Benali"
                    className="w-full p-2 bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg text-slate-900 dark:text-white"
                  />
                </div>
                <div>
                  <label className="font-semibold block mb-1 text-slate-700 dark:text-slate-300">
                    Adresse Email * :
                  </label>
                  <input
                    type="email"
                    required
                    value={manualUserEmail}
                    onChange={(e) => setManualUserEmail(e.target.value)}
                    placeholder="amina.benali@univ-alger.dz"
                    className="w-full p-2 bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg text-slate-900 dark:text-white"
                  />
                </div>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                <div>
                  <label className="font-semibold block mb-1 text-slate-700 dark:text-slate-300">
                    Formule :
                  </label>
                  <select
                    value={manualTier}
                    onChange={(e) => setManualTier(e.target.value as any)}
                    className="w-full p-2 bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg text-slate-900 dark:text-white"
                  >
                    <option value="resident_elite">Résident Élite (12 000 DZD)</option>
                    <option value="all_access">All-Access VIP (18 000 DZD)</option>
                    <option value="clinical_pro">Clinical Pro (9 000 DZD)</option>
                    <option value="etudiant">Étudiant (4 500 DZD)</option>
                  </select>
                </div>

                <div>
                  <label className="font-semibold block mb-1 text-slate-700 dark:text-slate-300">
                    Montant DZD * :
                  </label>
                  <input
                    type="number"
                    required
                    value={manualAmount}
                    onChange={(e) => setManualAmount(Number(e.target.value))}
                    className="w-full p-2 bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg font-mono text-slate-900 dark:text-white"
                  />
                </div>

                <div>
                  <label className="font-semibold block mb-1 text-slate-700 dark:text-slate-300">
                    Mode Paiement :
                  </label>
                  <select
                    value={manualMethod}
                    onChange={(e) => setManualMethod(e.target.value as any)}
                    className="w-full p-2 bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg text-slate-900 dark:text-white"
                  >
                    <option value="cash">Espèces / Cash</option>
                    <option value="baridimob">BaridiMob Virement</option>
                    <option value="ccp">Bordereau CCP Guichet</option>
                    <option value="cib">Carte CIB / Edahabia</option>
                  </select>
                </div>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label className="font-semibold block mb-1 text-slate-700 dark:text-slate-300">
                    Durée d'Accès :
                  </label>
                  <select
                    value={manualDurationDays}
                    onChange={(e) => setManualDurationDays(Number(e.target.value))}
                    className="w-full p-2 bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg text-slate-900 dark:text-white"
                  >
                    <option value={365}>1 An (365 jours)</option>
                    <option value={180}>6 Mois (180 jours)</option>
                    <option value={90}>3 Mois (90 jours)</option>
                    <option value={30}>1 Mois (30 jours)</option>
                  </select>
                </div>

                <div>
                  <label className="font-semibold block mb-1 text-slate-700 dark:text-slate-300">
                    Numéro de Reçu / Réf :
                  </label>
                  <input
                    type="text"
                    value={manualRef}
                    onChange={(e) => setManualRef(e.target.value)}
                    className="w-full p-2 bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg font-mono text-slate-900 dark:text-white"
                  />
                </div>
              </div>

              <div>
                <label className="font-semibold block mb-1 text-slate-700 dark:text-slate-300">
                  Notes Administrateur :
                </label>
                <input
                  type="text"
                  value={manualNotes}
                  onChange={(e) => setManualNotes(e.target.value)}
                  className="w-full p-2 bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg text-slate-900 dark:text-white"
                />
              </div>

              <div className="flex items-center gap-2 pt-1">
                <input
                  type="checkbox"
                  id="autoApprove"
                  checked={manualAutoApprove}
                  onChange={(e) => setManualAutoApprove(e.target.checked)}
                  className="rounded text-teal-600 focus:ring-teal-500"
                />
                <label htmlFor="autoApprove" className="font-medium text-slate-700 dark:text-slate-300">
                  Valider immédiatement et activer la formule du médecin
                </label>
              </div>

              <div className="flex items-center justify-end gap-2 pt-3 border-t border-slate-200 dark:border-slate-800">
                <button
                  type="button"
                  onClick={() => setShowManualModal(false)}
                  className="px-3 py-1.5 text-slate-500 hover:text-slate-800 dark:hover:text-slate-200 cursor-pointer"
                >
                  Annuler
                </button>
                <button
                  type="submit"
                  className="px-4 py-2 bg-teal-600 hover:bg-teal-700 text-white font-semibold rounded-lg shadow-xs cursor-pointer"
                >
                  Enregistrer & Régulariser
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Reject Payment Reason Modal */}
      {showRejectModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/60 backdrop-blur-xs">
          <div className="w-full max-w-md bg-white dark:bg-slate-900 rounded-xl shadow-2xl border border-slate-200 dark:border-slate-800 p-5 space-y-4">
            <h3 className="text-sm font-bold text-slate-900 dark:text-white">
              Rejeter la preuve de paiement
            </h3>
            <p className="text-xs text-slate-500">
              Indiquez la raison pour laquelle le reçu CCP/BaridiMob ne peut pas être validé.
            </p>
            <textarea
              rows={3}
              value={rejectReason}
              onChange={(e) => setRejectReason(e.target.value)}
              placeholder="e.g. Numéro de transaction introuvable sur le relevé CCP, montant insuffisant..."
              className="w-full p-2.5 bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg text-xs text-slate-900 dark:text-white"
            />
            <div className="flex items-center justify-end gap-2 pt-2">
              <button
                onClick={() => setShowRejectModal(false)}
                className="px-3 py-1.5 text-xs text-slate-500 hover:text-slate-800 cursor-pointer"
              >
                Annuler
              </button>
              <button
                onClick={handleConfirmReject}
                className="px-4 py-1.5 text-xs font-semibold text-white bg-rose-600 hover:bg-rose-700 rounded-lg cursor-pointer"
              >
                Confirmer le Rejet
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
