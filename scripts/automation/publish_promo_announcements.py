#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
=============================================================================
MEDSINA — DIFFUSEUR DES DEUX ANNONCES PROMO NOVEMBRE (PHOTOS & COPYWRITING)
=============================================================================
1. Annonce 1 : Liste & Félicitations des 40 Abonnés VIP All-Access (Infographie 1)
2. Annonce 2 : Appel Inscription & Grande Surprise Fin Promo (Infographie 2)

Diffuse sur :
- Les 4 Pages Facebook officielles (Medsina, MedevSync, Résidanat Blida 2027, CAT aux Urgences)
- Telegram (@medsina_officiel + Topic 1 General MEDSINA-COMMUNITY)
- In-App Notification (table medical_notifications)
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
WORKSPACE_ROOT = SCRIPT_DIR.parents[1] if len(SCRIPT_DIR.parents) > 1 else SCRIPT_DIR
sys.path.insert(0, str(SCRIPT_DIR))

from facebook_publisher import get_all_facebook_pages
from telegram_publisher import send_telegram_broadcast
from booklet_notification_broadcaster import get_credentials

IMG_VIP = WORKSPACE_ROOT / "medsina" / "assets" / "facebook" / "medsina_promo_vip_subscribers.png"
if not IMG_VIP.exists():
    IMG_VIP = Path(r"C:\Users\PC-Service\.gemini\antigravity\brain\0752fc32-0933-427d-8738-1205d9f05bcf\medsina_promo_vip_subscribers.png")

IMG_SURPRISE = WORKSPACE_ROOT / "medsina" / "assets" / "facebook" / "medsina_promo_surprise_announcement.png"
if not IMG_SURPRISE.exists():
    IMG_SURPRISE = Path(r"C:\Users\PC-Service\.gemini\antigravity\brain\0752fc32-0933-427d-8738-1205d9f05bcf\medsina_promo_surprise_announcement.png")


def publish_photo_to_all_fb_pages(image_path: Path, caption: str, dry_run: bool = False) -> List[Dict[str, Any]]:
    pages = get_all_facebook_pages()
    results = []
    for p in pages:
        p_name = p["name"]
        p_id = p["page_id"]
        p_token = p["token"]
        print(f"   🚀 [Facebook Photo] Publication sur {p_name} ({p_id})...")
        if dry_run:
            print(f"      [Dry-Run] Simulé sur {p_name}")
            results.append({"page": p["key"], "name": p_name, "success": True, "dry_run": True})
            continue

        url = f"https://graph.facebook.com/v21.0/{p_id}/photos"
        try:
            with open(image_path, "rb") as f:
                resp = requests.post(
                    url,
                    data={"caption": caption, "access_token": p_token},
                    files={"source": (image_path.name, f, "image/png")},
                    timeout=60
                )
            if resp.status_code == 200:
                res_data = resp.json()
                post_id = res_data.get("post_id") or res_data.get("id")
                print(f"      ✅ Succès sur {p_name} ! Post ID: {post_id}")
                results.append({"page": p["key"], "name": p_name, "id": post_id, "success": True})
            else:
                print(f"      ⚠️ Erreur sur {p_name} ({resp.status_code}): {resp.text}")
                results.append({"page": p["key"], "name": p_name, "error": resp.text, "success": False})
        except Exception as e:
            print(f"      ⚠️ Exception sur {p_name}: {e}")
            results.append({"page": p["key"], "name": p_name, "error": str(e), "success": False})

    return results


def send_in_app_notification_item(title: str, message: str, notif_id: str, badge: str, dry_run: bool = False):
    supabase_url, supabase_key = get_credentials()
    payload = {
        "id": notif_id,
        "title": title,
        "message": message,
        "type": "announcement",
        "created_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "metadata": {
            "badge": badge,
            "action_label": "Ouvrir Medsina 🚀",
            "url": "https://medsina.medevsync.com"
        },
        "target_role": "all"
    }
    if dry_run:
        print(f"   📱 [In-App Dry Run] {title}")
        return

    url = f"{supabase_url}/rest/v1/medical_notifications"
    headers = {
        "apikey": supabase_key,
        "Authorization": f"Bearer {supabase_key}",
        "Content-Type": "application/json"
    }
    try:
        r = requests.post(url, headers=headers, json=payload, timeout=10)
        if r.status_code in (200, 201, 204):
            print(f"   📱 ✅ In-App notification insérée : {title}")
        else:
            print(f"   📱 ⚠️ In-App error ({r.status_code}): {r.text}")
    except Exception as e:
        print(f"   📱 ⚠️ In-App exception: {e}")


