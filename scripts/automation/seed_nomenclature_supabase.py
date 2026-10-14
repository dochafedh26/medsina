#!/usr/bin/env python3
"""
Medsina Platform - Supabase Seeding Script for Algerian Official Nomenclature
Inserts or upserts the 5,425 registered pharmaceutical products (MSPRH)
into the `public.algerian_nomenclature` table.
"""

import os
import sys
import json
import time
import argparse
from pathlib import Path

try:
    import requests
except ImportError:
    print("Error: requests is required. Run 'pip install requests'.", file=sys.stderr)
    sys.exit(1)

DEFAULT_SUPABASE_URL = "https://qzfssrhhuorljftpdvjm.supabase.co"
DEFAULT_JSON_PATH = Path(__file__).resolve().parents[2] / "assets" / "data" / "algerian_nomenclature.json"

def seed_nomenclature(supabase_url: str, supabase_key: str, json_path: Path, batch_size: int = 150):
    if not json_path.exists():
        print(f"Error: JSON file not found at {json_path}", file=sys.stderr)
        sys.exit(1)

    print(f"Loading nomenclature catalog from: {json_path}")
    with open(json_path, "r", encoding="utf-8") as f:
        drugs = json.load(f)

    total_drugs = len(drugs)
    print(f"Found {total_drugs} drugs in Algerian nomenclature.")

    endpoint = f"{supabase_url.rstrip('/')}/rest/v1/algerian_nomenclature"
    headers = {
        "apikey": supabase_key,
        "Authorization": f"Bearer {supabase_key}",
        "Content-Type": "application/json",
        "Prefer": "resolution=merge-duplicates"
    }

    # Prepare records
    records = []
    for idx, item in enumerate(drugs):
        rec = {
            "id": idx + 1,
            "num": item.get("num") if isinstance(item.get("num"), int) else (idx + 1),
            "reg_num": item.get("regNum") or "",
            "code": item.get("code") or "",
            "dci": item.get("dci") or "",
            "brand_name": item.get("brand") or "",
            "form": item.get("form") or "",
            "dosage": item.get("dosage") or "",
            "packaging": item.get("packaging") or "",
            "liste": item.get("liste") or "",
            "laboratory": item.get("lab") or "",
            "country": item.get("pays") or "",
            "type": item.get("type") or "",
            "status": item.get("status") or "",
            "is_hospital_only": "HOPITAL" in f"{item.get('packaging', '')} {item.get('liste', '')}".upper(),
        }
        records.append(rec)

    # Batch insert/upsert
    inserted = 0
    total_batches = (total_drugs + batch_size - 1) // batch_size
    print(f"Starting upload in {total_batches} batches of {batch_size}...")

    for b in range(total_batches):
        batch = records[b * batch_size : (b + 1) * batch_size]
        try:
            resp = requests.post(endpoint, headers=headers, json=batch, timeout=30)
            if resp.status_code in (200, 201, 204):
                inserted += len(batch)
                print(f"  Batch {b+1}/{total_batches} uploaded successfully ({inserted}/{total_drugs})")
            else:
                print(f"  Error in batch {b+1}: HTTP {resp.status_code} - {resp.text}", file=sys.stderr)
                if "PGRST205" in resp.text:
                    print("\n[CRITICAL]: Table 'public.algerian_nomenclature' does not exist yet.")
                    print("Please run the migration SQL in Supabase SQL Editor:")
                    print("supabase/migrations/20261013000003_algerian_nomenclature.sql\n")
                    sys.exit(1)
        except Exception as e:
            print(f"  Network error in batch {b+1}: {e}", file=sys.stderr)
        time.sleep(0.1)

    print(f"\n[DONE] Successfully seeded {inserted}/{total_drugs} drugs to Supabase!")

def main():
    parser = argparse.ArgumentParser(description="Seed Algerian Nomenclature to Supabase")
    parser.add_argument("--url", default=os.environ.get("SUPABASE_URL", DEFAULT_SUPABASE_URL), help="Supabase project URL")
    parser.add_argument("--key", default=os.environ.get("SUPABASE_SERVICE_ROLE_KEY") or os.environ.get("SUPABASE_KEY", ""), help="Supabase service role or secret key")
    parser.add_argument("--json", default=str(DEFAULT_JSON_PATH), help="Path to nomenclature JSON file")
    parser.add_argument("--batch-size", type=int, default=150, help="Batch size for upserting")

    args = parser.parse_args()

    key = args.key
    if not key:
        print("[!] No Supabase key provided via --key or SUPABASE_SERVICE_ROLE_KEY / SUPABASE_KEY.")
        print("Usage: python seed_nomenclature_supabase.py --key <SERVICE_ROLE_KEY>")
        sys.exit(1)

    seed_nomenclature(args.url, key, Path(args.json), args.batch_size)

if __name__ == "__main__":
    main()

