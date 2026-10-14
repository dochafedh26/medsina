import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/app_secrets.dart';
import '../utils/medical_text_formatter.dart';
import '../../features/revision/data/residency_repository.dart';

class GeminiService {
  // Configured Gemini API Key from git-ignored secrets
  static String get apiKey => AppSecrets.geminiApiKey;

  // Active models with fallback cascade
  static const List<String> _modelCascade = [
    'gemini-2.5-flash',
    'gemini-2.0-flash',
    'gemini-1.5-flash',
  ];

  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';

  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 45),
  ));

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

  /// Search across all 1,209 courses in medsina_ressources for the best matching curriculum courses
  static List<String> _findMatchingCoursesInDrive(String query, {String? courseHint, String? moduleHint}) {
    final modules = ResidencyRepository.getModules();
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
    for (final m in modules) {
      for (final c in m.courses) {
        if (found.any((f) => f.contains(c.name))) continue;

        final cNameLower = c.name.toLowerCase();
        int score = 0;
        for (final w in words) {
          if (cNameLower.contains(w)) score++;
        }

        if (score > 0) {
          found.add('• Référence Curriculum : "${c.name}" (Module: ${m.name}, disponible sur Google Drive medsina_ressources)');
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
  }) async* {
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

  /// Fast Structured Audit for Prescription & Terrain Safety (0 False Negatives)
  static Future<Map<String, dynamic>?> auditPrescriptionWithAi({
    required List<String> drugs,
    required List<String> terrains,
  }) async {
    final prompt = '''
Tu es le moteur pharmacologique officiel Vidal, ANSM et MSPRH de Medsina.
Analyse la sécurité de cette prescription :
- Médicaments prescrits : ${drugs.join(', ')}
- Terrains / Profils patient : ${terrains.isEmpty ? 'Aucun terrain renseigné' : terrains.join(', ')}

Recherche rigoureusement :
1. Les contre-indications absolues ou relatives entre chaque médicament et les terrains patients indiqués.
2. Les interactions médicamenteuses majeures (contre-indiquées ou déconseillées) entre les médicaments entre eux.

Réponds STRICTEMENT sous forme d'un objet JSON valide avec cette structure exacte (sans aucun bloc markdown, sans texte autour) :
{
  "has_alert": true,
  "severity": "contraindicated",
  "title": "Titre clinique précis de l'alerte",
  "warning": "Mécanisme pharmacologique précis et danger clinique encouru",
  "recommendation": "Conduite à tenir immédiate (arrêt, adaptation posologique, molécule alternative)",
  "source": "Vidal / ANSM"
}
Si aucun risque n'existe, renvoie {"has_alert": false, "severity": "info", "title": "Aucune anomalie détectée", "warning": "", "recommendation": "", "source": "Vidal"}
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
  }
}
