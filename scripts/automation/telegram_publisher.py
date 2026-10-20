#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
=============================================================================
MEDSINA & MEDEVSYNC TELEGRAM BROADCASTER (Canal Officiel & Bot)
=============================================================================
Diffuse automatiquement sur Telegram :
1. La Perle Clinique & Piège du Concours (Matin / Midi)
2. Les Mémentos de Garde & CAT Urgences (Soir)
3. Les Mises à jour d'applications (Web, Android APK, Windows EXE)

Intègre :
- Téléversement de l'infographie haute résolution générée (1080x1080)
- Mise en page riche en HTML/Markdown Telegram avec emojis
- Boutons Inline interactifs (Lien Web Octenium, Téléchargement APK direct)
- Gestion des credentials depuis Supabase `admin_system_settings` ou variables d'environnement.
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
    if sys.stdout.encoding.lower() != 'utf-8':
        sys.stdout.reconfigure(encoding='utf-8')
except Exception:
    pass

SUPABASE_URL = os.getenv("SUPABASE_URL", "https://qzfssrhhuorljftpdvjm.supabase.co")
SUPABASE_SERVICE_ROLE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")

OCTENIUM_WEB_URL = "https://medsina.medevsync.com"
OCTENIUM_APK_URL = "https://medsina.medevsync.com/download/medsina.apk"
OCTENIUM_EXE_URL = "https://medsina.medevsync.com/download/medsina-setup.exe"


def load_env_service_role() -> str:
    global SUPABASE_SERVICE_ROLE_KEY
    if SUPABASE_SERVICE_ROLE_KEY:
        return SUPABASE_SERVICE_ROLE_KEY

    # Check .env in parent directories
    for p in [Path(".env"), Path("../../.env"), Path(__file__).resolve().parents[2] / ".env"]:
        if p.exists():
            import re
            content = p.read_text(encoding="utf-8")
            m = re.search(r"SUPABASE_SERVICE_ROLE_KEY\s*=\s*['\"]?([^'\"\r\n]+)['\"]?", content)
            if m:
                SUPABASE_SERVICE_ROLE_KEY = m.group(1).strip()
                return SUPABASE_SERVICE_ROLE_KEY
    return ""


def get_telegram_credentials() -> Dict[str, str]:
    """
    Récupère le token du bot Telegram et l'identifiant du canal depuis :
    1. Variables d'environnement (TELEGRAM_BOT_TOKEN, TELEGRAM_CHANNEL_ID)
    2. Supabase table `admin_system_settings`
    """
    token = os.getenv("TELEGRAM_BOT_TOKEN", "").strip()
    channel = os.getenv("TELEGRAM_CHANNEL_ID", "").strip()

    if token and channel:
        return {"bot_token": token, "channel_id": channel}

    key = load_env_service_role()
    if key:
        try:
            headers = {"apikey": key, "Authorization": f"Bearer {key}"}
            r = requests.get(f"{SUPABASE_URL}/rest/v1/admin_system_settings?select=*", headers=headers, timeout=10)
            if r.status_code == 200 and r.json():
                settings = {item.get("setting_key"): item.get("setting_value") for item in r.json() if isinstance(item, dict)}
                if not token:
                    token = (settings.get("telegram_bot_token") or "").strip()
                if not channel:
                    channel = (settings.get("telegram_channel_id") or "").strip()
        except Exception as e:
            print(f"⚠️ Erreur lors de la lecture des réglages Telegram Supabase: {e}")

    return {"bot_token": token, "channel_id": channel}


