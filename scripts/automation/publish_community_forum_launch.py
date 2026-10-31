#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
=============================================================================
DIFFUSEUR MULTI-CANAL : PROMOTION DU FORUM TELEGRAM MEDSINA-COMMUNITY
=============================================================================
Publie simultanément sur :
1. Facebook Page « Résidanat Blida 2027 » (ID: 1405719695953624)
2. Facebook Page Partenaire « MedevSync » (ID: 1329939320211198)
3. Facebook Page « CAT aux Urgences » (ID: 102416914491075)
4. Telegram Canal Officiel « @medsina_officiel »
5. Telegram Supergroupe Forum « MEDSINA-COMMUNITY » (Topic #General)

Objectifs :
- Annoncer l'ouverture du supergroupe Telegram forum MEDSINA-COMMUNITY avec 9 Topics.
- Résoudre le problème n°1 des étudiants : la dispersion dans 50 groupes et drives.
- Inviter expressément les gens à l'inscription sur Medsina Tout-en-Un.
- Intégrer en priorité le lien d'invitation direct du groupe Telegram.
=============================================================================
"""

import os
import sys
import json
import argparse
import requests
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
# RÉDACTION DES PUBLICATIONS FACEBOOK & TELEGRAM (ANONYMISÉES & CENTRÉES INSCRIPTION)
# =============================================================================

POST_FACEBOOK_GENERAL = f"""📢 @followers | FINIE LA DISPERSION : REJOIGNEZ LE GROUPE TELEGRAM & CRÉEZ VOTRE COMPTE SUR MEDSINA ! 🇩🇿⚡

Chers étudiants en médecine, internes et préparateurs du concours de Résidanat :

❌ Le fléau n°1 de tout préparateur en Algérie :
Se disperser entre 50 groupes Facebook, des canaux Telegram éparpillés, des drives aux liens morts et des cours introuvables. Vous perdez des heures chaque jour à chercher vos supports au lieu de réviser !

Pour en finir définitivement avec le désordre, deux solutions complémentaires sont à votre disposition dès aujourd'hui :

━━━━━━━━━━━━━━━━━━━━━━━━━━
🏛️ 1. LE FORUM COMMUNAUTAIRE TELEGRAM (ORGANISÉ EN 9 TOPICS DÉDIÉS)
Un Supergroupe structuré par spécialités et besoins, où chaque ressource est à sa place sans aucun bruit :

1️⃣ 📌 #General : Actualités officielles & nouveautés
2️⃣ 🚨 #CONDUITES PRATIQUES : Arbres décisionnels (CAT) & urgences
3️⃣ 📚 #RESIDANAT-BLIDA-2027-COURS : Polycopiés officiels des facultés & drives
4️⃣ 🌙 #MEMENTO DE GARDES : Fiches réflexes de garde, pharmacie Saidal/PCH, normes bio
5️⃣ 🏥 #CURSUS EXTERNAT BLIDA 2027 : Stages hospitaliers & tuteurs pédagogiques IA
6️⃣ 💡 #RESIDANAT-BLIDA-2027-RESUMES : Fiches de synthèse haute rentabilité & perles
7️⃣ 🏆 #RESIDANAT-BLIDA-2027-TEMOIGNAGES : Méthodologies & plannings des majors
8️⃣ 🎯 #RESIDANAT-BLIDA-2027-CONCOURS-PRATIQUE : Annales QCMs classées & corrigés
9️⃣ 📝 #CURSUS-EXTERNAT-BLIDA-2027- PRATIQUE EMD : Examens blancs de stage notés /20

👉 Cliquez ici pour rejoindre le Groupe Telegram :
🔗 {TELEGRAM_COMMUNITY_INVITE}

━━━━━━━━━━━━━━━━━━━━━━━━━━
🚀 2. INSCRIVEZ-VOUS SUR L'APPLICATION « MEDSINA TOUT-EN-UN »
Le forum vous oriente, mais l'APPLICATION MEDSINA est la plateforme complète où TOUT est réuni en un seul endroit :

• 47 Modules officiels du résidanat et de l'externat
• Milliers de QCMs d'annales classés par cours avec corrections détaillées
• Arbres décisionnels d'urgence étape par étape
• Fiches de synthèse, perles cliniques et témoignages des majors
• Tuteurs pédagogiques IA par année d'études
• ⚡ 100% Hors-Ligne (révisez à l'hôpital, en salle de garde ou chez vous sans internet)

🎁 CRÉEZ VOTRE COMPTE GRATUITEMENT EN 30 SECONDES :
Inscrivez-vous dès maintenant et commencez à réviser sans aucune dispersion :

🌐 Inscription & Accès Web direct : {OCTENIUM_WEB_URL}
📲 Téléchargement direct APK Android : {OCTENIUM_APK_URL}
💻 Téléchargement PC Windows : {OCTENIUM_EXE_URL}
👥 Groupe Telegram Communautaire : {TELEGRAM_COMMUNITY_INVITE}

Partagez l'invitation avec vos confrères et binômes de révision !

#Medsina #MedevSync #ResidanatBlida2027 #ExternatMedecine #ResidanatAlgerie #UrgencesMedicales #MedecineAlgerie #AlgerieSante"""


POST_FACEBOOK_CAT_URGENCES = f"""🚨 @followers | PRATICIENS DES URGENCES & INTERNES : INSCRIVEZ-VOUS SUR MEDSINA & REJOIGNEZ LE GROUPE TELEGRAM ! 🩺⚡

En garde de nuit comme au déchocage, la rapidité d'accès aux conduites à tenir (CAT) et aux repères thérapeutiques fait toute la différence.

Fini de fouiller dans vos photos ou d'attendre une réponse sur des groupes désordonnés au lit du malade !

Rejoignez la communauté médicale officielle organisée par topics et inscrivez-vous sur l'application Medsina :

🩺 Espaces Spécialisés du Groupe Telegram :
• 🚨 #CONDUITES PRATIQUES : Protocoles réflexes d'urgence, arbres CAT interactifs
• 🌙 #MEMENTO DE GARDES : Posologies hospitalières (PCH & Saidal), scores d'alerte, constantes bio
• 📚 #COURS & RÉSUMÉS : Fiches pratiques pour sécuriser chaque prescription

👉 Lien d'accès direct au Groupe Telegram :
🔗 {TELEGRAM_COMMUNITY_INVITE}

━━━━━━━━━━━━━━━━━━━━━━━━━━
⚡ INSCRIVEZ-VOUS SUR MEDSINA - TOUT EST RÉUNI AU MÊME ENDROIT :
Retrouvez les CAT complètes, les arbres interactifs et le moteur Omnisearch (recherche instantanée en 0,2s) dans l'application Medsina :
Accessible à 100% HORS-LIGNE, sans aucune dépendance au réseau au bloc ou en salle de garde !

🎁 Créez votre compte gratuitement dès aujourd'hui :
🌐 Inscription & Web App : {OCTENIUM_WEB_URL}
📲 Application Android (APK direct) : {OCTENIUM_APK_URL}
💻 Application PC Windows : {OCTENIUM_EXE_URL}
👥 Groupe Telegram : {TELEGRAM_COMMUNITY_INVITE}

#CATauxUrgences #UrgencesMedicales #Medsina #MedevSync #GardeHospitaliere #InternatMedecine #MedecineAlgerie"""


POST_TELEGRAM_CAPTION = f"""🩺 <b>[MEDSINA • ANNONCE OFFICIELLE]</b>
🏛️ <b>Lancement du Forum Telegram & Inscriptions Ouvertes sur Medsina !</b>

Chers confrères et candidats au Résidanat :
Finie la dispersion dans 50 groupes et drives disparates !

Rejoignez le <b>Groupe Forum Telegram MEDSINA-COMMUNITY</b> structuré en <b>9 Topics Thématiques Dédiés</b> :
1️⃣ <b>#General</b> : Nouveautés & annonces
2️⃣ <b>#CONDUITES PRATIQUES</b> : CAT d'urgences & arbres interactifs
3️⃣ <b>#RESIDANAT-COURS</b> : Cours des facultés & drives
4️⃣ <b>#MEMENTO DE GARDES</b> : Fiches réflexes & pharmacie Saidal
5️⃣ <b>#CURSUS EXTERNAT</b> : Stages hospitaliers & tuteurs IA
6️⃣ <b>#RESIDANAT-RESUMES</b> : Fiches synthèses & perles cliniques
7️⃣ <b>#RESIDANAT-TEMOIGNAGES</b> : Méthodes & plannings des majors
8️⃣ <b>#CONCOURS-PRATIQUE</b> : QCMs d'annales classées & corrigés
9️⃣ <b>#PRATIQUE EMD</b> : Examens blancs notés /20

━━━━━━━━━━━━━━━━━━━━
🚀 <b>INSCRIVEZ-VOUS SUR MEDSINA TOUT-EN-UN :</b>
Créez votre compte gratuit en 30s et retrouvez <b>TOUT au même endroit 100% hors-ligne</b> !"""


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

    # 2. Facebook Page MedevSync
    results["facebook_medevsync"] = publish_facebook(
        page_id=creds["medevsync_page_id"],
        token=creds["medevsync_token"],
        page_name="MedevSync Partenaire",
        image_path=BANNER_PATH,
        caption=POST_FACEBOOK_GENERAL,
        dry_run=dry_run
    )

    # 3. Facebook Page CAT aux Urgences
    results["facebook_cat"] = publish_facebook(
        page_id=creds["cat_page_id"],
        token=creds["cat_token"],
        page_name="CAT aux Urgences",
        image_path=BANNER_PATH,
        caption=POST_FACEBOOK_CAT_URGENCES,
        dry_run=dry_run
    )

    # 4. Telegram Canal Officiel & Forum Communautaire (Topic #General)
    print("\n✈️ Diffusion sur Telegram (Canal Officiel & Topic #General Communauté)...")
    try:
        promo_keyboard = {
            "inline_keyboard": [
                [
                    {"text": "👥 Rejoindre le Groupe Telegram", "url": TELEGRAM_COMMUNITY_INVITE},
                    {"text": "🎁 Créer mon Compte Gratuit", "url": OCTENIUM_WEB_URL}
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
