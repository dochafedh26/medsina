#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Publication Officielle : Recrutement Délégués & Émissaires Faculté de Médecine de Blida (V2 Mise à jour).
Diffuse en direct avec les coordonnées officielles du Dr Chikh Touami :
- Telegram : @docchikhtouami (https://t.me/docchikhtouami)
- Téléphone & WhatsApp : 0770 25 84 53 (https://wa.me/213770258453)
- Web : https://medsina.medevsync.com

1. Pages Facebook officielles (Résidanat Blida 2027, Medsina, MedevSync) avec image HD carrée corrigée
2. Telegram : Canal Officiel (@medsina_officiel) et Topic 8 (Cursus Externat Blida 2027) du Supergroupe (-1004438944860)
"""

import os
import sys
import json
import time
import requests
from pathlib import Path

# Fix Windows console UTF-8
if sys.stdout and hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

script_dir = Path(__file__).resolve().parent
workspace_root = script_dir.parents[1] if "scripts" in str(script_dir) else script_dir

def get_credentials():
    env_path = workspace_root / "medsina" / ".env"
    if not env_path.exists():
        env_path = Path("medsina/.env")
    if not env_path.exists():
        env_path = Path(".env")
        
    env_vars = {}
    if env_path.exists():
        for line in env_path.read_text(encoding="utf-8").splitlines():
            if "=" in line and not line.strip().startswith("#"):
                k, v = line.split("=", 1)
                env_vars[k.strip()] = v.strip().strip("\"'")

    supabase_url = env_vars.get("SUPABASE_URL", "https://qzfssrhhuorljftpdvjm.supabase.co")
    supabase_key = env_vars.get("SUPABASE_SERVICE_ROLE_KEY", "")
    
    headers = {"apikey": supabase_key, "Authorization": f"Bearer {supabase_key}"}
    r = requests.get(f"{supabase_url}/rest/v1/admin_system_settings?select=*", headers=headers, timeout=15)
    if r.status_code != 200:
        raise RuntimeError(f"Impossible de lire admin_system_settings Supabase ({r.status_code}): {r.text}")
    
    settings = {row["setting_key"]: row["setting_value"] for row in r.json()}
    return settings

def publish():
    print("=" * 70)
    print("📢 ACTUALISATION DE LA DIFFUSION : RECRUTEMENT BLIDA (V2)")
    print("=" * 70)
    
    settings = get_credentials()
    
    # Image sélectionnée
    square_img = workspace_root / "medsina" / "assets" / "facebook" / "medsina_emissaires_blida_square.png"
    if not square_img.exists():
        square_img = Path("medsina/assets/facebook/medsina_emissaires_blida_square.png")
    
    if not square_img.exists():
        raise FileNotFoundError(f"Image introuvable : {square_img}")
        
    print(f"🖼️ Image sélectionnée : {square_img.resolve()} ({square_img.stat().st_size} octets)")

    # -------------------------------------------------------------
    # TEXTE DE PUBLICATION FACEBOOK
    # -------------------------------------------------------------
    fb_caption = """🩺 [RECHERCHE DÉLÉGUÉS & ÉMISSAIRES DE PROMO • FACULTÉ DE MÉDECINE DE BLIDA] 🏛️

Salam à tous chers confrères, externes et résidents de Blida !

Je suis le Dr Chikh Touami, médecin et concepteur de la plateforme médicale Medsina (medsina.medevsync.com). 

Pour cette année universitaire 2026-2027, nous lançons un grand programme de soutien pédagogique pour la Faculté de Médecine de Blida (CHU Frantz Fanon). 

Nous recherchons pour chaque promotion (de la 1ère à la 6ème année, internat et résidents) :
👉 Les Délégués officiels de promotion et de stage.
👉 Tout(e) étudiant(e) motivé(e) ayant la volonté de devenir « Émissaire / Ambassadeur Medsina » pour représenter son amphi ou son groupe de révision !

🎯 QUEL EST LE RÔLE D'UN ÉMISSAIRE MEDSINA ?
• Être le relais privilégié de sa promotion au sein de la faculté.
• Partager les questions pièges officielles et fiches réflexes utiles dans son groupe de promo.
• Faire remonter les besoins spécifiques de son amphi pour adapter les simulateurs d'examens.

🎁 CE QUE NOUS VOUS OFFRONS EN CONTREPARTIE :
1️⃣ Un Pass All-Access VIP gratuit de 12 mois offert à chaque émissaire et délégué(e) sélectionné(e).
2️⃣ Un Pass All-Access VIP de 30 jours 100% offert pour tous les étudiants de votre promotion (47 modules, 15 000+ QCMs classés par tombabilité, annales de Blida et tuteurs IA MedsinaTeacher).
3️⃣ Accès direct à l'équipe médicale Medsina et à des concours blancs exclusifs.

🤝 Aucune expérience requise, juste la motivation d'aider votre promo à cartonner aux EMDs et au concours !

📩 Vous êtes délégué(e) ou vous souhaitez devenir l'Émissaire de votre promo ?
Contactez directement le Dr Chikh Touami :
📱 WhatsApp & Tél : 0770 25 84 53
✈️ Telegram direct : @docchikhtouami
👥 Confrères de Blida : taguez en commentaire les personnes motivées de votre promo qui feraient d'excellents émissaires ! 👇

👉 Tous les détails et le lien de contact direct sont également dans le premier commentaire épinglé.
#MedecineBlida #CHUBlida #ResidanatBlida #FaculteDeMedecineBlida #EmissaireMedsina #ExternatBlida #Medsina"""

    first_comment_text = """🔗 CONTACTEZ DIRECTEMENT LE DR CHIKH TOUAMI :
📱 WhatsApp & Téléphone : 0770 25 84 53 (https://wa.me/213770258453)
✈️ Telegram direct : @docchikhtouami (https://t.me/docchikhtouami)
🌐 Découvrir la plateforme et activer les 30 jours offerts : https://medsina.medevsync.com

⭐ Précisez simplement votre Année d'étude (1ère à 6ème / Interne) et votre statut (Délégué ou Candidat Émissaire) en message privé pour activer votre compte VIP 1 an !"""

    # -------------------------------------------------------------
    # 1. PUBLICATION SUR LES PAGES FACEBOOK
    # -------------------------------------------------------------
    fb_pages = [
        {
            "key": "residanat_blida_2027",
            "name": "Résidanat Blida 2027 (Page Principale)",
            "page_id": settings.get("facebook_blida_page_id") or "1405719695953624",
            "token": settings.get("facebook_blida_page_access_token") or settings.get("facebook_page_access_token")
        },
        {
            "key": "medsina",
            "name": "Medsina (Page Officielle)",
            "page_id": settings.get("facebook_medsina_page_id") or "1449308354921826",
            "token": settings.get("facebook_medsina_page_access_token")
        },
        {
            "key": "medevsync",
            "name": "MedevSync (Page Partenaire)",
            "page_id": settings.get("facebook_medevsync_page_id") or "1329939320211198",
            "token": settings.get("facebook_medevsync_page_access_token")
        }
    ]

    fb_results = []
    print("\n📘 --- ÉTAPE 1 : DIFFUSION SUR LES PAGES FACEBOOK ---")
    for p in fb_pages:
        page_name = p["name"]
        page_id = p["page_id"]
        token = p["token"]
        
        if not token:
            print(f"⚠️ Token manquant pour {page_name}")
            continue
            
        print(f"\n🚀 Publication sur {page_name} (ID: {page_id})...")
        try:
            url = f"https://graph.facebook.com/v21.0/{page_id}/photos"
            with open(square_img, "rb") as f_img:
                files = {"source": ("medsina_emissaires_blida_v2.png", f_img, "image/png")}
                data = {"caption": fb_caption, "access_token": token}
                resp = requests.post(url, data=data, files=files, timeout=45)
            
            res = resp.json()
            if resp.status_code == 200 and "id" in res:
                photo_id = res.get("id")
                post_id = res.get("post_id") or photo_id
                print(f"   🎉 SUCCÈS sur {page_name} ! Post ID: {post_id}")
                fb_results.append({"page": page_name, "post_id": post_id, "success": True})
            else:
                print(f"   ❌ Erreur API sur {page_name} ({resp.status_code}): {res}")
                fb_results.append({"page": page_name, "error": res, "success": False})
        except Exception as e:
            print(f"   ❌ Exception publication sur {page_name}: {e}")
            fb_results.append({"page": page_name, "error": str(e), "success": False})

    # -------------------------------------------------------------
    # 2. PUBLICATION TELEGRAM (CANAL + TOPIC FORUM)
    # -------------------------------------------------------------
    print("\n✈️ --- ÉTAPE 2 : ACTUALISATION SUR TELEGRAM ---")
    tg_token = settings.get("telegram_bot_token")
    tg_channel = settings.get("telegram_channel_id") or "@medsina_officiel"
    tg_group = settings.get("telegram_community_group_id") or "-1004438944860"
    
    tg_caption = """🏛️ <b>APPEL AUX DÉLÉGUÉS & ÉMISSAIRES • FACULTÉ DE MÉDECINE DE BLIDA</b> 🩺

Salam à tous chers confrères et externes de Blida !

Pour cette année 2026-2027, <b>Medsina</b> lance un programme de parrainage et de soutien pédagogique exclusif pour le <b>CHU Frantz Fanon</b>.

Nous recherchons pour chaque promotion (1ère à 6ème année, Internat, Résidents) :
👉 <b>Les Délégués officiels de promotion et de stage</b>
👉 <b>Tout(e) étudiant(e) motivé(e)</b> souhaitant devenir <b>Émissaire Medsina</b> pour représenter son amphi ou son groupe d'étude !

🎁 <b>VOS AVANTAGES EXCLUSIFS :</b>
1️⃣ <b>Pass VIP All-Access 12 Mois OFFERT</b> pour chaque délégué(e) et émissaire.
2️⃣ <b>Pass VIP 30 Jours OFFERT</b> pour toute votre promotion (annales Blida, 15 000+ QCMs classés, tuteurs IA).
3️⃣ Accès direct à l'équipe médicale Medsina & concours blancs exclusifs.

📩 <i>Vous êtes délégué(e) ou motivé(e) pour être l'émissaire de votre promo ?</i>
Contactez directement le <b>Dr Chikh Touami</b> ci-dessous 👇
📱 <b>WhatsApp & Tél :</b> 0770 25 84 53
✈️ <b>Telegram direct :</b> @docchikhtouami"""

    inline_keyboard = {
        "inline_keyboard": [
            [
                {"text": "📩 Contacter @docchikhtouami", "url": "https://t.me/docchikhtouami"},
                {"text": "📱 WhatsApp 0770258453", "url": "https://wa.me/213770258453"}
            ],
            [
                {"text": "🌐 Découvrir Medsina & Activer les 30 Jours", "url": "https://medsina.medevsync.com"}
            ]
        ]
    }

    tg_results = []
    if tg_token:
        # A. Nettoyage éventuel du précédent message Telegram
        try:
            requests.post(f"https://api.telegram.org/bot{tg_token}/deleteMessage", data={"chat_id": tg_channel, "message_id": 165}, timeout=10)
            requests.post(f"https://api.telegram.org/bot{tg_token}/deleteMessage", data={"chat_id": tg_group, "message_id": 168}, timeout=10)
        except Exception:
            pass

        # B. Sur le Canal Officiel
        print(f"\n📢 Envoi sur le Canal Officiel ({tg_channel})...")
        try:
            url = f"https://api.telegram.org/bot{tg_token}/sendPhoto"
            with open(square_img, "rb") as f_img:
                files = {"photo": ("medsina_blida_v2.png", f_img, "image/png")}
                data = {
                    "chat_id": tg_channel,
                    "caption": tg_caption,
                    "parse_mode": "HTML",
                    "reply_markup": json.dumps(inline_keyboard)
                }
                r_ch = requests.post(url, data=data, files=files, timeout=30)
                res_ch = r_ch.json()
                if res_ch.get("ok"):
                    msg_id = res_ch["result"]["message_id"]
                    print(f"   🎉 SUCCÈS Canal Telegram ! Message ID: {msg_id}")
                    tg_results.append({"target": "channel", "id": msg_id, "success": True})
                else:
                    print(f"   ❌ Erreur Canal Telegram: {res_ch}")
                    tg_results.append({"target": "channel", "error": res_ch, "success": False})
        except Exception as e:
            print(f"   ❌ Exception Canal Telegram: {e}")

        # C. Dans le Supergroupe Topic 8 (CURSUS EXTERNAT BLIDA 2027)
        print(f"\n👥 Envoi dans le Supergroupe (Chat ID: {tg_group}, Topic 8 : CURSUS EXTERNAT BLIDA)...")
        try:
            url = f"https://api.telegram.org/bot{tg_token}/sendPhoto"
            with open(square_img, "rb") as f_img:
                files = {"photo": ("medsina_blida_v2.png", f_img, "image/png")}
                data = {
                    "chat_id": tg_group,
                    "message_thread_id": 8,
                    "caption": tg_caption,
                    "parse_mode": "HTML",
                    "reply_markup": json.dumps(inline_keyboard)
                }
                r_grp = requests.post(url, data=data, files=files, timeout=30)
                res_grp = r_grp.json()
                if res_grp.get("ok"):
                    msg_id = res_grp["result"]["message_id"]
                    print(f"   🎉 SUCCÈS Topic 8 Supergroupe ! Message ID: {msg_id}")
                    tg_results.append({"target": "topic_8", "id": msg_id, "success": True})
                else:
                    print(f"   ❌ Erreur Topic Supergroupe: {res_grp}")
                    tg_results.append({"target": "topic_8", "error": res_grp, "success": False})
        except Exception as e:
            print(f"   ❌ Exception Topic Supergroupe: {e}")

    print("\n" + "=" * 70)
    print("📊 RÉSUMÉ DE LA DIFFUSION ACTUALISÉE :")
    print(f"• Facebook : {sum(1 for r in fb_results if r.get('success'))}/{len(fb_pages)} pages publiées")
    print(f"• Telegram : {sum(1 for r in tg_results if r.get('success'))}/{len(tg_results)} cibles publiées")
    print("=" * 70)

if __name__ == "__main__":
    publish()
