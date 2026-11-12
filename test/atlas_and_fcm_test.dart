import 'package:flutter_test/flutter_test.dart';
import 'package:medsina/features/atlas/data/clinical_atlas_repository.dart';
import 'package:medsina/features/atlas/models/clinical_atlas_model.dart';
import 'package:medsina/features/notifications/services/fcm_service.dart';

void main() {
  group('ClinicalAtlasRepository & Model', () {
    test('curatedCases has rich Blida high-yield cases and filters properly', () {
      final all = ClinicalAtlasRepository.curatedCases;
      expect(all.length, greaterThanOrEqualTo(8));

      final ecgOnly = ClinicalAtlasRepository.filterCases(
        all,
        modality: ClinicalModality.ecg,
      );
      expect(ecgOnly.length, greaterThanOrEqualTo(2));
      expect(ecgOnly.every((c) => c.modality == ClinicalModality.ecg), isTrue);

      final searchPneumo = ClinicalAtlasRepository.filterCases(
        all,
        query: 'pneumothorax',
      );
      expect(searchPneumo.length, 1);
      expect(searchPneumo.first.specialty, 'Pneumologie');
    });

    test('ClinicalAtlasCase JSON serialization roundtrip', () {
      final original = ClinicalAtlasRepository.curatedCases.first;
      final restored = ClinicalAtlasCase.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.modality, original.modality);
      expect(restored.diagnosis, original.diagnosis);
    });

    test('ClinicalModality.fromString maps common labels', () {
      expect(ClinicalModality.fromString('ECG'), ClinicalModality.ecg);
      expect(ClinicalModality.fromString('TDM / IRM'), ClinicalModality.tdmIrm);
      expect(ClinicalModality.fromString('Dermatologie'), ClinicalModality.dermatologie);
      expect(ClinicalModality.fromString('Fond d\'œil'), ClinicalModality.ophtalmologie);
    });
  });

  group('FcmService', () {
    test('exposes expected default Medsina topics', () {
      expect(FcmService.defaultTopics, contains('medsina_all'));
      expect(FcmService.defaultTopics, contains('medsina_residanat_blida'));
      expect(FcmService.defaultTopics, contains('medsina_updates'));
    });
  });
}
