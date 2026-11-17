import 'package:equatable/equatable.dart';

enum SpecialtyAccessibilityStatus {
  accessible,
  competitive,
  toConsolidate,
}

class ResidencySpecialtyCutoff extends Equatable {
  final String id;
  final String specialtyName;
  final String category; // 'Médicale', 'Chirurgicale', 'Biologique'
  final double minScoreBlida;
  final double minScoreAlger;
  final double minScoreOran;
  final double minScoreConstantine;
  final int typicalClosingRank;

  const ResidencySpecialtyCutoff({
    required this.id,
    required this.specialtyName,
    required this.category,
    required this.minScoreBlida,
    required this.minScoreAlger,
    required this.minScoreOran,
    required this.minScoreConstantine,
    required this.typicalClosingRank,
  });

  double thresholdForFaculty(String faculty) {
    final f = faculty.toLowerCase();
    if (f.contains('alger')) return minScoreAlger;
    if (f.contains('oran')) return minScoreOran;
    if (f.contains('constantine')) return minScoreConstantine;
    return minScoreBlida;
  }

  SpecialtyAccessibilityStatus evaluateStatus(double userScoreOutOf20, String faculty) {
    final threshold = thresholdForFaculty(faculty);
    if (userScoreOutOf20 >= threshold + 0.5) {
      return SpecialtyAccessibilityStatus.accessible;
    } else if (userScoreOutOf20 >= threshold - 0.6) {
      return SpecialtyAccessibilityStatus.competitive;
    }
    return SpecialtyAccessibilityStatus.toConsolidate;
  }

  @override
  List<Object?> get props => [id, specialtyName, category];
}

class ResidencyRankSimulatorData {
  static const List<String> faculties = [
    'Blida',
    'Alger',
    'Oran',
    'Constantine',
    'Annaba / Sétif / Tlemcen',
  ];

