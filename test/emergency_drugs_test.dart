import 'package:flutter_test/flutter_test.dart';
import 'package:medsina/features/clinical/data/clinical_repository.dart';
import 'package:medsina/features/clinical/models/emergency_drug_model.dart';
import 'package:medsina/features/clinical/bloc/clinical_bloc.dart';
import 'package:medsina/features/clinical/bloc/clinical_event.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Emergency Drugs & DCI Algeria Tests', () {
    test('EmergencyDrugModel serialization and deserialization', () {
      const drug = EmergencyDrugModel(
        id: 'drug_nicardipine',
        dci: 'Nicardipine',
        brand: 'Loxen / Nicardipine Saidal',
        category: 'Cardio / ACR / Choc',
        route: 'Perfusion IV (PSE)',
        indication: 'Poussée hypertensive sévère, OAP hypertensif, pré-éclampsie',
        dose: '5 à 10 mg/h au PSE',
        alert: 'Contre-indiqué en cas de sténose aortique serrée.',
        algerianAvailability: 'Disponible UMC / Maternité (Saidal)',
      );

      final json = drug.toJson();
      final restored = EmergencyDrugModel.fromJson(json);

      expect(restored.id, 'drug_nicardipine');
      expect(restored.dci, 'Nicardipine');
      expect(restored.brand, 'Loxen / Nicardipine Saidal');
      expect(restored.category, 'Cardio / ACR / Choc');
      expect(restored.algerianAvailability, 'Disponible UMC / Maternité (Saidal)');
    });

    test('ClinicalRepository fetches emergency drugs from local JSON asset', () async {
      final drugs = await ClinicalRepository.fetchEmergencyDrugs();
      expect(drugs.length, greaterThanOrEqualTo(50));

      final adrenaline = drugs.firstWhere((d) => d.id == 'drug_adrenaline');
      expect(adrenaline.dci, 'Adrénaline');
      expect(adrenaline.category, 'Cardio / ACR / Choc');

      final nicardipine = drugs.firstWhere((d) => d.id == 'drug_nicardipine');
      expect(nicardipine.brand.contains('Saidal'), isTrue);

      final sas = drugs.firstWhere((d) => d.id == 'drug_sas_serum_antiscorpionique');
      expect(sas.brand.contains('IPA'), isTrue);
    });

    test('ClinicalBloc searches and filters emergency drugs', () async {
      final bloc = ClinicalBloc();
      bloc.add(const LoadClinicalDataEvent());

      await expectLater(
        bloc.stream,
        emitsThrough(
          predicate<dynamic>((state) =>
              state.allDrugs.length >= 50 &&
              state.filteredDrugs.length >= 50),
        ),
      );

      // Search by brand Saidal
      bloc.add(const SearchEmergencyDrugsEvent('Saidal'));
      await expectLater(
        bloc.stream,
        emitsThrough(
          predicate<dynamic>((state) =>
              state.drugSearchQuery == 'Saidal' &&
              state.filteredDrugs.isNotEmpty &&
              state.filteredDrugs.every((d) =>
                  d.brand.toLowerCase().contains('saidal') ||
                  d.dci.toLowerCase().contains('saidal') ||
                  (d.algerianAvailability?.toLowerCase().contains('saidal') ?? false))),
        ),
      );

      // Filter by category
      bloc.add(const FilterDrugCategoryEvent('Respiratoire'));
      await expectLater(
        bloc.stream,
        emitsThrough(
          predicate<dynamic>((state) =>
              state.selectedDrugCategory == 'Respiratoire' &&
              state.filteredDrugs.every((d) => d.category == 'Respiratoire')),
        ),
      );

      await bloc.close();
    });
  });
}

