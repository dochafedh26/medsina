import { supabaseAdmin } from './supabase';

export interface GitHubWorkflowRun {
  id: number;
  name: string;
  workflowId: number;
  workflowFileName?: string;
  event: string;
  status: 'queued' | 'in_progress' | 'completed' | string;
  conclusion: 'success' | 'failure' | 'cancelled' | 'timed_out' | 'skipped' | null;
  createdAt: string;
  updatedAt: string;
  htmlUrl: string;
  runNumber: number;
}

export interface AgentInputDef {
  key: string;
  label: string;
  placeholder?: string;
  defaultValue?: string;
  type?: 'text' | 'select' | 'boolean';
  options?: string[];
  helpText?: string;
}

export type AgentCategory = 
  | 'all'
  | 'pedagogy'
  | 'clinical'
  | 'marketing'
  | 'resources'
  | 'system';

export interface GitHubAgentDef {
  id: string;
  title: string;
  shortTitle: string;
  category: 'pedagogy' | 'clinical' | 'marketing' | 'resources' | 'system';
  categoryLabel: string;
  workflowFile: string;
  script: string;
  description: string;
  defaultCadence: string;
  badgeColor: string;
  accentColor: string;
  iconName: string;
  inputs?: AgentInputDef[];
}

export const GITHUB_AGENTS_CATALOG: GitHubAgentDef[] = [
  // --- 1. PÉDAGOGIE & CONCOURS RÉSIDANAT (5 agents) ---
  {
    id: 'summaries',
    title: 'Résumés Automatiques de Cours (Fiches & Synthèses)',
    shortTitle: 'Fiches Synthèses',
    category: 'pedagogy',
    categoryLabel: 'Pédagogie & Concours',
    workflowFile: 'medsina_summaries_4h.yml',
    script: 'scripts/automation/medsina_agent.py --summary',
    description: 'Génère une fiche de synthèse officielle complète avec points clés, moyens mnémotechniques et pièges de concours pour chaque module de médecine.',
    defaultCadence: 'Toutes les 4 heures (Autonome)',
    badgeColor: 'bg-blue-500/10 text-blue-600 dark:text-blue-400 border-blue-200 dark:border-blue-900',
    accentColor: '#0284c7',
    iconName: 'BookOpen',
    inputs: [
      {
        key: 'course_id',
        label: 'ID du Cours Cible (optionnel)',
        placeholder: 'ex: Blida_CARDIOLOGIE_HTA (laisser vide pour sélection automatique)',
        type: 'text',
        helpText: 'Laissez vide pour laisser l\'agent sélectionner le cours le plus prioritaire.',
      },
    ],
  },
  {
    id: 'synapse_cases',
    title: 'Cas Cliniques Synapse ECOS (Simulation IA)',
    shortTitle: 'Cas Cliniques ECOS',
    category: 'pedagogy',
    categoryLabel: 'Pédagogie & Concours',
    workflowFile: 'medsina_synapse_case_generator.yml',
    script: 'scripts/automation/generate_synapse_clinical_case.py',
    description: 'Simulation interactive de cas clinique d\'examen ECOS avec diagnostic différentiel, examens complémentaires ciblés et grille d\'évaluation.',
    defaultCadence: '2 fois par jour (12h & 18h UTC)',
    badgeColor: 'bg-purple-500/10 text-purple-600 dark:text-purple-400 border-purple-200 dark:border-purple-900',
    accentColor: '#9333ea',
    iconName: 'Activity',
    inputs: [
      {
        key: 'reason',
        label: 'Motif ou Thème du cas clinique (optionnel)',
        placeholder: 'ex: Douleur thoracique aiguë aux urgences',
        defaultValue: 'Génération manuelle de cas clinique Synapse ECOS',
        type: 'text',
      },
    ],
  },
  {
    id: 'pearl',
    title: 'Perles du Jour & Pièges Concours Résidanat',
    shortTitle: 'Perles & Pièges QCM',
    category: 'pedagogy',
    categoryLabel: 'Pédagogie & Concours',
    workflowFile: 'medsina_pearl.yml',
    script: 'scripts/automation/medsina_agent.py --pearl',
    description: 'Règle clinique vitale de garde et question piège typique de QCM à fort pouvoir discriminant pour le concours de résidanat.',
    defaultCadence: 'Tous les jours à 03h53 UTC',
    badgeColor: 'bg-amber-500/10 text-amber-600 dark:text-amber-400 border-amber-200 dark:border-amber-900',
    accentColor: '#f59e0b',
    iconName: 'Lightbulb',
    inputs: [
      {
        key: 'course_id',
        label: 'ID du Cours Cible (optionnel)',
        placeholder: 'ex: Blida_PNEUMOLOGIE_ASTHME',
        type: 'text',
      },
    ],
  },
  {
    id: 'course_bundles',
    title: 'Livrets Tout-en-Un Résidanat 2027 (Édition)',
    shortTitle: 'Livrets Tout-en-Un',
    category: 'pedagogy',
    categoryLabel: 'Pédagogie & Concours',
    workflowFile: 'generate_course_bundles.yml',
    script: 'scripts/automation/generate_residanat_course_bundle.py',
    description: 'Compile le livret de révision complet : Polycopié officiel Faculté de Blida + Fiche de synthèse + QCMs d\'entraînement + Grille du corrigé type avec diffusion Google Drive.',
    defaultCadence: 'Tous les soirs à 02h00 UTC & Manuel',
    badgeColor: 'bg-indigo-500/10 text-indigo-600 dark:text-indigo-400 border-indigo-200 dark:border-indigo-900',
    accentColor: '#6366f1',
    iconName: 'FileText',
    inputs: [
      {
        key: 'course_id',
        label: 'ID du Cours Cible (ou "all")',
        placeholder: 'ex: Blida_HEPATO_GASTRO_ENTEROLOGIE_CANCER_DU_PANCREAS',
        defaultValue: 'all',
        type: 'text',
      },
      {
        key: 'limit',
        label: 'Nombre maximum de cours à traiter',
        defaultValue: '15',
        type: 'text',
      },
    ],
  },
  {
    id: 'course_mindmaps',
    title: 'Cartes Mentales & Mindmaps Visuelles SVG/JSON',
    shortTitle: 'Mindmaps Visuelles',
    category: 'pedagogy',
    categoryLabel: 'Pédagogie & Concours',
    workflowFile: 'generate_course_mindmaps.yml',
    script: 'scripts/automation/generate_course_mindmaps.py',
    description: 'Analyse sémantique des cours et génération automatique d\'arborescences de mémorisation visuelle et schémas conceptuels interactifs synchronisés sur Supabase et Drive.',
    defaultCadence: 'Quotidien & Déclenchement Repo',
    badgeColor: 'bg-teal-500/10 text-teal-600 dark:text-teal-400 border-teal-200 dark:border-teal-900',
    accentColor: '#14b8a6',
    iconName: 'GitBranch',
    inputs: [
      {
        key: 'course_id',
        label: 'ID du Cours Cible (ou "all")',
        placeholder: 'all',
        defaultValue: 'all',
        type: 'text',
      },
      {
        key: 'limit',
        label: 'Limite de cours',
        defaultValue: '10',
        type: 'text',
      },
    ],
  },

  // --- 2. CLINIQUE, URGENCES & PHARMACOLOGIE (4 agents) ---
  {
    id: 'cat',
    title: 'Conduites à Tenir Cliniques (CAT d\'Urgences)',
    shortTitle: 'CAT Urgences',
    category: 'clinical',
    categoryLabel: 'Clinique & Urgences',
    workflowFile: 'medsina_cat.yml',
    script: 'scripts/automation/medsina_agent.py --cat',
    description: 'Génération d\'arbres décisionnels d\'urgences médicales et protocoles de prise en charge hospitalière selon recommandations SFMU, SRLF et HAS sans duplication.',
    defaultCadence: 'Toutes les 6 heures (Autonome)',
    badgeColor: 'bg-rose-500/10 text-rose-600 dark:text-rose-400 border-rose-200 dark:border-rose-900',
    accentColor: '#ef4444',
    iconName: 'AlertTriangle',
    inputs: [
      {
        key: 'course_id',
        label: 'ID du Cours Cible pour la CAT (optionnel)',
        placeholder: 'ex: Blida_NEUROLOGIE_COMA',
        type: 'text',
      },
    ],
  },
  {
    id: 'drugs',
    title: 'Codex Urgences & DCI Algérie (Vidal National)',
    shortTitle: 'Codex DCI Algérie',
    category: 'clinical',
    categoryLabel: 'Clinique & Urgences',
    workflowFile: 'medsina_drugs.yml',
    script: 'scripts/automation/medsina_agent.py --drugs',
    description: 'Monographie posologique, dilutions d\'urgence, contre-indications et formes galéniques disponibles en Algérie (Nomenclature Ministère de la Santé Saidal / PCH).',
    defaultCadence: 'Toutes les 8 heures (Autonome)',
    badgeColor: 'bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 border-emerald-200 dark:border-emerald-900',
    accentColor: '#10b981',
    iconName: 'Pill',
    inputs: [
      {
        key: 'dci',
        label: 'DCI du Médicament Cible (optionnel)',
        placeholder: 'ex: Adrénaline, Labetalol, Furosémide',
        type: 'text',
      },
    ],
  },
  {
    id: 'mementos',
    title: 'Mémentos de Garde Hospitalière Réflexe',
    shortTitle: 'Mémentos Garde',
    category: 'clinical',
    categoryLabel: 'Clinique & Urgences',
    workflowFile: 'medsina_mementos.yml',
    script: 'scripts/automation/medsina_agent.py --memento',
    description: 'Fiche réflexe pratique d\'intervention chronologique minute par minute pour les gardes aux urgences, réanimation et déchoquage.',
    defaultCadence: 'Toutes les 8 heures (Autonome)',
    badgeColor: 'bg-violet-500/10 text-violet-600 dark:text-violet-400 border-violet-200 dark:border-violet-900',
    accentColor: '#8b5cf6',
    iconName: 'Clock',
    inputs: [
      {
        key: 'memento',
        label: 'Thème réflexe de garde (optionnel)',
        placeholder: 'ex: OAP Flash, État de Mal Épileptique, Choc Anaphylactique',
        type: 'text',
      },
    ],
  },
  {
    id: 'lab',
    title: 'Normes Biologiques de Référence & Constantes',
    shortTitle: 'Normes Biologie',
    category: 'clinical',
    categoryLabel: 'Clinique & Urgences',
    workflowFile: 'medsina_lab.yml',
    script: 'scripts/automation/medsina_agent.py --lab',
    description: 'Monographie de biologie clinique : valeurs physiologiques, seuils d\'urgence vitale, conduite à tenir devant perturbation et pièges de concours.',
    defaultCadence: 'Toutes les 8 heures (Autonome)',
    badgeColor: 'bg-cyan-500/10 text-cyan-600 dark:text-cyan-400 border-cyan-200 dark:border-cyan-900',
    accentColor: '#06b6d4',
    iconName: 'FlaskConical',
    inputs: [
      {
        key: 'lab',
        label: 'Paramètre biologique spécifique (optionnel)',
        placeholder: 'ex: Troponine, D-Dimères, Lactates, Procalcitonine',
        type: 'text',
      },
    ],
  },

  // --- 3. MARKETING, COMMUNAUTÉ & RÉSEAUX (3 agents) ---
  {
    id: 'facebook',
    title: 'Publication Multicanal Facebook & Telegram',
    shortTitle: 'Réseaux Sociaux Multi',
    category: 'marketing',
    categoryLabel: 'Marketing & Réseaux',
    workflowFile: 'medsina_facebook.yml',
    script: 'scripts/automation/facebook_post_generator.py',
    description: 'Génère des infographies médicales 1080x1080 haute définition et publie directement sur les 3 pages Facebook officielles (Medsina, Résidanat Blida, CAT Urgences) et Telegram.',
    defaultCadence: '3 fois par jour (08h, 13h, 17h UTC)',
    badgeColor: 'bg-sky-500/10 text-sky-600 dark:text-sky-400 border-sky-200 dark:border-sky-900',
    accentColor: '#1877f2',
    iconName: 'Share2',
    inputs: [
      {
        key: 'type',
        label: 'Visée du post',
        defaultValue: 'auto',
        type: 'select',
        options: ['auto', 'commercial', 'medical', 'qcm'],
      },
    ],
  },
  {
    id: 'student_life',
    title: 'Vie Réelle de l\'Étudiant (MedsinaTeacher 1e-6e)',
    shortTitle: 'Tuteur Externat 1e-6e',
    category: 'marketing',
    categoryLabel: 'Marketing & Réseaux',
    workflowFile: 'medsina_student_life.yml',
    script: 'scripts/automation/medsina_student_life_agent.py',
    description: 'Simule les 3 phases de la journée d\'un externe : lit du malade le matin, amphi et piège d\'EMD à midi, et défi flash de révision le soir diffusés sur FB et Telegram.',
    defaultCadence: '3 fois par jour (08h, 14h, 19h Algérie)',
    badgeColor: 'bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 border-emerald-200 dark:border-emerald-900',
    accentColor: '#059669',
    iconName: 'GraduationCap',
    inputs: [
      {
        key: 'year',
        label: 'Année ciblée (1 à 6, all, auto)',
        defaultValue: 'auto',
        type: 'select',
        options: ['auto', 'all', '1', '2', '3', '4', '5', '6'],
      },
    ],
  },
  {
    id: 'promo_hunter',
    title: 'Chasseur Promo Telegram & Assistant Entraide',
    shortTitle: 'Chasseur Promo & Entraide',
    category: 'marketing',
    categoryLabel: 'Marketing & Réseaux',
    workflowFile: 'medsina_promo_hunter.yml',
    script: 'scripts/automation/telegram_promo_hunter.py',
    description: 'Recherche les questions médicales et demandes de cours sur les groupes Telegram d\'étudiants et commentaires Facebook, et poste des réponses pédagogiques avec liens MedSina.',
    defaultCadence: 'À la demande & Quotidien',
    badgeColor: 'bg-blue-500/10 text-blue-600 dark:text-blue-400 border-blue-200 dark:border-blue-900',
    accentColor: '#2563eb',
    iconName: 'MessageSquare',
    inputs: [
      {
        key: 'target',
        label: 'Mode d\'exécution (cible)',
        defaultValue: 'all',
        type: 'select',
        options: ['all', 'telegram', 'facebook'],
      },
    ],
  },

  // --- 4. VEILLE, RESSOURCES & DONNÉES (3 agents) ---
  {
    id: 'mbset_scanner',
    title: 'Scanner API & Simulations MBset (Concours Résidanat)',
    shortTitle: 'Scanner MBset API',
    category: 'resources',
    categoryLabel: 'Veille & Ressources',
    workflowFile: 'medsina_mbset_scanner.yml',
    script: 'scripts/automation/mbset_resource_scanner.py',
    description: 'Surveillance continue de l\'API MBset (api.mbset.com, app.mbset.com, banques de QCMs, simulations de concours résidanat et fiches de principes) avec validation admin.',
    defaultCadence: '2 fois par jour (08h30 & 20h30 UTC)',
    badgeColor: 'bg-indigo-500/10 text-indigo-600 dark:text-indigo-400 border-indigo-200 dark:border-indigo-900',
    accentColor: '#6366f1',
    iconName: 'Zap',
    inputs: [
      {
        key: 'limit_categories',
        label: 'Nombre de modules à scanner (par défaut 25)',
        placeholder: 'ex: 25',
        defaultValue: '25',
        type: 'text',
      },
      {
        key: 'limit_items',
        label: 'Nombre maximum de nouvelles ressources à injecter',
        placeholder: 'ex: 50',
        defaultValue: '50',
        type: 'text',
      },
    ],
  },
  {
    id: 'blida_scanner',
    title: 'Scanner Telegram & Google Drive (Médecine Blida)',
    shortTitle: 'Scanner Ressources Blida',
    category: 'resources',
    categoryLabel: 'Veille & Ressources',
    workflowFile: 'medsina_blida_scanner.yml',
    script: 'scripts/automation/blida_resource_scanner.py',
    description: 'Surveillance intelligente des canaux Telegram étudiants et dossiers Drive partagés pour détecter de nouveaux polycopiés, EMD et séries QCM Blida avec file d\'attente de validation.',
    defaultCadence: '2 fois par jour (07h15 & 19h15 UTC)',
    badgeColor: 'bg-amber-500/10 text-amber-600 dark:text-amber-400 border-amber-200 dark:border-amber-900',
    accentColor: '#d97706',
    iconName: 'Radio',
    inputs: [
      {
        key: 'target',
        label: 'Canal Telegram (@...) ou Lien Google Drive spécifique (optionnel)',
        placeholder: 'ex: @fmb_blida ou https://drive.google.com/... (laisser vide pour scan global)',
        type: 'text',
      },
    ],
  },
  {
    id: 'sync_temoignages',
    title: 'Témoignages & Retours Résidanat (Sync DB)',
    shortTitle: 'Témoignages Majors',
    category: 'resources',
    categoryLabel: 'Veille & Ressources',
    workflowFile: 'medsina_sync_temoignages_db.yml',
    script: 'scripts/automation/seed_temoignages_supabase.py',
    description: 'Extraction, validation et synchronisation dans Supabase des témoignages, méthodologies et conseils de préparation des majors des promotions antérieures.',
    defaultCadence: 'À chaque mise à jour & Manuel',
    badgeColor: 'bg-yellow-500/10 text-yellow-700 dark:text-yellow-400 border-yellow-200 dark:border-yellow-900',
    accentColor: '#ca8a04',
    iconName: 'Award',
  },

  // --- 5. SYSTÈME, DÉPLOIEMENT & RELEASE (4 agents) ---
  {
    id: 'automation',
    title: 'Console Médicale Globale (Tout-en-un Orchestré)',
    shortTitle: 'Console Globale Multi-Pass',
    category: 'system',
    categoryLabel: 'Système & Déploiement',
    workflowFile: 'medsina_automation.yml',
    script: 'scripts/automation/medsina_agent.py --all',
    description: 'Exécute l\'ensemble des agents médicaux en cascade (résumés, CAT, perles, urgences et posologies) en une seule passe coordonnée.',
    defaultCadence: 'Déclenchement Manuel Orchestré',
    badgeColor: 'bg-pink-500/10 text-pink-600 dark:text-pink-400 border-pink-200 dark:border-pink-900',
    accentColor: '#db2777',
    iconName: 'Zap',
    inputs: [
      {
        key: 'action',
        label: 'Tâche à exécuter',
        defaultValue: 'all',
        type: 'select',
        options: ['all', 'both', 'cat', 'pearl'],
      },
    ],
  },
  {
    id: 'update_guide',
    title: 'Guide Découverte & Pratique MedSina (PDF)',
    shortTitle: 'Générateur Guide PDF',
    category: 'system',
    categoryLabel: 'Système & Déploiement',
    workflowFile: 'medsina_update_guide.yml',
    script: 'scripts/automation/update_medsina_guide.py',
    description: 'Compile et synchronise automatiquement le guide officiel illustré de 64 pages (captures réelles, guide d\'installation hors-ligne) vers Google Drive et assets.',
    defaultCadence: 'À la demande & Après mise à jour',
    badgeColor: 'bg-indigo-500/10 text-indigo-600 dark:text-indigo-400 border-indigo-200 dark:border-indigo-900',
    accentColor: '#4f46e5',
    iconName: 'Book',
    inputs: [
      {
        key: 'gdrive_file_id',
        label: 'Google Drive File ID du guide PDF officiel',
        defaultValue: '1JfS2J40ywxHJFJyPTdZuyRHYQZvoj-nN',
        type: 'text',
      },
    ],
  },
  {
    id: 'deploy_admin',
    title: 'Déploiement Admin Dashboard sur Octenium',
    shortTitle: 'Déploiement Octenium',
    category: 'system',
    categoryLabel: 'Système & Déploiement',
    workflowFile: 'deploy_admin_dashboard_octenium.yml',
    script: 'scripts/automation/deploy_admin_dashboard_to_octenium.py',
    description: 'Compilation de l\'interface React / Vite / TS et téléversement direct par FTP chiffré vers l\'hébergement web medevsync.com/admin/.',
    defaultCadence: 'Automatique sur push main & Manuel',
    badgeColor: 'bg-teal-500/10 text-teal-600 dark:text-teal-400 border-teal-200 dark:border-teal-900',
    accentColor: '#0d9488',
    iconName: 'UploadCloud',
  },
  {
    id: 'release_pipeline',
    title: 'Pipeline Release Multiplateforme & OTA',
    shortTitle: 'Release & OTA Pipeline',
    category: 'system',
    categoryLabel: 'Système & Déploiement',
    workflowFile: 'medsina_release.yml',
    script: 'scripts/automation/patch_release_build_number.py',
    description: 'Compilation Flutter automatisée (APK Android, Setup Windows x64), checksums SHA-256 et publication OTA Supabase pour l\'ensemble des utilisateurs.',
    defaultCadence: 'À la sortie de version & Manuel',
    badgeColor: 'bg-rose-500/10 text-rose-600 dark:text-rose-400 border-rose-200 dark:border-rose-900',
    accentColor: '#e11d48',
    iconName: 'PackageCheck',
    inputs: [
      {
        key: 'version',
        label: 'Nom de Version (ex: 1.0.78)',
        defaultValue: '1.0.78',
        type: 'text',
      },
      {
        key: 'build_number',
        label: 'Numéro de Build (ex: 78)',
        defaultValue: '78',
        type: 'text',
      },
    ],
  },
];

