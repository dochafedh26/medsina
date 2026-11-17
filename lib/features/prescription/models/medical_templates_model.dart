import 'package:equatable/equatable.dart';

class PrescriptionLineItem extends Equatable {
  final String dciName;
  final String commercialNameDz;
  final String formulation;
  final String adultDosage;
  final String? pediatricMgPerKgPerDay; // null si adulte uniquement
  final double? maxPediatricDailyMg;
  final String duration;
  final String? clinicalNote;

  const PrescriptionLineItem({
    required this.dciName,
    required this.commercialNameDz,
    required this.formulation,
    required this.adultDosage,
    this.pediatricMgPerKgPerDay,
    this.maxPediatricDailyMg,
    required this.duration,
    this.clinicalNote,
  });

  String formatForPatient({bool isPediatric = false, double weightKg = 20.0}) {
    if (isPediatric && pediatricMgPerKgPerDay != null) {
      final mgPerKg = double.tryParse(pediatricMgPerKgPerDay!) ?? 0.0;
      if (mgPerKg > 0) {
        double totalDailyMg = mgPerKg * weightKg;
        if (maxPediatricDailyMg != null && totalDailyMg > maxPediatricDailyMg!) {
          totalDailyMg = maxPediatricDailyMg!;
        }
        return '$dciName ($commercialNameDz) — $formulation\n'
            '  ➔ Posologie Pédiatrique (${weightKg.toStringAsFixed(0)} kg) : '
            '${totalDailyMg.toStringAsFixed(0)} mg/jour ($mgPerKg mg/kg/j) pendant $duration'
            '${clinicalNote != null ? '\n  ⚠ $clinicalNote' : ''}';
      }
    }
    return '$dciName ($commercialNameDz) — $formulation\n'
        '  ➔ $adultDosage pendant $duration'
        '${clinicalNote != null ? '\n  ℹ $clinicalNote' : ''}';
  }

  @override
  List<Object?> get props => [dciName, commercialNameDz, adultDosage, duration];
}

class PrescriptionTemplate extends Equatable {
  final String id;
  final String title;
  final String specialty;
  final String clinicalContext;
  final bool supportsPediatricWeight;
  final List<PrescriptionLineItem> lines;
  final List<String> patientAdvice;
  final List<String> contraindicationsAlert;

  const PrescriptionTemplate({
    required this.id,
    required this.title,
    required this.specialty,
    required this.clinicalContext,
    this.supportsPediatricWeight = false,
    required this.lines,
    this.patientAdvice = const [],
    this.contraindicationsAlert = const [],
  });

  @override
  List<Object?> get props => [id, title, specialty];
}

class MedicoLegalCertificateTemplate extends Equatable {
  final String id;
  final String title;
  final String legalCategory;
  final String legalReferenceDz;
  final String bodyTemplate;
  final bool includesIttDays;
  final List<String> medicoLegalReminders;

  const MedicoLegalCertificateTemplate({
    required this.id,
    required this.title,
    required this.legalCategory,
    required this.legalReferenceDz,
    required this.bodyTemplate,
    this.includesIttDays = false,
    this.medicoLegalReminders = const [],
  });

  String renderBody({
    required String doctorName,
    required String establishment,
    required String patientName,
    required String patientAge,
    required String findingsOrReason,
    int ittDays = 5,
    String city = 'Blida',
  }) {
    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    return bodyTemplate
        .replaceAll('{{DOCTOR}}', doctorName.isEmpty ? 'Dr. ........................' : doctorName)
        .replaceAll('{{ESTABLISHMENT}}', establishment.isEmpty ? 'CHU / EPSP ........................' : establishment)
        .replaceAll('{{PATIENT}}', patientName.isEmpty ? 'M. / Mme ........................' : patientName)
        .replaceAll('{{AGE}}', patientAge.isEmpty ? '.... ans' : '$patientAge ans')
        .replaceAll('{{FINDINGS}}', findingsOrReason.isEmpty ? '................................................' : findingsOrReason)
        .replaceAll('{{ITT_DAYS}}', '$ittDays')
        .replaceAll('{{CITY}}', city)
        .replaceAll('{{DATE}}', dateStr);
  }

