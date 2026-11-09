import React, { useState } from 'react';
import { 
  Megaphone, 
  Plus, 
  Bell, 
  Share2, 
  Copy, 
  Check, 
  AlertTriangle, 
  Info, 
  CheckCircle2, 
  Trash2,
  Sparkles,
  Send,
  X
} from 'lucide-react';
import { AnnouncementItem, AdminFacebookPrompt } from '../../types/medsina';

interface AnnouncementsViewProps {
  announcements: AnnouncementItem[];
  facebookPrompts: AdminFacebookPrompt[];
  onAddAnnouncement: (announcement: AnnouncementItem) => void;
  onToggleAnnouncement: (id: string) => void;
}

export const AnnouncementsView: React.FC<AnnouncementsViewProps> = ({
  announcements,
  facebookPrompts,
  onAddAnnouncement,
  onToggleAnnouncement
}) => {
  const [showAddModal, setShowAddModal] = useState(false);
  const [copiedPromptId, setCopiedPromptId] = useState<string | null>(null);

  // New announcement form
  const [title, setTitle] = useState('');
  const [message, setMessage] = useState('');
  const [type, setType] = useState<AnnouncementItem['type']>('info');
  const [targetRole, setTargetRole] = useState<AnnouncementItem['targetRole']>('all');

  const handleCopyPrompt = (id: string, text: string) => {
    navigator.clipboard.writeText(text);
    setCopiedPromptId(id);
    setTimeout(() => setCopiedPromptId(null), 2000);
  };

  const handleCreateAnnouncement = (e: React.FormEvent) => {
    e.preventDefault();
    if (!title) return;

    const newAnn: AnnouncementItem = {
      id: `ANN-${Math.floor(10 + Math.random() * 90)}`,
      title,
      message,
      type,
      targetRole,
      isActive: true,
      createdAt: new Date().toISOString().slice(0, 10)
    };

    onAddAnnouncement(newAnn);
    setTitle('');
    setMessage('');
    setShowAddModal(false);
  };

  return (
    <div className="space-y-6">
      {/* View Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-2 border-b border-slate-200 dark:border-slate-800">
        <div>
          <h1 className="text-xl md:text-2xl font-bold tracking-tight text-slate-900 dark:text-white">
            Annonces Système & Diffusion Marketing 📢
          </h1>
          <p className="text-xs md:text-sm text-slate-500 dark:text-slate-400 mt-0.5">
            Bannières d'alerte pour les étudiants et médecins, et générateur de publications Facebook Medsina.
          </p>
        </div>

        <button
          onClick={() => setShowAddModal(true)}
          className="flex items-center gap-1.5 px-3.5 py-2 text-xs font-semibold text-white bg-teal-600 hover:bg-teal-700 dark:bg-teal-500 rounded-lg shadow-2xs transition-colors cursor-pointer whitespace-nowrap"
        >
          <Plus className="w-3.5 h-3.5" />
          <span>Diffuser une Annonce</span>
        </button>
      </div>

      {/* Grid: System Announcements Left (6 cols) + Facebook Campaign Generator Right (6 cols) */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        {/* Left: Active System Announcements */}
        <div className="lg:col-span-6 space-y-4">
          <div className="flex items-center justify-between">
            <h2 className="text-sm font-bold text-slate-900 dark:text-white flex items-center gap-2">
              <Megaphone className="w-4 h-4 text-teal-600 dark:text-teal-400" />
              Bannières In-App Actives ({announcements.length})
            </h2>
            <span className="text-[11px] text-slate-400">Visibles dans Octenium Mobile & Web</span>
          </div>

          <div className="space-y-3">
            {announcements.map((ann) => {
              const isUrgent = ann.type === 'urgent';
              const isSuccess = ann.type === 'success';
              return (
                <div
                  key={ann.id}
                  className={`p-4 rounded-xl border transition-all bg-white dark:bg-slate-900 ${
                    ann.isActive
                      ? 'border-slate-200 dark:border-slate-800 shadow-2xs'
                      : 'opacity-60 border-slate-200 dark:border-slate-800 bg-slate-50'
                  }`}
                >
                  <div className="flex items-start justify-between gap-3">
                    <div className="space-y-1">
                      <div className="flex items-center gap-2">
                        <span className={`px-2 py-0.5 rounded text-[10px] font-bold uppercase ${
                          isUrgent
                            ? 'bg-rose-100 text-rose-800 dark:bg-rose-950 dark:text-rose-300'
                            : isSuccess
                            ? 'bg-emerald-100 text-emerald-800 dark:bg-emerald-950 dark:text-emerald-300'
                            : 'bg-sky-100 text-sky-800 dark:bg-sky-950 dark:text-sky-300'
                        }`}>
                          {ann.type}
                        </span>
                        <h3 className="font-bold text-xs text-slate-900 dark:text-white">
                          {ann.title}
                        </h3>
                      </div>
                      <p className="text-xs text-slate-600 dark:text-slate-300 leading-relaxed pt-1">
                        {ann.message}
                      </p>
                    </div>

                    {/* Toggle Switch */}
                    <button
                      onClick={() => onToggleAnnouncement(ann.id)}
                      className={`w-10 h-5 rounded-full transition-colors relative cursor-pointer shrink-0 ${
                        ann.isActive ? 'bg-teal-600' : 'bg-slate-300 dark:bg-slate-700'
                      }`}
                      title={ann.isActive ? 'Désactiver la bannière' : 'Activer la bannière'}
                    >
                      <span
                        className={`w-3.5 h-3.5 rounded-full bg-white absolute top-0.5 transition-transform ${
                          ann.isActive ? 'left-5' : 'left-1'
                        }`}
                      />
                    </button>
                  </div>

                  <div className="mt-3 pt-2 border-t border-slate-100 dark:border-slate-800 flex items-center justify-between text-[11px] text-slate-400 font-mono">
                    <span>Cible : {ann.targetRole.toUpperCase()}</span>
                    <span>Publié le : {ann.createdAt}</span>
                  </div>
                </div>
              );
            })}
          </div>
        </div>

        {/* Right: Facebook & Social Marketing Generator (from generate_facebook_assets.py) */}
        <div className="lg:col-span-6 space-y-4">
          <div className="flex items-center justify-between">
            <h2 className="text-sm font-bold text-slate-900 dark:text-white flex items-center gap-2">
              <Share2 className="w-4 h-4 text-blue-600 dark:text-blue-400" />
              Prompts Marketing Facebook Medsina
            </h2>
            <span className="text-[11px] font-mono text-slate-400">generate_facebook_assets.py</span>
          </div>

          <div className="space-y-3.5">
            {facebookPrompts.map((prm) => (
              <div
                key={prm.id}
                className="p-4 bg-white dark:bg-slate-900 rounded-xl border border-slate-200 dark:border-slate-800 shadow-2xs space-y-2.5"
              >
                <div className="flex items-center justify-between gap-2">
                  <div className="flex items-center gap-2">
                    <span className="px-2 py-0.5 rounded text-[10px] font-bold uppercase bg-blue-50 text-blue-700 dark:bg-blue-950 dark:text-blue-300 border border-blue-200 dark:border-blue-900">
                      {prm.postType}
                    </span>
                    <h3 className="font-bold text-xs text-slate-900 dark:text-white truncate">
                      {prm.title}
                    </h3>
                  </div>

                  <button
                    onClick={() => handleCopyPrompt(prm.id, prm.fullPrompt)}
                    className="flex items-center gap-1 px-2.5 py-1 text-xs font-semibold text-slate-700 dark:text-slate-300 bg-slate-100 dark:bg-slate-800 hover:bg-slate-200 rounded cursor-pointer shrink-0"
                  >
                    {copiedPromptId === prm.id ? (
                      <>
                        <Check className="w-3.5 h-3.5 text-emerald-500" />
                        <span>Copié !</span>
                      </>
                    ) : (
                      <>
                        <Copy className="w-3.5 h-3.5" />
                        <span>Copier pour Facebook</span>
                      </>
                    )}
                  </button>
                </div>

                <p className="text-xs text-slate-500 dark:text-slate-400">
                  {prm.summary}
                </p>

                <pre className="p-3 bg-slate-950 text-slate-200 rounded-lg text-[11px] font-mono whitespace-pre-wrap leading-relaxed max-h-36 overflow-y-auto border border-slate-800">
                  {prm.fullPrompt}
                </pre>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Broadcast Announcement Modal */}
      {showAddModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-4 bg-slate-950/60 backdrop-blur-xs">
          <div className="w-full max-w-md bg-white dark:bg-slate-900 rounded-2xl shadow-2xl border border-slate-200 dark:border-slate-800 max-h-[90vh] flex flex-col overflow-hidden animate-in fade-in-50 duration-150">
            <div className="p-4 border-b border-slate-200 dark:border-slate-800 flex items-center justify-between bg-slate-50 dark:bg-slate-950/50 shrink-0">
              <h3 className="text-sm font-bold text-slate-900 dark:text-white">
                Diffuser une Nouvelle Annonce Système
              </h3>
              <button onClick={() => setShowAddModal(false)} className="text-slate-400 hover:text-slate-600 cursor-pointer">
                <X className="w-4 h-4" />
              </button>
            </div>

            <form onSubmit={handleCreateAnnouncement} className="p-4 sm:p-5 overflow-y-auto space-y-3 text-xs">
              <div>
                <label className="block font-semibold text-slate-700 dark:text-slate-300 mb-1">
                  Titre du Message
                </label>
                <input
                  type="text"
                  required
                  placeholder="e.g. Session spéciale Concours Résidanat..."
                  value={title}
                  onChange={(e) => setTitle(e.target.value)}
                  className="w-full px-3 py-2 bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg text-slate-900 dark:text-white"
                />
              </div>

              <div>
                <label className="block font-semibold text-slate-700 dark:text-slate-300 mb-1">
                  Corps de l'Annonce
                </label>
                <textarea
                  rows={3}
                  required
                  placeholder="Détails de l'annonce diffusée sur les terminaux des médecins..."
                  value={message}
                  onChange={(e) => setMessage(e.target.value)}
                  className="w-full px-3 py-2 bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg text-slate-900 dark:text-white"
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block font-semibold text-slate-700 dark:text-slate-300 mb-1">
                    Niveau d'Urgence
                  </label>
                  <select
                    value={type}
                    onChange={(e) => setType(e.target.value as any)}
                    className="w-full px-3 py-2 bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg text-slate-900 dark:text-white"
                  >
                    <option value="info">Information (Bleu)</option>
                    <option value="urgent">Urgent / Important (Rouge)</option>
                    <option value="success">Succès / Nouveauté (Vert)</option>
                    <option value="warning">Avertissement (Orange)</option>
                  </select>
                </div>

                <div>
                  <label className="block font-semibold text-slate-700 dark:text-slate-300 mb-1">
                    Destinataires
                  </label>
                  <select
                    value={targetRole}
                    onChange={(e) => setTargetRole(e.target.value as any)}
                    className="w-full px-3 py-2 bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg text-slate-900 dark:text-white"
                  >
                    <option value="all">Tous les utilisateurs</option>
                    <option value="residents">Candidats Résidanat</option>
                    <option value="students">Étudiants & Externes</option>
                    <option value="doctors">Médecins en exercice</option>
                  </select>
                </div>
              </div>

              <div className="pt-2 flex justify-end gap-2">
                <button
                  type="button"
                  onClick={() => setShowAddModal(false)}
                  className="px-3 py-1.5 text-slate-500 hover:text-slate-800 cursor-pointer"
                >
                  Annuler
                </button>
                <button
                  type="submit"
                  className="px-4 py-2 bg-teal-600 hover:bg-teal-700 text-white rounded-lg font-semibold cursor-pointer shadow-xs"
                >
                  Publier Immédiatement
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
