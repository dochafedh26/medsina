import os
import sys
import requests
import json
import re
from pathlib import Path

try:
    if sys.stdout.encoding.lower() != 'utf-8':
        sys.stdout.reconfigure(encoding='utf-8')
except Exception:
    pass

env_file = Path(__file__).resolve().parents[2] / ".env"
url = "https://qzfssrhhuorljftpdvjm.supabase.co"
key = ""
if env_file.exists():
    content = env_file.read_text(encoding="utf-8")
    m = re.search(r"SUPABASE_SERVICE_ROLE_KEY\s*=\s*['\"]?([^'\"\r\n]+)['\"]?", content)
    if m:
        key = m.group(1).strip()

headers = {
    "apikey": key,
    "Authorization": f"Bearer {key}",
    "Range-Unit": "items",
    "Prefer": "count=exact"
}

tables = [
    "lab_reference_values",
    "on_call_mementos",
    "daily_pearls",
    "clinical_protocols",
    "emergency_drugs",
    "medical_modules",
    "courses",
    "qcm_questions",
    "subscription_plans",
    "system_announcements",
    "payments"
]

print("=" * 65)
print(f"AUDIT DIRECT SUPABASE CLOUD ({url})")
print("=" * 65)

for t in tables:
    try:
        r = requests.get(f"{url}/rest/v1/{t}?select=id", headers=headers, timeout=10)
        if r.status_code in (200, 206):
            items = r.json()
            print(f"✅ {t:<26} : EXISTE ({len(items)} enregistrements)")
        elif r.status_code == 404 or "PGRST205" in r.text:
            print(f"❌ {t:<26} : TABLE NON CRÉÉE SUR LE CLOUD (PGRST205)")
        else:
            print(f"⚠️ {t:<26} : Statut {r.status_code} ({r.text[:80]})")
    except Exception as e:
        print(f"❌ {t:<26} : Erreur connexion ({e})")
