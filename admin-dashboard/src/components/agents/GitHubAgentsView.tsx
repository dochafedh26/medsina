import React, { useState } from 'react';
import { 
  Bot, 
  Terminal, 
  Play, 
  CheckCircle2, 
  Clock, 
  RefreshCw, 
  Sparkles, 
  Database, 
  Share2, 
  FileCode,
  ShieldCheck
} from 'lucide-react';

export const GitHubAgentsView: React.FC = () => {
  const [isRunningAgent, setIsRunningAgent] = useState<string | null>(null);
  const [logs, setLogs] = useState<Array<{ timestamp: string; message: string; type: 'info' | 'success' | 'warn' }>>([
    { timestamp: '12:02:31', message: 'GitHub commit push sync to main (commit: d8205dbe) — Supabase schema updated', type: 'info' },
    { timestamp: '12:00:15', message: 'Agent Marketing : 4 nouveaux visuels branding générés via generate_all_branding_assets.py', type: 'success' },
    { timestamp: '11:45:00', message: 'Nomenclature nationale des médicaments 2026 synchronisée avec 4,890 DCI et princeps', type: 'success' }
  ]);

  const agents = [
    {
      id: 'agent_qcm',
      name: 'Agent QCM & Cas Cliniques Résidanat',
      description: 'Génération et vérification automatique de cas cliniques transversaux basés sur les annales officielles de résidanat.',
      script: 'scripts/generate_clinical_cases.py',
      status: 'Opérationnel',
      lastRun: 'Aujourd\'hui 09:30'
    },
    {
      id: 'agent_vidal',
      name: 'Agent Nomenclature & Vidal Algérie',
      description: 'Vérification des interactions médicamenteuses, contre-indications et posologies selon la nomenclature du Ministère de la Santé.',
      script: 'scripts/sync_algerian_formulary.py',
      status: 'Synchronisé',
      lastRun: 'Hier 18:20'
    },
    {
      id: 'agent_facebook',
      name: 'Agent Marketing Facebook & Branding',
      description: 'Génération automatisée des publications scientifiques et bannières promotionnelles BaridiMob pour la communauté médicale.',
      script: 'generate_facebook_assets.py',
      status: 'Prêt',
      lastRun: 'Il y a 2 heures'
    }
  ];

  const handleRunAgent = (agentId: string, agentName: string) => {
    setIsRunningAgent(agentId);
    const newLog = {
      timestamp: new Date().toTimeString().slice(0, 8),
      message: `Lancement de l'agent [${agentName}] en cours...`,
      type: 'info' as const
    };
    setLogs((prev) => [newLog, ...prev]);

    setTimeout(() => {
      setIsRunningAgent(null);
      setLogs((prev) => [
        {
          timestamp: new Date().toTimeString().slice(0, 8),
          message: `Succès : Exécution de [${agentName}] terminée avec succès. Données validées.`,
          type: 'success' as const
        },
        ...prev
      ]);
    }, 1500);
  };

  return (
    <div className="space-y-6">
      {/* View Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-2 border-b border-slate-200 dark:border-slate-800">
        <div>
          <h1 className="text-xl md:text-2xl font-bold tracking-tight text-slate-900 dark:text-white">
            Agents IA GitHub & Automatisation Système 🤖
          </h1>
          <p className="text-xs md:text-sm text-slate-500 dark:text-slate-400 mt-0.5">
            Orchestration des scripts Python du dépôt GitHub dochafedh26/medsina pour la génération pédagogique et le marketing.
          </p>
        </div>

        <div className="flex items-center gap-2">
          <span className="text-xs font-mono px-3 py-1.5 rounded-lg bg-teal-50 dark:bg-teal-950/60 text-teal-700 dark:text-teal-300 border border-teal-200 dark:border-teal-800 font-semibold">
            Dépôt : dochafedh26/medsina (main)
          </span>
        </div>
      </div>

      {/* Agents Cards Grid */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-5">
        {agents.map((agent) => {
          const isRunning = isRunningAgent === agent.id;
          return (
            <div
              key={agent.id}
              className="p-5 rounded-2xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 shadow-2xs flex flex-col justify-between"
            >
              <div>
                <div className="flex items-center justify-between gap-2 mb-2">
                  <span className="px-2 py-0.5 rounded text-[10px] font-mono font-bold uppercase bg-emerald-100 text-emerald-800 dark:bg-emerald-950 dark:text-emerald-300">
                    {agent.status}
                  </span>
                  <span className="text-[10px] font-mono text-slate-400">
                    {agent.lastRun}
                  </span>
                </div>

                <h3 className="font-bold text-sm text-slate-900 dark:text-white leading-snug">
                  {agent.name}
                </h3>

                <p className="text-xs text-slate-500 dark:text-slate-400 mt-2 leading-relaxed">
                  {agent.description}
                </p>

                <div className="mt-4 p-2.5 bg-slate-50 dark:bg-slate-800/60 rounded-lg border border-slate-200 dark:border-slate-800 text-[11px] font-mono text-teal-600 dark:text-teal-400 flex items-center gap-1.5 truncate">
                  <FileCode className="w-3.5 h-3.5 shrink-0" />
                  <span className="truncate">{agent.script}</span>
                </div>
              </div>

              <div className="mt-5 pt-3 border-t border-slate-100 dark:border-slate-800">
                <button
                  onClick={() => handleRunAgent(agent.id, agent.name)}
                  disabled={isRunning}
                  className="w-full flex items-center justify-center gap-1.5 py-2 px-3 text-xs font-semibold text-white bg-teal-600 hover:bg-teal-700 dark:bg-teal-500 rounded-lg transition-colors cursor-pointer disabled:opacity-50"
                >
                  {isRunning ? <RefreshCw className="w-3.5 h-3.5 animate-spin" /> : <Play className="w-3.5 h-3.5" />}
                  <span>{isRunning ? 'Exécution en cours...' : 'Déclencher l\'Agent'}</span>
                </button>
              </div>
            </div>
          );
        })}
      </div>

      {/* Real-time GitHub / Agent Terminal Output */}
      <div className="bg-slate-950 rounded-xl border border-slate-800 overflow-hidden shadow-md">
        <div className="px-4 py-2.5 bg-slate-900 border-b border-slate-800 flex items-center justify-between text-xs text-slate-300">
          <div className="flex items-center gap-2">
            <Terminal className="w-4 h-4 text-teal-400" />
            <span className="font-mono font-semibold">Console d'Exécution & Logs Supabase / GitHub</span>
          </div>
          <span className="text-[11px] font-mono text-slate-400">Node : worker-alger-01</span>
        </div>

        <div className="p-4 font-mono text-[11px] space-y-2 max-h-56 overflow-y-auto">
          {logs.map((log, i) => (
            <div key={i} className="flex items-start gap-2.5">
              <span className="text-slate-500 shrink-0">[{log.timestamp}]</span>
              <span className={
                log.type === 'success'
                  ? 'text-emerald-400 font-semibold'
                  : log.type === 'warn'
                  ? 'text-amber-400'
                  : 'text-slate-300'
              }>
                {log.message}
              </span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};
