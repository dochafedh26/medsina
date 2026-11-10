#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
=============================================================================
MEDSINA — MISE À JOUR DYNAMIQUE DU GUIDE DÉCOUVERTE PDF
=============================================================================
Télécharge la dernière version du guide officiel Medsina depuis Google Drive,
valide son intégrité binaire, met à jour l'asset local de secours et propage
les nouveaux paramètres dans Supabase (`admin_system_settings`) pour mise
à jour OTA instantanée sur toutes les plateformes (Android, Windows, Web).
=============================================================================
"""

import os
import sys
import argparse
import datetime
import urllib.request
import urllib.error
import json
from pathlib import Path

DEFAULT_GDRIVE_ID = "1JfS2J40ywxHJFJyPTdZuyRHYQZvoj-nN"
DEFAULT_SUPABASE_URL = "https://qzfssrhhuorljftpdvjm.supabase.co"
PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
DEFAULT_DEST = PROJECT_ROOT / "assets" / "data" / "Medsina_Guide_Decouverte_Fonctionnalites.pdf"


def download_pdf(download_url: str, dest_path: Path) -> int:
    """Télécharge le fichier PDF depuis l'URL de téléchargement direct."""
    print(f"📥 Téléchargement du PDF depuis : {download_url}")
    
    req = urllib.request.Request(
        download_url,
        headers={
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) MedsinaAutomation/1.0"
        }
    )
    
    with urllib.request.urlopen(req, timeout=45) as response:
        content = response.read()

    if not content:
        raise ValueError("Le fichier téléchargé est vide.")

    # Validation du format PDF
    if not content.startswith(b"%PDF-"):
        raise ValueError(
            f"Le fichier reçu n'est pas un document PDF valide (signature: {content[:10]!r}). "
            "Vérifiez que le fichier est bien partagé en mode public."
        )

    file_size = len(content)
    print(f"✅ Fichier PDF validé avec succès ({file_size / (1024 * 1024):.2f} Mo / {file_size:,} octets).")

    dest_path.parent.mkdir(parents=True, exist_ok=True)
    with open(dest_path, "wb") as f:
        f.write(content)
        
    print(f"💾 Fichier sauvegardé dans l'asset local : {dest_path}")
    return file_size


def update_supabase_setting(base_url: str, key: str, setting_key: str, setting_value: str, description: str = ""):
    """Met à jour ou insère un paramètre dans admin_system_settings via PostgREST."""
    endpoint = f"{base_url.rstrip('/')}/rest/v1/admin_system_settings"
    payload = json.dumps({
        "setting_key": setting_key,
        "setting_value": setting_value,
        "description": description,
        "updated_at": datetime.datetime.now(datetime.timezone.utc).isoformat()
    }).encode("utf-8")

    req = urllib.request.Request(
        endpoint,
        data=payload,
        headers={
            "apikey": key,
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
            "Prefer": "resolution=merge-duplicates"
        },
        method="POST"
    )

    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            print(f"   ✓ Supabase: {setting_key} mis à jour (HTTP {resp.status})")
    except urllib.error.HTTPError as err:
        err_body = err.read().decode("utf-8", errors="replace")
        print(f"   ⚠️ Échec mise à jour Supabase pour {setting_key} : HTTP {err.code} - {err_body}")


def main():
    parser = argparse.ArgumentParser(description="Mise à jour du Guide PDF Medsina (Google Drive & Supabase)")
    parser.add_argument("--gdrive-id", default=DEFAULT_GDRIVE_ID, help="Identifiant Google Drive du guide PDF")
    parser.add_argument("--url", default=None, help="URL de téléchargement direct (override)")
    parser.add_argument("--view-url", default=None, help="URL de consultation en ligne")
    parser.add_argument("--dest", default=str(DEFAULT_DEST), help="Chemin destination de l'asset local")
    parser.add_argument("--no-download", action="store_true", help="Ne pas télécharger l'asset local")
    parser.add_argument("--no-supabase", action="store_true", help="Ne pas mettre à jour Supabase")

    args = parser.parse_args()

    gdrive_id = args.gdrive_id.strip()
    download_url = args.url or f"https://drive.google.com/uc?export=download&id={gdrive_id}"
    view_url = args.view_url or f"https://drive.google.com/file/d/1JfS2J40ywxHJFJyPTdZuyRHYQZvoj-nN/view?usp=sharing"
    if args.gdrive_id != DEFAULT_GDRIVE_ID and not args.view_url:
        view_url = f"https://drive.google.com/file/d/{gdrive_id}/view?usp=sharing"

    dest_path = Path(args.dest)

    print("=" * 70)
    print("🚀 MEDSINA — SYNCHRONISATION DU GUIDE DÉCOUVERTE PDF")
    print(f"   • Google Drive ID : {gdrive_id}")
    print(f"   • Download Stream : {download_url}")
    print(f"   • View URL        : {view_url}")
    print("=" * 70)

    # 1. Téléchargement et validation
    file_size = 0
    if not args.no_download:
        try:
            file_size = download_pdf(download_url, dest_path)
        except Exception as e:
            print(f"❌ Erreur lors du téléchargement : {e}")
            sys.exit(1)
    else:
        print("⏭️ Téléchargement ignoré (--no-download).")

    # 2. Mise à jour Supabase
    if not args.no_supabase:
        supabase_url = os.environ.get("SUPABASE_URL", DEFAULT_SUPABASE_URL)
        supabase_key = (
            os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
            or os.environ.get("SUPABASE_KEY")
            or os.environ.get("SUPABASE_PUBLISHABLE_KEY")
            or "sb_publishable_E2OrqFqG1MbxVpoLb50jvA_DmOeP-UR"
        )
        print("\n☁️ Synchronisation avec Supabase admin_system_settings...")
        now_str = datetime.datetime.now(datetime.timezone.utc).isoformat()
        update_supabase_setting(
            supabase_url, supabase_key,
            "medsina_user_guide_gdrive_id", gdrive_id,
            "Identifiant Google Drive du guide officiel Medsina"
        )
        update_supabase_setting(
            supabase_url, supabase_key,
            "medsina_user_guide_url", download_url,
            "URL de streaming direct du guide officiel Medsina"
        )
        update_supabase_setting(
            supabase_url, supabase_key,
            "medsina_user_guide_view_url", view_url,
            "URL de visualisation Google Drive du guide officiel Medsina"
        )
        update_supabase_setting(
            supabase_url, supabase_key,
            "medsina_user_guide_updated_at", now_str,
            "Date et heure de dernière mise à jour du guide PDF Medsina"
        )
        if file_size > 0:
            update_supabase_setting(
                supabase_url, supabase_key,
                "medsina_user_guide_size_bytes", str(file_size),
                "Taille en octets du guide PDF Medsina officiel"
            )

    print("\n✨ Synchronisation du guide Medsina terminée avec succès !")


if __name__ == "__main__":
    main()
