#!/usr/bin/env python3
"""
Medsina Synapse — Générateur Automatique de Cas Cliniques ECOS
Enrichit la banque de cas cliniques de Medsina Synapse à partir de la bibliothèque des cours Medsina.

Ce script :
1. Sélectionne un cours clinique clé dans la table `courses` (priorité aux cours tombables/résidanat)
2. Récupère son résumé, ses pièges et critères diagnostiques dans `course_summaries`
3. Génère via Google Gemini un cas clinique ECOS réaliste (contexte algérien : UMC, EPH, CHU, nomenclature algérienne)
4. Enregistre le cas dans Supabase (`synapse_cases`)
5. Exporte et synchronise `cases.json` sur l'hébergement Octenium (/synapse/cases.json)
"""

import os
import sys
import json
import random
import re
import urllib.request
import ftplib
from datetime import datetime, timezone
from pathlib import Path

# Fix Windows stdout encoding
if sys.stdout and hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

SUPABASE_URL = os.environ.get("SUPABASE_URL", "https://qzfssrhhuorljftpdvjm.supabase.co").rstrip("/")
SUPABASE_KEY = os.environ.get(
    "SUPABASE_SERVICE_ROLE_KEY",
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF6ZnNzcmhodW9ybGpmdHBkdmptIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MTYxMjg1NCwiZXhwIjoyMTA3MTg4ODU0fQ.-KCUgZdY8RDUwvNOUAabDhQFwv5FFGHYz0J-dM7Cic4"
)

GEMINI_MODELS = [
    "models/gemini-3.1-flash-lite",
    "models/gemini-3.5-flash",
    "models/gemini-flash-latest"
]

CLINICAL_MODULES = [
    "Blida_CARDIOLOGIE",
    "Blida_PNEUMOLOGIE",
    "Blida_HEPATO_GASTRO_ENTEROLOGIE",
    "Blida_NEUROLOGIE",
    "Blida_ENDOCRINO",
    "Blida_MALADIES_INFECTIEUSES",
    "Blida_PEDIATRIE",
    "Blida_GYNECOLOGIE_OBSTETRIQUE",
    "Blida_DERMATOLOGIE",
    "Blida_HEMATOLOGIE",
    "Blida_APPAREIL_LOCOMOTEUR",
    "Blida_MALADIES_DE_SYSTEME",
    "Blida_GERIATRIE"
]

def log(msg, symbol="ℹ️"):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{timestamp}] {symbol} {msg}")

def get_gemini_api_key():
    key = os.environ.get("GEMINI_API_KEY")
    if key and key.strip():
        return key.strip()
    
    # Check Supabase admin_system_settings
    try:
        req = urllib.request.Request(
            f"{SUPABASE_URL}/rest/v1/admin_system_settings?setting_key=eq.gemini_api_key&select=setting_value",
            headers={"apikey": SUPABASE_KEY, "Authorization": f"Bearer {SUPABASE_KEY}"}
        )
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode())
            if data and data[0].get("setting_value"):
                return data[0]["setting_value"].strip()
    except Exception as e:
        log(f"Notice lors de la récupération de la clé Gemini depuis Supabase: {e}", "⚠️")
    
    return None

def get_octenium_credentials():
    ftp_host = os.environ.get("OCTENIUM_FTP_HOST", "medevsync.com")
    ftp_user = os.environ.get("OCTENIUM_FTP_USER", "rnhgnubg")
    ftp_pass = os.environ.get("OCTENIUM_FTP_PASSWORD")

    if not ftp_pass:
        try:
            req = urllib.request.Request(
                f"{SUPABASE_URL}/rest/v1/admin_system_settings?select=setting_key,setting_value",
                headers={"apikey": SUPABASE_KEY, "Authorization": f"Bearer {SUPABASE_KEY}"}
            )
            with urllib.request.urlopen(req, timeout=10) as resp:
                data = json.loads(resp.read().decode())
                for r in data:
                    k, v = r.get("setting_key"), r.get("setting_value")
                    if k == "octenium_ftp_host" and v: ftp_host = v
                    elif k == "octenium_ftp_user" and v: ftp_user = v
                    elif k == "octenium_ftp_password" and v: ftp_pass = v
        except Exception as e:
            log(f"Erreur credentials FTP: {e}", "⚠️")

    return ftp_host, ftp_user, ftp_pass

