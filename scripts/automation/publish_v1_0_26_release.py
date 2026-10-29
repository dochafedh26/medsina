#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Publication Officielle — Medsina v1.0.26 « Double Sauvegarde Cloud & Mode Hors-Ligne »
====================================================================================
Génère l'infographie officielle HD 1080x1080 et publie sur :
  1. Page Facebook "Residanat Blida 2027"
  2. Page Facebook "Medevsync"
  3. Canal Telegram Officiel (@medsina_officiel)
en utilisant les jetons actifs stockés dans Supabase (admin_system_settings).
"""

import os
import sys
from pathlib import Path
import requests

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
    render_banner_image,
    record_publication_success,
)
from telegram_publisher import send_telegram_broadcast

OUTPUT_DIR = Path(r"C:\Users\PC-Service\.gemini\antigravity\brain\0ba098d1-adef-41a0-8ca2-353fed62237c")
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
IMG_PATH = str(OUTPUT_DIR / "medsina_v1_0_26_cloud_offline_banner.png")


def fetch_live_facebook_pages():
    headers = {
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
    }
    r = requests.get(
        f"{SUPABASE_URL}/rest/v1/admin_system_settings?select=setting_key,setting_value",
        headers=headers,
        timeout=15,
    )
    r.raise_for_status()
    settings = {row["setting_key"]: row["setting_value"] for row in r.json()}

    return {
        "residanat_blida_2027": {
            "page_id": "1405719695953624",
            "name": "Residanat Blida 2027",
            "token": settings.get("facebook_page_access_token", "").strip(),
        },
        "medevsync": {
            "page_id": settings.get("facebook_medevsync_page_id", "1329939320211198").strip(),
            "name": "Medevsync",
            "token": settings.get("facebook_medevsync_page_access_token", "").strip(),
        },
        "medsina": {
            "page_id": settings.get("facebook_medsina_page_id", "1449308354921826").strip(),
            "name": "Medsina (Page Officielle)",
            "token": settings.get("facebook_medsina_page_access_token", "").strip(),
        },
    }


def generate_infographic():
    data = {
        "theme": "teal",
        "badge": "NOUVEAUTÉ v1.0.26 • CLOUD & HORS-LIGNE",
        "title": "Double Sauvegarde Cloud & Mode Hors-Ligne",
        "subtitle": "Multi-Appareils Windows & Android • Révision 100% Hors-Ligne • Gestion du Stockage",
        "mockup_type": "desktop",
        "screenshot_desktop": "assets/screenshots/desktop/Screenshot 2026-10-20 175342_dashboard.png",
        "points": [
            "Double Sauvegarde Automatique : Sessions sur-mesure, notes QCM, Study Planner et Flashcards synchronisés.",
            "Multi-Appareils Transparent : Passez de votre PC Windows à votre mobile Android sans rien perdre.",
            "Mode Hors-Ligne à la Demande : Téléchargement individuel ou par module complet pour réviser sans internet.",
            "Gestionnaire de Stockage Dédié : Suivi précis des Mo, ouverture instantanée 0s et option Wi-Fi uniquement.",
        ],
    }

    p = render_banner_image(data, IMG_PATH)
    print(f"✅ Infographie v1.0.26 générée avec succès : {p}")
    return p


def publish_to_fb_page(info: dict, image_path: str, caption: str):
    page_id = info["page_id"]
    page_name = info["name"]
    token = info["token"]

    if not token:
        print(f"⚠️ Aucun jeton d'accès pour {page_name}. Publication ignorée.")
        return None

    print(f"\n🚀 Publication sur la Page Facebook '{page_name}' (ID: {page_id})...")
    url = f"https://graph.facebook.com/v21.0/{page_id}/photos"

    try:
        with open(image_path, "rb") as f:
            files = {"source": (os.path.basename(image_path), f, "image/png")}
            data = {"caption": caption, "access_token": token}
            resp = requests.post(url, data=data, files=files, timeout=60)

        if resp.status_code == 200:
            res = resp.json()
            post_id = res.get("post_id") or res.get("id")
            print(f"🎉 SUCCÈS sur {page_name} ! Post ID: {post_id}")
            print(f"   🔗 Lien direct : https://www.facebook.com/{post_id}")
            return res
        else:
            print(f"❌ Erreur Facebook sur {page_name} ({resp.status_code}): {resp.text}")
            return None
    except Exception as e:
        print(f"❌ Exception lors de la publication sur {page_name}: {e}")
        return None


def main():
    print("=" * 72)
    print("📢 DIFFUSION OFFICIELLE : MEDSINA v1.0.26 (DOUBLE SAUVEGARDE & HORS-LIGNE)")
    print("=" * 72)

    pages = fetch_live_facebook_pages()
    image_path = generate_infographic()

    fb_caption = f"""🚨 NOUVELLE MISE À JOUR MAJEURE SUR MEDSINA (v1.0.26) : LA DOUBLE SAUVEGARDE CLOUD & LE MODE HORS-LIGNE SONT LÀ ! ☁️📲

Chers confrères, chères consœurs, candidats au concours de Résidanat 2027 🇩🇿🩺

Nous savons combien votre temps est précieux et à quel point vos conditions de révision varient entre la bibliothèque, les gardes aux urgences et les déplacements.

Aujourd'hui, nous sommes fiers de vous annoncer le déploiement de Medsina v1.0.26, pensée pour vous offrir une liberté d'étude totale, où que vous soyez et sur tous vos appareils !

━━━━━━━━━━━━━━━━━━━━
🌟 LES GRANDES NOUVEAUTÉS DE CETTE VERSION :