const LOCAL_PAT_KEY = 'medsina_github_pat';
const LOCAL_REPO_KEY = 'medsina_github_repo';
export const DEFAULT_REPO = 'dochafedh26/medsina';

/**
 * Retrieve GitHub Personal Access Token
 * 1. Checks localStorage
 * 2. If absent, queries Supabase admin_system_settings
 */
export async function getGitHubToken(): Promise<string | null> {
  const local = localStorage.getItem(LOCAL_PAT_KEY);
  if (local && local.trim().length > 0) {
    return local.trim();
  }

  try {
    const { data, error } = await supabaseAdmin
      .from('admin_system_settings')
      .select('setting_value')
      .eq('setting_key', 'github_pat')
      .single();

    if (!error && data?.setting_value) {
      const token = data.setting_value.trim();
      localStorage.setItem(LOCAL_PAT_KEY, token);
      return token;
    }
  } catch (err) {
    console.warn('Failed to load GitHub PAT from Supabase:', err);
  }

  return null;
}

/**
 * Retrieve GitHub target repository
 */
export async function getGitHubRepo(): Promise<string> {
  const local = localStorage.getItem(LOCAL_REPO_KEY);
  if (local && local.trim().length > 0) {
    return local.trim();
  }

  try {
    const { data } = await supabaseAdmin
      .from('admin_system_settings')
      .select('setting_value')
      .eq('setting_key', 'github_repo')
      .single();

    if (data?.setting_value) {
      const repo = data.setting_value.trim();
      localStorage.setItem(LOCAL_REPO_KEY, repo);
      return repo;
    }
  } catch (_) {}

  return DEFAULT_REPO;
}

