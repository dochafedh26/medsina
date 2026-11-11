import React, { useState, useEffect, useMemo } from 'react';
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
  ShieldCheck,
  Search,
  ExternalLink,
  Settings,
  AlertTriangle,
  XCircle,
  BookOpen,
  Activity,
  Lightbulb,
  FileText,
  GitBranch,
  Pill,
  FlaskConical,
  GraduationCap,
  MessageSquare,
  Radio,
  Award,
  Zap,
  Book,
  UploadCloud,
  PackageCheck,
  X,
  SlidersHorizontal
} from 'lucide-react';
import {
  GITHUB_AGENTS_CATALOG,
  GitHubAgentDef,
  GitHubWorkflowRun,
  AgentCategory,
  getGitHubToken,
  getGitHubRepo,
  saveGitHubToken,
  saveGitHubRepo,
  fetchGitHubWorkflowRuns,
  dispatchGitHubWorkflow,
  DEFAULT_REPO
} from '../../services/github';

const ICON_MAP: Record<string, React.FC<{ className?: string }>> = {
  BookOpen,
  Activity,
  Lightbulb,
  FileText,
  GitBranch,
  AlertTriangle,
  Pill,
  Clock,
  FlaskConical,
  Share2,
  GraduationCap,
  MessageSquare,
  Radio,
  Award,
  Zap,
  Book,
  UploadCloud,
  PackageCheck,
  Bot,
};

interface LogItem {
  timestamp: string;
  message: string;
  type: 'info' | 'success' | 'warn' | 'error';
}

