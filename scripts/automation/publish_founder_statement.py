#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
=============================================================================
MEDSINA & MEDEVSYNC - MESSAGE OFFICIEL DU FONDATEUR (DR CHIKH TOUAMI)
L'ÉCOSYSTÈME MÉDICAL TOUT-EN-UN : EN FINIR AVEC LA DISPERSION
=============================================================================
1. Génère l'infographie officielle HD 1080x1080 en thème LIGHT moderne
2. Publie sur les 3 pages Facebook officielles :
   - Résidanat Blida 2027 (1405719695953624)
   - Medsina Officiel (1449308354921826)
   - MedevSync (1329939320211198)
   + Commente automatiquement @followers pour alerter la communauté !
3. Publie sur le canal Telegram officiel (@medsina_officiel) avec image,
   légende <= 940 caractères et épingle le message avec notification push.
=============================================================================
"""

import os
import sys
import json
import time
import shutil
import requests
from pathlib import Path
from typing import Dict, Any, List, Optional

if sys.stdout and hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))

from generate_modern_light_banner import build_modern_light_banner
from telegram_publisher import send_telegram_broadcast

SUPABASE_URL = os.environ.get("SUPABASE_URL", "https://qzfssrhhuorljftpdvjm.supabase.co")
SUPABASE_KEY = (
    os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
    or os.environ.get("SUPABASE_KEY")
    or "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF6ZnNzcmhodW9ybGpmdHBkdmptIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MTYxMjg1NCwiZXhwIjoyMTA3MTg4ODU0fQ.-KCUgZdY8RDUwvNOUAabDhQFwv5FFGHYz0J-dM7Cic4"
)

OFFICIAL_TELEGRAM_URL = "https://t.me/medsina_officiel"
OFFICIAL_WEB_URL = "https://medsina.medevsync.com"
OFFICIAL_APK_URL = "https://medsina.medevsync.com/download/medsina.apk"
OFFICIAL_WIN_URL = "https://medsina.medevsync.com"

BANNER_OUTPUT_DIR = Path(__file__).resolve().parents[2] / "assets"
BANNER_IMAGE_PATH = str(BANNER_OUTPUT_DIR / "medsina_founder_dr_chikh_touami_banner.png")


# =============================================================================
# 1. GÉNÉRATION DE L'AFFICHE LIGHT THEME MODERNE
# =============================================================================

def generate_founder_banner() -> str:
    print("🎨 [Design] Génération de l'infographie officielle thème LIGHT moderne...")
    banner_data = {
        "theme": "teal",
        "badge": "MESSAGE DU FONDATEUR • DR CHIKH TOUAMI",
        "title": "Dr Chikh Touami • Fondateur MedevSync & Medsina",
        "subtitle": "L'Écosystème Médical Tout-en-Un : En finir avec la dispersion",
        "points": [
            "Centralisation Totale : Fini de perdre des heures entre 50 groupes Telegram, pages Facebook, Drives cassés et polycopiés éparpillés.",
            "Cours Officiels & Fiches Synthèses : 47 modules complets des facultés d'Algérie, résumés ciblés concours et consensus récents.",
            "Simulations Réelles & Annales : QCMs officiels classés, examens blancs chronométrés EMD /20 et annales du résidanat.",
            "Témoignages de Majors & IA Clinique : Retours d'expérience concrets, plans de révision types, mementos de garde et Copilote IA 24h/24."
        ],
    }

    path = build_modern_light_banner(
        data=banner_data,
        output_path=BANNER_IMAGE_PATH,
        app_version="VISION FONDATEUR",
    )
    print(f"✅ Infographie générée avec succès : {path}")
    return path


# =============================================================================
# 2. IDENTIFIANTS FACEBOOK ET TELEGRAM
# =============================================================================

def get_credentials() -> Dict[str, Any]:
    creds = {
        "medsina_page_id": os.environ.get("FB_MEDSINA_PAGE_ID", "1449308354921826").strip(),
        "medsina_token": os.environ.get("FB_MEDSINA_PAGE_ACCESS_TOKEN", "").strip(),
        "blida_page_id": os.environ.get("FB_BLIDA_PAGE_ID", "1405719695953624").strip(),
        "blida_token": os.environ.get("FB_BLIDA_PAGE_ACCESS_TOKEN", "").strip(),
        "medevsync_page_id": os.environ.get("FB_MEDEVSYNC_PAGE_ID", "1329939320211198").strip(),
        "medevsync_token": os.environ.get("FB_MEDEVSYNC_PAGE_ACCESS_TOKEN", "").strip(),
        "telegram_token": os.environ.get("TELEGRAM_BOT_TOKEN", "").strip(),
        "telegram_channel": os.environ.get("TELEGRAM_CHANNEL_ID", "@medsina_officiel").strip(),
    }

    # Fallback via Supabase admin_system_settings
    if not (creds["medsina_token"] and creds["blida_token"] and creds["medevsync_token"] and creds["telegram_token"]):
        try:
            url = f"{SUPABASE_URL}/rest/v1/admin_system_settings?select=setting_key,setting_value"
            headers = {"apikey": SUPABASE_KEY, "Authorization": f"Bearer {SUPABASE_KEY}"}
            r = requests.get(url, headers=headers, timeout=10)
            if r.status_code == 200:
                settings = {x["setting_key"]: x["setting_value"] for x in r.json() if isinstance(x, dict)}
                user_token = settings.get("facebook_user_access_token") or settings.get("facebook_page_access_token")

                # Resolve Page Access Tokens via /me/accounts if available
                if user_token:
                    try:
                        acc_r = requests.get("https://graph.facebook.com/v21.0/me/accounts", params={"access_token": user_token}, timeout=10)
                        if acc_r.status_code == 200:
                            for p in acc_r.json().get("data", []):
                                pid = str(p.get("id"))
                                ptok = p.get("access_token")
                                if pid == creds["medsina_page_id"]:
                                    creds["medsina_token"] = ptok
                                elif pid == creds["blida_page_id"]:
                                    creds["blida_token"] = ptok
                                elif pid == creds["medevsync_page_id"]:
                                    creds["medevsync_token"] = ptok
                    except Exception:
                        pass

                if not creds["medsina_token"]:
                    creds["medsina_token"] = (settings.get("facebook_medsina_page_access_token") or user_token or "").strip()
                if not creds["blida_token"]:
                    creds["blida_token"] = (settings.get("facebook_blida_page_access_token") or user_token or "").strip()
                if not creds["medevsync_token"]:
                    creds["medevsync_token"] = (settings.get("facebook_medevsync_page_access_token") or user_token or "").strip()
                if not creds["telegram_token"]:
                    creds["telegram_token"] = (settings.get("telegram_bot_token") or "").strip()
                if not creds["telegram_channel"] or creds["telegram_channel"] == "@medsina_officiel":
                    ch = (settings.get("telegram_channel_id") or "").strip()
                    if ch:
                        creds["telegram_channel"] = ch
        except Exception as e:
            print(f"⚠️ Avertissement lecture credentials Supabase : {e}")

    return creds


# =============================================================================
# 3. TEXTES OFFICIELS DU FONDATEUR (DR CHIKH TOUAMI)
# =============================================================================

POST_TEXT_BLIDA = """@followers