/**
 * Save GitHub Personal Access Token to Supabase & localStorage
 */
export async function saveGitHubToken(token: string): Promise<boolean> {
  const clean = token.trim();
  localStorage.setItem(LOCAL_PAT_KEY, clean);

  try {
    const { error } = await supabaseAdmin
      .from('admin_system_settings')
      .upsert({
        setting_key: 'github_pat',
        setting_value: clean,
        description: 'GitHub Personal Access Token pour les Agents IA',
        updated_at: new Date().toISOString(),
      });
    return !error;
  } catch (e) {
    console.error('Error saving GitHub PAT to Supabase:', e);
    return false;
  }
}

/**
 * Save GitHub target repo to Supabase & localStorage
 */
export async function saveGitHubRepo(repo: string): Promise<boolean> {
  const clean = repo.trim();
  localStorage.setItem(LOCAL_REPO_KEY, clean);

  try {
    const { error } = await supabaseAdmin
      .from('admin_system_settings')
      .upsert({
        setting_key: 'github_repo',
        setting_value: clean,
        description: 'Dépôt GitHub cible pour les workflows',
        updated_at: new Date().toISOString(),
      });
    return !error;
  } catch (e) {
    console.error('Error saving GitHub Repo to Supabase:', e);
    return false;
  }
}