def select_course_for_case():
    """Sélectionne un cours pertinent dans la bibliothèque Medsina."""
    log("Recherche d'un cours médical dans la bibliothèque Medsina...", "📚")
    
    # 1. Obtenir les IDs de cours qui ont déjà un cas Synapse
    existing_course_ids = set()
    try:
        req = urllib.request.Request(
            f"{SUPABASE_URL}/rest/v1/synapse_cases?select=course_id",
            headers={"apikey": SUPABASE_KEY, "Authorization": f"Bearer {SUPABASE_KEY}"}
        )
        with urllib.request.urlopen(req, timeout=10) as resp:
            for r in json.loads(resp.read().decode()):
                if r.get("course_id"):
                    existing_course_ids.add(r["course_id"])
    except Exception as e:
        log(f"Notice synapse_cases: {e}", "⚠️")

    # 2. Choisir un module clinique au hasard
    selected_module = random.choice(CLINICAL_MODULES)
    log(f"Module clinique cible : {selected_module}", "🎯")

    # 3. Récupérer les cours du module (priorité aux tombables ou avec questions)
    query_url = f"{SUPABASE_URL}/rest/v1/courses?module_id=eq.{selected_module}&select=id,name,module_id,tag,is_hypertombable,questions_count&limit=100"
    req = urllib.request.Request(
        query_url,
        headers={"apikey": SUPABASE_KEY, "Authorization": f"Bearer {SUPABASE_KEY}"}
    )
    with urllib.request.urlopen(req, timeout=15) as resp:
        courses = json.loads(resp.read().decode())

    if not courses:
        # Fallback sur n'importe quel cours
        req = urllib.request.Request(
            f"{SUPABASE_URL}/rest/v1/courses?select=id,name,module_id,tag,is_hypertombable,questions_count&limit=50",
            headers={"apikey": SUPABASE_KEY, "Authorization": f"Bearer {SUPABASE_KEY}"}
        )
        with urllib.request.urlopen(req, timeout=15) as resp:
            courses = json.loads(resp.read().decode())

    # Filtrer les cours sans cas encore généré
    uncovered = [c for c in courses if c["id"] not in existing_course_ids]
    candidate_pool = uncovered if uncovered else courses

    # Trier par priorité tombable
    candidate_pool.sort(key=lambda c: (c.get("is_hypertombable") is True, c.get("questions_count", 0)), reverse=True)
    
    # Prendre un cours parmi les meilleurs candidats
    top_candidates = candidate_pool[:min(10, len(candidate_pool))]
    chosen_course = random.choice(top_candidates)
    log(f"Cours sélectionné : '{chosen_course.get('name')}' (ID: {chosen_course.get('id')})", "✅")

    # 4. Récupérer le résumé de cours s'il existe
    summary_data = None
    try:
        s_url = f"{SUPABASE_URL}/rest/v1/course_summaries?course_id=eq.{chosen_course['id']}&select=*"
        req_s = urllib.request.Request(
            s_url,
            headers={"apikey": SUPABASE_KEY, "Authorization": f"Bearer {SUPABASE_KEY}"}
        )
        with urllib.request.urlopen(req_s, timeout=10) as resp:
            s_rows = json.loads(resp.read().decode())
            if s_rows:
                summary_data = s_rows[0]
                log(f"Résumé de cours trouvé pour '{chosen_course.get('name')}'.", "📖")
    except Exception as e:
        log(f"Pas de résumé structuré préexistant ({e}), génération sur base du titre.", "ℹ️")

    return chosen_course, summary_data

