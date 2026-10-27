#!/usr/bin/env python3
"""
MedsinaPilot Autonomous Medical Agent
Continuous Clinical Protocol (CAT) & Daily Pearl Enrichment Engine

Automates:
1. Generation of rigorous clinical protocols (Conduites à Tenir - CAT) grounded in
   official residency curriculum and latest international/Algerian consensus (HAS, ESC, GINA, GOLD, SFMU, MSPRH).
   Strict duplicate prevention: ensures every course gets covered without repetition.
2. Generation of the Daily Clinical Pearl & Residency Exam Trap (Perle du Jour).
"""

import os
import sys
import json
import random
import re
import argparse
import datetime
import time
from pathlib import Path
from typing import List, Dict, Any, Optional

# Ensure script directory is in sys.path
SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))


try:
    if sys.stdout.encoding.lower() != "utf-8":
        sys.stdout.reconfigure(encoding="utf-8")
    if sys.stderr.encoding.lower() != "utf-8":
        sys.stderr.reconfigure(encoding="utf-8")
except Exception:
    pass

try:
    import requests
except ImportError:
    print("Error: 'requests' library is required. Run 'pip install requests'.", file=sys.stderr)
    sys.exit(1)

DEFAULT_SUPABASE_URL = "https://qzfssrhhuorljftpdvjm.supabase.co"

def _resolve_gemini_key() -> str:
    # 1. Supabase admin_system_settings (centralized cloud config - always primary & up-to-date)
    sub_key = _resolve_supabase_key()
    if sub_key:
        try:
            url = f"{SUPABASE_URL}/rest/v1/admin_system_settings?setting_key=eq.gemini_api_key&select=setting_value"
            r = requests.get(url, headers={"apikey": sub_key, "Authorization": f"Bearer {sub_key}"}, timeout=8)
            if r.status_code == 200:
                rows = r.json()
                if rows and rows[0].get("setting_value"):
                    val = rows[0]["setting_value"].strip()
                    if val:
                        return val
        except Exception:
            pass

    # 2. Environment variable
    key = os.environ.get("GEMINI_API_KEY")
    if key and key.strip():
        return key.strip()

    # 3. app_secrets.dart fallback
    secrets_file = Path(__file__).resolve().parents[2] / "lib" / "core" / "config" / "app_secrets.dart"
    if secrets_file.exists():
        try:
            import re
            content = secrets_file.read_text(encoding="utf-8")
            m = re.search(r"geminiApiKey\s*=\s*['\"]([^'\"]+)['\"]", content)
            if m and m.group(1).strip():
                return m.group(1).strip()
        except Exception:
            pass

    return ""


def _resolve_supabase_key() -> str:
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY") or os.environ.get("SUPABASE_KEY")
    if key:
        return key
    env_file = Path(__file__).resolve().parents[2] / ".env"
    if env_file.exists():
        try:
            import re
            content = env_file.read_text(encoding="utf-8")
            m = re.search(r"SUPABASE_SERVICE_ROLE_KEY\s*=\s*['\"]?([^'\"\r\n]+)['\"]?", content)
            if m:
                return m.group(1).strip()
        except Exception:
            pass
    return ""

SUPABASE_URL = os.environ.get("SUPABASE_URL", DEFAULT_SUPABASE_URL).rstrip("/")
SUPABASE_KEY = _resolve_supabase_key()
GEMINI_API_KEY = _resolve_gemini_key()

CATALOG_FILE = Path(__file__).resolve().parents[2] / "assets" / "data" / "modules_catalog_47.json"
EMERGENCY_DRUGS_FILE = Path(__file__).resolve().parents[2] / "assets" / "data" / "emergency_drugs_algeria.json"
ALGERIAN_NOMENCLATURE_FILE = Path(__file__).resolve().parents[2] / "assets" / "data" / "algerian_nomenclature.json"
LAB_VALUES_FILE = Path(__file__).resolve().parents[2] / "assets" / "data" / "lab_reference_values.json"
ON_CALL_MEMENTOS_FILE = Path(__file__).resolve().parents[2] / "assets" / "data" / "on_call_mementos.json"
COURSE_SUMMARIES_FILE = Path(__file__).resolve().parents[2] / "assets" / "data" / "course_summaries.json"

GEMINI_MODELS = [
    "gemini-3.5-flash-lite",
    "gemini-3.8-flash",
    "gemini-3.1-pro-preview",
    "gemini-4-argon",
]


class SupabaseClient:
    """Lightweight REST client for Supabase PostgREST API."""

    def __init__(self, url: str, key: str):
        self.url = url
        self.key = key
        self.headers = {
            "apikey": key,
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
            "Prefer": "return=representation",
        }

    def get(self, endpoint: str, params: Optional[Dict[str, str]] = None) -> List[Dict[str, Any]]:
        if not self.key:
            return []
        try:
            r = requests.get(f"{self.url}/rest/v1/{endpoint}", headers=self.headers, params=params, timeout=20)
            if r.status_code in (200, 206):
                return r.json()
            print(f"Supabase GET /{endpoint} status {r.status_code}: {r.text[:200]}")
            return []
        except Exception as e:
            print(f"Supabase GET error: {e}")
            return []

    def post(self, endpoint: str, data: Dict[str, Any], upsert: bool = True) -> Optional[Dict[str, Any]]:
        if not self.key:
            print("Notice: No SUPABASE_KEY provided. Skipping remote database write.")
            return None
        headers = dict(self.headers)
        if upsert:
            headers["Prefer"] = "resolution=merge-duplicates,return=representation"
        try:
            r = requests.post(f"{self.url}/rest/v1/{endpoint}", headers=headers, json=data, timeout=25)
            if r.status_code in (200, 201):
                res = r.json()
                return res[0] if isinstance(res, list) and len(res) > 0 else res
            print(f"Supabase POST /{endpoint} error ({r.status_code}): {r.text[:300]}")
            return None
        except Exception as e:
            print(f"Supabase POST error: {e}")
            return None


def send_broadcast_notification(
    supabase: SupabaseClient,
    notif_id: str,
    title: str,
    message: str,
    notif_type: str,
    target_id: Optional[str] = None,
    metadata: Optional[Dict[str, Any]] = None,
) -> None:
    """Dispatches a broadcast notification to all Medsina users via medical_notifications."""
    payload = {
        "id": notif_id,
        "title": title,
        "message": message,
        "type": notif_type,
        "target_id": target_id,
        "target_role": "user",
        "is_broadcast": True,
        "metadata": metadata or {},
    }
    supabase.post("medical_notifications", payload, upsert=True)
    print(f"📢 Broadcast Notification Sent: '{title}'")


def call_gemini_api(prompt: str, system_prompt: str, enable_search: bool = True, max_rounds: int = 3) -> str:
    """Calls Gemini API with cascading models, exponential backoff on 429/503, and multi-round retries."""
    if not GEMINI_API_KEY:
        raise ValueError("Missing GEMINI_API_KEY")

    # Attempt with search first, fallback to standard if search tool hits quota limit
    search_options = [True, False] if enable_search else [False]

    for round_num in range(1, max_rounds + 1):
        if round_num > 1:
            backoff_delay = 5.0 * (round_num - 1)
            print(f"🔄 Retrying Gemini cascade (Round {round_num}/{max_rounds}) after {backoff_delay:.0f}s cooldown...")
            time.sleep(backoff_delay)

        for use_search in search_options:
            for model in GEMINI_MODELS:
                url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={GEMINI_API_KEY}"
                
                request_body: Dict[str, Any] = {
                    "systemInstruction": {
                        "parts": [{"text": system_prompt}]
                    },
                    "contents": [
                        {
                            "parts": [{"text": prompt}]
                        }
                    ],
                    "generationConfig": {
                        "temperature": 0.2,
                        "maxOutputTokens": 8192,
                    }
                }

                if use_search:
                    request_body["tools"] = [{"googleSearch": {}}]

                try:
                    resp = requests.post(url, json=request_body, headers={"Content-Type": "application/json"}, timeout=45)
                    if resp.status_code == 200:
                        data = resp.json()
                        candidates = data.get("candidates", [])
                        if candidates:
                            parts = candidates[0].get("content", {}).get("parts", [])
                            if parts and "text" in parts[0]:
                                return parts[0]["text"]
                    elif resp.status_code == 429 and use_search:
                        # Search quota exhausted, break model loop to switch to use_search=False immediately
                        print(f"Search tool quota exhausted on {model}, falling back to built-in medical knowledge...")
                        time.sleep(2.0)
                        break
                    elif resp.status_code == 429:
                        retry_after = int(resp.headers.get("Retry-After", 4))
                        pause = max(3.0, min(float(retry_after), 8.0))
                        print(f"Notice: Rate limit (429) hit on {model}, pausing {pause:.0f}s before fallback...")
                        time.sleep(pause)
                        continue
                    elif resp.status_code == 503:
                        # 503 Service Unavailable / High Demand: transient spike on Google infrastructure
                        print(f"Notice: Gemini {model} experiencing high demand (503). Pausing 4s before fallback...")
                        time.sleep(4.0)
                        continue
                    else:
                        print(f"Notice: Gemini {model} (search={use_search}) returned status {resp.status_code}: {resp.text[:120]}")
                        time.sleep(1.5)
                        continue
                except Exception as e:
                    print(f"Gemini {model} exception: {e}")
                    time.sleep(1.5)
                    continue

    raise RuntimeError("Failed to generate response across all Gemini models after multiple retry rounds.")


