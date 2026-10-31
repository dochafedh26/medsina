#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
=============================================================================
DIFFUSEUR MULTI-CANAL : PROMOTION DU FORUM TELEGRAM MEDSINA-COMMUNITY
=============================================================================
Publie simultanément sur :
1. Facebook Page « Résidanat Blida 2027 » (ID: 1405719695953624)
2. Facebook Page Officielle « Medsina » (ID: 1449308354921826)
3. Facebook Page Partenaire « MedevSync » (ID: 1329939320211198)
4. Facebook Page « CAT aux Urgences » (ID: 102416914491075)
5. Telegram Canal Officiel « @medsina_officiel »
6. Telegram Supergroupe Forum « MEDSINA-COMMUNITY » (Topic #General)

Objectifs de la communication :
- Annoncer l'ouverture du supergroupe Telegram forum MEDSINA-COMMUNITY avec 9 Topics.
- Résoudre le problème numéro 1 des étudiants : la dispersion dans 50 groupes et drives.
- Orienter et motiver vers l'application Medsina Tout-en-Un (Web, Android APK, Windows PC).
=============================================================================
"""

import os
import sys
import json
import argparse
import requests
import shutil
from pathlib import Path
from typing import Dict, Any, Optional

try:
    if sys.stdout.encoding.lower() != 'utf-8':
        sys.stdout.reconfigure(encoding='utf-8')
except Exception:
    pass

sys.path.insert(0, str(Path(__file__).resolve().parent))
from social_teaser_broadcaster import get_social_credentials
from telegram_publisher import send_telegram_broadcast, OCTENIUM_WEB_URL, OCTENIUM_APK_URL, OCTENIUM_EXE_URL

TELEGRAM_COMMUNITY_INVITE = "https://t.me/+TVTTgt8eIMk5NmI0"

BANNER_PATH = Path(__file__).resolve().parents[2] / "assets" / "medsina_community_telegram_forum_banner.png"

# =============================================================================
# RÉDACTION DES PUBLICATIONS FACEBOOK & TELEGRAM
# =============================================================================

POST_FACEBOOK_GENERAL = f"""📢 @followers | ANNONCE OFFICIELLE : LANCEMENT DU FORUM TELEGRAM « MEDSINA-COMMUNITY » ! 🇩🇿⚡

Chers confrères, internes, préparateurs du concours et étudiants en médecine :

En tant que Dr Chikh Touami, fondateur du Groupe MedevSync et concepteur de l'application Medsina, j'ai constaté depuis des années le fléau n°1 qui ralentit nos révisions et épuise nos candidats :
❌ LA DISPERSION TOTALE :
Des dizaines de groupes Facebook, des canaux Telegram éparpillés, des dossiers Google Drive aux liens expirés, des cours obsolètes et des discussions mélangées où l'on perd des heures à chercher une simple conduite à tenir ou un QCM corrigé.

Aujourd'hui, nous mettons un terme définitif au désordre avec deux solutions complémentaires conçues pour vous faire gagner un temps précieux :

━━━━━━━━━━━━━━━━━━━━━━━━━━
🏛️ 1. LE FORUM TELEGRAM « MEDSINA-COMMUNITY » (ORGANISÉ PAR TOPICS)
Nous avons créé un Supergroupe structuré en 9 Espaces Thématiques Dédiés pour échanger sans aucun bruit :

1️⃣ 📌 #General : Mises à jour, annonces et mot du fondateur
2️⃣ 🚨 #CONDUITES PRATIQUES : Conduites à tenir (CAT) d'urgence, arbres décisionnels
3️⃣ 📚 #RESIDANAT-BLIDA-2027-COURS : Polycopiés officiels des facultés & drives vérifiés
4️⃣ 🌙 #MEMENTO DE GARDES : Mémentos de garde hospitalière, pharmacie Saidal/PCH, normes bio
5️⃣ 🏥 #CURSUS EXTERNAT BLIDA 2027 : Stages hospitaliers, durées réelles & tuteurs IA
6️⃣ 💡 #RESIDANAT-BLIDA-2027-RESUMES : Fiches de synthèse haute rentabilité & perles cliniques
7️⃣ 🏆 #RESIDANAT-BLIDA-2027-TEMOIGNAGES : Retours d'expérience des majors & plannings
8️⃣ 🎯 #RESIDANAT-BLIDA-2027-CONCOURS-PRATIQUE : QCMs d'annales classées & corrigés officiels
9️⃣ 📝 #CURSUS-EXTERNAT-BLIDA-2027- PRATIQUE EMD : Examens blancs de stage notés sur 20

👉 Rejoignez dès maintenant le Forum Telegram :
🔗 {TELEGRAM_COMMUNITY_INVITE}

━━━━━━━━━━━━━━━━━━━━━━━━━━
🚀 2. LE CŒUR DE TOUT : L'APPLICATION « MEDSINA TOUT-EN-UN »
Le forum Telegram est l'espace d'échange, mais l'APPLICATION MEDSINA est votre quartier général où TOUT est réuni en un seul endroit :

• 47 Modules officiels du résidanat et de l'externat
• Des milliers de QCMs d'annales classés par cours avec corrections détaillées
• Arbres décisionnels interactifs étape par étape
• Mémentos de garde et monographies de posologies d'urgence
• Fiches résumés, témoignages des majors et plannings
• Tuteurs pédagogiques IA par année d'études
• ⚡ 100% Hors-Ligne (en salle de garde, au bloc UMC ou chez vous sans internet)

Ne perdez plus 1 heure par jour à chercher des fichiers. Concentrez-vous sur l'apprentissage !

📲 ACCÉDEZ À L'ÉCOSYSTÈME COMPLET DÈS AUJOURD'HUI :
🌐 Web App directe : {OCTENIUM_WEB_URL}
📲 Téléchargement direct APK Android : {OCTENIUM_APK_URL}
💻 Téléchargement PC Windows : {OCTENIUM_EXE_URL}
👥 Forum Telegram Communautaire : {TELEGRAM_COMMUNITY_INVITE}

Partagez avec vos confrères et binômes de révision !

#Medsina #MedevSync #ResidanatBlida2027 #ExternatMedecine #ResidanatAlgerie #UrgencesMedicales #MedecineAlgerie #AlgerieSante"""


POST_FACEBOOK_CAT_URGENCES = f"""🚨 @followers | PRATICIENS DES URGENCES & INTERNES : REJOIGNEZ LE FORUM « MEDSINA-COMMUNITY » ! 🩺⚡

En garde de nuit comme au déchocage, la rapidité d'accès aux conduites à tenir (CAT) et aux repères thérapeutiques fait toute la différence.

Fini de fouiller dans vos galeries photos, messages de groupe ou drives introuvables au lit du patient !

Le Dr Chikh Touami et l'équipe MedevSync vous ouvrent l'accès au nouveau Supergroupe Telegram « MEDSINA-COMMUNITY » doté d'espaces thématiques dédiés :

🩺 Topics Spécialisés d'Urgence :
• 🚨 #CONDUITES PRATIQUES : Protocoles réflexes d'urgence, arbres CAT interactifs
• 🌙 #MEMENTO DE GARDES : Posologies hospitalières (PCH & Saidal), scores d'alerte, seuils biologiques critiques
• 📚 #COURS & RÉSUMÉS : Fiches pratiques pour sécuriser chaque prescription

👉 Lien d'accès direct au Forum Telegram :
🔗 {TELEGRAM_COMMUNITY_INVITE}

━━━━━━━━━━━━━━━━━━━━━━━━━━
⚡ TOUT EN UN SEUL ENDROIT SUR L'APPLICATION MEDSINA :
Retrouvez les CAT complètes, les arbres interactifs et le moteur Omnisearch (recherche instantanée en 0,2s) dans l'application Medsina :
Accessible à 100% HORS-LIGNE, sans aucune dépendance au réseau au bloc ou en salle de garde !

🌐 Web App : {OCTENIUM_WEB_URL}
📲 Application Android (APK direct) : {OCTENIUM_APK_URL}
💻 Application PC Windows : {OCTENIUM_EXE_URL}

#CATauxUrgences #UrgencesMedicales #Medsina #MedevSync #GardeHospitaliere #InternatMedecine #MedecineAlgerie"""


POST_TELEGRAM_CAPTION = f"""🩺 <b>[MEDSINA • ANNONCE OFFICIELLE DU FONDATEUR]</b>
🏛️ <b>Lancement du Forum Telegram MEDSINA-COMMUNITY !</b>

Chers confrères et préparateurs :
Finie la dispersion dans 50 groupes et drives disparates !

Le <b>Dr Chikh Touami</b> et l'équipe MedevSync ont créé pour vous le <b>Supergroupe Forum Telegram</b> organisé en <b>9 Topics Thématiques</b> :

1️⃣ <b>#General</b> : Annonces officielles & versions
2️⃣ <b>#CONDUITES PRATIQUES</b> : CAT d'urgences & arbres interactifs
3️⃣ <b>#RESIDANAT-COURS</b> : Cours des facultés & drives
4️⃣ <b>#MEMENTO DE GARDES</b> : Fiches réflexes & pharmacie Saidal
5️⃣ <b>#CURSUS EXTERNAT</b> : Stages hospitaliers & tuteurs IA
6️⃣ <b>#RESIDANAT-RESUMES</b> : Fiches synthèses & perles cliniques
7️⃣ <b>#RESIDANAT-TEMOIGNAGES</b> : Retours des majors & plannings
8️⃣ <b>#CONCOURS-PRATIQUE</b> : QCMs d'annales classées & corrigés
9️⃣ <b>#PRATIQUE EMD</b> : Examens blancs de stage notés /20

━━━━━━━━━━━━━━━━━━━━
🚀 <b>TOUT EST RÉUNI SUR L'APPLICATION MEDSINA :</b>
L'application centralise <b>TOUT en un seul endroit 100% hors-ligne</b> pour réviser sans perte de temps !"""


# =============================================================================
# FONCTIONS DE PUBLICATION
# =============================================================================

def publish_facebook(page_id: str, token: str, page_name: str, image_path: Path, caption: str, dry_run: bool = False) -> Optional[str]:
    print(f"\n📢 Diffusion Facebook sur : {page_name} (ID: {page_id})...")
    if dry_run:
        print(f"   [DRY-RUN] Facebook {page_name} simulé avec succès.")
        return "dry_run_fb_id"

    if not token or not page_id:
        print(f"   ⚠️ Token ou Page ID manquant pour {page_name}.")
        return None

    try:
        url = f"https://graph.facebook.com/v21.0/{page_id}/photos"
        with open(image_path, "rb") as f:
            files = {"source": (os.path.basename(image_path), f, "image/png")}
            data = {"caption": caption, "access_token": token}
            r = requests.post(url, data=data, files=files, timeout=40)

        if r.status_code == 200:
            post_id = r.json().get("post_id") or r.json().get("id")
            print(f"   ✅ Succès Facebook {page_name} ! Post ID: {post_id}")
            print(f"   🔗 https://www.facebook.com/{post_id}")
            return post_id
        else:
            print(f"   ❌ Erreur Facebook {page_name} ({r.status_code}): {r.text[:200]}")
            return None
    except Exception as e:
        print(f"   ❌ Exception Facebook {page_name}: {e}")
        return None


def run_multi_channel_promo(dry_run: bool = False) -> Dict[str, Any]:
    print("=" * 70)
    print("🚀 LANCEMENT DE LA PROMOTION MULTI-CANAL : FORUM MEDSINA-COMMUNITY")
    print(f"⚙️ Mode : {'SIMULATION (--dry-run)' if dry_run else 'PRODUCTION RÉELLE'}")
    print("=" * 70)

    creds = get_social_credentials()

    if not BANNER_PATH.exists():
        print(f"⚠️ Affiche non trouvée à : {BANNER_PATH}")
        sys.exit(1)

    print(f"🖼️ Affiche marketing validée : {BANNER_PATH} ({os.path.getsize(BANNER_PATH) // 1024} Ko)")

    results = {
        "facebook_blida": None,
        "facebook_medsina": None,
        "facebook_medevsync": None,
        "facebook_cat": None,
        "telegram_channel": None,
        "telegram_community": None,
    }

    # 1. Facebook Page Résidanat Blida 2027
    results["facebook_blida"] = publish_facebook(
        page_id=creds["blida_page_id"],
        token=creds["blida_token"],
        page_name="Résidanat Blida 2027",
        image_path=BANNER_PATH,
        caption=POST_FACEBOOK_GENERAL,
        dry_run=dry_run
    )

    # 2. Facebook Page Medsina Officielle
    results["facebook_medsina"] = publish_facebook(
        page_id=creds["medsina_page_id"],
        token=creds["medsina_token"],
        page_name="Medsina Officiel",
        image_path=BANNER_PATH,
        caption=POST_FACEBOOK_GENERAL,
        dry_run=dry_run
    )

    # 3. Facebook Page MedevSync
    results["facebook_medevsync"] = publish_facebook(
        page_id=creds["medevsync_page_id"],
        token=creds["medevsync_token"],
        page_name="MedevSync Partenaire",
        image_path=BANNER_PATH,
        caption=POST_FACEBOOK_GENERAL,
        dry_run=dry_run
    )

    # 4. Facebook Page CAT aux Urgences
    results["facebook_cat"] = publish_facebook(
        page_id=creds["cat_page_id"],
        token=creds["cat_token"],
        page_name="CAT aux Urgences",
        image_path=BANNER_PATH,
        caption=POST_FACEBOOK_CAT_URGENCES,
        dry_run=dry_run
    )

    # 5. Telegram Canal Officiel & Forum Communautaire (Topic #General)
    print("\n✈️ Diffusion sur Telegram (Canal Officiel & Topic #General Communauté)...")
    try:
        promo_keyboard = {
            "inline_keyboard": [
                [
                    {"text": "👥 Rejoindre le Forum Telegram", "url": TELEGRAM_COMMUNITY_INVITE},
                    {"text": "🌐 Ouvrir Medsina Web", "url": OCTENIUM_WEB_URL}
                ],
                [
                    {"text": "📱 Télécharger APK Android", "url": OCTENIUM_APK_URL},
                    {"text": "💻 Télécharger PC Windows", "url": OCTENIUM_EXE_URL}
                ]
            ]
        }
        tg_res = send_telegram_broadcast(
            message_text=POST_TELEGRAM_CAPTION,
            image_path=str(BANNER_PATH),
            bot_token=creds["telegram_token"],
            channel_id=creds["telegram_channel"],
            community_group_id=creds.get("telegram_community"),
            topic_id=1,  # Topic #General
            inline_keyboard=promo_keyboard,
            dry_run=dry_run,
            auto_pin=True,
            broadcast_to_community=True
        )
        results["telegram_channel"] = tg_res.get("channel_msg_id") or ("dry_run" if dry_run else None)
        results["telegram_community"] = tg_res.get("community_msg_id") or ("dry_run" if dry_run else None)
        print(f"   ✅ Telegram résultat : {tg_res}")
    except Exception as e:
        print(f"   ❌ Erreur Telegram : {e}")

    print("\n" + "=" * 70)
    print("📊 RÉSUMÉ FINAL DE LA DIFFUSION MULTI-CANAL :")
    for ch, status in results.items():
        print(f"  • {ch.upper():20} : {status or 'ÉCHEC'}")
    print("=" * 70)

    return results


def main():
    parser = argparse.ArgumentParser(description="Multi-Channel Broadcaster for Medsina-Community Forum Launch")
    parser.add_argument("--dry-run", action="store_true", help="Simulate without publishing")
    args = parser.parse_args()

    run_multi_channel_promo(dry_run=args.dry_run)


if __name__ == "__main__":
    main()
