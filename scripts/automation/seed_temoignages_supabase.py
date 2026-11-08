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
        items = json.load(f)

    print(f"📦 Synchronisation de {len(items)} témoignages vers Supabase ({url})...")
    endpoint = f"{url}/rest/v1/temoignages_conseils"
    headers = {
        "apikey": key,
        "Authorization": f"Bearer {key}",
        "Content-Type": "application/json",
        "Prefer": "resolution=merge-duplicates"
    }

    resp = requests.post(endpoint, headers=headers, json=items)
    if resp.status_code in (200, 201, 204):
        print(f"✅ {len(items)} témoignages insérés / mis à jour avec succès dans Supabase !")
    else:
        print(f"⚠️ Erreur insertion Supabase ({resp.status_code}): {resp.text}")
        sys.exit(1)

if __name__ == "__main__":
    main()
