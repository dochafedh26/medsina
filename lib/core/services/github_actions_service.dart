import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_secrets.dart';
import '../network/supabase_service.dart';

class GitHubAgentDefinition {
  final String id;
  final String workflowFile;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String defaultCadence;
  final String? inputFieldKey;
  final String? inputFieldLabel;
  final String? inputFieldHint;

  const GitHubAgentDefinition({
    required this.id,
    required this.workflowFile,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.defaultCadence,
    this.inputFieldKey,
    this.inputFieldLabel,
    this.inputFieldHint,
  });
}

class GitHubWorkflowRun {
  final int id;
  final String name;
  final String event;
  final String status; // queued, in_progress, completed
  final String? conclusion; // success, failure, cancelled, null
  final DateTime createdAt;
  final DateTime updatedAt;
  final String htmlUrl;
  final int runNumber;

  const GitHubWorkflowRun({
    required this.id,
    required this.name,
    required this.event,
    required this.status,
    this.conclusion,
    required this.createdAt,
    required this.updatedAt,
    required this.htmlUrl,
    required this.runNumber,
  });

  bool get isRunning => status == 'in_progress' || status == 'queued';
  bool get isSuccess => conclusion == 'success';
  bool get isFailure => conclusion == 'failure';

  factory GitHubWorkflowRun.fromJson(Map<String, dynamic> json) {
    return GitHubWorkflowRun(
      id: json['id'] as int? ?? 0,
      name: json['name']?.toString() ?? 'Workflow Run',
      event: json['event']?.toString() ?? 'workflow_dispatch',
      status: json['status']?.toString() ?? 'queued',
      conclusion: json['conclusion']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      htmlUrl: json['html_url']?.toString() ?? '',
      runNumber: json['run_number'] as int? ?? 0,
    );
  }
}

class GitHubDispatchResult {
  final bool isSuccess;
  final String message;
  final int? statusCode;

  const GitHubDispatchResult({
    required this.isSuccess,
    required this.message,
    this.statusCode,
  });
}

