#!/usr/bin/env python3
"""
Medsina & MedevSync Multi-Page Video Publisher
Publishes the promotional video spot to the 3 official Facebook pages:
1. Résidanat Blida 2027 (ID: 1405719695953624)
2. Medsina (ID: 1449308354921826)
3. MedevSync (ID: 1329939320211198)

Uses Facebook Graph Video API:
POST https://graph-video.facebook.com/v21.0/{page_id}/videos
"""

import os
import sys
import json
import argparse
import urllib.request
import urllib.parse
from pathlib import Path
from typing import Dict, Any, Optional

if sys.stdout and hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

import requests

SUPABASE_URL = os.environ.get("SUPABASE_URL", "https://qzfssrhhuorljftpdvjm.supabase.co")
SUPABASE_KEY = os.environ.get(
    "SUPABASE_SERVICE_ROLE_KEY",
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF6ZnNzcmhodW9ybGpmdHBkdmptIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MTYxMjg1NCwiZXhwIjoyMTA3MTg4ODU0fQ.-KCUgZdY8RDUwvNOUAabDhQFwv5FFGHYz0J-dM7Cic4"
)

SCRIPT_DIR = Path(__file__).resolve().parent
MEDSINA_ROOT = SCRIPT_DIR.parent.parent
POSTS_DIR = MEDSINA_ROOT / "assets" / "facebook" / "posts"
DEFAULT_VIDEO = MEDSINA_ROOT / "assets" / "facebook" / "medsina_spot_deux_etudiants_1080p.mp4"

PAGES_CONFIG = {
    "blida": {
        "name": "Résidanat Blida 2027",
        "page_id_setting": "facebook_blida_page_id",
        "default_id": "1405719695953624",
        "token_setting": "facebook_page_access_token",
        "post_file": POSTS_DIR / "post_residanat_blida.txt",
        "video_title": "Résidanat 2027 : Révisez avec méthode grâce à Medsina",
    },
    "medsina": {
        "name": "Medsina (Page Officielle)",
        "page_id_setting": "facebook_medsina_page_id",
        "default_id": "1449308354921826",
        "token_setting": "facebook_medsina_page_access_token",
        "post_file": POSTS_DIR / "post_medsina.txt",
        "video_title": "Deux étudiants. Deux façons de réviser. Découvrez Medsina.",
    },
    "medevsync": {
        "name": "MedevSync",
        "page_id_setting": "facebook_medevsync_page_id",
        "default_id": "1329939320211198",
        "token_setting": "facebook_medevsync_page_access_token",
        "post_file": POSTS_DIR / "post_medevsync.txt",
        "video_title": "Innovation Médicale : Pourquoi Medsina change la donne",
    },
}


def fetch_supabase_settings() -> Dict[str, str]:
    """Fetches all system settings from Supabase."""
    settings = {}
    try:
        url = f"{SUPABASE_URL}/rest/v1/admin_system_settings?select=setting_key,setting_value"
        req = urllib.request.Request(
            url,
            headers={
                "apikey": SUPABASE_KEY,
                "Authorization": f"Bearer {SUPABASE_KEY}",
            }
        )
        with urllib.request.urlopen(req, timeout=10) as resp:
            rows = json.loads(resp.read().decode("utf-8"))
            for r in rows:
                settings[r.get("setting_key")] = r.get("setting_value", "")
    except Exception as e:
        print(f"⚠️ Avertissement : Impossible de récupérer les paramètres Supabase ({e})", file=sys.stderr)
    return settings


def publish_video_to_page(
    page_id: str,
    access_token: str,
    video_path: Path,
    description: str,
    title: str,
    dry_run: bool = False,
) -> Dict[str, Any]:
    """Publishes a video to Facebook using Graph Video API."""
    if dry_run:
        return {
            "id": f"dry_run_{page_id}_{int(os.path.getsize(video_path))}",
            "status": "SIMULATION_SUCCESS",
        }

    url = f"https://graph-video.facebook.com/v21.0/{page_id}/videos"

    data = {
        "description": description,
        "title": title,
        "access_token": access_token,
    }

    with open(video_path, "rb") as video_file:
        files = {
            "source": (video_path.name, video_file, "video/mp4"),
        }
        resp = requests.post(url, data=data, files=files, timeout=300)

    if resp.status_code == 200:
        return resp.json()
    else:
        raise RuntimeError(f"Facebook Graph API Error ({resp.status_code}): {resp.text}")


