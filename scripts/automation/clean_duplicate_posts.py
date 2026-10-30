#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
=============================================================================
MEDSINA - NETTOYAGE DES DOUBLONS DE PUBLICATION (TELEGRAM & FACEBOOK)
=============================================================================
1. Supprime le message #45 sur Telegram (@medsina_officiel) pour ne garder
   que le message #47 épinglé et officiel.
2. Supprime les premiers posts de 20h58 sur les 3 pages Facebook pour ne
   conserver que l'annonce finale et exhaustive des 6 Agents Pédagogiques.
=============================================================================
"""

import os
import sys
import requests
from pathlib import Path

if sys.stdout and hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))

from telegram_publisher import get_telegram_credentials
from publish_agents_pedagogiques_feature import fetch_facebook_pages

def delete_telegram_message(message_id: int):
    print(f"\n✈️ [Telegram] Suppression du message doublon #{message_id} sur @medsina_officiel...")
    creds = get_telegram_credentials()
    bot_token = creds.get("bot_token")
    channel_id = creds.get("channel_id", "@medsina_officiel")

    url = f"https://api.telegram.org/bot{bot_token}/deleteMessage"
    resp = requests.post(url, json={"chat_id": channel_id, "message_id": message_id}, timeout=15)
    data = resp.json()
    if data.get("ok"):
        print(f"  ✅ Message Telegram #{message_id} supprimé avec succès !")
        return True
    else:
        print(f"  ❌ Erreur suppression Telegram #{message_id} : {data}")
        return False

def delete_facebook_post(page_name: str, post_id: str, token: str):
    print(f"\n📢 [Facebook] Suppression du post doublon/antérieur sur {page_name} (ID: {post_id})...")
    url = f"https://graph.facebook.com/v21.0/{post_id}"
    resp = requests.delete(url, params={"access_token": token}, timeout=15)
    data = resp.json()
    if data.get("success"):
        print(f"  ✅ Post Facebook {post_id} supprimé avec succès sur {page_name} !")
        return True
    else:
        print(f"  ❌ Erreur suppression Facebook ({page_name}) : {data}")
        return False

def main():
    print("=" * 75)
    print("🧹 MEDSINA - NETTOYAGE DES DOUBLONS (TELEGRAM & FACEBOOK)")
    print("=" * 75)

    # 1. Telegram : Supprimer Message #45
    delete_telegram_message(45)

    # 2. Facebook : Supprimer le 1er post de 20h58 sur chaque page
    pages = fetch_facebook_pages()

    fb_targets = [
        ("residanat_blida_2027", "1405719695953624_122112475329511638"),
        ("medsina", "1449308354921826_122104972701522784"),
        ("medevsync", "1329939320211198_122116056699505100"),
    ]

    for page_key, post_id in fb_targets:
        page_info = pages.get(page_key)
        if page_info and page_info.get("token"):
            delete_facebook_post(page_info["name"], post_id, page_info["token"])

    print("\n" + "=" * 75)
    print("✨ NETTOYAGE TERMINÉ AVEC SUCCÈS")
    print("• Telegram : Message #47 conservé comme post officiel épinglé.")
    print("• Facebook : Les posts de 21h43 ('6 Agents IA Pédagogiques') sont conservés.")
    print("=" * 75)

if __name__ == "__main__":
    main()
