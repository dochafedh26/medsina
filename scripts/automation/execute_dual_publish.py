#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import os
import sys
import json
import requests
from pathlib import Path

# Fix Windows console UTF-8 output
if sys.stdout and hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

script_dir = Path(__file__).resolve().parent
sys.path.insert(0, str(script_dir))

from facebook_post_generator import (
    SUPABASE_URL,
    SUPABASE_KEY,
    OFFICIAL_WEB_URL,
    OFFICIAL_APK_URL,
    OFFICIAL_WIN_URL,
    OFFICIAL_TELEGRAM_URL,
    record_publication_success,
)
from telegram_publisher import send_telegram_broadcast

TOKENS = {
    "medevsync": {
        "page_id": "1329939320211198",
        "name": "Medevsync",
        "token": "EAAiP3YCtoGcBSzm9aQQl9D4BJNQPPEw81zONpNtM7GwHjrT02vZCtXR8Ut1oo4bnVsuZClYgiYiAyFH78clXxL4A1DI7YYZBdoGObRRTXL5JS4fFYyf9dxVMZA8zfV1PdXWDtm0rRvRSU37Mrxf6YHt2ZCFoJWFGrkeNIeMv5cKRDaBfWx2HRN6gTdbjlFXuPvbIZAkRfizWzVIv92frCZBSZApjbl1qAWmzFSMXotMIDKUZD",
    },
    "residanat_blida_2027": {
        "page_id": "1405719695953624",
        "name": "Residanat Blida 2027",
        "token": "EAAiP3YCtoGcBS6RkOF2JVWNA5dEIru8YheIl55H5s9S9nX7myHq2ZCVUfXofDhvzNaWdAhoyri03tRIRgmgW2Nr1j1pZAuVKXZB03bUwfr9xPVGICMiVSsvOZAZBhDYkbzBRCqM8dgXnllyRJZAOHTSCzNuBfBdDjlBkboZAjdlqoZBDHhTtYI8wRHTA2qoNT0D5KCEZBFRIZCVpB2EhULFnZB3waaJvBdb9KWnBEQhZAlMZBmLYZD",
    },
}

IMAGE_PATH = r"C:/Users/PC-Service/.gemini/antigravity/brain/0ba098d1-adef-41a0-8ca2-353fed62237c/medsina_30days_free_offer.png"

def update_supabase_tokens():
    print("1. Mise à jour des jetons dans Supabase (admin_system_settings)...")
    headers = {"apikey": SUPABASE_KEY, "Authorization": f"Bearer {SUPABASE_KEY}", "Content-Type": "application/json", "Prefer": "resolution=merge-duplicates"}
    
    updates = [
        {"setting_key": "facebook_page_access_token", "setting_value": TOKENS["residanat_blida_2027"]["token"]},
        {"setting_key": "facebook_page_id", "setting_value": TOKENS["residanat_blida_2027"]["page_id"]},
        {"setting_key": "facebook_medevsync_page_access_token", "setting_value": TOKENS["medevsync"]["token"]},
        {"setting_key": "facebook_medevsync_page_id", "setting_value": TOKENS["medevsync"]["page_id"]},
    ]
    
    url = f"{SUPABASE_URL}/rest/v1/admin_system_settings"
    r = requests.post(url, headers=headers, json=updates)
    if r.status_code in (200, 201, 204):
        print("✅ Jetons Facebook enregistrés dans Supabase avec succès.")
    else:
        print(f"⚠️ Erreur mise à jour Supabase: {r.status_code} {r.text}")

def publish_to_page(page_key: str, caption: str):
    info = TOKENS[page_key]
    page_id = info["page_id"]
    page_name = info["name"]
    token = info["token"]
    
    print(f"\n🚀 Publication sur la Page Facebook '{page_name}' (ID: {page_id})...")
    url = f"https://graph.facebook.com/v21.0/{page_id}/photos"
    
    with open(IMAGE_PATH, "rb") as f:
        files = {"source": ("medsina_30days_free_offer.png", f, "image/png")}
        data = {"caption": caption, "access_token": token}
        resp = requests.post(url, data=data, files=files, timeout=60)
        
    if resp.status_code == 200:
        res = resp.json()
        photo_id = res.get("id")
        post_id = res.get("post_id")
        print(f"🎉 SUCCÈS sur {page_name} !")
        print(f"   Photo ID: {photo_id}")
        print(f"   Post ID: {post_id}")
        if post_id:
            print(f"   🔗 URL: https://www.facebook.com/{post_id}")
        return res
    else:
        print(f"❌ Erreur Facebook sur {page_name} ({resp.status_code}): {resp.text}")
        return None

def publish_telegram(caption: str):
    print("\n✈️ Diffusion sur Telegram (@medsina_officiel)...")
    try:
        res = send_telegram_broadcast(message_text=caption, image_path=IMAGE_PATH)
        if res.get("ok"):
            msg_id = res.get("result", {}).get("message_id")
            print(f"🎉 SUCCÈS TELEGRAM ! Message ID: {msg_id}")
            return res
        else:
            print(f"⚠️ Erreur Telegram : {res}")
            return None
    except Exception as e:
        print(f"❌ Exception Telegram : {e}")
        return None

