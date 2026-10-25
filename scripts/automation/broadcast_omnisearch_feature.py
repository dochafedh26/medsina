#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Broadcast script to announce and promote Medsina Omnisearch on:
1. Telegram Channel (@medsina_officiel)
2. Facebook Page Résidanat Blida 2027 (ID: 1405719695953624)
3. Facebook Page Medevsync (ID: 1329939320211198)
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

from telegram_publisher import get_telegram_credentials, OCTENIUM_WEB_URL, OCTENIUM_APK_URL, OCTENIUM_EXE_URL

IMAGE_PATH = Path(__file__).resolve().parents[2] / "omnisearch_promo_banner.png"
if not IMAGE_PATH.exists():
    IMAGE_PATH = Path("medsina/omnisearch_promo_banner.png")

SUPABASE_URL = "https://qzfssrhhuorljftpdvjm.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF6ZnNzcmhodW9ybGpmdHBkdmptIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MTYxMjg1NCwiZXhwIjoyMTA3MTg4ODU0fQ.-KCUgZdY8RDUwvNOUAabDhQFwv5FFGHYz0J-dM7Cic4"

# -----------------------------------------------------------------------------
# 1. TELEGRAM POST CONTENT (< 1024 chars for Photo Caption)
# -----------------------------------------------------------------------------
TELEGRAM_MESSAGE = """🔍 <b>NOUVEAUTÉ MEDSINA v1.0.16 : DÉCOUVREZ OMNISEARCH !</b> 🚀🇩🇿

Plus besoin de chercher des heures : tapez un mot médical et trouvez instantanément votre réponse dans <b>TOUTE l'application</b> en &lt; 100 ms !

━━━━━━━━━━━━━━━━━━━━
⚡ <b>CE QUE SCANNE MEDSINA OMNISEARCH :</b>
• 📚 <b>Cours & PDFs :</b> 47 modules officiels. En 1 clic, le PDF s'ouvre avec le mot surligné sur la bonne page !
• 🎯 <b>19 000+ QCMs :</b> Énoncés d'annales de concours et pièges classiques.
• 🚨 <b>CAT Urgences (UMC) :</b> Protocoles vitaux, drapeaux rouges et étapes de prise en charge.
• 📋 <b>Mémentos de Garde :</b> 38 fiches réflexes hospitalières.
• 💊 <b>Médicaments :</b> DCI Saidal/IPA, doses et contre-indications.
• 🧮 <b>Normes & Scores :</b> Calculateurs Glasgow, Wells, Cockcroft...

⌨️ <i>Raccourci PC Windows :</i> <code>Ctrl + K</code>
📱 <i>100% Hors-Ligne sur Android & Windows</i>

🌐 <b>Tester en ligne :</b> <a href="https://medsina.medevsync.com">medsina.medevsync.com</a>"""


