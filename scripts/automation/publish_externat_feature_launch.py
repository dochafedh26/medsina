#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
=============================================================================
MEDSINA - PUBLICATION OFFICIELLE NOUVEAU HUB EXTERNAT (1ère - 6ème ANNÉE)
=============================================================================
Diffuse la campagne promotionnelle multicanal :
1. Génère l'infographie officielle HD 1080x1080 en thème LIGHT moderne
2. Publie sur les 3 pages Facebook officielles :
   - Résidanat Blida 2027 (1405719695953624)
   - Medsina Officiel (1449308354921826)
   - MedevSync (1329939320211198)
3. Diffuse sur le canal Telegram officiel (@medsina_officiel) avec boutons interactifs
4. Émet la notification temps réel In-App dans Supabase
=============================================================================
"""

import os
import sys
import json
import time
import argparse
import requests
from pathlib import Path
from typing import Dict, Any, Optional, List

if sys.stdout and hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))

from generate_modern_light_banner import build_modern_light_banner
from telegram_publisher import send_telegram_broadcast
from notify_multichannel import send_in_app_notification

SUPABASE_URL = os.environ.get("SUPABASE_URL", "https://qzfssrhhuorljftpdvjm.supabase.co")
SUPABASE_KEY = (
    os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
    or os.environ.get("SUPABASE_KEY")
    or "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF6ZnNzcmhodW9ybGpmdHBkdmptIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MTYxMjg1NCwiZXhwIjoyMTA3MTg4ODU0fQ.-KCUgZdY8RDUwvNOUAabDhQFwv5FFGHYz0J-dM7Cic4"
)

OFFICIAL_TELEGRAM_URL = "https://t.me/medsina_officiel"
OFFICIAL_WEB_URL = "https://medsina.medevsync.com"
OFFICIAL_APK_URL = "https://medsina.medevsync.com/download/medsina.apk"
OFFICIAL_WIN_URL = "https://medsina.medevsync.com/download/medsina-setup.exe"

OUTPUT_DIR = Path(r"C:\Users\PC-Service\.gemini\antigravity\brain\0ba098d1-adef-41a0-8ca2-353fed62237c")
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
BANNER_IMAGE_PATH = str(OUTPUT_DIR / "medsina_externat_hub_light_banner.png")


# -----------------------------------------------------------------------------
# 1. GÉNÉRATION DE L'INFOGRAPHIE OFFICIELLE LIGHT
# -----------------------------------------------------------------------------
def generate_light_infographic() -> str:
    print("🎨 [Design] Génération de l'infographie officielle thème LIGHT...")
    banner_data = {
        "theme": "teal",
        "badge": "NOUVEAUTE MAJEURE • OFFRE -50% PASS ETUDIANT",
        "title": "Nouveau Hub Externat & Cursus Medical",
        "subtitle": "1ere a 6eme Annee • 53 Modules Officiels • Cours PDF & Entrainements EMD",
        "points": [
            "Selecteur 1ere a 6eme Annee : Fondamental, Pre-clinique et Clinique organises selon le cursus officiel.",
            "Cours Officiels en PDF : Consultation integree des polycopies et schemas avec mode hors-ligne.",
            "Entrainements EMD QCM : Sujets d'examens des facultes de medecine avec corriges detailles.",
            "Offre Speciale Lancement : -50% de reduction immediate sur le Pass Etudiant pour toute l'annee !",
        ],
    }

    path = build_modern_light_banner(
        data=banner_data,
        output_path=BANNER_IMAGE_PATH,
        app_version="CURSUS",
    )
    print(f"✅ Infographie générée avec succès : {path}")
    return path


# -----------------------------------------------------------------------------
# 2. RÉCUPÉRATION DES CREDENTIALS FACEBOOK & TELEGRAM
# -----------------------------------------------------------------------------
def fetch_facebook_pages() -> Dict[str, Dict[str, str]]:
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
            "name": "Résidanat Blida 2027",
            "page_id": "1405719695953624",
            "token": settings.get("facebook_page_access_token", "").strip(),
        },
        "medsina": {
            "name": "Medsina (Page Officielle)",
            "page_id": settings.get("facebook_medsina_page_id", "1449308354921826").strip(),
            "token": settings.get("facebook_medsina_page_access_token", "").strip(),
        },
        "medevsync": {
            "name": "MedevSync",
            "page_id": settings.get("facebook_medevsync_page_id", "1329939320211198").strip(),
            "token": settings.get("facebook_medevsync_page_access_token", "").strip(),
        },
    }


# -----------------------------------------------------------------------------
# 3. TEXTES CIBLÉS PAR CANAL
# -----------------------------------------------------------------------------
POST_TEXT_BLIDA = """🎓 GRANDE NOUVEAUTÉ POUR TOUS LES ÉTUDIANTS EN MÉDECINE (1ère à 6ème Année) ! 🩺
🔥 OFFRE SPÉCIALE LANCEMENT : -50% SUR LE PASS ÉTUDIANT !

