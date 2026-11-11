#!/usr/bin/env python3
"""
Medsina Ultra — MBset API & Resource Scanner
===========================================
Surveille en continu l'écosystème MBset (api.mbset.com, app.mbset.com,
banques de QCMs, simulations de concours résidanat, fiches de principes d'examen,
et polycopiés PDF / dossiers Drive partagés pour la Faculté de Médecine de Blida).

Toutes les nouvelles ressources détectées sont injectées dans la file d'attente
de validation Admin de Medsina :
  - Table Supabase : public.discovered_blida_resources (status = 'pending')
  - Fallback Cloud : admin_system_settings (discovered_blida_resources_queue)

L'administrateur garde ainsi un contrôle total pour approuver ou rejeter
chaque ressource depuis l'Admin Dashboard Medsina.
"""

import argparse
import datetime
import hashlib
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any, Dict, List, Optional, Set, Tuple

# Path setup
ROOT_DIR = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT_DIR / "scripts"))
sys.path.insert(0, str(ROOT_DIR / "scripts" / "automation"))

from mbset_client import MBSetClient  # noqa: E402

DEFAULT_SUPABASE_URL = "https://qzfssrhhuorljftpdvjm.supabase.co"
DEFAULT_SUPABASE_KEY = "sb_publishable_E2OrqFqG1MbxVpoLb50jvA_DmOeP-UR"


def resolve_supabase_credentials() -> Tuple[str, str]:
    url = os.environ.get("SUPABASE_URL", DEFAULT_SUPABASE_URL).rstrip("/")
    key = (
        os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
        or os.environ.get("SUPABASE_KEY")
        or os.environ.get("SUPABASE_ANON_KEY")
        or ""
    ).strip()

    if not key:
        for p in [
            ROOT_DIR / ".env",
            ROOT_DIR / "admin-dashboard" / ".env",
        ]:
            if p.exists():
                try:
                    content = p.read_text(encoding="utf-8")
                    m = re.search(r"SUPABASE_SERVICE_ROLE_KEY\s*=\s*['\"]?([^'\"\r\n;]+)['\"]?", content)
                    if m and not m.group(1).startswith("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF6"):
                        key = m.group(1).strip()
                        break
                except Exception:
                    pass

    if not key:
        key = DEFAULT_SUPABASE_KEY

    return url, key



def generate_item_id(prefix: str, unique_str: str) -> str:
    """Génère un identifiant propre et déterministe."""
    clean_str = re.sub(r"[^a-zA-Z0-9_\-]", "_", unique_str).strip("_")
    if len(clean_str) > 40:
        h = hashlib.sha256(unique_str.encode("utf-8")).hexdigest()[:12]
        clean_str = f"{clean_str[:28]}_{h}"
    return f"mbset_{prefix}_{clean_str}"


def fetch_existing_resources(
    supabase_url: str,
    supabase_key: str,
) -> Tuple[List[Dict[str, Any]], Set[str]]:
    """
    Récupère la liste des ressources déjà indexées pour éviter les doublons.
    """
    if not supabase_key:
        return [], set()

    headers = {
        "apikey": supabase_key,
        "Authorization": f"Bearer {supabase_key}",
    }

    existing_rows: List[Dict[str, Any]] = []
    seen_ids: Set[str] = set()

    # 1. From dedicated table discovered_blida_resources
    try:
        req = urllib.request.Request(
            f"{supabase_url}/rest/v1/discovered_blida_resources?select=id,title,source_url,status",
            headers=headers,
        )
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            if isinstance(data, list):
                existing_rows = data
                for r in data:
                    if r.get("id"):
                        seen_ids.add(str(r["id"]))
                    if r.get("source_url"):
                        seen_ids.add(str(r["source_url"]))
    except Exception as e:
        print(f"ℹ️ Lecture table discovered_blida_resources: {e}")

    # 2. From admin_system_settings
    try:
        req = urllib.request.Request(
            f"{supabase_url}/rest/v1/admin_system_settings?setting_key=eq.discovered_blida_resources_queue&select=setting_value",
            headers=headers,
        )
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            if data and data[0].get("setting_value"):
                queue = json.loads(data[0]["setting_value"])
                if isinstance(queue, list):
                    for it in queue:
                        if it.get("id"):
                            seen_ids.add(str(it["id"]))
                        if it.get("source_url"):
                            seen_ids.add(str(it["source_url"]))
    except Exception:
        pass

    return existing_rows, seen_ids


