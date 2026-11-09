import React, { useState } from 'react';
import { 
  Award, 
  Plus, 
  Calendar, 
  Clock, 
  Users, 
  CheckCircle2, 
  BookOpen, 
  Radio, 
  X,
  TrendingUp,
  Percent
} from 'lucide-react';
import { NationalExamModel } from '../../types/medsina';

interface NationalExamsViewProps {
  exams: NationalExamModel[];
  onCreateExam: (newExam: NationalExamModel) => void;
}

export const NationalExamsView: React.FC<NationalExamsViewProps> = ({
  exams,
  onCreateExam
}) => {
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [title, setTitle] = useState('Concours Blanc National Résidanat 2027 — Session d\'Hiver');
  const [description, setDescription] = useState('Épreuve officielle nationale simulant le concours de résidanat algérien. 60 QCMs transversaux avec classement national immédiat.');
  const [targetType, setTargetType] = useState<'residency' | 'externat' | 'clinical'>('residency');
  const [moduleName, setModuleName] = useState('Épreuve Transversale Nationale');
  const [questionCount, setQuestionCount] = useState<number>(60);
  const [durationMinutes, setDurationMinutes] = useState<number>(60);
  const [isSynchronous, setIsSynchronous] = useState<boolean>(true);
  const [startDate, setStartDate] = useState('2026-11-22 14:00');
  const [endDate, setEndDate] = useState('2026-11-22 17:00');

  const handleCreate = (e: React.FormEvent) => {
    e.preventDefault();
    if (!title) return;

    const newExam: NationalExamModel = {
      id: `EXAM-${Math.floor(2027 + Math.random() * 100)}`,
      title,
      description,
      targetType,
      moduleName,
      questionCount: Number(questionCount) || 60,
      durationMinutes: Number(durationMinutes) || 60,
      startDate,
      endDate,
      isSynchronous,
      participantsCount: 0,
      averageScore: 0,
      highestScore: 0,
      passRate: 0,
      status: 'upcoming'
    };

    onCreateExam(newExam);
    setShowCreateModal(false);
  };

  return (
    <div className="space-y-5">
      {/* View Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-2 border-b border-slate-200 dark:border-slate-800">
        <div>
          <h1 className="text-xl md:text-2xl font-bold tracking-tight text-slate-900 dark:text-white">
            Concours Blancs & Examens Nationaux 🏆
          </h1>
          <p className="text-xs md:text-sm text-slate-500 dark:text-slate-400 mt-0.5">
            Organisation des épreuves nationales de simulation pour le concours de résidanat et examens d'externat.
          </p>
        </div>

        <button
          onClick={() => setShowCreateModal(true)}
          className="flex items-center gap-1.5 px-3.5 py-2 text-xs font-semibold text-white bg-teal-600 hover:bg-teal-700 dark:bg-teal-500 rounded-lg shadow-2xs transition-colors cursor-pointer whitespace-nowrap"
        >
          <Plus className="w-3.5 h-3.5" />
          <span>Créer un Concours Blanc</span>
        </button>
      </div>

      {/* Exam Cards Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-5">
        {exams.map((exam) => {
          const isUpcoming = exam.status === 'upcoming';
          return (
            <div
              key={exam.id}
              className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200 dark:border-slate-800 shadow-2xs p-5 flex flex-col justify-between"
            >
              <div>
                <div className="flex items-center justify-between gap-2 mb-2">
                  <span className={`px-2 py-0.5 rounded text-[10px] font-bold uppercase ${
                    isUpcoming
                      ? 'bg-amber-100 text-amber-800 dark:bg-amber-950 dark:text-amber-300'
                      : 'bg-emerald-100 text-emerald-800 dark:bg-emerald-950 dark:text-emerald-300'
                  }`}>
                    {exam.status === 'upcoming' ? 'Session À Venir' : 'Épreuve Clôturée'}
                  </span>
                  <span className="text-[11px] font-mono text-slate-400">
                    {exam.isSynchronous ? 'Synchrone (Direct)' : 'Asynchrone'}
                  </span>
                </div>

                <h3 className="text-sm font-bold text-slate-900 dark:text-white leading-snug">
                  {exam.title}
                </h3>

                <p className="text-xs text-slate-500 dark:text-slate-400 mt-2 line-clamp-2">
                  {exam.description}
                </p>

                {/* Exam Key Specifications */}
                <div className="mt-4 p-3 bg-slate-50 dark:bg-slate-800/50 rounded-xl border border-slate-200 dark:border-slate-800 space-y-2 text-xs font-mono">
                  <div className="flex items-center justify-between text-slate-700 dark:text-slate-300">
                    <span className="flex items-center gap-1.5 font-sans">
                      <BookOpen className="w-3.5 h-3.5 text-teal-600 dark:text-teal-400" />
                      Module :
                    </span>
                    <strong className="truncate max-w-[160px] font-sans">{exam.moduleName || 'Transversal'}</strong>
                  </div>

                  <div className="flex items-center justify-between text-slate-700 dark:text-slate-300">
                    <span className="flex items-center gap-1.5 font-sans">
                      <Clock className="w-3.5 h-3.5 text-teal-600 dark:text-teal-400" />
                      QCMs & Durée :
                    </span>
                    <span>{exam.questionCount} QCMs · {exam.durationMinutes} min</span>
                  </div>

                  <div className="flex items-center justify-between text-slate-700 dark:text-slate-300">
                    <span className="flex items-center gap-1.5 font-sans">
                      <Calendar className="w-3.5 h-3.5 text-teal-600 dark:text-teal-400" />
                      Date :
                    </span>
                    <span>{exam.startDate.split(' ')[0]}</span>
                  </div>
                </div>

                {/* Results & Statistics if completed */}
                {exam.status === 'completed' && (
                  <div className="mt-3 grid grid-cols-3 gap-2 text-center text-xs font-mono pt-2 border-t border-slate-100 dark:border-slate-800">
                    <div>
                      <span className="text-[10px] text-slate-400 font-sans block">Participants</span>
                      <strong className="text-slate-900 dark:text-white tabular-nums">{exam.participantsCount}</strong>
                    </div>
                    <div>
                      <span className="text-[10px] text-slate-400 font-sans block">Moyenne</span>
                      <strong className="text-teal-600 dark:text-teal-400 tabular-nums">{exam.averageScore} / 20</strong>
                    </div>
                    <div>
                      <span className="text-[10px] text-slate-400 font-sans block">Major</span>
                      <strong className="text-amber-600 dark:text-amber-400 tabular-nums">{exam.highestScore} / 20</strong>
                    </div>
                  </div>
                )}
              </div>

              {/* Action Button */}
              <div className="mt-4 pt-3 border-t border-slate-100 dark:border-slate-800">
                <button
                  onClick={() => alert(`Leaderboard pour ${exam.title} : ${exam.participantsCount} candidats classés avec succès.`)}
                  className="w-full py-2 px-3 text-xs font-semibold text-teal-700 dark:text-teal-300 bg-teal-50 dark:bg-teal-950/60 hover:bg-teal-100 rounded-lg transition-colors cursor-pointer text-center"
                >
                  {exam.status === 'completed' ? 'Consulter le Classement National' : 'Gérer les Inscriptions'}
                </button>
              </div>
            </div>
          );
        })}
      </div>

      {/* Create National Exam Modal (Matches admin_national_exams_tab.dart) */}
      {showCreateModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/60 backdrop-blur-xs">
          <div className="w-full max-w-lg bg-white dark:bg-slate-900 rounded-xl shadow-2xl border border-slate-200 dark:border-slate-800 p-5 space-y-4">
            <div className="flex items-center justify-between pb-2 border-b border-slate-200 dark:border-slate-800">
              <div className="flex items-center gap-2">
                <Award className="w-4 h-4 text-teal-600 dark:text-teal-400" />
                <h3 className="text-sm font-bold text-slate-900 dark:text-white">
                  Créer un Nouveau Concours Blanc National
                </h3>
              </div>
              <button onClick={() => setShowCreateModal(false)} className="text-slate-400 hover:text-slate-600 cursor-pointer">
                <X className="w-4 h-4" />
              </button>
            </div>

            <form onSubmit={handleCreate} className="space-y-3 text-xs">
              <div>
                <label className="block font-semibold text-slate-700 dark:text-slate-300 mb-1">
                  Intitulé Officiel de l'Épreuve
                </label>
                <input
                  type="text"
                  required
                  value={title}
                  onChange={(e) => setTitle(e.target.value)}
                  className="w-full px-3 py-2 bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg text-slate-900 dark:text-white"
                />
              </div>

              <div>
                <label className="block font-semibold text-slate-700 dark:text-slate-300 mb-1">
                  Description Pédagogique
                </label>
                <textarea
                  rows={2}
                  value={description}
                  onChange={(e) => setDescription(e.target.value)}
                  className="w-full px-3 py-2 bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg text-slate-900 dark:text-white"
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block font-semibold text-slate-700 dark:text-slate-300 mb-1">
                    Cible
                  </label>
                  <select
                    value={targetType}
                    onChange={(e) => setTargetType(e.target.value as any)}
                    className="w-full px-3 py-2 bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg text-slate-900 dark:text-white"
                  >
                    <option value="residency">Concours Résidanat (National)</option>
                    <option value="externat">Examens Externat (Facultés)</option>
                  </select>
                </div>

                <div>
                  <label className="block font-semibold text-slate-700 dark:text-slate-300 mb-1">
                    Module / Spécialité
                  </label>
                  <input
                    type="text"
                    value={moduleName}
                    onChange={(e) => setModuleName(e.target.value)}
                    className="w-full px-3 py-2 bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg text-slate-900 dark:text-white"
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block font-semibold text-slate-700 dark:text-slate-300 mb-1">
                    Nombre de Questions (QCMs)
                  </label>
                  <input
                    type="number"
                    value={questionCount}
                    onChange={(e) => setQuestionCount(Number(e.target.value))}
                    className="w-full px-3 py-2 bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg text-slate-900 dark:text-white font-mono"
                  />
                </div>

                <div>
                  <label className="block font-semibold text-slate-700 dark:text-slate-300 mb-1">
                    Durée Allouée (Minutes)
                  </label>
                  <input
                    type="number"
                    value={durationMinutes}
                    onChange={(e) => setDurationMinutes(Number(e.target.value))}
                    className="w-full px-3 py-2 bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg text-slate-900 dark:text-white font-mono"
                  />
                </div>
              </div>

              <div className="pt-2 flex justify-end gap-2">
                <button
                  type="button"
                  onClick={() => setShowCreateModal(false)}
                  className="px-3 py-1.5 text-slate-500 hover:text-slate-800 cursor-pointer"
                >
                  Annuler
                </button>
                <button
                  type="submit"
                  className="px-4 py-2 bg-teal-600 hover:bg-teal-700 text-white rounded-lg font-semibold cursor-pointer shadow-xs"
                >
                  Programmer le Concours
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