/// Service allowing Admin to manage and trigger GitHub Actions workflows directly from Medsina.
class GitHubActionsService {
  static const String _tokenPrefKey = 'medsina_github_pat_token';
  static const String _repoPrefKey = 'medsina_github_repo';
  static const String defaultRepo = 'dochafedh26/medsina';
  static const String defaultBranch = 'main';

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );

  static const List<GitHubAgentDefinition> availableAgents = [
    GitHubAgentDefinition(
      id: 'summaries',
      workflowFile: 'medsina_summaries_4h.yml',
      title: 'Résumés Automatiques de Cours',
      description: 'Génère une fiche de synthèse officielle complète avec points clés et pièges de concours.',
      icon: Icons.menu_book_rounded,
      color: Color(0xFF0284C7),
      defaultCadence: 'Toutes les 4 heures (Autonome)',
      inputFieldKey: 'course_id',
      inputFieldLabel: 'ID du Cours Cible (optionnel)',
      inputFieldHint: 'ex: Blida_CARDIOLOGIE_HTA (laisser vide pour auto)',
    ),
    GitHubAgentDefinition(
      id: 'cat',
      workflowFile: 'medsina_cat.yml',
      title: 'Conduites à Tenir Cliniques (CAT)',
      description: 'Génération d\'arbres décisionnels d\'urgences et protocoles SFMU / HAS sans duplication.',
      icon: Icons.emergency_rounded,
      color: Color(0xFFEF4444),
      defaultCadence: 'Toutes les 6 heures (Autonome)',
      inputFieldKey: 'course_id',
      inputFieldLabel: 'ID du Cours Cible (optionnel)',
      inputFieldHint: 'ex: Blida_NEUROLOGIE_COMA (laisser vide pour auto)',
    ),
    GitHubAgentDefinition(
      id: 'pearl',
      workflowFile: 'medsina_pearl.yml',
      title: 'Perles du Jour & Pièges Concours',
      description: 'Règle clinique vitale en garde et question piège de QCM typique pour le concours.',
      icon: Icons.tips_and_updates_rounded,
      color: Color(0xFFF59E0B),
      defaultCadence: 'Tous les jours à 03h53 (Autonome)',
      inputFieldKey: 'course_id',
      inputFieldLabel: 'ID du Cours Cible (optionnel)',
      inputFieldHint: 'ex: Blida_PNEUMOLOGIE_ASTHME (laisser vide pour auto)',
    ),
    GitHubAgentDefinition(
      id: 'drugs',
      workflowFile: 'medsina_drugs.yml',
      title: 'Codex Urgences & DCI Algérie',
      description: 'Monographie posologique, dilutions et spécialités disponibles en Algérie (Saidal/PCH).',
      icon: Icons.medication_rounded,
      color: Color(0xFF10B981),
      defaultCadence: 'Toutes les 8 heures (Autonome)',
      inputFieldKey: 'dci',
      inputFieldLabel: 'DCI du Médicament (optionnel)',
      inputFieldHint: 'ex: Labetalol, Adrénaline (laisser vide pour auto)',
    ),
    GitHubAgentDefinition(
      id: 'mementos',
      workflowFile: 'medsina_mementos.yml',
      title: 'Mémentos de Garde Hospitalière',
      description: 'Fiche réflexe pratique d\'intervention chronologique pour les gardes aux urgences.',
      icon: Icons.nights_stay_rounded,
      color: Color(0xFF8B5CF6),
      defaultCadence: 'Toutes les 8 heures (Autonome)',
      inputFieldKey: 'memento',
      inputFieldLabel: 'Thème réflexe de garde (optionnel)',
      inputFieldHint: 'ex: OAP Flash, Status Épileptique (laisser vide pour auto)',
    ),
    GitHubAgentDefinition(
      id: 'automation',
      workflowFile: 'medsina_automation.yml',
      title: 'Console Médicale Globale (Tout-en-un)',
      description: 'Exécute l\'ensemble des agents médicaux en une seule passe ou selon sélection.',
      icon: Icons.rocket_launch_rounded,
      color: Color(0xFFEC4899),
      defaultCadence: 'Déclenchement Manuel',
      inputFieldKey: 'action',
      inputFieldLabel: 'Action cible (optionnel)',
      inputFieldHint: 'all, both, cat, pearl, drugs, summary...',
    ),
    GitHubAgentDefinition(
      id: 'facebook',
      workflowFile: 'medsina_facebook.yml',
      title: 'Générateur de Prompts IA Facebook (2x/Jour)',
      description: 'Génère le prompt d\'ingénierie IA complet pour Gemini/Claude/ChatGPT et notifie l\'Admin Dashboard avec bouton de copie en 1 clic (sans publication directe).',
      icon: Icons.campaign_rounded,
      color: Color(0xFF1877F2),
      defaultCadence: '2 fois par jour (08h00 & 17h00 UTC)',
      inputFieldKey: 'topic',
      inputFieldLabel: 'Thème Médical / Promotionnel (optionnel)',
      inputFieldHint: 'ex: OAP, Analyseur ordonnance (laisser vide pour auto)',
    ),
  ];

  /// Get configured Personal Access Token
  /// 1. Checks local SharedPreferences cache
  /// 2. If fresh install or empty, attempts to restore from Supabase Cloud (admin_system_settings)
  /// 3. Falls back to embedded AppSecrets.githubPat
  static Future<String?> getGitHubToken({bool forceRemote = false}) async {
    final prefs = await SharedPreferences.getInstance();

    if (!forceRemote && prefs.containsKey(_tokenPrefKey)) {
      final userToken = prefs.getString(_tokenPrefKey);
      if (userToken != null && userToken.trim().isNotEmpty) {
        return userToken.trim();
      }
      return null;
    }

    // Attempt recovery from Supabase Cloud (e.g. after app reinstallation or update)
    try {
      final remoteToken = await SupabaseService.getAdminSetting('github_pat');
      if (remoteToken != null && remoteToken.trim().isNotEmpty) {
        final cleanToken = remoteToken.trim();
        await prefs.setString(_tokenPrefKey, cleanToken);
        return cleanToken;
      }
    } catch (e) {
      debugPrint('GitHubActionsService: Note - Supabase remote token fetch skipped: $e');
    }

    if (AppSecrets.githubPat.isNotEmpty) {
      final cleanSecret = AppSecrets.githubPat.trim();
      await prefs.setString(_tokenPrefKey, cleanSecret);
      // Asynchronously seed to Supabase if not yet present
      SupabaseService.saveAdminSetting(
        'github_pat',
        cleanSecret,
        description: 'GitHub Personal Access Token pour les Agents IA',
      ).catchError((_) => false);
      return cleanSecret;
    }

    return null;
  }

  /// Save Personal Access Token
  /// Persists locally and automatically synchronizes to Supabase Cloud for durability
  static Future<void> setGitHubToken(String token, {bool syncSupabase = true}) async {
    final clean = token.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenPrefKey, clean);

    if (syncSupabase && clean.isNotEmpty) {
      try {
        await SupabaseService.saveAdminSetting(
          'github_pat',
          clean,
          description: 'GitHub Personal Access Token pour les Agents IA',
        );
      } catch (e) {
        debugPrint('GitHubActionsService: Erreur lors de la sauvegarde Supabase: $e');
      }
    }
  }

  /// Get configured repository (defaults to 'dochafedh26/medsina')
  /// Checks local cache, then Supabase Cloud, then defaultRepo
  static Future<String> getRepo({bool forceRemote = false}) async {
    final prefs = await SharedPreferences.getInstance();

    if (!forceRemote && prefs.containsKey(_repoPrefKey)) {
      final userRepo = prefs.getString(_repoPrefKey);
      if (userRepo != null && userRepo.trim().isNotEmpty) {
        return userRepo.trim();
      }
    }

    try {
      final remoteRepo = await SupabaseService.getAdminSetting('github_repo');
      if (remoteRepo != null && remoteRepo.trim().isNotEmpty) {
        final cleanRepo = remoteRepo.trim();
        await prefs.setString(_repoPrefKey, cleanRepo);
        return cleanRepo;
      }
    } catch (_) {}

    return defaultRepo;
  }

  /// Save custom repository
  /// Persists locally and automatically synchronizes to Supabase Cloud
  static Future<void> setRepo(String repo, {bool syncSupabase = true}) async {
    final clean = repo.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_repoPrefKey, clean);

    if (syncSupabase && clean.isNotEmpty) {
      try {
        await SupabaseService.saveAdminSetting(
          'github_repo',
          clean,
          description: 'Dépôt GitHub cible pour les workflows',
        );
      } catch (e) {
        debugPrint('GitHubActionsService: Erreur sauvegarde repo Supabase: $e');
      }
    }
  }

  /// Explicitly synchronize PAT and Repo from Supabase Cloud to local storage
  static Future<Map<String, String?>> syncFromSupabase() async {
    final token = await getGitHubToken(forceRemote: true);
    final repo = await getRepo(forceRemote: true);
    return {
      'token': token,
      'repo': repo,
    };
  }

  /// Check whether GitHub is configured
  static Future<bool> isConfigured() async {
    final token = await getGitHubToken();
    return token != null && token.isNotEmpty;
  }

  /// Dispatches a workflow on GitHub Actions
  static Future<GitHubDispatchResult> triggerWorkflow({
    required String workflowFileName,
    Map<String, dynamic>? inputs,
    String ref = defaultBranch,
  }) async {
    final token = await getGitHubToken();
    if (token == null || token.isEmpty) {
      return const GitHubDispatchResult(
        isSuccess: false,
        message: 'Clé GitHub PAT non configurée. Cliquez sur "Configurer GitHub" pour ajouter votre token.',
      );
    }

    final repo = await getRepo();
    final url = 'https://api.github.com/repos/$repo/actions/workflows/$workflowFileName/dispatches';

    final cleanInputs = <String, dynamic>{};
    if (inputs != null) {
      inputs.forEach((k, v) {
        if (v != null && v.toString().trim().isNotEmpty) {
          cleanInputs[k] = v.toString().trim();
        }
      });
    }

    final payload = {
      'ref': ref,
      if (cleanInputs.isNotEmpty) 'inputs': cleanInputs,
    };

    try {
      final response = await _dio.post(
        url,
        data: payload,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/vnd.github.v3+json',
            'X-GitHub-Api-Version': '2022-11-28',
          },
        ),
      );

      if (response.statusCode == 204) {
        return const GitHubDispatchResult(
          isSuccess: true,
          message: 'Agent GitHub déclenché avec succès ! L\'exécution est en cours de traitement sur les serveurs GitHub.',
          statusCode: 204,
        );
      } else {
        return GitHubDispatchResult(
          isSuccess: false,
          message: 'Réponse GitHub inattendue (${response.statusCode}) : ${response.data}',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      String err;
      if (status == 401) {
        err = 'Erreur 401 : Token GitHub non autorisé ou expiré.';
      } else if (status == 403) {
        err = 'Erreur 403 : Permissions insuffisantes sur le Token GitHub (permission "actions:write" requise).';
      } else if (status == 404) {
        err = 'Erreur 404 : Workflow "$workflowFileName" ou dépôt "$repo" introuvable.';
      } else if (status == 422) {
        String? serverMsg;
        if (e.response?.data is Map) {
          serverMsg = (e.response?.data as Map)['message']?.toString();
        } else if (e.response?.data is String) {
          serverMsg = e.response?.data.toString();
        }

        if (serverMsg != null && serverMsg.toLowerCase().contains('disabled')) {
          try {
            // Tentative de réactivation automatique du workflow sur GitHub
            final enableUrl = 'https://api.github.com/repos/$repo/actions/workflows/$workflowFileName/enable';
            await _dio.put(
              enableUrl,
              options: Options(
                headers: {
                  'Authorization': 'Bearer $token',
                  'Accept': 'application/vnd.github.v3+json',
                },
              ),
            );

            // Nouvelle tentative de déclenchement
            final retryResponse = await _dio.post(
              url,
              data: payload,
              options: Options(
                headers: {
                  'Authorization': 'Bearer $token',
                  'Accept': 'application/vnd.github.v3+json',
                  'X-GitHub-Api-Version': '2022-11-28',
                },
              ),
            );

            if (retryResponse.statusCode == 204) {
              return const GitHubDispatchResult(
                isSuccess: true,
                message: 'Le workflow était désactivé sur GitHub. Il a été réactivé automatiquement et lancé avec succès ! 🚀',
                statusCode: 204,
              );
            }
          } catch (retryErr) {
            debugPrint('GitHubActionsService: Réactivation auto échouée: $retryErr');
          }
          err = 'Le workflow "$workflowFileName" est actuellement désactivé sur GitHub ($serverMsg).';
        } else {
          err = serverMsg != null
              ? 'Erreur 422 : $serverMsg'
              : 'Erreur 422 : Entrées de workflow invalides ou branche inexistante.';
        }
      } else {
        err = 'Erreur réseau GitHub Actions : ${e.message}';
      }
      return GitHubDispatchResult(isSuccess: false, message: err, statusCode: status);
    } catch (e) {
      return GitHubDispatchResult(isSuccess: false, message: 'Exception: $e');
    }
  }

  /// Fetches recent workflow runs from GitHub Actions
  static Future<List<GitHubWorkflowRun>> fetchRecentRuns({
    String? workflowFileName,
    int perPage = 10,
  }) async {
    final token = await getGitHubToken();
    final repo = await getRepo();

    final url = workflowFileName != null
        ? 'https://api.github.com/repos/$repo/actions/workflows/$workflowFileName/runs?per_page=$perPage'
        : 'https://api.github.com/repos/$repo/actions/runs?per_page=$perPage';

    try {
      final headers = <String, String>{
        'Accept': 'application/vnd.github.v3+json',
        'X-GitHub-Api-Version': '2022-11-28',
      };
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await _dio.get(url, options: Options(headers: headers));
      if (response.statusCode == 200) {
        final list = (response.data['workflow_runs'] as List<dynamic>? ?? []);
        return list.map((item) => GitHubWorkflowRun.fromJson(item as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('GitHubActionsService fetchRecentRuns notice: $e');
      return [];
    }
  }
}