/**
 * Fetch latest workflow runs from GitHub Actions
 */
export async function fetchGitHubWorkflowRuns(limit: number = 30): Promise<GitHubWorkflowRun[]> {
  const token = await getGitHubToken();
  const repo = await getGitHubRepo();

  if (!token) {
    return [];
  }

  try {
    const res = await fetch(`https://api.github.com/repos/${repo}/actions/runs?per_page=${limit}`, {
      headers: {
        Authorization: `Bearer ${token}`,
        Accept: 'application/vnd.github.v3+json',
      },
    });

    if (!res.ok) {
      console.warn(`GitHub Actions API returned ${res.status}: ${res.statusText}`);
      return [];
    }

    const data = await res.json();
    if (!data.workflow_runs || !Array.isArray(data.workflow_runs)) {
      return [];
    }

    return data.workflow_runs.map((r: any) => ({
      id: r.id,
      name: r.name || 'Workflow Run',
      workflowId: r.workflow_id,
      workflowFileName: r.path ? r.path.split('/').pop() : undefined,
      event: r.event || 'workflow_dispatch',
      status: r.status,
      conclusion: r.conclusion,
      createdAt: r.created_at,
      updatedAt: r.updated_at,
      htmlUrl: r.html_url,
      runNumber: r.run_number,
    }));
  } catch (err) {
    console.error('Error fetching GitHub workflow runs:', err);
    return [];
  }
}

