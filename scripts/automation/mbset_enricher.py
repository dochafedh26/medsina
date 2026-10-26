#!/usr/bin/env python3
"""
Medsina Ultra — MBset High-Yield Principles & Metadata Enricher
===============================================================
Uses MBSetClient to extract high-yield exam principles ('/principles/<subcategory_id>'),
frequent traps, and StudyRec links across Blida modules, persisting them to:
  medsina/assets/data/blida_exam_principles.json
"""

import json
import os
import sys
import time
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parents[3]
MEDSINA_DIR = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT_DIR))

from mbset_client import MBSetClient  # noqa: E402

OUTPUT_JSON = MEDSINA_DIR / "assets" / "data" / "blida_exam_principles.json"


def main():
    limit_categories = int(os.getenv("MBSET_ENRICH_CATEGORY_LIMIT", "3"))
    limit_subcategories = int(os.getenv("MBSET_ENRICH_SUBCATEGORY_LIMIT", "6"))

    client = MBSetClient()
    client.login()
    print(f"[MBsetEnricher] Authenticated as user_id={client.user_id}")

    existing = {}
    if OUTPUT_JSON.exists():
        try:
            existing = json.loads(OUTPUT_JSON.read_text(encoding="utf-8"))
        except Exception:
            existing = {}

    categories = client.get_categories()
    print(f"[MBsetEnricher] Loaded {len(categories)} Blida categories.")

    added_principles = 0
    for cat in categories[:limit_categories]:
        cat_id = cat.get("id") or cat.get("_id")
        cat_name = cat.get("name", "")
        subcats = cat.get("subcategories", [])
        for sub in subcats[:limit_subcategories]:
            sub_id = sub.get("id") or sub.get("_id")
            sub_name = sub.get("name", "")
            if not sub_id or sub_id in existing:
                continue

            principles = client.get_course_principles(sub_id)
            if principles:
                existing[sub_id] = {
                    "categoryId": cat_id,
                    "categoryName": cat_name,
                    "subcategoryId": sub_id,
                    "subcategoryName": sub_name,
                    "principles": principles,
                    "updatedAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                }
                added_principles += len(principles)
                print(f"  + {sub_name}: {len(principles)} principle(s)")
            time.sleep(0.6)

    OUTPUT_JSON.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_JSON.write_text(
        json.dumps(existing, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(
        f"[MBsetEnricher] Saved {len(existing)} enriched courses ({added_principles} new principles) -> {OUTPUT_JSON}"
    )


if __name__ == "__main__":
    main()