# =============================================================================
# 1. EXÉCUTION ANNONCE 1 : LISTE DES ABONNÉS VIP NOVEMBRE
# =============================================================================
def broadcast_announcement_1(dry_run: bool = False):
    print("\n" + "=" * 65)
    print("📢 DIFFUSION ANNONCE 1 : LISTE DES ABONNÉS PROMO VIP NOVEMBRE")
    print("=" * 65)

    fb_caption = """🎉 CAMPAGNE PROMO NOVEMBRE — FÉLICITATIONS À NOS 40 NOUVEAUX ABONNÉS ALL-ACCESS VIP !

Le Pass All-Access VIP 30 Jours Offert a été activé avec succès pour 40 confrères, internes et candidats au concours de Résidanat à travers l'ensemble des facultés de médecine d'Algérie !

🎓 Félicitations aux confrères de :
• Faculté de Médecine de Blida (CHU Frantz Fanon)
• Faculté de Médecine d'Alger
• Faculté de Médecine d'Oran
• Faculté de Médecine de Constantine
• Faculté de Médecine d'Annaba
• Faculté de Médecine de Sétif
• Faculté de Médecine de Tlemcen...

Ce qui est désormais débloqué à 100% sur leur compte :
✅ 47 Modules Médicaux complets en accès illimité
✅ 15 000+ QCMs d'annales réelles avec barème officiel
✅ Nouveaux Livrets de Révision Résidanat 2027 Tout-en-Un
✅ Simulateur d'EMD et Concours Blancs chronométrés
✅ Assistant Médical IA MedsinaPilot disponible 24h/24
✅ Fiches Urgences CAT, Mémentos de Garde & Codex DCI

Bienvenue dans l'aventure Medsina à tous nos confrères ! Ensemble pour la réussite du concours et de vos stages hospitaliers.

📞 Contact & Assistance : 0770 25 84 53
✈️ Telegram direct : @docchikhtouami
🌐 Plateforme Officielle : https://medsina.medevsync.com

#Medsina #PromoNovembre #ResidanatBlida2027 #VIPAllAccess #MedecineAlgerie"""

    tg_html = """🎉 <b>CAMPAGNE PROMO NOVEMBRE — FÉLICITATIONS À NOS 40 NOUVEAUX ABONNÉS ALL-ACCESS VIP !</b>

Le <b>Pass All-Access VIP 30 Jours Offert</b> a été activé avec succès pour <b>40 confrères, internes et candidats au concours de Résidanat</b> à travers toute l'Algérie !

🎓 <b>Facultés représentées :</b>
• Blida • Alger • Oran • Constantine • Annaba • Sétif • Tlemcen...

<b>Ce qui est désormais 100% débloqué sur leur compte :</b>
✅ 47 Modules Médicaux complets en accès illimité
✅ 15 000+ QCMs d'annales réelles avec corrigés types officiels
✅ Nouveaux Livrets de Révision Résidanat 2027 Tout-en-Un
✅ Simulateur d'EMD et Concours Blancs chronométrés
✅ Assistant IA MedsinaPilot 24/7 & Protocoles d'Urgences

Félicitations et plein succès à toute la promotion !

👉 <a href="https://medsina.medevsync.com"><b>Accéder à Medsina Web & Mobile</b></a>

📞 <b>Contact / WhatsApp :</b> 0770 25 84 53
👨‍⚕️ <b>Telegram direct :</b> @docchikhtouami

#PromoNovembre #VIPAllAccess #Medsina"""

    # 1. In-App Notification
    send_in_app_notification_item(
        title="🎉 Félicitations à nos 40 Nouveaux Abonnés VIP !",
        message="Le Pass All-Access VIP 30 Jours a été activé pour 40 confrères à travers toute l'Algérie. Découvrez la liste officielle dans l'annonce !",
        notif_id=f"notif_promo_vip_list_{int(time.time())}",
        badge="Promo VIP 🌟",
        dry_run=dry_run
    )

    # 2. Facebook 4 Pages (avec image)
    publish_photo_to_all_fb_pages(IMG_VIP, fb_caption, dry_run=dry_run)

    # 3. Telegram (avec image)
    tg_keyboard = {
        "inline_keyboard": [
            [{"text": "Ouvrir Medsina 🚀", "url": "https://medsina.medevsync.com"}],
            [{"text": "Contacter Dr Chikh Touami ✈️", "url": "https://t.me/docchikhtouami"}]
        ]
    }
    try:
        send_telegram_broadcast(
            message_text=tg_html,
            image_path=str(IMG_VIP),
            topic_id=1,  # Topic General
            inline_keyboard=tg_keyboard,
            dry_run=dry_run,
            auto_pin=False,
            broadcast_to_community=True
        )
        print("   ✈️ ✅ Telegram Annonce 1 diffusée avec succès !")
    except Exception as e:
        print(f"   ✈️ ⚠️ Erreur Telegram Annonce 1 : {e}")


