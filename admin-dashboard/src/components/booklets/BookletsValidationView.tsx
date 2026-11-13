import React, { useState, useEffect, useMemo } from 'react';
import {
  BookOpen,
  CheckCircle2,
  Clock,
  Edit3,
  ExternalLink,
  Eye,
  Flame,
  MessageSquareWarning,
  Network,
  RefreshCw,
  Search,
  X,
  XCircle,
} from 'lucide-react';
import { AdminBookletItem, BookletValidationStatus } from '../../types/medsina';
import {
  fetchBookletsForValidation,
  updateBookletValidationStatus,
} from '../../services/supabase';

interface BookletsValidationViewProps {
  adminId?: string;
}

const STATUS_META: Record<
  BookletValidationStatus,
  { label: string; badgeClass: string; icon: React.FC<{ className?: string }> }
> = {
  pending_review: {
    label: 'En attente de validation',
    badgeClass:
      'bg-amber-100 text-amber-800 dark:bg-amber-900/40 dark:text-amber-300 border-amber-200 dark:border-amber-800',
    icon: Clock,
  },
  changes_requested: {
    label: 'Modifications suggérées',
    badgeClass:
      'bg-orange-100 text-orange-800 dark:bg-orange-900/40 dark:text-orange-300 border-orange-200 dark:border-orange-800',
    icon: MessageSquareWarning,
  },
  approved: {
    label: 'Approuvé & Publié',
    badgeClass:
      'bg-emerald-100 text-emerald-800 dark:bg-emerald-900/40 dark:text-emerald-300 border-emerald-200 dark:border-emerald-800',
    icon: CheckCircle2,
  },
  rejected: {
    label: 'Rejeté / Dépublié',
    badgeClass:
      'bg-rose-100 text-rose-800 dark:bg-rose-900/40 dark:text-rose-300 border-rose-200 dark:border-rose-800',
    icon: XCircle,
  },
};

function toPreviewUrl(url: string): string {
  const driveMatch = url.match(/\/file\/d\/([^/]+)/);
  if (driveMatch && driveMatch[1]) {
    return `https://drive.google.com/file/d/${driveMatch[1]}/preview`;
  }
  return url;
}

