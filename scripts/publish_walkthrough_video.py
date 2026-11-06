#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Diffusion de la vidéo de démonstration des Drives & Témoignages des Majors
sur Facebook et Telegram.
"""

import os
import sys
import json
import argparse
import requests
from pathlib import Path

if sys.stdout and hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

VIDEO_PATH = Path(r"C:\Users\PC-Service\.gemini\antigravity\brain\0eebc01b-5b0e-4e57-9f76-92dd499b785a\.user_uploaded\media_1793455642351_68cb0a02.mp4")

ROOT_DIR = Path(__file__).resolve().parent.parent
SUPABASE_URL = os.getenv("SUPABASE_URL", "https://qzfssrhhuorljftpdvjm.supabase.co")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")

for env_candidate in [ROOT_DIR / ".env", ROOT_DIR / "medsina" / ".env"]:
    if not SUPABASE_KEY and env_candidate.exists():
        for line in env_candidate.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if line.startswith("SUPABASE_SERVICE_ROLE_KEY="):
                SUPABASE_KEY = line.split("=", 1)[1].strip()
            elif line.startswith("SUPABASE_URL="):
                SUPABASE_URL = line.split("=", 1)[1].strip()

OFFICIAL_WEB_URL = "https://medsina.medevsync.com"
OFFICIAL_APK_URL = "https://medsina.medevsync.com/download/medsina.apk"
OFFICIAL_EXE_URL = "https://medsina.medevsync.com/download/medsina-setup.exe"
OFFICIAL_TELEGRAM_URL = "https://t.me/medsina_officiel"

FB_TEXT = """🔥 EXCLUSIVITÉ MEDSINA : TOUS LES DRIVES & MÉTHODES DES MAJORS DU RÉSIDANAT CENTRALISÉS EN UN SEUL CLIC ! 🇩🇿📚

Finie la galère des liens Google Drive cassés, des dossiers introuvables la veille du concours ou des heures perdues à chercher les bons résumés sur 50 groupes différents !

Dans cette mise à jour majeure de Medsina, nous avons réuni dans l'onglet « Témoignages & Conseils des Majors » l'intégralité des sources légendaires et des méthodes réelles qui font le succès des lauréats :

🌟 LES DRIVES & PACKS DE RÉFÉRENCE NATIONALE :
• Dr Chakib Goumari (CG) : Les fameux résumés cliniques de référence absolue (GC+++) en Pneumologie et Cardiologie.
• Collection Dr GMA (Alger) : L'intégrale des 17 modules cliniques synthétisés + thérapeutiques.
• Dr Zarouta / Zerrouta (AZ) : Les séries et formations incontournables en Microbiologie, Virologie, Médecine Légale, Travail, UMC et Psychiatrie.
• Dr Dilmi Sidahmed (TOP 05 Blida 2025) : Ses réorganisations des cours officiels des professeurs pour la Biologie fondamentale.

🏆 LES LAURÉATS DU RÉSIDANAT BLIDA 2026 :
• Dr Benouarab Ikram (TOP 04) : Méga-Drive complet & guide méthodologique « Mega-Révision ».
• Dr Bentegri Zakaria (TOP 07), Dr Benkheira Ikram (TOP 20), Dr MOUAZ Zakaria (TOP 24).
• Dr Belhout Meriem (TOP 46) : Dossier Drive complet et fiches réflexes.
• Dr Zerouala Soufyane (TOP 90) : Stratégie Pomodoro 50/10 & maîtrise de la biologie fondamentale.
• Dr Rouis Nassima (TOP 97) : Réussir le résidanat avec un internat chargé (Anapath).

🥇 LES MAJORS NATIONAUX HISTORIQUES :
• Pack Dr Ferhat, Dr Boutiouta (1ère Nationale 2025), Dr Nouaret (1ère 2024 - Pharmaco & Psy), Dr Megateli (1ère 2023), Dr Ali Bachir (TOP 09), Dr Aissaoui (TOP 44).

⚡ CE QUE VOUS POUVEZ FAIRE DANS MEDSINA :
✅ Lire et feuilleter directement chaque guide PDF des majors sans quitter l'app.
✅ Ouvrir en un clic les dossiers Google Drive officiels vérifiés.
✅ Travailler 100% HORS-LIGNE à l'hôpital, de garde ou chez vous.

