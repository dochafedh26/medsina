import 'package:equatable/equatable.dart';

class LabValue extends Equatable {
  final String id;
  final String name;
  final String category;
  final String normalRange;
  final String unit;
  final String highInterpretation;
  final String lowInterpretation;
  final List<String> clinicalNotes;

  const LabValue({
    required this.id,
    required this.name,
    required this.category,
    required this.normalRange,
    required this.unit,
    required this.highInterpretation,
    required this.lowInterpretation,
    this.clinicalNotes = const [],
  });

  @override
  List<Object?> get props => [
        id,
        name,
        category,
        normalRange,
        unit,
        highInterpretation,
        lowInterpretation,
        clinicalNotes,
      ];
}

class PracticalToolsRepository {
  static List<LabValue> getLabValues() {
    return [
      const LabValue(
        id: 'lab_potassium',
        name: 'Potassium sérique (Kaliémie)',
        category: 'Ionogramme & Rein',
        normalRange: '3.5 - 5.0',
        unit: 'mmol/L',
        highInterpretation: 'Hyperkaliémie : Urgence si > 6.0 mmol/L ou signes ECG (ondes T pointues et symétriques, élargissement QRS). Risque d\'arrêt en asystolie. Causes : insuffisance rénale, acidose, rhabdomyolyse, médicaments (IEC, ARA2, spironolactone).',
        lowInterpretation: 'Hypokaliémie : Urgence si < 3.0 mmol/L. Risque de troubles du rythme ventriculaire (torsades de pointes, fibrillation). Signes ECG : onde U, aplatissement T, sous-décalage ST. Causes : pertes digestives (vomissements, diarrhée), diurétiques de l\'anse, hyperaldostéronisme.',
        clinicalNotes: [
          'Attention à la fausse hyperkaliémie par hémolyse lors du prélèvement (garrot trop serré).',
          'Toute dyskaliémie justifie un ECG 12 dérivations immédiat.',
        ],
      ),
      const LabValue(
        id: 'lab_sodium',
        name: 'Sodium sérique (Natrémie)',
        category: 'Ionogramme & Rein',
        normalRange: '135 - 145',
        unit: 'mmol/L',
        highInterpretation: 'Hypernatrémie (> 145 mmol/L) : Traduit toujours un déficit hydrique intracellulaire. Soif intense, sécheresse des muqueuses, fièvre, troubles de conscience. Corriger prudemment (< 10-12 mmol/L par 24h) pour éviter l\'œdème cérébral.',
        lowInterpretation: 'Hyponatrémie (< 135 mmol/L) : Hyperhydratation intracellulaire. Céphalées, nausées, dégoût de l\'eau, risque de convulsions et coma si < 120 mmol/L. Risque majeur de myélinolyse centropontine si correction trop rapide.',
        clinicalNotes: [
          'Calculer la glycémie pour corriger la natrémie : Na corrigé = Na mesuré + 1.6 * (Glycémie g/L - 1).',
        ],
      ),
      const LabValue(
        id: 'lab_creatinine',
        name: 'Créatinine sérique',
        category: 'Ionogramme & Rein',
        normalRange: 'Homme : 60 - 110 | Femme : 45 - 90',
        unit: 'µmol/L',
        highInterpretation: 'Insuffisance rénale aiguë ou chronique. Toujours comparer à la valeur antérieure. Calculer impérativement le Débit de Filtration Glomérulaire (DFG) par CKD-EPI.',
        lowInterpretation: 'Dénutrition sévère, amyotrophie majeure, grossesse.',
        clinicalNotes: [
          'L\'élévation aiguë de 26 µmol/L en 48h définit une insuffisance rénale aiguë (critères KDIGO).',
        ],
      ),
      const LabValue(
        id: 'lab_hemoglobine',
        name: 'Hémoglobine (NFS)',
        category: 'Hématologie',
        normalRange: 'Homme : 13 - 17 | Femme : 12 - 15.5 | Grossesse : > 10.5',
        unit: 'g/dL',
        highInterpretation: 'Polyglobulie (Primitive : Maladie de Vaquez ; Secondaire : Hypoxie chronique BPCO, cardiopathie cyanogène, tabagisme).',
        lowInterpretation: 'Anémie. Classifier selon le VGM (Microcytaire < 80 fl : carence martiale, thalassémie ; Normo/Macrocytaire : régénérative ou arégénérative).',
        clinicalNotes: [
          'Seuil transfusionnel standard chez le coronarien : Hb < 10 g/dL ; chez le sujet jeune sans comorbidité : Hb < 7 g/dL.',
        ],
      ),
      const LabValue(
        id: 'lab_plaquettes',
        name: 'Numération plaquettaire',
        category: 'Hématologie',
        normalRange: '150 000 - 400 000',
        unit: '/mm³',
        highInterpretation: 'Thrombocytose (> 450 000) : Réactionnelle (infection, inflammation, carence en fer, splénectomie) ou Syndrome myéloprolifératif (Thrombocytémie essentielle).',
        lowInterpretation: 'Thrombopénie (< 150 000) : Risque hémorragique spontané si < 20 000/mm³. Éliminer un artefact à l\'EDTA (faire tube citraté). Causes : CIVD, MAT/PTT, PTI, sepsis, héparine (TIH).',
        clinicalNotes: [
          'Rechercher impérativement un purpura pétéchial ou des bulles hémorragiques buccales si < 50 000/mm³.',
        ],
      ),
      const LabValue(
        id: 'lab_crp',
        name: 'Protéine C-Réactive (CRP)',
        category: 'Inflammation & Infectiologie',
        normalRange: '< 5',
        unit: 'mg/L',
        highInterpretation: 'Syndrome inflammatoire biologique aigu. Infection bactérienne (> 50-100 mg/L), sepsis sévère, maladie auto-immune active, nécrose tissulaire (infarctus).',
        lowInterpretation: 'Absence d\'inflammation systémique significative.',
        clinicalNotes: [
          'La CRP cinétique : commence à s\'élever 6 à 12h après le stimulus, pic à 48h, demi-vie courte (très bon marqueur d\'efficacité thérapeutique).',
        ],
      ),
    ];
  }
}