  @override
  List<Object?> get props => [id, title, legalCategory];
}

class MedicalTemplatesCatalog {
  static const List<PrescriptionTemplate> prescriptions = [
    PrescriptionTemplate(
      id: 'ordo_angine_strepto',
      title: 'Angine Aiguë Érythémato-Pultacée',
      specialty: 'ORL / Infectiologie',
      clinicalContext: 'Suspicion streptococcique (Score de MacIsaac ≥ 2)',
      supportsPediatricWeight: true,
      lines: [
        PrescriptionLineItem(
          dciName: 'Amoxicilline',
          commercialNameDz: 'Clamoxyl® / Amoxil® / Hiconcil®',
          formulation: 'Gélules 1 g (Adulte) / Susp. buv. 250 ou 500 mg/5 ml (Enfant)',
          adultDosage: '1 g x 2/jour (matin et soir)',
          pediatricMgPerKgPerDay: '50',
          maxPediatricDailyMg: 2000,
          duration: '6 jours',
          clinicalNote: 'Si allergie bêta-lactamines : Azithromycine (Zithromax® 500 mg/j pendant 3j).',
        ),
        PrescriptionLineItem(
          dciName: 'Paracétamol',
          commercialNameDz: 'Doliprane® / Panadol® / Paralgan®',
          formulation: 'Comprimés 1 g / Sirop pédiatrique',
          adultDosage: '1 g toutes les 6 à 8h si fièvre ou odynophagie (max 4 g/j)',
          pediatricMgPerKgPerDay: '60',
          maxPediatricDailyMg: 3000,
          duration: '3 à 5 jours',
        ),
      ],
      patientAdvice: [
        'Hydratation abondante et alimentation tiède/molle.',
        'Éviter les AINS (risque de cellulite cervicale / phlegmon amygdalien).',
      ],
      contraindicationsAlert: [
        'Vérifier absence d\'allergie aux Pénicillines avant prescription.',
      ],
    ),
    PrescriptionTemplate(
      id: 'ordo_pac_ambulatoire',
      title: 'Pneumonie Aiguë Communautaire (PAC) — Adulte Sain',
      specialty: 'Pneumologie',
      clinicalContext: 'CURB-65 = 0 ou 1 (prise en charge ambulatoire)',
      lines: [
        PrescriptionLineItem(
          dciName: 'Amoxicilline + Acide Clavulanique (ou Amoxicilline seule)',
          commercialNameDz: 'Augmentin® / Bioclavid® / Amoclan®',
          formulation: 'Sachets ou Comprimés 1 g / 125 mg',
          adultDosage: '1 sachet x 3/jour (toutes les 8h)',
          duration: '7 jours',
          clinicalNote: 'Réévaluation clinique IMPÉRATIVE à 48-72h (défervescence thermique).',
        ),
        PrescriptionLineItem(
          dciName: 'Paracétamol',
          commercialNameDz: 'Doliprane® 1000 mg',
          formulation: 'Comprimés 1 g',
          adultDosage: '1 cp x 3/jour si fièvre > 38,5°C',
          duration: '5 jours',
        ),
      ],
      patientAdvice: [
        'Consulter en urgence si dyspnée d\'aggravation, douleur thoracique ou fièvre persistante après 72h.',
      ],
      contraindicationsAlert: [
        'Si sujet âgé ou comorbidités : réévaluer le score CURB-65.',
      ],
    ),
    PrescriptionTemplate(
      id: 'ordo_cystite_simple',
      title: 'Cystite Aiguë Simple de la Femme',
      specialty: 'Urologie / Infectiologie',
      clinicalContext: 'Femme jeune sans facteur de risque de complication',
      lines: [
        PrescriptionLineItem(
          dciName: 'Fosfomycine-Trométamol',
          commercialNameDz: 'Monuril® / Fosfomicina®',
          formulation: 'Sachet-dose 3 g',
          adultDosage: '1 sachet en prise UNIQUE à jeun (ou 2h après repas, vessie vide au coucher)',
          duration: '1 jour (dose unique)',
        ),
      ],
      patientAdvice: [
        'Boire 1,5 à 2 L d\'eau/jour, mictions fréquentes non retenues.',
        'Reconsulter si fièvre ou douleur lombaire (suspicion pyélonéphrite).',
      ],
      contraindicationsAlert: [
        'ECBU non indiqué en première intention dans la cystite simple.',
      ],
    ),
    PrescriptionTemplate(
      id: 'ordo_pyelonephrite_simple',
      title: 'Pyélonéphrite Aiguë Simple (PNA)',
      specialty: 'Infectiologie / Urgences',
      clinicalContext: 'Sans signe de gravité ni grossesse (après ECBU réalisé)',
      lines: [
        PrescriptionLineItem(
          dciName: 'Ciprofloxacine (ou Ceftriaxone IV/IM si prise récente FQ)',
          commercialNameDz: 'Ciflox® / Ciprolon® / Rocephine®',
          formulation: 'Comprimés 500 mg',
          adultDosage: '500 mg x 2/jour (matin et soir)',
          duration: '7 jours',
          clinicalNote: 'Adapter selon l\'antibiogramme de l\'ECBU à 48h.',
        ),
        PrescriptionLineItem(
          dciName: 'Paracétamol',
          commercialNameDz: 'Doliprane® 1 g',
          formulation: 'Comprimés 1 g',
          adultDosage: '1 cp toutes les 8h si fièvre ou lombalgies',
          duration: '5 jours',
        ),
      ],
      patientAdvice: [
        'Échographie rénale dans les 24h si hyperalgique ou doute sur obstacle.',
      ],
      contraindicationsAlert: [
        'Fluoroquinolones contre-indiquées chez la femme enceinte (préférer Ceftriaxone).',
      ],
    ),
    PrescriptionTemplate(
      id: 'ordo_asthme_sortie',
      title: 'Crise d\'Asthme — Ordonnance de Sortie des Urgences',
      specialty: 'Pneumologie / Urgences',
      clinicalContext: 'Après nébulisations aux urgences et amélioration du DEP > 70%',
      supportsPediatricWeight: true,
      lines: [
        PrescriptionLineItem(
          dciName: 'Salbutamol (SABA)',
          commercialNameDz: 'Ventoline® / Asthalin®',
          formulation: 'Aérosol-doseur 100 µg/bouffée (+ Chambre d\'inhalation si enfant)',
          adultDosage: '2 bouffées à la demande si dyspnée/sifflements (jusqu\'à 4x/j)',
          duration: '15 jours',
        ),
        PrescriptionLineItem(
          dciName: 'Prednisone / Prednisolone',
          commercialNameDz: 'Cortancyl® / Solupred® / Precortyl®',
          formulation: 'Comprimés 20 mg ou 5 mg',
          adultDosage: '40 à 50 mg/jour en 1 prise unique le matin au petit-déjeuner',
          pediatricMgPerKgPerDay: '1',
          maxPediatricDailyMg: 40,
          duration: '5 jours (sans décroissance)',
        ),
        PrescriptionLineItem(
          dciName: 'Budésonide + Formotérol (ou Béclométasone)',
          commercialNameDz: 'Symbicort® / Clenil® / Pulmicort®',
          formulation: 'Inhalateur de fond',
          adultDosage: '1 à 2 inhalations matin et soir (selon palier GINA)',
          duration: '1 mois (à réévaluer en consultation pneumo)',
        ),
      ],
      patientAdvice: [
        'Se rincer la bouche après chaque prise de corticoïde inhalé.',
        'Consultation de suivi médical dans les 48-72h.',
      ],
    ),
    PrescriptionTemplate(
      id: 'ordo_hta_initiation',
      title: 'HTA Essentielle — Initiation Thérapeutique',
      specialty: 'Cardiologie',
      clinicalContext: 'HTA confirmée (PAS ≥ 140 et/ou PAD ≥ 90 mmHg au repos / MAPA)',
      lines: [
        PrescriptionLineItem(
          dciName: 'Amlodipine + Périndopril (ou Valsartan)',
          commercialNameDz: 'Coveram® / Exforge® / Amlor® + Coversyl®',
          formulation: 'Comprimés 5 mg / 5 mg (ou 5/80 mg)',
          adultDosage: '1 comprimé le matin',
          duration: '1 mois (renouvelable 3 mois)',
        ),
      ],
      patientAdvice: [
        'Régime hyposodé (< 5 g sel/j), activité physique régulière 30 min/j, arrêt du tabac.',
        'Automesure tensionnelle (règle des 3) avant la consultation de contrôle à 4 semaines.',
      ],
      contraindicationsAlert: [
        'IEC/ARA2 strictement contre-indiqués pendant la grossesse et si sténose bilatérale des artères rénales.',
      ],
    ),
    PrescriptionTemplate(
      id: 'ordo_gea_sro',
      title: 'Gastro-Entérite Aiguë & Prévention Déshydratation',
      specialty: 'Gastro-Entérologie / Pédiatrie',
      clinicalContext: 'Diarrhée aiguë sans signe de sepsis ni déshydratation sévère',
      supportsPediatricWeight: true,
      lines: [
        PrescriptionLineItem(
          dciName: 'Sels de Réhydratation Orale (SRO)',
          commercialNameDz: 'SRO Saidal® / Adiaril®',
          formulation: 'Sachets à diluer dans 200 ml (ou 1L selon sachet) d\'eau faiblement minéralisée',
          adultDosage: 'À volonté par petites gorgées fréquentes après chaque selle liquide',
          duration: '3 à 5 jours',
        ),
        PrescriptionLineItem(
          dciName: 'Diosmectite ou Racécadotril',
          commercialNameDz: 'Smecta® / Tiorfan®',
          formulation: 'Sachets pour suspension buvable',
          adultDosage: '1 sachet x 3/jour (Smecta à distance de 2h des autres médicaments)',
          duration: '3 à 5 jours',
        ),
        PrescriptionLineItem(
          dciName: 'Phloroglucinol (si douleurs spasmodiques)',
          commercialNameDz: 'Spasfon®',
          formulation: 'Comprimés orodispersibles 80 mg',
          adultDosage: '2 lyocs en cas de crampes abdominales (max 6/j)',
          duration: '3 jours',
        ),
      ],
    ),
  ];