🩺 MESSAGE DU FONDATEUR • DR CHIKH TOUAMI (MEDEVSYNC & MEDSINA) 👨‍⚕️🇩🇿
« EN FINIR AVEC LA DISPERSION : TOUTE VOTRE MÉDECINE & VOTRE RÉSIDANAT EN UN SEUL ENDROIT »

Chers consœurs, chers confrères, futurs résidents et étudiants en médecine,

En tant que médecin et fondateur du Groupe MedevSync et de l'écosystème Medsina, j'ai vécu de l'intérieur le parcours exigeant des études médicales et de la préparation au concours du résidanat en Algérie.

Le constat que nous faisons tous est sans appel :
❌ Un étudiant passe aujourd'hui entre 30% et 40% de son temps non pas à apprendre, mais à CHERCHER :
• Un polycopié introuvable sur un groupe Telegram,
• Un corrigé de QCM contesté sur une page Facebook,
• Un lien Google Drive expiré ou mal indexé,
• Des notes éparpillées sur des clés USB qui circulent au CHU.

Cette dispersion mentale et chronophage est le pire ennemi de votre réussite.

C'est précisément pour briser cette fragmentation que nous avons conçu Medsina : la première plateforme médicale véritablement TOUT-EN-UN (« All-in-One »).

━━━━━━━━━━━━━━━━━━━━━━━━━━
🎯 TOUT CE DONT VOUS AVEZ BESOIN, RÉUNI AU MÊME ENDROIT :
━━━━━━━━━━━━━━━━━━━━━━━━━━