MODULE_KEYWORDS = {
    "cardio": ["cardiologie", "cardio", "hta", "sca", "infarctus", "ecg"],
    "pneumo": ["pneumologie", "pneumo", "asthme", "bpco", "tuberculose"],
    "neuro": ["neurologie", "neuro", "avc", "epilepsie", "meningite"],
    "gastro": ["gastro", "hepato", "cirrhose", "ulcere", "crohn"],
    "endocrino": ["endocrinologie", "diabete", "thyroide"],
    "nephro": ["nephrologie", "insuffisance renale", "ira", "irc"],
    "hemato": ["hematologie", "anemie", "leucemie", "lymphome"],
    "infectieux": ["infectieuses", "infectiologie", "infectieux", "sepsis", "vih"],
    "pediatrie": ["pediatrie", "nourrisson", "bronchiolite"],
    "ophtalmo": ["ophtalmologie", "ophtalmo", "glaucome", "cataracte"],
    "ortho": ["orthopedie", "traumatologie", "fracture"],
    "uro": ["urologie", "prostate", "lithiase"],
    "gyneco": ["gynecologie", "obstetrique", "grossesse"],
    "psychiatrie": ["psychiatrie", "schizophrenie", "depression"],
    "dermato": ["dermatologie", "psoriasis", "eczema"],
}


def detect_module_id(text: str) -> Optional[str]:
    txt = text.lower()
    for mod_id, kws in MODULE_KEYWORDS.items():
        if any(kw in txt for kw in kws):
            return mod_id
    return None