def main():
    print("=" * 70)
    print("📢 DIFFUSION SIMULTANÉE : OFFRE 30 JOURS GRATUITS")
    print("=" * 70)
    
    # 1. Update Supabase
    update_supabase_tokens()
    
    # 2. Captions
    facebook_caption = f"""🎁 OFFRE EXCLUSIVE DE LANCEMENT : 30 JOURS D'ACCÈS 100% GRATUIT POUR LES 20 PREMIERS INSCRITS ! 🚀

Dans le cadre de l'accompagnement des médecins, internes et résidents d'Algérie dans la préparation du Concours de Résidanat 2027 et la pratique clinique quotidienne aux urgences, MedevSync offre un Pass VIP Intégral de 30 Jours aux 20 premiers inscrits sur la plateforme Medsina !

✨ CE QUE COMPREND VOTRE PASS GRATUIT (ACCÈS COMPLET) :
🎯 Annales Officielles & QCMs : Entraînement illimité sur des milliers de questions classées par module, cours et facultés (Alger, Blida, Constantine, Oran...) avec explications détaillées.
🤖 Assistant IA MedsinaPilot (24h/24) : Aide au raisonnement diagnostique, analyse d'ordonnances (détection des interactions & contre-indications) et fiches de synthèse instantanées.
📋 Mémento Clinique & Protocoles d'Urgence : Fiches Conduite à Tenir (CAT) indispensables pour les gardes et la pratique hospitalière.
🔬 Normes Biologiques de Référence : Interprétation rapide des bilans et posologies d'urgence.
📱 Mode 100% Hors-Ligne : Révisez et consultez vos fiches partout, même sans connexion internet dans les services !

━━━━━━━━━━━━━━━━━━━━
⚡ COMMENT EN PROFITER ? (Seulement 20 places disponibles !)
1️⃣ Rendez-vous sur l'application Web ou téléchargez l'application :
🌐 Version Web Directe : {OFFICIAL_WEB_URL}
📱 Télécharger sur Android (.apk) : {OFFICIAL_APK_URL}
💻 Télécharger sur PC Windows (.exe) : {OFFICIAL_WIN_URL}
2️⃣ Créez votre compte en 30 secondes (Nom, email, faculté).
3️⃣ Les 20 premiers comptes créés recevront automatiquement leurs 30 jours d'accès complet offert !

━━━━━━━━━━━━━━━━━━━━
✈️ Canal Officiel Telegram : {OFFICIAL_TELEGRAM_URL}
🇩🇿 Conçu par MedevSync pour l'excellence médicale et la réussite au Résidanat en Algérie.
#MedevSync #Medsina #Residanat2027 #ConcoursResidanat #MedecineAlgerie #OffreSpeciale #AccesGratuit #UrgencesMedicales #InternatMedecine"""

    telegram_caption = f"""🎁 <b>OFFRE EXCLUSIVE DE LANCEMENT : 30 JOURS 100% OFFERTS !</b>
<i>Réservé aux 20 premiers médecins et résidents inscrits sur Medsina</i>

MedevSync offre un <b>Pass VIP Intégral de 30 Jours</b> pour booster vos révisions du <b>Résidanat 2027</b> et sécuriser vos gardes aux urgences !

✨ <b>CE QUI EST INCLUS DANS VOTRE ACCÈS GRATUIT :</b>
• 🎯 <b>Annales & QCMs :</b> Accès illimité à tous les modules et facultés avec corrections détaillées.
• 🤖 <b>Assistant IA MedsinaPilot 24h/24 :</b> Aide diagnostique, fiches de révision et analyse d'ordonnances.
• 📋 <b>Mémento Clinique d'Urgence :</b> Conduites à tenir (CAT) et posologies réflexes hors-ligne.
• 🔬 <b>Normes Biologiques :</b> Valeurs de référence et interprétation des bilans.

⚡ <b>COMMENT EN BÉNÉFICIER :</b>
1. Cliquez sur le lien Web ci-dessous ou installez l'APK.
2. Créez votre compte en 30 secondes.
3. Les <b>20 premiers inscrits</b> sont automatiquement activés pour 30 jours complets !

🌐 <b>Accès Web :</b> <a href="{OFFICIAL_WEB_URL}">{OFFICIAL_WEB_URL}</a>
📱 <b>APK Android :</b> <a href="{OFFICIAL_APK_URL}">Télécharger l'APK</a>
💻 <b>Windows Setup :</b> <a href="{OFFICIAL_WIN_URL}">Télécharger pour PC</a>"""

    # 3. Publish to Facebook Pages
    fb1 = publish_to_page("residanat_blida_2027", facebook_caption)
    fb2 = publish_to_page("medevsync", facebook_caption)
    
    # 4. Record publication success in Supabase
    if fb1 and fb1.get("post_id"):
        post_data = {
            "title": "30 Jours d'Accès Gratuit Offerts aux 20 Premiers Inscrits !",
            "theme": "emerald",
            "caption": facebook_caption,
        }
        record_publication_success(fb1.get("post_id"), fb1.get("id"), post_data)
        
    # 5. Telegram
    publish_telegram(telegram_caption)
    
    print("\n" + "=" * 70)
    print("✅ OPÉRATION DE PUBLICATION TERMINÉE AVEC SUCCÈS !")
    print("=" * 70)

if __name__ == "__main__":
    main()