def main():
    parser = argparse.ArgumentParser(description="Publier le spot vidéo Medsina sur les 3 pages Facebook officielles.")
    parser.add_argument(
        "--page",
        choices=["blida", "medsina", "medevsync", "all"],
        default="all",
        help="Page cible (blida, medsina, medevsync ou all)",
    )
    parser.add_argument(
        "--video",
        type=str,
        default=str(DEFAULT_VIDEO),
        help="Chemin de la vidéo MP4 à téléverser",
    )
    parser.add_argument(
        "--token",
        type=str,
        default=None,
        help="Token manuel (écrasant Supabase si fourni)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Mode simulation (vérifie les fichiers et tokens sans publier)",
    )
    parser.add_argument(
        "--publish",
        action="store_true",
        help="Exécute la publication réelle",
    )
    args = parser.parse_args()

    dry_run = args.dry_run or not args.publish
    video_path = Path(args.video)

    print("=" * 70)
    print("📢 DIFFUSION VIDÉO MULTI-PAGE FACEBOOK (MEDSINA & MEDEVSYNC)")
    print(f"🎬 Vidéo source : {video_path}")
    print(f"📁 Taille vidéo : {round(video_path.stat().st_size / (1024*1024), 2)} Mo")
    print(f"⚙️ Mode         : {'🧪 SIMULATION (--dry-run)' if dry_run else '🚀 PUBLICATION RÉELLE'}")
    print("=" * 70)

    if not video_path.exists():
        print(f"❌ Erreur : Le fichier vidéo n'existe pas : {video_path}", file=sys.stderr)
        sys.exit(1)

    settings = fetch_supabase_settings()

    targets = list(PAGES_CONFIG.keys()) if args.page == "all" else [args.page]

    for target_key in targets:
        cfg = PAGES_CONFIG[target_key]
        print(f"\n👉 Traitement de la page : {cfg['name']}")

        # 1. Résolution de l'ID de page
        page_id = settings.get(cfg["page_id_setting"]) or cfg["default_id"]
        print(f"   • Page ID : {page_id}")

        # 2. Résolution du Token
        token = args.token if (args.token and args.page == target_key) else settings.get(cfg["token_setting"])
        if not token and target_key == "blida":
            token = settings.get("facebook_page_access_token")

        if not token:
            print(f"   ⚠️ Token d'accès manquant pour '{cfg['name']}'.")
            print(f"      -> Renseignez '{cfg['token_setting']}' dans Supabase ou via --token.")
            continue

        # 3. Lecture du texte
        post_file = cfg["post_file"]
        if not post_file.exists():
            print(f"   ❌ Fichier texte introuvable : {post_file}", file=sys.stderr)
            continue

        with open(post_file, "r", encoding="utf-8") as f:
            caption = f.read().strip()

        print(f"   • Fichier texte : {post_file.name} ({len(caption)} caractères)")
        print(f"   • Titre vidéo   : {cfg['video_title']}")

        # 4. Publication ou test
        try:
            print("   ⏳ Téléversement de la vidéo...")
            result = publish_video_to_page(
                page_id=page_id,
                access_token=token,
                video_path=video_path,
                description=caption,
                title=cfg["video_title"],
                dry_run=dry_run,
            )
            video_id = result.get("id")
            print(f"   ✅ Succès ! Video ID Facebook : {video_id}")
            if not dry_run:
                print(f"   🔗 Lien direct : https://facebook.com/{video_id}")
        except Exception as e:
            print(f"   ❌ Échec du téléversement : {e}", file=sys.stderr)

    print("\n" + "=" * 70)
    print("✨ Opération terminée avec succès.")
    print("=" * 70)


if __name__ == "__main__":
    main()
