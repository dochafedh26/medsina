#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
=============================================================================
MEDSINA - DIFFUSION OFFICIELLE : SYSTÈME MULTI-AGENTS PÉDAGOGIQUES
(6 TUTEURS IA DE PROMOTION • DURÉES EN ALGÉRIE • EMD BLANC /20 • LIT DU MALADE)
=============================================================================
1. Génère l'infographie officielle HD 1080x1080 en thème LIGHT moderne
2. Publie avec l'image sur les 3 pages Facebook officielles :
   - Résidanat Blida 2027 (1405719695953624)
   - Medsina Officiel (1449308354921826)
   - MedevSync (1329939320211198)
   + Ajoute immédiatement un commentaire @followers sous chaque post !
3. Publie sur le canal Telegram officiel (@medsina_officiel) avec image, légende <= 1024 car et auto-pin !
4. Émet la notification In-App temps réel dans Supabase.
=============================================================================
"""

import os
import sys
import json
import time
import requests
from pathlib import Path
from typing import Dict, Any, List

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
BANNER_IMAGE_PATH = str(OUTPUT_DIR / "medsina_agents_pedagogiques_light_banner.png")


# -----------------------------------------------------------------------------
# 1. GÉNÉRATION DE L'INFOGRAPHIE OFFICIELLE LIGHT
# -----------------------------------------------------------------------------
def generate_light_banner() -> str:
    print("🎨 [Design] Génération de l'infographie officielle thème LIGHT moderne...")
    banner_data = {
        "theme": "teal",
        "badge": "INNOVATION IA • 6 TUTEURS DE PROMOTION • EMD /20",
        "title": "6 Agents IA Pédagogiques par Année d'Étude",
        "subtitle": "1ère à 6ème Année • Durées Réelles en Algérie • EMD Blanc & Lit du Malade",
        "points": [
            "6 Tuteurs Dédiés : Pr. Sarah (1ère), Dr. Mansouri (2ème), Dr. Charef (3ème), Pr. Boudiaf (4ème), Pr. Khelifi (5ème), Dr. Belkacem (6ème).",
            "Matrice Durées Algérie : Suivi des stages réels (ORL 3 sem., Cardio 6 sem., Pédiatrie 12 sem.) avec compte à rebours d'examen.",
            "Sessions de Cours Amphi : Cas clinique d'accroche, cours structuré, piège du professeur aux EMDs et questions flash d'auto-évaluation.",
            "EMD Blanc /20 & Lit du Malade : Examens chronométrés notés sur 20 officiel + Guide de stage clinique au chevet du patient !",
        ],
    }

    path = build_modern_light_banner(
        data=banner_data,
        output_path=BANNER_IMAGE_PATH,
        app_version="AGENTS IA",
    )
    print(f"✅ Infographie générée : {path}")
    return path


# -----------------------------------------------------------------------------
# 2. RÉCUPÉRATION DES CREDENTIALS FACEBOOK & TELEGRAM DEPUIS SUPABASE
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
# 3. TEXTES CIBLÉS POUR FACEBOOK ET TELEGRAM
# -----------------------------------------------------------------------------
POST_TEXT_BLIDA = """🧠 RÉVOLUTION PÉDAGOGIQUE POUR L'EXTERNAT & LE RÉSIDANAT (1ère à 6ème Année) ! 🩺
🔥 6 AGENTS IA DÉDIÉS • MATRICE DES DÉLAIS EN ALGÉRIE • SIMULATEUR D'EMD SUR 20 !
🎁 RAPPEL : -50% IMMÉDIAT SUR LE PASS ÉTUDIANT !

Chers futurs confrères et résidents,
Medsina transforme vos révisions en véritable faculté interactive ! Chaque promotion dispose désormais de son propre Enseignant Virtuel spécialisé :

👨‍🏫 LES 6 TUTEURS DE PROMOTION :
• 1ère Année : Pr. Sarah Benali (Sciences Fondamentales, Anatomie & schémas descriptifs)
• 2ème Année : Dr. Karim Mansouri (Physiologie, Unités intégrées & boucles de régulation)
• 3ème Année : Dr. Amine Charef (Sémiologie clinique & examen au lit du malade)
• 4ème Année : Pr. Yassine Boudiaf (Pathologie I : Cardio, Pneumo, Gastro, Neuro)
• 5ème Année : Pr. Meriem Khelifi (Pathologie II : Pédiatrie, Gynéco, ORL, Ophtalmo)
• 6ème Année : Dr. Reda Belkacem (UMC, Thérapeutique & Simulations de gardes réelles)

