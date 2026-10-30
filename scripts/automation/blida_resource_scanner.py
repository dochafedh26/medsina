#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
=============================================================================
MEDSINA — SCANNER AUTOMATIQUE TELEGRAM & GOOGLE DRIVE (MÉDECINE BLIDA)
=============================================================================
Scanne périodiquement ou à la demande :
1. Les canaux publics Telegram (via https://t.me/s/<channel>) et les messages reçus
   par le Bot Telegram Medsina pour repérer les nouveaux PDFs, QCMs, EMDs,
   corrigés et annonces concernant la Faculté de Médecine de Blida & le Résidanat.
2. Extrait automatiquement tous les liens Google Drive partagés dans les canaux
   Telegram ainsi que les dossiers Google Drive surveillés.
3. Inspecte l'intérieur des dossiers Google Drive publics (via embeddedfolderview)
   pour lister les nouveaux fichiers PDF, sujets d'examen et banques de QCMs.
4. Classe chaque ressource par Module (47 modules) et Année d'étude (avec Gemini IA)
   et l'insère dans la file d'attente de validation Admin :
   `public.discovered_blida_resources` (status = 'pending').
=============================================================================
"""

import os
import re
import sys
import json
import html
import hashlib
import argparse
import datetime
import unicodedata
from pathlib import Path
from typing import List, Dict, Any, Optional, Set, Tuple
import requests

try:
    if sys.stdout.encoding and sys.stdout.encoding.lower() != "utf-8":
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    if sys.stderr.encoding and sys.stderr.encoding.lower() != "utf-8":
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

DEFAULT_SUPABASE_URL = "https://qzfssrhhuorljftpdvjm.supabase.co"

DEFAULT_SOURCES = [
    "@medsina_officiel",
    "@residanat_blida",
    "@medecine_blida",
    "@preprsdblida",
    "https://t.me/preprsdblida",
    "https://drive.google.com/drive/folders/1___jg3oAyaBm-REwGb68q_XTN5dKWX2E",
]

USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"
)

# Mapping of keywords to Medsina module IDs
MODULE_KEYWORDS: Dict[str, List[str]] = {
    "cardio": ["cardiologie", "cardio", "hta", "sca", "infarctus", "ecg", "insuffisance cardiaque", "valvulopathie", "endocardite"],
    "pneumo": ["pneumologie", "pneumo", "asthme", "bpco", "tuberculose", "pleuresie", "pneumothorax", "embolie pulmonaire"],
    "neuro": ["neurologie", "neuro", "avc", "epilepsie", "meningite", "parkinson", "sclerose en plaques", "cephalee", "coma"],
    "gastro": ["gastro", "hepato", "cirrhose", "ulcere", "hgd", "hemorragie digestive", "pancreatite", "ictere", "micii", "crohn"],
    "endocrino": ["endocrinologie", "endocrino", "diabete", "thyroide", "hyperthyroidie", "hypothyroidie", "cushing", "addison", "surrenale"],
    "nephro": ["nephrologie", "nephro", "insuffisance renale", "ira", "irc", "syndrome nephrotique", "glomerulonephrite", "dialyse"],
    "hemato": ["hematologie", "hemato", "anemie", "leucemie", "lymphome", "myelome", "hemostase", "thrombopenie", "drepanocytose"],
    "infectieux": ["infectiologie", "maladies infectieuses", "infectieux", "paludisme", "sepsis", "vih", "brucellose", "typhoide", "antibiotique"],
    "rhumato": ["rhumatologie", "rhumato", "polyarthrite", "spondylarthrite", "lupus", "goutte", "arthrose", "osteoporose"],
    "pediatrie": ["pediatrie", "nourrisson", "nouveau-ne", "bronchiolite", "deshydratation", "vaccination", " convulsions febriles"],
    "gyneco": ["gynecologie", "obstetrique", "gyneco", "grossesse", "pre-eclampsie", "accouchement", "geu", "fibrome", "cancer du sein"],
    "chir_gen": ["chirurgie generale", "viscerale", "appendicite", "peritonite", "occlusion", "cholecystite", "hernie"],
    "ortho": ["orthopedie", "traumatologie", "traumato", "fracture", "luxation", "entorse", "cotyle", "femur"],
    "uro": ["urologie", "uro", "prostate", "colique nephretique", "lithiase", "hematurie", "retention aigue"],
    "orl": ["orl", "otite", "angine", "sinusite", "vertige", "epistaxis", "larynx"],
    "ophtalmo": ["ophtalmologie", "ophtalmo", "glaucome", "cataracte", "oeil rouge", "uveite", "retine"],
    "psychiatrie": ["psychiatrie", "schizophrenie", "depression", "bipolaire", "anxiete", "suicide", "psychotrope"],
    "dermato": ["dermatologie", "dermato", "psoriasis", "eczema", "melanome", "urticaire", "erysipele"],
    "reanimation": ["reanimation", "urgences", "choc septique", "choc anaphylactique", "acr", "arret cardiaque", "intubation"],
    "anapath": ["anatomie pathologique", "anapath", "histologie", "biopsie", "tumeur"],
    "radiologie": ["radiologie", "imagerie", "tdm", "irm", "echographie"],
}

MEDICAL_RELEVANCE_KEYWORDS = [
    "blida", "residanat", "résidanat", "emd", "qcm", "qcs", "concours", "annale",
    "corrigé", "corrige", "sujet", "examen", "cours", "externe", "externat",
    "médecine", "medecine", "faculté", "faculte", "chu", "garde", "cat",
    "clinique", "ordonnance", "biologie", "module", "pdf", "drive.google.com",
]


def normalize_text(text: str) -> str:
    if not text:
        return ""
    nfkd = unicodedata.normalize("NFKD", text)
    ascii_str = "".join(c for c in nfkd if not unicodedata.combining(c))
    return ascii_str.lower()


def resolve_supabase_credentials() -> Tuple[str, str]:
    url = os.environ.get("SUPABASE_URL", DEFAULT_SUPABASE_URL).rstrip("/")
    key = (
        os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
        or os.environ.get("SUPABASE_KEY")
        or ""
    ).strip()

    if not key:
        for p in [
            Path(".env"),
            Path("medsina/.env"),
            Path(__file__).resolve().parents[2] / ".env",
        ]:
            if p.exists():
                try:
                    content = p.read_text(encoding="utf-8")
                    m = re.search(
                        r"SUPABASE_SERVICE_ROLE_KEY\s*=\s*['\"]?([^'\"\r\n]+)['\"]?",
                        content,
                    )
                    if m:
                        key = m.group(1).strip()
                        break
                except Exception:
                    pass
    return url, key


def resolve_gemini_key(supabase_url: str, supabase_key: str) -> str:
    if supabase_key:
        try:
            r = requests.get(
                f"{supabase_url}/rest/v1/admin_system_settings?setting_key=eq.gemini_api_key&select=setting_value",
                headers={
                    "apikey": supabase_key,
                    "Authorization": f"Bearer {supabase_key}",
                },
                timeout=8,
            )
            if r.status_code == 200 and r.json():
                val = (r.json()[0].get("setting_value") or "").strip()
                if val:
                    return val
        except Exception:
            pass

    env_key = os.environ.get("GEMINI_API_KEY", "").strip()
    if env_key:
        return env_key

    secrets_file = (
        Path(__file__).resolve().parents[2]
        / "lib"
        / "core"
        / "config"
        / "app_secrets.dart"
    )
    if secrets_file.exists():
        try:
            content = secrets_file.read_text(encoding="utf-8")
            m = re.search(r"geminiApiKey\s*=\s*['\"]([^'\"]+)['\"]", content)
            if m and m.group(1).strip():
                return m.group(1).strip()
        except Exception:
            pass
    return ""


def load_drives_from_gdrives_txt() -> List[str]:
    """Loads monitored Google Drive URLs from assets/drives/gdrives.txt."""
    candidates = [
        Path("assets/drives/gdrives.txt"),
        Path("medsina/assets/drives/gdrives.txt"),
        Path(r"D:\REVISION RESIDANAT\ressources\residanat-blida-2027\medsina\assets\drives\gdrives.txt"),
    ]
    drive_urls = []
    for c in candidates:
        if c.exists():
            try:
                for line in c.read_text(encoding="utf-8").splitlines():
                    clean = line.strip()
                    if clean.startswith("http") and "drive.google.com" in clean:
                        drive_urls.append(clean)
                if drive_urls:
                    break
            except Exception:
                pass
    return drive_urls


def fetch_configured_sources(supabase_url: str, supabase_key: str) -> List[str]:
    sources: List[str] = []
    if supabase_key:
        try:
            r = requests.get(
                f"{supabase_url}/rest/v1/admin_system_settings?setting_key=eq.blida_scanner_sources&select=setting_value",
                headers={
                    "apikey": supabase_key,
                    "Authorization": f"Bearer {supabase_key}",
                },
                timeout=10,
            )
            if r.status_code == 200 and r.json():
                raw = (r.json()[0].get("setting_value") or "").strip()
                if raw:
                    try:
                        cfg = json.loads(raw)
                        if isinstance(cfg, dict):
                            for tc in cfg.get("telegram_channels", []):
                                if tc:
                                    tc_s = str(tc).strip()
                                    sources.append(tc_s if (tc_s.startswith("@") or tc_s.startswith("http")) else f"@{tc_s}")
                            for gd in cfg.get("google_drive_folders", []):
                                if gd:
                                    sources.append(str(gd).strip())
                        elif isinstance(cfg, list):
                            for item in cfg:
                                if item:
                                    sources.append(str(item).strip())
                    except Exception:
                        for part in re.split(r"[,;\n]+", raw):
                            cleaned = part.strip()
                            if cleaned:
                                sources.append(cleaned)
        except Exception as e:
            print(f"⚠️ Lecture blida_scanner_sources ignorée: {e}")

    if not sources:
        sources = list(DEFAULT_SOURCES)

    # Always ensure the monitored Google Drives from gdrives.txt are included
    file_drives = load_drives_from_gdrives_txt()
    for d in file_drives:
        if d not in sources:
            sources.append(d)

    return sources


def fetch_existing_queue_and_ids(supabase_url: str, supabase_key: str) -> Tuple[List[Dict[str, Any]], Set[str]]:
    if not supabase_key:
        return [], set()
    headers = {
        "apikey": supabase_key,
        "Authorization": f"Bearer {supabase_key}",
    }
    # 1. Try dedicated table discovered_blida_resources
    try:
        r = requests.get(
            f"{supabase_url}/rest/v1/discovered_blida_resources?select=*&order=discovered_at.desc",
            headers=headers,
            timeout=12,
        )
        if r.status_code == 200 and isinstance(r.json(), list):
            rows = r.json()
            ids = {str(row.get("id")) for row in rows if row.get("id")}
            return rows, ids
    except Exception:
        pass

    # 2. Fallback: read from admin_system_settings (key: discovered_blida_resources_queue)
    try:
        r = requests.get(
            f"{supabase_url}/rest/v1/admin_system_settings?setting_key=eq.discovered_blida_resources_queue&select=setting_value",
            headers=headers,
            timeout=12,
        )
        if r.status_code == 200 and r.json():
            raw = r.json()[0].get("setting_value") or "[]"
            rows = json.loads(raw)
            if isinstance(rows, list):
                ids = {str(row.get("id")) for row in rows if isinstance(row, dict) and row.get("id")}
                return rows, ids
    except Exception as e:
        print(f"⚠️ Lecture file d'attente existante ignorée: {e}")

    return [], set()


def classify_resource_heuristically(title: str, text: str = "") -> Dict[str, Any]:
    combined = normalize_text(f"{title} {text}")

    # 1. Detect module
    detected_module = None
    best_score = 0
    for mod_id, kw_list in MODULE_KEYWORDS.items():
        score = sum(1 for kw in kw_list if normalize_text(kw) in combined)
        if score > best_score:
            best_score = score
            detected_module = mod_id

    # 2. Detect study year (1..6 for Externat, 7 for Résidanat)
    study_year: Optional[int] = 7 if ("residanat" in combined or "concours" in combined) else None
    for yr in range(1, 7):
        if f"{yr}eme" in combined or f"{yr}ere" in combined or f"{yr}e annee" in combined:
            study_year = yr
            break

    # 3. Detect resource type
    qcm_indicators = ["qcm", "qcs", "emd", "sujet", "examen", "concours", "corrig", "annale", "quiz"]
    if any(k in combined for k in qcm_indicators):
        resource_type = "qcm_exam"
    else:
        resource_type = "pdf_course"

    return {
        "suggested_module_id": detected_module,
        "study_year": study_year,
        "resource_type": resource_type,
    }


def extract_gdrive_links(text: str) -> List[Tuple[str, str, str]]:
    """
    Extrait tous les liens Google Drive d'un texte ou HTML.
    Retourne une liste de tuples: (kind, gdrive_id, canonical_url)
    kind: 'folder' | 'file'
    """
    results: List[Tuple[str, str, str]] = []
    seen: Set[str] = set()

    # Folder links
    for m in re.finditer(
        r"https?://drive\.google\.com/drive/(?:u/\d+/)?folders/([a-zA-Z0-9_-]{15,})",
        text,
    ):
        fid = m.group(1)
        if fid not in seen:
            seen.add(fid)
            results.append(("folder", fid, f"https://drive.google.com/drive/folders/{fid}"))

    # File links
    for m in re.finditer(
        r"https?://(?:drive|docs)\.google\.com/(?:file|document|presentation|spreadsheets)/d/([a-zA-Z0-9_-]{15,})",
        text,
    ):
        fid = m.group(1)
        if fid not in seen:
            seen.add(fid)
            results.append(("file", fid, f"https://drive.google.com/file/d/{fid}/view"))

    # Open ID links
    for m in re.finditer(
        r"https?://drive\.google\.com/open\?id=([a-zA-Z0-9_-]{15,})",
        text,
    ):
        fid = m.group(1)
        if fid not in seen:
            seen.add(fid)
            results.append(("file", fid, f"https://drive.google.com/file/d/{fid}/view"))

    return results


def strip_html_tags(raw_html: str) -> str:
    cleaned = re.sub(r"<br\s*/?>", "\n", raw_html, flags=re.IGNORECASE)
    cleaned = re.sub(r"<[^>]+>", " ", cleaned)
    cleaned = html.unescape(cleaned)
    return re.sub(r"[ \t]+", " ", cleaned).strip()


def scan_public_telegram_channel(channel_ref: str) -> Tuple[List[Dict[str, Any]], List[Tuple[str, str, str]]]:
    """
    Scanne la page publique https://t.me/s/<channel> d'un canal Telegram.
    Retourne :
      - la liste des ressources/publications pertinentes trouvées
      - la liste des liens Google Drive extraits des messages pour inspection approfondie
    """
    username = channel_ref.strip()
    username = re.sub(r"^https?://t\.me/(?:s/)?", "", username).strip("/ @")
    if not username or "/" in username:
        return [], []

    url = f"https://t.me/s/{username}"
    print(f"📡 Scan du canal Telegram public : @{username} ({url})")

    discovered_posts: List[Dict[str, Any]] = []
    discovered_drive_links: List[Tuple[str, str, str]] = []

    try:
        resp = requests.get(url, headers={"User-Agent": USER_AGENT}, timeout=15)
        if resp.status_code != 200:
            print(f"⚠️ Canal @{username} inaccessible (HTTP {resp.status_code})")
            return [], []

        page_html = resp.text

        # Split by message widget blocks
        blocks = re.split(r'(?=<div class="tgme_widget_message\b)', page_html)
        for block in blocks:
            post_match = re.search(r'data-post="([^"]+)"', block)
            if not post_match:
                continue
            post_id = post_match.group(1)  # e.g., "medecine_blida/412"
            post_url = f"https://t.me/{post_id}"

            # Extract text body
            text_match = re.search(
                r'<div class="tgme_widget_message_text[^"]*"[^>]*>(.*?)</div>',
                block,
                re.DOTALL,
            )
            msg_text = strip_html_tags(text_match.group(1)) if text_match else ""

            # Extract attached document title if any
            doc_match = re.search(
                r'<div class="tgme_widget_message_document_title"[^>]*>(.*?)</div>',
                block,
                re.DOTALL,
            )
            doc_title = strip_html_tags(doc_match.group(1)) if doc_match else ""

            # Extract all Google Drive links in this message block
            drive_links = extract_gdrive_links(block + " " + msg_text)
            for dl in drive_links:
                discovered_drive_links.append(dl)

            norm_combined = normalize_text(f"{doc_title} {msg_text}")
            if username.lower() == "medsina_officiel" and not doc_title and not drive_links:
                # Ignore self-promotional automated posts from Medsina's own channel unless they contain a file or Drive link
                continue

            is_relevant = (
                bool(doc_title)
                or bool(drive_links)
                or any(normalize_text(k) in norm_combined for k in MEDICAL_RELEVANCE_KEYWORDS)
            )
            if not is_relevant:
                continue

            title = doc_title if doc_title else (msg_text.split("\n")[0][:110] if msg_text else f"Publication @{username}")
            if len(title.strip()) < 4:
                continue

            classification = classify_resource_heuristically(title, msg_text)
            res_type = classification["resource_type"]
            if not doc_title and not drive_links:
                res_type = "telegram_post"

            det_id = f"tg_{re.sub(r'[^a-zA-Z0-9_]', '_', post_id)}"
            summary_snippet = msg_text[:280].replace("\n", " ").strip()
            if doc_title and summary_snippet:
                summary = f"Document partagé sur @{username} : {doc_title} — {summary_snippet}"
            elif doc_title:
                summary = f"Fichier PDF/Document partagé sur le canal Telegram @{username} ({doc_title})."
            else:
                summary = summary_snippet or f"Publication médicale détectée sur @{username}."

            discovered_posts.append({
                "id": det_id,
                "title": title.strip(),
                "resource_type": res_type,
                "source_type": "telegram",
                "source_origin": f"@{username}",
                "source_url": post_url,
                "gdrive_file_id": drive_links[0][1] if drive_links else None,
                "suggested_module_id": classification["suggested_module_id"],
                "suggested_course_id": None,
                "study_year": classification["study_year"],
                "ai_summary": summary,
                "status": "pending",
            })

    except Exception as e:
        print(f"⚠️ Erreur lors du scan Telegram @{username}: {e}")

    print(
        f"   ↳ @{username} : {len(discovered_posts)} publication(s) pertinente(s), "
        f"{len(discovered_drive_links)} lien(s) Google Drive extrait(s)."
    )
    return discovered_posts, discovered_drive_links


def scan_public_gdrive_folder(folder_id: str, origin_label: str = "Google Drive Blida") -> List[Dict[str, Any]]:
    """
    Inspecte un dossier public Google Drive via la vue embarquée publique
    https://drive.google.com/embeddedfolderview?id=<folder_id>#list
    sans nécessiter de jeton OAuth utilisateur.
    """
    embed_url = f"https://drive.google.com/embeddedfolderview?id={folder_id}#list"
    folder_url = f"https://drive.google.com/drive/folders/{folder_id}"
    print(f"📂 Inspection du dossier Google Drive : {folder_id}")

    discovered_items: List[Dict[str, Any]] = []

    try:
        resp = requests.get(embed_url, headers={"User-Agent": USER_AGENT}, timeout=15)
        if resp.status_code != 200:
            print(f"⚠️ Dossier Drive {folder_id} non public ou inaccessible (HTTP {resp.status_code})")
            return []

        html_body = resp.text

        # Parse flip-entry blocks in embeddedfolderview
        entry_pattern = re.compile(
            r'<div class="flip-entry" id="entry-([a-zA-Z0-9_-]+)"[^>]*>(.*?)</div>\s*</div>\s*</div>',
            re.DOTALL,
        )
        matches = list(entry_pattern.finditer(html_body))

        if not matches:
            # Fallback regex for any entry-<id> and flip-entry-title pairs
            ids = re.findall(r'id="entry-([a-zA-Z0-9_-]{15,})"', html_body)
            titles = re.findall(r'<div class="flip-entry-title">([^<]+)</div>', html_body)
            for idx, fid in enumerate(ids[:60]):
                raw_title = html.unescape(titles[idx]).strip() if idx < len(titles) else f"Fichier Drive {fid[:8]}"
                is_folder = not bool(re.search(r"\.(pdf|doc|docx|ppt|pptx|zip|rar)$", raw_title, re.IGNORECASE))
                classification = classify_resource_heuristically(raw_title)
                res_type = "gdrive_folder" if is_folder else classification["resource_type"]
                item_url = (
                    f"https://drive.google.com/drive/folders/{fid}"
                    if is_folder
                    else f"https://drive.google.com/file/d/{fid}/view"
                )
                discovered_items.append({
                    "id": f"gdrive_{fid}",
                    "title": raw_title,
                    "resource_type": res_type,
                    "source_type": "google_drive",
                    "source_origin": origin_label,
                    "source_url": item_url,
                    "gdrive_file_id": fid,
                    "suggested_module_id": classification["suggested_module_id"],
                    "suggested_course_id": None,
                    "study_year": classification["study_year"],
                    "ai_summary": (
                        f"{'Sous-dossier' if is_folder else 'Document PDF / QCM'} détecté dans {origin_label} "
                        f"({raw_title})."
                    ),
                    "status": "pending",
                })
        else:
            for m in matches[:60]:
                fid = m.group(1)
                inner = m.group(2)
                t_match = re.search(r'<div class="flip-entry-title">([^<]+)</div>', inner)
                raw_title = html.unescape(t_match.group(1)).strip() if t_match else f"Ressource Blida {fid[:8]}"
                is_folder = "drive.google.com/drive/folders/" in inner
                classification = classify_resource_heuristically(raw_title)
                res_type = "gdrive_folder" if is_folder else classification["resource_type"]
                item_url = (
                    f"https://drive.google.com/drive/folders/{fid}"
                    if is_folder
                    else f"https://drive.google.com/file/d/{fid}/view"
                )
                discovered_items.append({
                    "id": f"gdrive_{fid}",
                    "title": raw_title,
                    "resource_type": res_type,
                    "source_type": "google_drive",
                    "source_origin": origin_label,
                    "source_url": item_url,
                    "gdrive_file_id": fid,
                    "suggested_module_id": classification["suggested_module_id"],
                    "suggested_course_id": None,
                    "study_year": classification["study_year"],
                    "ai_summary": (
                        f"{'Dossier de cours/QCM' if is_folder else 'Fichier PDF / Sujet QCM'} "
                        f"détecté sur Google Drive ({raw_title})."
                    ),
                    "status": "pending",
                })

        # If folder itself had no parseable sub-entries but is a valid shared link, index the folder itself
        if not discovered_items:
            title_match = re.search(r"<title>([^<]+)</title>", html_body)
            folder_title = (
                html.unescape(title_match.group(1)).replace("- Google Drive", "").strip()
                if title_match
                else f"Dossier Google Drive Blida ({folder_id[:8]})"
            )
            if folder_title and len(folder_title) > 2:
                classification = classify_resource_heuristically(folder_title)
                discovered_items.append({
                    "id": f"gdrive_folder_{folder_id}",
                    "title": folder_title,
                    "resource_type": "gdrive_folder",
                    "source_type": "google_drive",
                    "source_origin": origin_label,
                    "source_url": folder_url,
                    "gdrive_file_id": folder_id,
                    "suggested_module_id": classification["suggested_module_id"],
                    "suggested_course_id": None,
                    "study_year": classification["study_year"],
                    "ai_summary": f"Dossier Google Drive partagé ({folder_title}).",
                    "status": "pending",
                })

    except Exception as e:
        print(f"⚠️ Erreur lors de l'inspection du dossier Drive {folder_id}: {e}")

    print(f"   ↳ Drive {folder_id} : {len(discovered_items)} élément(s) extrait(s).")
    return discovered_items


def inspect_single_gdrive_file(file_id: str, origin_label: str = "Lien Google Drive") -> Optional[Dict[str, Any]]:
    file_url = f"https://drive.google.com/file/d/{file_id}/view"
    try:
        resp = requests.get(file_url, headers={"User-Agent": USER_AGENT}, timeout=12)
        if resp.status_code != 200:
            return None
        title_match = re.search(r"<meta property=\"og:title\" content=\"([^\"]+)\"", resp.text)
        if not title_match:
            title_match = re.search(r"<title>([^<]+)</title>", resp.text)
        raw_title = (
            html.unescape(title_match.group(1)).replace("- Google Drive", "").strip()
            if title_match
            else f"Document Google Drive ({file_id[:8]})"
        )
        classification = classify_resource_heuristically(raw_title)
        return {
            "id": f"gdrive_{file_id}",
            "title": raw_title,
            "resource_type": classification["resource_type"],
            "source_type": "google_drive",
            "source_origin": origin_label,
            "source_url": file_url,
            "gdrive_file_id": file_id,
            "suggested_module_id": classification["suggested_module_id"],
            "suggested_course_id": None,
            "study_year": classification["study_year"],
            "ai_summary": f"Document Google Drive détecté depuis {origin_label} : {raw_title}",
            "status": "pending",
        }
    except Exception:
        return None


def enrich_with_gemini_ai(items: List[Dict[str, Any]], gemini_key: str) -> List[Dict[str, Any]]:
    """
    Si une clé Gemini est disponible, enrichit les résumés et classifications
    des nouvelles ressources découvertes (par lot de 15 max).
    """
    if not gemini_key or not items:
        return items

    batch = items[:15]
    prompt_lines = [
        "Tu es l'assistant médical de la plateforme Medsina (Faculté de Médecine de Blida & Résidanat).",
        "Voici une liste de nouvelles ressources détectées sur Telegram et Google Drive.",
        "Pour chaque élément (identifié par son index 0..N), renvoie un objet JSON avec :",
        "- index (int)",
        "- resource_type ('pdf_course', 'qcm_exam', 'gdrive_folder', 'telegram_post')",
        "- suggested_module_id (ex: 'cardio', 'pneumo', 'neuro', 'gastro', 'endocrino', 'nephro', 'hemato', 'infectieux', 'rhumato', 'pediatrie', 'gyneco', 'chir_gen', 'ortho', 'uro', 'orl', 'ophtalmo', 'psychiatrie', 'dermato', 'reanimation', ou null)",
        "- ai_summary (1 phrase claire en français résumant l'intérêt pédagogique pour un étudiant/candidat au Résidanat de Blida).",
        "Réponds UNIQUEMENT avec un tableau JSON valide.",
        "",
        "Ressources :",
    ]
    for idx, it in enumerate(batch):
        prompt_lines.append(
            f"[{idx}] Titre: {it['title']} | Source: {it['source_origin']} | Aperçu: {it.get('ai_summary', '')[:140]}"
        )

    try:
        endpoint = (
            f"https://generativelanguage.googleapis.com/v1beta/models/"
            f"gemini-2.5-flash:generateContent?key={gemini_key}"
        )
        payload = {
            "contents": [{"parts": [{"text": "\n".join(prompt_lines)}]}],
            "generationConfig": {
                "temperature": 0.2,
                "responseMimeType": "application/json",
            },
        }
        r = requests.post(endpoint, json=payload, timeout=20)
        if r.status_code == 200:
            data = r.json()
            text_out = (
                data.get("candidates", [{}])[0]
                .get("content", {})
                .get("parts", [{}])[0]
                .get("text", "[]")
            )
            parsed = json.loads(text_out)
            if isinstance(parsed, list):
                for entry in parsed:
                    idx = entry.get("index")
                    if isinstance(idx, int) and 0 <= idx < len(batch):
                        if entry.get("resource_type") in ("pdf_course", "qcm_exam", "gdrive_folder", "telegram_post"):
                            items[idx]["resource_type"] = entry["resource_type"]
                        if entry.get("suggested_module_id"):
                            items[idx]["suggested_module_id"] = entry["suggested_module_id"]
                        if entry.get("ai_summary"):
                            items[idx]["ai_summary"] = str(entry["ai_summary"]).strip()
    except Exception as e:
        print(f"ℹ️ Enrichissement Gemini ignoré (fallback local utilisé): {e}")

    return items


def push_to_admin_queue(
    new_items: List[Dict[str, Any]],
    existing_rows: List[Dict[str, Any]],
    supabase_url: str,
    supabase_key: str,
    dry_run: bool = False,
) -> int:
    if not new_items:
        print("✅ Aucune nouvelle ressource inédite à ajouter (tout est déjà indexé).")
        return 0

    now_iso = datetime.datetime.now(datetime.timezone.utc).isoformat()
    for it in new_items:
        if "discovered_at" not in it:
            it["discovered_at"] = now_iso

    if dry_run or not supabase_key:
        print(f"🧪 [DRY-RUN] {len(new_items)} nouvelle(s) ressource(s) prête(s) pour la file d'attente Admin :")
        for it in new_items[:15]:
            print(f"  - [{it['source_type']}] ({it['resource_type']}) {it['title']} -> {it['source_url']}")
        return len(new_items)

    headers = {
        "apikey": supabase_key,
        "Authorization": f"Bearer {supabase_key}",
        "Content-Type": "application/json",
        "Prefer": "resolution=merge-duplicates",
    }

    inserted_count = 0
    table_missing = False

    # 1. Try dedicated table discovered_blida_resources
    for i in range(0, len(new_items), 25):
        chunk = new_items[i : i + 25]
        try:
            r = requests.post(
                f"{supabase_url}/rest/v1/discovered_blida_resources",
                headers=headers,
                json=chunk,
                timeout=15,
            )
            if r.status_code in (200, 201):
                inserted_count += len(chunk)
            elif r.status_code == 404 or "PGRST205" in r.text:
                table_missing = True
                break
            else:
                print(f"⚠️ Erreur insertion Supabase ({r.status_code}): {r.text}")
        except Exception as e:
            print(f"⚠️ Exception lors de l'insertion Supabase: {e}")

    # 2. Cloud Fallback: store in admin_system_settings (discovered_blida_resources_queue)
    merged_queue = new_items + existing_rows
    # Keep max 200 most recent items in JSON setting to stay lightweight
    merged_queue = merged_queue[:200]

    if table_missing or inserted_count == 0:
        try:
            setting_payload = {
                "setting_key": "discovered_blida_resources_queue",
                "setting_value": json.dumps(merged_queue, ensure_ascii=False),
                "description": "File d'attente de validation Admin pour les ressources Blida (Telegram & Google Drive)",
            }
            r_set = requests.post(
                f"{supabase_url}/rest/v1/admin_system_settings",
                headers=headers,
                json=setting_payload,
                timeout=15,
            )
            if r_set.status_code in (200, 201, 204):
                inserted_count = len(new_items)
                print(
                    f"☁️ File d'attente synchronisée dans Supabase Cloud "
                    f"(admin_system_settings.discovered_blida_resources_queue : {len(merged_queue)} éléments)."
                )
        except Exception as e:
            print(f"⚠️ Erreur synchronisation admin_system_settings: {e}")

    # 3. Also ensure blida_scanner_sources setting exists in admin_system_settings
    try:
        r_check = requests.get(
            f"{supabase_url}/rest/v1/admin_system_settings?setting_key=eq.blida_scanner_sources&select=setting_key",
            headers={"apikey": supabase_key, "Authorization": f"Bearer {supabase_key}"},
            timeout=8,
        )
        if r_check.status_code == 200 and not r_check.json():
            requests.post(
                f"{supabase_url}/rest/v1/admin_system_settings",
                headers=headers,
                json={
                    "setting_key": "blida_scanner_sources",
                    "setting_value": ", ".join(DEFAULT_SOURCES),
                    "description": "Canaux Telegram (@username) et dossiers Google Drive surveillés par le scanner Blida",
                },
                timeout=8,
            )
    except Exception:
        pass

    # 4. Save local JSON cache for offline / repo sync
    try:
        assets_dir = Path(__file__).resolve().parents[2] / "assets" / "data"
        if assets_dir.exists():
            cache_file = assets_dir / "discovered_blida_resources.json"
            cache_file.write_text(
                json.dumps(merged_queue, ensure_ascii=False, indent=2),
                encoding="utf-8",
            )
    except Exception:
        pass

    # 5. Send real-time Admin Notification if new resources were queued
    if inserted_count > 0:
        sample_titles = ", ".join(it["title"][:35] for it in new_items[:3])
        if len(new_items) > 3:
            sample_titles += f" (+{len(new_items) - 3} autres)"
        notif_payload = {
            "id": f"blida_scan_{int(datetime.datetime.now().timestamp())}",
            "title": f"🔍 {inserted_count} nouvelle(s) ressource(s) Blida détectée(s) (Telegram / Drive)",
            "message": f"En attente de validation Admin : {sample_titles}",
            "type": "announcement",
            "target_role": "admin",
            "is_broadcast": False,
            "metadata": {
                "is_admin_only": True,
                "target_role": "admin",
                "discovered_count": inserted_count,
            },
        }
        try:
            requests.post(
                f"{supabase_url}/rest/v1/medical_notifications",
                headers=headers,
                json=notif_payload,
                timeout=10,
            )
        except Exception:
            pass

    print(f"✅ {inserted_count} nouvelle(s) ressource(s) ajoutée(s) dans la file d'attente Admin.")
    return inserted_count


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Medsina — Scanner Automatique Telegram & Google Drive (Médecine Blida)"
    )
    parser.add_argument(
        "--target",
        type=str,
        default="",
        help="Canal Telegram (@nom), lien t.me/... ou lien Google Drive spécifique à scanner",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Exécute le scan sans écrire dans Supabase",
    )
    args = parser.parse_args()

    print("=================================================================")
    print("🔍 MEDSINA — SCANNER TELEGRAM & GOOGLE DRIVE (MÉDECINE BLIDA)")
    print("=================================================================")

    supabase_url, supabase_key = resolve_supabase_credentials()
    gemini_key = resolve_gemini_key(supabase_url, supabase_key)

    sources = fetch_configured_sources(supabase_url, supabase_key)
    if args.target and args.target.strip():
        custom_targets = [
            t.strip() for t in re.split(r"[,;\n]+", args.target.strip()) if t.strip()
        ]
        sources = custom_targets + [s for s in sources if s not in custom_targets]

    print(f"📋 Sources à inspecter ({len(sources)}) : {', '.join(sources)}")

    existing_rows, existing_ids = fetch_existing_queue_and_ids(supabase_url, supabase_key)
    print(f"🗃️ Ressources déjà connues en base : {len(existing_ids)}")

    all_discovered: Dict[str, Dict[str, Any]] = {}
    drive_targets_to_crawl: List[Tuple[str, str, str]] = []
    crawled_drive_ids: Set[str] = set()

    for src in sources:
        # Check if source is a Google Drive URL
        drive_matches = extract_gdrive_links(src)
        if drive_matches:
            for kind, fid, url in drive_matches:
                drive_targets_to_crawl.append((kind, fid, "Google Drive Surveillé"))
        else:
            # Treat as Telegram channel
            posts, extracted_drives = scan_public_telegram_channel(src)
            for p in posts:
                if p["id"] not in existing_ids:
                    all_discovered[p["id"]] = p
            for kind, fid, _ in extracted_drives:
                drive_targets_to_crawl.append((kind, fid, f"Extrait de {src}"))

    # Now crawl all discovered & configured Google Drive folders/files (up to 2 levels deep)
    subfolders_level_2: List[Tuple[str, str]] = []
    for kind, fid, origin_label in drive_targets_to_crawl:
        if fid in crawled_drive_ids:
            continue
        crawled_drive_ids.add(fid)

        if kind == "folder":
            folder_items = scan_public_gdrive_folder(fid, origin_label=origin_label)
            for item in folder_items:
                if item["id"] not in existing_ids:
                    all_discovered[item["id"]] = item
                if item.get("resource_type") == "gdrive_folder" and item.get("gdrive_file_id"):
                    subfolders_level_2.append((item["gdrive_file_id"], f"Drive / {item['title']}"))
        else:
            if f"gdrive_{fid}" not in existing_ids:
                file_item = inspect_single_gdrive_file(fid, origin_label=origin_label)
                if file_item:
                    all_discovered[file_item["id"]] = file_item

    # Crawl level-2 subfolders (up to 6 subfolders per run to stay fast)
    for sub_fid, sub_label in subfolders_level_2[:6]:
        if sub_fid in crawled_drive_ids:
            continue
        crawled_drive_ids.add(sub_fid)
        sub_items = scan_public_gdrive_folder(sub_fid, origin_label=sub_label)
        for item in sub_items:
            if item["id"] not in existing_ids:
                all_discovered[item["id"]] = item

    new_list = list(all_discovered.values())
    print(f"✨ Nouveaux éléments détectés avant filtrage final : {len(new_list)}")

    if new_list:
        new_list = enrich_with_gemini_ai(new_list, gemini_key)

    push_to_admin_queue(
        new_list,
        existing_rows=existing_rows,
        supabase_url=supabase_url,
        supabase_key=supabase_key,
        dry_run=args.dry_run,
    )


if __name__ == "__main__":
    main()