def generate_case_with_gemini(course, summary, gemini_key):
    """Génère un cas clinique ECOS complet conforme au schéma Synapse."""
    course_name = course.get("name", "Pathologie Médicale")
    module_id = course.get("module_id", "Médecine")
    specialty = module_id.replace("Blida_", "").replace("_", " ").title()
    if "Hépato Gastro" in specialty or "Hepato Gastro" in specialty:
        specialty = "Gastro-entérologie"
    elif "Endocrino" in specialty:
        specialty = "Endocrinologie"
    elif "Infectieuses" in specialty:
        specialty = "Infectiologie"
    elif "Appareil Locomoteur" in specialty:
        specialty = "Rhumatologie / Orthopédie"
    elif "Systeme" in specialty:
        specialty = "Médecine Interne"

    log(f"Génération IA du cas clinique Synapse pour la spécialité '{specialty}'...", "🤖")

    course_context = f"Cours : {course_name} (Module : {module_id}, Spécialité : {specialty})."
    if summary:
        if summary.get("diagnostic_criteria"):
            course_context += f"\nCritères Diagnostiques : {summary.get('diagnostic_criteria')}"
        if summary.get("exam_traps"):
            course_context += f"\nPièges classiques Résidanat : {summary.get('exam_traps')}"
        if summary.get("treatment_summary"):
            course_context += f"\nPrise en charge thérapeutique : {summary.get('treatment_summary')}"
        if summary.get("key_takeaways"):
            course_context += f"\nPoints clés : {summary.get('key_takeaways')}"

    system_prompt = """Tu es un Professeur de Médecine en Algérie, concepteur d'épreuves cliniques de Résidanat et de stations ECOS (Examen Clinique Objectif Structuré) pour Medsina Synapse.
Tu dois générer un cas clinique ECOS interactif, ultra-réaliste, rigoureux et ancré dans la pratique médicale en Algérie (UMC, EPH, EPSP, CHU de Blida / Alger, nomenclature nationale des médicaments, consensus algériens MSPRH).

Tu DOIS impérativement répondre avec un SEUL objet JSON valide (aucun texte autour, pas de balises markdown) respectant SCRUPULEUSEMENT la structure suivante :
{
  "title": "Titre clinique percutant décrivant le motif d'admission (ex: Dyspnée aiguë et crachats mousseux aux UMC chez une femme de 62 ans)",
  "specialty": "Nom de la spécialité",
  "ednItem": "Item officiel du programme de Résidanat / EDN en Algérie",
  "level": "Débutant" ou "Intermédiaire" ou "Avancé",
  "contextSummary": "Court paragraphe d'admission détaillant les circonstances d'arrivée du patient",
  "patientProfile": {
    "name": "Prénom et Nom algérien réaliste (ex: Fatima Zohra B., Mohamed K.)",
    "age": 45,
    "gender": "Homme" ou "Femme",
    "profession": "Profession algérienne (ex: Enseignant, Agriculteur à Tipaza, Retraité, Femme au foyer)",
    "medicalHistory": "Antécédents médicaux et chirurgicaux précis",
    "lifestyle": "Mode de vie (tabagisme en PA, habitudes, alimentation)",
    "allergies": "Allergies connues ou 'Aucune allergie connue'"
  },
  "initialVitals": {
    "heartRate": 105,
    "bloodPressure": "150/90",
    "systolicBP": 150,
    "diastolicBP": 90,
    "spo2": 93,
    "respiratoryRate": 24,
    "temperature": 37.4,
    "glasgow": 15,
    "isCritical": true
  },
  "suggestedQuestions": [
    "Question clinique ciblée 1 que le médecin doit poser ?",
    "Question clinique ciblée 2 ?",
    "Question clinique ciblée 3 ?",
    "Question clinique ciblée 4 ?",
    "Question clinique ciblée 5 ?"
  ],
  "physicalExam": {
    "general": "État général, faciès, sueurs, posture, conjonctives",
    "cardiovascular": "Auscultation cardiaque, bruits, souffles, pouls, turgescence jugulaire",
    "pulmonary": "Auscultation pulmonaire, murmure vésiculaire, râles crépitants ou sibilants",
    "neurological": "Examen neurologique, conscience, réflexes, signes méningés ou déficit",
    "abdominal": "Palpation abdominale, hépatomégalie, splénomégalie, défense"
  },
  "availableLabs": [
    {
      "code": "nfs",
      "name": "Hémogramme complet (NFS)",
      "category": "Hématologie",
      "value": "Hb: 13.2 g/dL, Leucocytes: 11.8 G/L, Plaquettes: 220 G/L",
      "unit": "g/dL",
      "referenceRange": "12-16 g/dL",
      "isAbnormal": true,
      "clinicalSignificance": "Explication de la valeur pour le cas"
    },
    {
      "code": "iono_creat",
      "name": "Ionogramme sanguin & Fonction rénale",
      "category": "Biochimie",
      "value": "Na: 138 mmol/L, K: 4.2 mmol/L, Urée: 6.5 mmol/L, Créat: 82 µmol/L",
      "unit": "mmol/L",
      "referenceRange": "Na 135-145, K 3.5-5.0",
      "isAbnormal": false,
      "clinicalSignificance": "Fonction rénale conservée"
    },
    {
      "code": "lab_spe_1",
      "name": "Examen biologique spécifique à la pathologie",
      "category": "Biochimie",
      "value": "Valeur pathologique ou normale",
      "unit": "Unité",
      "referenceRange": "Norme",
      "isAbnormal": true,
      "clinicalSignificance": "Interprétation clinique déterminante"
    },
    {
      "code": "lab_spe_2",
      "name": "Deuxième examen biologique spécifique",
      "category": "Marqueurs",
      "value": "Valeur",
      "unit": "Unité",
      "referenceRange": "Norme",
      "isAbnormal": true,
      "clinicalSignificance": "Interprétation"
    }
  ],
  "availableImaging": [
    {
      "id": "img-1",
      "type": "ECG" ou "Radiographie" ou "Échographie" ou "TDM",
      "title": "Nom précis de l'examen d'imagerie",
      "findings": "Description sémiologique détaillée de l'anomalie visible",
      "conclusion": "Conclusion diagnostique de l'imagerie",
      "urgencyLevel": "Urgent" ou "Vital" ou "Programmable"
    }
  ],
  "correctDiagnosis": "Diagnostic principal exact et précis",
  "differentialDiagnoses": [
    "Diagnostic différentiel plausible 1",
    "Diagnostic différentiel plausible 2",
    "Diagnostic différentiel plausible 3"
  ],
  "clinicalRationale": "Explication physiopathologique et sémiologique complète justifiant le diagnostic et la stratégie selon les recommandations de consensus algérien et international (sociétés savantes).",
  "recommendedActions": [
    {
      "id": "act-1",
      "label": "Action thérapeutique ou de réanimation prioritaire obligatoire",
      "category": "Médicamenteux" ou "Oxygénothérapie" ou "Avis spécialisé" ou "Surveillance",
      "isMandatory": true,
      "isHarmful": false,
      "explanation": "Pourquoi cette action est indispensable"
    },
    {
      "id": "act-2",
      "label": "Deuxième action obligatoire",
      "category": "Médicamenteux",
      "isMandatory": true,
      "isHarmful": false,
      "explanation": "Raison"
    },
    {
      "id": "act-3",
      "label": "Troisième action obligatoire",
      "category": "Surveillance",
      "isMandatory": true,
      "isHarmful": false,
      "explanation": "Raison"
    },
    {
      "id": "act-4",
      "label": "Piège classique ou prescription contre-indiquée / dangereuse",
      "category": "Médicamenteux",
      "isMandatory": false,
      "isHarmful": true,
      "explanation": "Pourquoi cette action est formellement contre-indiquée et dangereuse pour ce patient"
    }
  ]
}"""

    prompt = f"""Génère un cas clinique complet de station ECOS pour la plateforme Medsina Synapse basé sur les connaissances de ce cours :
{course_context}

Assure-toi que :
1. Le cas représente une situation clinique authentique rencontrée en consultation, aux urgences (UMC) ou en hospitalisation en Algérie.
2. Les constantes vitales, signes d'examen, examens biologiques et radiologiques soient chiffrés et précis.
3. Les pièges et contre-indications (`isHarmful: true`) soient pertinents pour former les candidats au résidanat."""

    for model in GEMINI_MODELS:
        log(f"Tentative de génération avec le modèle '{model}'...", "⚡")
        url = f"https://generativelanguage.googleapis.com/v1beta/{model}:generateContent?key={gemini_key}"
        payload = {
            "systemInstruction": {"parts": [{"text": system_prompt}]},
            "contents": [{"parts": [{"text": prompt}]}],
            "generationConfig": {
                "temperature": 0.35,
                "maxOutputTokens": 6000,
                "responseMimeType": "application/json"
            }
        }
        
        try:
            req = urllib.request.Request(
                url,
                data=json.dumps(payload).encode("utf-8"),
                headers={"Content-Type": "application/json"}
            )
            with urllib.request.urlopen(req, timeout=50) as resp:
                if resp.status == 200:
                    raw_data = json.loads(resp.read().decode("utf-8"))
                    candidates = raw_data.get("candidates", [])
                    if candidates and "content" in candidates[0]:
                        parts = candidates[0]["content"].get("parts", [])
                        if parts and "text" in parts[0]:
                            text = parts[0]["text"].strip()
                            clean = re.sub(r"^```json\s*", "", text)
                            clean = re.sub(r"\s*```$", "", clean)
                            parsed = json.loads(clean)
                            log(f"Cas généré avec succès par {model} ! Titre: '{parsed.get('title')}'", "✨")
                            return parsed
        except Exception as e:
            log(f"Échec avec {model}: {e}. Essai du modèle suivant...", "⚠️")

    raise RuntimeError("Impossible de générer le cas clinique via Gemini (tous les modèles ont échoué).")

