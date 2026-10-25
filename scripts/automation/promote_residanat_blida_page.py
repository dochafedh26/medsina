#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import os
import sys
import json
import requests
from pathlib import Path

# Ensure UTF-8 output
if sys.stdout and hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

script_dir = Path(__file__).resolve().parent / "medsina" / "scripts" / "automation"
sys.path.insert(0, str(script_dir))

from telegram_publisher import get_telegram_credentials, OCTENIUM_WEB_URL, OCTENIUM_APK_URL, OCTENIUM_EXE_URL

FB_RESIDANAT_PAGE_URL = "https://www.facebook.com/residanatblida2027/"
FB_MEDEVSYNC_PAGE_ID = "1329939320211198"

SUPABASE_URL = "https://qzfssrhhuorljftpdvjm.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF6ZnNzcmhodW9ybGpmdHBkdmptIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MTYxMjg1NCwiZXhwIjoyMTA3MTg4ODU0fQ.-KCUgZdY8RDUwvNOUAabDhQFwv5FFGHYz0J-dM7Cic4"

# -----------------------------------------------------------------------------
# 1. TELEGRAM POST CONTENT (Under 1024 chars for Photo Caption)
# -----------------------------------------------------------------------------
TELEGRAM_MESSAGE = """📢 <b>REJOIGNEZ LA PAGE OFFICIELLE : RÉSIDANAT BLIDA 2027 !</b> 🇩🇿🩺

Chers confrères, candidats au concours et résidents,

Pour ne rien manquer des <b>actualités officielles</b>, annales corrigées, fiches de révision et nouveautés <b>Medsina</b>, rejoignez dès aujourd'hui la page Facebook de référence :

👉 <b>Page Facebook Officielle :</b>
🔗 <a href="https://www.facebook.com/residanatblida2027/">facebook.com/residanatblida2027</a>

━━━━━━━━━━━━━━━━━━━━
🎯 <b>AU PROGRAMME QUOTIDIEN :</b>
• 📚 <b>Annales & QCMs décortiqués :</b> Questions de la Faculté de Blida et nationales avec explications et pièges classiques.
• 💡 <b>Perles Cliniques & Mémentos :</b> Fiches synthétiques à haut rendement pour vos gardes et révisions.
• 🚀 <b>Medsina Omnisearch :</b> Le nouveau moteur de recherche médical unifié (Ctrl+K) et le mode 100% hors-ligne.
• 🤝 <b>Entraide & Méthodologie :</b> Conseils des lauréats et partages de ressources.

Abonnez-vous à la page, activez la cloche 🔔 et invitez vos confrères de promo !

🌐 <b>Plateforme Web :</b> <a href="https://medsina.medevsync.com">medsina.medevsync.com</a>"""


def publish_telegram_promo():
    print("=" * 65)
    print("✈️ PUBLICATION SUR LE CANAL TELEGRAM (@medsina_officiel)...")
    print("=" * 65)
    creds = get_telegram_credentials()
    token = creds.get("bot_token")
    channel = creds.get("channel_id")

    if not token or not channel:
        print("❌ Identifiants Telegram manquants.")
        return False

    inline_keyboard = {
        "inline_keyboard": [
            [
                {"text": "👥 Suivre la Page Facebook Blida 2027", "url": FB_RESIDANAT_PAGE_URL},
            ],
            [
                {"text": "🌐 Ouvrir Medsina Web", "url": OCTENIUM_WEB_URL},
                {"text": "📱 Télécharger APK Android", "url": OCTENIUM_APK_URL},
            ],
        ]
    }

    image_path = Path("medsina/output_banner.png")
    if not image_path.exists():
        image_path = Path("medsina_30days_free_offer.png")

    if image_path.exists():
        api_url = f"https://api.telegram.org/bot{token}/sendPhoto"
        with open(image_path, "rb") as f:
            files = {"photo": f}
            data = {
                "chat_id": channel,
                "caption": TELEGRAM_MESSAGE,
                "parse_mode": "HTML",
                "reply_markup": json.dumps(inline_keyboard),
            }
            resp = requests.post(api_url, data=data, files=files, timeout=40)
    else:
        api_url = f"https://api.telegram.org/bot{token}/sendMessage"
        data = {
            "chat_id": channel,
            "text": TELEGRAM_MESSAGE,
            "parse_mode": "HTML",
            "reply_markup": json.dumps(inline_keyboard),
        }
        resp = requests.post(api_url, data=data, timeout=40)

    try:
        res = resp.json()
        if res.get("ok"):
            msg_id = res.get("result", {}).get("message_id")
            print(f"🎉 SUCCÈS TELEGRAM ! Message ID: {msg_id}")
            print(f"🔗 Lien direct dans le canal : https://t.me/medsina_officiel/{msg_id}")
            return True
        else:
            print(f"❌ Erreur API Telegram : {res}")
            return False
    except Exception as e:
        print(f"❌ Exception Telegram : {e}")
        return False