export const BookletsValidationView: React.FC<BookletsValidationViewProps> = ({
  adminId,
}) => {
  const [booklets, setBooklets] = useState<AdminBookletItem[]>([]);
  const [isLoading, setIsLoading] = useState<boolean>(true);
  const [searchQuery, setSearchQuery] = useState<string>('');
  const [statusFilter, setStatusFilter] = useState<BookletValidationStatus | 'all'>(
    'pending_review'
  );
  const [savingId, setSavingId] = useState<string | null>(null);

  // Preview Modal
  const [previewBooklet, setPreviewBooklet] = useState<AdminBookletItem | null>(null);

  // Suggest Modifications Modal
  const [editingBooklet, setEditingBooklet] = useState<AdminBookletItem | null>(null);
  const [notesDraft, setNotesDraft] = useState<string>('');

  const loadBooklets = async () => {
    setIsLoading(true);
    const items = await fetchBookletsForValidation();
    setBooklets(items);
    setIsLoading(false);
  };

  useEffect(() => {
    loadBooklets();
  }, []);

  const counts = useMemo(() => {
    const map: Record<BookletValidationStatus | 'all', number> = {
      all: booklets.length,
      pending_review: 0,
      changes_requested: 0,
      approved: 0,
      rejected: 0,
    };
    for (const b of booklets) {
      map[b.bundleValidationStatus] = (map[b.bundleValidationStatus] || 0) + 1;
    }
    return map;
  }, [booklets]);

  const filteredBooklets = useMemo(() => {
    const q = searchQuery.trim().toLowerCase();
    return booklets.filter((b) => {
      const matchesStatus =
        statusFilter === 'all' || b.bundleValidationStatus === statusFilter;
      const matchesQuery =
        !q ||
        b.name.toLowerCase().includes(q) ||
        b.moduleId.toLowerCase().includes(q) ||
        b.id.toLowerCase().includes(q);
      return matchesStatus && matchesQuery;
    });
  }, [booklets, statusFilter, searchQuery]);

  const handleStatusChange = async (
    booklet: AdminBookletItem,
    newStatus: BookletValidationStatus,
    notes?: string
  ) => {
    setSavingId(booklet.id);
    const finalNotes = notes !== undefined ? notes : booklet.bundleAdminNotes;
    const ok = await updateBookletValidationStatus(
      booklet.id,
      newStatus,
      finalNotes,
      adminId
    );
    if (ok) {
      setBooklets((prev) =>
        prev.map((item) =>
          item.id === booklet.id
            ? {
                ...item,
                bundleValidationStatus: newStatus,
                bundleAdminNotes: finalNotes?.trim() ? finalNotes.trim() : undefined,
                bundleReviewedAt: new Date().toISOString(),
              }
            : item
        )
      );
      if (editingBooklet?.id === booklet.id) {
        setEditingBooklet(null);
        setNotesDraft('');
      }
    }
    setSavingId(null);
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-slate-900 dark:text-white flex items-center gap-2.5">
            <BookOpen className="w-6 h-6 text-teal-600 dark:text-teal-400" />
            Validation Humaine des Livrets 2027
          </h1>
          <p className="text-sm text-slate-500 dark:text-slate-400 mt-1">
            Consultez chaque livret généré (Fiche + Mindmap + Cours officiel + QCMs + Corrigé type), suggérez des modifications si besoin, puis approuvez-le pour publication aux étudiants.
          </p>
        </div>
        <button
          type="button"
          onClick={loadBooklets}
          disabled={isLoading}
          className="inline-flex items-center gap-2 px-4 py-2 rounded-xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 text-sm font-semibold text-slate-700 dark:text-slate-200 hover:bg-slate-50 dark:hover:bg-slate-800 transition-colors cursor-pointer shrink-0"
        >
          <RefreshCw className={`w-4 h-4 ${isLoading ? 'animate-spin' : ''}`} />
          Actualiser
        </button>
      </div>

      {/* KPI Filter Cards */}
      <div className="grid grid-cols-2 lg:grid-cols-5 gap-3">
        {(
          [
            { key: 'pending_review', label: 'En attente', color: 'text-amber-600 dark:text-amber-400' },
            { key: 'changes_requested', label: 'Modifications suggérées', color: 'text-orange-600 dark:text-orange-400' },
            { key: 'approved', label: 'Approuvés & Publiés', color: 'text-emerald-600 dark:text-emerald-400' },
            { key: 'rejected', label: 'Rejetés', color: 'text-rose-600 dark:text-rose-400' },
            { key: 'all', label: 'Tous les livrets', color: 'text-slate-700 dark:text-slate-200' },
          ] as const
        ).map((item) => {
          const active = statusFilter === item.key;
          return (
            <button
              key={item.key}
              type="button"
              onClick={() => setStatusFilter(item.key)}
              className={`p-3.5 rounded-2xl border text-left transition-all cursor-pointer ${
                active
                  ? 'bg-teal-50/70 dark:bg-teal-950/30 border-teal-500 ring-1 ring-teal-500/40'
                  : 'bg-white dark:bg-slate-900 border-slate-200 dark:border-slate-800 hover:border-slate-300 dark:hover:border-slate-700'
              }`}
            >
              <div className="text-xs font-medium text-slate-500 dark:text-slate-400">
                {item.label}
              </div>
              <div className={`text-2xl font-bold mt-1 ${item.color}`}>
                {counts[item.key]}
              </div>
            </button>
          );
        })}
      </div>

      {/* Search */}
      <div className="relative">
        <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
        <input
          type="text"
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          placeholder="Rechercher un livret par cours ou module..."
          className="w-full pl-10 pr-4 py-2.5 rounded-xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 text-sm text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-teal-500"
        />
      </div>

      {/* List */}
      {isLoading ? (
        <div className="flex flex-col items-center justify-center py-16 text-slate-500 dark:text-slate-400">
          <div className="w-8 h-8 border-3 border-teal-500 border-t-transparent rounded-full animate-spin mb-3" />
          <p className="text-sm">Chargement des livrets générés...</p>
        </div>
      ) : filteredBooklets.length === 0 ? (
        <div className="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-2xl p-10 text-center">
          <BookOpen className="w-10 h-10 text-slate-300 dark:text-slate-700 mx-auto mb-3" />
          <p className="text-sm font-medium text-slate-700 dark:text-slate-300">
            Aucun livret dans cette catégorie.
          </p>
        </div>
      ) : (
        <div className="space-y-3">
          {filteredBooklets.map((b) => {
            const meta = STATUS_META[b.bundleValidationStatus] || STATUS_META.pending_review;
            const StatusIcon = meta.icon;
            const isSaving = savingId === b.id;

            return (
              <div
                key={b.id}
                className="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-2xl p-4 sm:p-5 flex flex-col lg:flex-row lg:items-center lg:justify-between gap-4"
              >
                <div className="space-y-2 min-w-0 flex-1">
                  <div className="flex flex-wrap items-center gap-2">
                    <span
                      className={`inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-semibold border ${meta.badgeClass}`}
                    >
                      <StatusIcon className="w-3.5 h-3.5" />
                      {meta.label}
                    </span>

                    {b.isHypertombable && (
                      <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-semibold bg-rose-100 text-rose-700 dark:bg-rose-900/40 dark:text-rose-300">
                        <Flame className="w-3.5 h-3.5" />
                        Hypertombable
                      </span>
                    )}

                    {b.bundleHasMindmap && (
                      <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-semibold bg-sky-100 text-sky-700 dark:bg-sky-900/40 dark:text-sky-300">
                        <Network className="w-3.5 h-3.5" />
                        Mindmap incluse
                      </span>
                    )}

                    <span className="text-xs font-mono text-slate-500 dark:text-slate-400">
                      {b.qcmCount} QCMs
                    </span>
                  </div>

                  <div>
                    <h3 className="text-base font-bold text-slate-900 dark:text-white truncate">
                      {b.name}
                    </h3>
                    <p className="text-xs text-slate-500 dark:text-slate-400 mt-0.5">
                      Module : <span className="font-medium">{b.moduleId}</span>
                      {b.bundleGeneratedAt && (
                        <>
                          {' '}• Généré le{' '}
                          {new Date(b.bundleGeneratedAt).toLocaleDateString('fr-FR', {
                            day: '2-digit',
                            month: 'short',
                            year: 'numeric',
                          })}
                        </>
                      )}
                    </p>
                  </div>

                  {b.bundleAdminNotes && (
                    <div className="p-3 rounded-xl bg-orange-50 dark:bg-orange-950/30 border border-orange-200 dark:border-orange-900/60 text-xs text-orange-900 dark:text-orange-200">
                      <span className="font-semibold">Note / Suggestion Admin :</span>{' '}
                      {b.bundleAdminNotes}
                    </div>
                  )}
                </div>

                {/* Actions */}
                <div className="flex flex-wrap items-center gap-2 shrink-0">
                  <button
                    type="button"
                    onClick={() => setPreviewBooklet(b)}
                    className="inline-flex items-center gap-1.5 px-3 py-2 rounded-xl bg-slate-100 dark:bg-slate-800 text-slate-700 dark:text-slate-200 hover:bg-slate-200 dark:hover:bg-slate-700 text-xs font-semibold transition-colors cursor-pointer"
                  >
                    <Eye className="w-3.5 h-3.5" />
                    Consulter
                  </button>

                  <a
                    href={b.bundlePdfUrl}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="inline-flex items-center gap-1.5 px-3 py-2 rounded-xl bg-slate-100 dark:bg-slate-800 text-slate-700 dark:text-slate-200 hover:bg-slate-200 dark:hover:bg-slate-700 text-xs font-semibold transition-colors"
                  >
                    <ExternalLink className="w-3.5 h-3.5" />
                    Ouvrir
                  </a>

                  <button
                    type="button"
                    disabled={isSaving}
                    onClick={() => {
                      setEditingBooklet(b);
                      setNotesDraft(b.bundleAdminNotes || '');
                    }}
                    className="inline-flex items-center gap-1.5 px-3 py-2 rounded-xl bg-amber-50 dark:bg-amber-950/40 text-amber-700 dark:text-amber-300 border border-amber-200 dark:border-amber-800 hover:bg-amber-100 dark:hover:bg-amber-900/50 text-xs font-semibold transition-colors cursor-pointer disabled:opacity-50"
                  >
                    <Edit3 className="w-3.5 h-3.5" />
                    Suggérer modif.
                  </button>

                  {b.bundleValidationStatus !== 'approved' && (
                    <button
                      type="button"
                      disabled={isSaving}
                      onClick={() => handleStatusChange(b, 'approved')}
                      className="inline-flex items-center gap-1.5 px-3.5 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-semibold transition-colors cursor-pointer disabled:opacity-50"
                    >
                      <CheckCircle2 className="w-3.5 h-3.5" />
                      Valider & Publier
                    </button>
                  )}

                  {b.bundleValidationStatus !== 'rejected' && (
                    <button
                      type="button"
                      disabled={isSaving}
                      onClick={() => handleStatusChange(b, 'rejected')}
                      className="inline-flex items-center gap-1.5 px-3 py-2 rounded-xl bg-rose-50 dark:bg-rose-950/40 text-rose-700 dark:text-rose-300 border border-rose-200 dark:border-rose-800 hover:bg-rose-100 dark:hover:bg-rose-900/50 text-xs font-semibold transition-colors cursor-pointer disabled:opacity-50"
                    >
                      <XCircle className="w-3.5 h-3.5" />
                      Rejeter
                    </button>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* Embedded PDF Preview Modal */}
      {previewBooklet && (
        <div className="fixed inset-0 z-50 bg-slate-950/70 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-2xl w-full max-w-5xl h-[88vh] flex flex-col overflow-hidden shadow-2xl">
            <div className="flex items-center justify-between px-5 py-3.5 border-b border-slate-200 dark:border-slate-800">
              <div className="min-w-0">
                <h3 className="text-sm font-bold text-slate-900 dark:text-white truncate">
                  Consultation du Livret : {previewBooklet.name}
                </h3>
                <p className="text-xs text-slate-500 dark:text-slate-400">
                  Vérifiez la présence de la Fiche de synthèse, Pièges, Mindmap, Cours officiel, QCMs et Corrigé type.
                </p>
              </div>
              <div className="flex items-center gap-2 shrink-0">
                {previewBooklet.bundleValidationStatus !== 'approved' && (
                  <button
                    type="button"
                    onClick={() => {
                      handleStatusChange(previewBooklet, 'approved');
                      setPreviewBooklet(null);
                    }}
                    className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-semibold cursor-pointer"
                  >
                    <CheckCircle2 className="w-3.5 h-3.5" />
                    Valider & Publier
                  </button>
                )}
                <button
                  type="button"
                  onClick={() => setPreviewBooklet(null)}
                  className="p-1.5 rounded-lg text-slate-400 hover:text-slate-700 dark:hover:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-800 cursor-pointer"
                >
                  <X className="w-5 h-5" />
                </button>
              </div>
            </div>
            <iframe
              src={toPreviewUrl(previewBooklet.bundlePdfUrl)}
              title={previewBooklet.name}
              className="w-full flex-1 bg-slate-100 dark:bg-slate-950"
            />
          </div>
        </div>
      )}

      {/* Suggest Modifications Modal */}
      {editingBooklet && (
        <div className="fixed inset-0 z-50 bg-slate-950/60 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-2xl w-full max-w-lg p-6 space-y-4 shadow-2xl">
            <div className="flex items-start justify-between gap-3">
              <div>
                <h3 className="text-base font-bold text-slate-900 dark:text-white">
                  Suggérer des modifications
                </h3>
                <p className="text-xs text-slate-500 dark:text-slate-400 mt-0.5">
                  {editingBooklet.name}
                </p>
              </div>
              <button
                type="button"
                onClick={() => setEditingBooklet(null)}
                className="p-1 rounded-lg text-slate-400 hover:text-slate-700 dark:hover:text-slate-200 cursor-pointer"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <textarea
              rows={4}
              value={notesDraft}
              onChange={(e) => setNotesDraft(e.target.value)}
              placeholder="Décrivez les corrections souhaitées (ex: vérifier la page 4 du cours officiel, compléter les pièges concours, ajuster la Mindmap...)"
              className="w-full p-3 rounded-xl bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 text-sm text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-amber-500"
            />

            <div className="flex items-center justify-end gap-2">
              <button
                type="button"
                onClick={() => setEditingBooklet(null)}
                className="px-4 py-2 rounded-xl text-xs font-semibold text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 cursor-pointer"
              >
                Annuler
              </button>
              <button
                type="button"
                disabled={!notesDraft.trim() || savingId === editingBooklet.id}
                onClick={() =>
                  handleStatusChange(editingBooklet, 'changes_requested', notesDraft)
                }
                className="px-4 py-2 rounded-xl bg-amber-600 hover:bg-amber-700 text-white text-xs font-semibold disabled:opacity-50 cursor-pointer"
              >
                Enregistrer les suggestions
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
