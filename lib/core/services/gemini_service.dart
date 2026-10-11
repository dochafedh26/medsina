import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/app_secrets.dart';

class GeminiService {
  // Configured Gemini API Key from git-ignored secrets
  static String get apiKey => AppSecrets.geminiApiKey;

  // Primary model tested and active
  static const String primaryModel = 'gemini-3.5-flash';
  static const String fallbackModel = 'gemini-flash-latest';

  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';

  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
  ));

  /// Medical Persona System Instruction
  static const String _medicalSystemPrompt = '''
Tu es MedsinaPilot, l'assistant IA médical officiel de Medsina, la plateforme médicale de référence pour les médecins et candidats au concours de résidanat de médecine (Facultés de Blida, Alger, Constantine, Oran).
Ton rôle est d'apporter un soutien pédagogique et clinique de haute précision:
1. Réponds toujours avec rigueur scientifique selon les recommandations et consensus actuels (HAS, ESC, GINA, GOLD, consensus algériens).
2. Explique clairement pourquoi une proposition de QCM est vraie ou fausse, en identifiant les pièges classiques d'examen.
3. Sois structuré, concis, bienveillant et utilise des puces claires et du formatage markdown si nécessaire.
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
        'maxOutputTokens': 1024,
      }
    };

    // Try primary model first, fallback if unavailable
    for (final model in [primaryModel, fallbackModel]) {
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
              return parts[0]['text'] ?? 'Aucune réponse générée.';
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
