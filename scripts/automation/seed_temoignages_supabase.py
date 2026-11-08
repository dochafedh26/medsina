#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
=============================================================================
MEDSINA — SYNC TÉMOIGNAGES & CONSEILS TO SUPABASE
=============================================================================
Transfère et synchronise tous les témoignages depuis temoignages_conseils.json
vers la table Supabase `public.temoignages_conseils`.
=============================================================================
"""

import os
import sys
import json
import requests
from pathlib import Path

DEFAULT_SUPABASE_URL = "https://qzfssrhhuorljftpdvjm.supabase.co"
PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
JSON_PATH = PROJECT_ROOT / "assets" / "data" / "temoignages_conseils.json"

def main():
    url = os.environ.get("SUPABASE_URL", DEFAULT_SUPABASE_URL).rstrip("/")
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY") or os.environ.get("SUPABASE_KEY")

    if not key:
        env_file = PROJECT_ROOT / ".env"
        if env_file.exists():
            for line in env_file.read_text(encoding="utf-8").splitlines():
                if line.startswith("SUPABASE_SERVICE_ROLE_KEY="):
                    key = line.split("=", 1)[1].strip().strip('"').strip("'")
                    break

    if not key:
        print("❌ Clé SUPABASE_SERVICE_ROLE_KEY absente. Exécution annulée.")
        sys.exit(1)

    if not JSON_PATH.exists():
        print(f"❌ Fichier introuvable : {JSON_PATH}")
        sys.exit(1)

    with open(JSON_PATH, "r", encoding="utf-8") as f:
        raw_items = json.load(f)

    # PostgREST exige que TOUS les objets d'une liste JSON aient exactement les mêmes clés
    standard_keys = [
        "id", "name", "rank_badge", "rank_number", "year", "faculty",
        "is_recent_2026", "document_type", "target_url", "gdrive_folder_url",
        "telegram_url", "gdrive_id", "extra_gdrive_id", "pdf_file",
        "extra_pdf_file", "summary", "key_advices", "recommended_sources"
    ]

    normalized_items = []
    for it in raw_items:
        row = {}
        for k in standard_keys:
            val = it.get(k)
            if k == "key_advices" and val is None:
                val = []
            elif k == "is_recent_2026" and val is None:
                val = False
            elif k == "rank_number" and val is None:
                val = 99
            row[k] = val
        normalized_items.append(row)

    print(f"📦 Synchronisation de {len(normalized_items)} témoignages vers Supabase ({url})...")
    endpoint = f"{url}/rest/v1/temoignages_conseils"
    headers = {
        "apikey": key,
        "Authorization": f"Bearer {key}",
        "Content-Type": "application/json",
        "Prefer": "resolution=merge-duplicates"
    }

    # Insère un par un ou en batch normalisé
    success_count = 0
    for row in normalized_items:
        r = requests.post(endpoint, headers=headers, json=row)
        if r.status_code in (200, 201, 204):
            success_count += 1
        else:
            print(f"⚠️ Erreur insertion {row.get('id')} ({r.status_code}): {r.text}")

    print(f"✅ {success_count}/{len(normalized_items)} témoignages insérés / mis à jour avec succès dans Supabase !")
    if success_count == 0:
        sys.exit(1)

if __name__ == "__main__":
    main()
