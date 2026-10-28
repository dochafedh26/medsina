#!/usr/bin/env python3
"""
Medsina & MedevSync Facebook Post Migration Pipeline
Extracts historical posts (infographics, clinical pearls, QCMs, memos)
from MedevSync (1329939320211198) and migrates them to Medsina (1449308354921826).

Features:
- Pagination across all historical published posts.
- Downloads full-resolution media attachments to local cache.
- Publishes chronologically (oldest to newest) to preserve historical timeline.
- Deduplication manifest to ensure zero duplicate posts.
- Rate limiting & safety pauses (5s) between posts.
- Optional --delete-source flag to delete posts from MedevSync once migrated.
"""

import os
import sys
import json
import time
import argparse
import urllib.request
import urllib.parse
from pathlib import Path
from typing import Dict, Any, List, Optional

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

MEDEV_PAGE_ID_DEFAULT = "1329939320211198"
MEDSINA_PAGE_ID_DEFAULT = "1449308354921826"

SCRIPT_DIR = Path(__file__).resolve().parent
MEDSINA_ROOT = SCRIPT_DIR.parent.parent
CACHE_DIR = MEDSINA_ROOT / "assets" / "facebook" / "migration_cache"
MANIFEST_FILE = CACHE_DIR / "migration_manifest.json"


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