# -----------------------------------------------------------------------------
# 2. FACEBOOK POST : PAGE RÉSIDANAT BLIDA 2027
# -----------------------------------------------------------------------------
FB_RESIDANAT_MESSAGE = """🔍 NOUVELLE FONCTIONNALITÉ MAJEURE : MEDSINA OMNISEARCH EST ENFIN LÀ ! 🚀🇩🇿
(Mise à jour v1.0.16 disponible sur Web, Android APK & Windows PC)

Chers confrères candidats au concours de résidanat et résidents,

Combien de fois avez-vous perdu un temps précieux à chercher dans quel cours ou quel PDF se trouvait un piège d'examen, une posologie d'urgence ou une conduite à tenir ?

Aujourd'hui, nous lançons Medsina Omnisearch : le premier moteur de recherche médical unifié transversal spécialement conçu pour les médecins d'Algérie !

━━━━━━━━━━━━━━━━━━━━
⚡ POURQUOI OMNISEARCH VA TRANSFORMER VOS RÉVISIONS :

1️⃣ Deep-Linking PDF avec Surlignage Automatique :
Tapez n'importe quelle pathologie ou symptôme (ex: "Hyperkaliémie", "Appendicite", "Infarctus") : cliquez sur le cours, et le lecteur PDF s'ouvre directement avec le mot-clé PRÉ-SURLIGNÉ sur la bonne page !

2️⃣ Recherche Transversale dans 8 Bases Médicales en < 100 ms :
• 📚 47 Modules & Cours Officiels du Résidanat
• 📑 Fiches Synthèses & Alertes Pièges Concours
• 🎯 19 000+ QCMs & Annales corrigées
• 🚨 30+ Conduites à Tenir d'Urgence (CAT) avec drapeaux rouges
• 📋 38 Mémentos de Garde hospitalière
• 💊 Médicaments d'urgence & posologies Saidal / IPA
• 🧮 Scores cliniques (Glasgow, Wells, Cockcroft, CURB-65) et Normes Bio

3️⃣ Raccourci Clavier Desktop & 100% Hors-Ligne :
Sur PC Windows, pressez simplement [ Ctrl + K ] depuis n'importe quel écran pour invoquer la recherche instantanée, même sans aucune connexion internet !

━━━━━━━━━━━━━━━━━━━━
📲 TESTEZ OMNISEARCH DÈS AUJOURD'HUI :
🌐 Version Web Directe : https://medsina.medevsync.com
📱 Télécharger sur Android APK : https://medsina.medevsync.com/download/medsina.apk
💻 Télécharger sur PC Windows : https://medsina.medevsync.com/download/medsina-setup.exe
✈️ Canal Officiel Telegram : https://t.me/medsina_officiel

🎁 Rappel : 14 jours d'accès complet offert à chaque nouvel inscrit !

#Medsina #Omnisearch #ResidanatBlida2027 #Residanat2027 #MedecineAlgerie #FaculteBlida #QCMResidanat #UrgencesMedicales #ConcoursResidanat"""


# -----------------------------------------------------------------------------
# 3. FACEBOOK POST : PAGE MEDEVSYNC
# -----------------------------------------------------------------------------
FB_MEDEVSYNC_MESSAGE = """🚀 INNOVATION SANTÉ & TECHNOLOGIE MÉDICALE : MEDEVSYNC DÉPLOIE MEDSINA OMNISEARCH 🇩🇿🩺

MedevSync franchit une nouvelle étape dans la numérisation des outils médicaux en Algérie avec le lancement officiel de Medsina Omnisearch (v1.0.16).

Conçu pour répondre aux exigences d'immédiateté des médecins résidents, internes de garde et praticiens des UMC, Omnisearch unifie sur une seule barre de recherche l'accès à l'ensemble du savoir médical hospitalier et académique.

━━━━━━━━━━━━━━━━━━━━
🔬 PERFORMANCES TECHNIQUES & FONCTIONNALITÉS :

⚡ Indexation Multi-Domaines Temps Réel (< 100 ms) :
Scanne simultanément 47 modules académiques, 19 000+ questions d'annales, 30 protocoles d'urgences vitales, 38 mémentos de garde et la pharmacopée d'urgence locale.

📑 Deep-Linking PDF & Détection Sémantique :
Accès direct à la page exacte du document médical avec surlignage dynamique du mot-clé recherché, sans chargement réseau superflu.

🖥️ Raccourci Système Desktop (Ctrl + K) & Architecture Offline-First :
Totalement fonctionnel hors-ligne au lit du malade ou dans les sous-sols hospitaliers dépourvus de réseau.

━━━━━━━━━━━━━━━━━━━━
🌐 DÉCOUVREZ L'ÉCOSYSTÈME MEDSINA :
• Portail Officiel : https://medsina.medevsync.com
• Application Android APK & Setup Windows : Disponibles gratuitement
• Page Communauté Concours : https://www.facebook.com/residanatblida2027/
• Canal Telegram : https://t.me/medsina_officiel

#MedevSync #HealthTech #Medsina #MedecineAlgerie #InnovationMedicale #Residanat2027 #CliniqueMedicale #IntelligenceArtificielle"""


