#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Publication Officielle — Medsina v1.0.22 « Medsina Ultra »
==========================================================
Génère 2 infographies HD 1080x1080 avec mockups réels et publie sur :
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

from facebook_post_generator import (  # noqa: E402
    SUPABASE_URL,
    SUPABASE_KEY,
    OFFICIAL_WEB_URL,
    OFFICIAL_APK_URL,
    OFFICIAL_WIN_URL,
    OFFICIAL_TELEGRAM_URL,
    render_banner_image,
    record_publication_success,
)
from telegram_publisher import send_telegram_broadcast  # noqa: E402

ARTIFACT_DIR = Path(
    r"C:\Users\PC-Service\.gemini\antigravity\brain\25cef155-7085-4d66-bf1a-3fea0991b1a7"
)
IMG_1_PATH = str(ARTIFACT_DIR / "medsina_v1_0_22_ultra_infographic_1.png")
IMG_2_PATH = str(ARTIFACT_DIR / "medsina_v1_0_22_ultra_infographic_2.png")


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
            "page_id": settings.get("facebook_page_id", "1405719695953624").strip(),
            "name": "Residanat Blida 2027",
            "token": settings.get("facebook_page_access_token", "").strip(),
        },
        "medevsync": {
            "page_id": settings.get("facebook_medevsync_page_id", "1329939320211198").strip(),
            "name": "Medevsync",
            "token": settings.get("facebook_medevsync_page_access_token", "").strip(),
        },
    }


def generate_infographics():
    data_1 = {
        "theme": "indigo",
        "badge": "NOUVEAUTÉ v1.0.22 • MEDSINA ULTRA",
        "title": "QCM Ultra & Flashcards FSRS v4.5",
        "subtitle": "Statistiques par option (% A-E) • Répétition Espacée • 100% Hors-Ligne",
        "mockup_type": "duo",
        "screenshot_desktop": "assets/screenshots/desktop/revision_qcm_pc.png",
        "screenshot_mobile": "assets/screenshots/mobile/Screenshot_20261020_173923_Medsina.jpg",
        "points": [
            "Moteur QCM Ultra : Mode Examen Blanc Chronométré (Tout ou Rien / Partiel) & Filtres Erreurs / Favoris.",
            "Statistiques Communautaires : Affichage des % de choix par proposition (A, B, C, D, E) & Tombabilité.",
            "Vigilance Anti-Piège : Bandeau d'alerte automatique sur les questions négatives (Fausse / Sauf une).",
            "Flashcards FSRS v4.5 : Convertissez n'importe quel QCM en Flashcard Recto/Verso en 1 seul clic.",
        ],
    }

    data_2 = {
        "theme": "emerald",
        "badge": "PLANIFICATION & VEILLE BLIDA v1.0.22",
        "title": "Study Planner 3 Couches & Veille IA",
        "subtitle": "Suivi des 47 Modules • Priorités du Jour • Scanner Telegram & Drive Blida",
        "mockup_type": "desktop",
        "screenshot_desktop": "assets/screenshots/desktop/Screenshot 2026-10-20 175342_dashboard.png",
        "points": [
            "Study Planner Matriciel : Cochez Couche 1, Couche 2 et Couche 3 sur chaque cours des 47 modules.",
            "Simulateur de Cadence J-X : Calcul automatique du nombre de cours/jour avant votre EMD ou Concours.",
            "Diagnostic IA Quotidien : Recommandation des 3 cours les plus rentables (Poids examen x Erreurs).",
            "Scanner Auto Blida & Mur d'Avis 5 Etoiles : Nouveaux sujets EMD détectés et espace retours étudiants.",
        ],
    }

    p1 = render_banner_image(data_1, IMG_1_PATH)
    p2 = render_banner_image(data_2, IMG_2_PATH)
    print(f"✅ Infographie 1 générée : {p1}")
    print(f"✅ Infographie 2 générée : {p2}")
    return p1, p2


def publish_to_fb_page(info: dict, image_path: str, caption: str):
    page_id = info["page_id"]
    page_name = info["name"]
    token = info["token"]

    print(f"\n🚀 Publication sur la Page Facebook '{page_name}' (ID: {page_id})...")
    url = f"https://graph.facebook.com/v21.0/{page_id}/photos"

    with open(image_path, "rb") as f:
        files = {"source": (os.path.basename(image_path), f, "image/png")}
        data = {"caption": caption, "access_token": token}
        resp = requests.post(url, data=data, files=files, timeout=60)

    if resp.status_code == 200:
        res = resp.json()
        post_id = res.get("post_id") or res.get("id")
        print(f"🎉 SUCCÈS sur {page_name} ! Post ID: {post_id}")
        print(f"   🔗 Lien : https://www.facebook.com/{post_id}")
        return res
    else:
        print(f"❌ Erreur Facebook sur {page_name} ({resp.status_code}): {resp.text}")
        return None


