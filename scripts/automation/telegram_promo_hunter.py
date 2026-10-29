#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Telegram Promo Hunter & Medical Community Assistant (Option B)
==============================================================
Uses Telegram MTProto Client (Telethon) with user credentials:
- api_id: 21218217
- api_hash: f447a9ada0587a064cd7d3e70c7852da

Capabilities:
1. Global & Target Chat Search for Algerian medical & résidanat discussions.
2. Contextual AI/Template Assistance: Answers medical questions & recommends Medsina.
3. Anti-Spam & Safe Delays: Respects Telegram rate-limits and flood-wait policies.
4. History tracking: Never replies twice to the same post/message.
"""

import os
import sys
import json
import time
import asyncio
from pathlib import Path
from typing import List, Dict, Any, Optional

if sys.stdout and hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

from telethon import TelegramClient, functions, types
from telethon.errors import (
    FloodWaitError,
    PeerFloodError,
    UserDeactivatedBanError,
    SessionPasswordNeededError,
    ChatWriteForbiddenError,
    ChatAdminRequiredError,
    UserBannedInChannelError,
)

# -------------------------------------------------------------
# CONFIGURATION & CREDENTIALS
# -------------------------------------------------------------
API_ID = 21218217
API_HASH = "f447a9ada0587a064cd7d3e70c7852da"

SCRIPT_DIR = Path(__file__).resolve().parent
SESSION_FILE = SCRIPT_DIR / "medsina_user.session"
PROCESSED_DB_FILE = SCRIPT_DIR / "telegram_hunter_processed.json"

OFFICIAL_LINKS = {
    "web": "https://medsina.medevsync.com",
    "apk": "https://medsina.medevsync.com/download/medsina.apk",
    "win": "https://medsina.medevsync.com/download/medsina-setup.exe",
    "channel": "https://t.me/medsina_officiel",
}

MEDICAL_KEYWORDS = [
    "résidanat",
    "residanat",
    "concours blanc",
    "annales médecine",
    "qcm cardiologie",
    "vidal algérie",
    "mémento urgences",
    "sujets résidanat",
    "cours externat",
    "guide posologie",
    "cas clinique",
    "drive médecine",
]

TARGET_CHANNELS_GROUPS = [
    "residanat_algerie",
    "medecine_algerie",
    "residanat_blida",
    "externat_medecine",
    "qcm_medecine",
]


def load_processed_ids() -> set:
    if PROCESSED_DB_FILE.exists():
        try:
            with open(PROCESSED_DB_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
                return set(data.get("processed_ids", []))
        except Exception:
            return set()
    return set()


def save_processed_id(msg_id: str):
    processed = load_processed_ids()
    processed.add(str(msg_id))
    with open(PROCESSED_DB_FILE, "w", encoding="utf-8") as f:
        json.dump({"processed_ids": list(processed), "updated_at": time.time()}, f, indent=2)


def generate_helpful_reply(context_text: str) -> str:
    """
    Generates a courteous, highly-relevant answer with official Medsina links.
    """
    context_lower = context_text.lower()

    if "hors ligne" in context_lower or "offline" in context_lower or "internet" in context_lower or "garde" in context_lower:
        return (
            "Bonjour confrère ! 👋 Si tu cherches à réviser sans connexion à l'hôpital ou aux urgences, "
            "la nouvelle version de **Medsina (v1.0.26)** intègre justement un **Mode 100% Hors-Ligne** "
            "avec téléchargement de modules complets et synchronisation cloud automatique dès le retour du Wi-Fi.\n\n"
            f"📱 **Android (APK)** : {OFFICIAL_LINKS['apk']}\n"
            f"💻 **Windows (PC)** : {OFFICIAL_LINKS['win']}\n"
            f"🌐 **Web Direct** : {OFFICIAL_LINKS['web']}\n"
            "Bon courage pour tes gardes et révisions ! 🩺"
        )

    if "qcm" in context_lower or "annale" in context_lower or "concours" in context_lower or "résidanat" in context_lower:
        return (
            "Salut ! 🩺 Pour préparer le concours de Résidanat avec les annales officielles (Alger, Blida, Constantine, Oran) "
            "classées par module et cours avec explications détaillées et pièges fréquents, "
            "tu peux jeter un œil à la plateforme **Medsina** :\n\n"
            "✨ *Plus de 1 200 cours structurés, 47 modules, mode concours blanc et flashcards FSRS intégrées.*\n"
            f"🌐 **Plateforme Web** : {OFFICIAL_LINKS['web']}\n"
            f"📲 **Application Android (.apk)** : {OFFICIAL_LINKS['apk']}\n"
            f"🖥️ **Version PC (.exe)** : {OFFICIAL_LINKS['win']}\n"
            "Excellente préparation à toi !"
        )

    if "vidal" in context_lower or "médicament" in context_lower or "ordonnance" in context_lower or "posologie" in context_lower:
        return (
            "Bonjour ! 💊 Si tu as besoin d'un analyseur d'ordonnances et d'une base pharmacologique adaptée à la pratique en Algérie, "
            "**Medsina** inclut un module d'analyse d'ordonnances, détection d'interactions médicamenteuses et vérification de posologies en 1 clic.\n\n"
            f"👉 Accès immédiat : {OFFICIAL_LINKS['web']}\n"
            f"👉 Téléchargement APK : {OFFICIAL_LINKS['apk']}"
        )

    # General supportive answer
    return (
        "Bonjour confrère ! 🩺 Pour tes révisions médicales et la préparation du concours, "
        "découvre **Medsina**, la plateforme médicale globale algérienne (Cours, QCMs d'annales corrigés, Mémento de garde & Mode Hors-Ligne) :\n\n"
        f"🔗 **Accès Web** : {OFFICIAL_LINKS['web']}\n"
        f"📱 **Application Mobile** : {OFFICIAL_LINKS['apk']}\n"
        f"📢 **Canal Officiel** : {OFFICIAL_LINKS['channel']}"
    )


async def search_and_assist(client: TelegramClient, dry_run: bool = True, max_replies: int = 3):
    """
    Searches for relevant discussions and optionally posts helpful comments.
    """
    processed = load_processed_ids()
    print("🔍 Démarrage de la recherche de discussions médicales ciblées...")

    found_posts = []

    for kw in MEDICAL_KEYWORDS[:5]:
        print(f"   🔎 Recherche du mot-clé : '{kw}'...")
        try:
            # Search messages globally or in public chats
            result = await client(functions.messages.SearchGlobalRequest(
                q=kw,
                filter=types.InputMessagesFilterEmpty(),
                min_date=None,
                max_date=None,
                offset_rate=0,
                offset_peer=types.InputPeerEmpty(),
                offset_id=0,
                limit=10
            ))

            for msg in result.messages:
                if not isinstance(msg, types.Message) or not msg.message:
                    continue

                unique_id = f"{getattr(msg.peer_id, 'channel_id', getattr(msg.peer_id, 'chat_id', 'unknown'))}_{msg.id}"
                if unique_id in processed:
                    continue

                uname = None
                chat_title = "Discussion Médicale"
                try:
                    ent = await client.get_entity(msg.peer_id)
                    chat_title = getattr(ent, "title", getattr(ent, "first_name", "Discussion"))
                    uname = getattr(ent, "username", None)
                except Exception:
                    pass

                post_url = f"https://t.me/{uname}/{msg.id}" if uname else f"https://t.me/c/{getattr(msg.peer_id, 'channel_id', getattr(msg.peer_id, 'chat_id', ''))}/{msg.id}"

                found_posts.append({
                    "unique_id": unique_id,
                    "peer_id": msg.peer_id,
                    "msg_id": msg.id,
                    "chat_title": chat_title,
                    "post_url": post_url,
                    "text": msg.message[:150],
                    "full_text": msg.message,
                    "date": str(msg.date),
                })
        except FloodWaitError as e:
            print(f"⚠️ Telegram FloodWait: pause nécessaire de {e.seconds}s")
            await asyncio.sleep(e.seconds + 2)
        except Exception as e:
            print(f"ℹ️ Erreur recherche '{kw}': {e}")

    print(f"\n📊 Total trouvé : {len(found_posts)} messages pertinents récents.")

    replied_count = 0
    for post in found_posts:
        if replied_count >= max_replies:
            break

        print(f"\n🎯 [Candidat #{replied_count+1}]")
        print(f"   Canal / Groupe : {post.get('chat_title')}")
        print(f"   Lien Direct : {post.get('post_url')}")
        print(f"   Date : {post['date']}")
        print(f"   Extrait : {post['text']}...")

        reply_text = generate_helpful_reply(post["full_text"])

        if dry_run:
            print("   [DRY-RUN] Réponse préparée :")
            print("   " + "\n   ".join(reply_text.splitlines()[:3]) + "...")
            save_processed_id(post["unique_id"])
            replied_count += 1
        else:
            try:
                print("   🚀 Envoi de la réponse contextuelle...")
                try:
                    # If it's a broadcast channel with discussion thread: comment_to
                    await client.send_message(
                        entity=post["peer_id"],
                        message=reply_text,
                        comment_to=post["msg_id"],
                        link_preview=True
                    )
                except Exception:
                    # Standard group / supergroup reply
                    await client.send_message(
                        entity=post["peer_id"],
                        message=reply_text,
                        reply_to=post["msg_id"],
                        link_preview=True
                    )

                print("   ✅ Réponse publiée avec succès !")
                save_processed_id(post["unique_id"])
                replied_count += 1

                # Crucial Anti-Spam Delay: 3 to 5 minutes between comments
                delay = 180
                print(f"   ⏳ Pause anti-flood de {delay} secondes avant le prochain message...")
                await asyncio.sleep(delay)

            except PeerFloodError:
                print("❌ Attention: Telegram signale trop de requêtes (PeerFlood). Arrêt préventif du script.")
                break
            except (ChatWriteForbiddenError, ChatAdminRequiredError, UserBannedInChannelError) as e:
                print(f"ℹ️ Écriture non autorisée dans ce canal/groupe ({e}), message ignoré.")
                save_processed_id(post["unique_id"])
            except Exception as e:
                print(f"⚠️ Échec lors de la réponse: {e}")
                save_processed_id(post["unique_id"])

    print(f"\n🏁 Session terminée. {replied_count} message(s) traités.")


async def main():
    import argparse
    parser = argparse.ArgumentParser(description="Medsina Telegram Promo Hunter (Option B)")
    parser.add_argument("--auth", action="store_true", help="Authentifier le compte Telegram une première fois")
    parser.add_argument("--phone", type=str, help="Numéro de téléphone au format international (+213...)")
    parser.add_argument("--code", type=str, help="Code de vérification reçu par Telegram")
    parser.add_argument("--password", type=str, help="Mot de passe 2FA (si activé)")
    parser.add_argument("--dry-run", action="store_true", default=False, help="Mode simulation sans envoi de message")
    parser.add_argument("--live", action="store_true", default=False, help="Mode réel (envoi de messages)")
    parser.add_argument("--max", type=int, default=3, help="Nombre max de réponses par session")
    args = parser.parse_args()

    client = TelegramClient(str(SESSION_FILE), API_ID, API_HASH)

    if args.auth:
        await client.connect()
        if not await client.is_user_authorized():
            if not args.phone:
                print("❌ Erreur : veuillez fournir votre numéro avec --phone +213xxxxxxxxx")
                return
            if not args.code:
                print(f"📲 Envoi de la demande de code pour {args.phone}...")
                sent = await client.send_code_request(args.phone)
                print(f"✅ Code envoyé par Telegram ! Relancez avec: python telegram_promo_hunter.py --auth --phone {args.phone} --code <VOTRE_CODE>")
                with open(SCRIPT_DIR / "phone_code_hash.txt", "w") as f:
                    f.write(f"{args.phone}:{sent.phone_code_hash}")
                return
            else:
                phone_hash_file = SCRIPT_DIR / "phone_code_hash.txt"
                phone_code_hash = None
                if phone_hash_file.exists():
                    p, phone_code_hash = phone_hash_file.read_text().split(":", 1)
                try:
                    await client.sign_in(args.phone, args.code, phone_code_hash=phone_code_hash)
                    print("🎉 AUTHENTIFICATION TELEGRAM RÉUSSIE ! Session enregistrée.")
                except SessionPasswordNeededError:
                    if args.password:
                        await client.sign_in(password=args.password)
                        print("🎉 AUTHENTIFICATION 2FA RÉUSSIE ! Session enregistrée.")
                    else:
                        print("🔐 Mot de passe de double authentification (2FA) requis.")
                except Exception as e:
                    if "password" in str(e).lower() and args.password:
                        await client.sign_in(password=args.password)
                        print("🎉 AUTHENTIFICATION 2FA RÉUSSIE ! Session enregistrée.")
                    else:
                        print(f"❌ Erreur d'authentification: {e}")
        else:
            me = await client.get_me()
            print(f"✅ Déjà authentifié en tant que : {me.first_name} (@{me.username or me.phone})")
        await client.disconnect()
        return

    # Normal execution
    await client.connect()
    if not await client.is_user_authorized():
        print("❌ Session non authentifiée.")
        print("👉 Veuillez initialiser l'authentification avec :")
        print("   python telegram_promo_hunter.py --auth --phone +213xxxxxxxxx")
        await client.disconnect()
        return

    me = await client.get_me()
    print(f"👤 Connecté en tant que : {me.first_name} (ID: {me.id})")

    is_dry = not args.live or args.dry_run
    await search_and_assist(client, dry_run=is_dry, max_replies=args.max)
    await client.disconnect()


if __name__ == "__main__":
    asyncio.run(main())