def load_courses_catalog(supabase: SupabaseClient) -> List[Dict[str, Any]]:
    """Loads courses catalog from Supabase, or falls back to local JSON catalog."""
    courses = []

    # 1. Try Supabase
    db_courses = supabase.get("courses", params={"select": "id,name,module_id,medical_modules(name,category)"})
    if db_courses:
        for c in db_courses:
            mod = c.get("medical_modules") or {}
            courses.append({
                "id": c["id"],
                "name": c["name"],
                "module_id": c.get("module_id"),
                "module_name": mod.get("name", "Médecine Générale"),
                "category": mod.get("category", "Médecine"),
            })
        print(f"Loaded {len(courses)} courses from Supabase database.")
        return courses

    # 2. Fallback to modules_catalog_47.json
    if CATALOG_FILE.exists():
        with open(CATALOG_FILE, "r", encoding="utf-8") as f:
            data = json.load(f)
            for mod in data:
                mod_name = mod.get("name", "")
                mod_cat = mod.get("category", "Médecine")
                for c in mod.get("courses", []):
                    courses.append({
                        "id": c["id"],
                        "name": c["name"],
                        "module_id": c.get("module_id", mod.get("id")),
                        "module_name": mod_name,
                        "category": mod_cat,
                    })
        print(f"Loaded {len(courses)} courses from local catalog ({CATALOG_FILE.name}).")
        return courses

    raise RuntimeError("Could not find courses in Supabase or local catalog file.")


def extract_clean_json(raw_text: str) -> Dict[str, Any]:
    """Cleans markdown JSON fences and extracts pure JSON dict."""
    cleaned = raw_text.strip()
    if cleaned.startswith("```json"):
        cleaned = cleaned[7:]
    elif cleaned.startswith("```"):
        cleaned = cleaned[3:]
    if cleaned.endswith("```"):
        cleaned = cleaned[:-3]
    cleaned = cleaned.strip()

    # Find first { and last }
    start = cleaned.find("{")
    end = cleaned.rfind("}")
    if start != -1 and end != -1:
        cleaned = cleaned[start : end + 1]

    return json.loads(cleaned)


def generate_clinical_protocol(
    course: Dict[str, Any],
    supabase: SupabaseClient,
    dry_run: bool = False,
) -> Optional[Dict[str, Any]]:
    """Generates a complete, structured Conduite à Tenir (CAT) for a specific course."""
    print(f"\n=======================================================")
    print(f"🏥 GENERATING CONDUITE À TENIR (CAT) : {course['name']}")
    print(f"📚 Spécialité : {course['module_name']} (ID: {course['id']})")
    print(f"=======================================================")

    system_prompt = """Tu es MedsinaPilot, l'assistant médical d'élite pour les praticiens hospitaliers et résidents en Algérie.
Ton rôle est de rédiger une Conduite à Tenir (CAT) clinique d'urgence ultra-précise, rigoureuse et directement actionnable.
Tu DOIS chercher et t'appuyer sur les recommandations et consensus les plus récents (HAS, ESC, GINA, GOLD, SFMU, SRLF, MSPRH Algérie 2024-2026).

RÈGLES STRICTES :
1. N'utilise AUCUN symbole LaTeX ($ ou $$ ou \\ge ou \\text{}). Utilise des symboles Unicode clairs: "≥", "≤", "±", "×", "µg", "°C", "mm", "mV", "bpm", "%".
2. Favorise les dénominations communes internationales (DCI) et les disponibilités hospitalières en Algérie (ex: Pharmacie Centrale des Hôpitaux PCH, Saidal, IPA pour les sérums antivenimeux).
3. La réponse DOIT ÊTRE UN OBJET JSON STRICT et valide, sans aucun texte introductif ni conclusion en dehors du JSON.

SCHEMA DU JSON :
{
  "id": "cat_identifiant_unique",
  "course_id": "id_du_cours",
  "title": "CAT devant [Titre Précis de la situation clinique ou d'urgence]",
  "specialty": "Nom de la Spécialité",
  "urgency_level": "Urgence Vitale" OU "Urgence Relative" OU "Prise en charge réglée",
  "definition": "Définition clinique concise, critères diagnostiques clés et délai de prise en charge",
  "red_flags": [
    "Signe de gravité 1 avec seuil clinique précis",
    "Signe de gravité 2",
    "Signe de gravité 3"
  ],
  "steps": [
    {
      "title": "1. Conditionnement immédiat & Monitorage",
      "content": "Résumé des gestes de stabilisation immédiate",
      "bulletPoints": [
        "Position du patient, oxygénation avec cible SpO2",
        "Abords veineux et prélèvements biologiques d'urgence",
        "Monitorage scope ECG, TA, diurèse"
      ]
    },
    {
      "title": "2. Bilan paraclinique d'urgence",
      "content": "Examens de première intention sans retarder le traitement",
      "bulletPoints": ["Examen 1", "Examen 2"]
    },
    {
      "title": "3. Protocole thérapeutique d'urgence",
      "content": "Traitement pharmacologique et étiologique de première ligne",
      "bulletPoints": [
        "Molécule A (DCI) : posologie exacte, dilution, voie et débit",
        "Molécule B (DCI) : posologie et surveillance"
      ]
    },
    {
      "title": "4. Surveillance & Critères d'orientation / Transfert",
      "content": "Évaluation de l'efficacité et orientation (Réanimation, Soins Intensifs, Hospitalisation)",
      "bulletPoints": ["Critère 1", "Critère 2"]
    }
  ],
  "treatments": [
    "DCI 1 + Posologie d'urgence (ex: Adrénaline 0,5 mg IM)",
    "DCI 2 + Posologie d'urgence",
    "Soluté d'expansion volémique"
  ],
  "scientific_references": "Consensus exact (ex: Recommandations ESC 2024 / HAS 2023 / Consensus National Algérien)",
  "guidelines_year": 2024
}
"""

    prompt = f"""Rédige la Conduite à Tenir (CAT) officielle et pratique pour le cours suivant du concours de résidanat :
- Nom du Cours : {course['name']}
- Module Médical : {course['module_name']}
- ID du Cours : {course['id']}

Recherche sur le web les consensus officiels et recommandations les plus récentes (2024-2026) pour cette pathologie.
Génère le JSON complet et structuré."""

    try:
        raw_response = call_gemini_api(prompt, system_prompt, enable_search=True)
    except Exception as e:
        print(f"❌ Erreur appel Gemini protocole CAT ({course['name']}): {e}")
        return None

    try:
        data = extract_clean_json(raw_response)
    except Exception as e:
        print(f"Error parsing JSON from Gemini: {e}\nRaw snippet:\n{raw_response[:400]}")
        return None

    # Ensure required fields
    data["course_id"] = course["id"]
    if not data.get("id"):
        data["id"] = f"cat_{course['id']}"
    if not data.get("specialty"):
        data["specialty"] = course["module_name"]

    print(f"Generated CAT: {data.get('title')} ({data.get('urgency_level')})")
    print(f"Steps: {len(data.get('steps', []))} | Treatments: {len(data.get('treatments', []))}")
    print(f"Ref: {data.get('scientific_references')}")

    if dry_run:
        print("\n[DRY RUN] Generated data snippet:")
        print(json.dumps(data, indent=2, ensure_ascii=False)[:800] + "...")
        try:
            from social_teaser_broadcaster import broadcast_content_teaser
            broadcast_content_teaser("cat", data, supabase=supabase, dry_run=True)
        except Exception as e:
            print(f"⚠️ Avertissement teaser dry-run (cat): {e}")
        return data

    # Write to Supabase
    res = supabase.post("clinical_protocols", data, upsert=True)
    if res:
        print(f"Successfully saved protocol '{data['id']}' to Supabase clinical_protocols!")
        send_broadcast_notification(
            supabase=supabase,
            notif_id=f"notif_cat_{data['id']}",
            title=f"🚨 Nouvelle CAT Clinique : {data.get('title', course['name'])}",
            message=f"La Conduite à Tenir officielle pour \"{course['name']}\" ({course['module_name']}) a été ajoutée aux Outils Pratiques Medsina !",
            notif_type="cat",
            target_id=data["id"],
            metadata={
                "protocol_id": data["id"],
                "course_id": course["id"],
                "module_name": course["module_name"],
                "urgency_level": data.get("urgency_level", "Urgence"),
            },
        )
    else:
        print("Notice: Protocol generated locally (Supabase write skipped or pending).")

    # Multichannel Social Teaser Broadcast (Facebook Blida, Facebook MedevSync, Telegram)
    try:
        from social_teaser_broadcaster import broadcast_content_teaser
        broadcast_content_teaser("cat", data, supabase=supabase, dry_run=dry_run)
    except Exception as e:
        print(f"⚠️ Avertissement diffusion teaser réseaux sociaux (CAT): {e}")

    return data


