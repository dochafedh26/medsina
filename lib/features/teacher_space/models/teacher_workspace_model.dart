import 'package:equatable/equatable.dart';

/// Grade académique de l'enseignant hospitalo-universitaire
enum AcademicRank {
  resident,
  assistant,
  maitreAssistant,
  mca,
  professeur,
}

extension AcademicRankExtension on AcademicRank {
  String get label {
    switch (this) {
      case AcademicRank.resident:
        return 'Médecin Résident';
      case AcademicRank.assistant:
        return 'Assistant HU';
      case AcademicRank.maitreAssistant:
        return 'Maître-Assistant (MAHU)';
      case AcademicRank.mca:
        return 'Maître de Conférences (MCA)';
      case AcademicRank.professeur:
        return 'Professeur (Pr.)';
    }
  }

  String get shortBadge {
    switch (this) {
      case AcademicRank.resident:
        return 'Résident';
      case AcademicRank.assistant:
        return 'Assistant';
      case AcademicRank.maitreAssistant:
        return 'Maître-Assistant';
      case AcademicRank.mca:
        return 'MCA';
      case AcademicRank.professeur:
        return 'Pr.';
    }
  }
}

/// Type de ressource publiée par l'enseignant dans sa spécialité
enum TeacherContentType {
  course,
  summary,
  mindmap,
  flashcards,
  qcmBank,
}

extension TeacherContentTypeExtension on TeacherContentType {
  String get label {
    switch (this) {
      case TeacherContentType.course:
        return 'Cours / Polycopié';
      case TeacherContentType.summary:
        return 'Fiche de Synthèse';
      case TeacherContentType.mindmap:
        return 'Mind Map / Arbre';
      case TeacherContentType.flashcards:
        return 'Flashcards FSRS';
      case TeacherContentType.qcmBank:
        return 'Série QCM / QROC';
    }
  }
}

class TeacherFlashcardPair extends Equatable {
  final String front;
  final String back;

  const TeacherFlashcardPair({required this.front, required this.back});

  factory TeacherFlashcardPair.fromJson(Map<String, dynamic> json) =>
      TeacherFlashcardPair(
        front: json['front']?.toString() ?? '',
        back: json['back']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {'front': front, 'back': back};

  @override
  List<Object?> get props => [front, back];
}

class TeacherPublicationItem extends Equatable {
  final String id;
  final String authorName;
  final AcademicRank academicRank;
  final String specialty;
  final String faculty;
  final String targetAudience;
  final TeacherContentType contentType;
  final String title;
  final String summaryDescription;
  final String markdownBody;
  final String? attachmentUrl;
  final List<TeacherFlashcardPair> flashcards;
  final DateTime createdAt;

  const TeacherPublicationItem({
    required this.id,
    required this.authorName,
    required this.academicRank,
    required this.specialty,
    required this.faculty,
    this.targetAudience = 'Résidanat & Externat',
    required this.contentType,
    required this.title,
    required this.summaryDescription,
    this.markdownBody = '',
    this.attachmentUrl,
    this.flashcards = const [],
    required this.createdAt,
  });

