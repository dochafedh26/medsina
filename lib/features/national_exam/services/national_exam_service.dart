import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/network/supabase_service.dart';
import '../../revision/models/qcm_model.dart';
import '../models/national_exam_model.dart';

class NationalExamService {
  static final NationalExamService instance = NationalExamService._();
  NationalExamService._();

  SupabaseClient get _client => SupabaseService.client;

  /// Récupère la liste des examens / concours blancs nationaux
  Future<List<NationalExamModel>> getExams() async {
    try {
      final res = await _client
          .from('national_exams')
          .select('*, exam_participations(count)')
          .order('start_time', ascending: false);

      final exams = <NationalExamModel>[];
      for (final raw in (res as List)) {
        final data = Map<String, dynamic>.from(raw);
        final countArr = data['exam_participations'];
        int pCount = 0;
        if (countArr is List && countArr.isNotEmpty) {
          pCount = (countArr.first['count'] as num?)?.toInt() ?? 0;
        }
        data['participants_count'] = pCount;
        exams.add(NationalExamModel.fromJson(data));
      }
      return exams;
    } catch (e) {
      debugPrint('Error getExams: $e');
      return [];
    }
  }

  /// Récupère les détails d'un examen spécifique
  Future<NationalExamModel?> getExamById(String examId) async {
    try {
      final res = await _client.from('national_exams').select('*').eq('id', examId).single();
      return NationalExamModel.fromJson(res);
    } catch (e) {
      debugPrint('Error getExamById: $e');
      return null;
    }
  }

  /// Création d'un Examen National par l'Administrateur
  Future<NationalExamModel?> createNationalExam({
    required String adminUserId,
    required String title,
    String? description,
    String targetType = 'residency',
    String? targetModuleId,
    String? targetModuleName,
    required List<String> questionIds,
    required int durationMinutes,
    required DateTime startTime,
    required DateTime endTime,
    bool isLiveSynchronous = false,
    bool negativeMarking = false,
    String correctionStyle = 'allOrNothing',
    bool sendBroadcast = true,
  }) async {
    try {
      final examData = {
        'title': title.trim(),
        'description': description?.trim(),
        'created_by': adminUserId,
        'target_type': targetType,
        'target_module_id': targetModuleId,
        'target_module_name': targetModuleName,
        'question_ids': questionIds,
        'total_questions': questionIds.length,
        'duration_minutes': durationMinutes,
        'start_time': startTime.toIso8601String(),
        'end_time': endTime.toIso8601String(),
        'is_live_synchronous': isLiveSynchronous,
        'status': 'scheduled',
        'negative_marking': negativeMarking,
        'correction_style': correctionStyle,
        'announcement_sent': sendBroadcast,
      };

      final res = await _client.from('national_exams').insert(examData).select().single();
      final exam = NationalExamModel.fromJson(res);

      if (sendBroadcast) {
        await broadcastExamAnnouncement(exam);
      }

      return exam;
    } catch (e) {
      debugPrint('Error createNationalExam: $e');
      return null;
    }
  }

  /// Diffuse l'invitation à tous les utilisateurs enregistrés via medical_notifications
  Future<void> broadcastExamAnnouncement(NationalExamModel exam) async {
    try {
      final formattedDate = '${exam.startTime.day.toString().padLeft(2, '0')}/${exam.startTime.month.toString().padLeft(2, '0')} à ${exam.startTime.hour.toString().padLeft(2, '0')}h${exam.startTime.minute.toString().padLeft(2, '0')}';
      await _client.from('medical_notifications').insert({
        'title': '🏆 Concours Blanc National Résidanat 2027',
        'message': 'Nouvelle épreuve officielle : "${exam.title}" (${exam.totalQuestions} QCMs • ${exam.durationMinutes} min). Début : $formattedDate. Rejoignez et testez votre classement national !',
        'type': 'exam_invitation',
        'target_id': exam.id,
        'metadata': {
          'action': 'open_exam',
          'exam_id': exam.id,
          'title': exam.title,
          'start_time': exam.startTime.toIso8601String(),
          'duration_minutes': exam.durationMinutes,
        },
        'is_broadcast': true,
      });

      await _client.from('national_exams').update({'announcement_sent': true}).eq('id', exam.id);
    } catch (e) {
      debugPrint('Error broadcastExamAnnouncement: $e');
    }
  }