/**
 * Trigger a GitHub Action workflow via workflow_dispatch
 */
export async function dispatchGitHubWorkflow(
  workflowFile: string,
  inputs?: Record<string, string>,
  ref: string = 'main'
): Promise<{ success: boolean; message: string; statusCode?: number }> {
  const token = await getGitHubToken();
  const repo = await getGitHubRepo();

  if (!token) {
    return {
      success: false,
      message: 'Clé GitHub PAT non configurée. Veuillez renseigner votre token d\'accès.',
    };
  }

  const cleanInputs: Record<string, string> = {};
  if (inputs) {
    Object.entries(inputs).forEach(([k, v]) => {
      if (v !== undefined && v !== null && v.toString().trim().length > 0) {
        cleanInputs[k] = v.toString().trim();
      }
    });
  }

  const payload: any = { ref };
  if (Object.keys(cleanInputs).length > 0) {
    payload.inputs = cleanInputs;
  }

  try {
    const res = await fetch(`https://api.github.com/repos/${repo}/actions/workflows/${workflowFile}/dispatches`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        Accept: 'application/vnd.github.v3+json',
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(payload),
    });

    if (res.status === 204) {
      return {
        success: true,
        statusCode: 204,
        message: `Agent [${workflowFile}] déclenché avec succès ! Traitement en cours sur les runners GitHub.`,
      };
    }

    let errorData = '';
    try {
      const json = await res.json();
      errorData = json.message || JSON.stringify(json);
    } catch (_) {
      errorData = await res.text();
    }

    return {
      success: false,
      statusCode: res.status,
      message: `Erreur GitHub (${res.status}) : ${errorData || res.statusText}`,
    };
  } catch (err: any) {
    return {
      success: false,
      message: `Erreur de connexion à l'API GitHub : ${err?.message || err}`,
    };
  }
}
