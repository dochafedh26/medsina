import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/supabase_service.dart';
import '../../revision/data/residency_repository.dart';
import '../../revision/models/qcm_model.dart';
import '../models/teacher_workspace_model.dart';

class TeacherWorkspaceService {
  static const String _localPubsKey = 'medsina_teacher_publications_v1';
  static const String _localExamsKey = 'medsina_teacher_exams_v1';

  static final List<TeacherPublicationItem> _builtinExamples = [
    TeacherPublicationItem(
      id: 'pub_demo_cardio_sca',
      authorName: 'Dr. Mansouri (Cardiologie)',
      academicRank: AcademicRank.maitreAssistant,
      specialty: 'Cardiologie',
      faculty: 'Blida',
      targetAudience: 'Externat 4ème Année & Résidanat',
      contentType: TeacherContentType.summary,
      title: 'Fiche High-Yield : Prise en charge du SCA ST+ à H0',
      summaryDescription: 'Algorithme décisionnel Coronarographie primaire vs Fibrinolyse (délai 120 min) & traitement antithrombotique.',
      markdownBody:
          '### 1. Diagnostic ECG immédiat (< 10 min)\n'
          '- Sus-décalage ST ≥ 1 mm dans ≥ 2 dérivations contiguës (≥ 2 mm en V2-V3).\n'
          '- Ou BBG récent / présumé récent avec instabilité hémodynamique.\n\n'
          '### 2. Stratégie de Reperfusion\n'
          '- **Angioplastie primaire (ATL)** si réalisable en **< 120 minutes**.\n'
          '- Sinon **Fibrinolyse IV** (Tenecteplase / Metalyse) en < 10 min en l\'absence de contre-indication.\n\n'
          '### 3. Traitement Adjuvant (BASIC + Antithrombotiques)\n'
          '- Aspirine 150-300 mg PO/IV + Inhibiteur P2Y12 (Ticagrelor/Prasugrel ou Clopidogrel) + Héparine (Enoxaparine/HNF).',
      flashcards: const [
        TeacherFlashcardPair(
          front: 'Quel est le délai maximal toléré entre le diagnostic ECG d\'un SCA ST+ et le passage du guide en salle de cathétérisme pour préférer l\'ATL primaire ?',
          back: '120 minutes (2 heures). Au-delà, indiquer une fibrinolyse IV immédiate.',
        ),
        TeacherFlashcardPair(
          front: 'Quel territoire coronaire correspond à un sus-décalage ST en DII, DIII, aVF ?',
          back: 'Territoire INFÉRIEUR (Artère Coronaire Droite dans 80% des cas) — Penser à faire les dérivations droites V3R-V4R et V7-V8-V9 !',
        ),
      ],
      createdAt: DateTime(2026, 11, 10),
    ),
  ];

  static final List<TeacherExamModel> _builtinExams = [
    TeacherExamModel(
      id: 'exam_demo_emd_cardio',
      accessCode: 'EMD-BLIDA-27',
      authorName: 'Pr. Benali (CHU Blida)',
      academicRank: AcademicRank.professeur,
      specialty: 'Cardiologie',
      faculty: 'Blida',
      examCategory: 'emd_externat',
      title: 'EMD Blanc Cardiologie — Urgences Coronariennes & HTA',
      description: 'Épreuve hybride combinant des QCMs officiels de la banque Medsina et des QROCs rédigées par le service.',
      durationMinutes: 30,
      scoringMode: 'partial',
      medsinaQuestionIds: const ['q_demo_1'],
      customQuestions: const [
        CustomExamQuestion(
          id: 'cq_1',
          format: CustomQuestionFormat.qroc,
          questionText:
              'Un patient de 58 ans présente un SCA ST+ antérieur étendu diagnostiqué à 22h00 dans un hôpital périphérique situé à 3h30 de route du centre de coronarographie le plus proche. Quelle stratégie de reperfusion indiquez-vous en urgence ?',
          qrocReferenceAnswer: 'Fibrinolyse intraveineuse (thrombolyse) immédiate',
          qrocExpectedKeywords: ['fibrinolyse', 'thrombolyse'],
          explanation: 'Le délai prévisible jusqu\'à l\'angioplastie dépasse 120 minutes (3h30) : la fibrinolyse IV est formellement indiquée en l\'absence de contre-indication.',
        ),
        CustomExamQuestion(
          id: 'cq_2',
          format: CustomQuestionFormat.qcm,
          questionText: 'Parmi les classes suivantes, lesquelles font partie du traitement de fond BASIC du post-infarctus (SCA ST+) ?',
          options: [
            'Bêta-bloquant',
            'Antiagrégant plaquettaire (Aspirine + P2Y12)',
            'Statine à forte dose',
            'IEC (Inhibiteur de l\'enzyme de conversion)',
            'Inhibiteur calcique dihydropyridinique systématique',
          ],
          correctOptionIndices: [0, 1, 2, 3],
          explanation: 'BASIC = Bêta-bloquant, Antiagrégant, Statine, IEC, Contrôle des facteurs de risque.',
        ),
      ],
      createdAt: DateTime(2026, 11, 12),
    ),
  ];

