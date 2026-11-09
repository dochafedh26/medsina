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
  Building2
} from 'lucide-react';
import { PaymentItem, FinancialMetrics } from '../../types/medsina';

interface PaymentsViewProps {
  payments: PaymentItem[];
  financialMetrics: FinancialMetrics;
  onApprovePayment: (paymentId: string, bonusCredits: number, adminNotes?: string) => void;
  onRejectPayment: (paymentId: string, reason: string) => void;
  onArchivePayment: (paymentId: string) => void;
}

export const PaymentsView: React.FC<PaymentsViewProps> = ({
  payments,
  financialMetrics,
  onApprovePayment,
  onRejectPayment,
  onArchivePayment
}) => {
  const [selectedStatus, setSelectedStatus] = useState<string>('all');
  const [searchQuery, setSearchQuery] = useState<string>('');
  const [inspectingPayment, setInspectingPayment] = useState<PaymentItem | null>(payments[0] || null);
  const [rejectReason, setRejectReason] = useState<string>('');
  const [showRejectModal, setShowRejectModal] = useState<boolean>(false);
  const [bonusCreditsInput, setBonusCreditsInput] = useState<number>(0);
  const [approvalNotes, setApprovalNotes] = useState<string>('Validé par Dr. Hafedh. Attestation CCP vérifiée.');

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

  return (
    <div className="space-y-5">
      {/* View Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-2 border-b border-slate-200 dark:border-slate-800">
        <div>
          <h1 className="text-xl md:text-2xl font-bold tracking-tight text-slate-900 dark:text-white">
            Paiements CCP & Facturation BaridiMob 💳
          </h1>
          <p className="text-xs md:text-sm text-slate-500 dark:text-slate-400 mt-0.5">
            Validation manuelle des reçus de virement, régularisation des abonnements et archivage fiscal.
          </p>
        </div>

        <div className="flex items-center gap-2">
          <span className="text-xs font-mono px-3 py-1.5 rounded-lg bg-teal-50 dark:bg-teal-950/60 text-teal-700 dark:text-teal-300 border border-teal-200 dark:border-teal-800 font-bold">
            Total Validé : {financialMetrics.totalRevenue.toLocaleString()} DZD
          </span>
        </div>
      </div>

      {/* 4 Financial Metric Cards */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-3.5">
        <div className="p-3.5 bg-white dark:bg-slate-900 rounded-xl border border-slate-200 dark:border-slate-800 shadow-2xs">
          <span className="text-[11px] text-slate-400 font-semibold uppercase">Total Encaissé</span>
          <p className="text-xl font-bold font-mono text-emerald-600 dark:text-emerald-400 tabular-nums mt-1">
            {financialMetrics.totalRevenue.toLocaleString()} <span className="text-xs font-normal">DZD</span>
          </p>
          <span className="text-[10px] text-slate-400">{financialMetrics.approvedCount} transactions validées</span>
        </div>

        <div className="p-3.5 bg-white dark:bg-slate-900 rounded-xl border border-slate-200 dark:border-slate-800 shadow-2xs">
          <span className="text-[11px] text-slate-400 font-semibold uppercase">En Attente de Revue</span>
          <p className="text-xl font-bold font-mono text-amber-600 dark:text-amber-400 tabular-nums mt-1">
            {financialMetrics.pendingRevenue.toLocaleString()} <span className="text-xs font-normal">DZD</span>
          </p>
          <span className="text-[10px] text-amber-600 font-semibold">{financialMetrics.pendingCount} reçus à traiter</span>
        </div>

        <div className="p-3.5 bg-white dark:bg-slate-900 rounded-xl border border-slate-200 dark:border-slate-800 shadow-2xs">
          <span className="text-[11px] text-slate-400 font-semibold uppercase">Volume Total</span>
          <p className="text-xl font-bold font-mono text-slate-900 dark:text-white tabular-nums mt-1">
            {financialMetrics.totalTransactions}
          </p>
          <span className="text-[10px] text-slate-400">Reçus traités sur la plateforme</span>
        </div>

        <div className="p-3.5 bg-white dark:bg-slate-900 rounded-xl border border-slate-200 dark:border-slate-800 shadow-2xs">
          <span className="text-[11px] text-slate-400 font-semibold uppercase">Reçus Rejetés</span>
          <p className="text-xl font-bold font-mono text-rose-600 dark:text-rose-400 tabular-nums mt-1">
            {financialMetrics.rejectedCount}
          </p>
          <span className="text-[10px] text-slate-400">Paiements non confirmés</span>
        </div>
      </div>

      {/* Filter Tabs & Search Bar */}
      <div className="p-3 bg-white dark:bg-slate-900 rounded-xl border border-slate-200 dark:border-slate-800 shadow-2xs flex flex-col md:flex-row md:items-center justify-between gap-3">
        {/* Status Segmented Buttons */}
        <div className="flex items-center gap-1.5 overflow-x-auto text-xs">
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
                  : 'bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-400 hover:bg-slate-200'
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
            placeholder="Rechercher par référence, médecin, email..."
            className="w-full pl-9 pr-3 py-1.5 text-xs bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg text-slate-900 dark:text-white placeholder-slate-400 focus:outline-none"
          />
        </div>
      </div>

      {/* Main Content: Payments Table Left (7 cols) + Receipt Inspector Right (5 cols) */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-5">
        {/* Left: Table */}
        <div className="lg:col-span-7 bg-white dark:bg-slate-900 rounded-xl border border-slate-200 dark:border-slate-800 shadow-2xs overflow-hidden">
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
        <div className="lg:col-span-5 space-y-4">
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
                    {inspectingPayment.tier.replace('_', ' ')} (365j)
                  </span>
                </div>
              </div>

              {/* Receipt File Preview Canvas */}
              <div className="p-4 bg-slate-950 rounded-xl border border-slate-800 text-white space-y-2">
                <div className="flex items-center justify-between text-xs pb-2 border-b border-slate-800">
                  <div className="flex items-center gap-1.5 font-semibold text-slate-200">
                    <FileText className="w-4 h-4 text-teal-400" />
                    <span>{inspectingPayment.receiptFileName || 'recu_officiel_virement.pdf'}</span>
                  </div>
                  <span className="text-[10px] font-mono text-slate-400">PDF / Image</span>
                </div>

                {/* Simulated Receipt Voucher */}
                <div className="p-3 bg-slate-900/90 rounded-lg border border-slate-700/60 font-mono text-[11px] space-y-1 text-slate-300">
                  <p className="text-teal-400 font-bold">ALGERIE POSTE · BARIDIMOB / CCP</p>
                  <p>Réf Transaction : <strong className="text-white">{inspectingPayment.receiptReference}</strong></p>
                  <p>Bénéficiaire : MedSina Medical Education (CCP 0021489012 45)</p>
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
