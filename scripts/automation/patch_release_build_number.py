#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Patch Supabase app_releases table so Android v1.0.77 has build_number 2098,
ensuring ARM64 devices (which have versionCode 2097 on v1.0.76) detect the update.
"""

import os
import sys
import json
import requests

def main():
    url = os.environ.get("SUPABASE_URL", "https://qzfssrhhuorljftpdvjm.supabase.co").rstrip("/")
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")

    if not key:
        print("❌ SUPABASE_SERVICE_ROLE_KEY is required.")
        sys.exit(1)

    headers = {
        "apikey": key,
        "Authorization": f"Bearer {key}",
        "Content-Type": "application/json",
        "Prefer": "return=representation"
    }

    # 1. Update Android 1.0.77 to build_number 2098
    print("Patching Android 1.0.77 build_number to 2098...")
    patch_payload = {
        "build_number": 2098,
        "min_supported_build": 1
    }

    res = requests.patch(
        f"{url}/rest/v1/app_releases?platform=eq.android&version_name=eq.1.0.77",
        headers=headers,
        json=patch_payload
    )

    print(f"PATCH status: {res.status_code}")
    try:
        print(f"PATCH result: {json.dumps(res.json(), indent=2)}")
    except Exception:
        print(f"PATCH text: {res.text}")

    # 2. Verify latest releases
    r = requests.get(
        f"{url}/rest/v1/app_releases?platform=eq.android&is_active=eq.true&order=build_number.desc&limit=3",
        headers=headers
    )
    print("\nVerified latest Android releases in Supabase:")
    print(json.dumps(r.json(), indent=2))

if __name__ == "__main__":
    main()