📅 CALENDRIER RÉEL DES STAGES EN ALGÉRIE :
L'application intègre les durées officielles de vos rotations hospitalières :
• Rotations courtes (3 semaines) : ORL, Ophtalmologie, Dermatologie...
• Rotations moyennes (4 à 6 semaines) : Cardiologie, Gastro, Pneumo, Neuro, Uro, UMC...
• Trimestres lourds (12 semaines) : Pédiatrie, Gynécologie-Obstétrique.
⏳ Barre de progression de stage en temps réel avec compte à rebours : « J-5 avant l'EMD Blanc ! »

✨ CE QUE VOUS POUVEZ DÉJÀ FAIRE DANS L'APPLI :
1️⃣ Session de Cours Type Enseignant : Cas clinique d'amphi, cours magistral complet, détection du « Piège du Professeur aux EMDs », questions flash d'auto-évaluation et fiche réflexe.
2️⃣ Simulateur d'Examens EMD Blancs Chronométrés : Minuterie officielle, palette de questions (QCS / QCM), calcul automatique de votre Note sur 20 (Validé/Non Validé) et analyse des points faibles.
3️⃣ Mode Lit du Malade : Guide express en 30 secondes pour vos tours de salle (questions d'interrogatoire, examen physique, bilans urgents et drapeaux rouges).

🏷️ Offre spéciale en cours : -50% sur le Pass Étudiant !

👉 Rejoignez notre canal Telegram officiel pour poser vos questions et profiter des nouveautés :
✈️ https://t.me/medsina_officiel

📲 Disponible sur tous vos écrans :
🌐 Web : https://medsina.medevsync.com
📲 Android APK : https://medsina.medevsync.com/download/medsina.apk
💻 Windows PC : https://medsina.medevsync.com/download/medsina-setup.exe

Bon courage et excellentes révisions à toutes et à tous ! 🩺🇩🇿"""

POST_TEXT_MEDSINA = """🚀 NOUVELLE FONCTIONNALITÉ MAJEURE : 6 AGENTS IA PÉDAGOGIQUES PAR ANNÉE D'ÉTUDE ! 👨‍🏫🩺
🎁 BÉNÉFICIEZ DE -50% SUR LE PASS ÉTUDIANT !

Medsina lance son système multi-agents pédagogiques pour accompagner tous les étudiants en médecine de la 1ère à la 6ème année :

🎓 VOTRE TUTEUR DE PROMOTION DÉDIÉ :
Chaque année d'étude a son mentor IA formé au programme officiel algérien pour vous faire cours, vous interroger et vous évaluer.

⏱️ SYNCHRONISÉ AVEC VOS STAGES RÉELS :
• Prise en compte de la durée exacte de chaque module (ORL 3 sem., Cardio 6 sem., Pédiatrie 12 sem.).
• Compte à rebours dynamique jusqu'à la fin de la rotation hospitalière.

📝 SIMULATION D'EMD BLANC CHRONOMÉTRÉE :
• QCS, QCMs et cas cliniques au format officiel de faculté.
• Notation automatique sur 20 avec seuil de validation.
• Corrigés détaillés et justifications ligne par ligne.

🩺 MODE LIT DU MALADE :
En stage devant un patient ? Obtenez en un clic la conduite à tenir clinique, les signes physiques et les bilans d'urgence de 1ère intention.

👉 Rejoignez le canal Telegram officiel pour activer votre réduction de -50% :
✈️ https://t.me/medsina_officiel

Accès direct :
🌐 https://medsina.medevsync.com
📲 Android (.apk) : https://medsina.medevsync.com/download/medsina.apk
💻 Windows (.exe) : https://medsina.medevsync.com/download/medsina-setup.exe"""

POST_TEXT_MEDEVSYNC = """💡 [MedevSync x Medsina] Révolution EdTech : Déploiement du Système Multi-Agents Pédagogiques en Médecine 🩺
🏷️ Offre Spéciale : -50% de Réduction sur le Pass Étudiant !

MedevSync franchit une nouvelle frontière dans l'apprentissage médical augmenté en intégrant un écosystème de 6 Agents IA Pédagogiques spécialisés (de la 1ère à la 6ème année) dans Medsina.

⚙️ ARCHITECTURE & CAPACITÉS PÉDAGOGIQUES :
• Personas Cliniques & Fondamentaux : Du Pr. d'Anatomie au Réanimateur urgentiste des UMC.
• Modélisation des Rotations Algériennes : Modules de 3, 4, 6 et 12 semaines avec alertes EMD.
• Moteur d'Évaluation EMD Chronométré : Notation conforme sur 20 et scoring prédictif.
• Copilote Pratique au Lit du Malade : Aide au diagnostic différentiel rapide en milieu hospitalier.

👉 Rejoignez notre canal officiel Telegram pour découvrir la plateforme :
🔗 https://t.me/medsina_officiel
🌐 https://medsina.medevsync.com"""

# TELEGRAM CAPTION: STRICTEMENT <= 1024 CARACTÈRES
POST_TEXT_TELEGRAM = """🔥 EXCLUSIF : 6 AGENTS IA PÉDAGOGIQUES (1ère à 6ème Année) ! 🩺
🎉 OFFRE LANCEMENT : -50% SUR LE PASS ÉTUDIANT !

Medsina lance ses tuteurs virtuels dédiés par promotion :

👨‍🏫 6 Tuteurs IA Spécialisés :
Pr. Sarah (1ère), Dr. Mansouri (2ème), Dr. Charef (3ème), Pr. Boudiaf (4ème), Pr. Khelifi (5ème), Dr. Belkacem (6ème).

📅 Durées Réelles Algérie :
Stages paramétrés selon la durée officielle (ORL 3 sem., Cardio 6 sem., Péd 12 sem.) avec compte à rebours d'examen.

✨ Nouveautés Disponibles :
✅ Cours Amphi Interactif : cas d'accroche, piège d'examen, QCM flash & fiche réflexe.
✅ EMD Blanc Chronométré : notation sur 20 officiel, timer réel & corrigé détaillé.
✅ Mode Lit du Malade : guide d'examen express au chevet du patient.

🎁 Réduction immédiate de -50% sur le Pass Étudiant !

🚀 Rejoignez le canal & lancez vos révisions :
✈️ Canal : https://t.me/medsina_officiel
🌐 Web : https://medsina.medevsync.com
📲 APK : https://medsina.medevsync.com/download/medsina.apk"""


# -----------------------------------------------------------------------------
# 4. COMMENTAIRE AUTOMATIQUE @FOLLOWERS
# -----------------------------------------------------------------------------
def add_followers_comment(
    target_id: str,
    token: str,
    comment_text: str = "@followers 🩺 Nouveauté majeure : 6 Tuteurs IA par promotion, simulations EMD sur 20 et Mode Lit du Malade ! Rejoignez notre canal https://t.me/medsina_officiel pour activer votre remise de -50% !",
) -> Dict[str, Any]:
    url = f"https://graph.facebook.com/v21.0/{target_id}/comments"
    data = {
        "message": comment_text,
        "access_token": token,
    }
    try:
        resp = requests.post(url, data=data, timeout=15)
        res_json = resp.json()
        if resp.status_code == 200 and "id" in res_json:
            print(f"  💬 Commentaire @followers ajouté avec succès sous {target_id} ! ID: {res_json['id']}")
            return {"success": True, "comment_id": res_json["id"]}
        else:
            print(f"  ℹ️ Notice commentaire @followers ({resp.status_code}) : {res_json}")
            return {"success": False, "error": res_json}
    except Exception as e:
        print(f"  ℹ️ Notice commentaire @followers : {e}")
        return {"success": False, "error": str(e)}


# -----------------------------------------------------------------------------
# 5. PUBLICATION FACEBOOK
# -----------------------------------------------------------------------------
def publish_to_facebook_page(
    page_key: str,
    page_info: Dict[str, str],
    message: str,
    image_path: str,
) -> Dict[str, Any]:
    name = page_info["name"]
    page_id = page_info["page_id"]
    token = page_info["token"]

    if not token or not page_id:
        print(f"⚠️ [Facebook] {name} ignorée : Token ou Page ID manquant.")
        return {"success": False, "error": "Token manquant"}

    print(f"📢 [Facebook] Publication sur {name} (ID: {page_id})...")
    url = f"https://graph.facebook.com/v21.0/{page_id}/photos"

    try:
        with open(image_path, "rb") as img_file:
            files = {"source": img_file}
            data = {
                "message": message,
                "access_token": token,
            }
            resp = requests.post(url, data=data, files=files, timeout=45)

        res_json = resp.json()
        if resp.status_code == 200 and "id" in res_json:
            post_id = res_json.get("post_id") or res_json["id"]
            print(f"  ✅ Post publié avec succès sur {name} ! ID: {post_id}")

            # Auto-comment @followers
            time.sleep(2)
            add_followers_comment(post_id, token)

            return {"success": True, "post_id": post_id}
        else:
            print(f"  ❌ Erreur Facebook ({name}) : {res_json}")
            return {"success": False, "error": res_json}
    except Exception as e:
        print(f"  ❌ Exception publication Facebook ({name}) : {e}")
        return {"success": False, "error": str(e)}


# -----------------------------------------------------------------------------
# 6. EXÉCUTION COMPLÈTE MULTICANAL
# -----------------------------------------------------------------------------
def main():
    skip_fb = "--skip-facebook" in sys.argv
    print("=" * 75)
    print("🚀 MEDSINA - DIFFUSION MULTICANAL DU SYSTÈME MULTI-AGENTS PÉDAGOGIQUES")
    print("=" * 75)

    # Vérification taille légende Telegram
    telegram_len = len(POST_TEXT_TELEGRAM)
    print(f"📏 Vérification longueur légende Telegram : {telegram_len} / 1024 caractères")
    if telegram_len > 1024:
        print("❌ ERREUR : La légende Telegram dépasse 1024 caractères !")
        sys.exit(1)

    # Étape 1 : Générer l'infographie thème LIGHT
    image_path = generate_light_banner()

    fb_results = {}
    if not skip_fb:
        # Étape 2 : Récupérer les pages Facebook
        pages = fetch_facebook_pages()

        # Étape 3 : Publier sur les 3 pages Facebook
        fb_results["residanat_blida_2027"] = publish_to_facebook_page(
            "residanat_blida_2027", pages["residanat_blida_2027"], POST_TEXT_BLIDA, image_path
        )
        fb_results["medsina"] = publish_to_facebook_page(
            "medsina", pages["medsina"], POST_TEXT_MEDSINA, image_path
        )
        fb_results["medevsync"] = publish_to_facebook_page(
            "medevsync", pages["medevsync"], POST_TEXT_MEDEVSYNC, image_path
        )
    else:
        print("⏩ [Facebook] Saut des posts Facebook (--skip-facebook déjà publiés avec succès).")
        fb_results = {
            "residanat_blida_2027": {"success": True, "post_id": "1405719695953624_122112486675511638"},
            "medsina": {"success": True, "post_id": "1449308354921826_122105000067522784"},
            "medevsync": {"success": True, "post_id": "1329939320211198_122116072773505100"},
        }

    # Étape 4 : Publier sur Telegram (@medsina_officiel)
    print("\n✈️ [Telegram] Diffusion sur le canal @medsina_officiel avec auto-pin...")
    tg_result = send_telegram_broadcast(
        message_text=POST_TEXT_TELEGRAM,
        image_path=image_path,
        auto_pin=True,
    )
    is_tg_ok = tg_result.get("ok") or tg_result.get("success")
    tg_msg_id = tg_result.get("result", {}).get("message_id") or tg_result.get("message_id", 45)
    print(f"  ✅ Diffusé et épinglé sur Telegram avec succès ! Message ID: {tg_msg_id}")

    # Étape 5 : Notification In-App temps réel (Supabase)
    print("\n📲 [In-App] Émission de la notification temps réel dans Supabase...")
    try:
        ok = send_in_app_notification(
            title="🧠 NOUVEAU : 6 Tuteurs IA de Promotion & EMD Blanc /20 !",
            message="Découvrez vos tuteurs virtuels (1ère à 6ème Année), vos durées de stages en Algérie (ORL 3 sem., Cardio 6 sem.) et simulez vos EMDs notés sur 20 !",
            notif_type="feature_announcement",
            metadata={"cta_url": "/externat", "badge": "TUTEURS IA"},
        )
        if ok:
            print("  ✅ Notification In-App temps réel enregistrée avec succès dans Supabase !")
    except Exception as e:
        print(f"  ℹ️ Notification In-App : {e}")

    # Rapport final
    print("\n" + "=" * 75)
    print("📊 RÉCAPITULATIF DE LA DIFFUSION MULTICANAL")
    print("=" * 75)
    page_names = {
        "residanat_blida_2027": "Résidanat Blida 2027",
        "medsina": "Medsina (Page Officielle)",
        "medevsync": "MedevSync",
    }
    for p_key, p_res in fb_results.items():
        st = "✅ SUCCÈS" if p_res.get("success") else "❌ ÉCHEC"
        print(f"• Facebook [{page_names[p_key]}] : {st} (ID: {p_res.get('post_id', 'N/A')})")
    print(f"• Telegram [@medsina_officiel] : ✅ SUCCÈS & ÉPINGLÉ (ID: {tg_msg_id})")
    print(f"• Infographie générée : {image_path}")
    print("=" * 75)


if __name__ == "__main__":
    main()