# =============================================================================
# 2. EXÉCUTION ANNONCE 2 : APPEL INSCRIPTION & GRANDE SURPRISE FIN PROMO
# =============================================================================
def broadcast_announcement_2(dry_run: bool = False):
    print("\n" + "=" * 65)
    print("📢 DIFFUSION ANNONCE 2 : APPEL INSCRIPTION & GRANDE SURPRISE FIN PROMO")
    print("=" * 65)

    fb_caption = """🚀 VOUS N'ÊTES PAS ENCORE INSCRIT SUR MEDSINA ? IL EST ENCORE TEMPS !

🎁 UNE GRANDE SURPRISE SERA DÉVOILÉE À TOUS LES INSCRITS EN FIN DE PROMOTION !

La grande campagne Promo de Novembre bat son plein (déjà 40 comptes VIP activés cette semaine).
Si vous n'avez pas encore créé votre compte, inscrivez-vous dès maintenant (100% gratuit).

Pourquoi créer votre compte dès aujourd'hui ?
1️⃣ TÉLÉCHARGEMENT DES LIVRETS ALL-IN-ONE 2027 :
Accédez aux livrets complets de révision (Fiche express, cours complet, QCMs d'entraînement sans correction et grille officielle du corrigé type). Disponibles exclusivement dans l'application !

2️⃣ 15 000+ QCMS & ANNALES DU CONCOURS :
Testez vos connaissances sur les annales officielles avec barème de Blida, perles cliniques et corrigés détaillés.

3️⃣ CONCOURS BLANCS CHRONOMÉTRÉS :
Entraînez-vous dans les conditions réelles d'examen avec classement instantané.

4️⃣ 🎁 ET SURTOUT : UNE SURPRISE INÉDITE EN FIN DE PROMO !
Tous les utilisateurs ayant un compte actif sur l'application Medsina avant la fin de la promotion recevront un avantage majeur et exceptionnel pour préparer le concours et leurs stages hospitaliers.

📲 Inscription gratuite en 30 secondes chrono :
👉 https://medsina.medevsync.com

Rejoignez dès maintenant vos confrères et prenez une longueur d'avance !

📞 Contact & Assistance : 0770 25 84 53
✈️ Telegram direct : @docchikhtouami

#Medsina #SurpriseFinDePromo #ConcoursResidanat2027 #MedecineAlgerie"""

    tg_html = """🚀 <b>PAS ENCORE INSCRIT SUR MEDSINA ? IL EST ENCORE TEMPS !</b>

🎁 <b>UNE GRANDE SURPRISE ATTEND TOUS LES INSCRITS EN FIN DE PROMO !</b>

La promo de Novembre bat son plein avec déjà <b>40 comptes VIP activés</b> cette semaine !

Si vous n'avez pas encore créé votre compte gratuit, rejoignez l'aventure dès maintenant :

<b>Pourquoi vous inscrire dès aujourd'hui ?</b>
1️⃣ <b>Livrets All-in-One Résidanat 2027 :</b> Fiche de synthèse, cours complet, QCMs sans corrigé et grille officielle.
2️⃣ <b>15 000+ QCMs & Annales :</b> Classés par session avec barème officiel.
3️⃣ <b>Concours Blancs Chronométrés :</b> Épreuves en temps réel.
4️⃣ 🎁 <b>LA GRANDE SURPRISE DE FIN DE PROMO :</b> Un avantage exclusif et inédit sera offert à la clôture de la campagne à <b>tous les membres inscrits sur l'application</b> !

📲 <i>Inscription 100% gratuite en 30 secondes :</i>
👉 <a href="https://medsina.medevsync.com"><b>S'inscrire sur Medsina Web & Mobile</b></a>

📞 <b>Contact / WhatsApp :</b> 0770 25 84 53
👨‍⚕️ <b>Telegram direct :</b> @docchikhtouami

#Medsina #SurpriseFinPromo #Residanat2027"""

    # 1. In-App Notification
    send_in_app_notification_item(
        title="🎁 Une Grande Surprise vous attend en Fin de Promo !",
        message="La campagne de Novembre bat son plein ! Assurez-vous d'avoir un compte actif sur Medsina : un avantage exclusif et inédit sera offert à tous les inscrits à la fin du mois.",
        notif_id=f"notif_promo_surprise_teaser_{int(time.time())}",
        badge="Surprise Exclusif 🎁",
        dry_run=dry_run
    )

    # 2. Facebook 4 Pages (avec image)
    publish_photo_to_all_fb_pages(IMG_SURPRISE, fb_caption, dry_run=dry_run)

    # 3. Telegram (avec image)
    tg_keyboard = {
        "inline_keyboard": [
            [{"text": "Créer mon Compte Gratuit 📲", "url": "https://medsina.medevsync.com"}],
            [{"text": "Rejoindre le Canal Officiel ✈️", "url": "https://t.me/medsina_officiel"}]
        ]
    }
    try:
        send_telegram_broadcast(
            message_text=tg_html,
            image_path=str(IMG_SURPRISE),
            topic_id=1,  # Topic General
            inline_keyboard=tg_keyboard,
            dry_run=dry_run,
            auto_pin=False,
            broadcast_to_community=True
        )
        print("   ✈️ ✅ Telegram Annonce 2 diffusée avec succès !")
    except Exception as e:
        print(f"   ✈️ ⚠️ Erreur Telegram Annonce 2 : {e}")


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true", default=False)
    parser.add_argument("--annonce", type=int, choices=[1, 2, 0], default=0, help="1, 2 ou 0 pour les deux")
    args = parser.parse_args()

    if args.annonce in (1, 0):
        broadcast_announcement_1(dry_run=args.dry_run)
    if args.annonce in (2, 0):
        broadcast_announcement_2(dry_run=args.dry_run)
