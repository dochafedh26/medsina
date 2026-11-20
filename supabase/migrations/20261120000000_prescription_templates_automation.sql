-- =============================================================================
-- MEDSINA PLATFORM : PRESCRIPTION TEMPLATES (ORDONNANCES TYPES DCI/CNAS)
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.prescription_templates (
  id text PRIMARY KEY,
  title text NOT NULL,
  specialty text NOT NULL,
  clinical_context text NOT NULL DEFAULT '',
  supports_pediatric_weight boolean NOT NULL DEFAULT false,
  lines jsonb NOT NULL DEFAULT '[]'::jsonb,
  patient_advice jsonb NOT NULL DEFAULT '[]'::jsonb,
  contraindications_alert jsonb NOT NULL DEFAULT '[]'::jsonb,
  scientific_references text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_prescription_templates_active_created
  ON public.prescription_templates (created_at DESC)
  WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_prescription_templates_active_specialty
  ON public.prescription_templates (specialty)
  WHERE is_active = true;

ALTER TABLE public.prescription_templates ENABLE ROW LEVEL SECURITY;

GRANT SELECT ON public.prescription_templates TO anon, authenticated;
GRANT ALL ON public.prescription_templates TO service_role;

DROP POLICY IF EXISTS "Public read active prescription_templates" ON public.prescription_templates;
CREATE POLICY "Public read active prescription_templates"
  ON public.prescription_templates
  FOR SELECT
  TO anon, authenticated
  USING (is_active = true);

-- Seed the 7 built-in Ordonnances Types
INSERT INTO public.prescription_templates (
  id,
  title,
  specialty,
  clinical_context,
  supports_pediatric_weight,
  lines,
  patient_advice,
  contraindications_alert,
  scientific_references,
  is_active
)
VALUES
  (
    'ordo_angine_strepto',
    'Angine Aiguë Érythémato-Pultacée',
    'ORL / Infectiologie',
    'Suspicion streptococcique (Score de MacIsaac ≥ 2)',
    true,
    '[
      {
        "dci_name": "Amoxicilline",
        "commercial_name_dz": "Clamoxyl® / Amoxil® / Hiconcil®",
        "formulation": "Gélules 1 g (Adulte) / Susp. buv. 250 ou 500 mg/5 ml (Enfant)",
        "adult_dosage": "1 g x 2/jour (matin et soir)",
        "pediatric_mg_per_kg_per_day": "50",
        "max_pediatric_daily_mg": 2000,
        "duration": "6 jours",
        "clinical_note": "Si allergie bêta-lactamines : Azithromycine (Zithromax® 500 mg/j pendant 3j)."
      },
      {
        "dci_name": "Paracétamol",
        "commercial_name_dz": "Doliprane® / Panadol® / Paralgan®",
        "formulation": "Comprimés 1 g / Sirop pédiatrique",
        "adult_dosage": "1 g toutes les 6 à 8h si fièvre ou odynophagie (max 4 g/j)",
        "pediatric_mg_per_kg_per_day": "60",
        "max_pediatric_daily_mg": 3000,
        "duration": "3 à 5 jours",
        "clinical_note": null
      }
    ]'::jsonb,
    '[
      "Hydratation abondante et alimentation tiède/molle.",
      "Éviter les AINS (risque de cellulite cervicale / phlegmon amygdalien)."
    ]'::jsonb,
    '[
      "Vérifier absence d''allergie aux Pénicillines avant prescription."
    ]'::jsonb,
    'SPILF / HAS / Consensus Algérien d''Infectiologie ORL',
    true
  ),
  (
    'ordo_pac_ambulatoire',
    'Pneumonie Aiguë Communautaire (PAC) — Adulte Sain',
    'Pneumologie',
    'CURB-65 = 0 ou 1 (prise en charge ambulatoire)',
    false,
    '[
      {
        "dci_name": "Amoxicilline + Acide Clavulanique (ou Amoxicilline seule)",
        "commercial_name_dz": "Augmentin® / Bioclavid® / Amoclan®",
        "formulation": "Sachets ou Comprimés 1 g / 125 mg",
        "adult_dosage": "1 sachet x 3/jour (toutes les 8h)",
        "pediatric_mg_per_kg_per_day": null,
        "max_pediatric_daily_mg": null,
        "duration": "7 jours",
        "clinical_note": "Réévaluation clinique IMPÉRATIVE à 48-72h (défervescence thermique)."
      },
      {
        "dci_name": "Paracétamol",
        "commercial_name_dz": "Doliprane® 1000 mg",
        "formulation": "Comprimés 1 g",
        "adult_dosage": "1 cp x 3/jour si fièvre > 38,5°C",
        "pediatric_mg_per_kg_per_day": null,
        "max_pediatric_daily_mg": null,
        "duration": "5 jours",
        "clinical_note": null
      }
    ]'::jsonb,
    '[
      "Consulter en urgence si dyspnée d''aggravation, douleur thoracique ou fièvre persistante après 72h."
    ]'::jsonb,
    '[
      "Si sujet âgé ou comorbidités : réévaluer le score CURB-65."
    ]'::jsonb,
    'SPILF / SPLF / Recommandations Algériennes de Pneumologie',
    true
  ),
  (
    'ordo_cystite_simple',
    'Cystite Aiguë Simple de la Femme',
    'Urologie / Infectiologie',
    'Femme jeune sans facteur de risque de complication',
    false,
    '[
      {
        "dci_name": "Fosfomycine-Trométamol",
        "commercial_name_dz": "Monuril® / Fosfomicina®",
        "formulation": "Sachet-dose 3 g",
        "adult_dosage": "1 sachet en prise UNIQUE à jeun (ou 2h après repas, vessie vide au coucher)",
        "pediatric_mg_per_kg_per_day": null,
        "max_pediatric_daily_mg": null,
        "duration": "1 jour (dose unique)",
        "clinical_note": null
      }
    ]'::jsonb,
    '[
      "Boire 1,5 à 2 L d''eau/jour, mictions fréquentes non retenues.",
      "Reconsulter si fièvre ou douleur lombaire (suspicion pyélonéphrite)."
    ]'::jsonb,
    '[
      "ECBU non indiqué en première intention dans la cystite simple."
    ]'::jsonb,
    'SPILF / AFU Infections Urinaires Communautaires',
    true
  ),
  (
    'ordo_pyelonephrite_simple',
    'Pyélonéphrite Aiguë Simple (PNA)',
    'Infectiologie / Urgences',
    'Sans signe de gravité ni grossesse (après ECBU réalisé)',
    false,
    '[
      {
        "dci_name": "Ciprofloxacine (ou Ceftriaxone IV/IM si prise récente FQ)",
        "commercial_name_dz": "Ciflox® / Ciprolon® / Rocephine®",
        "formulation": "Comprimés 500 mg",
        "adult_dosage": "500 mg x 2/jour (matin et soir)",
        "pediatric_mg_per_kg_per_day": null,
        "max_pediatric_daily_mg": null,
        "duration": "7 jours",
        "clinical_note": "Adapter selon l''antibiogramme de l''ECBU à 48h."
      },
      {
        "dci_name": "Paracétamol",
        "commercial_name_dz": "Doliprane® 1 g",
        "formulation": "Comprimés 1 g",
        "adult_dosage": "1 cp toutes les 8h si fièvre ou lombalgies",
        "pediatric_mg_per_kg_per_day": null,
        "max_pediatric_daily_mg": null,
        "duration": "5 jours",
        "clinical_note": null
      }
    ]'::jsonb,
    '[
      "Échographie rénale dans les 24h si hyperalgique ou doute sur obstacle."
    ]'::jsonb,
    '[
      "Fluoroquinolones contre-indiquées chez la femme enceinte (préférer Ceftriaxone)."
    ]'::jsonb,
    'SPILF / SFMU Pyélonéphrite Aiguë',
    true
  ),
  (
    'ordo_asthme_sortie',
    'Crise d''Asthme — Ordonnance de Sortie des Urgences',
    'Pneumologie / Urgences',
    'Après nébulisations aux urgences et amélioration du DEP > 70%',
    true,
    '[
      {
        "dci_name": "Salbutamol (SABA)",
        "commercial_name_dz": "Ventoline® / Asthalin®",
        "formulation": "Aérosol-doseur 100 µg/bouffée (+ Chambre d''inhalation si enfant)",
        "adult_dosage": "2 bouffées à la demande si dyspnée/sifflements (jusqu''à 4x/j)",
        "pediatric_mg_per_kg_per_day": null,
        "max_pediatric_daily_mg": null,
        "duration": "15 jours",
        "clinical_note": null
      },
      {
        "dci_name": "Prednisone / Prednisolone",
        "commercial_name_dz": "Cortancyl® / Solupred® / Precortyl®",
        "formulation": "Comprimés 20 mg ou 5 mg",
        "adult_dosage": "40 à 50 mg/jour en 1 prise unique le matin au petit-déjeuner",
        "pediatric_mg_per_kg_per_day": "1",
        "max_pediatric_daily_mg": 40,
        "duration": "5 jours (sans décroissance)",
        "clinical_note": null
      },
      {
        "dci_name": "Budésonide + Formotérol (ou Béclométasone)",
        "commercial_name_dz": "Symbicort® / Clenil® / Pulmicort®",
        "formulation": "Inhalateur de fond",
        "adult_dosage": "1 à 2 inhalations matin et soir (selon palier GINA)",
        "pediatric_mg_per_kg_per_day": null,
        "max_pediatric_daily_mg": null,
        "duration": "1 mois (à réévaluer en consultation pneumo)",
        "clinical_note": null
      }
    ]'::jsonb,
    '[
      "Se rincer la bouche après chaque prise de corticoïde inhalé.",
      "Consultation de suivi médical dans les 48-72h."
    ]'::jsonb,
    '[]'::jsonb,
    'GINA / SPLF / SFMU Exacerbation d''Asthme',
    true
  ),
  (
    'ordo_hta_initiation',
    'HTA Essentielle — Initiation Thérapeutique',
    'Cardiologie',
    'HTA confirmée (PAS ≥ 140 et/ou PAD ≥ 90 mmHg au repos / MAPA)',
    false,
    '[
      {
        "dci_name": "Amlodipine + Périndopril (ou Valsartan)",
        "commercial_name_dz": "Coveram® / Exforge® / Amlor® + Coversyl®",
        "formulation": "Comprimés 5 mg / 5 mg (ou 5/80 mg)",
        "adult_dosage": "1 comprimé le matin",
        "pediatric_mg_per_kg_per_day": null,
        "max_pediatric_daily_mg": null,
        "duration": "1 mois (renouvelable 3 mois)",
        "clinical_note": null
      }
    ]'::jsonb,
    '[
      "Régime hyposodé (< 5 g sel/j), activité physique régulière 30 min/j, arrêt du tabac.",
      "Automesure tensionnelle (règle des 3) avant la consultation de contrôle à 4 semaines."
    ]'::jsonb,
    '[
      "IEC/ARA2 strictement contre-indiqués pendant la grossesse et si sténose bilatérale des artères rénales."
    ]'::jsonb,
    'ESC / ESH / Société Algérienne d''Hypertension Artérielle (SAHA)',
    true
  ),
  (
    'ordo_gea_sro',
    'Gastro-Entérite Aiguë & Prévention Déshydratation',
    'Gastro-Entérologie / Pédiatrie',
    'Diarrhée aiguë sans signe de sepsis ni déshydratation sévère',
    true,
    '[
      {
        "dci_name": "Sels de Réhydratation Orale (SRO)",
        "commercial_name_dz": "SRO Saidal® / Adiaril®",
        "formulation": "Sachets à diluer dans 200 ml (ou 1L selon sachet) d''eau faiblement minéralisée",
        "adult_dosage": "À volonté par petites gorgées fréquentes après chaque selle liquide",
        "pediatric_mg_per_kg_per_day": null,
        "max_pediatric_daily_mg": null,
        "duration": "3 à 5 jours",
        "clinical_note": null
      },
      {
        "dci_name": "Diosmectite ou Racécadotril",
        "commercial_name_dz": "Smecta® / Tiorfan®",
        "formulation": "Sachets pour suspension buvable",
        "adult_dosage": "1 sachet x 3/jour (Smecta à distance de 2h des autres médicaments)",
        "pediatric_mg_per_kg_per_day": null,
        "max_pediatric_daily_mg": null,
        "duration": "3 à 5 jours",
        "clinical_note": null
      },
      {
        "dci_name": "Phloroglucinol (si douleurs spasmodiques)",
        "commercial_name_dz": "Spasfon®",
        "formulation": "Comprimés orodispersibles 80 mg",
        "adult_dosage": "2 lyocs en cas de crampes abdominales (max 6/j)",
        "pediatric_mg_per_kg_per_day": null,
        "max_pediatric_daily_mg": null,
        "duration": "3 jours",
        "clinical_note": null
      }
    ]'::jsonb,
    '[]'::jsonb,
    '[]'::jsonb,
    'ESPGHAN / OMS / SFP Prise en Charge de la Gastro-Entérite Aiguë',
    true
  )
ON CONFLICT (id) DO NOTHING;