Vous nous l'avez demandé, c'est désormais officiel dans Medsina !

🚀 DÉCOUVREZ LE NOUVEAU HUB DÉDIÉ : « EXTERNAT (1ère à 6ème Année) & EMDs » !
Fini la dispersion entre multiples drives et polycopies éparpillées. Vous disposez désormais d'un espace de travail unique, structuré par année universitaire :

✨ CE QUI CHANGE POUR VOS RÉVISIONS :
1️⃣ Sélecteur Interactif 1ère ➔ 6ème Année : Cycle fondamental (Anatomie, Biochimie, Cytologie, Physiologie...), cycle pré-clinique (Anapath, Immuno, Pharmaco...) et cursus clinique complet.
2️⃣ Cours Officiels en PDF Haute Définition : Ouvrez directement les polycopies et schémas de faculté avec le lecteur intégré (mode zoom, annotations et support 100% hors-ligne).
3️⃣ Entraînement Ciblé « EMD QCM » : Testez-vous par cours et par module avec les questions d'examens et annales officielles des facultés de médecine + justifications détaillées.
4️⃣ Réduction Exceptionnelle de -50% : Le Pass Étudiant bénéficie d'une remise immédiate de 50% pour accompagner tous les étudiants durant leur cursus !

💡 Les abonnés au Pass Étudiant sont directement orientés vers ce grand menu dès l'ouverture de l'application !

👉 Rejoignez notre canal Telegram officiel pour activer votre réduction de 50% et découvrir toutes les nouveautés :
✈️ https://t.me/medsina_officiel

📱 Également accessible sur tous vos appareils :
🌐 Plateforme Web : https://medsina.medevsync.com
📲 Application Android (.apk) : https://medsina.medevsync.com/download/medsina.apk
🖥️ Version PC Windows (.exe) : https://medsina.medevsync.com/download/medsina-setup.exe

Partagez l'info avec vos promotions et binômes de révision ! Bon courage à tous ! 🩺🇩🇿"""

POST_TEXT_MEDSINA = """🚀 MISE À JOUR MAJEURE : LE NOUVEAU HUB « EXTERNAT (1ère à 6ème Année) » EST EN LIGNE ! 📚
🎁 BÉNÉFICIEZ DE -50% DE RÉDUCTION SUR LE PASS ÉTUDIANT !

Medsina franchit une nouvelle étape ! Conçu initialement pour le résidanat et la pratique clinique, l'écosystème s'ouvre officiellement à l'ensemble du cursus médical universitaire.

🔬 VOTRE COMPAGNON DU PREMIER JOUR D'AMPHI JUSQU'AU CONCOURS :
• 53 Modules structurés selon le programme médical officiel.
• Lecteur PDF Intégré : Consultez tous vos cours et polycopies sans quitter l'application.
• Entraînements EMD QCM : Sujets d'examens par spécialité avec corrigés détaillés et pièges fréquents.
• Navigation Dédiée : Interface adaptée pour les étudiants de 1ère, 2ème, 3ème, 4ème, 5ème et 6ème année.
• Double Sauvegarde Cloud & Mode 100% Hors-Ligne pour réviser à la fac, à l'hôpital ou en garde.

🔥 Profitez de -50% de réduction immédiate sur le Pass Étudiant !

👉 Retrouvez toutes les annonces et activez votre offre sur notre canal Telegram officiel :
✈️ https://t.me/medsina_officiel

Accès direct :
🌐 https://medsina.medevsync.com
📲 Android (.apk) : https://medsina.medevsync.com/download/medsina.apk
💻 Windows (.exe) : https://medsina.medevsync.com/download/medsina-setup.exe"""