def validate_and_format_case(case_data, course):
    """Valide et enrichit le cas pour la base de données et le frontend."""
    # Créer un ID unique et stable
    slug_title = re.sub(r"[^a-z0-9]+", "-", case_data.get("title", "").lower()).strip("-")[:40]
    case_id = f"synapse-{course.get('module_id', 'cas').lower()}-{slug_title}-{int(datetime.now().timestamp())}"
    
    formatted = {
        "id": case_id,
        "course_id": course.get("id"),
        "course_name": course.get("name"),
        "module_id": course.get("module_id"),
        "title": case_data.get("title", f"Cas clinique : {course.get('name')}"),
        "specialty": case_data.get("specialty", "Médecine"),
        "edn_item": case_data.get("ednItem", f"Item Résidanat · {course.get('name')}"),
        "level": case_data.get("level", "Intermédiaire"),
        "context_summary": case_data.get("contextSummary", ""),
        "patient_profile": case_data.get("patientProfile", {}),
        "initial_vitals": case_data.get("initialVitals", {}),
        "suggested_questions": case_data.get("suggestedQuestions", []),
        "physical_exam": case_data.get("physicalExam", {}),
        "available_labs": case_data.get("availableLabs", []),
        "available_imaging": case_data.get("availableImaging", []),
        "correct_diagnosis": case_data.get("correctDiagnosis", ""),
        "differential_diagnoses": case_data.get("differentialDiagnoses", []),
        "clinical_rationale": case_data.get("clinicalRationale", ""),
        "recommended_actions": case_data.get("recommendedActions", []),
        "is_active": True,
        "created_at": datetime.now(timezone.utc).isoformat()
    }
    return formatted

