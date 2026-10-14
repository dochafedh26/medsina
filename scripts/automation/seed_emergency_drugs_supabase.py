#!/usr/bin/env python3
"""
Medsina Platform - Seed Emergency Drugs into Supabase
Populates public.emergency_drugs with the 55 Algerian emergency hospital drugs.
"""

import os
import sys
import json
from pathlib import Path

try:
    import requests
except ImportError:
    print("Error: requests is required.", file=sys.stderr)
    sys.exit(1)

DEFAULT_SUPABASE_URL = "https://qzfssrhhuorljftpdvjm.supabase.co"
DEFAULT_JSON = Path(__file__).resolve().parents[2] / "assets" / "data" / "emergency_drugs_algeria.json"

def _resolve_supabase_key() -> str:
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY") or os.environ.get("SUPABASE_KEY")
    if key:
        return key
    secrets_file = Path(__file__).resolve().parents[2] / "lib" / "core" / "config" / "app_secrets.dart"
    if secrets_file.exists():
        try:
            import re
            content = secrets_file.read_text(encoding="utf-8")
            m = re.search(r"supabaseServiceKey\s*=\s*['\"]([^'\"]+)['\"]", content)
            if m:
                return m.group(1)
        except Exception:
            pass
    return ""

def seed_emergency_drugs(supabase_url: str, supabase_key: str, json_path: Path):
    if not json_path.exists():
        print(f"File not found: {json_path}", file=sys.stderr)
        sys.exit(1)

    with open(json_path, "r", encoding="utf-8") as f:
        drugs = json.load(f)

    print(f"Loaded {len(drugs)} emergency drugs from {json_path}")
    endpoint = f"{supabase_url.rstrip('/')}/rest/v1/emergency_drugs"
    headers = {
        "apikey": supabase_key,
        "Authorization": f"Bearer {supabase_key}",
        "Content-Type": "application/json",
        "Prefer": "resolution=merge-duplicates"
    }

    resp = requests.post(endpoint, headers=headers, json=drugs, timeout=30)
    if resp.status_code in (200, 201):
        print(f"[OK] Successfully seeded {len(drugs)} drugs into public.emergency_drugs!")
    else:
        print(f"[ERROR] HTTP {resp.status_code}: {resp.text}", file=sys.stderr)

def main():
    url = os.environ.get("SUPABASE_URL", DEFAULT_SUPABASE_URL)
    key = _resolve_supabase_key()
    if not key:
        print("Error: SUPABASE_SERVICE_ROLE_KEY not found.", file=sys.stderr)
        sys.exit(1)
    seed_emergency_drugs(url, key, DEFAULT_JSON)

if __name__ == "__main__":
    main()
