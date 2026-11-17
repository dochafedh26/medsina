import 'package:equatable/equatable.dart';

enum DuelAiDifficulty {
  externe,
  resident,
  majorPromo,
}

extension DuelAiDifficultyExtension on DuelAiDifficulty {
  String get label {
    switch (this) {
      case DuelAiDifficulty.externe:
        return 'Externe Assidu (~60% réussite)';
      case DuelAiDifficulty.resident:
        return 'Résident Élite (~78% réussite)';
      case DuelAiDifficulty.majorPromo:
        return 'Major de Promo (~90% réussite)';
    }
  }

  double get accuracyRate {
    switch (this) {
      case DuelAiDifficulty.externe:
        return 0.60;
      case DuelAiDifficulty.resident:
        return 0.78;
      case DuelAiDifficulty.majorPromo:
        return 0.90;
    }
  }
}

class QcmDuelMatch extends Equatable {
  final String id;
  final String challengeCode;
  final String moduleName;
  final String creatorName;
  final int creatorScore;
  final int creatorTimeSeconds;
  final String? opponentName;
  final int? opponentScore;
  final int? opponentTimeSeconds;
  final List<String> questionIds;
  final int totalQuestions;
  final String status; // 'open', 'completed'
  final DateTime createdAt;

  const QcmDuelMatch({
    required this.id,
    required this.challengeCode,
    required this.moduleName,
    required this.creatorName,
    this.creatorScore = 0,
    this.creatorTimeSeconds = 0,
    this.opponentName,
    this.opponentScore,
    this.opponentTimeSeconds,
    required this.questionIds,
    required this.totalQuestions,
    this.status = 'open',
    required this.createdAt,
  });

  factory QcmDuelMatch.fromJson(Map<String, dynamic> json) {
    final rawQIds = json['question_ids'];
    final qIds = rawQIds is List ? rawQIds.map((e) => e.toString()).toList() : <String>[];
    return QcmDuelMatch(
      id: json['id']?.toString() ?? '',
      challengeCode: json['challenge_code']?.toString() ?? '',
      moduleName: json['module_name']?.toString() ?? 'Multi-Modules',
      creatorName: json['creator_name']?.toString() ?? 'Confrère',
      creatorScore: (json['creator_score'] as num?)?.toInt() ?? 0,
      creatorTimeSeconds: (json['creator_time_seconds'] as num?)?.toInt() ?? 0,
      opponentName: json['opponent_name']?.toString(),
      opponentScore: (json['opponent_score'] as num?)?.toInt(),
      opponentTimeSeconds: (json['opponent_time_seconds'] as num?)?.toInt(),
      questionIds: qIds,
      totalQuestions: (json['total_questions'] as num?)?.toInt() ?? 5,
      status: json['status']?.toString() ?? 'open',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'challenge_code': challengeCode,
        'module_name': moduleName,
        'creator_name': creatorName,
        'creator_score': creatorScore,
        'creator_time_seconds': creatorTimeSeconds,
        'opponent_name': opponentName,
        'opponent_score': opponentScore,
        'opponent_time_seconds': opponentTimeSeconds,
        'question_ids': questionIds,
        'total_questions': totalQuestions,
        'status': status,
        'created_at': createdAt.toIso8601String(),
      };

  @override
  List<Object?> get props => [id, challengeCode, moduleName, creatorScore, opponentScore, status];
}