  static const List<MedicoLegalCertificateTemplate> certificates = [
    MedicoLegalCertificateTemplate(
      id: 'cert_cbv_itt',
      title: 'Certificat Médical Descriptif Initial (CBV & ITT)',
      legalCategory: 'Médico-Légal / Urgences',
      legalReferenceDz: 'Code Pénal Algérien (Art. 264, 266, 442 — Seuil délictuel > 15 jours)',
      includesIttDays: true,
      bodyTemplate: '''Je soussigné(e), Docteur {{DOCTOR}}, exerçant à {{ESTABLISHMENT}}, certifie avoir examiné ce jour ({{DATE}}) le/la nommé(e) {{PATIENT}}, âgé(e) de {{AGE}}, qui déclare avoir été victime de coups et blessures volontaires.

L'examen clinique initial objective les lésions suivantes :
{{FINDINGS}}

Ces lésions entraînent une Incapacité Totale de Travail (ITT) provisoire estimée à {{ITT_DAYS}} jours, sous réserve de complications ultérieures ou d'examens complémentaires en cours.

Certificat établi à la demande de l'intéressé(e) et remis en mains propres pour servir et valoir ce que de droit.

Fait à {{CITY}}, le {{DATE}}.''',
      medicoLegalReminders: [
        'Toujours utiliser la formule « déclare avoir été victime... » (ne jamais affirmer l\'agression ni nommer un tiers).',
        'Décrire objectivement chaque lésion : nature, dimensions (cm), siège anatomique exact et côté (droit/gauche).',
        'Rappel Code Pénal DZ : ITT ≤ 15 jours (contravention) vs ITT > 15 jours (délit).',
      ],
    ),
    MedicoLegalCertificateTemplate(
      id: 'cert_arret_travail',
      title: 'Certificat d\'Arrêt de Travail / Repos Médical',
      legalCategory: 'Médecine Générale / CNAS',
      legalReferenceDz: 'Législation Sécurité Sociale (CNAS / CASNOS)',
      includesIttDays: true,
      bodyTemplate: '''Je soussigné(e), Docteur {{DOCTOR}}, exerçant à {{ESTABLISHMENT}}, certifie que l'état de santé de {{PATIENT}}, âgé(e) de {{AGE}}, nécessite un arrêt de travail / repos médical avec dispense d'activité professionnelle d'une durée de {{ITT_DAYS}} jours à compter du {{DATE}}.

Observations / Précisions (sans violation du secret médical) :
{{FINDINGS}}

Certificat délivré à l'intéressé(e) pour faire valoir ce que de droit.

Fait à {{CITY}}, le {{DATE}}.''',
      medicoLegalReminders: [
        'Ne jamais mentionner le diagnostic médical sur un arrêt de travail destiné à l\'employeur (secret médical).',
      ],
    ),
    MedicoLegalCertificateTemplate(
      id: 'cert_bonne_sante',
      title: 'Certificat Médical de Bonne Santé & Aptitude',
      legalCategory: 'Administratif / Aptitude',
      legalReferenceDz: 'Usage administratif, concours, recrutement ou sport',
      bodyTemplate: '''Je soussigné(e), Docteur {{DOCTOR}}, exerçant à {{ESTABLISHMENT}}, certifie avoir examiné ce jour ({{DATE}}) {{PATIENT}}, âgé(e) de {{AGE}}.

L'examen clinique complet (cardiovasculaire, respiratoire, neurologique et locomoteur) ne révèle ce jour aucun signe clinique d'affection aiguë ou chronique évolutive contre-indiquant l'exercice d'une activité normale ou sportive.

Complément : {{FINDINGS}}

Certificat établi pour servir et valoir ce que de droit.

Fait à {{CITY}}, le {{DATE}}.''',
      medicoLegalReminders: [
        'Exiger une pièce d\'identité officielle et pratiquer un examen clinique réel (auscultation + TA).',
      ],
    ),
    MedicoLegalCertificateTemplate(
      id: 'cert_phtisiologie',
      title: 'Certificat de Phtisiologie (Non-Contagion)',
      legalCategory: 'Santé Publique / Dossier Administratif',
      legalReferenceDz: 'Réglementation sanitaire algérienne (recrutement / université)',
      bodyTemplate: '''Je soussigné(e), Docteur {{DOCTOR}}, exerçant à {{ESTABLISHMENT}}, certifie avoir examiné ce jour ({{DATE}}) {{PATIENT}}, âgé(e) de {{AGE}}, et consulté sa radiographie thoracique de face.

L'intéressé(e) est cliniquement et radiologiquement indemne de toute affection tuberculeuse pulmonaire active ou contagieuse.

Observations : {{FINDINGS}}

Fait à {{CITY}}, le {{DATE}}.''',
      medicoLegalReminders: [
        'Vérifier systématiquement la radiographie thoracique récente avant signature.',
      ],
    ),
  ];
}
