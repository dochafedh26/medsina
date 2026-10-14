#!/usr/bin/env python3
"""
Medsina Platform - Seed Vidal Terrain Contraindications into Supabase
Populates public.vidal_terrain_contraindications with initial verified clinical rules.
"""

import os
import sys
import json
import argparse
from pathlib import Path

try:
    import requests
except ImportError:
    print("Error: requests is required.", file=sys.stderr)
    sys.exit(1)

DEFAULT_SUPABASE_URL = "https://qzfssrhhuorljftpdvjm.supabase.co"
DEFAULT_JSON = Path(__file__).resolve().parents[2] / "assets" / "data" / "vidal_terrain_contraindications.json"

def seed_terrain_contraindications(supabase_url: str, supabase_key: str, json_path: Path):
    if not json_path.exists():
        print(f"File not found: {json_path}", file=sys.stderr)
        sys.exit(1)

    with open(json_path, "r", encoding="utf-8") as f:
        rules = json.load(f)

    print(f"Loaded {len(rules)} terrain contraindication rules from {json_path}")
    endpoint = f"{supabase_url.rstrip('/')}/rest/v1/vidal_terrain_contraindications"
    headers = {
        "apikey": supabase_key,
        "Authorization": f"Bearer {supabase_key}",
        "Content-Type": "application/json",
        "Prefer": "return=representation"
    }

    records = []
    for r in rules:
        records.append({
            "terrain": r.get("terrain", ""),
            "terrain_normalized": r.get("terrain_normalized", ""),
            "drug_class": r.get("drug_class", ""),
            "drug_patterns": r.get("drug_patterns", []),
            "severity": r.get("severity", "info"),
            "severity_level": r.get("severity_level", 1),
            "title": r.get("title", ""),
            "warning": r.get("warning", ""),
            "recommendation": r.get("recommendation", ""),
            "source": r.get("source", "Vidal / ANSM / MSPRH")
        })

    resp = requests.post(endpoint, headers=headers, json=records, timeout=30)
    if resp.status_code in (200, 201):
        print(f"[OK] Successfully seeded {len(records)} rules into public.vidal_terrain_contraindications!")
    else:
        print(f"[ERROR] HTTP {resp.status_code}: {resp.text}", file=sys.stderr)

def main():
    parser = argparse.ArgumentParser(description="Seed Vidal terrain contraindications to Supabase")
    parser.add_argument("--url", default=os.environ.get("SUPABASE_URL", DEFAULT_SUPABASE_URL))
    parser.add_argument("--key", default=os.environ.get("SUPABASE_SERVICE_ROLE_KEY") or os.environ.get("SUPABASE_KEY", ""))
    parser.add_argument("--json", default=str(DEFAULT_JSON))

    args = parser.parse_args()
    key = args.key or "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF6ZnNzcmhodW9ybGpmdHBkdmptIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MTYxMjg1NCwiZXhwIjoyMTA3MTg4ODU0fQ.-KCUgZdY8RDUwvNOUAabDhQFwv5FFGHYz0J-dM7Cic4"

    seed_terrain_contraindications(args.url, key, Path(args.json))

if __name__ == "__main__":
    main()

