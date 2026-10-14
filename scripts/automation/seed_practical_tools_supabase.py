#!/usr/bin/env python3
"""
Medsina Practical Tools Database Seeder
Seeds Lab Reference Values & On-Call Mementos into Supabase Cloud
"""

import os
import sys
import json
import re
from pathlib import Path
from typing import List, Dict, Any

try:
    if sys.stdout.encoding.lower() != "utf-8":
        sys.stdout.reconfigure(encoding="utf-8")
    if sys.stderr.encoding.lower() != "utf-8":
        sys.stderr.reconfigure(encoding="utf-8")
except Exception:
    pass

try:
    import requests
except ImportError:
    print("Error: 'requests' library required. Run 'pip install requests'.", file=sys.stderr)
    sys.exit(1)

PROJECT_ROOT = Path(__file__).resolve().parents[2]
LAB_FILE = PROJECT_ROOT / "assets" / "data" / "lab_reference_values.json"
MEMENTO_FILE = PROJECT_ROOT / "assets" / "data" / "on_call_mementos.json"
ENV_FILE = PROJECT_ROOT / ".env"

DEFAULT_SUPABASE_URL = "https://qzfssrhhuorljftpdvjm.supabase.co"

def get_supabase_creds():
    url = os.environ.get("SUPABASE_URL", DEFAULT_SUPABASE_URL).rstrip("/")
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY") or os.environ.get("SUPABASE_KEY")
    
    if not key and ENV_FILE.exists():
        try:
            content = ENV_FILE.read_text(encoding="utf-8")
            m_key = re.search(r"SUPABASE_SERVICE_ROLE_KEY\s*=\s*['\"]?([^'\"\r\n]+)['\"]?", content)
            if m_key:
                key = m_key.group(1).strip()
            m_url = re.search(r"SUPABASE_URL\s*=\s*['\"]?([^'\"\r\n]+)['\"]?", content)
            if m_url:
                url = m_url.group(1).strip().rstrip("/")
        except Exception:
            pass

    return url, key

def seed_table(url: str, key: str, table: str, items: List[Dict[str, Any]]) -> int:
    headers = {
        "apikey": key,
        "Authorization": f"Bearer {key}",
        "Content-Type": "application/json",
        "Prefer": "resolution=merge-duplicates,return=representation",
    }

    success_count = 0
    print(f"\nSeeding {len(items)} records into '{table}'...")

    for item in items:
        item_id = item.get("id") or item.get("name") or item.get("title")
        try:
            r = requests.post(
                f"{url}/rest/v1/{table}",
                headers=headers,
                json=item,
                timeout=20,
            )
            if r.status_code in (200, 201):
                success_count += 1
                name_disp = item.get("name") or item.get("title") or item_id
                print(f"  [OK] {name_disp}")
            else:
                print(f"  [FAIL] {item_id}: ({r.status_code}) {r.text[:200]}")
        except Exception as e:
            print(f"  [ERROR] {item_id}: {e}")

    return success_count

def main():
    print("=" * 65)
    print("Medsina Seeder : Normes Biologiques & Mémentos de Garde")
    print("=" * 65)

    url, key = get_supabase_creds()
    if not key:
        print("ERROR: SUPABASE_SERVICE_ROLE_KEY not found in environment or .env file.", file=sys.stderr)
        sys.exit(1)

    print(f"Target Supabase URL : {url}")

    # 1. Seed Lab Reference Values
    if LAB_FILE.exists():
        try:
            labs = json.loads(LAB_FILE.read_text(encoding="utf-8"))
            lab_success = seed_table(url, key, "lab_reference_values", labs)
            print(f"\n=> Seeded {lab_success}/{len(labs)} Lab Reference Values successfully.")
        except Exception as e:
            print(f"Error reading {LAB_FILE.name}: {e}")
    else:
        print(f"File not found: {LAB_FILE}")

    # 2. Seed On-Call Mementos
    if MEMENTO_FILE.exists():
        try:
            mementos = json.loads(MEMENTO_FILE.read_text(encoding="utf-8"))
            memento_success = seed_table(url, key, "on_call_mementos", mementos)
            print(f"\n=> Seeded {memento_success}/{len(mementos)} On-Call Mementos successfully.")
        except Exception as e:
            print(f"Error reading {MEMENTO_FILE.name}: {e}")
    else:
        print(f"File not found: {MEMENTO_FILE}")

    print("\nSeeding finished.")

if __name__ == "__main__":
    main()