def scan_mbset_simulations_and_announcements(
    client: MBSetClient,
    seen_ids: Set[str],
) -> List[Dict[str, Any]]:
    """
    Scanne les annonces, simulations et scores publics MBset.
    """
    print("📡 [1/3] Analyse des simulations publiques & annonces MBset...")
    raw_items = client.get_public_simulations_and_announcements()
    new_resources: List[Dict[str, Any]] = []

    for item in raw_items:
        item_id = item["id"]
        source_url = item.get("source_url") or item.get("url") or ""

        if item_id in seen_ids or source_url in seen_ids:
            continue

        seen_ids.add(item_id)
        if source_url:
            seen_ids.add(source_url)

        res_type = item.get("resource_type", "qcm_exam")
        if "file" in source_url or "pdf" in source_url.lower():
            res_type = "pdf_course"
        elif "folder" in source_url:
            res_type = "gdrive_folder"
        elif res_type not in ("pdf_course", "qcm_exam", "gdrive_folder", "telegram_post"):
            res_type = "qcm_exam"

        detected_mod = detect_module_id(item["title"] + " " + item.get("ai_summary", ""))

        new_resources.append({
            "id": item_id,
            "title": item["title"],
            "resource_type": res_type,
            "source_type": "mbset",
            "source_origin": "MBset Platform & API (@mbset_blida)",
            "source_url": source_url,
            "gdrive_file_id": None,
            "suggested_module_id": detected_mod,
            "suggested_course_id": None,
            "study_year": 7,  # 7 = Concours Résidanat
            "ai_summary": item.get("ai_summary", "Ressource médicale détectée via l'écosystème MBset."),
            "status": "pending",
            "discovered_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        })

    print(f"   ↳ {len(new_resources)} nouvelle(s) simulation/annonce inédite(s) trouvée(s).")
    return new_resources



def scan_mbset_categories_and_courses(
    client: MBSetClient,
    seen_ids: Set[str],
    limit_categories: int = 15,
) -> List[Dict[str, Any]]:
    """
    Scanne les catégories, cours et fiches de principes MBset (/categories, /principles).
    """
    print("🔬 [2/3] Analyse des catégories, cours et principes d'examen MBset...")
    new_resources: List[Dict[str, Any]] = []

    categories = client.get_categories()
    if not categories:
        print("   ↳ Aucune catégorie chargée.")
        return []

    print(f"   ↳ {len(categories)} modules disponibles dans le catalogue MBset.")

    for cat in categories[:limit_categories]:
        cat_id = str(cat.get("id") or cat.get("_id") or "")
        cat_name = cat.get("name") or "Module Médical"
        subcats = cat.get("subcategories") or cat.get("courses") or []

        # Créer ou mettre à jour la ressource "Banque de QCM du Module" si manquante
        module_res_id = generate_item_id("module_qcm", f"{cat_id}_{cat_name}")
        module_url = f"https://app.mbset.com/categories/{cat_id}" if cat_id else "https://app.mbset.com"

        if module_res_id not in seen_ids and module_url not in seen_ids:
            total_q = cat.get("questionsCount") or cat.get("total_questions") or 0
            seen_ids.add(module_res_id)
            seen_ids.add(module_url)

            new_resources.append({
                "id": module_res_id,
                "title": f"Banque QCM MBset : {cat_name} ({total_q} questions)",
                "resource_type": "qcm_exam",
                "source_type": "mbset",
                "source_origin": "api.mbset.com",
                "source_url": module_url,
                "gdrive_file_id": None,
                "suggested_module_id": detect_module_id(cat_name),
                "suggested_course_id": None,
                "study_year": 7,
                "ai_summary": (
                    f"Banque officielle de QCMs MBset pour le module {cat_name}. "
                    f"Comprend {len(subcats)} cours et environ {total_q} questions d'entraînement."
                ),
                "status": "pending",
                "discovered_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
            })

        # Pour chaque cours majeur, inspecter les principes d'examen
        for sub in subcats[:4]:
            sub_id = str(sub.get("id") or sub.get("_id") or "")
            sub_name = sub.get("name") or "Cours"
            if not sub_id:
                continue

            principle_res_id = generate_item_id("principle", f"{sub_id}_{sub_name}")
            principle_url = f"https://app.mbset.com/practice/principles/{sub_id}"

            if principle_res_id not in seen_ids and principle_url not in seen_ids:
                principles = client.get_course_principles(sub_id)
                if principles:
                    seen_ids.add(principle_res_id)
                    seen_ids.add(principle_url)

                    # Construire un résumé clair des points clés
                    points_summary = " ; ".join([p.get("text", "") for p in principles[:3] if isinstance(p, dict)])
                    if not points_summary and isinstance(principles[0], str):
                        points_summary = " ; ".join(principles[:3])

                    new_resources.append({
                        "id": principle_res_id,
                        "title": f"Fiche Pièges & Principes MBset : {sub_name} ({cat_name})",
                        "resource_type": "pdf_course",
                        "source_type": "mbset",
                        "source_origin": "api.mbset.com / principles",
                        "source_url": principle_url,
                        "gdrive_file_id": None,
                        "suggested_module_id": detect_module_id(cat_name),
                        "suggested_course_id": sub_id,
                        "study_year": 7,
                        "ai_summary": (
                            f"Fiche de révision haute rentabilité (High-Yield) pour le cours {sub_name}. "
                            f"{len(principles)} principes et pièges d'examen extraits de MBset. Points clés : {points_summary[:200]}"
                        ),
                        "status": "pending",
                        "discovered_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
                    })

    print(f"   ↳ {len(new_resources)} nouvelle(s) ressource(s) de modules/principes inédite(s) extraite(s).")
    return new_resources


def push_to_supabase_queue(
    new_items: List[Dict[str, Any]],
    supabase_url: str,
    supabase_key: str,
    dry_run: bool = False,
) -> int:
    """
    Envoie les ressources dans Supabase (table discovered_blida_resources + admin_system_settings).
    """
    if not new_items:
        print("✅ Aucune nouvelle ressource inédite à ajouter.")
        return 0

    if dry_run or not supabase_key:
        print(f"🧪 [DRY-RUN] {len(new_items)} ressource(s) prête(s) pour la file d'attente Admin :")
        for it in new_items[:10]:
            print(f"  - [{it['resource_type']}] {it['title']} ({it['source_origin']}) -> {it['source_url']}")
        return len(new_items)

    headers = {
        "apikey": supabase_key,
        "Authorization": f"Bearer {supabase_key}",
        "Content-Type": "application/json",
        "Prefer": "resolution=merge-duplicates",
    }

    inserted_count = 0

    # 1. Insertion dans public.discovered_blida_resources
    for i in range(0, len(new_items), 20):
        chunk = new_items[i : i + 20]
        try:
            req = urllib.request.Request(
                f"{supabase_url}/rest/v1/discovered_blida_resources",
                data=json.dumps(chunk, ensure_ascii=False).encode("utf-8"),
                headers=headers,
                method="POST",
            )
            with urllib.request.urlopen(req, timeout=12) as resp:
                if resp.status in (200, 201):
                    inserted_count += len(chunk)
        except urllib.error.HTTPError as err:
            err_msg = err.read().decode("utf-8", errors="ignore")
            print(f"⚠️ Insertion table Supabase ({err.code}): {err_msg[:200]}")
        except Exception as e:
            print(f"⚠️ Erreur insertion Supabase: {e}")

    # 2. Synchronisation dans admin_system_settings (discovered_blida_resources_queue)
    try:
        # Lire la file existante
        current_queue: List[Dict[str, Any]] = []
        try:
            req_get = urllib.request.Request(
                f"{supabase_url}/rest/v1/admin_system_settings?setting_key=eq.discovered_blida_resources_queue&select=setting_value",
                headers={
                    "apikey": supabase_key,
                    "Authorization": f"Bearer {supabase_key}",
                },
            )
            with urllib.request.urlopen(req_get, timeout=8) as r_get:
                data = json.loads(r_get.read().decode("utf-8"))
                if data and data[0].get("setting_value"):
                    current_queue = json.loads(data[0]["setting_value"])
        except Exception:
            pass

        # Fusionner avec les nouveaux en tête de liste
        merged = new_items + current_queue
        # Dé-doublonner par id
        seen = set()
        deduped = []
        for x in merged:
            x_id = x.get("id")
            if x_id and x_id not in seen:
                seen.add(x_id)
                deduped.append(x)
        deduped = deduped[:250]

        setting_payload = {
            "setting_key": "discovered_blida_resources_queue",
            "setting_value": json.dumps(deduped, ensure_ascii=False),
            "description": "File d'attente de validation Admin pour les ressources Blida & MBset",
        }

        req_set = urllib.request.Request(
            f"{supabase_url}/rest/v1/admin_system_settings",
            data=json.dumps(setting_payload, ensure_ascii=False).encode("utf-8"),
            headers=headers,
            method="POST",
        )
        with urllib.request.urlopen(req_set, timeout=10) as r_set:
            if r_set.status in (200, 201, 204):
                print(f"☁️ Synchronisé avec admin_system_settings (queue = {len(deduped)} éléments).")
    except Exception as e:
        print(f"ℹ️ Mise à jour admin_system_settings: {e}")

    # 3. Notification Admin dans medical_notifications
    if inserted_count > 0:
        try:
            notif_payload = {
                "title": f"⚡ Scanner MBset : {inserted_count} nouvelle(s) ressource(s)",
                "message": (
                    f"Le scanner d'API MBset a détecté {inserted_count} nouvelle(s) ressource(s) "
                    f"(simulations QCM, polycopiés, fiches principes). En attente de validation admin."
                ),
                "type": "system",
                "priority": "normal",
                "created_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
            }
            req_notif = urllib.request.Request(
                f"{supabase_url}/rest/v1/medical_notifications",
                data=json.dumps(notif_payload, ensure_ascii=False).encode("utf-8"),
                headers=headers,
                method="POST",
            )
            with urllib.request.urlopen(req_notif, timeout=6) as r_notif:
                if r_notif.status in (200, 201):
                    print("🔔 Notification d'alerte envoyée dans l'Admin Dashboard.")
        except Exception:
            pass

    # 4. Save local JSON cache for offline / repo sync
    try:
        assets_dir = ROOT_DIR / "assets" / "data"
        if assets_dir.exists():
            cache_file = assets_dir / "discovered_blida_resources.json"
            existing_cache = []
            if cache_file.exists():
                try:
                    existing_cache = json.loads(cache_file.read_text(encoding="utf-8"))
                except Exception:
                    existing_cache = []
            merged_cache = new_items + existing_cache
            seen_cache = set()
            deduped_cache = []
            for item in merged_cache:
                iid = item.get("id")
                if iid and iid not in seen_cache:
                    seen_cache.add(iid)
                    deduped_cache.append(item)
            cache_file.write_text(
                json.dumps(deduped_cache[:250], ensure_ascii=False, indent=2),
                encoding="utf-8",
            )
            print(f"💾 Cache local mis à jour : {cache_file} ({len(deduped_cache)} éléments).")
    except Exception as e:
        print(f"ℹ️ Mise à jour cache local: {e}")

    return inserted_count



def main():
    parser = argparse.ArgumentParser(description="Medsina Ultra — MBset Resource Scanner")
    parser.add_argument("--dry-run", action="store_true", help="Exécute sans écrire dans Supabase")
    parser.add_argument("--limit-categories", type=int, default=15, help="Nombre max de modules à scanner")
    parser.add_argument("--limit-items", type=int, default=40, help="Nombre max de ressources à injecter")
    args = parser.parse_args()

    supabase_url, supabase_key = resolve_supabase_credentials()

    print("=" * 70)
    print("🚀 MEDSINA ULTRA — SCANNER MBSET (API, TESTS & RESSOURCES)")
    print("=" * 70)

    # Initialisation du client MBset
    client = MBSetClient(supabase_url=supabase_url, supabase_key=supabase_key)
    logged_in = client.login()
    if logged_in:
        print("🔑 Connecté avec succès à l'API MBset avec jeton Firebase.")
    else:
        print("🌐 Mode d'analyse public & inspection des annonces actif.")

    # Récupération de l'existant
    _, seen_ids = fetch_existing_resources(supabase_url, supabase_key)
    print(f"📋 {len(seen_ids)} ressource(s) déjà connues dans Medsina.")

    # 1. Simulations & annonces
    new_sims = scan_mbset_simulations_and_announcements(client, seen_ids)

    # 2. Catégories, cours & principes
    new_cats = scan_mbset_categories_and_courses(client, seen_ids, limit_categories=args.limit_categories)

    total_candidates = new_sims + new_cats
    if args.limit_items and len(total_candidates) > args.limit_items:
        total_candidates = total_candidates[: args.limit_items]

    print("=" * 70)
    print(f"📦 Total de nouvelles ressources prêtes à valider : {len(total_candidates)}")

    inserted = push_to_supabase_queue(
        total_candidates,
        supabase_url=supabase_url,
        supabase_key=supabase_key,
        dry_run=args.dry_run,
    )

    print("=" * 70)
    print(f"🎉 Terminé avec succès ! {inserted} ressource(s) injectée(s) avec status='pending'.")
    print("L'administrateur peut maintenant les Approuver ou les Rejeter depuis l'Admin Dashboard.")
    print("=" * 70)


if __name__ == "__main__":
    main()
