import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/app_secrets.dart';
import '../utils/medical_text_formatter.dart';

class GeminiService {
  // Configured Gemini API Key from git-ignored secrets
  static String get apiKey => AppSecrets.geminiApiKey;

  // Active models with fallback cascade
  static const List<String> _modelCascade = [
    'gemini-3.5-flash',
    'gemini-3.8-flash',
    'gemini-flash-latest',
  ];

  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';

  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 45),
  ));

  /// Medical Persona System Instruction
  static const String _medicalSystemPrompt = '''
Tu es MedsinaPilot, l'assistant IA médical officiel de Medsina, la plateforme médicale de référence pour les médecins et candidats au concours de résidanat de médecine (Facultés de Blida, Alger, Constantine, Oran).
Ton rôle est d'apporter un soutien pédagogique et clinique de haute précision:
1. Réponds toujours avec rigueur scientifique selon les recommandations et consensus actuels (HAS, ESC, GINA, GOLD, consensus algériens).
2. Fournis des explications complètes, exhaustives et structurées du début jusqu'à la fin de la conduite à tenir sans couper la réponse.
3. Explique clairement pourquoi une proposition de QCM est vraie ou fausse, en identifiant les pièges classiques d'examen.
4. FORMATAGE DU TEXTE ET DES UNITÉS (RÈGLE STRICTE):
   - N'UTILISE JAMAIS de syntaxe LaTeX, ni de symboles dollar (\$...\$ ou \$\$...\$\$).
   - N'utilise JAMAIS de commandes LaTeX telles que \\ge, \\le, \\text{...}, \\mathrm{...}, \\pm, \\times, \\mu.
   - Écris TOUJOURS les unités et symboles mathématiques directement en texte Unicode clair et naturel: "≥", "≤", "±", "×", "µg", "°C", "mm", "mV", "bpm", "%", "/".
   - Par exemple, écris: "≥ 1 mm (0,1 mV)" et JAMAIS "\$\\ge 1 \\text{ mm}\$ (\$0,1 \\text{ mV}\$)".
5. Utilise un formatage Markdown élégant (titres, listes à puces, gras) pour faciliter la lecture rapide en situation d'urgence ou de révision.
''';

  /// Send prompt to Gemini API
  static Future<String> generateMedicalResponse({
    required String prompt,
    String? contextInfo,
  }) async {
    final fullPrompt = contextInfo != null
        ? '$_medicalSystemPrompt\n\n[CONTEXTE DE LA QUESTION OU DU PATIENT]:\n$contextInfo\n\n[QUESTION DE L\'ÉTUDIANT]:\n$prompt'
        : '$_medicalSystemPrompt\n\n[QUESTION DE L\'ÉTUDIANT]:\n$prompt';

    final requestData = {
      'contents': [
        {
          'parts': [
            {'text': fullPrompt}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.3,
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

  /// QCM Explanation Helper
  static Future<String> explainQcm({
    required String questionTitle,
    required List<String> optionsText,
    required List<String> correctKeys,
    required String userQuery,
  }) async {
    final context = '''
Question d'examen: $questionTitle
Propositions:
${optionsText.join('\n')}
Bonne(s) réponse(s) officielle(s): ${correctKeys.join(', ')}
''';

    return await generateMedicalResponse(
      prompt: userQuery,
      contextInfo: context,
    );
  }

  /// Clinical Decision & CAT Helper
  static Future<String> getClinicalAdvice({
    required String clinicalSituation,
    required String userQuery,
  }) async {
    return await generateMedicalResponse(
      prompt: userQuery,
      contextInfo: 'Situation Clinique: $clinicalSituation',
    );
  }
}
