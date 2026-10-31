#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
=============================================================================
MEDSINA & MEDEVSYNC TELEGRAM BROADCASTER (Canal Officiel & Topics Communauté)
=============================================================================
Diffusé automatiquement sur Telegram :
1. Sur le Canal Officiel « @medsina_officiel » (Push global)
2. Dans le Topic ciblé du Supergroupe « MEDSINA-COMMUNITY » (-1004438944860) :
   - ID 1  : General (Annonces, releases, mot du fondateur)
   - ID 2  : CONDUITES PRATIQUES (CAT, arbres décisionnels, urgences)
   - ID 4  : RESIDANAT-BLIDA-2027-COURS (Cours officiels des facultés, drives)
   - ID 6  : MEMENTO DE GARDES (Mémentos de garde, pharmacie d'urgence, normes bio)
   - ID 8  : CURSUS EXTERNAT BLIDA 2027 (Informations stages, tuteurs IA des 6 années)
   - ID 11 : RESIDANAT-BLIDA-2027-RESUMES (Fiches résumés, perles cliniques)
   - ID 13 : RESIDANAT-BLIDA-2027-TEMOIGNAGES (Retours d'expérience majors, plannings)
   - ID 15 : RESIDANAT-BLIDA-2027-CONCOURS-PRATIQUE (QCMs résidanat, annales classées)
   - ID 18 : CURSUS-EXTERNAT-BLIDA-2027- PRATIQUE EMD (Simulations EMD blanches /20)

Intègre :
- Téléversement de l'infographie haute résolution (1080x1080)
- Mise en page riche en HTML Telegram avec boutons interactifs
- Orientation proactive vers l'application Medsina TOUT-EN-UN
=============================================================================
"""

import os
import sys
import argparse
import requests
import json
from pathlib import Path
from typing import Dict, Any, Optional

try:
    from anti_duplicate_guard import check_duplicate_or_flood, record_publication
except ImportError:
    check_duplicate_or_flood = None
    record_publication = None

try:
    if sys.stdout.encoding.lower() != 'utf-8':
        sys.stdout.reconfigure(encoding='utf-8')
except Exception:
    pass

SUPABASE_URL = os.getenv("SUPABASE_URL", "https://qzfssrhhuorljftpdvjm.supabase.co")
SUPABASE_SERVICE_ROLE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")

OCTENIUM_WEB_URL = "https://medsina.medevsync.com"
OCTENIUM_APK_URL = "https://medsina.medevsync.com/download/medsina.apk"
OCTENIUM_EXE_URL = "https://medsina.medevsync.com/download/medsina-setup.exe"

# Supergroupe Communautaire (MEDSINA-COMMUNITY)
DEFAULT_COMMUNITY_GROUP_ID = "-1004438944860"

DEFAULT_TOPICS_MAP = {
    "general": 1,
    "cat": 2,
    "cours": 4,
    "residanat": 4,
    "memento": 6,
    "drug": 6,
    "lab": 6,
    "externat": 8,
    "summary": 11,
    "pearl": 11,
    "testimony": 13,
    "qcm": 15,
    "concours": 15,
    "emd": 18,
    "simulation": 18
}

TOPIC_NAMES = {
    1: "General",
    2: "CONDUITES PRATIQUES",
    4: "RESIDANAT-BLIDA-2027-COURS",
    6: "MEMENTO DE GARDES",
    8: "CURSUS EXTERNAT BLIDA 2027",
    11: "RESIDANAT-BLIDA-2027-RESUMES",
    13: "RESIDANAT-BLIDA-2027-TEMOIGNAGES",
    15: "RESIDANAT-BLIDA-2027-CONCOURS-PRATIQUE",
    18: "CURSUS-EXTERNAT-BLIDA-2027- PRATIQUE EMD"
}


def load_env_service_role() -> str:
    global SUPABASE_SERVICE_ROLE_KEY
    if SUPABASE_SERVICE_ROLE_KEY:
        return SUPABASE_SERVICE_ROLE_KEY

    for p in [Path(".env"), Path("../../.env"), Path(__file__).resolve().parents[2] / ".env"]:
        if p.exists():
            import re
            content = p.read_text(encoding="utf-8")
            m = re.search(r"SUPABASE_SERVICE_ROLE_KEY\s*=\s*['\"]?([^'\"\r\n]+)['\"]?", content)
            if m:
                SUPABASE_SERVICE_ROLE_KEY = m.group(1).strip()
                return SUPABASE_SERVICE_ROLE_KEY
    return ""


def get_telegram_credentials() -> Dict[str, Any]:
    """
    Récupère le bot token, canal ID, groupe ID et mapping des topics depuis :
    1. Variables d'environnement
    2. Supabase table admin_system_settings
    """
    token = os.getenv("TELEGRAM_BOT_TOKEN", "").strip()
    channel = os.getenv("TELEGRAM_CHANNEL_ID", "").strip()
    community_group = os.getenv("TELEGRAM_COMMUNITY_GROUP_ID", "").strip()
    topics_map = None

    key = load_env_service_role()
    if key and (not token or not channel or not community_group or not topics_map):
        try:
            headers = {"apikey": key, "Authorization": f"Bearer {key}"}
            r = requests.get(f"{SUPABASE_URL}/rest/v1/admin_system_settings?select=*", headers=headers, timeout=10)
            if r.status_code == 200 and r.json():
                settings = {item.get("setting_key"): item.get("setting_value") for item in r.json() if isinstance(item, dict)}
                if not token:
                    token = (settings.get("telegram_bot_token") or "").strip()
                if not channel:
                    channel = (settings.get("telegram_channel_id") or "@medsina_officiel").strip()
                if not community_group:
                    community_group = (settings.get("telegram_community_group_id") or DEFAULT_COMMUNITY_GROUP_ID).strip()
                if not topics_map and settings.get("telegram_topics_map"):
                    try:
                        topics_map = json.loads(settings.get("telegram_topics_map"))
                    except Exception:
                        pass
        except Exception as e:
            print(f"⚠️ Erreur lors de la lecture des réglages Telegram Supabase: {e}")

    if not channel:
        channel = "@medsina_officiel"
    if not community_group:
        community_group = DEFAULT_COMMUNITY_GROUP_ID
    if not topics_map:
        topics_map = DEFAULT_TOPICS_MAP

    return {
        "bot_token": token,
        "channel_id": channel,
        "community_group_id": community_group,
        "topics_map": topics_map
    }


def resolve_telegram_topic(category: Optional[str] = None, text: str = "", topics_map: Optional[Dict[str, int]] = None) -> int:
    """
    Détermine automatiquement l'ID du topic correspondant dans MEDSINA-COMMUNITY.
    """
    mapping = topics_map or DEFAULT_TOPICS_MAP
    cat_lower = (category or "").lower().strip()

    if cat_lower in mapping:
        return mapping[cat_lower]

    for k, v in mapping.items():
        if k in cat_lower:
            return v

    t = text.lower()
    if any(w in t for w in ["conduite à tenir", "cat", "arbre décisionnel", "urgence vitale", "protocole d'urgence", "réanimation", "cat aux urgences"]):
        return mapping.get("cat", 2)
    if any(w in t for w in ["mémento", "memento", "garde", "posologie", "dci", "constantes", "normes bio", "saidal", "pch"]):
        return mapping.get("memento", 6)
    if any(w in t for w in ["qcm", "concours réel", "annales", "session 20", "corrigé type", "qcm concours"]):
        return mapping.get("qcm", 15)
    if any(w in t for w in ["emd", "examen blanc", "simulation emd"]):
        return mapping.get("emd", 18)
    if any(w in t for w in ["externat", "stage", "tuteur", "tuteurs pédagogiques"]):
        return mapping.get("externat", 8)
    if any(w in t for w in ["témoignage", "temoignage", "major", "méthodologie", "planning"]):
        return mapping.get("testimony", 13)
    if any(w in t for w in ["résumé", "resume", "perle", "piège", "piege", "fiche de synthèse"]):
        return mapping.get("summary", 11)
    if any(w in t for w in ["cours", "drive", "polycopié"]):
        return mapping.get("cours", 4)

    return mapping.get("general", 1)


def _post_telegram_payload(
    token: str,
    target_id: str,
    message_text: str,
    image_path: Optional[str] = None,
    inline_keyboard: Optional[Dict] = None,
    message_thread_id: Optional[int] = None,
    auto_pin: bool = False,
    target_label: str = "Telegram"
) -> Optional[int]:
    """
    Envoie une photo ou un message texte vers un chat_id (canal ou groupe)
    avec support natif du message_thread_id pour les topics de forum.
    """
    reply_markup = inline_keyboard or {}

    # Tronquage propre pour sendPhoto (max 1024 caractères UTF-16)
    tg_caption = message_text
    if len(tg_caption) > 940:
        cut_idx = tg_caption[:890].rfind("\n")
        if cut_idx == -1:
            cut_idx = 890
        tg_caption = tg_caption[:cut_idx].strip() + "...\n\n👉 Suite sur " + OCTENIUM_WEB_URL

    # Note Telegram Forum : Le thread 1 (General) est le root du groupe, sans message_thread_id
    valid_thread_id = message_thread_id if (message_thread_id and message_thread_id != 1) else None

    msg_id = None
    if image_path and os.path.exists(image_path):
        api_url = f"https://api.telegram.org/bot{token}/sendPhoto"
        with open(image_path, "rb") as img:
            files = {"photo": img}
            data = {
                "chat_id": target_id,
                "caption": tg_caption,
                "parse_mode": "HTML",
                "reply_markup": json.dumps(reply_markup)
            }
            if valid_thread_id:
                data["message_thread_id"] = valid_thread_id

            resp = requests.post(api_url, data=data, files=files, timeout=40)

        if resp.status_code == 200 and resp.json().get("ok"):
            msg_id = resp.json().get("result", {}).get("message_id")
        else:
            # Fallback résilient : photo courte puis texte complet sendMessage
            print(f"⚠️ Avertissement sendPhoto {target_label} ({resp.status_code}): {resp.text[:120]}")
            with open(image_path, "rb") as img2:
                fb_data = {"chat_id": target_id, "caption": f"🩺 {OCTENIUM_WEB_URL}"}
                if valid_thread_id:
                    fb_data["message_thread_id"] = valid_thread_id
                requests.post(api_url, data=fb_data, files={"photo": img2}, timeout=25)

            msg_url = f"https://api.telegram.org/bot{token}/sendMessage"
            text_data = {
                "chat_id": target_id,
                "text": message_text[:4000],
                "parse_mode": "HTML",
                "reply_markup": json.dumps(reply_markup),
                "disable_web_page_preview": False
            }
            if valid_thread_id:
                text_data["message_thread_id"] = valid_thread_id
            resp2 = requests.post(msg_url, json=text_data, timeout=30)
            if resp2.status_code == 200 and resp2.json().get("ok"):
                msg_id = resp2.json().get("result", {}).get("message_id")
            else:
                # Raw text fallback
                text_data.pop("parse_mode", None)
                resp3 = requests.post(msg_url, json=text_data, timeout=25)
                if resp3.status_code == 200 and resp3.json().get("ok"):
                    msg_id = resp3.json().get("result", {}).get("message_id")
    else:
        msg_url = f"https://api.telegram.org/bot{token}/sendMessage"
        text_data = {
            "chat_id": target_id,
            "text": message_text[:4000],
            "parse_mode": "HTML",
            "reply_markup": json.dumps(reply_markup),
            "disable_web_page_preview": False
        }
        if valid_thread_id:
            text_data["message_thread_id"] = valid_thread_id
        resp = requests.post(msg_url, json=text_data, timeout=30)
        if resp.status_code == 200 and resp.json().get("ok"):
            msg_id = resp.json().get("result", {}).get("message_id")
        else:
            text_data.pop("parse_mode", None)
            resp2 = requests.post(msg_url, json=text_data, timeout=25)
            if resp2.status_code == 200 and resp2.json().get("ok"):
                msg_id = resp2.json().get("result", {}).get("message_id")

    if msg_id:
        topic_info = f" [Topic #{message_thread_id} : {TOPIC_NAMES.get(message_thread_id, 'Topic')}]" if message_thread_id else ""
        print(f"✅ Succès {target_label}{topic_info} ! Message ID: {msg_id}")
        if auto_pin:
            try:
                requests.post(
                    f"https://api.telegram.org/bot{token}/pinChatMessage",
                    json={"chat_id": target_id, "message_id": msg_id, "disable_notification": False},
                    timeout=10
                )
                print(f"📌 Message #{msg_id} épinglé sur {target_label}.")
            except Exception:
                pass
    return msg_id


def send_telegram_broadcast(
    message_text: str,
    image_path: Optional[str] = None,
    bot_token: Optional[str] = None,
    channel_id: Optional[str] = None,
    community_group_id: Optional[str] = None,
    topic_id: Optional[int] = None,
    category: Optional[str] = None,
    dry_run: bool = False,
    auto_pin: bool = True,
    broadcast_to_community: bool = True
) -> Dict[str, Any]:
    """
    Envoie le post formaté avec photo et boutons inline sur Telegram :
    1. Sur le canal officiel (@medsina_officiel)
    2. Dans le bon Topic du supergroupe communautaire MEDSINA-COMMUNITY
    """
    creds = get_telegram_credentials()
    token = (bot_token or creds.get("bot_token", "")).strip()
    channel = (channel_id or creds.get("channel_id", "")).strip()
    community = (community_group_id or creds.get("community_group_id", "")).strip()
    topics_map = creds.get("topics_map", DEFAULT_TOPICS_MAP)

    target_topic_id = topic_id if topic_id is not None else resolve_telegram_topic(category, message_text, topics_map)
    topic_title = TOPIC_NAMES.get(target_topic_id, f"Topic #{target_topic_id}")

    inline_keyboard = {
        "inline_keyboard": [
            [
                {"text": "🌐 Ouvrir Medsina Web", "url": OCTENIUM_WEB_URL},
                {"text": "📱 Télécharger APK Android", "url": OCTENIUM_APK_URL}
            ],
            [
                {"text": "💻 Télécharger PC Windows", "url": OCTENIUM_EXE_URL},
                {"text": "👥 Page Facebook Residanat Blida", "url": "https://www.facebook.com/residanatblida2027"}
            ]
        ]
    }

    if dry_run or not token or not channel:
        print("\n" + "=" * 60)
        print("📢 [TELEGRAM SIMULATEUR / DRY RUN]")
        print(f"🎯 Canal Officiel : {channel or 'NON CONFIGURÉ (ex: @medsina_officiel)'}")
        print(f"🎯 Groupe Communauté : {community} -> Topic #{target_topic_id} ({topic_title})")
        print(f"🤖 Bot Token   : {'PRÉSENT' if token else 'NON CONFIGURÉ'}")
        if image_path and os.path.exists(image_path):
            print(f"🖼️ Image jointe: {image_path} ({os.path.getsize(image_path) // 1024} Ko)")
        print("-" * 60)
        print(message_text)
        print("=" * 60)
        return {"simulated": True, "success": True, "topic_id": target_topic_id, "topic_name": topic_title}

    # Protection anti-doublon et anti-flood sur le canal officiel
    if check_duplicate_or_flood:
        is_dup, reason = check_duplicate_or_flood(channel, message_text, cooldown_minutes=60)
        if is_dup:
            print(f"🛑 [Telegram Anti-Doublon] Publication ignorée sur le canal : {reason}")
            return {"success": False, "skipped": True, "reason": reason}

    results = {
        "channel_success": False,
        "channel_msg_id": None,
        "community_success": False,
        "community_msg_id": None,
        "topic_id": target_topic_id,
        "topic_name": topic_title
    }

    # 1. Diffusion sur le Canal Officiel
    print(f"🚀 Diffusion Telegram sur le Canal Officiel ({channel})...")
    ch_msg_id = _post_telegram_payload(
        token=token,
        target_id=channel,
        message_text=message_text,
        image_path=image_path,
        inline_keyboard=inline_keyboard,
        message_thread_id=None,
        auto_pin=auto_pin,
        target_label="Canal Officiel"
    )
    if ch_msg_id:
        results["channel_success"] = True
        results["channel_msg_id"] = ch_msg_id
        if record_publication:
            record_publication(channel, message_text, str(ch_msg_id))

    # 2. Diffusion ciblée dans le Topic du Forum Communautaire
    if broadcast_to_community and community:
        print(f"🚀 Diffusion Telegram sur MEDSINA-COMMUNITY -> Topic #{target_topic_id} : « {topic_title} »...")
        com_msg_id = _post_telegram_payload(
            token=token,
            target_id=community,
            message_text=message_text,
            image_path=image_path,
            inline_keyboard=inline_keyboard,
            message_thread_id=target_topic_id,
            auto_pin=False,
            target_label=f"Communauté #{target_topic_id}"
        )
        if com_msg_id:
            results["community_success"] = True
            results["community_msg_id"] = com_msg_id

    results["success"] = results["channel_success"] or results["community_success"]
    return results


def format_telegram_caption(title: str, badge: str, points: list, reference: str = "", app_version: str = "1.0.8") -> str:
    """
    Formate un message clair, élégant et optimisé pour Telegram en HTML,
    orientant l'étudiant vers l'application tout-en-un Medsina.
    """
    html = f"🩺 <b>[MEDSINA • {badge.upper()}]</b>\n"
    html += f"📌 <b>{title}</b>\n\n"

    for i, pt in enumerate(points[:4], 1):
        html += f"<b>{i}️⃣</b> {pt}\n"

    if reference:
        html += f"\n💡 <i>Référence clinique : {reference}</i>\n"

    html += "\n━━━━━━━━━━━━━━━━━━━━\n"
    html += "🚀 <b>TOUT-EN-UN SUR L'APPLICATION MEDSINA</b>\n"
    html += "<i>Fini de vous disperser entre 50 groupes, drives et canaux !\nCours complets, résumés, QCMs classés, arbres CAT d'urgence et tuteurs IA réunis en un seul endroit 100% hors-ligne.</i>"
    return html


def format_telegram_quiz_caption(qcm: dict, app_version: str = "1.0.8") -> str:
    """
    Formate une question d'annales QCM pour diffusion sur Telegram avec options et call to action Medsina.
    """
    source = qcm.get("source", "Concours Officiel")
    course = qcm.get("courseName", "Révision Médicale")
    module = qcm.get("moduleName", "Médecine")
    year = qcm.get("year", "2024")
    q_text = qcm.get("questionText", "").strip()
    options = qcm.get("options", [])

    html = f"🎯 <b>[QCM CONCOURS RÉEL • {source.upper()}]</b>\n"
    html += f"📚 <b>Module : {module}</b> | <b>{course}</b> (Session {year})\n\n"
    html += f"❓ <b>Question :</b>\n<i>« {q_text[:280]} »</i>\n\n"

    for opt in options[:5]:
        html += f"🔹 <b>{opt.get('key')}</b> : {opt.get('text')}\n"

    html += "\n💬 <b>Commentez votre réponse (A, B, C, D ou E) !</b>\n"
    html += "━━━━━━━━━━━━━━━━━━━━\n"
    html += "🚀 <i>La correction détaillée du Pr. et les annales classées par module sont réunies sur l'application Tout-en-Un Medsina.</i>"
    return html


def main():
    parser = argparse.ArgumentParser(description="Medsina Official Telegram Broadcaster with Topic Support")
    parser.add_argument("--image", type=str, default="output_banner.png", help="Path to banner image")
    parser.add_argument("--title", type=str, default="Urgences Obstétricales en Garde", help="Post title")
    parser.add_argument("--badge", type=str, default="MÉMENTO • GYNÉCOLOGIE", help="Badge category")
    parser.add_argument("--category", type=str, default="memento", help="Content category for topic routing")
    parser.add_argument("--topic-id", type=int, default=None, help="Explicit Telegram message_thread_id")
    parser.add_argument("--dry-run", action="store_true", help="Test mode without sending")
    parser.add_argument("--no-community", action="store_true", help="Skip broadcasting to community forum")
    args = parser.parse_args()

    points = [
        "<b>Pré-éclampsie sévère</b> : PAS ≥ 160 ou PAD ≥ 110 mmHg + protéinurie + céphalées → Nicardipine IV (Loxen) au PSE + Sulfate de magnésium.",
        "<b>Crise d'éclampsie</b> : MgSO4 4 g IV en 15 min puis 1 g/h au PSE. Toujours avoir du Gluconate de calcium à portée de main.",
        "<b>Hémorragie de la Délivrance</b> : Ocytocine 5 à 10 UI IV lente immédiate + révision utérine + sac de recueil.",
        "<b>Contre-indication formelle</b> : AINS et Aspirine forte dose dès le début du 6e mois de grossesse."
    ]

    caption = format_telegram_caption(args.title, args.badge, points, reference="Recommandations CNGOF / SFAR")
    send_telegram_broadcast(
        message_text=caption,
        image_path=args.image if os.path.exists(args.image) else None,
        category=args.category,
        topic_id=args.topic_id,
        dry_run=args.dry_run,
        broadcast_to_community=not args.no_community
    )


if __name__ == "__main__":
    main()