def generate_daily_pearl(
    course: Dict[str, Any],
    supabase: SupabaseClient,
    dry_run: bool = False,
) -> Optional[Dict[str, Any]]:
    """Generates a high-yield Daily Clinical Pearl & Residency Exam Trap for a specific course."""
    print(f"\n=======================================================")
    print(f"💡 GENERATING DAILY PEARL (Perle du Jour) : {course['name']}")
    print(f"📚 Spécialité : {course['module_name']}")
    print(f"=======================================================")

    system_prompt = """Tu es MedsinaPilot, l'assistant d'excellence pour le concours de résidanat de médecine en Algérie.
Ton rôle est d'extraire la « Perle Clinique & Piège de Concours » ultime pour un cours du programme.
La perle doit être percutante, mémorable, scientifiquement irréprochable et contenir :
1. Une règle d'or clinique indispensable en garde / pratique.
2. Le piège classique de QCM où tombent 80% des candidats au concours.
3. Un rappel mnémotechnique ou physiopathologique clair.
N'utilise JAMAIS de syntaxe LaTeX. Utilise du texte Unicode propre.
La réponse DOIT ÊTRE UN OBJET JSON STRICT.

SCHEMA JSON :
{
  "title": "Perle Clinique : [Nom percutant du sujet]",
  "course_id": "id_du_cours",
  "course_name": "Nom du Cours",
  "module_name": "Nom du Module",
  "pearl_text": "Explication claire en 2-3 phrases de la règle clinique et de sa justification clinique.",
  "vital_rule": "RÈGLE VITALE : [La règle absolue à ne jamais enfreindre]",
  "exam_trap": "PIÈGE DE CONCOURS : [La proposition fausse typique ou l'astuce de formulation piège]",
  "scientific_sources": "Consensus officiel ou cours de référence (ex: Collège ECN / HAS 2024 / ESC 2024)"
}
"""

    prompt = f"""Extrais la Perle Clinique et Piège de Concours pour :
- Cours : {course['name']}
- Module : {course['module_name']}
- ID : {course['id']}

Recherche les dernières recommandations pour garantir une précision absolue.
Génère le JSON complet."""

    try:
        raw_response = call_gemini_api(prompt, system_prompt, enable_search=True)
    except Exception as e:
        print(f"❌ Erreur appel Gemini perle ({course['name']}): {e}")
        return None

    try:
        data = extract_clean_json(raw_response)
    except Exception as e:
        print(f"Error parsing JSON from Gemini: {e}\nRaw snippet:\n{raw_response[:400]}")
        return None

    data["course_id"] = course["id"]
    data["course_name"] = course["name"]
    data["module_name"] = course["module_name"]
    data["module_id"] = course.get("module_id")
    data["created_at"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    data["is_active"] = True

    print(f"Generated Pearl: {data.get('title')}")
    print(f"Vital Rule: {data.get('vital_rule')}")
    print(f"Exam Trap: {data.get('exam_trap')}")

    if dry_run:
        print("\n[DRY RUN] Generated Pearl snippet:")
        print(json.dumps(data, indent=2, ensure_ascii=False)[:800] + "...")
        try:
            from social_teaser_broadcaster import broadcast_content_teaser
            broadcast_content_teaser("pearl", data, supabase=supabase, dry_run=True)
        except Exception as e:
            print(f"⚠️ Avertissement teaser dry-run (pearl): {e}")
        return data

    res = supabase.post("daily_pearls", data, upsert=False)
    if res:
        print("Successfully saved daily pearl to Supabase daily_pearls table!")
        pearl_id = data.get("id") or str(res.get("id", "")) if isinstance(res, dict) else ""
        send_broadcast_notification(
            supabase=supabase,
            notif_id=f"notif_pearl_{pearl_id or datetime.datetime.now().strftime('%Y%m%d%H%M')}",
            title=f"💡 Perle Clinique du Jour : {data.get('course_name', 'Medsina')}",
            message=f"{data.get('title', 'Nouvelle perle clinique')} : découvrez la règle vitale et le piège de concours du jour !",
            notif_type="pearl",
            target_id=str(pearl_id or data.get("course_id", "")),
            metadata={
                "course_id": data.get("course_id"),
                "course_name": data.get("course_name"),
                "module_name": data.get("module_name"),
            },
        )
    else:
        print("Notice: Daily pearl generated locally (Supabase write skipped or pending).")

    # Multichannel Social Teaser Broadcast (Facebook Blida, Facebook MedevSync, Telegram)
    try:
        from social_teaser_broadcaster import broadcast_content_teaser
        broadcast_content_teaser("pearl", data, supabase=supabase, dry_run=dry_run)
    except Exception as e:
        print(f"⚠️ Avertissement diffusion teaser réseaux sociaux (Pearl): {e}")

    return data


def pick_candidate_course_for_cat(
    courses: List[Dict[str, Any]],
    supabase: SupabaseClient,
    target_course_id: Optional[str] = None,
) -> Optional[Dict[str, Any]]:
    """Selects a course that DOES NOT ALREADY HAVE a clinical protocol (zero duplication)."""
    if target_course_id:
        match = next((c for c in courses if c["id"] == target_course_id), None)
        if match:
            return match
        print(f"Warning: Specified course ID '{target_course_id}' not found.")

    # Fetch existing protocol IDs and course_ids
    existing_protocols = supabase.get("clinical_protocols", params={"select": "id,course_id,title"})
    existing_ids = set()
    for p in existing_protocols:
        if p.get("id"):
            existing_ids.add(p["id"])
            # If id is 'cat_xxx', add 'xxx'
            if p["id"].startswith("cat_"):
                existing_ids.add(p["id"][4:])
        if p.get("course_id"):
            existing_ids.add(p["course_id"])

    print(f"Found {len(existing_protocols)} existing CAT protocols in database.")

    # Filter out courses with existing protocols
    candidates = [c for c in courses if c["id"] not in existing_ids and f"cat_{c['id']}" not in existing_ids]

    print(f"Remaining courses without CAT: {len(candidates)} / {len(courses)} total.")

    if not candidates:
        print("All courses already have a clinical protocol! Selecting at random for update.")
        return random.choice(courses) if courses else None

    # Prioritize emergency and medical modules (Cardio, Pneumo, Neuro, Infectieux, Urgences, Pédiatrie)
    priority_modules = {"Cardiologie", "Pneumologie", "Neurologie", "Maladies Infectieuses", "Pédiatrie", "Gastro-entérologie", "Urgences"}
    priority_candidates = [c for c in candidates if any(pm.lower() in c.get("module_name", "").lower() for pm in priority_modules)]

    chosen = random.choice(priority_candidates) if priority_candidates else random.choice(candidates)
    return chosen


def pick_candidate_course_for_pearl(
    courses: List[Dict[str, Any]],
    supabase: SupabaseClient,
    target_course_id: Optional[str] = None,
) -> Optional[Dict[str, Any]]:
    """Selects a course that was NOT used in recent daily pearls (zero duplicate in current cycle)."""
    if target_course_id:
        match = next((c for c in courses if c["id"] == target_course_id), None)
        if match:
            return match

    # Fetch recent pearls
    recent_pearls = supabase.get("daily_pearls", params={"select": "course_id", "order": "created_at.desc", "limit": "100"})
    recent_course_ids = {p["course_id"] for p in recent_pearls if p.get("course_id")}

    candidates = [c for c in courses if c["id"] not in recent_course_ids]
    if not candidates:
        candidates = courses

    return random.choice(candidates) if candidates else None



MASTER_EMERGENCY_DCI_POOL = [
    # Cardiovasculaire, Choc & Réanimation
    "Labetalol", "Esmolol", "Isoprénaline", "Dobutamine", "Nicardipine", "Urapidil", "Clonidine",
    "Amiodarone", "Atropine", "Trinitrine", "Dinitrate d'Isosorbide", "Diltiazem", "Vérapamil",
    "Digoxine", "Furosémide", "Milrinone", "Lévosimendan", "Métoprolol", "Propranolol",
    "Adrénaline", "Noradrénaline", "Éphédrine", "Nitroprussiate de sodium", "Adénosine",

    # Anti-infectieux & Sepsis sévère
    "Pipéracilline + Tazobactam", "Céfépime", "Imipénème + Cilastatine", "Méropénème",
    "Ceftriaxone", "Céfotaxime", "Vancomycine", "Teicoplanine", "Colistine", "Linézolide",
    "Amikacine", "Gentamicine", "Moxifloxacine", "Ciprofloxacine", "Lévofloxacine", "Métronidazole",
    "Aciclovir", "Fluconazole", "Voriconazole", "Amphotéricine B", "Co-trimoxazole", "Oseltamivir",
    "Tigécycline", "Fosfomycine injectable",

    # Anesthésie, Sédation, Analgésie & Neurologie
    "Propofol", "Étomidate", "Kétamine", "Midazolam", "Diazépam", "Clonazépam", "Phénytoïne",
    "Lévétiracétam", "Valproate de sodium", "Rocuronium", "Atracurium", "Cisatracurium",
    "Suxaméthonium", "Sugammadex", "Néostigmine", "Rémifentanil", "Sufentanil",
    "Fentanyl", "Morphine", "Fosphénytoïne", "Halopéridol", "Loxapine", "Mannitol 20%",
    "Chlorpromazine",

    # Antidotes, Toxicologie & Envenimations
    "Naloxone", "Flumazénil", "N-Acétylcystéine", "Pralidoxime", "Bleu de Méthylène",
    "Hydroxocobalamine", "Sérum Antivipérin", "Sérum Antiscorpionique", "Sérum Antitétanique",
    "Vitamine K1", "Sulfate de Protamine", "Gluconate de Calcium",
    "Chlorure de Calcium", "Émulsion lipidique (Intralipid)", "Glucagon", "Digifab",
    "Déféroxamine", "Physostigmine", "Charbon activé",

    # Pneumologie & Urgences Métaboliques
    "Salbutamol", "Terbutaline", "Bromure d'Ipratropium",
    "Méthylprednisolone", "Hydrocortisone", "Dexaméthasone", "Sulfate de Magnésium",
    "Insuline rapide", "Sérum Glucosé 30%", "Bicarbonate de sodium",
    "Chlorure de potassium (KCl)",

    # Hémostase, Gastro & Obstétrique
    "Acide Tranexamique", "Complexe Prothrombinique Humain (PPSB)",
    "Fibrinogène humain", "Facteur VIIa recombinant", "Desmopressine", "Enoxaparine",
    "Héparine non fractionnée (HNF)", "Fondaparinux", "Octréotide", "Somatostatine",
    "Terlipressine", "Ocytocine", "Carbétocine", "Sulprostone"
]


def pick_candidate_emergency_drug(supabase: SupabaseClient, target_dci: Optional[str] = None) -> Optional[str]:
    """Selects an emergency DCI that does not already exist in the database or local catalog.
    If all predefined candidates are indexed, dynamically discovers a new emergency molecule using Gemini."""
    if target_dci:
        return target_dci

    existing_names = set()
    # Check remote Supabase
    remote_drugs = supabase.get("emergency_drugs", params={"select": "id,dci"})
    for d in remote_drugs:
        if d.get("id"):
            existing_names.add(d["id"].lower())
        if d.get("dci"):
            existing_names.add(d["dci"].lower().strip())

    # Check local JSON
    if EMERGENCY_DRUGS_FILE.exists():
        try:
            local_drugs = json.loads(EMERGENCY_DRUGS_FILE.read_text(encoding="utf-8"))
            for d in local_drugs:
                if d.get("id"):
                    existing_names.add(d["id"].lower())
                if d.get("dci"):
                    existing_names.add(d["dci"].lower().strip())
        except Exception:
            pass

    def _normalize(s: str) -> str:
        return re.sub(r'[^a-z0-9]', '', s.lower())

    normalized_existing = {_normalize(n) for n in existing_names}

    candidates = [
        dci for dci in MASTER_EMERGENCY_DCI_POOL
        if _normalize(dci) not in normalized_existing and not any(_normalize(dci) in ex or ex in _normalize(dci) for ex in normalized_existing)
    ]

    print(f"Predefined emergency drug candidates remaining: {len(candidates)} / {len(MASTER_EMERGENCY_DCI_POOL)}.")

    if candidates:
        return random.choice(candidates)

    # Dynamic fallback: ask Gemini to propose an unindexed vital emergency molecule
    print("All predefined emergency drugs are already indexed! Dynamically querying Gemini for a new unindexed emergency drug...")
    prompt = (
        f"Donne le nom DCI d'une molécule d'urgence vitale, réanimation, anesthésie ou antidote utilisée en milieu hospitalier en Algérie qui ne figure PAS dans cette liste : {', '.join(sorted(list(existing_names))[:100])}.\n"
        "Réponds UNIQUEMENT par le nom de la molécule (DCI pure, 1 à 3 mots, sans aucun commentaire ni guillemets ni ponctuation)."
    )
    try:
        suggested = call_gemini_api(prompt, "Tu es pharmacologue hospitalier.", enable_search=False).strip().strip('"').strip("'")
        if suggested and len(suggested) > 2 and _normalize(suggested) not in normalized_existing:
            print(f"Gemini dynamically discovered new emergency molecule: {suggested}")
            return suggested
    except Exception as e:
        print(f"Notice querying Gemini for candidate drug: {e}")

    # Ultimate fallback: pick random candidate
    return random.choice(MASTER_EMERGENCY_DCI_POOL)


def generate_emergency_drug(dci_name: str, supabase: SupabaseClient, dry_run: bool = False) -> Optional[Dict[str, Any]]:
    """Generates an Algerian hospital emergency drug monograph strictly and authentically using Vidal.fr + Algerian Nomenclature."""
    print("=======================================================")
    print(f"💊 GENERATING EMERGENCY DRUG MONOGRAPH (STRICT VIDAL PRO): {dci_name}")
    print("=======================================================")

    try:
        from vidal_prescription_analyzer import VidalPrescriptionAnalyzer
        vidal_client = VidalPrescriptionAnalyzer()
    except Exception as e:
        print(f"⚠️ Erreur chargement VidalPrescriptionAnalyzer: {e}")
        vidal_client = None

    vidal_mono = None
    if vidal_client:
        vidal_mono = vidal_client.fetch_drug_monograph(dci_name, prefer_injectable=True)

    if not vidal_mono:
        print(f"❌ Refus de génération : Aucune monographie Vidal officielle trouvée pour '{dci_name}'.")
        print("💡 Conformité stricte : Seules les molécules certifiées par Vidal.fr peuvent être indexées.")
        return None

    # Load Algerian nomenclature for official MSPRH brands & laboratories
    algerian_nomen = None
    if ALGERIAN_NOMENCLATURE_FILE.exists():
        try:
            algerian_nomen = json.loads(ALGERIAN_NOMENCLATURE_FILE.read_text(encoding="utf-8"))
        except Exception as e:
            print(f"Notice reading algerian nomenclature: {e}")

    # Build drug record 100% strictly from Vidal data + Algerian Nomenclature
    data = vidal_client.format_as_emergency_drug(
        vidal_mono,
        dci_display_name=dci_name,
        algerian_nomenclature=algerian_nomen
    )

    data["created_at"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    data["updated_at"] = datetime.datetime.now(datetime.timezone.utc).isoformat()

    # Normalize availability key
    if "algerianAvailability" in data and "algerian_availability" not in data:
        data["algerian_availability"] = data.pop("algerianAvailability")
    if "algerian_availability" in data:
        data["algerianAvailability"] = data["algerian_availability"]

    print(f"Generated Drug (Vidal): {data.get('dci')} ({data.get('brand')})")
    print(f"Category: {data.get('category')} | Route: {data.get('route')}")

    if dry_run:
        print("[DRY RUN] Generated Drug snippet (Vidal):")
        print(json.dumps(data, indent=2, ensure_ascii=False)[:800] + "...")
        try:
            from social_teaser_broadcaster import broadcast_content_teaser
            broadcast_content_teaser("drug", data, supabase=supabase, dry_run=True)
        except Exception as e:
            print(f"⚠️ Avertissement teaser dry-run (drug): {e}")
        return data

    # 1. Save to remote Supabase (only pass table columns)
    supabase_record = {
        "id": data["id"],
        "dci": data.get("dci", dci_name),
        "brand": data.get("brand", "Disponible PCH / Hôpitaux"),
        "category": data.get("category", "Général"),
        "route": data.get("route", ""),
        "indication": data.get("indication", ""),
        "dose": data.get("dose", ""),
        "alert": data.get("alert", ""),
        "algerian_availability": data.get("algerian_availability", ""),
        "created_at": data["created_at"],
        "updated_at": data["updated_at"],
    }
    res = supabase.post("emergency_drugs", supabase_record, upsert=True)
    if res:
        print("Successfully saved drug to Supabase emergency_drugs table!")
        send_broadcast_notification(
            supabase=supabase,
            notif_id=f"notif_drug_{data['id']}",
            title=f"💊 Médicament d'Urgence : {data.get('dci', dci_name)}",
            message=f"La fiche posologique et vigilance pratique de \"{data.get('dci', dci_name)}\" (Vidal.fr) a été ajoutée au Codex Urgences !",
            notif_type="announcement",
            target_id=data["id"],
            metadata={
                "drug_id": data["id"],
                "dci": data.get("dci", dci_name),
                "brand": data.get("brand"),
                "category": data.get("category"),
            },
        )
    else:
        print("Notice: Drug generated locally (Supabase write skipped or pending).")

    # 2. Append/Update local JSON asset file
    if EMERGENCY_DRUGS_FILE.exists():
        try:
            local_list = json.loads(EMERGENCY_DRUGS_FILE.read_text(encoding="utf-8"))
            idx = next((i for i, d in enumerate(local_list) if d.get("id") == data["id"] or d.get("dci", "").lower() == data.get("dci", "").lower()), None)
            if idx is not None:
                local_list[idx] = data
                print(f"Updated existing drug '{data.get('dci')}' in local catalog.")
            else:
                local_list.append(data)
                print(f"Added NEW drug monograph '{data.get('dci')}' to local catalog (now {len(local_list)} total drugs)!")
            EMERGENCY_DRUGS_FILE.write_text(json.dumps(local_list, indent=2, ensure_ascii=False), encoding="utf-8")
        except Exception as e:
            print(f"Warning updating local drugs file: {e}")

    # Multichannel Social Teaser Broadcast (Facebook Blida, Facebook MedevSync, Telegram)
    try:
        from social_teaser_broadcaster import broadcast_content_teaser
        broadcast_content_teaser("drug", data, supabase=supabase, dry_run=dry_run)
    except Exception as e:
        print(f"⚠️ Avertissement diffusion teaser réseaux sociaux (Drug): {e}")

    return data

# 4. BIOLOGICAL LAB REFERENCE VALUES (NORMES BIOLOGIQUES)
# =============================================================================

MASTER_LAB_POOL = [
    "Troponine T et I hypersensible (hs-cTn)",
    "D-Dimères",
    "Procalcitonine (PCT)",
    "Gazométrie artérielle (pH, PaO2, PaCO2, HCO3-, SaO2)",
    "Ferritine sérique & Coefficient de Saturation de la Transferrine (CST)",
    "Transaminases ALAT et ASAT",
    "Lipase sérique",
    "Bilirubine totale, conjuguée et libre",
    "Phosphatases Alcalines (PAL) & Gamma-GT",
    "Urée sérique / sanguine",
    "Acide urique (Uricémie)",
    "Hémoglobine glyquée (HbA1c)",
    "Peptide Natriurétique BNP et NT-proBNP",
    "TSH ultrasensible (TSHus)",
    "T4 libre (FT4) et T3 libre (FT3)",
    "Magnésémie (Magnésium sérique)",
    "Phosphorémie (Phosphate inorganique)",
    "Lactates plasmatiques (Lactatémie artérielle / veineuse)",
    "Cholestérol total, HDL-C et calcul du LDL-C (Friedewald)",
    "Triglycérides sériques",
    "Protéinurie des 24h & Rapport Albuminurie/Créatininurie (RAC)",
    "Microalbuminurie",
    "Vitesse de Sédimentation (VS)",
    "Temps de Quick (TQ) et INR",
    "Temps de Céphaline Activée (TCA)",
    "Fibrinogène sérique",
    "Cortisol sérique à 8h",
    "Prolactine sérique",
    "Ammoniémie (Ammoniaque plasmatique)",
    "Créatine Phosphokinase totale (CPK)",
    "Calcémie corrigée & Calcium ionisé",
    "Électrophorèse des protéines sériques (EPS) & Pic monoclonal",
    "Bêta-HCG plasmatique quantitative",
    "Antigène Spécifique de la Prostate (PSA total et libre)",
    "Facteur Rhumatoïde (FR) & Anticorps Anti-CCP (ACPA)",
    "Anticorps Anti-Nucléaires (AAN / ANA)",
    "Complément sérique C3 et C4",
    "Vitamines B12 et Folates (Vitamine B9)",
    "Vitamine D (25-OH-Vitamine D3)",
    "Osmolalité plasmatique & Trou osmotique",
    "Analyse cytochimique du Liquide Céphalo-Rachidien (LCR)",
    "Ponction et analyse du Liquide d'Ascite (Gradient SAAG & PNN)",
    "Ponction pleurale : Critères de Light (Exsudat vs Transsudat)",
    "Analyse du Liquide Articulaire (Synovial) : Mécanique, Inflammatoire, Septique, Microcristallin",
    "Ionogramme urinaire (Natriurèse, Kaliurèse, Rapport Na/K urinaire)",
    "Trou anionique plasmatique et Trou anionique urinaire",
    "Haptoglobine, LDH et Bilirubine libre (Bilan d'hémolyse)",
    "Numération des Réticulocytes (Anémie régénérative vs arégénérative)",
    "Test de Coombs direct (Test direct à l'antiglobuline)",
    "Frottis sanguin périphérique : Schizocytes et Microangiopathie Thrombotique (MAT)",
    "Albumine sérique et Préalbumine (Bilan nutritionnel)",
    "Parathormone intacte (PTH) et Bilan phosphocalcique",
    "Aldostérone plasmatique, Rénine active et Rapport Aldostérone/Rénine",
    "Métanéphrines et Normétanéphrines urinaires / plasmatiques (Phéochromocytome)",
    "Cortisol libre urinaire des 24h (CLU) et Freinage minute à la Dexaméthasone",
    "ACTH plasmatique (Corticotrophine)",
    "Peptide C et Insulinémie à jeun (Indice HOMA-IR)",
    "Anticorps anti-Transglutaminase IgA et IgG (Maladie cœliaque)",
    "ANCA (Anti-PR3 et Anti-MPO) — Vascularites à ANCA",
    "Anticorps Anti-Phospholipides (Lupus anticoagulant, Anti-Cardiolipine, Anti-Bêta2GP1)",
    "Anticorps Anti-récepteurs de la TSH (TRAK) et Anti-TPO",
    "Alpha-Fœtoprotéine (AFP) sérique",
    "CA 125, CA 19-9, CA 15-3 et ACE (Antigène Carcino-Embryonnaire)",
    "Bêta-2-Microglobuline sérique",
    "Calcitonine sérique (Cancer médullaire de la thyroïde)",
    "Fer sérique, Transferrine et Capacité Totale de Fixation de la Transferrine (CTFT)",
    "G6PD érythrocytaire (Déficit en Glucose-6-Phosphate Déshydrogénase)",
    "Électrophorèse de l'Hémoglobine (Drépanocytose et Thalassémies)",
    "Facteurs de la coagulation (Facteur V, Facteur VIII, Facteur Willebrand)",
    "Antithrombine III, Protéine C et Protéine S (Bilan de thrombophilie)",
    "Dosage de la Digoxinémie (Suivi thérapeutique pharmacologique)",
    "Dosage de la Lithiumémie (Suivi thérapeutique du Lithium)",
    "Paracétamolémie et Nomogramme de Rumack-Matthew",
    "Salicylémie (Intoxication à l'Aspirine)",
    "Carboxyhémoglobine (HbCO — Intoxication au Monoxyde de Carbone)",
    "Méthémoglobinémie (MetHb)",
    "Cholinestérases plasmatiques et érythrocytaires (Intoxication aux Organophosphorés)",
    "Calprotectine fécale (MICI vs Troubles fonctionnels intestinaux)",
    "Clairance fécale de l'Alpha-1-Antitrypsine (Entéropathie exsudative)",
    "Élastase fécale pancréatique (Insuffisance pancréatique exocrine)",
    "Céruloplasmine et Cuprémie / Cuprurie des 24h (Maladie de Wilson)",
    "Alpha-1-Antitrypsine sérique (Déficit en A1AT)",
    "Enzyme de Conversion de l'Angiotensine (ECA sérique — Sarcoïdose)",
    "Cryoglobulinémie (Recherche et typage des Cryoglobulines)",
    "Quantiféron-TB Gold (IGRA — Tuberculose latente)",
    "Sérologie Hépatite B complète (Ag HBs, Ac anti-HBs, Ac anti-HBc, Ag HBe, ADN VHB)",
    "Pro-ADM et Interleukine-6 (IL-6) dans le Sepsis",
    "Myoglobine sérique et urinaire (Rhabdomyolyse aiguë)",
    "Troponine et NT-proBNP dans l'Embolie Pulmonaire (Stratification du risque ESC)",
    "Gazométrie du sang veineux mêlé (SvO2) et sang veineux central (ScvO2)",
]


def pick_candidate_lab_value(supabase: SupabaseClient, target_lab: Optional[str] = None) -> Optional[str]:
    """Selects a biological parameter that does not already exist in the database or local catalog."""
    if target_lab:
        return target_lab

    existing_names = set()
    # Check remote Supabase
    remote_labs = supabase.get("lab_reference_values", params={"select": "id,name"})
    for l in remote_labs:
        if l.get("id"):
            existing_names.add(l["id"].lower())
        if l.get("name"):
            existing_names.add(l["name"].lower().strip())

    # Check local JSON
    if LAB_VALUES_FILE.exists():
        try:
            local_labs = json.loads(LAB_VALUES_FILE.read_text(encoding="utf-8"))
            for l in local_labs:
                if l.get("id"):
                    existing_names.add(l["id"].lower())
                if l.get("name"):
                    existing_names.add(l["name"].lower().strip())
        except Exception:
            pass

    def _normalize(s: str) -> str:
        return re.sub(r'[^a-z0-9]', '', s.lower())

    normalized_existing = {_normalize(n) for n in existing_names}

    candidates = [
        lab for lab in MASTER_LAB_POOL
        if _normalize(lab) not in normalized_existing and not any(_normalize(lab) in ex or ex in _normalize(lab) for ex in normalized_existing)
    ]

    print(f"Predefined lab reference value candidates remaining: {len(candidates)} / {len(MASTER_LAB_POOL)}.")

    if candidates:
        return random.choice(candidates)

    # Dynamic fallback: ask Gemini to propose a new unindexed biological parameter
    print("All predefined lab values are already indexed! Dynamically querying Gemini for a new unindexed lab test...")
    prompt = (
        f"Donne le nom exact d'un examen biologique hospitalier, bilan d'urgence, marqueur spécialisé ou ponction de liquide biologique utile au concours de résidanat et en garde médicale qui ne figure PAS dans cette liste : {', '.join(sorted(list(existing_names))[:100])}.\n"
        "Réponds UNIQUEMENT par le nom de l'examen biologique (2 à 6 mots maximum, sans aucun commentaire ni guillemets)."
    )
    try:
        suggested = call_gemini_api(prompt, "Tu es biologiste médical hospitalier.", enable_search=False).strip().strip('"').strip("'")
        if suggested and len(suggested) > 2 and _normalize(suggested) not in normalized_existing:
            print(f"Gemini dynamically discovered new lab parameter: {suggested}")
            return suggested
    except Exception as e:
        print(f"Notice querying Gemini for candidate lab value: {e}")

    return random.choice(MASTER_LAB_POOL)


def generate_lab_value(lab_name: str, supabase: SupabaseClient, dry_run: bool = False) -> Optional[Dict[str, Any]]:
    """Generates an Algerian residency / clinical lab reference value monograph using Gemini Grounding."""
    print(f"\n=======================================================")
    print(f"🧪 GENERATING LAB REFERENCE VALUE: {lab_name}")
    print(f"=======================================================")

    system_prompt = """Tu es MedsinaPilot, biologiste médical hospitalier et réanimateur expert en médecine interne en Algérie.
Ton rôle est de créer une fiche de valeur biologique de référence hyper-précise et adaptée aux candidats au concours de résidanat et aux médecins internes/résidents hospitaliers algériens.
La fiche doit être claire, immédiatement exploitable au laboratoire et au lit du malade, et scientifiquement irréprochable (Consensus internationaux, SFBC, HAS, MSPRH Algérie).

Format JSON STRICT attendu :
{
  "id": "lab_nom_sans_accents",
  "name": "Nom de l'examen biologique exact (avec abréviation usuelle)",
  "category": "Catégorie biologique",
  "normal_range": "Plage physiologique normale (ex: 3.5 - 5.0 ou Homme: ... | Femme: ...)",
  "unit": "Unité de mesure usuelle (ex: mmol/L, g/L, UI/L, µmol/L)",
  "high_interpretation": "Interprétation clinique si valeur élevée (causes fréquentes, seuil d'urgence vitale, conduite à tenir immédiate)",
  "low_interpretation": "Interprétation clinique si valeur basse (causes fréquentes, seuil d'urgence vitale, conduite à tenir immédiate)",
  "clinical_notes": [
    "Point de vigilance pré-analytique ou piège diagnostique (ex: fausse hyperkaliémie par hémolyse)",
    "Règle de correction ou calcul associé indispensable au concours / lit du malade"
  ]
}
Catégories autorisées : "Ionogramme & Rein", "Hématologie & Hémostase", "Cardiologie & Vasculaire", "Hépato-Gastro & Pancréas", "Endocrinologie & Métabolisme", "Infectiologie & Inflammation", "Gazométrie & Équilibre Acido-Basique", "Immunologie & Rhumatologie", "Vitamines & Oligo-éléments", "Marqueurs Tumoraux & Toxicologie".
N'utilise AUCUNE balise Markdown dans ta réponse brute, juste le JSON pur.
"""

    prompt = f"""Rédige la fiche de référence biologique complète pour l'examen : {lab_name}.
Fournis les normes usuelles exactes, les causes et seuils critiques d'urgence pour les valeurs hautes et basses, ainsi que 2 à 3 perles cliniques ou pièges fréquents du concours de résidanat."""

    try:
        raw_response = call_gemini_api(prompt, system_prompt, enable_search=True)
    except Exception as e:
        print(f"❌ Erreur appel Gemini norme biologique ({lab_name}): {e}")
        return None
    try:
        data = extract_clean_json(raw_response)
    except Exception as e:
        print(f"Error parsing JSON from Gemini: {e}\nRaw snippet:\n{raw_response[:400]}")
        return None

    if not data.get("id"):
        clean_id = re.sub(r'[^a-zA-Z0-9]', '_', lab_name.lower()).strip('_')
        data["id"] = f"lab_{clean_id}"

    data["created_at"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    data["updated_at"] = datetime.datetime.now(datetime.timezone.utc).isoformat()

    print(f"Generated Lab Value: {data.get('name')}")
    print(f"Normal Range: {data.get('normal_range')} {data.get('unit')} | Category: {data.get('category')}")

    if dry_run:
        print("\n[DRY RUN] Generated Lab snippet:")
        print(json.dumps(data, indent=2, ensure_ascii=False)[:800] + "...")
        try:
            from social_teaser_broadcaster import broadcast_content_teaser
            broadcast_content_teaser("lab", data, supabase=supabase, dry_run=True)
        except Exception as e:
            print(f"⚠️ Avertissement teaser dry-run (lab): {e}")
        return data

    # 1. Save to remote Supabase (only columns present in lab_reference_values table)
    valid_lab_cols = {"id", "name", "category", "normal_range", "unit", "high_interpretation", "low_interpretation", "clinical_notes"}
    db_lab_payload = {k: v for k, v in data.items() if k in valid_lab_cols}
    res = supabase.post("lab_reference_values", db_lab_payload, upsert=True)
    if res:
        print("Successfully saved lab value to Supabase lab_reference_values table!")
        send_broadcast_notification(
            supabase=supabase,
            notif_id=f"notif_lab_{data['id']}",
            title=f"🧪 Normes Biologiques : {data.get('name', lab_name)}",
            message=f"La fiche de référence biologique pour \"{data.get('name', lab_name)}\" ({data.get('normal_range', '')} {data.get('unit', '')}) est disponible sur Medsina !",
            notif_type="announcement",
            target_id=data["id"],
            metadata={
                "lab_id": data["id"],
                "name": data.get("name", lab_name),
                "category": data.get("category"),
            },
        )
    else:
        print("Notice: Lab value generated locally (Supabase write skipped or pending).")

    # 2. Append/Update local JSON asset file
    if LAB_VALUES_FILE.exists():
        try:
            local_list = json.loads(LAB_VALUES_FILE.read_text(encoding="utf-8"))
            idx = next((i for i, d in enumerate(local_list) if d.get("id") == data["id"] or d.get("name", "").lower() == data.get("name", "").lower()), None)
            if idx is not None:
                local_list[idx] = data
            else:
                local_list.append(data)
            LAB_VALUES_FILE.write_text(json.dumps(local_list, indent=2, ensure_ascii=False), encoding="utf-8")
            print(f"Updated local {LAB_VALUES_FILE.name} ({len(local_list)} total lab values)!")
        except Exception as e:
            print(f"Warning updating local lab values file: {e}")

    # Multichannel Social Teaser Broadcast (Facebook Blida, Facebook MedevSync, Telegram)
    try:
        from social_teaser_broadcaster import broadcast_content_teaser
        broadcast_content_teaser("lab", data, supabase=supabase, dry_run=dry_run)
    except Exception as e:
        print(f"⚠️ Avertissement diffusion teaser réseaux sociaux (Lab): {e}")

    return data


# =============================================================================
# 5. ON-CALL MEMENTOS (MÉMENTO DE GARDE HOSPITALIÈRE)
# =============================================================================

MASTER_MEMENTO_POOL = [
    "État de Mal Épileptique / Convulsions Aiguës de l'Adulte",
    "OAP Flash Hypertensif et Crise Aiguë Hypertensive",
    "Hémorragie Digestive Haute par Rupture de Varices Œsophagiennes",
    "Pneumothorax Spontané Compressif sous Tension",
    "Accident d'Exposition au Sang et Liquides Biologiques (AES)",
    "Malaise et Syncope aux Urgences — Algorithme Diagnostique",
    "Rétention Aiguë d'Urine (Globe Vésical) en Urgence",
    "Transfusion d'Urgence Vitale & Choc Hémorragique Massif",
    "Pancréatite Aiguë — Tri et Prise en Charge Initiale",
    "Syndrome Méningé Aigu & Indication de la Ponction Lombaire",
    "Hyperkaliémie Aiguë avec Menace ECG Immédiate",
    "Acidocétose Diabétique de l'Adulte — Réanimation Métabolique",
    "Syndrome Coronarien Aigu sans Élévation du Segment ST (SCA non ST+)",
    "Asthme Aigu Grave (AAG) aux Urgences",
    "Arrêt Cardio-Respiratoire (ACR) de l'Adulte — Réanimation Spécialisée",
    "Intoxication Médicamenteuse Aiguë Poly-médicamenteuse",
    "Traumatisme Crânien Léger à Modéré — Critères de Scanner",
    "Pédiatrie : Convulsion Fébrilée et État de Mal Pédiatrique",
    "Pédiatrie : Déshydratation Aiguë et Réhydratation IV",
    "Pédiatrie : Bronchiolite Aiguë du Nourrisson aux Urgences",
    "Ischémie Aiguë de Membre Inférieur — Urgence Vasculaire",
    "Morsures de Vipère en Algérie — Conduite Clinique et Antivenin",
    "Choc Anaphylactique — Adrénaline Immédiate et Surveillance",
    "Métrorragies du Premier Trimestre et Suspicion de GEU",
    "Colique Néphrétique Hyperalgique et Fébrilée",
]


def pick_candidate_on_call_memento(supabase: SupabaseClient, target_memento: Optional[str] = None) -> Optional[str]:
    """Selects an on-call memento topic that does not already exist in the database or local catalog."""
    if target_memento:
        return target_memento

    existing_titles = set()
    # Check remote Supabase
    remote_mementos = supabase.get("on_call_mementos", params={"select": "id,title"})
    for m in remote_mementos:
        if m.get("id"):
            existing_titles.add(m["id"].lower())
        if m.get("title"):
            existing_titles.add(m["title"].lower().strip())

    # Check local JSON
    if ON_CALL_MEMENTOS_FILE.exists():
        try:
            local_mementos = json.loads(ON_CALL_MEMENTOS_FILE.read_text(encoding="utf-8"))
            for m in local_mementos:
                if m.get("id"):
                    existing_titles.add(m["id"].lower())
                if m.get("title"):
                    existing_titles.add(m["title"].lower().strip())
        except Exception:
            pass

    def _normalize(s: str) -> str:
        return re.sub(r'[^a-z0-9]', '', s.lower())

    normalized_existing = {_normalize(t) for t in existing_titles}

    candidates = [
        topic for topic in MASTER_MEMENTO_POOL
        if _normalize(topic) not in normalized_existing and not any(_normalize(topic) in ex or ex in _normalize(topic) for ex in normalized_existing)
    ]

    print(f"Predefined on-call memento candidates remaining: {len(candidates)} / {len(MASTER_MEMENTO_POOL)}.")

    if candidates:
        return random.choice(candidates)

    # Dynamic fallback: ask Gemini to propose a new unindexed on-call clinical emergency topic
    print("All predefined on-call mementos are already indexed! Dynamically querying Gemini for a new unindexed on-call topic...")
    prompt = (
        f"Donne le titre exact d'une situation d'urgence médicale ou chirurgicale de garde hospitalière (UMC, Réanimation, Pédiatrie, Gynécologie-Obstétrique, Cardiologie) qui ne figure PAS dans cette liste : {', '.join(sorted(list(existing_titles))[:100])}.\n"
        "Réponds UNIQUEMENT par le titre concis de la situation clinique (3 à 8 mots, sans guillemets ni commentaires)."
    )
    try:
        suggested = call_gemini_api(prompt, "Tu es chef de garde aux urgences médico-chirurgicales.", enable_search=False).strip().strip('"').strip("'")
        if suggested and len(suggested) > 4 and _normalize(suggested) not in normalized_existing:
            print(f"Gemini dynamically discovered new on-call memento topic: {suggested}")
            return suggested
    except Exception as e:
        print(f"Notice querying Gemini for candidate memento: {e}")

    return random.choice(MASTER_MEMENTO_POOL)


def generate_on_call_memento(memento_title: str, supabase: SupabaseClient, dry_run: bool = False) -> Optional[Dict[str, Any]]:
    """Generates an Algerian hospital on-call reflex protocol sheet using Gemini Grounding."""
    print(f"\n=======================================================")
    print(f"🌙 GENERATING ON-CALL MEMENTO PROTOCOL: {memento_title}")
    print(f"=======================================================")

    system_prompt = """Tu es MedsinaPilot, médecin chef de garde des urgences médico-chirurgicales (UMC) et réanimateur en Algérie.
Ton rôle est de créer une fiche réflexe pour le « Mémento de Garde Hospitalière », destinée aux internes et résidents assurant la garde hospitalière de nuit.
La fiche doit être ultra-synthétique, immédiatement opérationnelle au lit du malade au déchoquage, et scientifiquement irréprochable (SFMU, SRLF, ESC, Consensus Nationaux Algériens).

Format JSON STRICT attendu :
{
  "id": "memento_nom_sans_accents",
  "title": "Titre percutant avec emoji (ex: ⚡ Titre du Protocole)",
  "category": "Catégorie de la garde",
  "icon_name": "nom_icone_materiel",
  "color_hex": "#HEX_COULEUR",
  "priority_level": 1,
  "points": [
    "Étape 1 : geste immédiat, évaluation initiale ou élimination d'une urgence vitale",
    "Étape 2 : examens paracliniques urgents à prélever au lit du malade",
    "Étape 3 : thérapeutique d'urgence de 1ère intention avec posologies précises",
    "Étape 4 : surveillance armée, critères de gravité imposant le transfert en réanimation",
    "Étape 5 : piège médico-légal ou contre-indication absolue en situation d'urgence"
  ],
  "scientific_references": "Consensus SFMU / SRLF / Collège de Réanimation / MSPRH Algérie"
}

Noms d'icônes valides autorisés :
"checklist_rounded", "description_rounded", "bolt_rounded", "air_rounded", "favorite_border_rounded", "emergency_rounded", "medication_liquid_rounded", "biotech_rounded", "pregnant_woman_rounded", "child_care_rounded", "psychology_rounded", "local_fire_department_rounded", "bug_report_rounded", "health_and_safety_rounded", "healing_rounded", "warning_rounded".

priority_level :
1 = Urgence vitale extrême (rouge/orange foncé)
2 = Vigilance accrue / Protocole standard (bleu/cyan/violet)
3 = Bonne pratique & organisationnelle (vert/teal)

Couleurs recommandées (color_hex) :
"#EF4444" (Rouge alerte), "#DC2626" (Rouge sombre), "#F59E0B" (Ambre urgence), "#0284C7" (Bleu ciel), "#2563EB" (Bleu roi), "#7C3AED" (Violet), "#0D9488" (Teal/Vert d'eau), "#059669" (Émeraude), "#EA580C" (Orange vif).

N'utilise AUCUNE balise Markdown dans ta réponse brute, juste le JSON pur.
"""

    prompt = f"""Rédige la fiche réflexe de garde d'urgence pour : {memento_title}.
Rédige entre 4 et 6 points réflexes numérotés ou ordonnés par ordre chronologique d'intervention, avec les posologies exactes adaptées à la pratique hospitalière en Algérie."""

    try:
        raw_response = call_gemini_api(prompt, system_prompt, enable_search=True)
    except Exception as e:
        print(f"❌ Erreur appel Gemini mémento ({memento_title}): {e}")
        return None
    try:
        data = extract_clean_json(raw_response)
    except Exception as e:
        print(f"Error parsing JSON from Gemini: {e}\nRaw snippet:\n{raw_response[:400]}")
        return None

    if not data.get("id"):
        clean_id = re.sub(r'[^a-zA-Z0-9]', '_', memento_title.lower()).strip('_')
        data["id"] = f"memento_{clean_id}"

    data["is_active"] = True
    data["created_at"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    data["updated_at"] = datetime.datetime.now(datetime.timezone.utc).isoformat()

    print(f"Generated Memento: {data.get('title')}")
    print(f"Category: {data.get('category')} | Priority: {data.get('priority_level')}")

    if dry_run:
        print("\n[DRY RUN] Generated Memento snippet:")
        print(json.dumps(data, indent=2, ensure_ascii=False)[:800] + "...")
        try:
            from social_teaser_broadcaster import broadcast_content_teaser
            broadcast_content_teaser("memento", data, supabase=supabase, dry_run=True)
        except Exception as e:
            print(f"⚠️ Avertissement teaser dry-run (memento): {e}")
        return data

    # 1. Save to remote Supabase
    res = supabase.post("on_call_mementos", data, upsert=True)
    if res:
        print("Successfully saved memento to Supabase on_call_mementos table!")
        send_broadcast_notification(
            supabase=supabase,
            notif_id=f"notif_memento_{data['id']}",
            title=f"📋 Mémento de Garde : {data.get('title', memento_title)}",
            message=f"Nouveau mémento pratique de garde disponible : \"{data.get('title', memento_title)}\" ({data.get('category', 'Urgences')}) !",
            notif_type="announcement",
            target_id=data["id"],
            metadata={
                "memento_id": data["id"],
                "title": data.get("title", memento_title),
                "category": data.get("category"),
            },
        )
    else:
        print("Notice: Memento generated locally (Supabase write skipped or pending).")

    # 2. Append/Update local JSON asset file
    if ON_CALL_MEMENTOS_FILE.exists():
        try:
            local_list = json.loads(ON_CALL_MEMENTOS_FILE.read_text(encoding="utf-8"))
            idx = next((i for i, d in enumerate(local_list) if d.get("id") == data["id"] or d.get("title", "").lower() == data.get("title", "").lower()), None)
            if idx is not None:
                local_list[idx] = data
            else:
                local_list.append(data)
            ON_CALL_MEMENTOS_FILE.write_text(json.dumps(local_list, indent=2, ensure_ascii=False), encoding="utf-8")
            print(f"Updated local {ON_CALL_MEMENTOS_FILE.name} ({len(local_list)} total on-call mementos)!")
        except Exception as e:
            print(f"Warning updating local mementos file: {e}")

    # Multichannel Social Teaser Broadcast (Facebook Blida, Facebook MedevSync, Telegram)
    try:
        from social_teaser_broadcaster import broadcast_content_teaser
        broadcast_content_teaser("memento", data, supabase=supabase, dry_run=dry_run)
    except Exception as e:
        print(f"⚠️ Avertissement diffusion teaser réseaux sociaux (Memento): {e}")

    return data


def pick_candidate_course_for_summary(
    courses: List[Dict[str, Any]],
    supabase: SupabaseClient,
    target_course_id: Optional[str] = None,
) -> Optional[Dict[str, Any]]:
    """Selects a course that DOES NOT ALREADY HAVE a summary (zero duplicate)."""
    if target_course_id:
        match = next((c for c in courses if c["id"] == target_course_id), None)
        if match:
            return match
        print(f"Warning: Specified course ID '{target_course_id}' not found.")

    # 1. Existing IDs from Supabase
    existing_summaries = supabase.get("course_summaries", params={"select": "course_id"})
    existing_ids = {s["course_id"] for s in existing_summaries if s.get("course_id")}

    # 2. Existing IDs from local JSON file
    if COURSE_SUMMARIES_FILE.exists():
        try:
            local_list = json.loads(COURSE_SUMMARIES_FILE.read_text(encoding="utf-8"))
            for item in local_list:
                if item.get("course_id"):
                    existing_ids.add(item["course_id"])
        except Exception as e:
            print(f"Warning reading local course summaries: {e}")

    print(f"Found {len(existing_ids)} existing course summaries.")

    candidates = [c for c in courses if c["id"] not in existing_ids]
    print(f"Remaining courses without summary: {len(candidates)} / {len(courses)} total.")

    if not candidates:
        print("All courses already summarized! Selecting at random for update.")
        return random.choice(courses) if courses else None

    # Prioritize clinical modules for the residency exam
    priority_modules = {
        "Cardiologie", "Pneumologie", "Neurologie", "Gastro-entérologie",
        "Néphrologie", "Infectieux", "Pédiatrie", "Endocrinologie",
        "Hématologie", "Gynécologie", "Urgences", "Psychiatrie", "Rhumatologie"
    }
    priority_candidates = [
        c for c in candidates
        if any(pm.lower() in c.get("module_name", "").lower() for pm in priority_modules)
    ]

    chosen = random.choice(priority_candidates) if priority_candidates else random.choice(candidates)
    return chosen


def generate_course_summary(
    course: Dict[str, Any],
    supabase: SupabaseClient,
    dry_run: bool = False,
) -> Optional[Dict[str, Any]]:
    """Generates an academic, high-yield Course Summary for the Algerian Residency Concours."""
    print(f"\n=======================================================")
    print(f"📖 GENERATING COURSE SUMMARY (Fiche Résumé) : {course['name']}")
    print(f"📚 Spécialité : {course['module_name']} (ID: {course['id']})")
    print(f"=======================================================")

    system_prompt = """Tu es MedsinaPilot, l'assistant médical d'excellence pour la préparation du Concours de Résidanat de Médecine en Algérie (Alger, Blida, Constantine, Oran).
Ton rôle est de générer une FICHE SYNTHÉTIQUE DE COURS ULTRA-COMPLÈTE, structurée, rigoureuse et orientée QCM.
Tu dois t'appuyer sur les cours officiels de résidanat et les derniers consensus médicaux internationaux et algériens (HAS, ESC, GINA, GOLD, SFMU, MSPRH).

STRUCTURE DE LA FICHE :
La fiche doit contenir un texte Markdown complet divisé en sections claires :
1. Définition & Physiopathologie essentielle
2. Démarche Diagnostique (Clinique, Paraclinique de référence, Critères diagnostiques)
3. Diagnostic Différentiel & Formes Cliniques
4. Stratégie Thérapeutique (Mesures générales, Traitement de 1ère et 2ème ligne, DCI, Contre-indications)
5. Évolution, Pronostic & Complications majeures

La réponse DOIT ÊTRE UN OBJET JSON STRICT respectant scrupuleusement ce schéma :
{
  "course_id": "id_du_cours",
  "course_name": "Nom exact du cours",
  "module_id": "id_du_module",
  "module_name": "Nom du module / spécialité",
  "summary_markdown": "Texte markdown riche et soigné, avec titres h2 (##), listes à puces, mise en gras des mots-clés et valeurs chiffrées importantes pour le concours.",
  "key_takeaways": [
    "Point clé 1 incontournable pour le concours",
    "Point clé 2...",
    "Point clé 3...",
    "Point clé 4...",
    "Point clé 5..."
  ],
  "exam_traps": [
    "Piège Annales : formulation classique vicieuse ou fausse proposition type des annales",
    "Piège Traitement : contre-indication ou erreur de prescription éliminatoire",
    "Piège Diagnostic : signe à ne jamais confondre"
  ],
  "diagnostic_criteria": "Résumé en 1-2 phrases des critères formels de diagnostic positif",
  "treatment_summary": "Résumé en 1-2 phrases de la ligne thérapeutique de référence et des urgences",
  "target_audience": "Concours Résidanat 2027"
}

N'utilise AUCUNE balise LaTeX. Utilise du texte Unicode pur (ex: ≥, ≤, µg, ², →).
Réponds UNIQUEMENT par le JSON pur sans texte avant ni après.
"""

    prompt = f"""Rédige la Fiche Synthétique de Révision officielle pour :
- Nom du cours : {course['name']}
- Module : {course['module_name']}
- ID du cours : {course['id']}

Fournis une fiche médicale approfondie d'au moins 5 sections avec des points clés à haut rendement pour réussir les QCM du résidanat."""

    try:
        raw_response = call_gemini_api(prompt, system_prompt, enable_search=True)
    except Exception as e:
        print(f"❌ Erreur appel Gemini résumé cours ({course['name']}): {e}")
        return None
    try:
        data = extract_clean_json(raw_response)
    except Exception as e:
        print(f"Error parsing JSON from Gemini: {e}\nRaw snippet:\n{raw_response[:400]}")
        return None

    data["course_id"] = course["id"]
    data["course_name"] = course["name"]
    data["module_id"] = course.get("module_id")
    data["module_name"] = course["module_name"]
    data["target_audience"] = "Concours Résidanat 2027"
    data["updated_at"] = datetime.datetime.now(datetime.timezone.utc).isoformat()

    print(f"Generated Summary for: {data.get('course_name')}")
    print(f"Key Takeaways count: {len(data.get('key_takeaways', []))}")
    print(f"Exam Traps count: {len(data.get('exam_traps', []))}")

    if dry_run:
        print("\n[DRY RUN] Generated Course Summary snippet:")
        print(json.dumps(data, indent=2, ensure_ascii=False)[:800] + "...")
        try:
            from social_teaser_broadcaster import broadcast_content_teaser
            broadcast_content_teaser("summary", data, supabase=supabase, dry_run=True)
        except Exception as e:
            print(f"⚠️ Avertissement teaser dry-run (summary): {e}")
        return data

    # 1. Save to Supabase
    res = supabase.post("course_summaries", data, upsert=True)
    if res:
        print("Successfully saved course summary to Supabase course_summaries table!")
        send_broadcast_notification(
            supabase=supabase,
            notif_id=f"notif_summary_{data['course_id']}",
            title=f"📖 Nouvelle Fiche Synthèse : {data['course_name']}",
            message=f"La fiche de révision officielle du cours \"{data['course_name']}\" (Module {data['module_name']}) est disponible sur Medsina avec points clés et pièges de concours !",
            notif_type="course",
            target_id=data["course_id"],
            metadata={
                "course_id": data["course_id"],
                "course_name": data["course_name"],
                "module_id": data["module_id"],
                "module_name": data["module_name"],
            },
        )
    else:
        print("Notice: Summary generated locally (Supabase write skipped or pending).")

    # 2. Append/Update local JSON asset file
    if COURSE_SUMMARIES_FILE.exists():
        try:
            local_list = json.loads(COURSE_SUMMARIES_FILE.read_text(encoding="utf-8"))
            idx = next((i for i, d in enumerate(local_list) if d.get("course_id") == data["course_id"]), None)
            if idx is not None:
                local_list[idx] = data
            else:
                local_list.append(data)
            COURSE_SUMMARIES_FILE.write_text(json.dumps(local_list, indent=2, ensure_ascii=False), encoding="utf-8")
            print(f"Updated local {COURSE_SUMMARIES_FILE.name} ({len(local_list)} total course summaries)!")
        except Exception as e:
            print(f"Warning updating local course summaries file: {e}")

    # Multichannel Social Teaser Broadcast (Facebook Blida, Facebook MedevSync, Telegram)
    try:
        from social_teaser_broadcaster import broadcast_content_teaser
        broadcast_content_teaser("summary", data, supabase=supabase, dry_run=dry_run)
    except Exception as e:
        print(f"⚠️ Avertissement diffusion teaser réseaux sociaux (Summary): {e}")

    return data


def main():
    parser = argparse.ArgumentParser(description="MedsinaPilot Autonomous Medical Agent")
    parser.add_argument("--action", choices=["cat", "pearl", "drugs", "lab", "memento", "summary", "both", "all"], default="all", help="Action to perform")
    parser.add_argument("--dci", type=str, default=None, help="Specific drug DCI to generate")
    parser.add_argument("--lab", type=str, default=None, help="Specific lab test name to generate")
    parser.add_argument("--memento", type=str, default=None, help="Specific on-call memento topic to generate")
    parser.add_argument("--course-id", type=str, default=None, help="Specific course ID to process")
    parser.add_argument("--dry-run", action="store_true", help="Run without writing to Supabase")
    args = parser.parse_args()

    print("=" * 65)
    print("🚀 MEDSINA AUTONOMOUS AI AGENT (GitHub Actions Automation)")
    print(f"📅 Timestamp : {datetime.datetime.now(datetime.timezone.utc).isoformat()}")
    print(f"⚙️ Action    : {args.action.upper()} | Dry Run: {args.dry_run}")
    print("=" * 65)

    supabase = SupabaseClient(SUPABASE_URL, SUPABASE_KEY)
    courses = load_courses_catalog(supabase)

    summary_results = []

    # 1. Conduite à Tenir (CAT)
    if args.action in ("cat", "both", "all"):
        cat_course = pick_candidate_course_for_cat(courses, supabase, target_course_id=args.course_id)
        if cat_course:
            cat_data = generate_clinical_protocol(cat_course, supabase, dry_run=args.dry_run)
            if cat_data:
                summary_results.append({
                    "type": "Conduite à Tenir (CAT)",
                    "course": cat_course["name"],
                    "specialty": cat_course["module_name"],
                    "title": cat_data.get("title"),
                    "status": "Succès ✅",
                })
            else:
                summary_results.append({
                    "type": "Conduite à Tenir (CAT)",
                    "course": cat_course["name"],
                    "specialty": cat_course["module_name"],
                    "title": "Non généré",
                    "status": "Échec temporaire (Gemini saturé) ⚠️",
                })

    # 2. Daily Pearl (Perle du Jour)
    if args.action in ("pearl", "both", "all"):
        pearl_course = pick_candidate_course_for_pearl(courses, supabase, target_course_id=args.course_id)
        if pearl_course:
            pearl_data = generate_daily_pearl(pearl_course, supabase, dry_run=args.dry_run)
            if pearl_data:
                summary_results.append({
                    "type": "Perle du Jour & Piège",
                    "course": pearl_course["name"],
                    "specialty": pearl_course["module_name"],
                    "title": pearl_data.get("title"),
                    "status": "Succès ✅",
                })
            else:
                summary_results.append({
                    "type": "Perle du Jour & Piège",
                    "course": pearl_course["name"],
                    "specialty": pearl_course["module_name"],
                    "title": "Non généré",
                    "status": "Échec temporaire (Gemini saturé) ⚠️",
                })

    # 3. Emergency Drug Monograph (Urgences & DCI Algérie)
    if args.action in ("drugs", "all"):
        drug_dci = pick_candidate_emergency_drug(supabase, target_dci=args.dci)
        if drug_dci:
            drug_data = generate_emergency_drug(drug_dci, supabase, dry_run=args.dry_run)
            if drug_data:
                summary_results.append({
                    "type": "Médicament d'Urgence & DCI",
                    "course": drug_data.get("brand", "Algérie (Saidal/IPA)"),
                    "specialty": drug_data.get("category", "Urgences"),
                    "title": drug_data.get("dci", drug_dci),
                    "status": "Succès ✅",
                })
            else:
                summary_results.append({
                    "type": "Médicament d'Urgence & DCI",
                    "course": drug_dci,
                    "specialty": "Urgences",
                    "title": drug_dci,
                    "status": "Échec temporaire (Gemini saturé) ⚠️",
                })

    # 4. Biological Reference Values (Normes Biologiques)
    if args.action in ("lab", "all"):
        lab_candidate = pick_candidate_lab_value(supabase, target_lab=args.lab)
        if lab_candidate:
            lab_data = generate_lab_value(lab_candidate, supabase, dry_run=args.dry_run)
            if lab_data:
                summary_results.append({
                    "type": "Normes Biologiques",
                    "course": (lab_data.get("normal_range") or "") + " " + (lab_data.get("unit") or ""),
                    "specialty": lab_data.get("category", "Biologie"),
                    "title": lab_data.get("name", lab_candidate),
                    "status": "Succès ✅",
                })
            else:
                summary_results.append({
                    "type": "Normes Biologiques",
                    "course": lab_candidate,
                    "specialty": "Biologie",
                    "title": lab_candidate,
                    "status": "Échec temporaire (Gemini saturé) ⚠️",
                })

    # 5. On-Call Hospital Memento (Mémento de Garde)
    if args.action in ("memento", "all"):
        memento_candidate = pick_candidate_on_call_memento(supabase, target_memento=args.memento)
        if memento_candidate:
            memento_data = generate_on_call_memento(memento_candidate, supabase, dry_run=args.dry_run)
            if memento_data:
                summary_results.append({
                    "type": "Mémento de Garde",
                    "course": f"Priorité {memento_data.get('priority_level', 1)}",
                    "specialty": memento_data.get("category", "Garde Hospitalière"),
                    "title": memento_data.get("title", memento_candidate),
                    "status": "Succès ✅",
                })
            else:
                summary_results.append({
                    "type": "Mémento de Garde",
                    "course": memento_candidate,
                    "specialty": "Garde Hospitalière",
                    "title": memento_candidate,
                    "status": "Échec temporaire (Gemini saturé) ⚠️",
                })

    # 6. Official Residency Course Summary (Fiche Résumé Concours)
    if args.action in ("summary", "all"):
        summary_course = pick_candidate_course_for_summary(courses, supabase, target_course_id=args.course_id)
        if summary_course:
            summary_data = generate_course_summary(summary_course, supabase, dry_run=args.dry_run)
            if summary_data:
                summary_results.append({
                    "type": "Fiche Résumé Cours",
                    "course": summary_course["name"],
                    "specialty": summary_course["module_name"],
                    "title": summary_data.get("course_name"),
                    "status": "Succès ✅",
                })
            else:
                summary_results.append({
                    "type": "Fiche Résumé Cours",
                    "course": summary_course["name"],
                    "specialty": summary_course["module_name"],
                    "title": "Non généré",
                    "status": "Échec temporaire (Gemini saturé) ⚠️",
                })

    # Print GitHub Actions step summary if available
    github_summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    if github_summary_path:
        with open(github_summary_path, "a", encoding="utf-8") as gf:
            gf.write("## 🩺 MedsinaPilot Automation Summary\n\n")
            gf.write("| Type | Cours / Info | Spécialité | Titre Généré | Statut |\n")
            gf.write("| :--- | :--- | :--- | :--- | :--- |\n")
            for r in summary_results:
                gf.write(f"| {r['type']} | {r['course']} | {r['specialty']} | {r['title']} | {r['status']} |\n")
            gf.write("\n*Recherches et consensus médicaux validés avec Google Search Grounding.* 🚀\n")

    print("\n✅ Execution completed successfully.")


if __name__ == "__main__":
    main()