def save_case_to_supabase(case):
    """Sauvegarde le nouveau cas dans `synapse_cases`."""
    log(f"Enregistrement du cas '{case['id']}' dans Supabase...", "💾")
    url = f"{SUPABASE_URL}/rest/v1/synapse_cases"
    req = urllib.request.Request(
        url,
        data=json.dumps(case).encode("utf-8"),
        headers={
            "apikey": SUPABASE_KEY,
            "Authorization": f"Bearer {SUPABASE_KEY}",
            "Content-Type": "application/json",
            "Prefer": "resolution=merge-duplicates"
        }
    )
    with urllib.request.urlopen(req, timeout=15) as resp:
        log("Cas sauvegardé avec succès dans Supabase !", "✅")

def sync_cases_to_octenium(ftp_host, ftp_user, ftp_pass):
    """Récupère tous les cas actifs de Supabase et génère /synapse/cases.json sur Octenium."""
    log("Synchronisation de la banque de cas complète vers Octenium FTP...", "🚀")
    
    # Récupérer tous les cas
    req = urllib.request.Request(
        f"{SUPABASE_URL}/rest/v1/synapse_cases?is_active=eq.true&order=created_at.desc",
        headers={"apikey": SUPABASE_KEY, "Authorization": f"Bearer {SUPABASE_KEY}"}
    )
    with urllib.request.urlopen(req, timeout=15) as resp:
        db_cases = json.loads(resp.read().decode("utf-8"))

    # Convertir vers le format camelCase exact attendu par le frontend React Synapse
    frontend_cases = []
    for c in db_cases:
        frontend_cases.append({
            "id": c["id"],
            "courseId": c.get("course_id"),
            "courseName": c.get("course_name"),
            "title": c["title"],
            "specialty": c["specialty"],
            "ednItem": c.get("edn_item"),
            "level": c.get("level", "Intermédiaire"),
            "contextSummary": c["context_summary"],
            "patientProfile": c["patient_profile"],
            "initialVitals": c["initial_vitals"],
            "suggestedQuestions": c.get("suggested_questions", []),
            "physicalExam": c["physical_exam"],
            "availableLabs": c.get("available_labs", []),
            "availableImaging": c.get("available_imaging", []),
            "correctDiagnosis": c["correct_diagnosis"],
            "differentialDiagnoses": c.get("differential_diagnoses", []),
            "clinicalRationale": c["clinical_rationale"],
            "recommendedActions": c.get("recommended_actions", []),
            "createdAt": c.get("created_at")
        })

    json_bytes = json.dumps(frontend_cases, ensure_ascii=False, indent=2).encode("utf-8")
    log(f"Nombre total de cas dans la banque : {len(frontend_cases)} ({len(json_bytes)} octets)", "📊")

    # Connexion FTP
    try:
        ftp = ftplib.FTP(ftp_host, timeout=30)
        ftp.login(ftp_user, ftp_pass)
        
        # Aller dans medsina.medevsync.com/synapse
        try:
            ftp.cwd("medsina.medevsync.com/synapse")
        except Exception:
            ftp.cwd("public_html/synapse")

        import io
        bio = io.BytesIO(json_bytes)
        ftp.storbinary("STOR cases.json", bio)
        log("Fichier 'cases.json' transféré avec succès sur Octenium !", "✅")

        # Aussi dans api/cases.json si le dossier api existe
        try:
            ftp.cwd("api")
            bio2 = io.BytesIO(json_bytes)
            ftp.storbinary("STOR cases.json", bio2)
            log("Fichier 'api/cases.json' synchronisé !", "✅")
        except Exception:
            pass

        ftp.quit()
    except Exception as e:
        log(f"Avertissement lors de l'upload FTP sur Octenium : {e}", "⚠️")

