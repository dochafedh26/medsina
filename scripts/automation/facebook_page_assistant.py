#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Facebook Page Automated Assistant & Comment Responder
=====================================================
Monitors posts on Medsina & MedevSync Facebook Pages, detects user comments
and questions, and automatically responds with official links and guidance.

Capabilities:
1. Scans recent posts on all connected Facebook Pages.
2. Identifies user comments and questions (e.g. liens, téléchargement, offline, prix, résidanat).
3. Posts courteous, official page replies.
4. Tracks replied comment IDs in JSON to avoid any duplicate responses.
"""

import os
import sys
import json
import time
from pathlib import Path
from typing import Dict, Any, List
import requests

if sys.stdout and hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))

from facebook_post_generator import get_all_facebook_pages

PROCESSED_COMMENTS_FILE = SCRIPT_DIR / "facebook_processed_comments.json"

OFFICIAL_LINKS = {
    "web": "https://medsina.medevsync.com",
    "apk": "https://medsina.medevsync.com/download/medsina.apk",
    "win": "https://medsina.medevsync.com/download/medsina-setup.exe",
    "telegram": "https://t.me/medsina_officiel",
}


def load_processed_comments() -> set:
    if PROCESSED_COMMENTS_FILE.exists():
        try:
            with open(PROCESSED_COMMENTS_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
                return set(data.get("processed_comment_ids", []))
        except Exception:
            return set()
    return set()


def save_processed_comment(comment_id: str):
    processed = load_processed_comments()
    processed.add(str(comment_id))
    with open(PROCESSED_COMMENTS_FILE, "w", encoding="utf-8") as f:
        json.dump({"processed_comment_ids": list(processed), "updated_at": time.time()}, f, indent=2)


def generate_page_reply(comment_message: str) -> str:
    msg = comment_message.lower()

    if any(k in msg for k in ["lien", "link", "telecharger", "télécharger", "download", "installer", "apk", "pc", "windows"]):
        return (
            "Bonjour Dr. ! 🩺 Voici les liens d'accès officiels à la plateforme Medsina :\n"
            f"🌐 Accès Web direct : {OFFICIAL_LINKS['web']}\n"
            f"📱 Application Android (.apk) : {OFFICIAL_LINKS['apk']}\n"
            f"💻 Logiciel PC Windows (.exe) : {OFFICIAL_LINKS['win']}\n"
            "Bonne révision et excellent succès !"
        )

    if any(k in msg for k in ["prix", "tarif", "combien", "abonnement", "vip", "gratuit"]):
        return (
            "Bonjour ! 🌟 L'accès initial à Medsina comprend l'exploration de tous les modules, les QCMs d'entraînement et les fiches cliniques. "
            "Les options VIP tout-inclus et hors-ligne sont détaillées directement dans l'application :\n"
            f"👉 Rendez-vous sur : {OFFICIAL_LINKS['web']}"
        )

    if any(k in msg for k in ["offline", "hors ligne", "sans connexion", "internet", "garde"]):
        return (
            "Bonjour confrère ! ✅ Oui, Medsina intègre un Mode 100% Hors-Ligne avec téléchargement individuel ou par pack de modules complets. "
            "Vous pouvez réviser et consulter vos fiches aux urgences sans aucune connexion internet, avec synchronisation cloud automatique au retour du réseau.\n"
            f"👉 Disponible dès maintenant sur {OFFICIAL_LINKS['web']}"
        )

    # General supportive answer
    return (
        "Bonjour Dr. ! 🩺 Merci pour votre intérêt. Retrouvez l'ensemble des cours, annales officielles du concours et outils cliniques sur la plateforme Medsina :\n"
        f"🔗 Accès officiel : {OFFICIAL_LINKS['web']}\n"
        f"📢 Canal Telegram : {OFFICIAL_LINKS['telegram']}"
    )


def process_page_comments(dry_run: bool = True):
    pages = get_all_facebook_pages()
    processed = load_processed_comments()

    print(f"🔍 Surveillance des commentaires sur {len(pages)} Page(s) Facebook...")

    for page in pages:
        page_name = page.get("name")
        page_id = page.get("page_id")
        token = page.get("token")

        if not token:
            continue

        print(f"\n📄 Vérification de la Page : {page_name} ({page_id})")

        # 1. Fetch recent posts from the page
        posts_url = f"https://graph.facebook.com/v21.0/{page_id}/posts?fields=id,message,created_time&limit=5&access_token={token}"
        try:
            res = requests.get(posts_url, timeout=15)
            if res.status_code != 200:
                print(f"   ⚠️ Impossible de lire les posts de {page_name} ({res.status_code})")
                continue

            posts = res.json().get("data", [])
            print(f"   📋 {len(posts)} publication(s) récente(s) analysée(s).")

            for post in posts:
                post_id = post["id"]
                # 2. Fetch comments on each post
                comments_url = f"https://graph.facebook.com/v21.0/{post_id}/comments?fields=id,from,message,created_time&limit=15&access_token={token}"
                c_res = requests.get(comments_url, timeout=15)
                if c_res.status_code != 200:
                    continue

                comments = c_res.json().get("data", [])
                for comment in comments:
                    c_id = comment["id"]
                    from_user = comment.get("from", {}).get("name", "Utilisateur")
                    from_id = comment.get("from", {}).get("id")
                    msg = comment.get("message", "")

                    # Don't reply to the page itself
                    if str(from_id) == str(page_id):
                        continue

                    if c_id in processed:
                        continue

                    print(f"\n   💬 Nouveau commentaire de {from_user} : \"{msg}\"")
                    reply_text = generate_page_reply(msg)

                    if dry_run:
                        print("      [DRY-RUN] Réponse préparée :")
                        print("      " + "\n      ".join(reply_text.splitlines()[:3]) + "...")
                        save_processed_comment(c_id)
                    else:
                        print("      🚀 Publication de la réponse officielle...")
                        post_comment_url = f"https://graph.facebook.com/v21.0/{c_id}/comments"
                        reply_res = requests.post(
                            post_comment_url,
                            data={"message": reply_text, "access_token": token},
                            timeout=20,
                        )
                        if reply_res.status_code == 200:
                            print("      ✅ Réponse postée avec succès !")
                            save_processed_comment(c_id)
                        else:
                            print(f"      ❌ Échec de la réponse : {reply_res.text}")

        except Exception as e:
            print(f"   ⚠️ Erreur sur {page_name} : {e}")

    print("\n🏁 Surveillance Facebook terminée.")


if __name__ == "__main__":
    is_live = "--live" in sys.argv
    process_page_comments(dry_run=not is_live)