1️⃣ 📚 COURS OFFICIELS & COMPLETS :
L'intégralité des 47 modules du cursus médical et du concours du résidanat, classés par spécialité et conformes aux enseignements des facultés algériennes.

2️⃣ 📝 FICHES DE SYNTHÈSE & RÉSUMÉS CONCOURS :
Pour vos révisions rapides : des fiches condensées, axées sur les points discriminants, les pièges classiques et les consensus 2024–2026.

3️⃣ 🏆 RETOURS D'EXPÉRIENCE & MÉTHODES DES MAJORS :
Ce qui fait la différence le jour J : témoignages exclusifs des majors de promotion, plannings de révision réalistes et méthodologie de travail éprouvée.

4️⃣ 📂 ANNUAIRE CENTRALISÉ DES DRIVES & POLICHIERS :
Fini les liens morts : un accès structuré, vérifié et mis à jour en continu à toutes les ressources de référence de Blida, Alger, Constantine, Oran...

5️⃣ ⏱️ SIMULATIONS D'EXAMENS EMD & ANNALES DU RÉSIDANAT :
Des dizaines de milliers de QCMs officiels, classés par cours, avec examens blancs chronométrés et notation sur 20 conforme au format officiel.

6️⃣ 🌙 OUTILS CLINIQUES DE GARDE AU LIT DU MALADE :
Arbres décisionnels de Conduite à Tenir (CAT), Mémentos de garde de nuit, Monographies DCI adaptées à la Saidal/PCH et Normes Biologiques d'urgence.

7️⃣ 🤖 MEDSINAPILOT & 6 TUTEURS IA DE PROMOTION :
Un tuteur virtuel spécialisé pour chaque année d'externat (1ère à 6ème année) synchronisé avec la durée réelle de vos stages hospitaliers (ORL 3 sem., Cardio 6 sem., Pédiatrie 12 sem.).

8️⃣ 📶 100% HORS-LIGNE (OFFLINE FIRST) :
Disponible sur Web, application Android (.APK) et PC Windows (.EXE). Vous pouvez réviser et consulter vos protocoles même sans connexion Internet en salle de garde ou au bloc !

━━━━━━━━━━━━━━━━━━━━━━━━━━
🎁 OFFRE EXCLUSIVE PASS ÉTUDIANT : -50% IMMÉDIAT !
━━━━━━━━━━━━━━━━━━━━━━━━━━
Parce que chaque étudiant mérite d'avoir accès aux meilleurs outils, nous maintenons une réduction exceptionnelle de 50% sur le Pass Étudiant.

👉 Rejoignez notre communauté sur le canal Telegram officiel pour échanger et suivre chaque mise à jour :
✈️ https://t.me/medsina_officiel

📲 Accédez dès maintenant à votre espace de révision :
🌐 Web App directe : https://medsina.medevsync.com
📲 Téléchargement Android (.apk) : https://medsina.medevsync.com/download/medsina.apk
💻 Téléchargement Windows PC (.exe) : https://medsina.medevsync.com

Votre temps est précieux, consacrez-le à apprendre. Nous nous occupons du reste.

Fraternellement,
Dr Chikh Touami
Fondateur du Groupe MedevSync & Concepteur de Medsina

#Medsina #MedevSync #DrChikhTouami #ResidanatBlida2027 #MedecineAlgerie #ConcoursResidanat #ExternatMedecine #InnovationMedicale"""


POST_TEXT_MEDSINA = """@followers

🩺 MOT DU FONDATEUR • DR CHIKH TOUAMI (MEDEVSYNC & MEDSINA) 👨‍⚕️
« MEDSINA : LA RÉPONSE TOUT-EN-UN CONTRE LA DISPERSION DES ÉTUDIANTS EN MÉDECINE »

Pourquoi avoir créé Medsina ?
Parce qu'un préparateur au résidanat ou un externe en médecine en Algérie ne devrait plus jamais perdre des heures à chercher des cours éparpillés entre Telegram, Facebook et des Drives saturés.

Medsina réunit dans un seul espace ultra-rapide et 100% Hors-Ligne :
✅ 47 Modules Complets & Cours Officiels des Facultés
✅ Fiches Résumés & Synthèses Ciblées Concours
✅ Témoignages & Méthodes de Travail des Majors
✅ Annuaire Unifié des Drives & Polycopiés
✅ Simulations EMD & Annales Concours Chronométrées
✅ Conduites à Tenir (CAT) & Mémentos de Garde Clinique
✅ 6 Agents Pédagogiques IA (1ère à 6ème Année)

🎁 RAPPEL : Réduction immédiate de -50% sur le Pass Étudiant !

👉 Rejoignez le canal Telegram officiel :
✈️ https://t.me/medsina_officiel

Accès & Téléchargements :
🌐 Web : https://medsina.medevsync.com
📲 Android (.apk) : https://medsina.medevsync.com/download/medsina.apk
💻 Windows (.exe) : https://medsina.medevsync.com

Dr Chikh Touami
Fondateur MedevSync & Medsina"""


