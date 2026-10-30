#!/usr/bin/env python3
"""
Medsina & MedevSync Multi-Channel Facebook Automation Publisher
Allows publishing promotional posts, feature spotlights, and clinical pearls
directly to the 3 official Facebook Pages (Medsina, MedevSync, Résidanat Blida 2027) using Meta Graph API.
Credentials are automatically retrieved from Supabase admin_system_settings or environment variables.
"""

import os
import sys
import json
import argparse
import urllib.request
import urllib.parse
from typing import Optional, Dict, Any, List

SUPABASE_URL = os.environ.get("SUPABASE_URL", "https://qzfssrhhuorljftpdvjm.supabase.co")
SUPABASE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY") or os.environ.get(
    "SUPABASE_KEY",
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF6ZnNzcmhodW9ybGpmdHBkdmptIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MTYxMjg1NCwiZXhwIjoyMTA3MTg4ODU0fQ.-KCUgZdY8RDUwvNOUAabDhQFwv5FFGHYz0J-dM7Cic4"
)


def get_all_facebook_pages() -> List[Dict[str, str]]:
    pages_config = [
        {
            "key": "medsina",
            "name": "Medsina (Page Officielle)",
            "page_id": (os.environ.get("FB_MEDSINA_PAGE_ID") or "1449308354921826").strip(),
            "token": (os.environ.get("FB_MEDSINA_PAGE_ACCESS_TOKEN") or "").strip(),
            "db_id_key": "facebook_medsina_page_id",
            "db_token_key": "facebook_medsina_page_access_token",
        },
        {
            "key": "medevsync",
            "name": "MedevSync (Page Partenaire)",
            "page_id": (os.environ.get("FB_MEDEVSYNC_PAGE_ID") or "1329939320211198").strip(),
            "token": (os.environ.get("FB_MEDEVSYNC_PAGE_ACCESS_TOKEN") or "").strip(),
            "db_id_key": "facebook_medevsync_page_id",
            "db_token_key": "facebook_medevsync_page_access_token",
        },
        {
            "key": "residanat_blida_2027",
            "name": "Résidanat Blida 2027 (Page Communauté)",
            "page_id": (os.environ.get("FB_BLIDA_PAGE_ID") or "1405719695953624").strip(),
            "token": (os.environ.get("FB_BLIDA_PAGE_ACCESS_TOKEN") or "").strip(),
            "db_id_key": "facebook_blida_page_id",
            "db_token_key": "facebook_blida_page_access_token",
        },
    ]

    try:
        url = f"{SUPABASE_URL}/rest/v1/admin_system_settings?select=setting_key,setting_value"
        req = urllib.request.Request(
            url,
            headers={"apikey": SUPABASE_KEY, "Authorization": f"Bearer {SUPABASE_KEY}"}
        )
        with urllib.request.urlopen(req, timeout=10) as resp:
            rows = json.loads(resp.read().decode("utf-8"))
            settings = {r.get("setting_key"): r.get("setting_value") for r in rows if isinstance(r, dict)}
            for p in pages_config:
                if not p["token"]:
                    p["token"] = (settings.get(p["db_token_key"]) or "").strip()
                if not p["page_id"]:
                    p["page_id"] = (settings.get(p["db_id_key"]) or "").strip()
            if not pages_config[2]["token"]:
                pages_config[2]["token"] = (settings.get("facebook_page_access_token") or "").strip()
    except Exception as e:
        print(f"Warning: Could not fetch Facebook credentials from Supabase: {e}", file=sys.stderr)

    return [p for p in pages_config if p["page_id"] and p["token"]]


def get_facebook_credentials() -> Dict[str, str]:
    pages = get_all_facebook_pages()
    medsina = next((p for p in pages if p["key"] == "medsina"), None)
    if medsina:
        return {"page_id": medsina["page_id"], "page_token": medsina["token"]}
    if pages:
        return {"page_id": pages[0]["page_id"], "page_token": pages[0]["token"]}
    raise ValueError("Missing Facebook credentials (no active page found).")


