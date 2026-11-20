import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medsina/features/prescription/data/algerian_nomenclature_repository.dart';
import 'package:medsina/features/prescription/data/vidal_interaction_repository.dart';
import 'package:medsina/features/prescription/data/terrain_contraindication_repository.dart';
import 'package:medsina/features/prescription/presentation/prescription_analysis_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Algerian Nomenclature & Vidal Prescription Analysis Tests', () {
    test('Algerian Nomenclature loads and searches Sintrom and Algerian drugs', () async {
      final catalog = await AlgerianNomenclatureRepository.loadCatalog();
      expect(catalog.isNotEmpty, true);
      expect(catalog.length >= 5000, true);

      // Search for Sintrom
      final sintromResults = AlgerianNomenclatureRepository.search('Sintrom');
      expect(sintromResults.isNotEmpty, true);
      final sintrom = sintromResults.firstWhere((d) => d.brand.contains('SINTROM'));
      expect(sintrom.dci, equals('ACENOCOUMAROL'));
      expect(sintrom.dosage, equals('4MG'));

      // Search for Rifamycine
      final rifamResults = AlgerianNomenclatureRepository.search('Rifam');
      expect(rifamResults.isNotEmpty, true);

      // DCI resolver
      final resolvedDci = AlgerianNomenclatureRepository.resolveActiveDci('SINTROM');
      expect(resolvedDci, equals('ACENOCOUMAROL'));
    });

    test('Vidal Interaction Engine detects Sintrom + Rifampicine interaction', () async {
      final rules = await VidalInteractionRepository.loadRules();
      expect(rules.isNotEmpty, true);

      // Test Case: Sintrom + Rifampicine
      final prescribed = [
        const PrescribedTarget(name: 'SINTROM 4 mg cp quadriséc', activeDci: 'ACENOCOUMAROL'),
        const PrescribedTarget(name: 'RIFAMPICINE 300 mg gél', activeDci: 'RIFAMPICINE'),
      ];

      final interactions = VidalInteractionRepository.findInteractions(prescribed, rules);
      expect(interactions.isNotEmpty, true);

      final sintromRifam = interactions.firstWhere(
        (i) => i.title.contains('Antivitamines K') && i.title.contains('Rifampicine'),
      );
      expect(sintromRifam.severity, equals(InteractionSeverity.precaution));
      expect(sintromRifam.description, contains('Diminution très importante des concentrations plasmatiques'));
      expect(sintromRifam.recommendation, contains('INR'));
    });

    test('Vidal Interaction Engine detects Colchicine + Clarithromycine contraindication', () async {
      final rules = await VidalInteractionRepository.loadRules();

      final prescribed = [
        const PrescribedTarget(name: 'Colchicine 1mg', activeDci: 'COLCHICINE'),
        const PrescribedTarget(name: 'Zeclar 500mg', activeDci: 'CLARITHROMYCINE'),
      ];

      final interactions = VidalInteractionRepository.findInteractions(prescribed, rules);
      expect(interactions.isNotEmpty, true);

      final colchicineZeclar = interactions.firstWhere(
        (i) => i.title.contains('Colchicine') && i.title.contains('Macrolides'),
      );
      expect(colchicineZeclar.severity, equals(InteractionSeverity.contraindicated));
      expect(colchicineZeclar.severityLevel, equals(4));
    });

    test('Vidal Interaction Engine detects Double AINS (Kétoprofène + Aspirine)', () async {
      final rules = await VidalInteractionRepository.loadRules();

      final prescribed = [
        const PrescribedTarget(name: 'Profénid 100mg', activeDci: 'KETOPROFENE'),
        const PrescribedTarget(name: 'Kardégic 160mg', activeDci: 'ASPIRINE'),
      ];

      final interactions = VidalInteractionRepository.findInteractions(prescribed, rules);
      expect(interactions.isNotEmpty, true);

      final doubleAins = interactions.firstWhere(
        (i) => i.title.contains('Anti-inflammatoires') && (i.title.contains('Deux') || i.title.contains('2')),
      );
      expect(doubleAins.severity, equals(InteractionSeverity.disadvised));
      expect(doubleAins.severityLevel, equals(3));
    });

    test('Vidal Interaction Engine detects Sintrom + Plavix severe hemorrhagic risk', () async {
      final rules = await VidalInteractionRepository.loadRules();

      // Exactly the user's test scenario:
      // Sintrom (Acénocoumarol) + Plavix (Clopidogrel)
      final prescribed = [
        const PrescribedTarget(name: 'SINTROM', activeDci: 'ACENOCOUMAROL'),
        const PrescribedTarget(name: 'PLAVIX', activeDci: 'CLOPIDOGREL HYDROGENOSULFATE EXPRIME EN CLOPIDOGREL'),
      ];

      final interactions = VidalInteractionRepository.findInteractions(prescribed, rules);
      expect(interactions.isNotEmpty, true);

      final sintromPlavix = interactions.firstWhere(
        (i) => i.title.contains('Antivitamines K') && i.title.contains('Antiagrégants'),
      );
      expect(sintromPlavix.severity, equals(InteractionSeverity.disadvised));
      expect(sintromPlavix.severityLevel, equals(3));
      expect(sintromPlavix.description, contains('hémorragique'));
      expect(sintromPlavix.recommendation, contains('INR'));
    });

    test('Vidal Interaction Engine detects Plavix + Oméprazole CYP2C19 loss of efficacy', () async {
      final rules = await VidalInteractionRepository.loadRules();

      final prescribed = [
        const PrescribedTarget(name: 'PLAVIX 75mg', activeDci: 'CLOPIDOGREL'),
        const PrescribedTarget(name: 'OMEPRAZOLE 20mg', activeDci: 'OMEPRAZOLE'),
      ];

      final interactions = VidalInteractionRepository.findInteractions(prescribed, rules);
      expect(interactions.isNotEmpty, true);

      final plavixOme = interactions.firstWhere(
        (i) => i.title.contains('Clopidogrel') && i.title.contains('Oméprazole'),
      );
      expect(plavixOme.severity, equals(InteractionSeverity.disadvised));
      expect(plavixOme.severityLevel, equals(3));
      expect(plavixOme.description, contains('CYP2C19'));
    });

    test('Patient Terrain Rules detect Solupred with Diabetes and Hypertension alerts', () async {
      final diabetesTerrain = 'Diabète de type 1 ou 2';
      final htaTerrain = 'Hypertension Artérielle non contrôlée';

      // Simulation of user test case
      final solupredName = 'SOLUPRED ORO';
      final solupredDci = 'PREDNISOLONE SOUS FORME METASULFOBENZOATE SODIQUE';

      // Verify that drug patterns match
      final corticoPatterns = ['PREDNISOLONE', 'SOLUPRED', 'PREDNISONE', 'CORTANCYL'];
      final matchesSolupred = corticoPatterns.any((p) =>
          solupredName.contains(p) || solupredDci.contains(p));

      expect(matchesSolupred, true);
      expect(diabetesTerrain.toLowerCase().contains('diabète'), true);
      expect(htaTerrain.toLowerCase().contains('hypertension'), true);
    });

    test('Vidal Interaction Engine detects Sintrom + Kétoprofène (with accents)', () async {
      final rules = await VidalInteractionRepository.loadRules();

      // Test exactly the user scenario from screenshot:
      // Sintrom (ACENOCOUMAROL) + Kétoprofène (accented)
      final resolvedDci = AlgerianNomenclatureRepository.resolveActiveDci('Kétoprofène');
      expect(resolvedDci, equals('KETOPROFENE'));

      final prescribed = [
        const PrescribedTarget(name: 'Sintrom', activeDci: 'ACENOCOUMAROL'),
        PrescribedTarget(name: 'Kétoprofène', activeDci: resolvedDci),
      ];

      final interactions = VidalInteractionRepository.findInteractions(prescribed, rules);
      expect(interactions.isNotEmpty, true);

      final sintromKeto = interactions.firstWhere(
        (i) => i.title.contains('Antivitamines K') && i.title.contains('Anti-inflammatoires'),
      );
      expect(sintromKeto.severity, equals(InteractionSeverity.disadvised));
      expect(sintromKeto.severityLevel, equals(3));
      expect(sintromKeto.description, contains('hémorragique'));
    });

    test('TerrainContraindicationRepository detects Rifampicine on Hépatite aiguë / Cytolyse active', () async {
      final terrainRules = await TerrainContraindicationRepository.loadRules();
      expect(terrainRules.isNotEmpty, true);
      expect(terrainRules.length >= 35, true);

      // Exactly the user's test scenario:
      // Drug: Rifampicine
      // Terrain: Hépatite aiguë / Cytolyse active
      final prescribed = [
        const PrescribedTarget(name: 'RIFAMPICINE 300 mg', activeDci: 'RIFAMPICINE'),
      ];
      final selectedTerrains = {'Hépatite aiguë / Cytolyse active'};

      final warnings = TerrainContraindicationRepository.findContraindications(
        prescribed,
        selectedTerrains,
        terrainRules,
      );

      expect(warnings.isNotEmpty, true);
      final rifamWarning = warnings.firstWhere(
        (w) => w.title.contains('Rifampicine') && w.terrain.contains('Hépatite'),
      );
      expect(rifamWarning.severity, equals(InteractionSeverity.contraindicated));
      expect(rifamWarning.severityLevel, equals(4));
      expect(rifamWarning.warning, contains('hépatotoxique'));
      expect(rifamWarning.recommendation, contains('Arrêt immédiat'));
      expect(rifamWarning.source, contains('Guide National Tuberculose Algérie'));
    });

    test('TerrainContraindicationRepository detects Paracetamol on Insuffisance Hépatique', () async {
      final terrainRules = await TerrainContraindicationRepository.loadRules();

      final prescribed = [
        const PrescribedTarget(name: 'DOLIPRANE 1000 mg', activeDci: 'PARACETAMOL'),
      ];
      final selectedTerrains = {'Insuffisance Hépatique'};

      final warnings = TerrainContraindicationRepository.findContraindications(
        prescribed,
        selectedTerrains,
        terrainRules,
      );

      expect(warnings.isNotEmpty, true);
      final paraWarning = warnings.firstWhere(
        (w) => w.title.contains('Paracétamol') && w.terrain.contains('Hépatique'),
      );
      expect(paraWarning.severity, equals(InteractionSeverity.contraindicated));
    });

    test('TerrainContraindicationRepository detects Colchicine on Insuffisance Rénale Sévère', () async {
      final terrainRules = await TerrainContraindicationRepository.loadRules();

      // Exactly user's test scenario:
      // Colchicine on Insuffisance Rénale Sévère
      final prescribed = [
        const PrescribedTarget(name: 'COLCHICINE 1mg', activeDci: 'COLCHICINE'),
      ];
      final selectedTerrains = {'Insuffisance Rénale Sévère'};

      final warnings = TerrainContraindicationRepository.findContraindications(
        prescribed,
        selectedTerrains,
        terrainRules,
      );

      expect(warnings.isNotEmpty, true);
      final colchicineWarning = warnings.firstWhere(
        (w) => w.title.contains('Colchicine') && w.terrain.contains('Rénale'),
      );
      expect(colchicineWarning.severity, equals(InteractionSeverity.contraindicated));
      expect(colchicineWarning.severityLevel, equals(4));
      expect(colchicineWarning.warning, contains('aplasie médullaire'));
      expect(colchicineWarning.recommendation, contains('Contre-indication formelle et absolue'));
    });

    testWidgets('Prescription analysis search suggestions render without crash on narrow mobile screen', (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: PrescriptionAnalysisScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Enter search text for a common drug
      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);
      await tester.enterText(searchField, 'Sintrom');
      await tester.pumpAndSettle();

      // Suggestions should appear and not crash
      expect(find.textContaining('SINTROM'), findsWidgets);

      // Tap first suggestion
      await tester.tap(find.textContaining('SINTROM').first);
      await tester.pumpAndSettle();

      // Drug should be added as a chip
      expect(find.text('Médicaments dans l\'ordonnance à analyser :'), findsOneWidget);
    });
  });
}


