import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/supabase_service.dart';
import '../data/residency_repository.dart';
import '../models/qcm_duel_model.dart';
import '../models/qcm_model.dart';

class QcmDuelService {
  static const String _localHistoryKey = 'medsina_qcm_duel_history_v1';

  /// Génère un code de défi court déterministe ex: DZ-4829
  static String generateChallengeCode({int? seed}) {
    final rng = seed != null ? Random(seed) : Random();
    final numPart = 1000 + rng.nextInt(9000);
    return 'DZ-$numPart';
  }

  /// Sélectionne de manière déterministe `count` QCMs à partir d'un code de défi
  static Future<List<QcmQuestion>> pickQuestionsForDuel({
    required String challengeCode,
    String? moduleId,
    int count = 5,
  }) async {
    final modules = await ResidencyRepository.loadModulesAsync();
    final pool = <QcmQuestion>[];

    if (moduleId != null && moduleId.isNotEmpty) {
      final qs = await ResidencyRepository.getQuestionsForMultipleCoursesAsync(
        courseIds: const [],
        moduleIds: [moduleId],
        limit: 40,
      );
      pool.addAll(qs);
    } else {
      final modIds = modules.take(6).map((m) => m.id).toList();
      if (modIds.isNotEmpty) {
        final qs = await ResidencyRepository.getQuestionsForMultipleCoursesAsync(
          courseIds: const [],
          moduleIds: modIds,
          limit: 60,
        );
        pool.addAll(qs);
      }
    }

    if (pool.isEmpty) {
      // Fallback garanti si aucun asset JSON chargé en test
      return List.generate(
        count,
        (i) => QcmQuestion(
          id: 'duel_fb_$i',
          moduleId: 'Blida_CARDIOLOGIE',
          courseId: 'c_cardio_hta',
          courseName: 'Urgences & Résidanat',
          type: QuestionType.qcs,
          questionText:
              'Question Duel #${i + 1} : Quel est le vasopresseur de 1ère intention dans le choc septique de l\'adulte ?',
          options: const [
            QcmOption(key: 'A', text: 'Noradrénaline'),
            QcmOption(key: 'B', text: 'Dobutamine'),
            QcmOption(key: 'C', text: 'Isoprénaline'),
            QcmOption(key: 'D', text: 'Nicardipine'),
          ],
          correctAnswers: const ['A'],
          explanation: 'La Noradrénaline est le vasopresseur de référence en 1ère intention dans le choc septique (PAM cible ≥ 65 mmHg).',
          source: 'Blida 2025',
          year: 2025,
        ),
      );
    }

    final seed = challengeCode.codeUnits.fold<int>(0, (acc, c) => acc * 31 + c);
    final rng = Random(seed);
    final shuffled = List<QcmQuestion>.from(pool)..shuffle(rng);
    return shuffled.take(count.clamp(1, shuffled.length)).toList();
  }

  static int simulateAiOpponentScore({
    required int totalQuestions,
    required DuelAiDifficulty difficulty,
    required int seed,
  }) {
    final rng = Random(seed);
    int score = 0;
    for (int i = 0; i < totalQuestions; i++) {
      if (rng.nextDouble() < difficulty.accuracyRate) {
        score += 100;
      }
    }
    return score;
  }

  static Future<void> saveDuelMatch(QcmDuelMatch match, {bool isJoining = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localHistoryKey);
    final existing = raw != null ? (jsonDecode(raw) as List).cast<Map<String, dynamic>>() : <Map<String, dynamic>>[];
    existing.removeWhere((e) => e['challenge_code'] == match.challengeCode);
    existing.insert(0, match.toJson());
    await prefs.setString(_localHistoryKey, jsonEncode(existing.take(30).toList()));

    if (SupabaseService.isAuthenticated && SupabaseService.currentUser != null) {
      try {
        final uid = SupabaseService.currentUser!.id;
        if (isJoining) {
          await SupabaseService.client.from('qcm_duel_matches').update({
            'opponent_id': uid,
            'opponent_name': match.opponentName,
            'opponent_score': match.opponentScore,
            'opponent_time_seconds': match.opponentTimeSeconds,
            'status': 'completed',
          }).eq('challenge_code', match.challengeCode);
        } else {
          await SupabaseService.client.from('qcm_duel_matches').upsert({
            ...match.toJson(),
            'creator_id': uid,
          });
        }
      } catch (_) {}
    }
  }

  static Future<QcmDuelMatch?> fetchMatchByCode(String code) async {
    final normalized = code.trim().toUpperCase();
    if (SupabaseService.isAuthenticated) {
      try {
        final row = await SupabaseService.client
            .from('qcm_duel_matches')
            .select()
            .eq('challenge_code', normalized)
            .maybeSingle();
        if (row != null) {
          return QcmDuelMatch.fromJson(Map<String, dynamic>.from(row));
        }
      } catch (_) {}
    }
    final history = await loadHistory();
    try {
      return history.firstWhere((m) => m.challengeCode == normalized);
    } catch (_) {
      return null;
    }
  }

  static Future<List<QcmDuelMatch>> loadHistory() async {
    final list = <QcmDuelMatch>[];
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_localHistoryKey);
      if (raw != null) {
        final decoded = jsonDecode(raw) as List;
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            list.add(QcmDuelMatch.fromJson(item));
          }
        }
      }
    } catch (_) {}
    return list;
  }
}