  /// Inscription d'un candidat à un concours blanc
  Future<bool> registerForExam({
    required String examId,
    required String userId,
    bool isAnonymous = false,
  }) async {
    try {
      await _client.from('exam_participations').upsert({
        'exam_id': examId,
        'user_id': userId,
        'status': 'registered',
        'is_anonymous_in_leaderboard': isAnonymous,
      });
      return true;
    } catch (e) {
      debugPrint('Error registerForExam: $e');
      return false;
    }
  }

  /// Récupère la participation de l'utilisateur connecté
  Future<ExamParticipationModel?> getUserParticipation({
    required String examId,
    required String userId,
  }) async {
    try {
      final res = await _client
          .from('exam_participations')
          .select('*')
          .eq('exam_id', examId)
          .eq('user_id', userId)
          .maybeSingle();

      if (res == null) return null;
      return ExamParticipationModel.fromJson(res);
    } catch (e) {
      debugPrint('Error getUserParticipation: $e');
      return null;
    }
  }

  /// Soumet la copie d'un candidat au concours blanc et enregistre les scores
  Future<ExamParticipationModel?> submitExamParticipation({
    required String examId,
    required String userId,
    required List<QcmQuestion> questions,
    required Map<String, Set<String>> userAnswers,
    required int timeSpentSeconds,
    required String correctionStyle,
    bool isAnonymous = false,
  }) async {
    try {
      int correctCount = 0;
      int incorrectCount = 0;
      int unansweredCount = 0;
      double points = 0.0;

      final answersPayload = <String, dynamic>{};

      for (final q in questions) {
        final chosen = userAnswers[q.id] ?? <String>{};
        final correctKeys = q.correctAnswers.map((k) => k.toUpperCase().trim()).toSet();

        bool isQCorrect = false;
        if (chosen.isEmpty) {
          unansweredCount++;
        } else {
          if (correctionStyle == 'allOrNothing') {
            isQCorrect = chosen.length == correctKeys.length && chosen.containsAll(correctKeys);
          } else {
            final correctChosen = chosen.intersection(correctKeys);
            final wrongChosen = chosen.difference(correctKeys);
            if (wrongChosen.isEmpty && correctChosen.isNotEmpty) {
              if (correctChosen.length == correctKeys.length) {
                isQCorrect = true;
              } else {
                points += 0.5;
              }
            }
          }

          if (isQCorrect) {
            correctCount++;
            points += 1.0;
          } else {
            incorrectCount++;
          }
        }

        answersPayload[q.id] = {
          'selected': chosen.toList(),
          'correct': correctKeys.toList(),
          'is_correct': isQCorrect,
        };
      }

      final totalQ = questions.length;
      final scoreOutOf20 = totalQ > 0 ? (points / totalQ) * 20.0 : 0.0;
      final avgSeconds = totalQ > 0 ? timeSpentSeconds / totalQ : 0.0;

      final updateData = {
        'status': 'submitted',
        'submitted_at': DateTime.now().toIso8601String(),
        'time_spent_seconds': timeSpentSeconds,
        'score': points,
        'score_out_of_20': scoreOutOf20,
        'correct_answers_count': correctCount,
        'incorrect_answers_count': incorrectCount,
        'unanswered_count': unansweredCount,
        'average_seconds_per_question': avgSeconds,
        'is_anonymous_in_leaderboard': isAnonymous,
        'answers': answersPayload,
      };

      final res = await _client
          .from('exam_participations')
          .update(updateData)
          .eq('exam_id', examId)
          .eq('user_id', userId)
          .select()
          .single();

      return ExamParticipationModel.fromJson(res);
    } catch (e) {
      debugPrint('Error submitExamParticipation: $e');
      return null;
    }
  }