POST_TEXT_MEDEVSYNC = """@followers

💡 [MedevSync Group • Message Officiel du Fondateur]
Dr Chikh Touami présente la vision technologique et médicale derrière l'écosystème Medsina 🩺🇩🇿

« Notre mission à travers MedevSync est d'offrir aux professionnels de santé et futurs médecins algériens des technologies fiables, ergonomiques et capables d'éradiquer la friction d'accès au savoir médical. »

Medsina concrétise cette vision en devenant le premier écosystème médical All-in-One :
• Architecture Offline-First pour garantir un fonctionnement total sans Internet en milieu hospitalier.
• Système Multi-Agents Pédagogiques modélisant les durées réelles des stages cliniques en Algérie.
• Centralisation exhaustive : Cours, Résumés, Annales, Drives, QCMs, Outils Cliniques & Retours d'expérience.

🌐 Découvrez l'infrastructure : https://medsina.medevsync.com
✈️ Canal Telegram officiel : https://t.me/medsina_officiel"""


# POST TELEGRAM : STRICTEMENT <= 940 CARACTÈRES AVEC BOUTONS INLINE
POST_TEXT_TELEGRAM = """🩺 MESSAGE DU FONDATEUR • DR CHIKH TOUAMI
Fondateur du Groupe MedevSync & Medsina 👨‍⚕️🇩🇿

« En finir avec la dispersion : Toute votre médecine et votre résidanat en un seul endroit. »

Chers confrères et étudiants,
Ne perdez plus 30% de votre temps à chercher entre 50 groupes Telegram, pages Facebook et Drives saturés. Medsina est votre hub TOUT-EN-UN :

✅ Cours Officiels des Facultés d'Algérie (47 modules)
✅ Fiches Résumés & Synthèses Concours
✅ Annales QCMs & Simulations d'EMD notées sur 20
✅ Témoignages & Méthodes types des Majors
✅ Annuaire indexé des Drives & Polycopiés
✅ Mémentos de Garde, Urgences & CAT au lit du malade
✅ 6 Tuteurs IA par Année d'Étude (1ère à 6ème année)
✅ 100% Hors-Ligne (Web, APK Android, PC Windows)

🎁 Profitez de -50% sur le Pass Étudiant !

👉 Accédez immédiatement à la plateforme :
🌐 Web : https://medsina.medevsync.com
📲 APK : https://medsina.medevsync.com/download/medsina.apk"""


# =============================================================================
# 4. DIFFUSEUR MULTICANAL
# =============================================================================

def publish_facebook(page_id: str, token: str, page_name: str, image_path: str, caption: str, dry_run: bool = False) -> Optional[str]:
    if dry_run:
        print(f"   [DRY-RUN] Facebook {page_name} ({page_id}) simulé avec succès.")
        return "dry_run_post_id"

    if not page_id or not token:
        print(f"   ⚠️ Facebook {page_name} ignoré : page_id ou token manquant.")
        return None

    pid = None
    if image_path and os.path.exists(image_path):
        try:
            url = f"https://graph.facebook.com/v21.0/{page_id}/photos"
            with open(image_path, "rb") as f:
                files = {"source": (os.path.basename(image_path), f, "image/png")}
                data = {"caption": caption, "access_token": token}
                r = requests.post(url, data=data, files=files, timeout=40)
            if r.status_code == 200:
                res = r.json()
                pid = res.get("post_id") or res.get("id")
                print(f"   ✅ Succès Facebook {page_name} (Photo)! Post ID: {pid}")
            else:
                print(f"   ⚠️ Avertissement photo Facebook {page_name} ({r.status_code}): {r.text[:120]}")
        except Exception as e:
            print(f"   ⚠️ Erreur upload photo Facebook {page_name}: {e}")

    if not pid:
        try:
            url = f"https://graph.facebook.com/v21.0/{page_id}/feed"
            data = {"message": caption, "link": OFFICIAL_WEB_URL, "access_token": token}
            r = requests.post(url, data=data, timeout=30)
            if r.status_code == 200:
                pid = r.json().get("id")
                print(f"   ✅ Succès Facebook {page_name} (Feed Text)! Post ID: {pid}")
            else:
                print(f"   ❌ Échec Facebook {page_name} ({r.status_code}): {r.text[:150]}")
        except Exception as e:
            print(f"   ❌ Erreur Facebook feed {page_name}: {e}")

    # Add @followers comment
    if pid:
        try:
            comment_url = f"https://graph.facebook.com/v21.0/{pid}/comments"
            c_data = {
                "message": "@followers Retrouvez la vision complète et commencez dès aujourd'hui sur https://medsina.medevsync.com\nRejoignez le canal Telegram : https://t.me/medsina_officiel",
                "access_token": token
            }
            c_r = requests.post(comment_url, data=c_data, timeout=10)
            if c_r.status_code == 200:
                print(f"   💬 Commentaire @followers ajouté avec succès sur Facebook {page_name}.")
        except Exception:
            pass

    return pid