1️⃣ ☁️ DOUBLE SAUVEGARDE AUTOMATIQUE (CLOUD SUPABASE + LOCAL) :
• Vous révisez sur votre PC portable Windows le soir et vous poursuivez sur votre smartphone ou tablette Android en journée ? C'est désormais 100% instantané et automatique !
• Vos sessions sur-mesure, vos notes et favoris sur les QCMs, votre avancement dans le Study Planner (Couches 1, 2, 3) et vos Flashcards FSRS se synchronisent en temps réel.
• Même en changeant d'appareil ou en réinstallant l'application, vous retrouvez 100% de votre travail en une seconde dès votre connexion.

2️⃣ 📴 MODE HORS-LIGNE À LA DEMANDE (ACCÈS 100% SANS INTERNET) :
• Une garde dans un service sans réseau ? Pas de Wi-Fi ou forfait 4G limité ?
• Téléchargement en 1 clic : Enregistrez n'importe quel cours ou téléchargez le Pack complet d'un module pour un accès immédiat sans connexion.
• Sessions préchargées : Cochez simplement « Rendre cette session disponible hors-ligne » lors de la création d'une session, et tous les supports sont pré-enregistrés automatiquement.
• Lecteur PDF Ultra-Rapide : 0 seconde de chargement pour tous vos cours téléchargés.
• Gestionnaire de Stockage Dédié : Visualisez l'espace utilisé sur votre mémoire interne, activez l'option « Télécharger uniquement en Wi-Fi » et gérez vos fichiers en toute simplicité.

3️⃣ 🎯 OPTIMISATIONS & EXPÉRIENCE FLUIDE :
• Palette de navigation des 50 questions 100% responsive et fluide sur mobile et desktop.
• Sauvegarde immédiate dans vos « Sessions Enregistrées ».

━━━━━━━━━━━━━━━━━━━━
📥 TÉLÉCHARGEZ OU METTEZ À JOUR MEDSINA (v1.0.26) :
🌐 Accès Web Direct : {OFFICIAL_WEB_URL}
💻 Application Windows PC : {OFFICIAL_WIN_URL}
📱 Application Android (.apk) : {OFFICIAL_APK_URL}
✈️ Rejoignez le Canal Officiel Telegram : {OFFICIAL_TELEGRAM_URL}

Bon courage à tous pour votre préparation, l'excellence clinique est à portée de main ! 💪🇩🇿

#Medsina #Residanat2027 #MedecineAlgerie #ConcoursResidanat #Blida #Alger #Oran #Constantine #DoubleSauvegarde #ModeHorsLigne"""

    tg_caption = f"""🚀 <b>Medsina v1.0.26 est disponible !</b>
<i>(Double Sauvegarde Cloud + Mode Hors-Ligne Intégral)</i>

Chers médecins & candidats au Résidanat 🇩🇿🩺, la version <b>v1.0.26</b> est en ligne !

☁️ <b>1. Double Sauvegarde Multi-Appareils :</b>
• Passez de votre PC Windows à votre mobile Android sans rien perdre.
• Synchronisation Cloud temps réel de vos Sessions Sur-Mesure, notes/favoris QCM, Study Planner (3 couches) et Flashcards FSRS.

📴 <b>2. Mode Hors-Ligne à la Demande (100% Offline) :</b>
• Révisez en garde, à l'hôpital ou dans les transports sans 4G ni Wi-Fi.
• <b>Bouton Pack Hors-Ligne :</b> téléchargez d'un coup tous les cours d'un module entier.
• <b>Lecteur PDF 0s :</b> ouverture instantanée de tous vos supports enregistrés.
• Nouveau gestionnaire de stockage avec suivi de l'espace mémoire (Mo).

🛠 <b>3. Ergonomie & Corrections :</b>
• Navigation responsive 100% fluide sur mobile et desktop.

<i>Mettez à jour votre application dès maintenant via les boutons ci-dessous !</i> 🩺💪"""

    results = {}

    # 1. Publication Facebook Page "Residanat Blida 2027"
    r1 = publish_to_fb_page(pages["residanat_blida_2027"], image_path, fb_caption)
    results["fb_blida"] = r1

    # 2. Publication Facebook Page "Medevsync"
    r2 = publish_to_fb_page(pages["medevsync"], image_path, fb_caption)
    results["fb_medevsync"] = r2

    # 3. Tentative Page "Medsina" (si jeton actif)
    if pages["medsina"]["token"]:
        r3 = publish_to_fb_page(pages["medsina"], image_path, fb_caption)
        results["fb_medsina"] = r3
    else:
        print("ℹ️ Page Facebook Medsina : Aucun jeton actif configuré.")

    # 4. Publication Telegram Canal Officiel (@medsina_officiel)
    print("\n✈️ Diffusion sur Telegram (@medsina_officiel)...")
    try:
        tg_res = send_telegram_broadcast(message_text=tg_caption, image_path=image_path)
        if tg_res.get("ok"):
            msg_id = tg_res.get("result", {}).get("message_id")
            print(f"🎉 SUCCÈS TELEGRAM ! Message ID: {msg_id}")
            print(f"   🔗 Lien Telegram : https://t.me/medsina_officiel/{msg_id}")
            results["telegram"] = tg_res
        else:
            print(f"❌ Erreur Telegram : {tg_res}")
            results["telegram"] = None
    except Exception as e:
        print(f"❌ Exception Telegram : {e}")
        results["telegram"] = None

    print("\n" + "=" * 72)
    print("RÉCAPITULATIF DE LA PUBLICATION :")
    for k, v in results.items():
        status = "✅ Réussi" if v else "❌ Échec"
        print(f"  • {k}: {status}")
    print("=" * 72)


if __name__ == "__main__":
    main()
