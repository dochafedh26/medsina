import React, { useState } from 'react';
import { 
  Key, 
  Plus, 
  Copy, 
  Check, 
  Ban, 
  Download, 
  Search, 
  ShieldAlert, 
  CheckCircle2, 
  X,
  FileSpreadsheet
} from 'lucide-react';
import { AdminLicenseItem, SubscriptionTier } from '../../types/medsina';

interface LicensesViewProps {
  licenses: AdminLicenseItem[];
  onGenerateLicenses: (tier: SubscriptionTier, durationDays: number, count: number, prefix: string) => void;
  onRevokeLicense: (keyCode: string, reason: string) => void;
}

export const LicensesView: React.FC<LicensesViewProps> = ({
  licenses,
  onGenerateLicenses,
  onRevokeLicense
}) => {
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedFilter, setSelectedFilter] = useState<'all' | 'available' | 'redeemed' | 'revoked'>('all');
  const [showGenerateModal, setShowGenerateModal] = useState(false);
  const [copiedKey, setCopiedKey] = useState<string | null>(null);

  // Revoke state
  const [keyToRevoke, setKeyToRevoke] = useState<AdminLicenseItem | null>(null);
  const [revocationReason, setRevocationReason] = useState('Fraude au bordereau CCP ou compte partagé');

  // Generator form
  const [genTier, setGenTier] = useState<SubscriptionTier>('all_access');
  const [genDuration, setGenDuration] = useState<number>(365);
  const [genCount, setGenCount] = useState<number>(5);
  const [genPrefix, setGenPrefix] = useState<string>('MEDSINA-VIP-2027');

  const filteredLicenses = licenses.filter((l) => {
    const matchesSearch = 
      l.keyCode.toLowerCase().includes(searchQuery.toLowerCase()) ||
      (l.redeemedUserName && l.redeemedUserName.toLowerCase().includes(searchQuery.toLowerCase())) ||
      (l.redeemedUserEmail && l.redeemedUserEmail.toLowerCase().includes(searchQuery.toLowerCase()));

    if (selectedFilter === 'available') return matchesSearch && !l.isRedeemed && !l.isRevoked;
    if (selectedFilter === 'redeemed') return matchesSearch && l.isRedeemed && !l.isRevoked;
    if (selectedFilter === 'revoked') return matchesSearch && l.isRevoked;
    return matchesSearch;
  });

  const handleCopy = (code: string) => {
    navigator.clipboard.writeText(code);
    setCopiedKey(code);
    setTimeout(() => setCopiedKey(null), 2000);
  };

  const handleConfirmGenerate = (e: React.FormEvent) => {
    e.preventDefault();
    onGenerateLicenses(genTier, genDuration, genCount, genPrefix);
    setShowGenerateModal(false);
  };

  const handleConfirmRevoke = () => {
    if (!keyToRevoke) return;
    onRevokeLicense(keyToRevoke.keyCode, revocationReason);
    setKeyToRevoke(null);
  };

  const handleExportCsv = () => {
    const headers = ['KeyCode', 'Tier', 'Duration_Days', 'IsRedeemed', 'RedeemedBy', 'RedeemedEmail', 'IsRevoked'];
    const rows = filteredLicenses.map(l => [
      l.keyCode,
      l.tier,
      l.durationDays,
      l.isRedeemed ? 'YES' : 'NO',
      `"${l.redeemedUserName || ''}"`,
      l.redeemedUserEmail || '',
      l.isRevoked ? 'REVOKED' : 'ACTIVE'
    ]);
    const csvContent = 'data:text/csv;charset=utf-8,' + [headers.join(','), ...rows.map(e => e.join(','))].join('\n');
    const encodedUri = encodeURI(csvContent);
    const link = document.createElement('a');
    link.setAttribute('href', encodedUri);
    link.setAttribute('download', `medsina_licences_${new Date().toISOString().slice(0, 10)}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  return (
    <div className="space-y-5">
      {/* View Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-2 border-b border-slate-200 dark:border-slate-800">
        <div>
          <h1 className="text-xl md:text-2xl font-bold tracking-tight text-slate-900 dark:text-white">
            Clés de Licence VIP & Quotas d'Accès 🔑
          </h1>
          <p className="text-xs md:text-sm text-slate-500 dark:text-slate-400 mt-0.5">
            Génération de codes VIP à usage unique pour partenaires, facultés de médecine et abonnements groupés.
          </p>
        </div>

        <div className="flex items-center gap-2">
          <button
            onClick={handleExportCsv}
            className="flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium text-slate-700 dark:text-slate-300 bg-white dark:bg-slate-800 hover:bg-slate-50 rounded-lg border border-slate-200 dark:border-slate-700 shadow-2xs transition-colors cursor-pointer"
          >
            <Download className="w-3.5 h-3.5" />
            <span>Exporter CSV</span>
          </button>
          <button
            onClick={() => setShowGenerateModal(true)}
            className="flex items-center gap-1.5 px-3.5 py-1.5 text-xs font-semibold text-white bg-teal-600 hover:bg-teal-700 dark:bg-teal-500 rounded-lg shadow-2xs transition-colors cursor-pointer"
          >
            <Plus className="w-3.5 h-3.5" />
            <span>Générer Clés VIP</span>
          </button>
        </div>
      </div>

      {/* Filter and Search Bar */}
      <div className="p-3 bg-white dark:bg-slate-900 rounded-xl border border-slate-200 dark:border-slate-800 shadow-2xs flex flex-col md:flex-row md:items-center justify-between gap-3">
        {/* Status Filter */}
        <div className="flex items-center gap-1.5 overflow-x-auto text-xs">
          {[
            { id: 'all', label: 'Toutes les Clés' },
            { id: 'available', label: 'Disponibles / Non Activées' },
            { id: 'redeemed', label: 'Activées par un Médecin' },
            { id: 'revoked', label: 'Révoquées / Suspendues' }
          ].map((tab) => (
            <button
              key={tab.id}
              onClick={() => setSelectedFilter(tab.id as any)}
              className={`px-3 py-1.5 rounded-lg whitespace-nowrap transition-colors cursor-pointer font-medium ${
                selectedFilter === tab.id
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
            placeholder="Rechercher une clé ou un bénéficiaire..."
            className="w-full pl-9 pr-3 py-1.5 text-xs bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg text-slate-900 dark:text-white placeholder-slate-400 focus:outline-none"
          />
        </div>
      </div>

      {/* Mobile Licenses Card List (< md screens) */}
      <div className="block md:hidden space-y-3">
        {filteredLicenses.length === 0 ? (
          <div className="p-6 text-center text-xs text-slate-400 bg-white dark:bg-slate-900 rounded-xl border border-slate-200 dark:border-slate-800">
            Aucune clé de licence trouvée pour ce filtre.
          </div>
        ) : (
          filteredLicenses.map((lic) => {
            const isRevoked = lic.isRevoked;
            const isRedeemed = lic.isRedeemed && !lic.isRevoked;
            return (
              <div
                key={lic.keyCode}
                className="p-3.5 bg-white dark:bg-slate-900 rounded-xl border border-slate-200 dark:border-slate-800 shadow-2xs space-y-2.5"
              >
                <div className="flex items-center justify-between gap-2">
                  <div className="flex items-center gap-2">
                    <span className={`font-mono font-bold text-xs tabular-nums ${isRevoked ? 'line-through text-rose-500' : 'text-teal-600 dark:text-teal-400'}`}>
                      {lic.keyCode}
                    </span>
                    <button
                      onClick={() => handleCopy(lic.keyCode)}
                      className="p-1 text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 cursor-pointer"
                      title="Copier le code"
                    >
                      {copiedKey === lic.keyCode ? <Check className="w-4 h-4 text-emerald-500" /> : <Copy className="w-4 h-4" />}
                    </button>
                  </div>

                  <span className={`px-2 py-0.5 rounded text-[10px] font-bold uppercase ${
                    isRevoked
                      ? 'bg-rose-100 text-rose-800 dark:bg-rose-950 dark:text-rose-300'
                      : isRedeemed
                      ? 'bg-blue-100 text-blue-800 dark:bg-blue-950 dark:text-blue-300'
                      : 'bg-emerald-100 text-emerald-800 dark:bg-emerald-950 dark:text-emerald-300'
                  }`}>
                    {isRevoked ? 'Révoquée' : isRedeemed ? 'Activée' : 'Disponible'}
                  </span>
                </div>

                <div className="flex items-center justify-between text-xs pt-1 border-t border-slate-100 dark:border-slate-800">
                  <span className="font-semibold text-slate-800 dark:text-slate-200 uppercase text-[11px]">
                    {lic.tier.replace('_', ' ')}
                  </span>
                  <span className="text-slate-500 dark:text-slate-400 text-[11px]">
                    {lic.durationDays} Jours
                  </span>
                </div>

                {isRedeemed && (
                  <div className="p-2 bg-slate-50 dark:bg-slate-800/50 rounded-lg text-xs space-y-0.5">
                    <p className="font-bold text-slate-900 dark:text-white">{lic.redeemedUserName}</p>
                    <p className="text-[11px] text-slate-400 font-mono">{lic.redeemedUserEmail} · {lic.redeemedAt}</p>
                  </div>
                )}

                {isRevoked && (
                  <p className="text-[11px] text-rose-500 italic">
                    Raison : {lic.revocationReason || 'Non précisé'}
                  </p>
                )}

                {!isRevoked && (
                  <div className="flex justify-end pt-1">
                    <button
                      onClick={() => setKeyToRevoke(lic)}
                      className="px-2.5 py-1 text-xs font-semibold text-rose-700 dark:text-rose-300 bg-rose-50 dark:bg-rose-950/60 hover:bg-rose-100 rounded transition-colors cursor-pointer"
                    >
                      Révoquer cette clé
                    </button>
                  </div>
                )}
              </div>
            );
          })
        )}
      </div>

      {/* Desktop Licenses Table (>= md screens) */}
      <div className="hidden md:block bg-white dark:bg-slate-900 rounded-xl border border-slate-200 dark:border-slate-800 shadow-2xs overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-xs text-left">
            <thead className="bg-slate-50 dark:bg-slate-800/60 text-slate-500 dark:text-slate-400 border-b border-slate-200 dark:border-slate-800">
              <tr>
                <th className="py-3 px-4 font-semibold">Code Clé de Licence</th>
                <th className="py-3 px-4 font-semibold">Formule Associée</th>
                <th className="py-3 px-4 font-semibold">Durée d'Accès</th>
                <th className="py-3 px-4 font-semibold">Statut & Bénéficiaire</th>
                <th className="py-3 px-4 font-semibold text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-200 dark:divide-slate-800 font-mono">
              {filteredLicenses.map((lic) => {
                const isRevoked = lic.isRevoked;
                const isRedeemed = lic.isRedeemed && !lic.isRevoked;
                return (
                  <tr key={lic.keyCode} className="hover:bg-slate-50/70 dark:hover:bg-slate-800/40 transition-colors">
                    <td className="py-3.5 px-4">
                      <div className="flex items-center gap-2">
                        <span className={`font-bold tabular-nums ${isRevoked ? 'line-through text-rose-500' : 'text-teal-600 dark:text-teal-400'}`}>
                          {lic.keyCode}
                        </span>
                        <button
                          onClick={() => handleCopy(lic.keyCode)}
                          className="p-1 text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 cursor-pointer"
                          title="Copier le code"
                        >
                          {copiedKey === lic.keyCode ? <Check className="w-3.5 h-3.5 text-emerald-500" /> : <Copy className="w-3.5 h-3.5" />}
                        </button>
                      </div>
                    </td>

                    <td className="py-3.5 px-4 font-sans uppercase font-bold text-slate-800 dark:text-slate-200 text-[11px]">
                      {lic.tier.replace('_', ' ')}
                    </td>

                    <td className="py-3.5 px-4 tabular-nums text-slate-700 dark:text-slate-300 font-sans">
                      {lic.durationDays} Jours
                    </td>

                    <td className="py-3.5 px-4 font-sans">
                      {isRevoked ? (
                        <div>
                          <span className="text-[10px] font-bold text-rose-600 uppercase">Révoquée</span>
                          <p className="text-[10px] text-slate-400">{lic.revocationReason || 'Non précisé'}</p>
                        </div>
                      ) : isRedeemed ? (
                        <div>
                          <span className="font-bold text-slate-900 dark:text-white">{lic.redeemedUserName}</span>
                          <p className="text-[11px] text-slate-400 font-mono">{lic.redeemedUserEmail} · {lic.redeemedAt}</p>
                        </div>
                      ) : (
                        <span className="text-[11px] font-bold text-emerald-600 dark:text-emerald-400">
                          Disponible (Non activée)
                        </span>
                      )}
                    </td>

                    <td className="py-3.5 px-4 text-right font-sans">
                      {!isRevoked && (
                        <button
                          onClick={() => setKeyToRevoke(lic)}
                          className="px-2.5 py-1 text-xs font-semibold text-rose-700 dark:text-rose-300 bg-rose-50 dark:bg-rose-950/60 hover:bg-rose-100 rounded transition-colors cursor-pointer"
                        >
                          Révoquer
                        </button>
                      )}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </div>

      {/* Generate Keys Modal */}
      {showGenerateModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/60 backdrop-blur-xs">
          <div className="w-full max-w-md bg-white dark:bg-slate-900 rounded-2xl shadow-2xl border border-slate-200 dark:border-slate-800 max-h-[90vh] flex flex-col overflow-hidden animate-in fade-in-50 duration-150">
            <div className="p-4 border-b border-slate-200 dark:border-slate-800 flex items-center justify-between bg-slate-50 dark:bg-slate-950/50">
              <h3 className="text-sm font-bold text-slate-900 dark:text-white">
                Générateur de Clés VIP Medsina
              </h3>
              <button onClick={() => setShowGenerateModal(false)} className="text-slate-400 hover:text-slate-600 cursor-pointer">
                <X className="w-4 h-4" />
              </button>
            </div>

            <form onSubmit={handleConfirmGenerate} className="space-y-3.5 text-xs">
              <div>
                <label className="block font-semibold text-slate-700 dark:text-slate-300 mb-1">
                  Formule d'Abonnement à Octroyer
                </label>
                <select
                  value={genTier}
                  onChange={(e) => setGenTier(e.target.value as SubscriptionTier)}
                  className="w-full px-3 py-2 bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg text-slate-900 dark:text-white"
                >
                  <option value="all_access">Medsina All-Access VIP</option>
                  <option value="resident_elite">Résident Élite (Concours)</option>
                  <option value="clinical_pro">Clinical Pro</option>
                  <option value="etudiant">Formule Étudiant</option>
                </select>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block font-semibold text-slate-700 dark:text-slate-300 mb-1">
                    Durée (Jours)
                  </label>
                  <select
                    value={genDuration}
                    onChange={(e) => setGenDuration(Number(e.target.value))}
                    className="w-full px-3 py-2 bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg text-slate-900 dark:text-white"
                  >
                    <option value={30}>30 Jours (1 Mois)</option>
                    <option value={90}>90 Jours (3 Mois)</option>
                    <option value={180}>180 Jours (6 Mois)</option>
                    <option value={365}>365 Jours (1 An)</option>
                  </select>
                </div>

                <div>
                  <label className="block font-semibold text-slate-700 dark:text-slate-300 mb-1">
                    Nombre de Clés
                  </label>
                  <input
                    type="number"
                    min="1"
                    max="50"
                    value={genCount}
                    onChange={(e) => setGenCount(Number(e.target.value))}
                    className="w-full px-3 py-2 bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg text-slate-900 dark:text-white font-mono"
                  />
                </div>
              </div>

              <div>
                <label className="block font-semibold text-slate-700 dark:text-slate-300 mb-1">
                  Préfixe du Code de Licence
                </label>
                <input
                  type="text"
                  value={genPrefix}
                  onChange={(e) => setGenPrefix(e.target.value)}
                  className="w-full px-3 py-2 bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg text-slate-900 dark:text-white font-mono"
                />
              </div>

              <div className="pt-2 flex justify-end gap-2">
                <button
                  type="button"
                  onClick={() => setShowGenerateModal(false)}
                  className="px-3 py-1.5 text-slate-500 hover:text-slate-800 cursor-pointer"
                >
                  Annuler
                </button>
                <button
                  type="submit"
                  className="px-4 py-2 bg-teal-600 hover:bg-teal-700 text-white rounded-lg font-semibold cursor-pointer shadow-xs"
                >
                  Générer {genCount} Clé(s)
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Revoke Key Modal */}
      {keyToRevoke && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/60 backdrop-blur-xs">
          <div className="w-full max-w-md bg-white dark:bg-slate-900 rounded-xl shadow-2xl border border-slate-200 dark:border-slate-800 p-5 space-y-4">
            <h3 className="text-sm font-bold text-slate-900 dark:text-white">
              Révoquer la clé {keyToRevoke.keyCode} ?
            </h3>
            <p className="text-xs text-slate-500">
              L'accès associé à cette clé sera immédiatement suspendu sur l'application mobile et web.
            </p>
            <textarea
              rows={2}
              value={revocationReason}
              onChange={(e) => setRevocationReason(e.target.value)}
              className="w-full p-2 bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded text-xs text-slate-900 dark:text-white"
            />
            <div className="flex justify-end gap-2 pt-1">
              <button
                onClick={() => setKeyToRevoke(null)}
                className="px-3 py-1.5 text-xs text-slate-500 cursor-pointer"
              >
                Annuler
              </button>
              <button
                onClick={handleConfirmRevoke}
                className="px-4 py-1.5 text-xs font-semibold text-white bg-rose-600 hover:bg-rose-700 rounded-lg cursor-pointer"
              >
                Confirmer la Révocation
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