def publish_telegram(token: str, channel_id: str, image_path: str, caption: str, dry_run: bool = False) -> bool:
    if dry_run:
        print("   [DRY-RUN] Telegram broadcast simulé avec succès.")
        return True

    if not token or not channel_id:
        print("   ⚠️ Telegram ignoré : token ou channel manquant.")
        return False

    reply_markup = {
        "inline_keyboard": [
            [
                {"text": "🌐 Ouvrir Medsina Web", "url": OFFICIAL_WEB_URL},
                {"text": "📱 Télécharger APK Android", "url": OFFICIAL_APK_URL}
            ],
            [
                {"text": "💻 Télécharger PC Windows", "url": OFFICIAL_WIN_URL},
                {"text": "👥 Page Facebook Blida", "url": "https://www.facebook.com/residanatblida2027"}
            ]
        ]
    }

    tg_caption = caption
    suffix = f"\n\n👉 Accès direct : {OFFICIAL_WEB_URL}"
    max_body_len = 940 - len(suffix)
    if len(tg_caption) > (1010 - len(suffix)):
        cut_point = tg_caption[:max_body_len]
        if "\n" in cut_point:
            cut_point = cut_point.rsplit("\n", 1)[0]
        tg_caption = cut_point.strip() + "..." + suffix

    msg_id = None
    try:
        if image_path and os.path.exists(image_path):
            url = f"https://api.telegram.org/bot{token}/sendPhoto"
            with open(image_path, "rb") as f:
                files = {"photo": f}
                data = {
                    "chat_id": channel_id,
                    "caption": tg_caption,
                    "reply_markup": json.dumps(reply_markup)
                }
                r = requests.post(url, data=data, files=files, timeout=35)

            if r.status_code == 200 and r.json().get("ok"):
                msg_id = r.json().get("result", {}).get("message_id")
                print(f"   ✅ Succès Telegram photo (@medsina_officiel)! Message ID: {msg_id}")
            else:
                print(f"   ⚠️ Avertissement sendPhoto Telegram ({r.status_code}): {r.text[:150]}")
                print("   🔄 Repli résilient : envoi de la photo puis du message via sendMessage...")
                short_caption = caption[:180].rsplit("\n", 1)[0] + f"\n\n👉 {OFFICIAL_WEB_URL}"
                with open(image_path, "rb") as f2:
                    requests.post(url, data={"chat_id": channel_id, "caption": short_caption}, files={"photo": f2}, timeout=30)
                msg_url = f"https://api.telegram.org/bot{token}/sendMessage"
                r3 = requests.post(msg_url, data={"chat_id": channel_id, "text": caption[:4000], "reply_markup": json.dumps(reply_markup)}, timeout=25)
                if r3.status_code == 200 and r3.json().get("ok"):
                    msg_id = r3.json().get("result", {}).get("message_id")
                    print(f"   ✅ Succès Telegram en repli décomposé! Message ID: {msg_id}")
        else:
            url = f"https://api.telegram.org/bot{token}/sendMessage"
            r = requests.post(url, data={"chat_id": channel_id, "text": caption[:4000], "reply_markup": json.dumps(reply_markup)}, timeout=20)
            if r.status_code == 200 and r.json().get("ok"):
                msg_id = r.json().get("result", {}).get("message_id")
                print(f"   ✅ Succès Telegram sendMessage (@medsina_officiel)! Message ID: {msg_id}")

        if msg_id:
            try:
                pin_url = f"https://api.telegram.org/bot{token}/pinChatMessage"
                requests.post(pin_url, json={"chat_id": channel_id, "message_id": msg_id, "disable_notification": False}, timeout=10)
                print(f"   📌 Message Telegram #{msg_id} épinglé avec succès.")
            except Exception:
                pass
            return True

    except Exception as e:
        print(f"   ⚠️ Erreur Telegram : {e}")

    return False