  static String generateExamAccessCode(String specialty) {
    final prefix = specialty.replaceAll(RegExp(r'[^A-Za-z]'), '').toUpperCase();
    final short = prefix.length >= 3 ? prefix.substring(0, 3) : 'MED';
    final num = 100 + Random().nextInt(900);
    return 'EMD-$short-$num';
  }

  static Future<List<TeacherPublicationItem>> loadPublications() async {
    final list = <TeacherPublicationItem>[];
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_localPubsKey);
      if (raw != null) {
        final decoded = jsonDecode(raw) as List;
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            list.add(TeacherPublicationItem.fromJson(item));
          }
        }
      }
    } catch (_) {}

    if (SupabaseService.isInitialized) {
      try {
        final rows = await SupabaseService.client
            .from('teacher_publications')
            .select()
            .order('created_at', ascending: false)
            .limit(40);
        final ids = list.map((e) => e.id).toSet();
        for (final r in rows) {
          final item = TeacherPublicationItem.fromJson(Map<String, dynamic>.from(r));
          if (!ids.contains(item.id)) list.add(item);
        }
      } catch (_) {}
    }

    final existingIds = list.map((e) => e.id).toSet();
    for (final b in _builtinExamples) {
      if (!existingIds.contains(b.id)) list.add(b);
    }
    return list;
  }

  static Future<void> publishItem(TeacherPublicationItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localPubsKey);
    final existing = raw != null ? (jsonDecode(raw) as List).cast<Map<String, dynamic>>() : <Map<String, dynamic>>[];
    existing.removeWhere((e) => e['id'] == item.id);
    existing.insert(0, item.toJson());
    await prefs.setString(_localPubsKey, jsonEncode(existing));

    final uid = SupabaseService.currentUser?.id;
    if (SupabaseService.isInitialized && uid != null) {
      try {
        await SupabaseService.client.from('teacher_publications').upsert({
          ...item.toJson(),
          'author_id': uid,
        });
      } catch (_) {}
    }
  }

  static Future<List<TeacherExamModel>> loadExams() async {
    final list = <TeacherExamModel>[];
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_localExamsKey);
      if (raw != null) {
        final decoded = jsonDecode(raw) as List;
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            list.add(TeacherExamModel.fromJson(item));
          }
        }
      }
    } catch (_) {}

    if (SupabaseService.isInitialized) {
      try {
        final rows = await SupabaseService.client
            .from('teacher_exams')
            .select()
            .eq('is_published', true)
            .order('created_at', ascending: false)
            .limit(40);
        final ids = list.map((e) => e.id).toSet();
        for (final r in rows) {
          final item = TeacherExamModel.fromJson(Map<String, dynamic>.from(r));
          if (!ids.contains(item.id)) list.add(item);
        }
      } catch (_) {}
    }

    final existingIds = list.map((e) => e.id).toSet();
    for (final b in _builtinExams) {
      if (!existingIds.contains(b.id)) list.add(b);
    }
    return list;
  }

  static Future<void> publishExam(TeacherExamModel exam) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localExamsKey);
    final existing = raw != null ? (jsonDecode(raw) as List).cast<Map<String, dynamic>>() : <Map<String, dynamic>>[];
    existing.removeWhere((e) => e['id'] == exam.id);
    existing.insert(0, exam.toJson());
    await prefs.setString(_localExamsKey, jsonEncode(existing));

    final uid = SupabaseService.currentUser?.id;
    if (SupabaseService.isInitialized && uid != null) {
      try {
        await SupabaseService.client.from('teacher_exams').upsert({
          ...exam.toJson(),
          'author_id': uid,
          'is_published': true,
        });
      } catch (_) {}
    }
  }

  /// Récupère des QCMs existants de Medsina pour un module donné afin de les inclure dans un examen enseignant
  static Future<List<QcmQuestion>> fetchMedsinaBankQuestions(String moduleId) async {
    return ResidencyRepository.getQuestionsForModuleAsync(moduleId);
  }
}
