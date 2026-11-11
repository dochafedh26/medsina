#!/usr/bin/env python3
"""
Medsina Ultra — MBset Client & API Adapter
==========================================
Unified API client for MBset (app.mbset.com & api.mbset.com).
Supports:
  - Firebase Authentication (AIzaSyDNKkgXgtCib2ecK8-AMBE4tXBolEkF6-o / bmset-85f8a-e1af4)
  - Modules, categories & courses retrieval (/categories, /fsrs/categories)
  - High-yield exam principles retrieval (/principles/<subcat_id>)
  - Public simulation & quiz test discovery (/tests/<id>, /scoreboard/<id>, @mbset_blida)
  - Extraction of shared Google Drive folders and PDF polycopiés announced by MBset
  - Automatic fallback to verified local cache (modules_catalog_47.json)
"""

import html
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

ROOT_DIR = Path(__file__).resolve().parents[2]


class MBSetClient:
    FIREBASE_API_KEY = os.getenv("MBSET_FIREBASE_KEY", "AIzaSyDNKkgXgtCib2ecK8-AMBE4tXBolEkF6-o")
    FIREBASE_AUTH_URL = f"https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key={FIREBASE_API_KEY}"
    BASE_API_URL = "https://api.mbset.com"
    APP_URL = "https://app.mbset.com"
    DOWNLOAD_URL = "https://download.mbset.com"
    TELEGRAM_CHANNEL_URL = "https://t.me/s/mbset_blida"

    def __init__(
        self,
        email: Optional[str] = None,
        password: Optional[str] = None,
        supabase_url: Optional[str] = None,
        supabase_key: Optional[str] = None,
    ):
        self.email = email or os.getenv("MBSET_EMAIL")
        self.password = password or os.getenv("MBSET_PASSWORD")
        self.supabase_url = supabase_url or os.getenv("SUPABASE_URL", "https://qzfssrhhuorljftpdvjm.supabase.co")
        self.supabase_key = supabase_key or os.getenv("SUPABASE_SERVICE_ROLE_KEY") or os.getenv("SUPABASE_ANON_KEY")

        self.id_token: Optional[str] = None
        self.refresh_token: Optional[str] = None
        self.user_id: Optional[str] = None
        self.token_expiry: float = 0.0
        self.is_authenticated: bool = False

        # Attempt resolving credentials from Supabase if not present in env
        if not self.email and self.supabase_key:
            self._load_credentials_from_supabase()

    def _load_credentials_from_supabase(self) -> None:
        """Loads MBset credentials from admin_system_settings if configured."""
        try:
            req = urllib.request.Request(
                f"{self.supabase_url}/rest/v1/admin_system_settings?setting_key=eq.mbset_credentials&select=setting_value",
                headers={
                    "apikey": self.supabase_key,
                    "Authorization": f"Bearer {self.supabase_key}",
                },
            )
            with urllib.request.urlopen(req, timeout=5) as resp:
                data = json.loads(resp.read().decode("utf-8"))
                if data and data[0].get("setting_value"):
                    raw = json.loads(data[0]["setting_value"])
                    self.email = raw.get("email")
                    self.password = raw.get("password")
        except Exception:
            pass

    def login(self, email: Optional[str] = None, password: Optional[str] = None) -> bool:
        """Logs into MBset using Firebase Authentication."""
        em = email or self.email
        pw = password or self.password

        if not em or not pw:
            print("[MBSetClient] Aucun identifiant fourni. Fonctionnement en mode inspection web public.")
            self.is_authenticated = False
            return False

        payload = {
            "email": em.strip(),
            "password": pw.strip(),
            "returnSecureToken": True,
        }

        req = urllib.request.Request(
            self.FIREBASE_AUTH_URL,
            data=json.dumps(payload).encode("utf-8"),
            headers={"Content-Type": "application/json"},
        )

        try:
            with urllib.request.urlopen(req, timeout=10) as resp:
                res_data = json.loads(resp.read().decode("utf-8"))
                self.id_token = res_data.get("idToken")
                self.refresh_token = res_data.get("refreshToken")
                self.user_id = res_data.get("localId")
                expires_in = int(res_data.get("expiresIn", "3600"))
                self.token_expiry = time.time() + expires_in - 60
                self.is_authenticated = True
                print(f"[MBSetClient] Authentifié avec succès (user_id={self.user_id})")
                return True
        except urllib.error.HTTPError as err:
            err_body = err.read().decode("utf-8", errors="ignore")
            print(f"[MBSetClient] Échec de connexion Firebase ({err.code}): {err_body}")
            self.is_authenticated = False
            return False
        except Exception as e:
            print(f"[MBSetClient] Erreur de connexion: {e}")
            self.is_authenticated = False
            return False

    def _get_auth_headers(self) -> Dict[str, str]:
        headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) MedsinaScanner/1.0",
            "Origin": self.APP_URL,
            "Referer": f"{self.APP_URL}/",
            "Accept": "application/json, text/plain, */*",
        }
        if self.id_token:
            headers["Authorization"] = f"Bearer {self.id_token}"
        return headers

    def get_categories(self) -> List[Dict[str, Any]]:
        """
        Retrieves official modules & subcategories.
        Attempts live API call if authenticated; falls back to modules_catalog_47.json.
        """
        if self.id_token:
            for endpoint in ["/categories", "/fsrs/categories"]:
                url = f"{self.BASE_API_URL}{endpoint}"
                req = urllib.request.Request(url, headers=self._get_auth_headers())
                try:
                    with urllib.request.urlopen(req, timeout=10) as resp:
                        res = json.loads(resp.read().decode("utf-8"))
                        data = res.get("data") if isinstance(res, dict) and "data" in res else res
                        if isinstance(data, list) and len(data) > 0:
                            return data
                except Exception as e:
                    print(f"[MBSetClient] Note: {endpoint} -> {e}")

        # Fallback to local verified catalog
        catalog_path = ROOT_DIR / "assets" / "data" / "modules_catalog_47.json"
        if catalog_path.exists():
            try:
                cat = json.loads(catalog_path.read_text(encoding="utf-8"))
                if isinstance(cat, list):
                    formatted = []
                    for m in cat:
                        formatted.append({
                            "id": m.get("id"),
                            "name": m.get("name"),
                            "questionsCount": m.get("total_questions", 0),
                            "subcategories": [
                                {
                                    "id": c.get("id"),
                                    "name": c.get("name"),
                                    "tag": c.get("tag"),
                                    "questionsCount": c.get("questions_count", 0),
                                    "hasPdf": c.get("has_pdf", True),
                                    "orderIndex": c.get("display_order", 0),
                                }
                                for c in m.get("courses", [])
                            ]
                        })
                    return formatted
            except Exception as e:
                print(f"[MBSetClient] Erreur lecture catalog local: {e}")

        return []

    def get_course_principles(self, subcategory_id: str) -> List[Dict[str, Any]]:
        """
        Retrieves high-yield exam principles for a course (/principles/<subcategory_id>).
        """
        if self.id_token:
            url = f"{self.BASE_API_URL}/principles/{subcategory_id}"
            req = urllib.request.Request(url, headers=self._get_auth_headers())
            try:
                with urllib.request.urlopen(req, timeout=10) as resp:
                    res = json.loads(resp.read().decode("utf-8"))
                    data = res.get("data") if isinstance(res, dict) and "data" in res else res
                    if isinstance(data, list):
                        return data
            except Exception:
                pass

        # Fallback to local principles cache
        principles_path = ROOT_DIR / "assets" / "data" / "blida_exam_principles.json"
        if principles_path.exists():
            try:
                cache = json.loads(principles_path.read_text(encoding="utf-8"))
                if subcategory_id in cache:
                    return cache[subcategory_id].get("principles", [])
            except Exception:
                pass

        return []

    def get_public_simulations_and_announcements(self) -> List[Dict[str, Any]]:
        """
        Extracts public exam simulations, quizzes, scoreboards, and PDF links
        published by MBset on its web portal and official channel.
        """
        discovered: List[Dict[str, Any]] = []

        try:
            req = urllib.request.Request(
                self.TELEGRAM_CHANNEL_URL,
                headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"},
            )
            with urllib.request.urlopen(req, timeout=12) as resp:
                page_html = resp.read().decode("utf-8", errors="ignore")

            # Split into individual message widget blocks
            blocks = re.split(r'(?=<div class="tgme_widget_message\b)', page_html)
            for block in blocks:
                post_match = re.search(r'data-post="([^"]+)"', block)
                if not post_match:
                    continue
                post_id = post_match.group(1)  # e.g., "mbset_blida/494"
                post_url = f"https://t.me/{post_id}"

                text_match = re.search(r'<div class="tgme_widget_message_text[^"]*"[^>]*>(.*?)</div>', block, re.DOTALL)
                if not text_match:
                    continue

                raw_text = text_match.group(1)
                text_clean = re.sub(r"<br\s*/?>", " ", raw_text)
                text_clean = re.sub(r"<[^>]+>", " ", text_clean)
                text_clean = html.unescape(text_clean)
                text_clean = re.sub(r"\s+", " ", text_clean).strip()

                # Extract URLs
                test_links = re.findall(r"https?://app\.mbset\.com/(?:tests|scoreboard)/[a-zA-Z0-9_\-\:]+", block)
                quiz_links = re.findall(r"https?://app\.mbset\.com/practice/[a-zA-Z0-9_\-]+", block)
                drive_links = re.findall(r"https?://drive\.google\.com/(?:file/d/|drive/folders/)[a-zA-Z0-9_\-]+[^\s\"\'<>]*", block)

                if test_links or drive_links or "SIMULATION" in text_clean or "Mise à jour" in text_clean or "Témoignage" in text_clean:
                    main_url = test_links[0] if test_links else (drive_links[0] if drive_links else (quiz_links[0] if quiz_links else post_url))

                    # Determine resource type
                    if drive_links:
                        res_type = "pdf_course" if "file" in drive_links[0] else "drive_folder"
                    elif "SIMULATION" in text_clean or "tests/" in main_url or "scoreboard/" in main_url:
                        res_type = "qcm_exam"
                    else:
                        res_type = "other"

                    # Module detection
                    mod_name = "Médecine Blida"
                    for kw in ["Ophtalmologie", "Infectieuses", "Neurologie", "Cardiologie", "Pneumologie", "Uro-Néphrologie", "Hématologie", "Pédiatrie", "Gastro-Entérologie", "Anatomie"]:
                        if kw.lower() in text_clean.lower():
                            mod_name = kw
                            break

                    title = f"MBset : {mod_name}"
                    if "Témoignage" in text_clean:
                        doc_name = re.search(r"Dr\s+([A-Za-zÀ-ÿ\- ]+)", text_clean)
                        name_str = doc_name.group(1).strip() if doc_name else ""
                        title = f"Témoignage Major MBset : Dr {name_str}" if name_str else "Témoignage Major MBset"
                    elif "SIMULATION" in text_clean:
                        title = f"Simulation Concours MBset : {mod_name}"
                    elif "Mise à jour" in text_clean:
                        title = f"Série QCM MBset Mise à Jour : {mod_name}"

                    discovered.append({
                        "id": f"mbset_tg_{post_id.replace('/', '_')}",
                        "title": title,
                        "resource_type": res_type,
                        "source_type": "mbset_api",
                        "source_origin": "MBset Platform & API (@mbset_blida)",
                        "source_url": main_url,
                        "url": main_url,
                        "suggested_module": mod_name,
                        "ai_summary": text_clean[:320] + ("..." if len(text_clean) > 320 else ""),
                        "status": "pending",
                        "discovered_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                    })
        except Exception as e:
            print(f"[MBSetClient] Erreur scan web MBset: {e}")

        return discovered