POST_TEXT_MEDEVSYNC = """💡 [MedevSync x Medsina] Innovation EdTech Médicale : Déploiement du Hub Cursus Médical & Externat 🩺
🏷️ Offre Spéciale : -50% de Réduction sur le Pass Étudiant !

Nous sommes fiers d'annoncer l'extension majeure de la plateforme Medsina aux étudiants de la 1ère à la 6ème année de médecine.

⚙️ LES ATOUTS DE CETTE NOUVELLE EXPÉRIENCE :
• Architecture Offline-First : Téléchargement et mise en cache locale des polycopies de cours et banques de QCM EMD.
• Expérience Adaptative : Routage dynamique de l'interface utilisateur selon le cycle d'études (Pass Étudiant, Résident Élite, Clinique Pro).
• Lecteur PDF Haute Résolution & Moteur de QCMs avec correction analytique détaillée.

👉 Suivez toutes nos actualités et accédez à l'offre promotionnelle (-50%) sur Telegram :
🔗 https://t.me/medsina_officiel
🌐 https://medsina.medevsync.com"""

POST_TEXT_TELEGRAM = """🔥 NOUVEAU SUR MEDSINA : LE HUB EXTERNAT (1ère à 6ème Année) EST LÀ ! 🩺
🎉 OFFRE SPÉCIALE : -50% SUR LE PASS ÉTUDIANT !

Chers carabins et futurs résidents,
Le grand Hub Cursus Médical & Externat est officiellement disponible !

🎓 Au programme du nouveau Hub :
✅ Cursus complet 1ère ➔ 6ème Année (Fondamental, Pré-clinique, Clinique)
✅ Tous les Cours officiels en PDF haute résolution intégrés in-app
✅ Banques de QCMs EMD avec corrigés officiels et explications
✅ Mode 100% Hors-Ligne pour réviser sans connexion en stage et amphi
✅ Redirection automatique dédiée pour les abonnés Pass Étudiant

🎁 Offre de lancement : Bénéficiez immédiatement de -50% sur votre Pass Étudiant !

🚀 Rejoignez-nous et lancez vos révisions :
✈️ Canal Officiel : https://t.me/medsina_officiel
🌐 Plateforme Web : https://medsina.medevsync.com
📲 Android (.apk) : https://medsina.medevsync.com/download/medsina.apk

Bonnes révisions à toutes et à tous ! 🩺💪"""


# -----------------------------------------------------------------------------
# 4. PUBLICATION FACEBOOK VIA META GRAPH API
# -----------------------------------------------------------------------------
def publish_to_facebook_page(
    page_key: str,
    page_info: Dict[str, str],
    message: str,
    image_path: str,
    dry_run: bool = False,
) -> Dict[str, Any]:
    name = page_info["name"]
    page_id = page_info["page_id"]
    token = page_info["token"]

    if not token or not page_id:
        print(f"⚠️ [Facebook] {name} ignorée : Token ou Page ID manquant.")
        return {"success": False, "error": "Token manquant"}

    if dry_run:
        print(f"🧪 [DRY-RUN] [Facebook] {name} ({page_id}) prête pour publication.")
        return {"success": True, "dry_run": True}

    print(f"📢 [Facebook] Publication sur {name} ({page_id})...")
    url = f"https://graph.facebook.com/v20.0/{page_id}/photos"

    try:
        with open(image_path, "rb") as img_file:
            files = {"source": ("banner.png", img_file, "image/png")}
            data = {
                "caption": message,
                "access_token": token,
            }
            resp = requests.post(url, data=data, files=files, timeout=40)
            res_json = resp.json()

            if resp.status_code == 200 and "id" in res_json:
                post_id = res_json.get("post_id") or res_json.get("id")
                print(f"  ✅ {name} : Post publié avec succès ! ID = {post_id}")
                return {"success": True, "post_id": post_id}
            else:
                print(f"  ⚠️ {name} Erreur ({resp.status_code}) : {res_json}")
                return {"success": False, "error": res_json}
    except Exception as e:
        print(f"  ❌ {name} Exception : {e}")
        return {"success": False, "error": str(e)}


