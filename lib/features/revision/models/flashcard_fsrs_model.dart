import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/cloud_sync_service.dart';
import 'qcm_model.dart';

enum FsrsCardState { newCard, learning, review, relearning }

enum FsrsRating { again, hard, good, easy }

class FlashcardFsrsItem {
  final String id;
  final String front;
  final String back;
  final String moduleId;
  final String courseName;
  final String? linkedQuestionId;
  final FsrsCardState state;
  final double stability; // S (in days)
  final double difficulty; // D (1.0 .. 10.0)
  final int reps;
  final int lapses;
  final DateTime dueDate;
  final DateTime? lastReviewedAt;
  final DateTime createdAt;

  const FlashcardFsrsItem({
    required this.id,
    required this.front,
    required this.back,
    this.moduleId = '',
    this.courseName = '',
    this.linkedQuestionId,
    this.state = FsrsCardState.newCard,
    this.stability = 1.0,
    this.difficulty = 5.0,
    this.reps = 0,
    this.lapses = 0,
    required this.dueDate,
    this.lastReviewedAt,
    required this.createdAt,
  });

  bool get isDueNow => !dueDate.isAfter(DateTime.now());
  bool get isMature => stability >= 21.0;

  /// Estimated memory retention R (0.0 .. 1.0) using FSRS power forgetting curve.
  double get estimatedRetention {
    if (lastReviewedAt == null || state == FsrsCardState.newCard) return 1.0;
    final elapsedDays =
        DateTime.now().difference(lastReviewedAt!).inHours / 24.0;
    if (elapsedDays <= 0 || stability <= 0) return 1.0;
    return math.pow(1.0 + elapsedDays / (9.0 * stability), -1.0).toDouble().clamp(0.0, 1.0);
  }

  FlashcardFsrsItem copyWith({
    String? front,
    String? back,
    String? moduleId,
    String? courseName,
    FsrsCardState? state,
    double? stability,
    double? difficulty,
    int? reps,
    int? lapses,
    DateTime? dueDate,
    DateTime? lastReviewedAt,
  }) {
    return FlashcardFsrsItem(
      id: id,
      front: front ?? this.front,
      back: back ?? this.back,
      moduleId: moduleId ?? this.moduleId,
      courseName: courseName ?? this.courseName,
      linkedQuestionId: linkedQuestionId,
      state: state ?? this.state,
      stability: stability ?? this.stability,
      difficulty: difficulty ?? this.difficulty,
      reps: reps ?? this.reps,
      lapses: lapses ?? this.lapses,
      dueDate: dueDate ?? this.dueDate,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
      createdAt: createdAt,
    );
  }

  factory FlashcardFsrsItem.fromJson(Map<String, dynamic> json) {
    final stateStr = json['state']?.toString() ?? 'newCard';
    final parsedState = FsrsCardState.values.firstWhere(
      (e) => e.name == stateStr,
      orElse: () => FsrsCardState.newCard,
    );
    return FlashcardFsrsItem(
      id: json['id']?.toString() ?? '',
      front: json['front']?.toString() ?? '',
      back: json['back']?.toString() ?? '',
      moduleId: json['moduleId']?.toString() ?? '',
      courseName: json['courseName']?.toString() ?? '',
      linkedQuestionId: json['linkedQuestionId']?.toString(),
      state: parsedState,
      stability: (json['stability'] as num?)?.toDouble() ?? 1.0,
      difficulty: (json['difficulty'] as num?)?.toDouble() ?? 5.0,
      reps: (json['reps'] as num?)?.toInt() ?? 0,
      lapses: (json['lapses'] as num?)?.toInt() ?? 0,
      dueDate: json['dueDate'] != null
          ? DateTime.tryParse(json['dueDate'].toString()) ?? DateTime.now()
          : DateTime.now(),
      lastReviewedAt: json['lastReviewedAt'] != null
          ? DateTime.tryParse(json['lastReviewedAt'].toString())
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'front': front,
        'back': back,
        'moduleId': moduleId,
        'courseName': courseName,
        if (linkedQuestionId != null) 'linkedQuestionId': linkedQuestionId,
        'state': state.name,
        'stability': stability,
        'difficulty': difficulty,
        'reps': reps,
        'lapses': lapses,
        'dueDate': dueDate.toIso8601String(),
        if (lastReviewedAt != null)
          'lastReviewedAt': lastReviewedAt!.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };
}

/// FSRS v4.5 inspired scheduler & offline-first Flashcard manager.
class FlashcardFsrsService extends ChangeNotifier {
  FlashcardFsrsService._();
  static final FlashcardFsrsService instance = FlashcardFsrsService._();

