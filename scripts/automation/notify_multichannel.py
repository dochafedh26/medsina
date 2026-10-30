#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
=============================================================================
MEDSINA - MULTI-CHANNEL BROADCASTER & NOTIFICATION DISPATCHER
=============================================================================
Unified engine to notify all users whenever:
1. A new feature is released in Medsina.
2. New pedagogical resources (Samedis Pédagogiques, Témoignages, Courses, QCMs) are added.
3. System announcements or clinical alerts are published.

Broadcast Channels:
- In-App Realtime Notification (Supabase WebSockets -> Android, Windows, Web)
- 3 Official Facebook Pages (Medsina, MedevSync, Résidanat Blida 2027)
- Official Telegram Channel & Bot (@medsina_officiel)
=============================================================================
"""

import os
import sys
import json
import time
import argparse
import requests
from pathlib import Path
from typing import Dict, Any, Optional, List

if sys.stdout and hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

SCRIPT_DIR = Path(__file__).resolve().parent
ROOT_DIR = SCRIPT_DIR.parents[1]
ENV_PATH = ROOT_DIR / ".env"

SUPABASE_URL = os.environ.get("SUPABASE_URL", "https://qzfssrhhuorljftpdvjm.supabase.co")
SERVICE_ROLE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")

if not SERVICE_ROLE_KEY and ENV_PATH.exists():
    with open(ENV_PATH, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line.startswith("SUPABASE_SERVICE_ROLE_KEY="):
                SERVICE_ROLE_KEY = line.split("=", 1)[1]
            elif line.startswith("SUPABASE_URL="):
                SUPABASE_URL = line.split("=", 1)[1]

if not SERVICE_ROLE_KEY:
    # Fallback to service_role JWT
    SERVICE_ROLE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF6ZnNzcmhodW9ybGpmdHBkdmptIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MTYxMjg1NCwiZXhwIjoyMTA3MTg4ODU0fQ.-KCUgZdY8RDUwvNOUAabDhQFwv5FFGHYz0J-dM7Cic4"

# -----------------------------------------------------------------------------
# 1. IN-APP REALTIME NOTIFICATION (SUPABASE)
# -----------------------------------------------------------------------------
def send_in_app_notification(
    title: str,
    message: str,
    notif_type: str = "announcement",
    target_id: Optional[str] = None,
    metadata: Optional[Dict[str, Any]] = None,
    custom_id: Optional[str] = None
) -> bool:
    """Inserts a notification into Supabase medical_notifications, triggering Realtime WebSocket push."""
    notif_id = custom_id or f"notif_{int(time.time() * 1000)}"
    payload = {
        "id": notif_id,
        "title": title,
        "message": message,
        "type": notif_type,
        "target_id": target_id,
        "target_role": "all",
        "metadata": metadata or {},
        "created_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    }

    headers = {
        "apikey": SERVICE_ROLE_KEY,
        "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
        "Content-Type": "application/json",
        "Prefer": "resolution=merge-duplicates"
    }
    url = f"{SUPABASE_URL}/rest/v1/medical_notifications"
    try:
        res = requests.post(url, headers=headers, json=payload, timeout=15)
        if res.status_code in (200, 201):
            print(f"  📲 [In-App] Notification diffusée en temps réel avec succès (ID: {notif_id})")
            return True
        else:
            print(f"  ⚠️ [In-App] Erreur Supabase ({res.status_code}): {res.text}")
            return False
    except Exception as e:
        print(f"  ❌ [In-App] Erreur de connexion: {e}")
        return False

# -----------------------------------------------------------------------------
# 2. FACEBOOK MULTI-PAGE BROADCAST (3 PAGES)
# -----------------------------------------------------------------------------
def send_facebook_broadcast(message: str, link: Optional[str] = None) -> Dict[str, Any]:
    """Publishes the announcement to the 3 Facebook pages."""
    sys.path.insert(0, str(SCRIPT_DIR))
    try:
        from facebook_publisher import publish_facebook_post
        print("  📢 [Facebook] Diffusion sur les 3 pages (Medsina, MedevSync, Résidanat Blida 2027)...")
        res = publish_facebook_post(message, link=link)
        return res
    except Exception as e:
        print(f"  ⚠️ [Facebook] Notification Facebook en attente de validation token : {e}")
        return {"success": False, "error": str(e)}

# -----------------------------------------------------------------------------
# 3. TELEGRAM CHANNEL BROADCAST
# -----------------------------------------------------------------------------
def send_telegram_broadcast_message(
    message_text: str,
    image_path: Optional[str] = None
) -> Dict[str, Any]:
    """Publishes the message to the Telegram channel."""
    sys.path.insert(0, str(SCRIPT_DIR))
    try:
        from telegram_publisher import send_telegram_broadcast
        print("  ✈️ [Telegram] Diffusion sur le canal officiel Telegram...")
        res = send_telegram_broadcast(message_text, image_path=image_path)
        return res
    except Exception as e:
        print(f"  ⚠️ [Telegram] Notification Telegram : {e}")
        return {"success": False, "error": str(e)}

# -----------------------------------------------------------------------------
# 4. MASTER BROADCAST DISPATCHER
# -----------------------------------------------------------------------------
def broadcast_all(
    title: str,
    in_app_message: str,
    social_message: Optional[str] = None,
    notif_type: str = "announcement",
    target_id: Optional[str] = None,
    link: Optional[str] = None,
    image_path: Optional[str] = None,
    custom_id: Optional[str] = None
) -> Dict[str, bool]:
    """
    Simultaneously notifies all users across In-App, Facebook (3 pages), and Telegram.
    """
    print("\n" + "=" * 60)
    print(f"🚀 DIFFUSION MULTICANALE : {title}")
    print("=" * 60)

    results = {
        "in_app": False,
        "facebook": False,
        "telegram": False
    }

    # 1. In-App Notification (Instant Realtime)
    results["in_app"] = send_in_app_notification(
        title=title,
        message=in_app_message,
        notif_type=notif_type,
        target_id=target_id,
        metadata={"link": link} if link else None,
        custom_id=custom_id
    )

    # Content for Social Media
    full_social_text = social_message or f"{title}\n\n{in_app_message}\n\n🌐 Disponible sur Medsina : https://medsina.medevsync.com"

    # 2. Facebook (3 Pages)
    fb_res = send_facebook_broadcast(full_social_text, link=link)
    results["facebook"] = bool(fb_res.get("id"))

    # 3. Telegram
    tg_text = f"<b>{title}</b>\n\n{in_app_message}\n\n🌐 <a href='https://medsina.medevsync.com'>Accéder à Medsina Web & Téléchargements</a>"
    tg_res = send_telegram_broadcast_message(tg_text, image_path=image_path)
    results["telegram"] = bool(tg_res.get("success") or tg_res.get("ok"))

    print("\n📊 Bilan de la diffusion :")
    print(f"  - In-App Realtime : {'✅ SUCCÈS' if results['in_app'] else '❌ ÉCHEC'}")
    print(f"  - Facebook (3 Pages) : {'✅ SUCCÈS' if results['facebook'] else 'ℹ️ EN ATTENTE CREDENTIALS'}")
    print(f"  - Telegram Officiel : {'✅ SUCCÈS' if results['telegram'] else 'ℹ️ EN ATTENTE CREDENTIALS'}")
    print("=" * 60 + "\n")

    return results

def main():
    parser = argparse.ArgumentParser(description="Broadcast an announcement in-app, on 3 FB pages, and on Telegram.")
    parser.add_argument("--title", type=str, required=True, help="Notification title")
    parser.add_argument("--message", type=str, required=True, help="Notification body message")
    parser.add_argument("--social", type=str, default=None, help="Specific message for social networks (optional)")
    parser.add_argument("--type", type=str, default="announcement", help="Notification type (course, pearl, cat, announcement)")
    parser.add_argument("--link", type=str, default="https://medsina.medevsync.com", help="External or app link")
    parser.add_argument("--image", type=str, default=None, help="Image path for Telegram/FB")
    parser.add_argument("--id", type=str, default=None, help="Custom ID for in-app deduplication")
    args = parser.parse_args()

    broadcast_all(
        title=args.title,
        in_app_message=args.message,
        social_message=args.social,
        notif_type=args.type,
        link=args.link,
        image_path=args.image,
        custom_id=args.id
    )

if __name__ == "__main__":
    main()