# -----------------------------------------------------------------------------
# 2. FACEBOOK MEDEVSYNC POST CONTENT & PUBLISHER
# -----------------------------------------------------------------------------
FACEBOOK_MESSAGE = """📢 MEDEVSYNC SOUTIENT LES CANDIDATS AU RÉSIDANAT 2027 ! 🇩🇿🩺

Chers médecins, internes et étudiants en médecine d'Algérie,

MedevSync a le plaisir de vous inviter à rejoindre la page officielle de référence dédiée à la préparation intensive du concours :
👉 Résidanat Blida 2027 (Officiel) : https://www.facebook.com/residanatblida2027/

━━━━━━━━━━━━━━━━━━━━
🎯 POURQUOI SUIVRE CETTE PAGE ?

Que vous prépariez le concours à la Faculté de Médecine de Blida, Alger, Constantine, Oran ou Annaba, cette page est votre point de ralliement quotidien :

📚 Annales & QCMs Décortiqués : Analyses détaillées des questions pièges, consensus thérapeutiques récents et statistiques de tombabilité.
💡 Perles Cliniques & Pièges Concours : Fiches mémos ultra-visuelles conçues pour fixer les notions clés rapidement.
🚀 Nouveautés Medsina : Suivez l'évolution de la plateforme médicale Medsina (Moteur de recherche unifié Omnisearch Ctrl+K, intégration 100% hors-ligne sur mobile et PC).
🤝 Espace Confraternel d'Échange : Méthodologie de révision, retours d'expérience et entraide inter-promotions.

━━━━━━━━━━━━━━━━━━━━
🔗 LIENS UTILES :
👥 Rejoindre la Page Facebook : https://www.facebook.com/residanatblida2027/
🌐 Découvrir la Plateforme Medsina : https://medsina.medevsync.com
📱 Télécharger sur Android APK : https://medsina.medevsync.com/download/medsina.apk
💻 Télécharger sur PC Windows : https://medsina.medevsync.com/download/medsina-setup.exe
✈️ Canal Officiel Telegram : https://t.me/medsina_officiel

Abonnez-vous dès maintenant à la page, aimez la publication et taguez vos confrères de garde et de révision ! 🌟

#MedevSync #Medsina #ResidanatBlida2027 #Residanat2027 #MedecineAlgerie #FaculteBlida #ConcoursResidanat #InternatMedecine #QCMResidanat #MedecinsAlgerie"""


def publish_facebook_medevsync():
    print("\n" + "=" * 65)
    print("📘 TENTATIVE DE PUBLICATION SUR LA PAGE FACEBOOK MEDEVSYNC...")
    print("=" * 65)

    headers = {"apikey": SUPABASE_KEY, "Authorization": f"Bearer {SUPABASE_KEY}"}
    url = f"{SUPABASE_URL}/rest/v1/admin_system_settings?select=setting_key,setting_value"
    r = requests.get(url, headers=headers)
    token = None
    if r.status_code == 200:
        for row in r.json():
            if row.get("setting_key") == "facebook_medevsync_page_access_token":
                token = row.get("setting_value")

    if not token:
        print("⚠️ Jeton Facebook Medevsync non trouvé dans Supabase.")
        return False

    post_url = f"https://graph.facebook.com/v21.0/{FB_MEDEVSYNC_PAGE_ID}/feed"
    payload = {
        "message": FACEBOOK_MESSAGE,
        "link": FB_RESIDANAT_PAGE_URL,
        "access_token": token,
    }

    resp = requests.post(post_url, data=payload, timeout=30)
    try:
        res = resp.json()
        if resp.status_code == 200 and "id" in res:
            post_id = res["id"]
            print(f"🎉 SUCCÈS PUBLICATION FACEBOOK SUR MEDEVSYNC !")
            print(f"   Post ID : {post_id}")
            print(f"   🔗 Lien direct : https://www.facebook.com/{post_id}")
            return True
        else:
            err = res.get("error", {})
            msg = err.get("message", "Erreur inconnue")
            code = err.get("code")
            subcode = err.get("error_subcode")
            print(f"⚠️ Réponse Facebook API ({resp.status_code}) : Code {code} (subcode {subcode}) : {msg}")
            return False
    except Exception as e:
        print(f"❌ Exception Facebook : {e}")
        return False


def main():
    tg_ok = publish_telegram_promo()
    fb_ok = publish_facebook_medevsync()

    print("\n" + "=" * 65)
    print("RÉSUMÉ DE L'OPÉRATION :")
    print(f"• Telegram (@medsina_officiel) : {'✅ PUBLIÉ EN DIRECT' if tg_ok else '❌ ÉCHEC'}")
    print(f"• Facebook Medevsync Page      : {'✅ PUBLIÉ EN DIRECT' if fb_ok else '⚠️ TOKEN EXPIRÉ (À renouveler)'}")
    print("=" * 65)

if __name__ == "__main__":
    main()
