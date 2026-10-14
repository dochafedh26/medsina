import 'package:flutter_test/flutter_test.dart';
import 'package:medsina/features/revision/models/revision_session_model.dart';
import 'package:medsina/features/revision/services/revision_session_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Revision Session Models and Storage Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('CourseRevisionProgress serialization and deserialization', () {
      final now = DateTime.now();
      final progress = CourseRevisionProgress(
        courseId: 'c1',
        courseName: 'Cardiopathies congénitales',
        moduleId: 'm_cardio',
        currentQuestionIndex: 5,
        totalQuestions: 20,
        userAnswers: {
          'q1': {'A'},
          'q2': {'A', 'C'},
        },
        revealedQuestions: {'q1', 'q2'},
        isCompleted: false,
        lastActiveAt: now,
      );

      final json = progress.toJson();
      final restored = CourseRevisionProgress.fromJson(json);

      expect(restored.courseId, 'c1');
      expect(restored.courseName, 'Cardiopathies congénitales');
      expect(restored.currentQuestionIndex, 5);
      expect(restored.totalQuestions, 20);
      expect(restored.userAnswers['q1'], {'A'});
      expect(restored.userAnswers['q2'], {'A', 'C'});
      expect(restored.revealedQuestions.contains('q1'), isTrue);
      expect(restored.revealedQuestions.contains('q2'), isTrue);
      expect(restored.isCompleted, isFalse);
    });

    test('CustomRevisionSession serialization and deserialization', () {
      final now = DateTime.now();
      final session = CustomRevisionSession(
        id: 'session_123',
        title: 'Session Mixte Cardio-Anat',
        moduleIds: const ['m_cardio', 'm_anat'],
        courseIds: const ['c_cardio_1', 'c_anat_1'],
        questionLimit: 30,
        shuffleQuestions: true,
        currentQuestionIndex: 3,
        totalQuestions: 30,
        userAnswers: {
          'q1': {'B'},
        },
        revealedQuestions: {'q1'},
        isCompleted: false,
        createdAt: now,
        lastActiveAt: now,
      );

      final json = session.toJson();
      final restored = CustomRevisionSession.fromJson(json);

      expect(restored.id, 'session_123');
      expect(restored.title, 'Session Mixte Cardio-Anat');
      expect(restored.courseIds, ['c_cardio_1', 'c_anat_1']);
      expect(restored.questionLimit, 30);
      expect(restored.shuffleQuestions, isTrue);
      expect(restored.currentQuestionIndex, 3);
      expect(restored.progressPercentage, closeTo(4 / 30, 0.001));
    });

    test('RevisionSessionStorage saves and retrieves course progress', () async {
      final storage = RevisionSessionStorage.instance;
      final progress = CourseRevisionProgress(
        courseId: 'c_test',
        courseName: 'Test Course',
        moduleId: 'm_test',
        currentQuestionIndex: 7,
        totalQuestions: 15,
        userAnswers: {
          'q0': {'A'},
        },
        revealedQuestions: {'q0'},
        isCompleted: false,
        lastActiveAt: DateTime.now(),
      );

      await storage.saveCourseProgress(progress);

      final retrieved = await storage.getCourseProgress('c_test');
      expect(retrieved, isNotNull);
      expect(retrieved!.currentQuestionIndex, 7);
      expect(retrieved.totalQuestions, 15);

      final all = await storage.getAllCourseProgress();
      expect(all.containsKey('c_test'), isTrue);

      await storage.clearCourseProgress('c_test');
      final afterClear = await storage.getCourseProgress('c_test');
      expect(afterClear, isNull);
    });

    test('RevisionSessionStorage saves and retrieves custom sessions', () async {
      final storage = RevisionSessionStorage.instance;
      final session = CustomRevisionSession(
        id: 'sess_1',
        title: 'Session Test',
        moduleIds: const ['m1'],
        courseIds: const ['c1'],
        questionLimit: 10,
        shuffleQuestions: false,
        currentQuestionIndex: 2,
        totalQuestions: 10,
        userAnswers: const {},
        revealedQuestions: const {},
        isCompleted: false,
        createdAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
      );

      await storage.saveCustomSession(session);
      var sessions = await storage.getCustomSessions();
      expect(sessions.length, 1);
      expect(sessions.first.id, 'sess_1');

      await storage.deleteCustomSession('sess_1');
      sessions = await storage.getCustomSessions();
      expect(sessions.isEmpty, isTrue);
    });
  });
}

