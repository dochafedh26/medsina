#!/usr/bin/env python3
"""
Medsina & MedevSync Facebook Automation Publisher
Allows publishing promotional posts, feature spotlights, and clinical pearls
directly to the official Medevsync Facebook Page using Meta Graph API.
Credentials are automatically retrieved from Supabase admin_system_settings or environment variables.
"""

import os
import sys
import json
import argparse
import urllib.request
import urllib.parse
from typing import Optional, Dict, Any

SUPABASE_URL = os.environ.get("SUPABASE_URL", "https://qzfssrhhuorljftpdvjm.supabase.co")
SUPABASE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY") or os.environ.get("SUPABASE_KEY", "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF6ZnNzcmhodW9ybGpmdHBkdmptIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MTYxMjg1NCwiZXhwIjoyMTA3MTg4ODU0fQ.-KCUgZdY8RDUwvNOUAabDhQFwv5FFGHYz0J-dM7Cic4")


def get_facebook_credentials() -> Dict[str, str]:
    """Retrieves Facebook credentials from environment or Supabase."""
    page_id = os.environ.get("FB_PAGE_ID")
    page_token = os.environ.get("FB_PAGE_ACCESS_TOKEN")

    if not page_id or not page_token:
        try:
            url = f"{SUPABASE_URL}/rest/v1/admin_system_settings?select=setting_key,setting_value"
            req = urllib.request.Request(
                url,
                headers={
                    "apikey": SUPABASE_KEY,
                    "Authorization": f"Bearer {SUPABASE_KEY}",
                }
            )
            with urllib.request.urlopen(req, timeout=10) as resp:
                rows = json.loads(resp.read().decode("utf-8"))
                for row in rows:
                    if row.get("setting_key") == "facebook_page_id" and not page_id:
                        page_id = row.get("setting_value")
                    elif row.get("setting_key") == "facebook_page_access_token" and not page_token:
                        page_token = row.get("setting_value")
        except Exception as e:
            print(f"Warning: Could not fetch Facebook credentials from Supabase: {e}", file=sys.stderr)

    if not page_id or not page_token:
        raise ValueError("Missing Facebook credentials (facebook_page_id or facebook_page_access_token).")

    return {"page_id": page_id.strip(), "page_token": page_token.strip()}


def publish_facebook_post(message: str, link: Optional[str] = None) -> Dict[str, Any]:
    """Publishes a text post (with optional link) to the Facebook page feed."""
    creds = get_facebook_credentials()
    page_id = creds["page_id"]
    token = creds["page_token"]

    url = f"https://graph.facebook.com/v21.0/{page_id}/feed"

    payload = {
        "message": message,
        "access_token": token,
    }
    if link:
        payload["link"] = link

    encoded_data = urllib.parse.urlencode(payload).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=encoded_data,
        method="POST",
        headers={"User-Agent": "MedevSyncPublisher/1.0"},
    )

    with urllib.request.urlopen(req, timeout=20) as resp:
        result = json.loads(resp.read().decode("utf-8"))
        return result


def main():
    parser = argparse.ArgumentParser(description="Publish a post to the official Medevsync Facebook page.")
    parser.add_argument("--message", type=str, required=True, help="Post text content")
    parser.add_argument("--link", type=str, default=None, help="Optional URL to attach to the post")
    args = parser.parse_args()

    print("🚀 Publishing post to Medevsync Facebook Page...")
    try:
        res = publish_facebook_post(args.message, link=args.link)
        post_id = res.get("id")
        print(f"✅ Post published successfully! Post ID: {post_id}")
    except Exception as e:
        print(f"❌ Error publishing post: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()