👉 Rejoignez dès maintenant la plateforme Medsina :
🌐 Accès Web direct : https://medsina.medevsync.com
📱 Application Android (APK) : https://medsina.medevsync.com/download/medsina.apk
💻 Application PC Windows : https://medsina.medevsync.com/download/medsina-setup.exe
💬 Canal Telegram Officiel : https://t.me/medsina_officiel

#ResidanatBlida2027 #ResidanatAlgerie #Medsina #MedecineAlgerie #DrivesResidanat #ChakibGoumari #GMA #Zarouta #Dilmi #MajorsResidanat"""

TG_CAPTION_SHORT = """🩺 <b>[MEDSINA • TOUS LES DRIVES DES MAJORS EN 1 CLIC !]</b> 🇩🇿✨

L'onglet <b>« Témoignages & Conseils »</b> intègre désormais toutes les sources mythiques de révision :

🔹 <b>Dr Chakib Goumari (CG)</b> : Packs Pneumo & Cardio (GC+++)
🔹 <b>Collection Dr GMA (Alger)</b> : 17 modules cliniques synthétisés
🔹 <b>Dr Zarouta / Zerrouta (AZ)</b> : Microbio, Viro, Légale, Travail, UMC
🔹 <b>Dr Dilmi Sidahmed (TOP 05)</b> : Réorganisations Biologie des Profs
🔹 <b>Majors Blida 2026</b> : Benouarab (TOP 04), Bentegri, Benkheira, Mouaz, Belhout, Zerouala, Rouis
🔹 <b>Majors Nationaux</b> : Dr Ferhat, Boutiouta (1ère), Nouaret, Megateli

💡 <i>Ouvrez chaque Drive officiel en 1 clic ou lisez le guide PDF dans l'app en mode 100% Hors-Ligne !</i>

🌐 <b>Accès :</b> <a href="https://medsina.medevsync.com">medsina.medevsync.com</a>"""


def get_settings():
    url = f"{SUPABASE_URL}/rest/v1/admin_system_settings?select=setting_key,setting_value"
    headers = {"apikey": SUPABASE_KEY, "Authorization": f"Bearer {SUPABASE_KEY}"}
    r = requests.get(url, headers=headers, timeout=10)
    data = r.json()
    return {row["setting_key"]: row["setting_value"] for row in data if "setting_key" in row}

def publish_facebook(page_id, token, page_name, dry_run=True):
    print(f"\n📘 [Facebook] Publication sur la page : {page_name} ({page_id})")
    if dry_run:
        print("   [DRY-RUN] Simulation réussie pour Facebook.")
        return True
    
    url = f"https://graph-video.facebook.com/v21.0/{page_id}/videos"
    data = {
        "title": "Medsina : Tous les Drives & Méthodes des Majors en 1 Clic",
        "description": FB_TEXT,
        "access_token": token
    }
    with open(VIDEO_PATH, "rb") as vf:
        files = {"source": (VIDEO_PATH.name, vf, "video/mp4")}
        resp = requests.post(url, data=data, files=files, timeout=300)
    
    if resp.status_code == 200:
        res = resp.json()
        print(f"   ✅ Vidéo publiée avec succès sur Facebook ! ID: {res.get('id')}")
        # Add comment
        vid_id = res.get('id')
        try:
            c_url = f"https://graph.facebook.com/v21.0/{vid_id}/comments"
            c_data = {
                "message": "@followers Retrouvez tous ces drives officiels et témoignages directement sur https://medsina.medevsync.com !",
                "access_token": token
            }
            requests.post(c_url, data=c_data, timeout=15)
            print("   💬 Commentaire @followers ajouté avec succès.")
        except Exception as ce:
            print(f"   ⚠️ Commentaire ignoré: {ce}")
        return True
    else:
        print(f"   ❌ Erreur Facebook ({resp.status_code}): {resp.text}")
        return False