def update_admin_stats(case):
    """Enregistre la trace de génération pour l'admin."""
    try:
        now_str = datetime.now(timezone.utc).isoformat()
        payload = [
            {
                "setting_key": "last_synapse_generated_case",
                "setting_value": json.dumps({
                    "id": case["id"],
                    "title": case["title"],
                    "specialty": case["specialty"],
                    "course_id": case.get("course_id"),
                    "generated_at": now_str
                }, ensure_ascii=False),
                "updated_at": now_str
            }
        ]
        req = urllib.request.Request(
            f"{SUPABASE_URL}/rest/v1/admin_system_settings",
            data=json.dumps(payload).encode("utf-8"),
            headers={
                "apikey": SUPABASE_KEY,
                "Authorization": f"Bearer {SUPABASE_KEY}",
                "Content-Type": "application/json",
                "Prefer": "resolution=merge-duplicates"
            }
        )
        urllib.request.urlopen(req, timeout=10)
    except Exception as e:
        log(f"Notice admin_stats: {e}", "ℹ️")

def main():
    log("=== Medsina Synapse — Enrichissement Automatique de Cas Cliniques ===", "🏥")
    
    # 1. Clé Gemini
    gemini_key = get_gemini_api_key()
    
    # 2. Identifiants FTP Octenium
    ftp_host, ftp_user, ftp_pass = get_octenium_credentials()

    # 3. Sélectionner un cours dans la bibliothèque
    course, summary = select_course_for_case()

    # 4. Générer le cas avec l'IA
    raw_case = generate_case_with_gemini(course, summary, gemini_key)

    # 5. Valider et formater
    formatted_case = validate_and_format_case(raw_case, course)

    # 6. Sauvegarder dans Supabase
    save_case_to_supabase(formatted_case)

    # 7. Synchroniser vers Octenium
    sync_cases_to_octenium(ftp_host, ftp_user, ftp_pass)

    # 8. Mettre à jour les paramètres admin
    update_admin_stats(formatted_case)

    log(f"🎉 SUCCÈS COMPLET ! Nouveau cas Synapse créé : '{formatted_case['title']}' ({formatted_case['specialty']})", "🏆")

if __name__ == "__main__":
    main()