def publish_telegram():
    print("=" * 65)
    print("✈️ 1. DIFFUSION SUR LE CANAL TELEGRAM (@medsina_officiel)...")
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
                {"text": "🔍 Tester Medsina Omnisearch", "url": OCTENIUM_WEB_URL},
            ],
            [
                {"text": "📱 Télécharger APK Android", "url": OCTENIUM_APK_URL},
                {"text": "💻 Télécharger PC Windows", "url": OCTENIUM_EXE_URL},
            ],
            [
                {"text": "👥 Page Facebook Blida 2027", "url": "https://www.facebook.com/residanatblida2027/"},
            ],
        ]
    }

    if IMAGE_PATH.exists():
        api_url = f"https://api.telegram.org/bot{token}/sendPhoto"
        with open(IMAGE_PATH, "rb") as f:
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


def get_fb_settings():
    headers = {"apikey": SUPABASE_KEY, "Authorization": f"Bearer {SUPABASE_KEY}"}
    url = f"{SUPABASE_URL}/rest/v1/admin_system_settings?select=setting_key,setting_value"
    r = requests.get(url, headers=headers)
    settings = {}
    if r.status_code == 200:
        for row in r.json():
            settings[row.get("setting_key")] = row.get("setting_value")
    return settings


def publish_fb_page(page_name: str, page_id: str, token: str, message: str):
    print(f"\n📘 TENTATIVE SUR LA PAGE FACEBOOK '{page_name}' (ID: {page_id})...")
    if not token:
        print("⚠️ Jeton manquant pour cette page.")
        return False

    url = f"https://graph.facebook.com/v21.0/{page_id}/photos"
    if IMAGE_PATH.exists():
        with open(IMAGE_PATH, "rb") as f:
            files = {"source": ("omnisearch_promo_banner.png", f, "image/png")}
            data = {"caption": message, "access_token": token}
            resp = requests.post(url, data=data, files=files, timeout=45)
    else:
        post_url = f"https://graph.facebook.com/v21.0/{page_id}/feed"
        resp = requests.post(post_url, data={"message": message, "access_token": token}, timeout=30)

    try:
        res = resp.json()
        if resp.status_code == 200 and ("id" in res or "post_id" in res):
            pid = res.get("post_id", res.get("id"))
            print(f"🎉 SUCCÈS FACEBOOK sur {page_name} ! Post ID: {pid}")
            print(f"🔗 Lien direct : https://www.facebook.com/{pid}")
            return True
        else:
            err = res.get("error", {})
            msg = err.get("message", "Erreur inconnue")
            print(f"⚠️ Erreur Meta Graph API ({resp.status_code}): {msg}")
            return False
    except Exception as e:
        print(f"❌ Exception Facebook : {e}")
        return False


def main():
    # 1. Telegram
    tg_ok = publish_telegram()

    # 2. Facebook
    settings = get_fb_settings()
    token_blida = settings.get("facebook_page_access_token")
    token_medevsync = settings.get("facebook_medevsync_page_access_token")

    fb1_ok = publish_fb_page("Résidanat Blida 2027", "1405719695953624", token_blida, FB_RESIDANAT_MESSAGE)
    fb2_ok = publish_fb_page("Medevsync", "1329939320211198", token_medevsync, FB_MEDEVSYNC_MESSAGE)

    print("\n" + "=" * 65)
    print("RÉSUMÉ DU BROADCAST OMNISEARCH :")
    print(f"• Telegram (@medsina_officiel)     : {'✅ PUBLIÉ EN DIRECT' if tg_ok else '❌ ÉCHEC'}")
    print(f"• Facebook (Résidanat Blida 2027) : {'✅ PUBLIÉ EN DIRECT' if fb1_ok else '⚠️ TOKEN EXPIRÉ'}")
    print(f"• Facebook (Medevsync)            : {'✅ PUBLIÉ EN DIRECT' if fb2_ok else '⚠️ TOKEN EXPIRÉ'}")
    print("=" * 65)


if __name__ == "__main__":
    main()