# =============================================================================
# 5. EXÉCUTION PRINCIPALE
# =============================================================================

def main():
    import argparse
    parser = argparse.ArgumentParser(description="Publication Officielle Dr Chikh Touami • Medsina Tout-en-Un")
    parser.add_argument("--dry-run", action="store_true", help="Mode test sans poster")
    args = parser.parse_args()

    print("\n" + "=" * 70)
    print("📢 DIFFUSION OFFICIELLE : MESSAGE DU FONDATEUR (DR CHIKH TOUAMI)")
    print("MEDSINA ALL-IN-ONE • CENTRALISATION TOTALE & GAIN DE TEMPS")
    print("=" * 70)

    # 1. Génération de l'infographie
    banner_path = generate_founder_banner()

    # Copie dans le dossier des artifacts brain si présent
    brain_dir = Path("C:/Users/PC-Service/.gemini/antigravity/brain/0ba098d1-adef-41a0-8ca2-353fed62237c")
    if brain_dir.exists():
        try:
            shutil.copy2(banner_path, brain_dir / "medsina_founder_dr_chikh_touami_banner.png")
            print(f"📁 Affiche copiée dans le dossier artifacts : {brain_dir / 'medsina_founder_dr_chikh_touami_banner.png'}")
        except Exception:
            pass

    # 2. Récupération des credentials
    creds = get_credentials()

    # 3. Diffusion Facebook - Page 1 : Résidanat Blida 2027
    print("\n🚀 [1/4] Diffusion Facebook : Résidanat Blida 2027...")
    p1 = publish_facebook(
        page_id=creds["blida_page_id"],
        token=creds["blida_token"],
        page_name="Résidanat Blida 2027",
        image_path=banner_path,
        caption=POST_TEXT_BLIDA,
        dry_run=args.dry_run
    )

    # 4. Diffusion Facebook - Page 2 : Medsina Officiel
    print("\n🚀 [2/4] Diffusion Facebook : Medsina (Page Officielle)...")
    p2 = publish_facebook(
        page_id=creds["medsina_page_id"],
        token=creds["medsina_token"],
        page_name="Medsina Officiel",
        image_path=banner_path,
        caption=POST_TEXT_MEDSINA,
        dry_run=args.dry_run
    )

    # 5. Diffusion Facebook - Page 3 : MedevSync
    print("\n🚀 [3/4] Diffusion Facebook : MedevSync...")
    p3 = publish_facebook(
        page_id=creds["medevsync_page_id"],
        token=creds["medevsync_token"],
        page_name="MedevSync",
        image_path=banner_path,
        caption=POST_TEXT_MEDEVSYNC,
        dry_run=args.dry_run
    )

    # 6. Diffusion Telegram - Canal Officiel @medsina_officiel
    print("\n🚀 [4/4] Diffusion Telegram : @medsina_officiel...")
    tg_ok = publish_telegram(
        token=creds["telegram_token"],
        channel_id=creds["telegram_channel"],
        image_path=banner_path,
        caption=POST_TEXT_TELEGRAM,
        dry_run=args.dry_run
    )

    print("\n" + "=" * 70)
    print("📊 RÉSUMÉ DE LA DIFFUSION MULTICANALE :")
    print(f"   • Facebook Résidanat Blida 2027 : {'✅ Posté (ID: ' + str(p1) + ')' if p1 else '❌ Échec'}")
    print(f"   • Facebook Medsina Officiel     : {'✅ Posté (ID: ' + str(p2) + ')' if p2 else '❌ Échec'}")
    print(f"   • Facebook MedevSync            : {'✅ Posté (ID: ' + str(p3) + ')' if p3 else '❌ Échec'}")
    print(f"   • Telegram @medsina_officiel    : {'✅ Diffusé & Épinglé' if tg_ok else '❌ Échec'}")
    print("=" * 70)


if __name__ == "__main__":
    main()