  static const String _prefKey = 'medsina_fsrs_flashcards_v1';
  List<FlashcardFsrsItem> _cards = [];
  bool _initialized = false;

  List<FlashcardFsrsItem> get cards => _cards;

  List<FlashcardFsrsItem> get dueCards =>
      _cards.where((c) => c.isDueNow).toList()
        ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

  Future<void> ensureInitialized() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        _cards = list
            .whereType<Map>()
            .map((m) => FlashcardFsrsItem.fromJson(Map<String, dynamic>.from(m)))
            .toList();
      } catch (e) {
        debugPrint('Error loading FSRS flashcards: $e');
      }
    }
    if (_cards.isEmpty) {
      _cards = _buildStarterHighYieldCards();
      await _persist();
    }
    _initialized = true;
  }

  bool hasFlashcardForQuestion(String questionId) {
    return _cards.any((c) => c.linkedQuestionId == questionId);
  }

  /// Creates an FSRS Flashcard directly from a QCM question in 1 click.
  Future<FlashcardFsrsItem> createFromQuestion(QcmQuestion q) async {
    await ensureInitialized();
    final existingIdx =
        _cards.indexWhere((c) => c.linkedQuestionId == q.id);
    if (existingIdx != -1) {
      return _cards[existingIdx];
    }

    final correctOpts = q.options
        .where((o) => q.correctAnswers.contains(o.key))
        .map((o) => '- **${o.key}.** ${o.text}')
        .join('\n');

    final frontText = StringBuffer()
      ..writeln('**[${q.courseName}]** (${q.source} ${q.year})')
      ..writeln()
      ..writeln(q.questionText);
    if (q.options.isNotEmpty) {
      frontText.writeln();
      for (final opt in q.options) {
        frontText.writeln('${opt.key}. ${opt.text}');
      }
    }

    final backText = StringBuffer()
      ..writeln('### ✅ Réponse(s) exacte(s) : ${q.correctAnswers.join(", ")}')
      ..writeln(correctOpts)
      ..writeln();
    if (q.explanation.trim().isNotEmpty) {
      backText.writeln('---');
      backText.writeln(q.explanation.trim());
    }

    final now = DateTime.now();
    final card = FlashcardFsrsItem(
      id: 'qcm_${q.id}',
      front: frontText.toString().trim(),
      back: backText.toString().trim(),
      moduleId: q.moduleId,
      courseName: q.courseName,
      linkedQuestionId: q.id,
      state: FsrsCardState.newCard,
      stability: 1.2,
      difficulty: q.isInverse ? 6.4 : 5.2,
      dueDate: now,
      createdAt: now,
    );

    _cards.insert(0, card);
    await _persist();
    notifyListeners();
    return card;
  }

  Future<FlashcardFsrsItem> createCustomCard({
    required String front,
    required String back,
    String moduleId = 'Général',
    String courseName = 'Note Personnelle',
  }) async {
    await ensureInitialized();
    final now = DateTime.now();
    final card = FlashcardFsrsItem(
      id: 'custom_${now.millisecondsSinceEpoch}',
      front: front.trim(),
      back: back.trim(),
      moduleId: moduleId,
      courseName: courseName,
      dueDate: now,
      createdAt: now,
    );
    _cards.insert(0, card);
    await _persist();
    notifyListeners();
    return card;
  }

  Future<void> deleteCard(String id) async {
    await ensureInitialized();
    _cards.removeWhere((c) => c.id == id);
    await _persist();
    notifyListeners();
  }

  /// Preview human-readable next interval for a given rating on a card.
  String previewNextIntervalLabel(FlashcardFsrsItem card, FsrsRating rating) {
    final scheduled = _computeNextSchedule(card, rating);
    final diff = scheduled.dueDate.difference(DateTime.now());
    if (diff.inMinutes < 60) {
      return '${math.max(1, diff.inMinutes)} min';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours} h';
    }
    return '${math.max(1, diff.inDays)} j';
  }

  /// Apply an FSRS review grade and persist updated stability, difficulty, and dueDate.
  Future<FlashcardFsrsItem> reviewCard(
    FlashcardFsrsItem card,
    FsrsRating rating,
  ) async {
    await ensureInitialized();
    final updated = _computeNextSchedule(card, rating);
    final idx = _cards.indexWhere((c) => c.id == card.id);
    if (idx != -1) {
      _cards[idx] = updated;
    }
    await _persist();
    notifyListeners();
    return updated;
  }

  FlashcardFsrsItem _computeNextSchedule(
    FlashcardFsrsItem card,
    FsrsRating rating,
  ) {
    final now = DateTime.now();
    double d = card.difficulty;
    double s = card.stability;
    int reps = card.reps + 1;
    int lapses = card.lapses;
    FsrsCardState nextState = card.state;
    DateTime nextDue;

    switch (rating) {
      case FsrsRating.again:
        d = (d + 1.2).clamp(1.0, 10.0);
        s = math.max(0.4, s * 0.35);
        lapses += 1;
        nextState = card.reps == 0
            ? FsrsCardState.learning
            : FsrsCardState.relearning;
        nextDue = now.add(const Duration(minutes: 10));
        break;
      case FsrsRating.hard:
        d = (d + 0.45).clamp(1.0, 10.0);
        s = card.reps == 0 ? 1.2 : math.max(1.0, s * 1.35);
        nextState = FsrsCardState.review;
        final days = math.max(1, s.round());
        nextDue = now.add(Duration(days: days));
        break;
      case FsrsRating.good:
        d = (d - 0.15).clamp(1.0, 10.0);
        final factor = 2.1 + (10.0 - d) * 0.15;
        s = card.reps == 0 ? 2.5 : (s * factor).clamp(1.5, 365.0);
        nextState = FsrsCardState.review;
        nextDue = now.add(Duration(days: math.max(2, s.round())));
        break;
      case FsrsRating.easy:
        d = (d - 0.45).clamp(1.0, 10.0);
        final factor = 2.8 + (10.0 - d) * 0.2;
        s = card.reps == 0 ? 5.0 : (s * factor).clamp(4.0, 365.0);
        nextState = FsrsCardState.review;
        nextDue = now.add(Duration(days: math.max(4, s.round())));
        break;
    }

    return card.copyWith(
      state: nextState,
      stability: double.parse(s.toStringAsFixed(2)),
      difficulty: double.parse(d.toStringAsFixed(2)),
      reps: reps,
      lapses: lapses,
      dueDate: nextDue,
      lastReviewedAt: now,
    );
  }

  Map<String, dynamic> getStatsSummary() {
    final total = _cards.length;
    final newCount =
        _cards.where((c) => c.state == FsrsCardState.newCard).length;
    final learningCount = _cards
        .where((c) =>
            c.state == FsrsCardState.learning ||
            c.state == FsrsCardState.relearning)
        .length;
    final reviewCount =
        _cards.where((c) => c.state == FsrsCardState.review).length;
    final matureCount = _cards.where((c) => c.isMature).length;
    final dueToday = dueCards.length;

    double avgStability = 0;
    double avgDifficulty = 0;
    double avgRetention = 0;
    if (total > 0) {
      avgStability =
          _cards.fold<double>(0, (s, c) => s + c.stability) / total;
      avgDifficulty =
          _cards.fold<double>(0, (s, c) => s + c.difficulty) / total;
      avgRetention =
          _cards.fold<double>(0, (s, c) => s + c.estimatedRetention) / total;
    }

    return {
      'total': total,
      'new': newCount,
      'learning': learningCount,
      'review': reviewCount,
      'mature': matureCount,
      'dueToday': dueToday,
      'avgStability': avgStability,
      'avgDifficulty': avgDifficulty,
      'avgRetention': avgRetention,
    };
  }

  bool _isImporting = false;

  Future<void> importCards(List<FlashcardFsrsItem> cards) async {
    _isImporting = true;
    _cards = List<FlashcardFsrsItem>.from(cards);
    await _persist();
    _isImporting = false;
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_cards.map((c) => c.toJson()).toList());
      await prefs.setString(_prefKey, encoded);
      if (!_isImporting) {
        CloudSyncService.instance.notifyLocalChange(
          'fsrs_flashcards',
          _cards.map((c) => c.toJson()).toList(),
        );
      }
    } catch (e) {
      debugPrint('Error saving FSRS flashcards: $e');
    }
  }

  List<FlashcardFsrsItem> _buildStarterHighYieldCards() {
    final now = DateTime.now();
    return [
      FlashcardFsrsItem(
        id: 'starter_blida_1',
        front:
            '**[Piège Résidanat Blida • Anatomie]**\n\nDans l\'articulation talo-crurale (cheville), la paroi latérale de la mortaise tibio-fibulaire correspond-elle à la malléole tibiale ?',
        back:
            '### ❌ NON — Piège fréquent aux EMD de Blida !\n\n- La **malléole tibiale** est **médiale (interne)**.\n- La paroi **latérale (externe)** de la mortaise correspond à la **malléole fibulaire (péronière)**.\n- Toujours associer : **Tibia = Médial**, **Fibula = Latéral**.',
        moduleId: 'Anatomie',
        courseName: 'Articulation de la cheville et du pied',
        stability: 2.4,
        difficulty: 4.8,
        dueDate: now,
        createdAt: now,
      ),
      FlashcardFsrsItem(
        id: 'starter_blida_2',
        front:
            '**[Piège Résidanat Blida • Cardiologie]**\n\nQuel est le critère ECG principal différenciant un BAV II Mobitz 1 (Wenckebach) d\'un BAV II Mobitz 2 ?',
        back:
            '### ✅ L\'évolution de l\'espace PR avant l\'onde P bloquée :\n\n- **Mobitz 1 (Wenckebach)** : allongement **progressif** du PR jusqu\'à une onde P bloquée (bloc **nodal**, bénin).\n- **Mobitz 2** : espace PR **constant** avant l\'onde P bloquée (bloc **infra-hisien**, haut risque d\'asystolie → **Pacemaker**).',
        moduleId: 'Cardiologie',
        courseName: 'Troubles de la conduction',
        stability: 3.1,
        difficulty: 5.2,
        dueDate: now,
        createdAt: now,
      ),
      FlashcardFsrsItem(
        id: 'starter_blida_3',
        front:
            '**[Piège Résidanat Blida • Cytologie]**\n\nQuel est le diamètre des microfilaments d\'actine vs filaments intermédiaires vs microtubules ?',
        back:
            '### ✅ Règle mnémotechnique « 7 - 10 - 25 nm » :\n\n- **Microfilaments d\'actine (F-actine)** : **7 nm** (polarisés, dépendants de l\'ATP).\n- **Filaments intermédiaires** : **10 nm** (non polarisés, résistance mécanique).\n- **Microtubules** : **25 nm** (polarisés, dimères α/β-tubuline, liés au GTP).',
        moduleId: 'Cytologie',
        courseName: 'Cytosquelette',
        stability: 1.8,
        difficulty: 4.5,
        dueDate: now,
        createdAt: now,
      ),
    ];
  }
}