def load_manifest() -> Dict[str, Any]:
    if MANIFEST_FILE.exists():
        try:
            with open(MANIFEST_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            pass
    return {"migrated_posts": {}, "downloaded_posts": {}}


def save_manifest(manifest: Dict[str, Any]):
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    with open(MANIFEST_FILE, "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)


def fetch_all_medevsync_posts(medev_token: str, medev_id: str) -> List[Dict[str, Any]]:
    """Fetches all published posts from MedevSync using Graph API pagination."""
    all_posts = []
    base_url = f"https://graph.facebook.com/v21.0/{medev_id}/published_posts"
    fields = "id,message,created_time,story,full_picture,attachments{type,media,title,url,target,subattachments}"
    url = f"{base_url}?fields={fields}&limit=25&access_token={medev_token}"

    page_num = 1
    while url:
        print(f"   ⏳ Récupération de la page {page_num} des publications MedevSync...")
        try:
            resp = requests.get(url, timeout=20)
            if resp.status_code != 200:
                print(f"   ❌ Erreur Graph API ({resp.status_code}) : {resp.text}", file=sys.stderr)
                break
            data = resp.json()
            posts = data.get("data", [])
            all_posts.extend(posts)
            url = data.get("paging", {}).get("next")
            page_num += 1
        except Exception as e:
            print(f"   ❌ Exception lors de la pagination : {e}", file=sys.stderr)
            break

    print(f"   ✅ Total de {len(all_posts)} publications trouvées sur MedevSync.")
    return all_posts


def download_post_media(post: Dict[str, Any], manifest: Dict[str, Any]) -> Optional[Path]:
    """Downloads the highest resolution image for a post."""
    post_id = post["id"]
    CACHE_DIR.mkdir(parents=True, exist_ok=True)

    # 1. Determine media URL
    media_url = None
    atts = post.get("attachments", {}).get("data", [])
    if atts:
        media_obj = atts[0].get("media", {})
        if "image" in media_obj and "src" in media_obj["image"]:
            media_url = media_obj["image"]["src"]

    if not media_url and post.get("full_picture"):
        media_url = post["full_picture"]

    if not media_url:
        return None

    filename = f"post_{post_id.split('_')[-1]}.jpg"
    dest_path = CACHE_DIR / filename

    if dest_path.exists() and dest_path.stat().st_size > 1000:
        return dest_path

    try:
        r = requests.get(media_url, timeout=30)
        if r.status_code == 200:
            with open(dest_path, "wb") as f:
                f.write(r.content)
            manifest["downloaded_posts"][post_id] = {
                "local_file": str(dest_path.name),
                "created_time": post.get("created_time"),
                "size_bytes": len(r.content),
            }
            save_manifest(manifest)
            return dest_path
    except Exception as e:
        print(f"   ⚠️ Impossible de télécharger le média pour {post_id} : {e}")

    return None


def publish_post_to_medsina(
    post: Dict[str, Any],
    media_path: Optional[Path],
    medsina_token: str,
    medsina_id: str,
) -> Dict[str, Any]:
    """Publishes a post (photo, video, or status) to the Medsina page."""
    caption = post.get("message") or post.get("story") or ""
    
    # Check post type from attachments
    atts = post.get("attachments", {}).get("data", [])
    post_type = atts[0].get("type") if atts else "status"

    # 1. Photo Post
    if media_path and media_path.exists() and post_type in ["photo", "cover_photo", "profile_media", "album", "share"]:
        url = f"https://graph.facebook.com/v21.0/{medsina_id}/photos"
        with open(media_path, "rb") as img_file:
            files = {"source": (media_path.name, img_file, "image/jpeg")}
            data = {"caption": caption, "access_token": medsina_token}
            r = requests.post(url, data=data, files=files, timeout=60)
            if r.status_code == 200:
                return r.json()
            else:
                raise RuntimeError(f"Photo publish failed ({r.status_code}): {r.text}")

    # 2. Text / Status Post
    url = f"https://graph.facebook.com/v21.0/{medsina_id}/feed"
    payload = {"message": caption, "access_token": medsina_token}
    r = requests.post(url, data=payload, timeout=30)
    if r.status_code == 200:
        return r.json()
    else:
        raise RuntimeError(f"Feed post failed ({r.status_code}): {r.text}")


def main():
    parser = argparse.ArgumentParser(description="Pipeline de migration des publications MedevSync vers Medsina.")
    parser.add_argument("--dry-run", action="store_true", help="Inventaire et simulation sans publication")
    parser.add_argument("--download-only", action="store_true", help="Télécharger tous les médias et textes en local")
    parser.add_argument("--migrate", action="store_true", help="Exécuter la migration réelle vers Medsina")
    parser.add_argument("--token", type=str, default=None, help="Page Access Token pour Medsina (avec pages_manage_posts)")
    parser.add_argument("--limit", type=int, default=None, help="Nombre maximal de posts à traiter (pour test unitaire)")
    parser.add_argument("--delay", type=float, default=6.0, help="Délai en secondes entre deux publications (défaut: 6.0s)")
    parser.add_argument("--delete-source", action="store_true", help="Supprimer de MedevSync après confirmation de copie")
    args = parser.parse_args()

    print("=" * 75)
    print("📦 PIPELINE DE MIGRATION FACEBOOK : MEDEVSYNC ➡️ MEDSINA")
    print(f"📁 Dossier de cache local : {CACHE_DIR}")
    print("=" * 75)

    settings = fetch_supabase_settings()
    medev_id = settings.get("facebook_medevsync_page_id") or MEDEV_PAGE_ID_DEFAULT
    medev_token = settings.get("facebook_medevsync_page_access_token")

    medsina_id = settings.get("facebook_medsina_page_id") or MEDSINA_PAGE_ID_DEFAULT
    medsina_token = args.token or settings.get("facebook_medsina_page_access_token")

    if not medev_token:
        print("❌ Erreur : facebook_medevsync_page_access_token manquant dans Supabase.", file=sys.stderr)
        sys.exit(1)

    manifest = load_manifest()

    print("\n🔍 1. Inventaire des publications MedevSync...")
    posts = fetch_all_medevsync_posts(medev_token, medev_id)
    if not posts:
        print("❌ Aucune publication récupérée.", file=sys.stderr)
        sys.exit(1)

    # Filter out empty or duplicate posts if any
    valid_posts = [p for p in posts if p.get("message") or p.get("full_picture")]
    print(f"   • {len(valid_posts)} publications valides prêtes pour migration.")

    # Chronological sort (oldest to newest)
    valid_posts.sort(key=lambda x: x.get("created_time", ""))

    if args.limit:
        valid_posts = valid_posts[:args.limit]
        print(f"   • Limitation appliquée : {len(valid_posts)} publication(s).")

    print("\n📥 2. Téléchargement et mise en cache des médias HD...")
    downloaded_count = 0
    post_media_map = {}
    for idx, p in enumerate(valid_posts, 1):
        pid = p["id"]
        created = p.get("created_time", "")[:10]
        desc = (p.get("message") or p.get("story") or "Sans texte")[:45].replace("\n", " ")
        print(f"   [{idx}/{len(valid_posts)}] ({created}) {desc}...")
        media_path = download_post_media(p, manifest)
        if media_path:
            post_media_map[pid] = media_path
            downloaded_count += 1

    print(f"   ✅ {downloaded_count} médias sauvegardés dans {CACHE_DIR}")

    # Mode Dry-Run ou Download-Only
    if args.dry_run or args.download_only or not args.migrate:
        print("\n" + "=" * 75)
        print("🧪 MODE SIMULATION / TÉLÉCHARGEMENT TERMINÉ")
        print(f"   • Publications analysées : {len(valid_posts)}")
        print(f"   • Médias prêts en local   : {downloaded_count}")
        print(f"   • Déjà migrées (manifeste) : {len(manifest.get('migrated_posts', {}))}")
        print(f"\n👉 Pour lancer la publication vers Medsina, exécutez :")
        print(f"   python medsina/scripts/automation/migrate_posts_to_medsina.py --migrate --token <MEDSINA_PAGE_ACCESS_TOKEN>")
        print("=" * 75)
        return

    # Mode Migration Réelle
    if not medsina_token:
        print("\n❌ Erreur : Un jeton avec 'pages_manage_posts' pour la page Medsina est requis pour migrer.", file=sys.stderr)
        print("   Utilisez le paramètre --token <MEDSINA_TOKEN>.", file=sys.stderr)
        sys.exit(1)

    print("\n🚀 3. Migration en cours vers la page Medsina...")
    migrated_count = 0
    for idx, p in enumerate(valid_posts, 1):
        pid = p["id"]
        if pid in manifest["migrated_posts"]:
            print(f"   ⏩ [{idx}/{len(valid_posts)}] Déjà migré : {pid} -> Medsina ID: {manifest['migrated_posts'][pid].get('new_id')}")
            continue

        created = p.get("created_time", "")[:10]
        media_path = post_media_map.get(pid)
        print(f"   ⏳ [{idx}/{len(valid_posts)}] ({created}) Publication sur Medsina...")

        try:
            res = publish_post_to_medsina(p, media_path, medsina_token, medsina_id)
            new_id = res.get("id") or res.get("post_id")
            manifest["migrated_posts"][pid] = {
                "medsina_post_id": new_id,
                "migrated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                "original_created_time": p.get("created_time"),
            }
            save_manifest(manifest)
            migrated_count += 1
            print(f"      ✅ Succès ! Medsina Post ID : {new_id}")

            # Optional delete source
            if args.delete_source:
                try:
                    del_url = f"https://graph.facebook.com/v21.0/{pid}?access_token={medev_token}"
                    del_resp = requests.delete(del_url, timeout=10)
                    if del_resp.status_code == 200:
                        print(f"      🗑️ Supprimé de MedevSync : {pid}")
                except Exception as del_err:
                    print(f"      ⚠️ Échec suppression MedevSync : {del_err}")

            time.sleep(args.delay)
        except Exception as e:
            print(f"      ❌ Erreur publication : {e}", file=sys.stderr)

    print("\n" + "=" * 75)
    print("✨ MIGRATION TERMINÉE !")
    print(f"   • Total migré : {migrated_count} / {len(valid_posts)}")
    print(f"   • Journal de suivi : {MANIFEST_FILE}")
    print("=" * 75)


if __name__ == "__main__":
    main()