  factory TeacherPublicationItem.fromJson(Map<String, dynamic> json) {
    final rankStr = json['academic_rank']?.toString() ?? 'assistant';
    final rank = AcademicRank.values.firstWhere(
      (r) => r.name == rankStr || r.label == rankStr,
      orElse: () => AcademicRank.assistant,
    );
    final typeStr = json['content_type']?.toString() ?? 'course';
    final type = TeacherContentType.values.firstWhere(
      (t) => t.name == typeStr,
      orElse: () => TeacherContentType.course,
    );
    final payload = json['structured_payload'];
    final rawCards = payload is Map ? payload['flashcards'] : null;
    final cards = rawCards is List
        ? rawCards
            .whereType<Map>()
            .map((c) => TeacherFlashcardPair.fromJson(Map<String, dynamic>.from(c)))
            .toList()
        : <TeacherFlashcardPair>[];

    return TeacherPublicationItem(
      id: json['id']?.toString() ?? '',
      authorName: json['author_name']?.toString() ?? 'Enseignant HU',
      academicRank: rank,
      specialty: json['specialty']?.toString() ?? 'Médecine',
      faculty: json['faculty']?.toString() ?? 'Blida',
      targetAudience: json['target_audience']?.toString() ?? 'Résidanat & Externat',
      contentType: type,
      title: json['title']?.toString() ?? '',
      summaryDescription: json['summary_description']?.toString() ?? '',
      markdownBody: json['markdown_body']?.toString() ?? '',
      attachmentUrl: json['attachment_url']?.toString(),
      flashcards: cards,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'author_name': authorName,
        'academic_rank': academicRank.name,
        'specialty': specialty,
        'faculty': faculty,
        'target_audience': targetAudience,
        'content_type': contentType.name,
        'title': title,
        'summary_description': summaryDescription,
        'markdown_body': markdownBody,
        'attachment_url': attachmentUrl,
        'structured_payload': {
          'flashcards': flashcards.map((c) => c.toJson()).toList(),
        },
        'created_at': createdAt.toIso8601String(),
      };

  @override
  List<Object?> get props => [id, title, specialty, contentType, academicRank];
}

/// Format d'une question rédigée sur mesure par l'enseignant
enum CustomQuestionFormat {
  qcs,
  qcm,
  casClinique,
  qroc,
}

extension CustomQuestionFormatExtension on CustomQuestionFormat {
  String get label {
    switch (this) {
      case CustomQuestionFormat.qcs:
        return 'QCS (Choix Simple)';
      case CustomQuestionFormat.qcm:
        return 'QCM (Choix Multiple)';
      case CustomQuestionFormat.casClinique:
        return 'Cas Clinique';
      case CustomQuestionFormat.qroc:
        return 'QROC (Réponse Courte)';
    }
  }
}

class CustomExamQuestion extends Equatable {
  final String id;
  final CustomQuestionFormat format;
  final String questionText;
  final List<String> options; // A..E pour QCS/QCM/Cas Clinique
  final List<int> correctOptionIndices;
  final String qrocReferenceAnswer;
  final List<String> qrocExpectedKeywords; // Mots-clés pour correction auto de la QROC
  final String explanation;

  const CustomExamQuestion({
    required this.id,
    required this.format,
    required this.questionText,
    this.options = const [],
    this.correctOptionIndices = const [],
    this.qrocReferenceAnswer = '',
    this.qrocExpectedKeywords = const [],
    this.explanation = '',
  });

  /// Évalue automatiquement une réponse libre QROC en pourcentage de mots-clés trouvés (0.0 à 1.0)
  double evaluateQrocAnswer(String studentAnswer) {
    final normalized = studentAnswer.trim().toLowerCase();
    if (normalized.isEmpty) return 0.0;
    if (qrocExpectedKeywords.isEmpty) {
      final ref = qrocReferenceAnswer.trim().toLowerCase();
      if (ref.isEmpty) return 1.0;
      return normalized.contains(ref) || ref.contains(normalized) ? 1.0 : 0.0;
    }
    int matched = 0;
    for (final kw in qrocExpectedKeywords) {
      if (normalized.contains(kw.trim().toLowerCase())) {
        matched++;
      }
    }
    return matched / qrocExpectedKeywords.length;
  }