  /// Récupère le Classement National officiel ordonné par Note puis par Vitesse
  Future<List<ExamLeaderboardEntry>> getExamLeaderboard(String examId, {String? currentUserId}) async {
    try {
      final res = await _client
          .from('exam_participations')
          .select('*, profiles(id, full_name, email, faculty, avatar_url)')
          .eq('exam_id', examId)
          .eq('status', 'submitted')
          .order('score', ascending: false)
          .order('time_spent_seconds', ascending: true);

      final list = <ExamLeaderboardEntry>[];
      int rankCounter = 1;

      for (final raw in (res as List)) {
        final profile = (raw['profiles'] as Map<String, dynamic>?) ?? {};
        final pUserId = raw['user_id']?.toString() ?? profile['id']?.toString() ?? '';
        final isMe = currentUserId != null && pUserId == currentUserId;
        final totalQ = ((raw['correct_answers_count'] as num?)?.toInt() ?? 0) +
            ((raw['incorrect_answers_count'] as num?)?.toInt() ?? 0) +
            ((raw['unanswered_count'] as num?)?.toInt() ?? 0);
        final correct = (raw['correct_answers_count'] as num?)?.toInt() ?? 0;
        final accuracy = totalQ > 0 ? (correct / totalQ) * 100.0 : 0.0;

        list.add(ExamLeaderboardEntry(
          rank: rankCounter++,
          userId: pUserId,
          candidateName: profile['full_name']?.toString() ?? 'Candidat Medsina',
          faculty: profile['faculty']?.toString() ?? 'Faculté de Médecine',
          avatarUrl: profile['avatar_url']?.toString(),
          scoreOutOf20: (raw['score_out_of_20'] as num?)?.toDouble() ?? 0.0,
          accuracyPercentage: accuracy,
          totalQuestions: totalQ,
          correctCount: correct,
          timeSpentSeconds: (raw['time_spent_seconds'] as num?)?.toInt() ?? 0,
          averageSecondsPerQuestion: (raw['average_seconds_per_question'] as num?)?.toDouble() ?? 0.0,
          isCurrentUser: isMe,
          isAnonymous: raw['is_anonymous_in_leaderboard'] == true,
        ));
      }

      return list;
    } catch (e) {
      debugPrint('Error getExamLeaderboard: $e');
      return [];
    }
  }

  /// Clôture de l'épreuve par l'Admin et calcul définitif des rangs officiels
  Future<bool> closeExamAndCalculateOfficialRanks(String examId) async {
    try {
      // 1. Mettre le statut de l'examen à 'completed'
      await _client.from('national_exams').update({'status': 'completed', 'updated_at': DateTime.now().toIso8601String()}).eq('id', examId);

      // 2. Récupérer toutes les participations soumises
      final leaderboard = await getExamLeaderboard(examId);
      final totalCandidates = leaderboard.length;

      // 3. Mettre à jour les rangs et percentiles dans exam_participations
      for (final entry in leaderboard) {
        final percentile = totalCandidates > 0 ? ((totalCandidates - entry.rank + 1) / totalCandidates) * 100.0 : 100.0;
        await _client
            .from('exam_participations')
            .update({
              'rank': entry.rank,
              'percentile': percentile,
            })
            .eq('exam_id', examId)
            .eq('user_id', entry.userId);
      }

      // 4. Envoyer notification générale des résultats
      final exam = await getExamById(examId);
      final examTitle = exam?.title ?? 'Concours Blanc National';
      await _client.from('medical_notifications').insert({
        'title': '🎉 Résultats & Classement Disponibles !',
        'message': 'Le classement officiel pour "$examTitle" est en ligne ! Découvrez votre rang national et votre fiche d\'analyse des erreurs.',
        'type': 'exam_results',
        'target_id': examId,
        'metadata': {
          'action': 'open_leaderboard',
          'exam_id': examId,
          'exam_title': examTitle,
        },
        'is_broadcast': true,
      });

      return true;
    } catch (e) {
      debugPrint('Error closeExamAndCalculateOfficialRanks: $e');
      return false;
    }
  }
}