def main():
    print("=" * 72)
    print("📢 DIFFUSION OFFICIELLE : MEDSINA v1.0.22 « MEDSINA ULTRA »")
    print("=" * 72)

    pages = fetch_live_facebook_pages()
    img1, img2 = generate_infographics()

    fb_caption_1 = f"""🚀 MISE À JOUR MAJEURE : MEDSINA v1.0.22 « MEDSINA ULTRA » EST DISPONIBLE ! 🩺🇩🇿

Pour accompagner les étudiants en médecine (1ère à 6ème année), les internes et les candidats au Concours de Résidanat 2027 (Faculté de Médecine de Blida & programme national), Medsina lance sa version v1.0.22 « Medsina Ultra » — 100 % fluide et utilisable Hors-Ligne !

✨ LES NOUVEAUTÉS PHARES DE CETTE VERSION :

1️⃣ 🎯 MOTEUR QCM « ULTRA-RÉSIDANAT » & STATS COMMUNAUTAIRES :
• Modes au choix : 📖 Révision (Corrigé immédiat) ou ⏱️ Examen Blanc Chronométré (Tout ou Rien / Partiel pondéré).
• Filtres intelligents : 🆕 Jamais consultées, ❌ Vos Erreurs, ⭐ Vos Favoris, 📝 Avec vos Notes personnelles, 🔥 Haute Tombabilité.
• Pourcentages de choix par proposition (% A, B, C, D, E) après validation + Alerte visuelle anti-piège sur les questions négatives (« Fausse / Sauf une ») !

2️⃣ 🧠 RÉPÉTITION ESPACÉE FSRS v4.5 & FLASHCARDS EN 1 CLIC :
• Convertissez n'importe quel QCM ou piège de concours en Flashcard Recto/Verso en 1 seul clic !
• Algorithme FSRS v4.5 calculant votre rétention mémorielle, la stabilité et l'intervalle optimal (À revoir, Difficile, Bien, Facile).

3️⃣ 📅 STUDY PLANNER MATRICIEL (3 COUCHES) & ANALYTICS :
• Cochez l'avancement Couche 1 / Couche 2 / Couche 3 sur les 47 modules avec synchronisation automatique de votre % de maîtrise QCM.
• Compte à rebours J-X avant votre EMD ou Concours de Résidanat et calcul automatique des 3 cours les plus rentables à réviser chaque jour !

4️⃣ 📡 VEILLE AUTOMATIQUE MÉDECINE BLIDA & MUR D'AVIS 5★ :
• Détection quotidienne des nouveaux sujets d'EMD/QCM Blida et mur communautaire d'évaluations intégré.

━━━━━━━━━━━━━━━━━━━━
📲 TÉLÉCHARGEZ OU METTEZ À JOUR MEDSINA (v1.0.22) :
🌐 Version Web Directe : {OFFICIAL_WEB_URL}
📱 Application Android (.apk) : {OFFICIAL_APK_URL}
💻 Application PC Windows (.exe) : {OFFICIAL_WIN_URL}
✈️ Canal Officiel Telegram : {OFFICIAL_TELEGRAM_URL}

🇩🇿 Conçu par MedevSync pour l'excellence médicale en Algérie.
#Medsina #MedevSync #ResidanatBlida2027 #MedecineBlida #ResidanatAlgerie #QCMMedecine #FSRS #FlashcardsMedecine #UrgencesMedicales"""

    fb_caption_2 = f"""📅 NOUVEAU DANS MEDSINA v1.0.22 : STUDY PLANNER 3 COUCHES, PRIORITÉS DU JOUR & VEILLE BLIDA ! 🔥🩺

Organisez vos révisions d'Externat et du Concours de Résidanat 2027 avec une précision chirurgicale grâce au nouveau Study Planner Matriciel de Medsina Ultra :

✅ SUIVI PAR 3 COUCHES SUR LES 47 MODULES :
• Couche 1 (Lecture & Compréhension) • Couche 2 (Mémorisation & Fiches) • Couche 3 (Révision Finale & Annales) + % de Maîtrise QCM calculé en temps réel !
⏱️ SIMULATEUR DE CADENCE QUOTIDIENNE (J-X) :
• Fixez la date de votre prochain EMD ou du Concours de Résidanat : Medsina calcule automatiquement combien de cours valider par jour.
🎯 DIAGNOSTIC IA « PRIORITÉS DU JOUR » :
• Identifie chaque matin les 3 chapitres les plus rentables (Poids aux examens de Blida × Couches restantes).
📡 SCANNER AUTOMATIQUE TELEGRAM & GOOGLE DRIVE BLIDA :
• Veille biquotidienne détectant les nouveaux sujets d'EMD, QCM et cours PDF de Médecine Blida !

━━━━━━━━━━━━━━━━━━━━
📲 ACCÈS IMMÉDIAT & GRATUIT (14 JOURS D'ESSAI COMPLET) :
🌐 Version Web : {OFFICIAL_WEB_URL}
📱 Android APK : {OFFICIAL_APK_URL}
💻 Windows PC : {OFFICIAL_WIN_URL}
✈️ Canal Telegram : {OFFICIAL_TELEGRAM_URL}

#Medsina #MedevSync #StudyPlanner #ResidanatBlida2027 #MedecineBlida #ConcoursResidanat #EtudiantMedecineDZ"""

    # Publish Post 1 (Duo Mockup QCM Ultra + FSRS) on both Facebook pages
    res_blida_1 = publish_to_fb_page(pages["residanat_blida_2027"], img1, fb_caption_1)
    res_medev_1 = publish_to_fb_page(pages["medevsync"], img1, fb_caption_1)

    # Publish Post 2 (Study Planner 3 Couches & Veille Blida) on both Facebook pages
    res_blida_2 = publish_to_fb_page(pages["residanat_blida_2027"], img2, fb_caption_2)
    res_medev_2 = publish_to_fb_page(pages["medevsync"], img2, fb_caption_2)

    if res_blida_1 and (res_blida_1.get("post_id") or res_blida_1.get("id")):
        record_publication_success(
            res_blida_1.get("post_id") or res_blida_1.get("id"),
            res_blida_1.get("id"),
            {
                "title": "Medsina v1.0.22 Ultra : FSRS, Study Planner 3 Couches & QCM Ultra",
                "theme": "indigo",
                "caption": fb_caption_1,
            },
        )

    # Concise Telegram captions (< 1024 chars limit for sendPhoto)
    tg_caption_1 = f"""🚀 <b>MISE À JOUR MAJEURE : MEDSINA v1.0.22 « MEDSINA ULTRA » !</b> 🩺🇩🇿

1️⃣ 🎯 <b>Moteur QCM Ultra & Stats (% A-E) :</b>
• Mode Révision ou <b>Examen Blanc Chronométré</b> (Tout ou Rien / Partiel).
• Filtres : <i>Jamais vues, Mes Erreurs, Favoris ⭐, Mes Notes 📝, Haute Tombabilité 🔥</i>.
• <b>% de choix par option (A-E)</b> + Alerte sur les questions négatives !

2️⃣ 🧠 <b>Répétition Espacée FSRS v4.5 & Flashcards 1-Clic :</b>
• Convertissez n'importe quel QCM en Flashcard Recto/Verso en 1 seul clic.

3️⃣ 📅 <b>Study Planner 3 Couches & Veille Auto Blida :</b>
• Suivi <b>Couche 1/2/3 + % QCM</b>, compte à rebours J-X, Top 3 cours du jour & Mur d'Avis 5★.

🌐 <b>Web :</b> <a href="{OFFICIAL_WEB_URL}">{OFFICIAL_WEB_URL}</a>
📱 <b>Android APK :</b> <a href="{OFFICIAL_APK_URL}">Télécharger l'APK</a>
💻 <b>Windows PC :</b> <a href="{OFFICIAL_WIN_URL}">Télécharger Setup PC</a>"""

    tg_caption_2 = f"""📅 <b>NOUVEAU : STUDY PLANNER 3 COUCHES & VEILLE AUTO BLIDA (v1.0.22) !</b> 🔥🩺

• ☑️ <b>Suivi par 3 Couches</b> (Lecture, Mémorisation, Finale) + <b>% Maîtrise QCM</b> sur les 47 modules.
• ⏱️ <b>Cadence Quotidienne (J-X) :</b> calcul automatique du nombre de cours/jour avant l'EMD ou le Concours de Résidanat.
• 🎯 <b>Priorités du Jour :</b> les 3 chapitres les plus rentables aux examens de Blida.
• 📡 <b>Scanner Auto Telegram & Drive Blida :</b> détection quotidienne des nouveaux QCM et sujets d'EMD !

🌐 <b>Web :</b> <a href="{OFFICIAL_WEB_URL}">{OFFICIAL_WEB_URL}</a>
📱 <b>Android APK :</b> <a href="{OFFICIAL_APK_URL}">Télécharger l'APK</a>
💻 <b>Windows PC :</b> <a href="{OFFICIAL_WIN_URL}">Télécharger Setup PC</a>"""

    print("\n✈️ Diffusion des 2 infographies sur Telegram (@medsina_officiel)...")
    tg1 = send_telegram_broadcast(message_text=tg_caption_1, image_path=img1)
    print(f"🎉 Telegram Post 1 OK ! Message ID: {tg1.get('result', {}).get('message_id')}")
    tg2 = send_telegram_broadcast(message_text=tg_caption_2, image_path=img2)
    print(f"🎉 Telegram Post 2 OK ! Message ID: {tg2.get('result', {}).get('message_id')}")


if __name__ == "__main__":
    main()
