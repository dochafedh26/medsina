#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Publication spéciale : Offre Exclusive 30 Jours d'Accès Gratuit pour les 20 premiers inscrits.
Diffusion simultanée :
1. Image HD 1080x1080 personnalisée
2. Diffusion sur Telegram (@medsina_officiel) avec boutons interactifs
3. Diffusion sur Facebook (Page Residanat Blida 2027 / MedevSync)
"""

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
    render_banner_image,
    publish_photo_to_facebook,
    record_publication_success,
    get_facebook_credentials,
    APP_VERSION,
    OFFICIAL_WEB_URL,
    OFFICIAL_APK_URL,
    OFFICIAL_WIN_URL,
    OFFICIAL_TELEGRAM_URL,
)
from telegram_publisher import send_telegram_broadcast

def main():
    print("=" * 65)
    print("🎁 PUBLICATION SPÉCIALE : 30 JOURS GRATUITS • 20 PREMIERS INSCRITS")
    print("=" * 65)

    post_data = {
        "title": "30 Jours d'Accès Gratuit Offerts aux 20 Premiers Inscrits !",
        "subtitle": "Accédez à 100% de Medsina : QCMs Annales, Mémento & IA Clinique",
        "badge": "OFFRE EXCLUSIVE • 20 PREMIERS INSCRITS 🎁",
        "theme": "emerald",
        "key_points": [
            "Accès illimité à toutes les annales et QCMs corrigés",
            "Assistant IA MedsinaPilot et analyseur d'ordonnance 24h/24",
            "Mémento des Urgences et fiches CAT hors-ligne",
            "Activation automatique pour les 20 premiers comptes créés !"
        ],
        "screenshot_desktop": "assets/screenshots/desktop/Screenshot 2026-10-20 175342_dashboard.png",
        "mockup_type": "desktop",
    }

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

    post_data["caption"] = facebook_caption

    # 1. Génération de l'image
    output_image = "medsina_30days_free_offer.png"
    print("\n🖼️ 1. Génération de l'infographie haute définition 1080x1080...")
    img_path = render_banner_image(post_data, output_image)
    print(f"✅ Infographie générée avec succès : {img_path}")

    # 2. Diffusion sur Telegram
    print("\n✈️ 2. Diffusion sur le canal officiel Telegram (@medsina_officiel)...")
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

    try:
        tele_res = send_telegram_broadcast(message_text=telegram_caption, image_path=img_path)
        if tele_res.get("ok"):
            msg_id = tele_res.get("result", {}).get("message_id")
            print(f"🎉 SUCCÈS TELEGRAM ! Message ID: {msg_id} sur @medsina_officiel")
        else:
            print(f"⚠️ Réponse Telegram inattendue : {tele_res}")
    except Exception as e:
        print(f"❌ Erreur lors de la diffusion Telegram : {e}")

    # 3. Diffusion sur Facebook
    print("\n🚀 3. Diffusion sur la page Facebook...")
    try:
        fb_res = publish_photo_to_facebook(img_path, facebook_caption)
        photo_id = fb_res.get("id")
        post_id = fb_res.get("post_id")
        print(f"🎉 SUCCÈS FACEBOOK ! Photo ID: {photo_id} | Post ID: {post_id}")
        if post_id:
            print(f"🔗 Lien Facebook direct : https://www.facebook.com/{post_id}")
        record_publication_success(post_id, photo_id, post_data)
    except Exception as e:
        print(f"⚠️ Information Facebook : {e}")
        print("ℹ️ Note : Le jeton Facebook a expiré lors de votre précédente déconnexion/reconnexion.")

    print("\n🏁 Opération terminée avec succès.")

if __name__ == "__main__":
    main()
