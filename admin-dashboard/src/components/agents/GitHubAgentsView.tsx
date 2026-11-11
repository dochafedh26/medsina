import React, { useState, useEffect, useMemo, useCallback } from 'react';
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
  SlidersHorizontal,
  Check,
  CheckCheck,
  Inbox,
  Send,
  Eye,
  ShieldAlert,
  FileCheck
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
import {
  DiscoveredBlidaResource,
  fetchDiscoveredBlidaResources,
  updateDiscoveredBlidaResourceStatus,
  updateDiscoveredBlidaResourcesBatch,
  getBlidaScannerSources,
  saveBlidaScannerSources,
  DEFAULT_BLIDA_SCANNER_SOURCES
} from '../../services/supabase';

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

type MainTab = 'validation' | 'catalog' | 'facebook' | 'promo' | 'logs';

export const GitHubAgentsView: React.FC = () => {
  // Navigation
  const [activeTab, setActiveTab] = useState<MainTab>('validation');

  // GitHub & Token status
  const [hasToken, setHasToken] = useState<boolean>(false);
  const [currentRepo, setCurrentRepo] = useState<string>(DEFAULT_REPO);
  const [workflowRuns, setWorkflowRuns] = useState<GitHubWorkflowRun[]>([]);
  const [isRefreshingRuns, setIsRefreshingRuns] = useState(false);
  const [isRunningAgent, setIsRunningAgent] = useState<string | null>(null);

  // Catalog filtering & searching
  const [selectedCategory, setSelectedCategory] = useState<AgentCategory>('all');
  const [searchQuery, setSearchQuery] = useState('');

  // Modals for Agent Parameters & Config
  const [activeParamAgent, setActiveParamAgent] = useState<GitHubAgentDef | null>(null);
  const [inputValues, setInputValues] = useState<Record<string, string>>({});
  const [isConfigModalOpen, setIsConfigModalOpen] = useState(false);
  const [tempPatToken, setTempPatToken] = useState('');
  const [tempRepo, setTempRepo] = useState('');
  const [configSaving, setConfigSaving] = useState(false);

  // --- BLIDA VALIDATION QUEUE STATES ---
  const [discoveredResources, setDiscoveredResources] = useState<DiscoveredBlidaResource[]>([]);
  const [isLoadingBlidaQueue, setIsLoadingBlidaQueue] = useState(false);
  const [blidaQueueFilterStatus, setBlidaQueueFilterStatus] = useState<'pending' | 'approved' | 'rejected' | 'all'>('pending');
  const [selectedBlidaResourceIds, setSelectedBlidaResourceIds] = useState<string[]>([]);
  const [isProcessingBatchBlida, setIsProcessingBatchBlida] = useState(false);
  const [isScanningBlida, setIsScanningBlida] = useState(false);

  // Sources config modal
  const [isSourcesModalOpen, setIsSourcesModalOpen] = useState(false);
  const [sourcesConfigText, setSourcesConfigText] = useState('');
  const [isSavingSources, setIsSavingSources] = useState(false);
  const [sourcesError, setSourcesError] = useState<string | null>(null);

  // --- FACEBOOK PUBLISHER STATES ---
  const [isFacebookModalOpen, setIsFacebookModalOpen] = useState(false);
  const [fbTopic, setFbTopic] = useState('');
  const [fbType, setFbType] = useState('auto');
  const [fbScreenshot, setFbScreenshot] = useState('');
  const [fbMockupType, setFbMockupType] = useState('auto');
  const [isTriggeringFacebook, setIsTriggeringFacebook] = useState(false);

  // --- PROMO HUNTER STATES ---
  const [isPromoModalOpen, setIsPromoModalOpen] = useState(false);
  const [promoTarget, setPromoTarget] = useState<'telegram' | 'facebook' | 'all'>('telegram');
  const [promoMaxReplies, setPromoMaxReplies] = useState<number>(2);
  const [isTriggeringPromo, setIsTriggeringPromo] = useState(false);

  // Terminal Logs
  const [logs, setLogs] = useState<LogItem[]>([
    {
      timestamp: new Date().toTimeString().slice(0, 8),
      message: 'Console MedSina initialisée — Prêt pour l\'orchestration des agents IA GitHub et la validation des ressources.',
      type: 'info',
    },
  ]);

  const addLog = useCallback((message: string, type: 'info' | 'success' | 'warn' | 'error' = 'info') => {
    setLogs((prev) => [
      {
        timestamp: new Date().toTimeString().slice(0, 8),
        message,
        type,
      },
      ...prev,
    ]);
  }, []);

  // Format relative timestamp
  const formatTimeAgo = (dateStr: string) => {
    try {
      const date = new Date(dateStr);
      if (isNaN(date.getTime())) return dateStr;
      const now = new Date();
      const diffMs = now.getTime() - date.getTime();
      const diffMins = Math.floor(diffMs / (1000 * 60));
      const diffHours = Math.floor(diffMs / (1000 * 60 * 60));
      const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));

      if (diffMins < 1) return 'À l\'instant';
      if (diffMins < 60) return `Il y a ${diffMins} min`;
      if (diffHours < 24) return `Il y a ${diffHours}h`;
      if (diffDays < 7) return `Il y a ${diffDays}j`;
      return date.toLocaleDateString('fr-FR', { day: '2-digit', month: '2-digit', year: 'numeric' });
    } catch {
      return dateStr;
    }
  };

  // Load Blida Validation Queue
  const loadBlidaQueue = useCallback(async (statusOverride?: 'pending' | 'approved' | 'rejected' | 'all') => {
    const status = statusOverride || blidaQueueFilterStatus;
    setIsLoadingBlidaQueue(true);
    try {
      const items = await fetchDiscoveredBlidaResources(status);
      setDiscoveredResources(items);
      setSelectedBlidaResourceIds([]);
    } catch (err: any) {
      console.error('Error loading blida queue:', err);
      addLog(`Erreur lors du chargement de la file Blida : ${err?.message || err}`, 'error');
    } finally {
      setIsLoadingBlidaQueue(false);
    }
  }, [blidaQueueFilterStatus, addLog]);

  // Load initial GitHub status & recent runs
  const loadInitialData = async () => {
    const token = await getGitHubToken();
    const repo = await getGitHubRepo();
    setHasToken(!!token);
    setCurrentRepo(repo);

    // Load queue resources
    loadBlidaQueue();

    if (token) {
      setIsRefreshingRuns(true);
      try {
        const runs = await fetchGitHubWorkflowRuns(40);
        setWorkflowRuns(runs);

        if (runs.length > 0) {
          const runLogs: LogItem[] = runs.slice(0, 3).map((r) => ({
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
    addLog('Interrogation de l\'API GitHub Actions pour synchronisation des derniers runs...', 'info');

    const runs = await fetchGitHubWorkflowRuns(40);
    setWorkflowRuns(runs);
    setIsRefreshingRuns(false);
    addLog(`Synchronisation terminée : ${runs.length} exécutions récentes récupérées depuis GitHub.`, 'success');
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

  // Trigger an agent dispatch
  const executeDispatch = async (agent: GitHubAgentDef, inputs: Record<string, string>) => {
    setIsRunningAgent(agent.id);
    setActiveParamAgent(null);

    addLog(`Déclenchement de l'agent [${agent.title}] (Workflow: ${agent.workflowFile})...`, 'info');

    try {
      const res = await dispatchGitHubWorkflow(agent.workflowFile, inputs);

      if (res.success) {
        addLog(`✅ Succès GitHub (HTTP 204) : L'agent [${agent.title}] a été planifié sur le runner GitHub Actions !`, 'success');

        // Auto-refresh runs after 3.5 seconds
        setTimeout(() => {
          fetchGitHubWorkflowRuns(30).then((runs) => {
            if (runs.length) setWorkflowRuns(runs);
          });
        }, 3500);
      } else {
        addLog(`⚠️ Résultat déclenchement [${agent.title}] : ${res.message}`, 'warn');
      }
    } catch (err: any) {
      addLog(`❌ Erreur lors du déclenchement de [${agent.title}] : ${err?.message || err}`, 'error');
    } finally {
      setIsRunningAgent(null);
    }
  };

  const handleTriggerClick = (agent: GitHubAgentDef) => {
    if (agent.inputs && agent.inputs.length > 0) {
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

  // --- BLIDA QUEUE ACTIONS ---

  const handleFilterChange = (status: 'pending' | 'approved' | 'rejected' | 'all') => {
    setBlidaQueueFilterStatus(status);
    loadBlidaQueue(status);
  };

  const handleToggleSelectAll = () => {
    if (selectedBlidaResourceIds.length === discoveredResources.length) {
      setSelectedBlidaResourceIds([]);
    } else {
      setSelectedBlidaResourceIds(discoveredResources.map((r) => r.id));
    }
  };

  const handleToggleSelectItem = (id: string) => {
    setSelectedBlidaResourceIds((prev) => 
      prev.includes(id) ? prev.filter((item) => item !== id) : [...prev, id]
    );
  };

  const handleSingleStatusUpdate = async (resource: DiscoveredBlidaResource, newStatus: 'approved' | 'rejected') => {
    const actionLabel = newStatus === 'approved' ? 'Approbation' : 'Rejet';
    addLog(`${actionLabel} de la ressource "${resource.title}"...`, 'info');

    const success = await updateDiscoveredBlidaResourceStatus(resource.id, newStatus);
    if (success) {
      addLog(`✅ Ressource "${resource.title}" marquée comme ${newStatus === 'approved' ? 'Approuvée' : 'Rejetée'}.`, 'success');
      loadBlidaQueue();
    } else {
      addLog(`⚠️ Échec de mise à jour pour "${resource.title}".`, 'warn');
    }
  };

  const handleBatchStatusUpdate = async (newStatus: 'approved' | 'rejected') => {
    if (selectedBlidaResourceIds.length === 0) return;
    setIsProcessingBatchBlida(true);
    const count = selectedBlidaResourceIds.length;
    addLog(`Traitement par lot de ${count} ressource(s) -> ${newStatus}...`, 'info');

    try {
      const affected = await updateDiscoveredBlidaResourcesBatch(selectedBlidaResourceIds, newStatus);
      addLog(`✅ ${affected} ressource(s) validée(s) comme ${newStatus === 'approved' ? 'Approuvée(s)' : 'Rejetée(s)'} sur Supabase Cloud !`, 'success');
      await loadBlidaQueue();
    } catch (err: any) {
      addLog(`❌ Erreur lot Blida : ${err?.message || err}`, 'error');
    } finally {
      setIsProcessingBatchBlida(false);
    }
  };

  const handleTriggerScannerNow = async () => {
    setIsScanningBlida(true);
    addLog('📡 Lancement immédiat du Scanner Telegram & Google Drive (Médecine Blida)...', 'info');

    try {
      const res = await dispatchGitHubWorkflow('medsina_blida_scanner.yml', {});
      if (res.success) {
        addLog('✅ Robot Scanner Blida déclenché avec succès sur GitHub Actions ! Rafraîchissement prévu dans 15 secondes...', 'success');
        setTimeout(() => {
          loadBlidaQueue();
          handleRefreshRuns();
        }, 15000);
      } else {
        addLog(`⚠️ Scanner Blida : ${res.message}`, 'warn');
      }
    } catch (err: any) {
      addLog(`❌ Erreur déclenchement scanner : ${err?.message || err}`, 'error');
    } finally {
      setIsScanningBlida(false);
    }
  };

  // Open Sources Modal
  const handleOpenSourcesModal = async () => {
    setSourcesError(null);
    try {
      const config = await getBlidaScannerSources();
      setSourcesConfigText(config);
    } catch {
      setSourcesConfigText(DEFAULT_BLIDA_SCANNER_SOURCES);
    }
    setIsSourcesModalOpen(true);
  };

  const handleSaveSourcesConfig = async () => {
    setSourcesError(null);
    try {
      JSON.parse(sourcesConfigText);
    } catch (e: any) {
      setSourcesError(`Format JSON invalide : ${e?.message || e}`);
      return;
    }

    setIsSavingSources(true);
    try {
      const ok = await saveBlidaScannerSources(sourcesConfigText);
      if (ok) {
        addLog('✅ Sources Telegram et Google Drive sauvegardées avec succès dans Supabase admin_system_settings !', 'success');
        setIsSourcesModalOpen(false);
      } else {
        setSourcesError('Erreur de sauvegarde sur Supabase Cloud.');
      }
    } catch (err: any) {
      setSourcesError(`Erreur : ${err?.message || err}`);
    } finally {
      setIsSavingSources(false);
    }
  };

  // --- FACEBOOK PUBLISHER DISPATCH ---
  const handleTriggerFacebookPublish = async () => {
    setIsTriggeringFacebook(true);
    addLog(`🚀 Création et publication multicanal Facebook & Telegram (${fbType})...`, 'info');

    const inputs: Record<string, string> = {
      type: fbType,
    };
    if (fbTopic.trim()) inputs.topic = fbTopic.trim();
    if (fbScreenshot.trim()) inputs.screenshot = fbScreenshot.trim();
    if (fbMockupType && fbMockupType !== 'auto') inputs.mockup_type = fbMockupType;

    try {
      const res = await dispatchGitHubWorkflow('medsina_facebook.yml', inputs);
      if (res.success) {
        addLog('✅ Publication Facebook et Telegram lancée ! L\'infographie 1080x1080 et le post seront en ligne dans ~1 minute.', 'success');
        setIsFacebookModalOpen(false);
        setTimeout(handleRefreshRuns, 4000);
      } else {
        addLog(`⚠️ Publication Facebook : ${res.message}`, 'warn');
      }
    } catch (err: any) {
      addLog(`❌ Erreur Facebook Publisher : ${err?.message || err}`, 'error');
    } finally {
      setIsTriggeringFacebook(false);
    }
  };

  // --- PROMO HUNTER DISPATCH ---
  const handleTriggerPromoHunter = async () => {
    setIsTriggeringPromo(true);
    addLog(`🎯 Lancement du Chasseur Promo Telegram & FB (Cible: ${promoTarget}, Max: ${promoMaxReplies})...`, 'info');

    const inputs: Record<string, string> = {
      target: promoTarget,
      max_replies: promoMaxReplies.toString(),
    };

    try {
      const res = await dispatchGitHubWorkflow('medsina_promo_hunter.yml', inputs);
      if (res.success) {
        addLog('✅ Chasseur Promo déclenché ! Détection des questions d\'étudiants et réponses polies en cours.', 'success');
        setIsPromoModalOpen(false);
        setTimeout(handleRefreshRuns, 4000);
      } else {
        addLog(`⚠️ Chasseur Promo : ${res.message}`, 'warn');
      }
    } catch (err: any) {
      addLog(`❌ Erreur Chasseur Promo : ${err?.message || err}`, 'error');
    } finally {
      setIsTriggeringPromo(false);
    }
  };

  // --- CONFIG MODAL (TOKEN & REPO) ---
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

    addLog('Configuration GitHub mise à jour avec succès dans Supabase admin_system_settings.', 'success');
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

  // Compute pending resources count
  const pendingCount = useMemo(() => {
    return discoveredResources.filter((r) => r.status === 'pending').length;
  }, [discoveredResources]);

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
                {pendingCount > 0 && (
                  <span className="text-xs px-2.5 py-0.5 rounded-full font-semibold bg-amber-100 text-amber-800 dark:bg-amber-950 dark:text-amber-300 border border-amber-300 dark:border-amber-800 animate-pulse">
                    {pendingCount} En Attente ⏳
                  </span>
                )}
              </h1>
              <p className="text-xs md:text-sm text-slate-500 dark:text-slate-400 mt-0.5">
                Validation Blida (Telegram & Drive), diffusion multicanal Facebook, veille et orchestration des 18 agents sur {currentRepo}.
              </p>
            </div>
          </div>
        </div>

        {/* Global Action Controls */}
        <div className="flex flex-wrap items-center gap-2">
          <button
            onClick={() => setIsPromoModalOpen(true)}
            className="flex items-center gap-1.5 px-3 py-1.5 text-xs font-semibold text-sky-700 dark:text-sky-300 bg-sky-50 dark:bg-sky-950/60 border border-sky-300 dark:border-sky-800 hover:bg-sky-100 rounded-lg transition-colors cursor-pointer"
            title="Lancer le Chasseur Promo Telegram"
          >
            <Radio className="w-3.5 h-3.5 text-sky-500" />
            <span>Chasseur Promo 🎯</span>
          </button>

          <button
            onClick={() => setIsFacebookModalOpen(true)}
            className="flex items-center gap-1.5 px-3 py-1.5 text-xs font-semibold text-blue-700 dark:text-blue-300 bg-blue-50 dark:bg-blue-950/60 border border-blue-300 dark:border-blue-800 hover:bg-blue-100 rounded-lg transition-colors cursor-pointer"
            title="Créer une publication Facebook & Telegram"
          >
            <Send className="w-3.5 h-3.5 text-blue-500" />
            <span>Publier FB/TG 🚀</span>
          </button>

          <button
            onClick={handleRefreshRuns}
            disabled={isRefreshingRuns}
            className="flex items-center gap-1.5 px-3 py-1.5 text-xs font-semibold text-slate-700 dark:text-slate-200 bg-white dark:bg-slate-800 border border-slate-300 dark:border-slate-700 hover:bg-slate-50 dark:hover:bg-slate-750 rounded-lg transition-colors cursor-pointer disabled:opacity-50"
            title="Rafraîchir les statuts des runs GitHub Actions"
          >
            <RefreshCw className={`w-3.5 h-3.5 ${isRefreshingRuns ? 'animate-spin text-teal-500' : ''}`} />
            <span>Sync Statuts</span>
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

      {/* Main Feature Tabs */}
      <div className="flex border-b border-slate-200 dark:border-slate-800 overflow-x-auto no-scrollbar gap-1">
        <button
          onClick={() => setActiveTab('validation')}
          className={`flex items-center gap-2 px-4 py-2.5 text-xs font-bold border-b-2 whitespace-nowrap transition-colors cursor-pointer ${
            activeTab === 'validation'
              ? 'border-sky-500 text-sky-600 dark:text-sky-400 bg-sky-50/50 dark:bg-sky-950/20'
              : 'border-transparent text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white'
          }`}
        >
          <Radio className="w-4 h-4 text-sky-500" />
          <span>File de Validation Blida (Telegram & Drive)</span>
          <span className="px-2 py-0.5 rounded-full text-[10px] bg-sky-100 dark:bg-sky-900/60 text-sky-700 dark:text-sky-300 font-extrabold">
            {discoveredResources.length}
          </span>
        </button>

        <button
          onClick={() => setActiveTab('catalog')}
          className={`flex items-center gap-2 px-4 py-2.5 text-xs font-bold border-b-2 whitespace-nowrap transition-colors cursor-pointer ${
            activeTab === 'catalog'
              ? 'border-teal-500 text-teal-600 dark:text-teal-400 bg-teal-50/50 dark:bg-teal-950/20'
              : 'border-transparent text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white'
          }`}
        >
          <Bot className="w-4 h-4 text-teal-500" />
          <span>Catalogue des 18 Agents IA</span>
        </button>

        <button
          onClick={() => setActiveTab('facebook')}
          className={`flex items-center gap-2 px-4 py-2.5 text-xs font-bold border-b-2 whitespace-nowrap transition-colors cursor-pointer ${
            activeTab === 'facebook'
              ? 'border-blue-500 text-blue-600 dark:text-blue-400 bg-blue-50/50 dark:bg-blue-950/20'
              : 'border-transparent text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white'
          }`}
        >
          <Send className="w-4 h-4 text-blue-500" />
          <span>Publication Facebook & Telegram</span>
        </button>

        <button
          onClick={() => setActiveTab('promo')}
          className={`flex items-center gap-2 px-4 py-2.5 text-xs font-bold border-b-2 whitespace-nowrap transition-colors cursor-pointer ${
            activeTab === 'promo'
              ? 'border-indigo-500 text-indigo-600 dark:text-indigo-400 bg-indigo-50/50 dark:bg-indigo-950/20'
              : 'border-transparent text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white'
          }`}
        >
          <MessageSquare className="w-4 h-4 text-indigo-500" />
          <span>Chasseur Promo & Entraide</span>
        </button>

        <button
          onClick={() => setActiveTab('logs')}
          className={`flex items-center gap-2 px-4 py-2.5 text-xs font-bold border-b-2 whitespace-nowrap transition-colors cursor-pointer ${
            activeTab === 'logs'
              ? 'border-emerald-500 text-emerald-600 dark:text-emerald-400 bg-emerald-50/50 dark:bg-emerald-950/20'
              : 'border-transparent text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white'
          }`}
        >
          <Terminal className="w-4 h-4 text-emerald-500" />
          <span>Console & Télémétrie</span>
          <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse" />
        </button>
      </div>

      {/* ========================================================================= */}
      {/* --- TAB 1: BLIDA VALIDATION QUEUE (TELEGRAM & DRIVE) --- */}
      {/* ========================================================================= */}
      {activeTab === 'validation' && (
        <div className="space-y-5">
          {/* Main Card Header */}
          <div className="p-5 rounded-2xl border border-sky-300/40 dark:border-sky-800/40 bg-white dark:bg-slate-900 shadow-sm">
            <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 pb-4 border-b border-slate-100 dark:border-slate-800">
              <div className="flex items-start gap-3.5">
                <div className="p-3 bg-sky-500/10 text-sky-600 dark:text-sky-400 rounded-xl border border-sky-500/20">
                  <Radio className="w-6 h-6" />
                </div>
                <div>
                  <div className="flex items-center gap-2 flex-wrap">
                    <h2 className="text-base md:text-lg font-bold text-slate-900 dark:text-white">
                      File d'Attente de Validation Blida (Telegram & Drive)
                    </h2>
                    <span className="px-2.5 py-0.5 rounded-full text-xs font-extrabold bg-sky-100 text-sky-800 dark:bg-sky-950 dark:text-sky-300 border border-sky-300 dark:border-sky-800">
                      {discoveredResources.length} ressource(s)
                    </span>
                  </div>
                  <p className="text-xs text-slate-500 dark:text-slate-400 mt-1 max-w-3xl leading-relaxed">
                    Ressources PDF, QCM, EMD et Drives détectés automatiquement sur les canaux Telegram et dossiers Google Drive de Médecine Blida. Aucune ressource n'est publiée sans votre validation explicite.
                  </p>
                </div>
              </div>

              {/* Action Buttons */}
              <div className="flex flex-wrap items-center gap-2">
                <button
                  onClick={handleOpenSourcesModal}
                  className="flex items-center gap-1.5 px-3 py-1.5 text-xs font-semibold text-sky-700 dark:text-sky-300 bg-sky-50 dark:bg-sky-950/60 border border-sky-300 dark:border-sky-700 hover:bg-sky-100 dark:hover:bg-sky-900/60 rounded-lg transition-colors cursor-pointer"
                  title="Configurer les canaux Telegram et dossiers Google Drive surveillés"
                >
                  <SlidersHorizontal className="w-3.5 h-3.5" />
                  <span>Sources Surveillées</span>
                </button>

                <button
                  onClick={handleTriggerScannerNow}
                  disabled={isScanningBlida}
                  className="flex items-center gap-1.5 px-3.5 py-1.5 text-xs font-bold text-white bg-sky-600 hover:bg-sky-700 dark:bg-sky-500 dark:hover:bg-sky-600 rounded-lg transition-colors cursor-pointer disabled:opacity-50 shadow-xs"
                >
                  {isScanningBlida ? (
                    <>
                      <RefreshCw className="w-3.5 h-3.5 animate-spin" />
                      <span>Scan en cours...</span>
                    </>
                  ) : (
                    <>
                      <Radio className="w-3.5 h-3.5" />
                      <span>Scanner Maintenant</span>
                    </>
                  )}
                </button>

                <button
                  onClick={() => loadBlidaQueue()}
                  disabled={isLoadingBlidaQueue}
                  className="p-1.5 text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 rounded-lg border border-slate-200 dark:border-slate-700 transition-colors cursor-pointer disabled:opacity-50"
                  title="Actualiser la file d'attente"
                >
                  <RefreshCw className={`w-4 h-4 ${isLoadingBlidaQueue ? 'animate-spin text-sky-500' : ''}`} />
                </button>
              </div>
            </div>

            {/* Filter Chips Bar */}
            <div className="flex flex-wrap items-center justify-between gap-3 pt-4">
              <div className="flex flex-wrap items-center gap-1.5">
                {[
                  { key: 'pending' as const, label: 'En attente ⏳', color: 'border-amber-400 bg-amber-50 dark:bg-amber-950/40 text-amber-700 dark:text-amber-300' },
                  { key: 'approved' as const, label: 'Approuvés ✅', color: 'border-emerald-400 bg-emerald-50 dark:bg-emerald-950/40 text-emerald-700 dark:text-emerald-300' },
                  { key: 'rejected' as const, label: 'Rejetés ❌', color: 'border-rose-400 bg-rose-50 dark:bg-rose-950/40 text-rose-700 dark:text-rose-300' },
                  { key: 'all' as const, label: 'Tous', color: 'border-sky-400 bg-sky-50 dark:bg-sky-950/40 text-sky-700 dark:text-sky-300' },
                ].map((f) => (
                  <button
                    key={f.key}
                    onClick={() => handleFilterChange(f.key)}
                    className={`px-3 py-1.5 rounded-lg text-xs font-bold transition-all cursor-pointer border ${
                      blidaQueueFilterStatus === f.key
                        ? f.color
                        : 'border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-600 dark:text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-750'
                    }`}
                  >
                    {f.label}
                  </button>
                ))}
              </div>

              {/* Status counter indicator */}
              <div className="text-xs text-slate-500 dark:text-slate-400">
                Filtre actif : <strong className="text-slate-900 dark:text-white capitalize">{blidaQueueFilterStatus}</strong> ({discoveredResources.length} élément(s))
              </div>
            </div>
          </div>

          {/* Batch Selection Toolbar */}
          {discoveredResources.length > 0 && (
            <div className="p-3 bg-slate-50 dark:bg-slate-850 rounded-xl border border-slate-200 dark:border-slate-800 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3">
              <div className="flex items-center gap-2">
                <input
                  type="checkbox"
                  id="select-all-blida"
                  checked={discoveredResources.length > 0 && selectedBlidaResourceIds.length === discoveredResources.length}
                  onChange={handleToggleSelectAll}
                  className="w-4 h-4 text-sky-600 rounded-sm border-slate-300 focus:ring-sky-500 cursor-pointer"
                />
                <label htmlFor="select-all-blida" className="text-xs font-semibold text-slate-700 dark:text-slate-300 cursor-pointer">
                  {selectedBlidaResourceIds.length === 0
                    ? `Tout sélectionner (${discoveredResources.length})`
                    : `${selectedBlidaResourceIds.length}/${discoveredResources.length} sélectionné(s)`}
                </label>
              </div>

              {selectedBlidaResourceIds.length > 0 && (
                <div className="flex items-center gap-2">
                  <button
                    onClick={() => setSelectedBlidaResourceIds([])}
                    className="px-2.5 py-1 text-xs text-slate-500 hover:text-slate-700 dark:hover:text-slate-300 cursor-pointer"
                  >
                    Désélectionner
                  </button>

                  <button
                    onClick={() => handleBatchStatusUpdate('approved')}
                    disabled={isProcessingBatchBlida}
                    className="flex items-center gap-1.5 px-3 py-1.5 text-xs font-bold text-white bg-emerald-600 hover:bg-emerald-700 rounded-lg transition-colors cursor-pointer disabled:opacity-50"
                  >
                    <CheckCircle2 className="w-3.5 h-3.5" />
                    <span>Approuver ({selectedBlidaResourceIds.length})</span>
                  </button>

                  <button
                    onClick={() => handleBatchStatusUpdate('rejected')}
                    disabled={isProcessingBatchBlida}
                    className="flex items-center gap-1.5 px-3 py-1.5 text-xs font-bold text-rose-600 dark:text-rose-400 bg-rose-50 dark:bg-rose-950/40 border border-rose-300 dark:border-rose-800 hover:bg-rose-100 rounded-lg transition-colors cursor-pointer disabled:opacity-50"
                  >
                    <XCircle className="w-3.5 h-3.5" />
                    <span>Rejeter ({selectedBlidaResourceIds.length})</span>
                  </button>
                </div>
              )}
            </div>
          )}

          {/* Resources List or Empty State */}
          {isLoadingBlidaQueue && discoveredResources.length === 0 ? (
            <div className="p-12 text-center rounded-2xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900">
              <RefreshCw className="w-8 h-8 text-sky-500 animate-spin mx-auto mb-3" />
              <p className="text-sm font-semibold text-slate-700 dark:text-slate-300">
                Chargement des ressources surveillées...
              </p>
            </div>
          ) : discoveredResources.length === 0 ? (
            <div className="p-12 text-center rounded-2xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900">
              <Inbox className="w-10 h-10 text-slate-400 mx-auto mb-3" />
              <h3 className="font-bold text-sm text-slate-800 dark:text-slate-200">
                {blidaQueueFilterStatus === 'pending'
                  ? 'Aucune ressource en attente de validation.'
                  : 'Aucune ressource trouvée pour ce filtre.'}
              </h3>
              <p className="text-xs text-slate-500 dark:text-slate-400 mt-1 max-w-md mx-auto">
                Cliquez sur "Scanner Maintenant" pour lancer une inspection automatisée des canaux Telegram et Google Drive.
              </p>
              <button
                onClick={handleTriggerScannerNow}
                disabled={isScanningBlida}
                className="mt-4 inline-flex items-center gap-1.5 px-4 py-2 text-xs font-bold text-white bg-sky-600 hover:bg-sky-700 rounded-lg transition-colors cursor-pointer"
              >
                <Radio className="w-4 h-4" />
                <span>Scanner Maintenant</span>
              </button>
            </div>
          ) : (
            <div className="space-y-3">
              {discoveredResources.map((item) => {
                const isSelected = selectedBlidaResourceIds.includes(item.id);
                const isDrive = (item.source_type || '').includes('drive') || (item.url || '').includes('drive.google');
                const sourceColor = isDrive ? 'text-emerald-600 dark:text-emerald-400 bg-emerald-50 dark:bg-emerald-950/60 border-emerald-300 dark:border-emerald-800' : 'text-sky-600 dark:text-sky-400 bg-sky-50 dark:bg-sky-950/60 border-sky-300 dark:border-sky-800';
                const sourceLabel = isDrive ? 'Google Drive' : 'Telegram';

                let typeLabel = 'Ressource';
                let typeColor = 'text-indigo-600 dark:text-indigo-400 bg-indigo-50 dark:bg-indigo-950/60 border-indigo-200 dark:border-indigo-800';
                if (item.resource_type === 'qcm_exam') {
                  typeLabel = 'QCM / EMD';
                  typeColor = 'text-amber-600 dark:text-amber-400 bg-amber-50 dark:bg-amber-950/60 border-amber-200 dark:border-amber-800';
                } else if (item.resource_type === 'pdf_course') {
                  typeLabel = 'Cours PDF';
                  typeColor = 'text-pink-600 dark:text-pink-400 bg-pink-50 dark:bg-pink-950/60 border-pink-200 dark:border-pink-800';
                } else if (item.resource_type === 'drive_folder') {
                  typeLabel = 'Dossier Drive';
                  typeColor = 'text-emerald-600 dark:text-emerald-400 bg-emerald-50 dark:bg-emerald-950/60 border-emerald-200 dark:border-emerald-800';
                } else if (item.resource_type === 'mindmap') {
                  typeLabel = 'Mind Map';
                  typeColor = 'text-purple-600 dark:text-purple-400 bg-purple-50 dark:bg-purple-950/60 border-purple-200 dark:border-purple-800';
                }

                return (
                  <div
                    key={item.id}
                    className={`p-4 rounded-xl border transition-all ${
                      isSelected
                        ? 'border-sky-500 bg-sky-50/30 dark:bg-sky-950/20'
                        : 'border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 hover:border-slate-300 dark:hover:border-slate-700'
                    }`}
                  >
                    <div className="flex items-start gap-3">
                      <input
                        type="checkbox"
                        checked={isSelected}
                        onChange={() => handleToggleSelectItem(item.id)}
                        className="mt-1 w-4 h-4 text-sky-600 rounded-sm border-slate-300 focus:ring-sky-500 cursor-pointer shrink-0"
                      />

                      <div className="flex-1 min-w-0">
                        {/* Badges Bar */}
                        <div className="flex flex-wrap items-center gap-1.5 mb-2">
                          <span className={`px-2 py-0.5 rounded-md text-[10px] font-bold border flex items-center gap-1 ${sourceColor}`}>
                            <Radio className="w-3 h-3" />
                            <span>{item.source_channel_or_folder || item.source_origin ? `${sourceLabel} • ${item.source_channel_or_folder || item.source_origin}` : sourceLabel}</span>
                          </span>

                          <span className={`px-2 py-0.5 rounded-md text-[10px] font-bold border ${typeColor}`}>
                            {typeLabel}
                          </span>

                          <span className="px-2 py-0.5 rounded-md text-[10px] font-bold border border-teal-200 dark:border-teal-800 bg-teal-50 dark:bg-teal-950/60 text-teal-700 dark:text-teal-300">
                            {item.study_year ? `${item.suggested_module} (${item.study_year})` : item.suggested_module}
                          </span>

                          {item.status === 'approved' && (
                            <span className="px-2 py-0.5 rounded-md text-[10px] font-bold border border-emerald-300 bg-emerald-50 text-emerald-700 dark:bg-emerald-950 dark:text-emerald-300">
                              Validé ✅
                            </span>
                          )}
                          {item.status === 'rejected' && (
                            <span className="px-2 py-0.5 rounded-md text-[10px] font-bold border border-rose-300 bg-rose-50 text-rose-700 dark:bg-rose-950 dark:text-rose-300">
                              Rejeté ❌
                            </span>
                          )}

                          <span className="text-[11px] text-slate-400 ml-auto">
                            {formatTimeAgo(item.discovered_at)}
                          </span>
                        </div>

                        {/* Title */}
                        <h4 className="text-sm font-bold text-slate-900 dark:text-white leading-snug">
                          {item.title}
                        </h4>

                        {/* Summary / Description */}
                        {(item.ai_summary || item.description) && (
                          <p className="text-xs text-slate-600 dark:text-slate-400 mt-1 line-clamp-2 leading-relaxed">
                            {item.ai_summary || item.description}
                          </p>
                        )}

                        {/* Actions row */}
                        <div className="flex flex-wrap items-center justify-end gap-2 mt-3 pt-2 border-t border-slate-100 dark:border-slate-800/80">
                          {item.url && (
                            <a
                              href={item.url}
                              target="_blank"
                              rel="noopener noreferrer"
                              className="inline-flex items-center gap-1 px-2.5 py-1 text-xs font-semibold text-slate-700 dark:text-slate-200 bg-slate-100 dark:bg-slate-800 hover:bg-slate-200 rounded-lg transition-colors"
                            >
                              <ExternalLink className="w-3 h-3 text-slate-500" />
                              <span>Inspecter Lien</span>
                            </a>
                          )}

                          {item.status !== 'approved' && (
                            <button
                              onClick={() => handleSingleStatusUpdate(item, 'approved')}
                              className="inline-flex items-center gap-1 px-3 py-1 text-xs font-bold text-white bg-emerald-600 hover:bg-emerald-700 rounded-lg transition-colors cursor-pointer shadow-2xs"
                            >
                              <Check className="w-3.5 h-3.5" />
                              <span>Approuver</span>
                            </button>
                          )}

                          {item.status !== 'rejected' && (
                            <button
                              onClick={() => handleSingleStatusUpdate(item, 'rejected')}
                              className="inline-flex items-center gap-1 px-2.5 py-1 text-xs font-semibold text-rose-600 dark:text-rose-400 border border-rose-200 dark:border-rose-800 hover:bg-rose-50 dark:hover:bg-rose-950/40 rounded-lg transition-colors cursor-pointer"
                            >
                              <X className="w-3.5 h-3.5" />
                              <span>Rejeter</span>
                            </button>
                          )}
                        </div>
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      )}

      {/* ========================================================================= */}
      {/* --- TAB 2: AGENTS CATALOG (18 WORKFLOWS) --- */}
      {/* ========================================================================= */}
      {activeTab === 'catalog' && (
        <div className="space-y-6">
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
                    <div className="flex items-center justify-between gap-2 mb-3">
                      <span className={`px-2.5 py-0.5 rounded-md text-[10px] font-semibold border ${agent.badgeColor}`}>
                        {agent.categoryLabel}
                      </span>
                      {statusBadge}
                    </div>

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

                    <p className="text-xs text-slate-600 dark:text-slate-400 mt-3 leading-relaxed min-h-[44px]">
                      {agent.description}
                    </p>

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
        </div>
      )}

      {/* ========================================================================= */}
      {/* --- TAB 3: MULTICHANNEL FACEBOOK & TELEGRAM PUBLISHER --- */}
      {/* ========================================================================= */}
      {activeTab === 'facebook' && (
        <div className="p-6 rounded-2xl border border-blue-200 dark:border-blue-900/60 bg-white dark:bg-slate-900 shadow-sm space-y-6">
          <div className="flex items-start gap-4 pb-4 border-b border-slate-100 dark:border-slate-800">
            <div className="p-3 bg-blue-500/10 text-blue-600 dark:text-blue-400 rounded-xl border border-blue-500/20">
              <Send className="w-6 h-6" />
            </div>
            <div>
              <h2 className="text-lg font-bold text-slate-900 dark:text-white">
                Publication Multicanal Facebook & Telegram
              </h2>
              <p className="text-xs text-slate-500 dark:text-slate-400 mt-1 max-w-2xl">
                Générateur d'infographies 1080x1080 et de publications avec captures d'écran réelles de l'application Medsina pour la page Facebook Residanat Blida 2027 et le canal Telegram officiel.
              </p>
            </div>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div className="space-y-4">
              <div>
                <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1.5">
                  Type de publication :
                </label>
                <select
                  value={fbType}
                  onChange={(e) => setFbType(e.target.value)}
                  className="w-full px-3 py-2 text-xs rounded-lg border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:ring-2 focus:ring-blue-500"
                >
                  <option value="auto">Automatique (Médical le matin / Promo le soir)</option>
                  <option value="commercial">Promotion Commerciale (Téléchargement de Medsina)</option>
                  <option value="medical">Médicale Clinique & Concours (Fiches, CAT, Pièges)</option>
                  <option value="qcm">🎯 QCM Annales Réelles (Source & Date Concours)</option>
                </select>
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1.5">
                  Thème ou sujet spécifique (optionnel) :
                </label>
                <input
                  type="text"
                  value={fbTopic}
                  onChange={(e) => setFbTopic(e.target.value)}
                  placeholder="ex: Cardiologie, Pneumologie, Arrêt cardiaque, Blida 2023, Urgences..."
                  className="w-full px-3 py-2 text-xs rounded-lg border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:ring-2 focus:ring-blue-500"
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1.5">
                  Capture d'écran de l'application :
                </label>
                <select
                  value={fbScreenshot}
                  onChange={(e) => setFbScreenshot(e.target.value)}
                  className="w-full px-3 py-2 text-xs rounded-lg border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:ring-2 focus:ring-blue-500"
                >
                  <option value="">Sélection automatique / Assets standards</option>
                  <option value="Screenshot 2026-10-20 175342_dashboard.png">Tableau de Bord Récent Medsina (Desktop)</option>
                  <option value="desktop/prescription_audit_pc.png">Audit Ordonnance & Vidal PC</option>
                  <option value="desktop/revision_qcm_pc.png">Révision QCM & Concours PC</option>
                  <option value="desktop/clinical_copilot_pc.png">Copilote Clinique PC</option>
                  <option value="desktop/admin_analytics_pc.png">Analytics Administrateur PC</option>
                  <option value="mobile/clinical_copilot_mobile.png">Copilote Clinique Mobile</option>
                  <option value="mobile/ai_copilot_mobile.png">Assistant IA Mobile</option>
                  <option value="mobile/prescription_mobile.png">Prescription Mobile</option>
                  <option value="mobile/qcm_session_mobile.png">Session QCM Mobile</option>
                </select>
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1.5">
                  Format du cadre de la maquette :
                </label>
                <select
                  value={fbMockupType}
                  onChange={(e) => setFbMockupType(e.target.value)}
                  className="w-full px-3 py-2 text-xs rounded-lg border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:ring-2 focus:ring-blue-500"
                >
                  <option value="auto">Automatique (Adapté selon l'orientation)</option>
                  <option value="desktop">PC Desktop (Moniteur haute fidélité)</option>
                  <option value="phone">Smartphone (Châssis mobile titanium)</option>
                  <option value="none">Sans maquette (Infographie pleine largeur avec points clés)</option>
                </select>
              </div>
            </div>

            <div className="flex flex-col justify-between p-4 rounded-xl bg-blue-50/50 dark:bg-blue-950/20 border border-blue-200 dark:border-blue-900">
              <div className="space-y-3">
                <div className="flex items-center gap-2 text-blue-700 dark:text-blue-300 font-bold text-xs">
                  <CheckCircle2 className="w-4 h-4 text-blue-500" />
                  <span>Pipeline de diffusion autonome</span>
                </div>
                <p className="text-xs text-slate-600 dark:text-slate-400 leading-relaxed">
                  L'agent exécute le script <code className="font-mono text-blue-600 dark:text-blue-400">scripts/automation/facebook_post_generator.py</code> sur le runner GitHub Actions, assemble l'infographie via Pillow, contacte l'API Graph de Facebook et le Bot Telegram pour une publication instantanée.
                </p>
                <div className="p-2.5 rounded-lg bg-white dark:bg-slate-800 border border-blue-200 dark:border-blue-800 text-[11px] text-slate-600 dark:text-slate-300">
                  📍 <strong>Cibles :</strong> Page Facebook « Résidanat Médecine Blida 2027 » & Canal Telegram MedSina.
                </div>
              </div>

              <button
                onClick={handleTriggerFacebookPublish}
                disabled={isTriggeringFacebook}
                className="mt-6 w-full flex items-center justify-center gap-2 py-2.5 px-4 text-xs font-bold text-white bg-blue-600 hover:bg-blue-700 rounded-xl transition-colors cursor-pointer shadow-sm disabled:opacity-50"
              >
                {isTriggeringFacebook ? (
                  <>
                    <RefreshCw className="w-4 h-4 animate-spin" />
                    <span>Création & Publication en cours...</span>
                  </>
                ) : (
                  <>
                    <Send className="w-4 h-4" />
                    <span>Tout Créer & Publier Directement 🚀</span>
                  </>
                )}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ========================================================================= */}
      {/* --- TAB 4: CHASSEUR PROMO & ENTRAIDE --- */}
      {/* ========================================================================= */}
      {activeTab === 'promo' && (
        <div className="p-6 rounded-2xl border border-sky-200 dark:border-sky-900/60 bg-white dark:bg-slate-900 shadow-sm space-y-6">
          <div className="flex items-start gap-4 pb-4 border-b border-slate-100 dark:border-slate-800">
            <div className="p-3 bg-sky-500/10 text-sky-600 dark:text-sky-400 rounded-xl border border-sky-500/20">
              <Radio className="w-6 h-6" />
            </div>
            <div>
              <h2 className="text-lg font-bold text-slate-900 dark:text-white">
                Chasseur Promo Telegram & Assistant Réponses Facebook
              </h2>
              <p className="text-xs text-slate-500 dark:text-slate-400 mt-1 max-w-2xl">
                Scanne en temps réel les questions d'étudiants (résidanat, QCMs, annales, cours) et y répond poliment avec les liens officiels Medsina en respectant les filtres de sécurité.
              </p>
            </div>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div className="space-y-4">
              <div>
                <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1.5">
                  Cible de l'exécution :
                </label>
                <select
                  value={promoTarget}
                  onChange={(e) => setPromoTarget(e.target.value as any)}
                  className="w-full px-3 py-2 text-xs rounded-lg border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:ring-2 focus:ring-sky-500"
                >
                  <option value="telegram">Telegram Option B (Discussions & Entraide)</option>
                  <option value="facebook">Facebook Pages (Réponses aux Commentaires)</option>
                  <option value="all">Tout Exécuter (Telegram + Facebook)</option>
                </select>
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1.5">
                  Plafond de réponses ciblées :
                </label>
                <select
                  value={promoMaxReplies}
                  onChange={(e) => setPromoMaxReplies(parseInt(e.target.value, 10))}
                  className="w-full px-3 py-2 text-xs rounded-lg border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:ring-2 focus:ring-sky-500"
                >
                  <option value={1}>1 réponse ciblée</option>
                  <option value={2}>2 réponses (Recommandé)</option>
                  <option value={3}>3 réponses</option>
                  <option value={5}>5 réponses maximum</option>
                </select>
              </div>

              <div className="p-3.5 rounded-xl bg-emerald-50 dark:bg-emerald-950/30 border border-emerald-200 dark:border-emerald-800 text-xs text-emerald-800 dark:text-emerald-300 flex items-start gap-2.5">
                <ShieldCheck className="w-5 h-5 text-emerald-600 shrink-0 mt-0.5" />
                <div>
                  <strong className="block font-bold">Sécurité Anti-Spam Garantie :</strong>
                  <span>Canaux MBset strictement exclus + temporisation anti-flood de 180s entre les messages pour une intégration 100% éthique.</span>
                </div>
              </div>
            </div>

            <div className="flex flex-col justify-between p-4 rounded-xl bg-sky-50/50 dark:bg-sky-950/20 border border-sky-200 dark:border-sky-900">
              <div className="space-y-3">
                <div className="flex items-center gap-2 text-sky-700 dark:text-sky-300 font-bold text-xs">
                  <Sparkles className="w-4 h-4 text-sky-500" />
                  <span>Automatisation Intelligente</span>
                </div>
                <p className="text-xs text-slate-600 dark:text-slate-400 leading-relaxed">
                  Le script <code className="font-mono text-sky-600 dark:text-sky-400">scripts/automation/telegram_promo_hunter.py</code> analyse l'intention des messages Telegram récents grâce à Gemini 2.5 Flash et formule une réponse médicale bienveillante citant MedSina.
                </p>
              </div>

              <button
                onClick={handleTriggerPromoHunter}
                disabled={isTriggeringPromo}
                className="mt-6 w-full flex items-center justify-center gap-2 py-2.5 px-4 text-xs font-bold text-white bg-sky-600 hover:bg-sky-700 rounded-xl transition-colors cursor-pointer shadow-sm disabled:opacity-50"
              >
                {isTriggeringPromo ? (
                  <>
                    <RefreshCw className="w-4 h-4 animate-spin" />
                    <span>Chasseur en action...</span>
                  </>
                ) : (
                  <>
                    <Radio className="w-4 h-4" />
                    <span>Lancer le Chasseur Promo 🎯</span>
                  </>
                )}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ========================================================================= */}
      {/* --- TAB 5: TERMINAL & TELEMETRY LOGS --- */}
      {/* ========================================================================= */}
      {activeTab === 'logs' && (
        <div className="space-y-4">
          <div className="bg-slate-950 rounded-xl border border-slate-800 overflow-hidden shadow-lg">
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

            <div className="p-4 font-mono text-[11px] space-y-1.5 max-h-96 overflow-y-auto">
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
        </div>
      )}

      {/* ========================================================================= */}
      {/* --- MODAL: SOURCES CONFIGURATION --- */}
      {/* ========================================================================= */}
      {isSourcesModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/70 backdrop-blur-xs">
          <div className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200 dark:border-slate-800 shadow-2xl max-w-2xl w-full p-6 animate-in fade-in zoom-in-95 duration-150">
            <div className="flex items-start justify-between gap-4 pb-3 border-b border-slate-100 dark:border-slate-800">
              <div className="flex items-center gap-2.5">
                <div className="p-2 bg-sky-500/10 text-sky-600 rounded-lg">
                  <Radio className="w-5 h-5" />
                </div>
                <div>
                  <h3 className="font-bold text-base text-slate-900 dark:text-white">
                    Sources Telegram & Google Drive (Médecine Blida)
                  </h3>
                  <p className="text-xs text-slate-500 dark:text-slate-400 mt-0.5">
                    Surveillance intelligente des canaux Telegram étudiants et dossiers Drive partagés
                  </p>
                </div>
              </div>
              <button
                onClick={() => setIsSourcesModalOpen(false)}
                className="text-slate-400 hover:text-slate-600 dark:hover:text-white p-1 rounded-lg"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="mt-4 space-y-3">
              <p className="text-xs text-slate-600 dark:text-slate-300 leading-relaxed">
                Configurez la structure JSON des canaux Telegram publics (@handle), des dossiers Google Drive partagés et des mots-clés surveillés par le robot GitHub Actions :
              </p>

              {sourcesError && (
                <div className="p-3 rounded-lg bg-rose-50 text-rose-700 dark:bg-rose-950/50 dark:text-rose-300 border border-rose-300 text-xs font-mono">
                  {sourcesError}
                </div>
              )}

              <textarea
                value={sourcesConfigText}
                onChange={(e) => setSourcesConfigText(e.target.value)}
                rows={12}
                className="w-full p-3 text-xs font-mono rounded-lg border border-slate-300 dark:border-slate-700 bg-slate-50 dark:bg-slate-950 text-slate-900 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-sky-500"
              />
            </div>

            <div className="mt-6 flex items-center justify-end gap-2 pt-3 border-t border-slate-100 dark:border-slate-800">
              <button
                onClick={() => setIsSourcesModalOpen(false)}
                className="px-3.5 py-2 text-xs font-semibold text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 rounded-lg transition-colors cursor-pointer"
              >
                Annuler
              </button>
              <button
                onClick={handleSaveSourcesConfig}
                disabled={isSavingSources}
                className="flex items-center gap-1.5 px-4 py-2 text-xs font-bold text-white bg-sky-600 hover:bg-sky-700 rounded-lg transition-colors cursor-pointer shadow-xs disabled:opacity-50"
              >
                {isSavingSources ? <RefreshCw className="w-3.5 h-3.5 animate-spin" /> : <Check className="w-3.5 h-3.5" />}
                <span>Enregistrer sur Supabase Cloud</span>
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ========================================================================= */}
      {/* --- MODAL: FACEBOOK QUICK LAUNCH --- */}
      {/* ========================================================================= */}
      {isFacebookModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/70 backdrop-blur-xs">
          <div className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200 dark:border-slate-800 shadow-2xl max-w-lg w-full p-6 animate-in fade-in zoom-in-95 duration-150">
            <div className="flex items-start justify-between gap-4 pb-3 border-b border-slate-100 dark:border-slate-800">
              <div className="flex items-center gap-2.5">
                <div className="p-2 bg-blue-500/10 text-blue-600 rounded-lg">
                  <Send className="w-5 h-5" />
                </div>
                <div>
                  <h3 className="font-bold text-base text-slate-900 dark:text-white">
                    Créer une Publication Facebook & Telegram
                  </h3>
                  <p className="text-xs text-slate-500 dark:text-slate-400 mt-0.5">
                    Infographie 1080x1080 + post prêt à diffuser
                  </p>
                </div>
              </div>
              <button
                onClick={() => setIsFacebookModalOpen(false)}
                className="text-slate-400 hover:text-slate-600 dark:hover:text-white p-1 rounded-lg"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="mt-4 space-y-3.5">
              <div>
                <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1">
                  Type de publication :
                </label>
                <select
                  value={fbType}
                  onChange={(e) => setFbType(e.target.value)}
                  className="w-full px-3 py-2 text-xs rounded-lg border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:ring-2 focus:ring-blue-500"
                >
                  <option value="auto">Automatique (Médical le matin / Promo le soir)</option>
                  <option value="commercial">Promotion Commerciale (Téléchargement de Medsina)</option>
                  <option value="medical">Médicale Clinique & Concours (Fiches, CAT, Pièges)</option>
                  <option value="qcm">🎯 QCM Annales Réelles (Source & Date Concours)</option>
                </select>
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1">
                  Thème ou sujet spécifique (optionnel) :
                </label>
                <input
                  type="text"
                  value={fbTopic}
                  onChange={(e) => setFbTopic(e.target.value)}
                  placeholder="ex: Cardiologie, Pneumologie, Arrêt cardiaque, Blida 2023..."
                  className="w-full px-3 py-2 text-xs rounded-lg border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:ring-2 focus:ring-blue-500"
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1">
                  Capture d'écran de l'application :
                </label>
                <select
                  value={fbScreenshot}
                  onChange={(e) => setFbScreenshot(e.target.value)}
                  className="w-full px-3 py-2 text-xs rounded-lg border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:ring-2 focus:ring-blue-500"
                >
                  <option value="">Sélection automatique / Assets standards</option>
                  <option value="Screenshot 2026-10-20 175342_dashboard.png">Tableau de Bord Récent Medsina (Desktop)</option>
                  <option value="desktop/prescription_audit_pc.png">Audit Ordonnance & Vidal PC</option>
                  <option value="desktop/revision_qcm_pc.png">Révision QCM & Concours PC</option>
                  <option value="desktop/clinical_copilot_pc.png">Copilote Clinique PC</option>
                  <option value="desktop/admin_analytics_pc.png">Analytics Administrateur PC</option>
                  <option value="mobile/clinical_copilot_mobile.png">Copilote Clinique Mobile</option>
                  <option value="mobile/ai_copilot_mobile.png">Assistant IA Mobile</option>
                  <option value="mobile/prescription_mobile.png">Prescription Mobile</option>
                  <option value="mobile/qcm_session_mobile.png">Session QCM Mobile</option>
                </select>
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1">
                  Format de la maquette :
                </label>
                <select
                  value={fbMockupType}
                  onChange={(e) => setFbMockupType(e.target.value)}
                  className="w-full px-3 py-2 text-xs rounded-lg border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:ring-2 focus:ring-blue-500"
                >
                  <option value="auto">Automatique (Adapté selon l'orientation)</option>
                  <option value="desktop">PC Desktop (Moniteur haute fidélité)</option>
                  <option value="phone">Smartphone (Châssis mobile titanium)</option>
                  <option value="none">Sans maquette (Infographie pleine largeur)</option>
                </select>
              </div>
            </div>

            <div className="mt-6 flex items-center justify-end gap-2 pt-3 border-t border-slate-100 dark:border-slate-800">
              <button
                onClick={() => setIsFacebookModalOpen(false)}
                className="px-3.5 py-2 text-xs font-semibold text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 rounded-lg transition-colors cursor-pointer"
              >
                Annuler
              </button>
              <button
                onClick={handleTriggerFacebookPublish}
                disabled={isTriggeringFacebook}
                className="flex items-center gap-1.5 px-4 py-2 text-xs font-bold text-white bg-blue-600 hover:bg-blue-700 rounded-lg transition-colors cursor-pointer shadow-xs disabled:opacity-50"
              >
                {isTriggeringFacebook ? <RefreshCw className="w-3.5 h-3.5 animate-spin" /> : <Send className="w-3.5 h-3.5" />}
                <span>Publier Directement 🚀</span>
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ========================================================================= */}
      {/* --- MODAL: PROMO HUNTER QUICK LAUNCH --- */}
      {/* ========================================================================= */}
      {isPromoModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/70 backdrop-blur-xs">
          <div className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200 dark:border-slate-800 shadow-2xl max-w-lg w-full p-6 animate-in fade-in zoom-in-95 duration-150">
            <div className="flex items-start justify-between gap-4 pb-3 border-b border-slate-100 dark:border-slate-800">
              <div className="flex items-center gap-2.5">
                <div className="p-2 bg-sky-500/10 text-sky-600 rounded-lg">
                  <Radio className="w-5 h-5" />
                </div>
                <div>
                  <h3 className="font-bold text-base text-slate-900 dark:text-white">
                    Chasseur Promo & Entraide (Telegram & FB)
                  </h3>
                  <p className="text-xs text-slate-500 dark:text-slate-400 mt-0.5">
                    Détection de questions étudiantes et réponses ciblées MedSina
                  </p>
                </div>
              </div>
              <button
                onClick={() => setIsPromoModalOpen(false)}
                className="text-slate-400 hover:text-slate-600 dark:hover:text-white p-1 rounded-lg"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="mt-4 space-y-3.5">
              <div>
                <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1">
                  Cible de l'exécution :
                </label>
                <select
                  value={promoTarget}
                  onChange={(e) => setPromoTarget(e.target.value as any)}
                  className="w-full px-3 py-2 text-xs rounded-lg border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:ring-2 focus:ring-sky-500"
                >
                  <option value="telegram">Telegram Option B (Discussions & Entraide)</option>
                  <option value="facebook">Facebook Pages (Réponses aux Commentaires)</option>
                  <option value="all">Tout Exécuter (Telegram + Facebook)</option>
                </select>
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1">
                  Plafond de réponses Telegram :
                </label>
                <select
                  value={promoMaxReplies}
                  onChange={(e) => setPromoMaxReplies(parseInt(e.target.value, 10))}
                  className="w-full px-3 py-2 text-xs rounded-lg border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:ring-2 focus:ring-sky-500"
                >
                  <option value={1}>1 réponse ciblée</option>
                  <option value={2}>2 réponses (Recommandé)</option>
                  <option value={3}>3 réponses</option>
                  <option value={5}>5 réponses maximum</option>
                </select>
              </div>

              <div className="p-3 rounded-lg bg-emerald-50 dark:bg-emerald-950/30 border border-emerald-200 dark:border-emerald-800 text-xs text-emerald-800 dark:text-emerald-300">
                🛡️ <strong>Sécurité anti-spam :</strong> canaux MBset strictement exclus + temporisation anti-flood de 180s.
              </div>
            </div>

            <div className="mt-6 flex items-center justify-end gap-2 pt-3 border-t border-slate-100 dark:border-slate-800">
              <button
                onClick={() => setIsPromoModalOpen(false)}
                className="px-3.5 py-2 text-xs font-semibold text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 rounded-lg transition-colors cursor-pointer"
              >
                Annuler
              </button>
              <button
                onClick={handleTriggerPromoHunter}
                disabled={isTriggeringPromo}
                className="flex items-center gap-1.5 px-4 py-2 text-xs font-bold text-white bg-sky-600 hover:bg-sky-700 rounded-lg transition-colors cursor-pointer shadow-xs disabled:opacity-50"
              >
                {isTriggeringPromo ? <RefreshCw className="w-3.5 h-3.5 animate-spin" /> : <Radio className="w-3.5 h-3.5" />}
                <span>Lancer la Campagne 🚀</span>
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ========================================================================= */}
      {/* --- MODAL: AGENT PARAMETERS --- */}
      {/* ========================================================================= */}
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

      {/* ========================================================================= */}
      {/* --- MODAL: GITHUB PAT & REPO CONFIGURATION --- */}
      {/* ========================================================================= */}
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
                Le jeton PAT permet au Tableau de Bord de déclencher les workflows d'automatisation via l'API GitHub et de synchroniser les statuts des 18 agents. Ce token est sauvegardé dans <code className="text-teal-600 dark:text-teal-400 font-mono text-[11px]">admin_system_settings</code>.
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
                  Permissions : <code className="font-mono text-teal-600 dark:text-teal-400">actions:write</code> et <code className="font-mono text-teal-600 dark:text-teal-400">repo</code>.
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