def publish_telegram(token, channel_id, community_id, dry_run=True):
    print(f"\n✈️ [Telegram] Diffusion sur le Canal Officiel ({channel_id}) et Communauté ({community_id})")
    if dry_run:
        print("   [DRY-RUN] Simulation réussie pour Telegram.")
        return True
    
    keyboard = {
        "inline_keyboard": [
            [
                {"text": "🌐 Ouvrir Medsina Web", "url": OFFICIAL_WEB_URL},
                {"text": "📱 Télécharger APK Android", "url": OFFICIAL_APK_URL}
            ],
            [
                {"text": "💻 Télécharger PC Windows", "url": OFFICIAL_EXE_URL},
                {"text": "👥 Page Facebook Résidanat Blida", "url": "https://www.facebook.com/residanatblida2027"}
            ]
        ]
    }
    
    # 1. Post to Official Channel
    url_vid = f"https://api.telegram.org/bot{token}/sendVideo"
    with open(VIDEO_PATH, "rb") as vf:
        files = {"video": (VIDEO_PATH.name, vf, "video/mp4")}
        data = {
            "chat_id": channel_id,
            "caption": TG_CAPTION_SHORT,
            "parse_mode": "HTML",
            "reply_markup": json.dumps(keyboard),
            "supports_streaming": True
        }
        resp = requests.post(url_vid, data=data, files=files, timeout=180)
    
    ch_ok = False
    if resp.status_code == 200 and resp.json().get("ok"):
        msg_id = resp.json()["result"]["message_id"]
        print(f"   ✅ Vidéo diffusée sur le canal officiel ! Message ID: {msg_id}")
        ch_ok = True
        # Pin
        try:
            requests.post(
                f"https://api.telegram.org/bot{token}/pinChatMessage",
                json={"chat_id": channel_id, "message_id": msg_id, "disable_notification": False},
                timeout=10
            )
            print(f"   📌 Message #{msg_id} épinglé sur le canal.")
        except Exception:
            pass
    else:
        print(f"   ❌ Erreur sendVideo Canal: {resp.text}")

    # 2. Post to Community Topic 13 (Témoignages)
    com_ok = False
    if community_id:
        with open(VIDEO_PATH, "rb") as vf:
            files = {"video": (VIDEO_PATH.name, vf, "video/mp4")}
            data = {
                "chat_id": community_id,
                "message_thread_id": 13, # Topic Témoignages
                "caption": TG_CAPTION_SHORT,
                "parse_mode": "HTML",
                "reply_markup": json.dumps(keyboard),
                "supports_streaming": True
            }
            resp_com = requests.post(url_vid, data=data, files=files, timeout=180)
        if resp_com.status_code == 200 and resp_com.json().get("ok"):
            c_msg_id = resp_com.json()["result"]["message_id"]
            print(f"   ✅ Vidéo diffusée dans MEDSINA-COMMUNITY (Topic #13 Témoignages) ! Message ID: {c_msg_id}")
            com_ok = True
        else:
            print(f"   ⚠️ Erreur Topic Communauté: {resp_com.text}")

    return ch_ok or com_ok

def main():
    parser = argparse.ArgumentParser(description="Publier la vidéo sur Facebook & Telegram")
    parser.add_argument("--publish", action="store_true", help="Lancer la vraie publication")
    parser.add_argument("--target", choices=["all", "facebook", "telegram"], default="all", help="Cibles")
    args = parser.parse_args()
    
    dry_run = not args.publish
    
    print("=" * 65)
    print("🎬 DIFFUSION MULTI-RÉSEAUX VIDÉO : DRIVES & TÉMOIGNAGES MAJORS")
    print(f"Fichier vidéo : {VIDEO_PATH}")
    print(f"Mode : {'🧪 SIMULATION (dry-run)' if dry_run else '🚀 PUBLICATION EN DIRECT'}")
    print(f"Cible : {args.target}")
    print("=" * 65)
    
    settings = get_settings()
    
    blida_id = settings.get("facebook_blida_page_id") or "1405719695953624"
    blida_token = settings.get("facebook_blida_page_access_token") or settings.get("facebook_page_access_token")
    
    medsina_id = settings.get("facebook_medsina_page_id") or "1449308354921826"
    medsina_token = settings.get("facebook_medsina_page_access_token") or blida_token
    
    tg_token = settings.get("telegram_bot_token")
    tg_channel = settings.get("telegram_channel_id") or "@medsina_officiel"
    tg_comm = settings.get("telegram_community_group_id") or "-1004438944860"
    
    # 1. Facebook Résidanat Blida 2027
    if args.target in ["all", "facebook"] and blida_token:
        publish_facebook(blida_id, blida_token, "Résidanat Blida 2027", dry_run=dry_run)
    
    # 2. Facebook Medsina Officiel
    if args.target in ["all", "facebook"] and medsina_token:
        publish_facebook(medsina_id, medsina_token, "Medsina Officiel", dry_run=dry_run)
        
    # 3. Telegram
    if args.target in ["all", "telegram"] and tg_token:
        publish_telegram(tg_token, tg_channel, tg_comm, dry_run=dry_run)


if __name__ == "__main__":
    main()