def send_telegram_broadcast(
    message_text: str,
    image_path: Optional[str] = None,
    bot_token: Optional[str] = None,
    channel_id: Optional[str] = None,
    dry_run: bool = False
) -> Dict[str, Any]:
    """
    Envoie le post formaté avec photo et boutons inline sur Telegram.
    """
    creds = get_telegram_credentials()
    token = (bot_token or creds.get("bot_token", "")).strip()
    channel = (channel_id or creds.get("channel_id", "")).strip()

    # Boutons d'action rapides Medsina Octenium
    inline_keyboard = {
        "inline_keyboard": [
            [
                {"text": "🌐 Ouvrir Medsina Web", "url": OCTENIUM_WEB_URL},
                {"text": "📱 Télécharger APK Android", "url": OCTENIUM_APK_URL}
            ],
            [
                {"text": "💻 Télécharger PC Windows", "url": OCTENIUM_EXE_URL},
                {"text": "👥 Page Facebook", "url": "https://www.facebook.com/1329939320211198"}
            ]
        ]
    }

    if dry_run or not token or not channel:
        print("\n" + "=" * 60)
        print("📢 [TELEGRAM SIMULATEUR / DRY RUN]")
        print(f"🎯 Canal Cible : {channel or 'NON CONFIGURÉ (ex: @medsina_officiel)'}")
        print(f"🤖 Bot Token   : {'PRÉSENT' if token else 'NON CONFIGURÉ'}")
        if image_path and os.path.exists(image_path):
            print(f"🖼️ Image jointe: {image_path} ({os.path.getsize(image_path) // 1024} Ko)")
        print("-" * 60)
        print(message_text)
        print("-" * 60)
        print("🔘 Boutons Inline :")
        for row in inline_keyboard["inline_keyboard"]:
            print("  " + " | ".join([f"[{b['text']} -> {b['url']}]" for b in row]))
        print("=" * 60)

        if not token or not channel:
            print("\n💡 NOTE CONFIGURATION TELEGRAM :")
            print("Pour activer la diffusion réelle sur Telegram :")
            print("1. Créez un bot via @BotFather et obtenez le token.")
            print("2. Créez un canal Telegram (ex: @medsina_dz), ajoutez le bot en Administrateur.")
            print("3. Renseignez `telegram_bot_token` et `telegram_channel_id` dans Supabase `admin_system_settings` ou dans les secrets GitHub.")
            return {"simulated": True, "success": True, "notice": "Credentials pending"}

        return {"simulated": True, "success": True}

    # Publication réelle via l'API Telegram Bot
    if image_path and os.path.exists(image_path):
        api_url = f"https://api.telegram.org/bot{token}/sendPhoto"
        with open(image_path, "rb") as img:
            files = {"photo": img}
            data = {
                "chat_id": channel,
                "caption": message_text,
                "parse_mode": "HTML",
                "reply_markup": json.dumps(inline_keyboard)
            }
            resp = requests.post(api_url, data=data, files=files, timeout=45)
    else:
        api_url = f"https://api.telegram.org/bot{token}/sendMessage"
        data = {
            "chat_id": channel,
            "text": message_text,
            "parse_mode": "HTML",
            "reply_markup": json.dumps(inline_keyboard),
            "disable_web_page_preview": False
        }
        resp = requests.post(api_url, json=data, timeout=30)

    if resp.status_code == 200:
        result = resp.json()
        print(f"✅ Diffusion Telegram réussie sur {channel} ! Message ID: {result.get('result', {}).get('message_id')}")
        return result
    else:
        print(f"❌ Erreur Telegram ({resp.status_code}): {resp.text}")
        raise RuntimeError(f"Telegram API Error: {resp.text}")


def format_telegram_caption(title: str, badge: str, points: list, reference: str = "", app_version: str = "1.0.8") -> str:
    """
    Formate un message clair, élégant et optimisé pour Telegram en HTML.
    """
    html = f"<b>🩺 [MEDSINA • {badge.upper()}]</b>\n"
    html += f"<b>{title}</b>\n\n"

    for i, pt in enumerate(points, 1):
        html += f"<b>{i}️⃣</b> {pt}\n\n"

    if reference:
        html += f"💡 <i>Référence clinique : {reference}</i>\n\n"

    html += "━━━━━━━━━━━━━━━━━━━━\n"
    html += f"🇩🇿 <b>Medsina v{app_version}</b> — L'Écosystème Médical & Concours Résidanat en Algérie.\n"
    html += "<i>Accédez aux 47 modules, annales QCMs et protocoles de garde.</i>"
    return html


def main():
    parser = argparse.ArgumentParser(description="Medsina Official Telegram Channel Broadcaster")
    parser.add_argument("--image", type=str, default="output_banner.png", help="Path to infographic image")
    parser.add_argument("--title", type=str, default="Urgences Obstétricales en Garde", help="Post title")
    parser.add_argument("--badge", type=str, default="MÉMENTO • GYNÉCOLOGIE", help="Badge category")
    parser.add_argument("--dry-run", action="store_true", help="Test mode without sending to Telegram")
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
        dry_run=args.dry_run
    )


if __name__ == "__main__":
    main()

