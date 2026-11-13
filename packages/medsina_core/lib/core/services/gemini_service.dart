import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/app_secrets.dart';
import '../utils/medical_text_formatter.dart';

class GeminiService {
  // Configured Gemini API Key from environment or git-ignored secrets
  static String get apiKey {
    const envKey = String.fromEnvironment('GEMINI_API_KEY');
    if (envKey.isNotEmpty) return envKey;
    return AppSecrets.geminiApiKey;
  }

  // Active models with fallback cascade (Google Gemini 3.x / Flash / Argon)
  static const List<String> _modelCascade = [
    'gemini-3.8-flash',
    'gemini-3.5-flash-lite',
    'gemini-3.1-pro-preview',
    'gemini-4-argon',
  ];

  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';

  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 45),
  ));

  // Concurrency Limiter & Pacing Queue (FIFO Queue, 1 active request, 3-sec cooldown)
  static final List<Completer<void>> _requestQueue = [];
  static bool _isExecuting = false;
  static DateTime? _lastRequestFinishTime;
  static const Duration _pacingCooldown = Duration(milliseconds: 3000);

  static Future<T> _executeWithConcurrencyAndPacing<T>(Future<T> Function() task) async {
    final completer = Completer<void>();
    _requestQueue.add(completer);

    if (!_isExecuting && _requestQueue.length == 1) {
      completer.complete();
    }

    await completer.future;
    _isExecuting = true;

    try {
      if (_lastRequestFinishTime != null) {
        final elapsed = DateTime.now().difference(_lastRequestFinishTime!);
        if (elapsed < _pacingCooldown) {
          await Future.delayed(_pacingCooldown - elapsed);
        }
      }
      return await task();
    } finally {
      _lastRequestFinishTime = DateTime.now();
      _isExecuting = false;
      _requestQueue.remove(completer);
      if (_requestQueue.isNotEmpty) {
        _requestQueue.first.complete();
      }
    }
  }

  static Stream<T> _executeStreamWithPacing<T>(Stream<T> Function() streamFactory) async* {
    final completer = Completer<void>();
    _requestQueue.add(completer);

    if (!_isExecuting && _requestQueue.length == 1) {
      completer.complete();
    }

    await completer.future;
    _isExecuting = true;

    try {
      if (_lastRequestFinishTime != null) {
        final elapsed = DateTime.now().difference(_lastRequestFinishTime!);
        if (elapsed < _pacingCooldown) {
          await Future.delayed(_pacingCooldown - elapsed);
        }
      }
      yield* streamFactory();
    } finally {
      _lastRequestFinishTime = DateTime.now();
      _isExecuting = false;
      _requestQueue.remove(completer);
      if (_requestQueue.isNotEmpty) {
        _requestQueue.first.complete();
      }
    }
  }

  /// Medical Persona System Instruction with Grounding in medsina_ressources and Official Consensus
  static const String _medicalSystemPrompt = '''
Tu es MedsinaPilot, l'assistant IA médical officiel de Medsina, la plateforme médicale de référence pour les médecins et candidats au concours de résidanat de médecine (Facultés de Blida, Alger, Constantine, Oran).

RÈGLES FONDAMENTALES DE RECHERCHE ET DE CITATION DE SOURCES :
1. SOURCE PRIMAIRE OFFICIELLE (Google Drive "medsina_ressources") :
   - Tu es directement adossé à la bibliothèque officielle des 47 modules et 1 205 cours du concours de résidanat (stockés dans le dossier Google Drive "medsina_ressources").
   - Quand des cours correspondants issus de "medsina_ressources" te sont fournis dans le contexte, tu DOIS t'appuyer en priorité sur les définitions, classifications et conduites à tenir de ces cours officiels.
   - Mentionne toujours explicitement le nom du cours et son module pour rassurer le candidat sur la conformité de ta réponse au programme officiel.

2. AUTRES SOURCES FIABLES ET CONSENSUS INTERNATIONAUX :
   - Pour toute recommandation clinique, thérapeutique ou diagnostique, tu dois toujours t'aligner sur les consensus les plus récents et fiables :
     * HAS (Haute Autorité de Santé)
     * ESC (European Society of Cardiology)
     * GINA (Global Initiative for Asthma) et GOLD (BPCO)
     * KDIGO (Néphrologie)
     * SFMU (Société Française de Médecine d'Urgence) et SRLF (Réanimation)
     * Collèges Universitaires des Enseignants Français (ECN / EDN)
     * Consensus et Recommandations Nationales Algériennes.

3. STRUCTURE DE RÉPONSE CLINIQUE & PÉDAGOGIQUE :
   - Réponse claire, exhaustive et structurée (définition, physiopathologie, diagnostic, prise en charge).
   - Analyse détaillée de chaque proposition de QCM : justifie pourquoi chaque proposition est VRAIE ou FAUSSE.
   - Mets en avant les pièges classiques d'examen et les subtilités de formulation.
   - SECTION FINALE OBLIGATOIRE "### 📚 Sources & Références Fiables" :
     * 🎓 **Cours Officiel Medsina** : [Nom du cours] (*Dossier medsina_ressources • Module [Nom du module]*)
     * 🏛️ **Consensus & Sociétés Savantes** : [Consensus exact avec année, ex: ESC 2024 / HAS 2023]
     * 💡 **Point-clé Résidanat** : [Mots-clés ou piège d'examen récurrent au concours]

4. FORMATAGE DU TEXTE ET DES UNITÉS (RÈGLE STRICTE) :
   - N'UTILISE JAMAIS de syntaxe LaTeX, ni de symboles dollar (\$...\$ ou \$\$...\$\$).
   - N'utilise JAMAIS de commandes LaTeX telles que \\ge, \\le, \\text{...}, \\mathrm{...}, \\pm, \\times, \\mu.
   - Écris TOUJOURS les unités et symboles mathématiques directement en texte Unicode clair et naturel: "≥", "≤", "±", "×", "µg", "°C", "mm", "mV", "bpm", "%", "/".
   - Par exemple, écris: "≥ 1 mm (0,1 mV)" et JAMAIS "\$\\ge 1 \\text{ mm}\$".
''';

  /// Optional catalog provider injected by study/residanat packages.
  static List<({String moduleName, List<String> courseNames})> Function()? courseCatalogProvider;

  /// Search across all 1,209 courses in medsina_ressources for the best matching curriculum courses
  static List<String> _findMatchingCoursesInDrive(String query, {String? courseHint, String? moduleHint}) {
    final catalog = courseCatalogProvider?.call() ?? const [];
    final List<String> found = [];

    // If explicit course hint provided, prioritize it
    if (courseHint != null && courseHint.isNotEmpty) {
      final moduleName = moduleHint ?? 'Résidanat';
      found.add('• Cours Prioritaire : "$courseHint" (Module: $moduleName, dossier medsina_ressources/courses/$moduleName)');
    }

    // Extract significant keywords (length >= 4) from query
    final cleanQuery = query.toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9àâäéèêëîïôöùûüç]'), ' ');
    final words = cleanQuery.split(' ').where((w) => w.length >= 4).toSet();

    if (words.isEmpty && found.isNotEmpty) return found;

    // Search through all modules and courses
    int count = found.length;
    for (final m in catalog) {
      for (final cName in m.courseNames) {
        if (found.any((f) => f.contains(cName))) continue;

        final cNameLower = cName.toLowerCase();
        int score = 0;
        for (final w in words) {
          if (cNameLower.contains(w)) score++;
        }

        if (score > 0) {
          found.add('• Référence Curriculum : "$cName" (Module: ${m.moduleName}, disponible sur Google Drive medsina_ressources)');
          count++;
          if (count >= 4) break;
        }
      }
      if (count >= 4) break;
    }

    return found;
  }

  /// Send prompt to Gemini API with Medsina Drive RAG Grounding
  static Future<String> generateMedicalResponse({
    required String prompt,
    String? contextInfo,
    String? courseName,
    String? moduleId,
  }) async {
    return _executeWithConcurrencyAndPacing(() async {
      // 1. Retrieve matching official courses from medsina_ressources
      final matchingResources = _findMatchingCoursesInDrive(
        '$prompt ${contextInfo ?? ""}',
        courseHint: courseName,
        moduleHint: moduleId,
      );

      String groundingContext = '';
      if (matchingResources.isNotEmpty) {
        groundingContext = '\n\n[RESSOURCES OFFICIELLES DU PROGRAMME DANS GOOGLE DRIVE (medsina_ressources)]:\n${matchingResources.join("\n")}';
      }

      final fullPrompt = contextInfo != null
          ? '$_medicalSystemPrompt$groundingContext\n\n[CONTEXTE DE LA QUESTION OU DU PATIENT]:\n$contextInfo\n\n[QUESTION DE L\'ÉTUDIANT]:\n$prompt'
          : '$_medicalSystemPrompt$groundingContext\n\n[QUESTION DE L\'ÉTUDIANT]:\n$prompt';

      final requestData = {
        'contents': [
          {
            'parts': [
              {'text': fullPrompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.25,
          'maxOutputTokens': 8192,
        }
      };

      // Try model cascade until successful
      for (final model in _modelCascade) {
        try {
          final url = '$_baseUrl/$model:generateContent?key=$apiKey';
          final response = await _dio.post(
            url,
            options: Options(headers: {'Content-Type': 'application/json'}),
            data: requestData,
          );

          if (response.statusCode == 200) {
            final data = response.data is String ? jsonDecode(response.data) : response.data;
            final candidates = data['candidates'] as List?;
            if (candidates != null && candidates.isNotEmpty) {
              final parts = candidates[0]['content']?['parts'] as List?;
              if (parts != null && parts.isNotEmpty) {
                final raw = parts[0]['text'] as String?;
                if (raw != null) {
                  return MedicalTextFormatter.clean(raw);
                }
                return 'Aucune réponse générée.';
              }
            }
          }
        } catch (e) {
          debugPrint('Gemini Exception with $model: $e');
        }
      }

      return 'Désolé, MedsinaPilot est momentanément indisponible. Veuillez réessayer dans quelques instants.';
    });
  }

  /// QCM Explanation Helper with Medsina Drive & Consensus Grounding
  static Future<String> explainQcm({
    required String questionTitle,
    required List<String> optionsText,
    required List<String> correctKeys,
    required String userQuery,
    String? courseName,
    String? moduleId,
  }) async {
    final context = '''
Question d'examen: $questionTitle
Propositions:
${optionsText.join('\n')}
Bonne(s) réponse(s) officielle(s): ${correctKeys.join(', ')}
${courseName != null ? 'Cours officiel rattaché: $courseName' : ''}
${moduleId != null ? 'Module d\'enseignement: $moduleId' : ''}
''';

    return await generateMedicalResponse(
      prompt: userQuery,
      contextInfo: context,
      courseName: courseName,
      moduleId: moduleId,
    );
  }

  /// Clinical Decision & CAT Helper with Medsina Drive & Consensus Grounding
  static Future<String> getClinicalAdvice({
    required String clinicalSituation,
    required String userQuery,
    String? courseName,
    String? moduleId,
  }) async {
    return await generateMedicalResponse(
      prompt: userQuery,
      contextInfo: 'Situation Clinique: $clinicalSituation',
      courseName: courseName,
      moduleId: moduleId,
    );
  }

  /// Streaming version — yields partial text chunks as they arrive from Gemini SSE
  static Stream<String> streamMedicalResponse({
    required String prompt,
    String? contextInfo,
    String? courseName,
    String? moduleId,
  }) {
    return _executeStreamWithPacing(() async* {
      final matchingResources = _findMatchingCoursesInDrive(
        '$prompt ${contextInfo ?? ""}',
        courseHint: courseName,
        moduleHint: moduleId,
      );
      String groundingContext = '';
      if (matchingResources.isNotEmpty) {
        groundingContext = '\n\n[RESSOURCES OFFICIELLES DU PROGRAMME DANS GOOGLE DRIVE (medsina_ressources)]:\n${matchingResources.join("\n")}';
      }
      final fullPrompt = contextInfo != null
          ? '$_medicalSystemPrompt$groundingContext\n\n[CONTEXTE DE LA QUESTION OU DU PATIENT]:\n$contextInfo\n\n[QUESTION DE L\'ÉTUDIANT]:\n$prompt'
          : '$_medicalSystemPrompt$groundingContext\n\n[QUESTION DE L\'ÉTUDIANT]:\n$prompt';

      final requestData = {
        'contents': [
          {
            'parts': [
              {'text': fullPrompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.25,
          'maxOutputTokens': 8192,
        }
      };

      for (final model in _modelCascade) {
        bool modelSucceeded = false;
        try {
          final url = '$_baseUrl/$model:streamGenerateContent?alt=sse&key=$apiKey';
          final response = await _dio.post<ResponseBody>(
            url,
            options: Options(
              headers: {'Content-Type': 'application/json'},
              responseType: ResponseType.stream,
            ),
            data: requestData,
          );

          if (response.data != null) {
            final stream = response.data!.stream
                .cast<List<int>>()
                .transform(utf8.decoder)
                .transform(const LineSplitter());

            await for (final line in stream) {
              if (!line.startsWith('data: ')) continue;
              final jsonStr = line.substring(6).trim();
              if (jsonStr.isEmpty || jsonStr == '[DONE]') continue;
              try {
                final chunk = jsonDecode(jsonStr) as Map<String, dynamic>;
                final candidates = chunk['candidates'] as List?;
                if (candidates == null || candidates.isEmpty) continue;
                final parts = candidates[0]['content']?['parts'] as List?;
                if (parts == null || parts.isEmpty) continue;
                final text = parts[0]['text'] as String?;
                if (text != null && text.isNotEmpty) {
                  yield MedicalTextFormatter.clean(text);
                  modelSucceeded = true;
                }
              } catch (_) {}
            }
          }
          if (modelSucceeded) return;
        } catch (e) {
          debugPrint('Gemini streaming exception with $model: $e');
        }
      }

      yield 'Désolé, MedsinaPilot est momentanément indisponible. Veuillez réessayer dans quelques instants.';
    });
  }

  /// Streaming QCM explanation
  static Stream<String> streamExplainQcm({
    required String questionTitle,
    required List<String> optionsText,
    required List<String> correctKeys,
    required String userQuery,
    String? courseName,
    String? moduleId,
  }) {
    final context = '''
Question d'examen: $questionTitle
Propositions:
${optionsText.join('\n')}
Bonne(s) réponse(s) officielle(s): ${correctKeys.join(', ')}
${courseName != null ? 'Cours officiel rattaché: $courseName' : ''}
${moduleId != null ? 'Module d\'enseignement: $moduleId' : ''}
''';
    return streamMedicalResponse(
      prompt: userQuery,
      contextInfo: context,
      courseName: courseName,
      moduleId: moduleId,
    );
  }

  /// Streaming clinical advice
  static Stream<String> streamClinicalAdvice({
    required String clinicalSituation,
    required String userQuery,
    String? courseName,
    String? moduleId,
  }) {
    return streamMedicalResponse(
      prompt: userQuery,
      contextInfo: 'Situation Clinique: $clinicalSituation',
      courseName: courseName,
      moduleId: moduleId,
    );
  }

  /// Advanced Cross-Parameter Biological Lab Results Analyzer with Gemini Streaming
  static Stream<String> streamLabAnalysis({
    required String labData,
    String? patientAge,
    String? patientSex,
    String? clinicalContext,
  }) {
    final patientInfo = [
      if (patientAge != null && patientAge.isNotEmpty) 'Âge: $patientAge ans',
      if (patientSex != null && patientSex.isNotEmpty) 'Sexe: $patientSex',
      if (clinicalContext != null && clinicalContext.isNotEmpty) 'Contexte/Motif: $clinicalContext',
    ].join(' | ');

    final prompt = '''
Tu es un médecin biologiste hospitalier et réanimateur senior expert en Algérie (CHU d'Alger, Blida, Oran, Constantine) et enseignant préparateur au concours de résidanat.
Analyse ce bilan biologique de manière rigoureuse, croisée et immédiatement actionnable.

[DONNÉES DU PATIENT]:
${patientInfo.isEmpty ? 'Non précisé' : patientInfo}

[RÉSULTATS BIOLOGIQUES REÇUS]:
$labData

Directives de rédaction :
Rédige une analyse médicale structurée en Markdown enrichi avec les sections suivantes obligatoires :

### 1. 🚨 Alertes Vitales & Seuils Critiques
(Indique immédiatement les valeurs engageant le pronostic vital ou justifiant une action dans l'heure : kaliémie extrême, acidose sévère, thrombopénie majeure, cytolyse fulminante, lactates élevés, etc. Si tout est stable, indique « Aucune anomalie critique immédiate »).

### 2. 📊 Interprétation Croisée des Paramètres
(Dresse la liste des anomalies avec leur statut : [BAS 🔻], [NORMAL ✅], [ÉLEVÉ 🔺]. Ne te contente pas d'isoler les chiffres : mets-les en relation systémique : ex: anémie + VGM bas + ferritine basse = anémie microcytaire ferriprive ; Na bas + glycémie très haute = fausse hyponatrémie par hyperosmolarité).

### 3. 🧮 Calculs & Formules Clés Appliquées
(Détaille les calculs pertinents :
- Trou Anionique Plasmatique = Na - (Cl + HCO3) [Norme : 12 ± 4 mmol/L]
- Trou Osmolaire si applicable
- Natrémie Corrigée de Katz si hyperglycémie
- Calcémie Corrigée sur l'albumine si hypoalbuminémie
- DFG estimé CKD-EPI ou Cockcroft si âge/créatinine disponibles
- Ratio De Ritis (ASAT / ALAT) si bilan hépatique).

### 4. 🧠 Diagnostic Syndromique & Hypothèses Étiologiques
(Formule une conclusion syndromique claire : ex: « Acidose métabolique à trou anionique élevé compatible avec une décompensation acido-cétosique diabétique inaugurale sur terrain d'insuffisance rénale fonctionnelle ». Détaille les diagnostics différentiels par ordre de probabilité).

### 5. 🎯 Conduite à Tenir Clinique Immédiate (CAT)
(Protocole thérapeutique d'urgence : solutés de réhydratation, insulinothérapie IVSE, correction hydro-électrolytique prudente, bilans complémentaires urgents à prélever sans délai).

### 6. 💡 Pièges du Concours de Résidanat & Vigilance Pré-analytique
(Souligne les pièges classiques posés aux dossiers de résidanat et les artefacts de laboratoire : fausse hyperkaliémie sur hémolyse du tube ou garrot trop serré, prélèvement sur bras perfusé, etc.).
''';

    return streamMedicalResponse(
      prompt: prompt,
      contextInfo: 'Analyse de Bilan Biologique Hospitalier & Résidanat Algérie',
    );
  }

  /// Fast Structured Audit for Prescription & Terrain Safety (0 False Negatives)
  static Future<Map<String, dynamic>?> auditPrescriptionWithAi({
    required List<String> drugs,
    required List<String> terrains,
  }) async {
    return _executeWithConcurrencyAndPacing(() async {
      final prompt = '''
Tu es le moteur pharmacologique officiel Vidal, ANSM et MSPRH de Medsina.
RÈGLE ABSOLUE : ZÉRO FAUX NÉGATIF. PAS DROIT À L'ERREUR EN SÉCURITÉ CLINIQUE ET THÉRAPEUTIQUE.
Analyse la sécurité de cette prescription :
- Médicaments prescrits : ${drugs.join(', ')}
- Terrains / Profils patient : ${terrains.isEmpty ? 'Aucun terrain renseigné' : terrains.join(', ')}

Recherche rigoureusement :
1. Les interactions médicamenteuses directes ou indirectes entre les molécules prescrites (Contre-indication > Association déconseillée > Précaution d'emploi > À prendre en compte).
2. Les contre-indications absolues ou relatives entre chaque médicament et les terrains patients indiqués.

Réponds STRICTEMENT sous forme d'un objet JSON valide avec cette structure exacte (sans aucun bloc markdown, sans texte additionnel) :
{
  "has_alert": true,
  "is_drug_interaction": true,
  "drug_a": "Nom commercial ou DCI du 1er médicament concerné",
  "drug_b": "Nom commercial ou DCI du 2e médicament concerné (si interaction entre deux molécules)",
  "severity": "contraindicated", // "contraindicated", "disadvised", "precaution", "info"
  "severity_level": 4, // 4 pour CI, 3 pour Déconseillé, 2 pour Précaution, 1 pour Info
  "title": "Titre clinique précis de l'alerte (ex: Interaction Anticoagulant + AINS : Risque hémorragique majeur)",
  "warning": "Mécanisme pharmacologique précis et danger clinique encouru",
  "recommendation": "Conduite à tenir immédiate (arrêt, adaptation posologique, molécule de substitution)",
  "source": "Vidal / ANSM"
}
Si absolument AUCUN risque n'existe, renvoie STRICTEMENT :
{"has_alert": false, "is_drug_interaction": false, "severity": "info", "severity_level": 1, "title": "Aucune interaction ni anomalie détectée", "warning": "", "recommendation": "", "source": "Vidal / ANSM"}
''';

      final requestData = {
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.1,
          'responseMimeType': 'application/json',
        }
      };

      for (final model in _modelCascade) {
        try {
          final url = '$_baseUrl/$model:generateContent?key=$apiKey';
          final response = await _dio.post(
            url,
            options: Options(headers: {'Content-Type': 'application/json'}),
            data: requestData,
          );

          if (response.statusCode == 200) {
            final data = response.data is String ? jsonDecode(response.data) : response.data;
            final candidates = data['candidates'] as List?;
            if (candidates != null && candidates.isNotEmpty) {
              final parts = candidates[0]['content']?['parts'] as List?;
              if (parts != null && parts.isNotEmpty) {
                final raw = parts[0]['text'] as String?;
                if (raw != null) {
                  var clean = raw.replaceAll('```json', '').replaceAll('```', '').trim();
                  final firstBrace = clean.indexOf('{');
                  final lastBrace = clean.lastIndexOf('}');
                  if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
                    clean = clean.substring(firstBrace, lastBrace + 1);
                  }
                  return jsonDecode(clean) as Map<String, dynamic>;
                }
              }
            }
          }
        } catch (e) {
          debugPrint('Gemini audit exception with $model: $e');
        }
      }
      return null;
    });
  }

  static final Map<String, Map<String, dynamic>> _monographCache = {};

  /// Generates a complete structured clinical drug monograph (Vidal / ANSM / MSPRH)
  static Future<Map<String, dynamic>?> fetchDrugMonographWithAi({
    required String drugName,
    String? dci,
    String? dosage,
    String? form,
  }) async {
    final cacheKey = '${drugName.toUpperCase()}_${(dci ?? "").toUpperCase()}';
    if (_monographCache.containsKey(cacheKey)) {
      return _monographCache[cacheKey];
    }

    return _executeWithConcurrencyAndPacing(() async {
      final prompt = '''
Tu es le référentiel pharmacologique officiel Vidal, ANSM et Nomenclature Algérienne MSPRH de Medsina.
Rédige une fiche monographie clinique complète, précise et pratique pour le médicament suivant :
- Nom commercial / Médicament : $drugName
- DCI (Molécule active) : ${dci != null && dci.isNotEmpty ? dci : 'À préciser'}
- Dosage / Forme : ${[if (dosage != null && dosage.isNotEmpty) dosage, if (form != null && form.isNotEmpty) form].join(' ')}

Réponds STRICTEMENT sous forme d'un objet JSON valide avec cette structure exacte (sans aucun bloc markdown, sans symboles LaTeX) :
{
  "pharmacological_class": "Classe pharmacothérapeutique précise (ex: Anticoagulant oral de type Anti-Vitamine K)",
  "description": "Description claire de la molécule, de son mécanisme d'action pharmacologique et de son délai/durée d'action.",
  "indications": [
    "Indication thérapeutique principale 1",
    "Indication thérapeutique 2",
    "Indication thérapeutique 3"
  ],
  "posology_adult": "Posologie usuelle chez l'adulte, dose d'attaque/entretien, horaires et modalités pratiques d'administration.",
  "posology_pediatric_or_special": "Posologie pédiatrique (mg/kg/j) et/ou adaptation chez le sujet âgé, insuffisant rénal (DFG/ClCr) ou hépatique.",
  "contraindications": [
    "Contre-indication absolue ou relative 1",
    "Contre-indication 2"
  ],
  "side_effects_and_monitoring": "Effets indésirables principaux, signes de surdosage/toxicité et surveillance clinique/biologique recommandée (ex: INR, ionogramme, créatinine, ECG, bilan hépatique).",
  "residanat_key_point": "Piège classique ou point-clé indispensable pour le concours de résidanat et la garde aux urgences."
}
''';

      final requestData = {
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.15,
          'responseMimeType': 'application/json',
        }
      };

      for (final model in _modelCascade) {
        try {
          final url = '$_baseUrl/$model:generateContent?key=$apiKey';
          final response = await _dio.post(
            url,
            options: Options(headers: {'Content-Type': 'application/json'}),
            data: requestData,
          );

          if (response.statusCode == 200) {
            final data = response.data is String ? jsonDecode(response.data) : response.data;
            final candidates = data['candidates'] as List?;
            if (candidates != null && candidates.isNotEmpty) {
              final parts = candidates[0]['content']?['parts'] as List?;
              if (parts != null && parts.isNotEmpty) {
                final raw = parts[0]['text'] as String?;
                if (raw != null) {
                  final clean = raw.replaceAll('```json', '').replaceAll('```', '').trim();
                  final parsed = jsonDecode(clean) as Map<String, dynamic>;
                  _monographCache[cacheKey] = parsed;
                  return parsed;
                }
              }
            }
          }
        } catch (e) {
          debugPrint('Gemini monograph exception with $model: $e');
        }
      }
      return null;
    });
  }

  /// Generates a comprehensive, high-yield Course Summary for residency exam candidates
  static Future<Map<String, dynamic>?> generateCourseSummary({
    required String courseName,
    required String moduleName,
    required String courseId,
    String? moduleId,
  }) async {
    return _executeWithConcurrencyAndPacing(() async {
      final prompt = '''
Tu es le grand professeur expert et référent officiel du Concours de Résidanat de Médecine en Algérie (Facultés d'Alger, Blida, Constantine, Oran).
Rédige une Fiche Synthétique de Révision officielle et exhaustive pour le cours suivant :
- Cours : $courseName
- Module / Spécialité : $moduleName
- ID Cours : $courseId

La fiche doit être claire, percutante, axée sur les questions fermées et cas cliniques des annales de résidanat.
Respecte scrupuleusement ce schéma JSON valide (sans aucun bloc markdown, sans texte additionnel) :
{
  "course_id": "$courseId",
  "course_name": "$courseName",
  "module_id": "${moduleId ?? ""}",
  "module_name": "$moduleName",
  "summary_markdown": "Texte markdown riche et soigné, avec titres h2 (##), listes à puces, mise en gras des mots-clés et valeurs chiffrées importantes pour le concours.",
  "key_takeaways": [
    "Point clé 1 incontournable pour le concours",
    "Point clé 2...",
    "Point clé 3...",
    "Point clé 4...",
    "Point clé 5..."
  ],
  "exam_traps": [
    "Piège Annales : formulation classique vicieuse ou fausse proposition type des annales",
    "Piège Traitement : contre-indication ou erreur de prescription éliminatoire",
    "Piège Diagnostic : signe à ne jamais confondre"
  ],
  "diagnostic_criteria": "Résumé en 1-2 phrases des critères formels de diagnostic positif",
  "treatment_summary": "Résumé en 1-2 phrases de la ligne thérapeutique de référence et des urgences",
  "target_audience": "Concours Résidanat 2027"
}
N'utilise AUCUNE balise LaTeX. Utilise du texte Unicode pur (ex: ≥, ≤, µg, ², →).
''';

      final requestData = {
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.2,
          'responseMimeType': 'application/json',
        }
      };

      for (final model in _modelCascade) {
        try {
          final url = '$_baseUrl/$model:generateContent?key=$apiKey';
          final response = await _dio.post(
            url,
            options: Options(headers: {'Content-Type': 'application/json'}),
            data: requestData,
          );

          if (response.statusCode == 200) {
            final data = response.data is String ? jsonDecode(response.data) : response.data;
            final candidates = data['candidates'] as List?;
            if (candidates != null && candidates.isNotEmpty) {
              final parts = candidates[0]['content']?['parts'] as List?;
              if (parts != null && parts.isNotEmpty) {
                final raw = parts[0]['text'] as String?;
                if (raw != null) {
                  var clean = raw.replaceAll('```json', '').replaceAll('```', '').trim();
                  final firstBrace = clean.indexOf('{');
                  final lastBrace = clean.lastIndexOf('}');
                  if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
                    clean = clean.substring(firstBrace, lastBrace + 1);
                  }
                  final parsed = jsonDecode(clean) as Map<String, dynamic>;
                  parsed['course_id'] = courseId;
                  parsed['course_name'] = courseName;
                  parsed['module_name'] = moduleName;
                  parsed['updated_at'] = DateTime.now().toIso8601String();
                  return parsed;
                }
              }
            }
          }
        } catch (e) {
          debugPrint('Gemini summary generation exception with $model: $e');
        }
      }
      return null;
    });
  }

  static final Map<String, List<Map<String, dynamic>>> _indicationSearchCache = {};
  static final Map<String, Map<String, dynamic>> _internationalEquivCache = {};

  /// Vidal-style "Recherche par indication": returns recommended DCIs for a clinical indication/pathology.
  static Future<List<Map<String, dynamic>>> searchDrugsByIndicationWithAi(String indication) async {
    final cleanKey = indication.trim().toUpperCase();
    if (cleanKey.isEmpty) return [];
    if (_indicationSearchCache.containsKey(cleanKey)) {
      return _indicationSearchCache[cleanKey]!;
    }

    final result = await _executeWithConcurrencyAndPacing(() async {
      final prompt = '''
Tu es le référentiel pharmacologique Vidal & Nomenclature Algérienne MSPRH.
Un médecin ou étudiant recherche des médicaments par indication thérapeutique : "$indication".
Liste les 6 à 8 principales molécules (DCI en MAJUSCULES sans accents si possible, ex: AMOXICILLINE, RAMIPRIL, METFORMINE) recommandées en pratique clinique pour cette indication.

Réponds STRICTEMENT avec un JSON valide (aucun markdown) :
{
  "results": [
    {
      "dci": "NOM DCI EN MAJUSCULES",
      "therapeutic_class": "Classe pharmacologique (ex: IEC, Antibiotique Bêta-lactamine)",
      "line_of_treatment": "1ère intention / 2ème intention / Adjuvant",
      "usual_dosage": "Posologie usuelle adulte concise",
      "key_precaution": "Précaution ou contre-indication majeure en 1 phrase"
    }
  ]
}
''';

      final requestData = {
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.15,
          'responseMimeType': 'application/json',
        }
      };

      for (final model in _modelCascade) {
        try {
          final url = '$_baseUrl/$model:generateContent?key=$apiKey';
          final response = await _dio.post(
            url,
            options: Options(headers: {'Content-Type': 'application/json'}),
            data: requestData,
          );

          if (response.statusCode == 200) {
            final data = response.data is String ? jsonDecode(response.data) : response.data;
            final candidates = data['candidates'] as List?;
            if (candidates != null && candidates.isNotEmpty) {
              final parts = candidates[0]['content']?['parts'] as List?;
              if (parts != null && parts.isNotEmpty) {
                final raw = parts[0]['text'] as String?;
                if (raw != null) {
                  final clean = raw.replaceAll('```json', '').replaceAll('```', '').trim();
                  final parsed = jsonDecode(clean) as Map<String, dynamic>;
                  final list = (parsed['results'] as List?)
                          ?.map((e) => Map<String, dynamic>.from(e as Map))
                          .toList() ??
                      <Map<String, dynamic>>[];
                  _indicationSearchCache[cleanKey] = list;
                  return list;
                }
              }
            }
          }
        } catch (e) {
          debugPrint('Gemini indication search exception with $model: $e');
        }
      }
      return <Map<String, dynamic>>[];
    });

    return result ?? <Map<String, dynamic>>[];
  }

  /// Vidal-style "Équivalences internationales / Convertisseur DC": maps a foreign/French brand name to its DCI.
  static Future<Map<String, dynamic>?> resolveInternationalEquivalentWithAi(String foreignBrand) async {
    final cleanKey = foreignBrand.trim().toUpperCase();
    if (cleanKey.isEmpty) return null;
    if (_internationalEquivCache.containsKey(cleanKey)) {
      return _internationalEquivCache[cleanKey];
    }

    return _executeWithConcurrencyAndPacing(() async {
      final prompt = '''
Tu es le convertisseur d'équivalences internationales Vidal (France / Europe / USA ↔ Algérie MSPRH).
Le médecin recherche l'équivalent du médicament étranger suivant : "$foreignBrand".

Réponds STRICTEMENT avec un JSON valide (aucun markdown) :
{
  "foreign_name": "$foreignBrand",
  "country_origin": "France / International",
  "dci": "DCI EXACTE EN MAJUSCULES (ex: PARACETAMOL, ACIDE ACETYLSALICYLIQUE, PHLOROGLUCINOL)",
  "search_keyword": "Mot-clé DCI court sans sel pour la recherche catalogue (ex: AMOXICILLINE, OMEPRAZOLE)",
  "pharmacological_class": "Classe pharmacologique",
  "notes": "Précision utile sur le dosage ou les équivalents courants en Algérie"
}
''';

      final requestData = {
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.1,
          'responseMimeType': 'application/json',
        }
      };

      for (final model in _modelCascade) {
        try {
          final url = '$_baseUrl/$model:generateContent?key=$apiKey';
          final response = await _dio.post(
            url,
            options: Options(headers: {'Content-Type': 'application/json'}),
            data: requestData,
          );

          if (response.statusCode == 200) {
            final data = response.data is String ? jsonDecode(response.data) : response.data;
            final candidates = data['candidates'] as List?;
            if (candidates != null && candidates.isNotEmpty) {
              final parts = candidates[0]['content']?['parts'] as List?;
              if (parts != null && parts.isNotEmpty) {
                final raw = parts[0]['text'] as String?;
                if (raw != null) {
                  final clean = raw.replaceAll('```json', '').replaceAll('```', '').trim();
                  final parsed = jsonDecode(clean) as Map<String, dynamic>;
                  _internationalEquivCache[cleanKey] = parsed;
                  return parsed;
                }
              }
            }
          }
        } catch (e) {
          debugPrint('Gemini international equiv exception with $model: $e');
        }
      }
      return null;
    });
  }
}
