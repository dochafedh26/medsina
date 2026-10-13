import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:medsina/features/revision/models/qcm_model.dart';

void main() {
  group('Course-Specific QCM Isolation Tests', () {
    test('Muscles de la hanche et de la cuisse loads its own anatomical questions', () {
      final file = File('assets/data/qcms/Blida_ANATOMIE_1_ERE.json');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      final list = jsonDecode(content) as List<dynamic>;
      final questions = list
          .map((m) => QcmQuestion.fromJson(m as Map<String, dynamic>))
          .where((q) => q.courseId == 'Blida_ANATOMIE_1_ERE_MUSCLES_DE_LA_HANCHE_ET_DE_LA_CUISSE')
          .toList();

      expect(questions.isNotEmpty, isTrue);
      expect(questions.length, equals(11));

      // Verify that questions are indeed about muscles/anatomy and not hypertension
      for (final q in questions) {
        expect(q.courseName, equals('Muscles de la hanche et de la cuisse'));
        expect(q.questionText.toLowerCase().contains('hypertension'), isFalse);
        expect(q.questionText.toLowerCase().contains('tensionnelle'), isFalse);
        expect(q.moduleId, equals('Blida_ANATOMIE_1_ERE'));
      }

      // First question check
      expect(questions.first.questionText.contains('groupe musculaire médial de la cuisse'), isTrue);
      expect(questions.first.options.any((o) => o.text.contains('semi-tendineux')), isTrue);
    });

    test('Cardiologie module questions are segregated into Blida_CARDIOLOGIE.json', () {
      final file = File('assets/data/qcms/Blida_CARDIOLOGIE.json');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      final list = jsonDecode(content) as List<dynamic>;
      expect(list.length, greaterThan(100));

      final firstQ = QcmQuestion.fromJson(list.first as Map<String, dynamic>);
      expect(firstQ.moduleId, equals('Blida_CARDIOLOGIE'));
    });
  });
}