  static const List<ResidencySpecialtyCutoff> specialties = [
    ResidencySpecialtyCutoff(
      id: 'spec_ophtalmo',
      specialtyName: 'Ophtalmologie',
      category: 'Chirurgicale',
      minScoreBlida: 15.80,
      minScoreAlger: 16.40,
      minScoreOran: 15.90,
      minScoreConstantine: 15.70,
      typicalClosingRank: 35,
    ),
    ResidencySpecialtyCutoff(
      id: 'spec_dermato',
      specialtyName: 'Dermatologie',
      category: 'Médicale',
      minScoreBlida: 15.40,
      minScoreAlger: 16.10,
      minScoreOran: 15.50,
      minScoreConstantine: 15.30,
      typicalClosingRank: 55,
    ),
    ResidencySpecialtyCutoff(
      id: 'spec_cardio',
      specialtyName: 'Cardiologie',
      category: 'Médicale',
      minScoreBlida: 14.90,
      minScoreAlger: 15.60,
      minScoreOran: 15.10,
      minScoreConstantine: 14.80,
      typicalClosingRank: 95,
    ),
    ResidencySpecialtyCutoff(
      id: 'spec_radio',
      specialtyName: 'Radiologie & Imagerie Médicale',
      category: 'Médicale',
      minScoreBlida: 14.60,
      minScoreAlger: 15.30,
      minScoreOran: 14.70,
      minScoreConstantine: 14.50,
      typicalClosingRank: 120,
    ),
    ResidencySpecialtyCutoff(
      id: 'spec_orl',
      specialtyName: 'ORL & Chirurgie Cervico-Faciale',
      category: 'Chirurgicale',
      minScoreBlida: 14.20,
      minScoreAlger: 14.90,
      minScoreOran: 14.30,
      minScoreConstantine: 14.10,
      typicalClosingRank: 160,
    ),
    ResidencySpecialtyCutoff(
      id: 'spec_gyneco',
      specialtyName: 'Gynécologie-Obstétrique',
      category: 'Chirurgicale',
      minScoreBlida: 13.80,
      minScoreAlger: 14.50,
      minScoreOran: 14.00,
      minScoreConstantine: 13.70,
      typicalClosingRank: 210,
    ),
    ResidencySpecialtyCutoff(
      id: 'spec_pediatrie',
      specialtyName: 'Pédiatrie',
      category: 'Médicale',
      minScoreBlida: 13.60,
      minScoreAlger: 14.30,
      minScoreOran: 13.80,
      minScoreConstantine: 13.50,
      typicalClosingRank: 240,
    ),
    ResidencySpecialtyCutoff(
      id: 'spec_gastro',
      specialtyName: 'Hépato-Gastro-Entérologie',
      category: 'Médicale',
      minScoreBlida: 13.90,
      minScoreAlger: 14.60,
      minScoreOran: 14.00,
      minScoreConstantine: 13.80,
      typicalClosingRank: 195,
    ),
    ResidencySpecialtyCutoff(
      id: 'spec_neuro',
      specialtyName: 'Neurologie',
      category: 'Médicale',
      minScoreBlida: 13.40,
      minScoreAlger: 14.00,
      minScoreOran: 13.50,
      minScoreConstantine: 13.30,
      typicalClosingRank: 270,
    ),
    ResidencySpecialtyCutoff(
      id: 'spec_endo',
      specialtyName: 'Endocrinologie & Diabétologie',
      category: 'Médicale',
      minScoreBlida: 13.50,
      minScoreAlger: 14.20,
      minScoreOran: 13.60,
      minScoreConstantine: 13.40,
      typicalClosingRank: 260,
    ),
    ResidencySpecialtyCutoff(
      id: 'spec_rea',
      specialtyName: 'Anesthésie-Réanimation',
      category: 'Médicale',
      minScoreBlida: 12.60,
      minScoreAlger: 13.30,
      minScoreOran: 12.80,
      minScoreConstantine: 12.50,
      typicalClosingRank: 390,
    ),
    ResidencySpecialtyCutoff(
      id: 'spec_chir_gen',
      specialtyName: 'Chirurgie Générale',
      category: 'Chirurgicale',
      minScoreBlida: 12.50,
      minScoreAlger: 13.20,
      minScoreOran: 12.70,
      minScoreConstantine: 12.40,
      typicalClosingRank: 420,
    ),
    ResidencySpecialtyCutoff(
      id: 'spec_ortho',
      specialtyName: 'Orthopédie & Traumatologie',
      category: 'Chirurgicale',
      minScoreBlida: 12.90,
      minScoreAlger: 13.60,
      minScoreOran: 13.10,
      minScoreConstantine: 12.80,
      typicalClosingRank: 340,
    ),
    ResidencySpecialtyCutoff(
      id: 'spec_med_int',
      specialtyName: 'Médecine Interne',
      category: 'Médicale',
      minScoreBlida: 12.40,
      minScoreAlger: 13.10,
      minScoreOran: 12.60,
      minScoreConstantine: 12.30,
      typicalClosingRank: 450,
    ),
    ResidencySpecialtyCutoff(
      id: 'spec_pneumo',
      specialtyName: 'Pneumo-Phtisiologie',
      category: 'Médicale',
      minScoreBlida: 12.10,
      minScoreAlger: 12.80,
      minScoreOran: 12.20,
      minScoreConstantine: 12.00,
      typicalClosingRank: 510,
    ),
    ResidencySpecialtyCutoff(
      id: 'spec_microbio',
      specialtyName: 'Microbiologie / Biochimie Médicale',
      category: 'Biologique',
      minScoreBlida: 11.80,
      minScoreAlger: 12.50,
      minScoreOran: 11.90,
      minScoreConstantine: 11.70,
      typicalClosingRank: 560,
    ),
  ];

  /// Calcule la moyenne pondérée du concours (Fondamentale 1/3, Clinique Médicale 1/3, Chirurgicale 1/3)
  static double computeWeightedAverage({
    required double sciencesFondamentales,
    required double pathologieMedicale,
    required double pathologieChirurgicale,
  }) {
    return (sciencesFondamentales + pathologieMedicale + pathologieChirurgicale) / 3.0;
  }

  /// Estime le rang indicatif sur ~2 000 candidats selon la note sur 20
  static int estimateRank(double scoreOutOf20) {
    if (scoreOutOf20 >= 17.5) return 5;
    if (scoreOutOf20 >= 16.0) return (10 + (17.5 - scoreOutOf20) * 28).round();
    if (scoreOutOf20 >= 14.0) return (52 + (16.0 - scoreOutOf20) * 95).round();
    if (scoreOutOf20 >= 12.0) return (242 + (14.0 - scoreOutOf20) * 180).round();
    if (scoreOutOf20 >= 10.0) return (602 + (12.0 - scoreOutOf20) * 260).round();
    return 1250;
  }
}