export const GitHubAgentsView: React.FC = () => {
  const [selectedCategory, setSelectedCategory] = useState<AgentCategory>('all');
  const [searchQuery, setSearchQuery] = useState('');
  const [isRunningAgent, setIsRunningAgent] = useState<string | null>(null);
  const [isRefreshingRuns, setIsRefreshingRuns] = useState(false);
  const [workflowRuns, setWorkflowRuns] = useState<GitHubWorkflowRun[]>([]);
  const [hasToken, setHasToken] = useState<boolean>(false);
  const [currentRepo, setCurrentRepo] = useState<string>(DEFAULT_REPO);

  // Modal states
  const [activeParamAgent, setActiveParamAgent] = useState<GitHubAgentDef | null>(null);
  const [inputValues, setInputValues] = useState<Record<string, string>>({});
  const [isConfigModalOpen, setIsConfigModalOpen] = useState(false);
  const [tempPatToken, setTempPatToken] = useState('');
  const [tempRepo, setTempRepo] = useState('');
  const [configSaving, setConfigSaving] = useState(false);

  // Terminal Logs
  const [logs, setLogs] = useState<LogItem[]>([
    {
      timestamp: new Date().toTimeString().slice(0, 8),
      message: 'Console MedSina initialisée — Prêt pour l\'orchestration des 18 agents autonomes GitHub.',
      type: 'info',
    },
  ]);

  // Load initial GitHub status & recent runs
  const loadInitialData = async () => {
    const token = await getGitHubToken();
    const repo = await getGitHubRepo();
    setHasToken(!!token);
    setCurrentRepo(repo);

    if (token) {
      setIsRefreshingRuns(true);
      try {
        const runs = await fetchGitHubWorkflowRuns(40);
        setWorkflowRuns(runs);

        if (runs.length > 0) {
          const runLogs: LogItem[] = runs.slice(0, 4).map((r) => ({
            timestamp: new Date(r.createdAt).toTimeString().slice(0, 8),
            message: `[GitHub Run #${r.runNumber}] ${r.name} — Statut: ${r.status}${r.conclusion ? ` (${r.conclusion})` : ''}`,
            type: r.conclusion === 'success' ? 'success' : r.conclusion === 'failure' ? 'error' : 'info',
          }));
          setLogs((prev) => [...runLogs, ...prev]);
        }
      } catch (err) {
        console.warn('Could not fetch workflow runs:', err);
      } finally {
        setIsRefreshingRuns(false);
      }
    }
  };

  useEffect(() => {
    loadInitialData();
  }, []);

  const handleRefreshRuns = async () => {
    setIsRefreshingRuns(true);
    setLogs((prev) => [
      {
        timestamp: new Date().toTimeString().slice(0, 8),
        message: 'Interrogation de l\'API GitHub Actions pour synchronisation des derniers runs...',
        type: 'info',
      },
      ...prev,
    ]);

    const runs = await fetchGitHubWorkflowRuns(40);
    setWorkflowRuns(runs);
    setIsRefreshingRuns(false);

    setLogs((prev) => [
      {
        timestamp: new Date().toTimeString().slice(0, 8),
        message: `Synchronisation terminée : ${runs.length} exécutions récentes récupérées depuis GitHub.`,
        type: 'success',
      },
      ...prev,
    ]);
  };

  // Find latest run for an agent
  const getLatestRunForAgent = (agent: GitHubAgentDef) => {
    if (!workflowRuns.length) return null;
    return workflowRuns.find((r) => {
      if (r.workflowFileName && r.workflowFileName.toLowerCase() === agent.workflowFile.toLowerCase()) {
        return true;
      }
      return r.name.toLowerCase().includes(agent.shortTitle.toLowerCase()) ||
             r.name.toLowerCase().includes(agent.workflowFile.replace('.yml', '').replace('medsina_', '').toLowerCase());
    });
  };

  // Trigger an agent
  const handleTriggerClick = (agent: GitHubAgentDef) => {
    if (agent.inputs && agent.inputs.length > 0) {
      // Pre-fill default values
      const initial: Record<string, string> = {};
      agent.inputs.forEach((inp) => {
        if (inp.defaultValue) initial[inp.key] = inp.defaultValue;
      });
      setInputValues(initial);
      setActiveParamAgent(agent);
    } else {
      executeDispatch(agent, {});
    }
  };

  const executeDispatch = async (agent: GitHubAgentDef, inputs: Record<string, string>) => {
    setIsRunningAgent(agent.id);
    setActiveParamAgent(null);

    const ts = new Date().toTimeString().slice(0, 8);
    setLogs((prev) => [
      {
        timestamp: ts,
        message: `Déclenchement de l'agent [${agent.title}] (Workflow: ${agent.workflowFile})...`,
        type: 'info',
      },
      ...prev,
    ]);

    try {
      const res = await dispatchGitHubWorkflow(agent.workflowFile, inputs);

      if (res.success) {
        setLogs((prev) => [
          {
            timestamp: new Date().toTimeString().slice(0, 8),
            message: `✅ Succès GitHub (HTTP 204) : L'agent [${agent.title}] a été planifié sur le runner GitHub Actions !`,
            type: 'success',
          },
          ...prev,
        ]);

        // Auto-refresh runs after 3 seconds to show new run in progress
        setTimeout(() => {
          fetchGitHubWorkflowRuns(30).then((runs) => {
            if (runs.length) setWorkflowRuns(runs);
          });
        }, 3500);
      } else {
        setLogs((prev) => [
          {
            timestamp: new Date().toTimeString().slice(0, 8),
            message: `⚠️ Résultat déclenchement [${agent.title}] : ${res.message}`,
            type: 'warn',
          },
          ...prev,
        ]);
      }
    } catch (err: any) {
      setLogs((prev) => [
        {
          timestamp: new Date().toTimeString().slice(0, 8),
          message: `❌ Erreur lors du déclenchement de [${agent.title}] : ${err?.message || err}`,
          type: 'error',
        },
        ...prev,
      ]);
    } finally {
      setIsRunningAgent(null);
    }
  };

  const handleOpenConfigModal = async () => {
    const token = await getGitHubToken();
    const repo = await getGitHubRepo();
    setTempPatToken(token || '');
    setTempRepo(repo || DEFAULT_REPO);
    setIsConfigModalOpen(true);
  };

  const handleSaveConfig = async () => {
    setConfigSaving(true);
    await saveGitHubToken(tempPatToken);
    await saveGitHubRepo(tempRepo);
    setHasToken(!!tempPatToken.trim());
    setCurrentRepo(tempRepo.trim() || DEFAULT_REPO);
    setConfigSaving(false);
    setIsConfigModalOpen(false);

    setLogs((prev) => [
      {
        timestamp: new Date().toTimeString().slice(0, 8),
        message: 'Configuration GitHub mise à jour avec succès dans Supabase admin_system_settings.',
        type: 'success',
      },
      ...prev,
    ]);

    handleRefreshRuns();
  };

  // Filtered agents
  const filteredAgents = useMemo(() => {
    return GITHUB_AGENTS_CATALOG.filter((agent) => {
      const matchesCategory = selectedCategory === 'all' || agent.category === selectedCategory;
      const q = searchQuery.toLowerCase().trim();
      const matchesSearch = 
        !q ||
        agent.title.toLowerCase().includes(q) ||
        agent.description.toLowerCase().includes(q) ||
        agent.workflowFile.toLowerCase().includes(q) ||
        agent.script.toLowerCase().includes(q) ||
        agent.categoryLabel.toLowerCase().includes(q);

      return matchesCategory && matchesSearch;
    });
  }, [selectedCategory, searchQuery]);

  // Statistics
  const categoryCounts = useMemo(() => {
    const counts = {
      all: GITHUB_AGENTS_CATALOG.length,
      pedagogy: 0,
      clinical: 0,
      marketing: 0,
      resources: 0,
      system: 0,
    };
    GITHUB_AGENTS_CATALOG.forEach((a) => {
      counts[a.category]++;
    });
    return counts;
  }, []);

  return (
    <div className="space-y-6">
      {/* View Header */}
      <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-4 pb-4 border-b border-slate-200 dark:border-slate-800">
        <div>
          <div className="flex items-center gap-2.5">
            <div className="p-2 bg-teal-500/10 text-teal-600 dark:text-teal-400 rounded-xl border border-teal-500/20">
              <Bot className="w-6 h-6" />
            </div>
            <div>
              <h1 className="text-xl md:text-2xl font-bold tracking-tight text-slate-900 dark:text-white flex items-center gap-2">
                Tableau de Bord des Agents IA GitHub 🤖
                <span className="text-xs px-2.5 py-0.5 rounded-full font-semibold bg-emerald-100 text-emerald-800 dark:bg-emerald-950 dark:text-emerald-300 border border-emerald-300 dark:border-emerald-800">
                  {GITHUB_AGENTS_CATALOG.length} Agents Actifs
                </span>
              </h1>
              <p className="text-xs md:text-sm text-slate-500 dark:text-slate-400 mt-0.5">
                Orchestration complète des 18 scripts et workflows du dépôt GitHub {currentRepo} pour la pédagogie médicale, les urgences et la diffusion.
              </p>
            </div>
          </div>
        </div>

        {/* Action Controls */}
        <div className="flex flex-wrap items-center gap-2">
          <button
            onClick={handleRefreshRuns}
            disabled={isRefreshingRuns}
            className="flex items-center gap-1.5 px-3 py-1.5 text-xs font-semibold text-slate-700 dark:text-slate-200 bg-white dark:bg-slate-800 border border-slate-300 dark:border-slate-700 hover:bg-slate-50 dark:hover:bg-slate-750 rounded-lg transition-colors cursor-pointer disabled:opacity-50"
            title="Rafraîchir les statuts des runs GitHub Actions"
          >
            <RefreshCw className={`w-3.5 h-3.5 ${isRefreshingRuns ? 'animate-spin text-teal-500' : ''}`} />
            <span>Synchroniser Statuts</span>
          </button>

          <button
            onClick={handleOpenConfigModal}
            className="flex items-center gap-1.5 px-3 py-1.5 text-xs font-semibold text-slate-700 dark:text-slate-200 bg-white dark:bg-slate-800 border border-slate-300 dark:border-slate-700 hover:bg-slate-50 dark:hover:bg-slate-750 rounded-lg transition-colors cursor-pointer"
            title="Configurer le Personal Access Token GitHub et le Dépôt"
          >
            <Settings className="w-3.5 h-3.5 text-slate-500" />
            <span>Token GitHub</span>
            {hasToken ? (
              <span className="w-2 h-2 rounded-full bg-emerald-500" title="Token PAT configuré" />
            ) : (
              <span className="w-2 h-2 rounded-full bg-amber-500" title="Token PAT manquant" />
            )}
          </button>

          <a
            href={`https://github.com/${currentRepo}/actions`}
            target="_blank"
            rel="noopener noreferrer"
            className="flex items-center gap-1.5 px-3 py-1.5 text-xs font-semibold text-teal-700 dark:text-teal-300 bg-teal-50 dark:bg-teal-950/60 border border-teal-200 dark:border-teal-800 hover:bg-teal-100 rounded-lg transition-colors"
          >
            <ExternalLink className="w-3.5 h-3.5" />
            <span>Actions GitHub ↗</span>
          </a>
        </div>
      </div>

      {/* Metrics Cards Bar */}
      <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-3">
        <div className="p-3.5 rounded-xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 shadow-2xs">
          <div className="text-[11px] font-medium text-slate-500 dark:text-slate-400">Total Agents</div>
          <div className="text-xl font-bold text-slate-900 dark:text-white mt-1 flex items-baseline gap-1.5">
            {GITHUB_AGENTS_CATALOG.length}
            <span className="text-[10px] text-emerald-600 dark:text-emerald-400 font-semibold">100% Opérationnels</span>
          </div>
        </div>

        <div className="p-3.5 rounded-xl border border-blue-200/60 dark:border-blue-900/40 bg-blue-50/40 dark:bg-blue-950/20 shadow-2xs">
          <div className="text-[11px] font-medium text-blue-700 dark:text-blue-300">Pédagogie & Résidanat</div>
          <div className="text-xl font-bold text-blue-900 dark:text-blue-200 mt-1">
            {categoryCounts.pedagogy} <span className="text-xs font-normal text-blue-600 dark:text-blue-400">agents</span>
          </div>
        </div>

        <div className="p-3.5 rounded-xl border border-rose-200/60 dark:border-rose-900/40 bg-rose-50/40 dark:bg-rose-950/20 shadow-2xs">
          <div className="text-[11px] font-medium text-rose-700 dark:text-rose-300">Clinique & Urgences</div>
          <div className="text-xl font-bold text-rose-900 dark:text-rose-200 mt-1">
            {categoryCounts.clinical} <span className="text-xs font-normal text-rose-600 dark:text-rose-400">agents</span>
          </div>
        </div>

        <div className="p-3.5 rounded-xl border border-sky-200/60 dark:border-sky-900/40 bg-sky-50/40 dark:bg-sky-950/20 shadow-2xs">
          <div className="text-[11px] font-medium text-sky-700 dark:text-sky-300">Marketing & Réseaux</div>
          <div className="text-xl font-bold text-sky-900 dark:text-sky-200 mt-1">
            {categoryCounts.marketing} <span className="text-xs font-normal text-sky-600 dark:text-sky-400">agents</span>
          </div>
        </div>

        <div className="p-3.5 rounded-xl border border-amber-200/60 dark:border-amber-900/40 bg-amber-50/40 dark:bg-amber-950/20 shadow-2xs">
          <div className="text-[11px] font-medium text-amber-700 dark:text-amber-300">Veille & Ressources</div>
          <div className="text-xl font-bold text-amber-900 dark:text-amber-200 mt-1">
            {categoryCounts.resources} <span className="text-xs font-normal text-amber-600 dark:text-amber-400">agents</span>
          </div>
        </div>

        <div className="p-3.5 rounded-xl border border-pink-200/60 dark:border-pink-900/40 bg-pink-50/40 dark:bg-pink-950/20 shadow-2xs">
          <div className="text-[11px] font-medium text-pink-700 dark:text-pink-300">Système & Release</div>
          <div className="text-xl font-bold text-pink-900 dark:text-pink-200 mt-1">
            {categoryCounts.system} <span className="text-xs font-normal text-pink-600 dark:text-pink-400">agents</span>
          </div>
        </div>
      </div>

      {/* Filter and Search Bar */}
      <div className="flex flex-col md:flex-row items-stretch md:items-center justify-between gap-3 p-2 bg-slate-50 dark:bg-slate-900/60 rounded-xl border border-slate-200 dark:border-slate-800">
        {/* Category Pills */}
        <div className="flex flex-wrap items-center gap-1.5 overflow-x-auto no-scrollbar">
          {[
            { id: 'all' as AgentCategory, label: `Tous (${categoryCounts.all})` },
            { id: 'pedagogy' as AgentCategory, label: `Pédagogie (${categoryCounts.pedagogy})` },
            { id: 'clinical' as AgentCategory, label: `Urgences & DCI (${categoryCounts.clinical})` },
            { id: 'marketing' as AgentCategory, label: `Marketing (${categoryCounts.marketing})` },
            { id: 'resources' as AgentCategory, label: `Veille Blida (${categoryCounts.resources})` },
            { id: 'system' as AgentCategory, label: `Système (${categoryCounts.system})` },
          ].map((cat) => (
            <button
              key={cat.id}
              onClick={() => setSelectedCategory(cat.id)}
              className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-all cursor-pointer ${
                selectedCategory === cat.id
                  ? 'bg-teal-600 text-white shadow-xs'
                  : 'bg-white dark:bg-slate-800 text-slate-600 dark:text-slate-300 border border-slate-200 dark:border-slate-700 hover:bg-slate-100 dark:hover:bg-slate-750'
              }`}
            >
              {cat.label}
            </button>
          ))}
        </div>

        {/* Search input */}
        <div className="relative min-w-[240px] md:w-72">
          <Search className="w-4 h-4 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Rechercher par nom, script, workflow..."
            className="w-full pl-9 pr-3 py-1.5 text-xs rounded-lg border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-900 dark:text-white placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-teal-500"
          />
          {searchQuery && (
            <button
              onClick={() => setSearchQuery('')}
              className="absolute right-2.5 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600 dark:hover:text-white"
            >
              <X className="w-3.5 h-3.5" />
            </button>
          )}
        </div>
      </div>

      {/* Agents Grid (18 Cards) */}
      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-5">
        {filteredAgents.map((agent) => {
          const isRunning = isRunningAgent === agent.id;
          const latestRun = getLatestRunForAgent(agent);
          const AgentIcon = ICON_MAP[agent.iconName] || Bot;

          let statusBadge = (
            <span className="px-2 py-0.5 rounded-full text-[10px] font-mono font-bold uppercase bg-emerald-100 text-emerald-800 dark:bg-emerald-950 dark:text-emerald-300 border border-emerald-200 dark:border-emerald-800 flex items-center gap-1">
              <CheckCircle2 className="w-3 h-3 text-emerald-600 dark:text-emerald-400" />
              Opérationnel
            </span>
          );

          if (latestRun) {
            if (latestRun.status === 'in_progress' || latestRun.status === 'queued') {
              statusBadge = (
                <span className="px-2 py-0.5 rounded-full text-[10px] font-mono font-bold uppercase bg-amber-100 text-amber-800 dark:bg-amber-950 dark:text-amber-300 border border-amber-300 dark:border-amber-700 flex items-center gap-1 animate-pulse">
                  <RefreshCw className="w-3 h-3 animate-spin text-amber-600" />
                  En cours
                </span>
              );
            } else if (latestRun.conclusion === 'failure') {
              statusBadge = (
                <span className="px-2 py-0.5 rounded-full text-[10px] font-mono font-bold uppercase bg-rose-100 text-rose-800 dark:bg-rose-950 dark:text-rose-300 border border-rose-300 dark:border-rose-800 flex items-center gap-1">
                  <XCircle className="w-3 h-3 text-rose-600" />
                  Échec récent
                </span>
              );
            }
          }

          return (
            <div
              key={agent.id}
              className="p-5 rounded-2xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 shadow-2xs hover:shadow-md transition-shadow flex flex-col justify-between group"
            >
              <div>
                {/* Header row: Category & Status */}
                <div className="flex items-center justify-between gap-2 mb-3">
                  <span className={`px-2.5 py-0.5 rounded-md text-[10px] font-semibold border ${agent.badgeColor}`}>
                    {agent.categoryLabel}
                  </span>
                  {statusBadge}
                </div>

                {/* Title & Icon */}
                <div className="flex items-start gap-3">
                  <div
                    className="p-2.5 rounded-xl shrink-0 mt-0.5"
                    style={{ backgroundColor: `${agent.accentColor}18`, color: agent.accentColor }}
                  >
                    <AgentIcon className="w-5 h-5" />
                  </div>
                  <div>
                    <h3 className="font-bold text-sm text-slate-900 dark:text-white leading-snug group-hover:text-teal-600 dark:group-hover:text-teal-400 transition-colors">
                      {agent.title}
                    </h3>
                    <div className="flex items-center gap-1.5 text-[11px] text-slate-400 dark:text-slate-500 mt-1">
                      <Clock className="w-3 h-3" />
                      <span>{agent.defaultCadence}</span>
                    </div>
                  </div>
                </div>

                {/* Description */}
                <p className="text-xs text-slate-600 dark:text-slate-400 mt-3 leading-relaxed min-h-[44px]">
                  {agent.description}
                </p>

                {/* Technical Paths & Links */}
                <div className="mt-4 space-y-1.5 pt-3 border-t border-slate-100 dark:border-slate-800/80">
                  <div className="flex items-center justify-between text-[11px] font-mono text-slate-500 dark:text-slate-400">
                    <span className="flex items-center gap-1 text-slate-400">
                      <FileCode className="w-3 h-3" /> Script:
                    </span>
                    <span className="truncate max-w-[200px] text-teal-600 dark:text-teal-400 font-semibold" title={agent.script}>
                      {agent.script.split('/').pop()}
                    </span>
                  </div>

                  <div className="flex items-center justify-between text-[11px] font-mono text-slate-500 dark:text-slate-400">
                    <span className="flex items-center gap-1 text-slate-400">
                      <GitBranch className="w-3 h-3" /> Workflow:
                    </span>
                    <a
                      href={`https://github.com/${currentRepo}/blob/main/.github/workflows/${agent.workflowFile}`}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="text-indigo-600 dark:text-indigo-400 hover:underline flex items-center gap-1 truncate max-w-[200px]"
                      title="Ouvrir le workflow YAML sur GitHub"
                    >
                      <span className="truncate">{agent.workflowFile}</span>
                      <ExternalLink className="w-2.5 h-2.5 shrink-0" />
                    </a>
                  </div>
                </div>
              </div>

              {/* Action Buttons */}
              <div className="mt-5 pt-3 border-t border-slate-100 dark:border-slate-800 flex items-center gap-2">
                <button
                  onClick={() => handleTriggerClick(agent)}
                  disabled={isRunning}
                  className="flex-1 flex items-center justify-center gap-1.5 py-2 px-3 text-xs font-semibold text-white bg-teal-600 hover:bg-teal-700 dark:bg-teal-500 dark:hover:bg-teal-600 rounded-lg transition-colors cursor-pointer disabled:opacity-50 shadow-xs"
                >
                  {isRunning ? (
                    <>
                      <RefreshCw className="w-3.5 h-3.5 animate-spin" />
                      <span>Déclenchement...</span>
                    </>
                  ) : (
                    <>
                      <Play className="w-3.5 h-3.5 fill-current" />
                      <span>Déclencher l'Agent</span>
                    </>
                  )}
                </button>

                {agent.inputs && agent.inputs.length > 0 && (
                  <button
                    onClick={() => {
                      const initial: Record<string, string> = {};
                      agent.inputs?.forEach((inp) => {
                        if (inp.defaultValue) initial[inp.key] = inp.defaultValue;
                      });
                      setInputValues(initial);
                      setActiveParamAgent(agent);
                    }}
                    title="Paramétrer les entrées de l'agent"
                    className="p-2 text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 rounded-lg border border-slate-200 dark:border-slate-700 transition-colors cursor-pointer"
                  >
                    <SlidersHorizontal className="w-3.5 h-3.5" />
                  </button>
                )}
              </div>
            </div>
          );
        })}
      </div>

      {/* Real-time GitHub / Agent Terminal Output */}
      <div className="bg-slate-950 rounded-xl border border-slate-800 overflow-hidden shadow-lg mt-6">
        <div className="px-4 py-3 bg-slate-900 border-b border-slate-800 flex items-center justify-between text-xs text-slate-300">
          <div className="flex items-center gap-2">
            <Terminal className="w-4 h-4 text-teal-400" />
            <span className="font-mono font-bold text-white">Console d'Orchestration des 18 Agents IA MedSina</span>
            <span className="px-2 py-0.5 rounded text-[10px] font-mono bg-teal-950 text-teal-400 border border-teal-800">
              {currentRepo}
            </span>
          </div>

          <div className="flex items-center gap-3">
            <span className="text-[11px] font-mono text-slate-400 hidden sm:inline">
              Connexion Supabase : <span className="text-emerald-400 font-semibold">Active</span>
            </span>
            <button
              onClick={() => setLogs([])}
              className="text-[10px] font-mono text-slate-400 hover:text-white px-2 py-0.5 rounded hover:bg-slate-800"
            >
              Effacer logs
            </button>
          </div>
        </div>

        <div className="p-4 font-mono text-[11px] space-y-1.5 max-h-64 overflow-y-auto">
          {logs.length === 0 ? (
            <div className="text-slate-500 italic">Aucun log récent. Déclenchez un agent pour afficher la télémétrie.</div>
          ) : (
            logs.map((log, i) => (
              <div key={i} className="flex items-start gap-2.5 leading-relaxed">
                <span className="text-slate-500 shrink-0 select-none">[{log.timestamp}]</span>
                <span
                  className={
                    log.type === 'success'
                      ? 'text-emerald-400 font-medium'
                      : log.type === 'warn'
                      ? 'text-amber-400'
                      : log.type === 'error'
                      ? 'text-rose-400 font-semibold'
                      : 'text-slate-300'
                  }
                >
                  {log.message}
                </span>
              </div>
            ))
          )}
        </div>
      </div>

      {/* Modal: Parameter Inputs */}
      {activeParamAgent && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/70 backdrop-blur-xs">
          <div className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200 dark:border-slate-800 shadow-2xl max-w-md w-full p-6 animate-in fade-in zoom-in-95 duration-150">
            <div className="flex items-start justify-between gap-4 pb-3 border-b border-slate-100 dark:border-slate-800">
              <div>
                <h3 className="font-bold text-base text-slate-900 dark:text-white">
                  Paramètres de l'Agent
                </h3>
                <p className="text-xs text-slate-500 dark:text-slate-400 mt-0.5 font-mono">
                  {activeParamAgent.workflowFile}
                </p>
              </div>
              <button
                onClick={() => setActiveParamAgent(null)}
                className="text-slate-400 hover:text-slate-600 dark:hover:text-white p-1 rounded-lg"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="mt-4 space-y-3.5">
              <p className="text-xs text-slate-600 dark:text-slate-300">
                {activeParamAgent.description}
              </p>

              {activeParamAgent.inputs?.map((input) => (
                <div key={input.key} className="space-y-1">
                  <label className="block text-xs font-semibold text-slate-700 dark:text-slate-300">
                    {input.label}
                  </label>

                  {input.type === 'select' && input.options ? (
                    <select
                      value={inputValues[input.key] || input.defaultValue || ''}
                      onChange={(e) => setInputValues({ ...inputValues, [input.key]: e.target.value })}
                      className="w-full px-3 py-2 text-xs rounded-lg border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-teal-500"
                    >
                      {input.options.map((opt) => (
                        <option key={opt} value={opt}>
                          {opt}
                        </option>
                      ))}
                    </select>
                  ) : (
                    <input
                      type="text"
                      value={inputValues[input.key] || ''}
                      onChange={(e) => setInputValues({ ...inputValues, [input.key]: e.target.value })}
                      placeholder={input.placeholder || ''}
                      className="w-full px-3 py-2 text-xs rounded-lg border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-teal-500"
                    />
                  )}

                  {input.helpText && (
                    <p className="text-[11px] text-slate-400">{input.helpText}</p>
                  )}
                </div>
              ))}
            </div>

            <div className="mt-6 flex items-center justify-end gap-2 pt-3 border-t border-slate-100 dark:border-slate-800">
              <button
                onClick={() => setActiveParamAgent(null)}
                className="px-3.5 py-2 text-xs font-semibold text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 rounded-lg transition-colors cursor-pointer"
              >
                Annuler
              </button>
              <button
                onClick={() => executeDispatch(activeParamAgent, inputValues)}
                className="flex items-center gap-1.5 px-4 py-2 text-xs font-semibold text-white bg-teal-600 hover:bg-teal-700 rounded-lg transition-colors cursor-pointer shadow-xs"
              >
                <Play className="w-3.5 h-3.5 fill-current" />
                <span>Lancer l'Agent sur GitHub</span>
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Modal: GitHub Token & Repo Configuration */}
      {isConfigModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/70 backdrop-blur-xs">
          <div className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200 dark:border-slate-800 shadow-2xl max-w-md w-full p-6 animate-in fade-in zoom-in-95 duration-150">
            <div className="flex items-start justify-between gap-4 pb-3 border-b border-slate-100 dark:border-slate-800">
              <div className="flex items-center gap-2">
                <ShieldCheck className="w-5 h-5 text-teal-500" />
                <h3 className="font-bold text-base text-slate-900 dark:text-white">
                  Configuration GitHub Actions
                </h3>
              </div>
              <button
                onClick={() => setIsConfigModalOpen(false)}
                className="text-slate-400 hover:text-slate-600 dark:hover:text-white p-1 rounded-lg"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="mt-4 space-y-4">
              <p className="text-xs text-slate-500 dark:text-slate-400 leading-relaxed">
                Le jeton PAT permet au Tableau de Bord de déclencher les workflows d'automatisation via l'API GitHub et de synchroniser les statuts des 18 agents. Ce token est sauvegardé de manière chiffrée dans <code className="text-teal-600 dark:text-teal-400 font-mono text-[11px]">admin_system_settings</code>.
              </p>

              <div>
                <label className="block text-xs font-semibold text-slate-700 dark:text-slate-300 mb-1">
                  GitHub Personal Access Token (PAT)
                </label>
                <input
                  type="password"
                  value={tempPatToken}
                  onChange={(e) => setTempPatToken(e.target.value)}
                  placeholder="ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
                  className="w-full px-3 py-2 text-xs font-mono rounded-lg border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-teal-500"
                />
                <p className="text-[11px] text-slate-400 mt-1">
                  Permission requise : <code className="font-mono text-teal-600 dark:text-teal-400">actions:write</code> et <code className="font-mono text-teal-600 dark:text-teal-400">repo</code>.
                </p>
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-700 dark:text-slate-300 mb-1">
                  Dépôt GitHub Cible
                </label>
                <input
                  type="text"
                  value={tempRepo}
                  onChange={(e) => setTempRepo(e.target.value)}
                  placeholder="dochafedh26/medsina"
                  className="w-full px-3 py-2 text-xs font-mono rounded-lg border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-teal-500"
                />
              </div>
            </div>

            <div className="mt-6 flex items-center justify-end gap-2 pt-3 border-t border-slate-100 dark:border-slate-800">
              <button
                onClick={() => setIsConfigModalOpen(false)}
                className="px-3.5 py-2 text-xs font-semibold text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 rounded-lg transition-colors cursor-pointer"
              >
                Annuler
              </button>
              <button
                onClick={handleSaveConfig}
                disabled={configSaving}
                className="flex items-center gap-1.5 px-4 py-2 text-xs font-semibold text-white bg-teal-600 hover:bg-teal-700 rounded-lg transition-colors cursor-pointer shadow-xs disabled:opacity-50"
              >
                {configSaving ? <RefreshCw className="w-3.5 h-3.5 animate-spin" /> : <CheckCircle2 className="w-3.5 h-3.5" />}
                <span>Enregistrer</span>
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
