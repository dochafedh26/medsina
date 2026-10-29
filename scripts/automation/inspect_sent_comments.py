import sys
import asyncio
from telethon import TelegramClient

if sys.stdout and hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

SESSION_FILE = "scripts/automation/medsina_user.session"
API_ID = 21218217
API_HASH = "f447a9ada0587a064cd7d3e70c7852da"

async def check():
    client = TelegramClient(SESSION_FILE, API_ID, API_HASH)
    await client.connect()

    entity = await client.get_entity(-1004362488515)
    title = getattr(entity, "title", "No Title")
    username = getattr(entity, "username", None)

    print("=" * 60)
    print("📍 DÉTAILS DU GROUPE / CANAL TELEGRAM OÙ LE MESSAGE A ÉTÉ POSTÉ :")
    print(f"📌 Titre : {title}")
    if username:
        print(f"🔗 Lien public : https://t.me/{username}")
    else:
        print(f"🆔 ID Canal : {entity.id}")
    print("=" * 60)

    print("\n📩 DERNIERS MESSAGES DU FIL DE DISCUSSION :")
    async for m in client.iter_messages(entity, limit=5):
        sender = getattr(m.sender, "first_name", "Anonyme") if m.sender else "Canal"
        print(f"\n[Message #{m.id}] Envoyé par: {sender} (le {m.date})")
        print(f"Texte: {m.message}")

    await client.disconnect()

if __name__ == "__main__":
    asyncio.run(check())