def add_followers_comment(
    target_id: str,
    token: str,
    comment_text: str = "@followers 🩺 Partagez avec vos confrères et activez les notifications pour ne rien manquer !",
) -> Dict[str, Any]:
    """
    Poste un commentaire sous la publication avec la mention @followers pour taguer tous les abonnés.
    Si le jeton de page possède la permission pages_manage_engagement, le commentaire est publié en direct.
    """
    url = f"https://graph.facebook.com/v21.0/{target_id}/comments"
    payload = {
        "message": comment_text,
        "access_token": token,
    }
    encoded_data = urllib.parse.urlencode(payload).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=encoded_data,
        method="POST",
        headers={"User-Agent": "MedsinaPublisher/1.0"},
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            comment_id = data.get("id")
            print(f"   💬 Commentaire @followers ajouté avec succès ! ID: {comment_id}")
            return {"success": True, "comment_id": comment_id}
    except urllib.error.HTTPError as e:
        err_body = e.read().decode("utf-8")
        print(f"   ℹ️ Notice commentaire @followers ({e.code}) : {err_body}")
        return {"success": False, "error": err_body}
    except Exception as e:
        print(f"   ℹ️ Notice commentaire @followers : {e}")
        return {"success": False, "error": str(e)}


def publish_to_page_feed(page_id: str, token: str, message: str, link: Optional[str] = None) -> Dict[str, Any]:
    url = f"https://graph.facebook.com/v21.0/{page_id}/feed"
    payload = {
        "message": message,
        "access_token": token,
    }
    if link:
        payload["link"] = link

    encoded_data = urllib.parse.urlencode(payload).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=encoded_data,
        method="POST",
        headers={"User-Agent": "MedsinaPublisher/1.0"},
    )
    with urllib.request.urlopen(req, timeout=20) as resp:
        res = json.loads(resp.read().decode("utf-8"))
        post_id = res.get("id")
        if post_id:
            add_followers_comment(
                target_id=post_id,
                token=token,
                comment_text="@followers 🩺 Partagez avec vos confrères et activez les notifications pour ne rien manquer !",
            )
        return res


def publish_facebook_post(message: str, link: Optional[str] = None) -> Dict[str, Any]:
    """Publies a text post (with optional link) to all 3 Facebook page feeds."""
    pages = get_all_facebook_pages()
    if not pages:
        raise ValueError("Aucune page Facebook configurée.")

    results = []
    for p in pages:
        name = p["name"]
        page_id = p["page_id"]
        token = p["token"]
        print(f"   🚀 Publication en cours sur {name} (ID: {page_id})...")
        try:
            res = publish_to_page_feed(page_id, token, message, link)
            post_id = res.get("id")
            print(f"   🎉 SUCCÈS sur {name} ! Post ID: {post_id}")
            results.append({"page": p["key"], "name": name, "id": post_id, "success": True})
        except Exception as e:
            print(f"   ❌ Erreur sur {name}: {e}")
            results.append({"page": p["key"], "name": name, "error": str(e), "success": False})

    medsina_res = next((r for r in results if r.get("page") == "medsina" and r.get("success")), None)
    if medsina_res:
        return {"id": medsina_res.get("id"), "all_results": results}
    first_ok = next((r for r in results if r.get("success")), None)
    if first_ok:
        return {"id": first_ok.get("id"), "all_results": results}
    raise RuntimeError(f"Échec de publication sur toutes les pages: {results}")


def main():
    parser = argparse.ArgumentParser(description="Publish a post across the 3 official Facebook pages.")
    parser.add_argument("--message", type=str, required=True, help="Post text content")
    parser.add_argument("--link", type=str, default=None, help="Optional URL to attach to the post")
    args = parser.parse_args()

    print("🚀 Publishing post to all 3 Facebook Pages (Medsina, MedevSync, Résidanat Blida 2027)...")
    try:
        res = publish_facebook_post(args.message, link=args.link)
        print(f"✅ Multichannel publication completed! Primary ID: {res.get('id')}")
    except Exception as e:
        print(f"❌ Error publishing post: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