  factory CustomExamQuestion.fromJson(Map<String, dynamic> json) {
    final fmtStr = json['format']?.toString() ?? 'qcs';
    final fmt = CustomQuestionFormat.values.firstWhere(
      (f) => f.name == fmtStr,
      orElse: () => CustomQuestionFormat.qcs,
    );
    return CustomExamQuestion(
      id: json['id']?.toString() ?? '',
      format: fmt,
      questionText: json['question_text']?.toString() ?? '',
      options: (json['options'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      correctOptionIndices: (json['correct_option_indices'] as List?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      qrocReferenceAnswer: json['qroc_reference_answer']?.toString() ?? '',
      qrocExpectedKeywords: (json['qroc_expected_keywords'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      explanation: json['explanation']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'format': format.name,
        'question_text': questionText,
        'options': options,
        'correct_option_indices': correctOptionIndices,
        'qroc_reference_answer': qrocReferenceAnswer,
        'qroc_expected_keywords': qrocExpectedKeywords,
        'explanation': explanation,
      };

  @override
  List<Object?> get props => [id, format, questionText];
}

class TeacherExamModel extends Equatable {
  final String id;
  final String accessCode;
  final String authorName;
  final AcademicRank academicRank;
  final String specialty;
  final String faculty;
  final String examCategory; // 'emd_externat', 'concours_residanat', 'stage_evaluation'
  final String title;
  final String description;
  final int durationMinutes;
  final String scoringMode; // 'partial', 'allOrNothing', 'negative'
  final List<String> medsinaQuestionIds;
  final List<CustomExamQuestion> customQuestions;
  final DateTime createdAt;

  const TeacherExamModel({
    required this.id,
    required this.accessCode,
    required this.authorName,
    required this.academicRank,
    required this.specialty,
    required this.faculty,
    required this.examCategory,
    required this.title,
    this.description = '',
    this.durationMinutes = 45,
    this.scoringMode = 'partial',
    this.medsinaQuestionIds = const [],
    this.customQuestions = const [],
    required this.createdAt,
  });

  int get totalQuestionsCount => medsinaQuestionIds.length + customQuestions.length;

  String get categoryLabel {
    switch (examCategory) {
      case 'concours_residanat':
        return 'Concours Blanc Résidanat';
      case 'stage_evaluation':
        return 'Évaluation de Stage';
      default:
        return 'Examen EMD Externat';
    }
  }

  factory TeacherExamModel.fromJson(Map<String, dynamic> json) {
    final rankStr = json['academic_rank']?.toString() ?? 'maitreAssistant';
    final rank = AcademicRank.values.firstWhere(
      (r) => r.name == rankStr,
      orElse: () => AcademicRank.maitreAssistant,
    );
    final rawMedsina = json['medsina_question_ids'];
    final medsinaIds = rawMedsina is List ? rawMedsina.map((e) => e.toString()).toList() : <String>[];
    final rawCustom = json['custom_questions'];
    final customQs = rawCustom is List
        ? rawCustom
            .whereType<Map>()
            .map((e) => CustomExamQuestion.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <CustomExamQuestion>[];

    return TeacherExamModel(
      id: json['id']?.toString() ?? '',
      accessCode: json['access_code']?.toString() ?? '',
      authorName: json['author_name']?.toString() ?? 'Enseignant HU',
      academicRank: rank,
      specialty: json['specialty']?.toString() ?? 'Cardiologie',
      faculty: json['faculty']?.toString() ?? 'Blida',
      examCategory: json['exam_category']?.toString() ?? 'emd_externat',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 45,
      scoringMode: json['scoring_mode']?.toString() ?? 'partial',
      medsinaQuestionIds: medsinaIds,
      customQuestions: customQs,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'access_code': accessCode,
        'author_name': authorName,
        'academic_rank': academicRank.name,
        'specialty': specialty,
        'faculty': faculty,
        'exam_category': examCategory,
        'title': title,
        'description': description,
        'duration_minutes': durationMinutes,
        'scoring_mode': scoringMode,
        'medsina_question_ids': medsinaQuestionIds,
        'custom_questions': customQuestions.map((q) => q.toJson()).toList(),
        'created_at': createdAt.toIso8601String(),
      };

  @override
  List<Object?> get props => [id, accessCode, title, specialty, examCategory];
}