# -----------------------------------------------------------------------------
# 5. POINT D'ENTRÉE PRINCIPAL
# -----------------------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(
        description="Medsina - Promotion Multicanal du Nouveau Hub Externat (1ère - 6ème Année)"
    )
    parser.add_argument("--live", action="store_true", help="Publie réellement sur les pages Facebook et Telegram")
    parser.add_argument("--dry-run", action="store_true", help="Génère l'infographie sans diffuser")
    args = parser.parse_args()

    is_live = args.live and not args.dry_run

    print("=================================================================")
    print("🚀 MEDSINA — DÉPLOIEMENT CAMPAGNE PROMOTIONNELLE HUB EXTERNAT")
    print(f"   Mode : {'🔴 LIVE (RÉEL)' if is_live else '🧪 DRY-RUN (TEST PRÉPARATOIRE)'}")
    print("=================================================================")

    # 1. Génération Infographie Light HD
    infographic_path = generate_light_infographic()

    # 2. Récupération des Pages FB
    pages = fetch_facebook_pages()

    # Associer chaque message à sa page
    page_texts = {
        "residanat_blida_2027": POST_TEXT_BLIDA,
        "medsina": POST_TEXT_MEDSINA,
        "medevsync": POST_TEXT_MEDEVSYNC,
    }

    results = {}

    # 3. Diffusion Facebook sur les 3 pages
    for key, p_info in pages.items():
        text = page_texts.get(key, POST_TEXT_MEDSINA)
        res = publish_to_facebook_page(
            page_key=key,
            page_info=p_info,
            message=text,
            image_path=infographic_path,
            dry_run=not is_live,
        )
        results[key] = res

    # 4. Diffusion Telegram Officiel
    if is_live:
        print("✈️ [Telegram] Diffusion sur le canal officiel @medsina_officiel...")
        try:
            tg_res = send_telegram_broadcast(
                message_text=POST_TEXT_TELEGRAM,
                image_path=infographic_path,
            )
            results["telegram"] = tg_res
            if tg_res.get("success"):
                print("  ✅ Telegram : Post illustré diffusé avec succès !")
            else:
                print(f"  ⚠️ Telegram Erreur : {tg_res.get('error')}")
        except Exception as tg_e:
            print(f"  ❌ Telegram Exception : {tg_e}")
            results["telegram"] = {"success": False, "error": str(tg_e)}
    else:
        print("🧪 [DRY-RUN] [Telegram] Prêt pour diffusion sur @medsina_officiel.")
        results["telegram"] = {"success": True, "dry_run": True}

    # 5. Émission Notification In-App
    if is_live:
        print("📲 [In-App] Émission de la notification temps réel aux utilisateurs...")
        notif_sent = send_in_app_notification(
            title="🎓 Nouveau Hub Externat (1ère - 6ème Année)",
            message="Découvrez vos modules par année, cours complets en PDF et entraînements EMD QCM. Promo -50% sur le Pass Étudiant !",
            notif_type="announcement",
            target_id="externat_hub",
        )
        results["in_app"] = {"success": notif_sent}
    else:
        print("🧪 [DRY-RUN] [In-App] Prêt pour envoi de notification temps réel.")
        results["in_app"] = {"success": True, "dry_run": True}

    print("\n=================================================================")
    print("📊 RÉSUMÉ DES RÉSULTATS :")
    print(json.dumps(results, indent=2, ensure_ascii=False))
    print("=================================================================")


if __name__ == "__main__":
    main()
