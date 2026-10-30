#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Anti-Duplicate & Anti-Flood Guard for Medsina Multichannel Publishers
====================================================================
Prevents sending identical posts or spamming channels within a cooldown period.
Maintains a local persistent cache in `.published_history.json`.
"""

import os
import json
import time
import hashlib
import re
from pathlib import Path
from typing import Tuple, Dict, Any, Optional

HISTORY_FILE = Path(__file__).resolve().parent / ".published_history.json"


def _normalize_text(text: str) -> str:
    """Removes extra spaces, punctuation and lowercases for fuzzy match comparison."""
    clean = re.sub(r"\s+", " ", text).strip().lower()
    return clean


def _compute_hash(text: str) -> str:
    normalized = _normalize_text(text)
    return hashlib.sha256(normalized.encode("utf-8")).hexdigest()


def _load_history() -> Dict[str, Any]:
    if not HISTORY_FILE.exists():
        return {"publications": []}
    try:
        with open(HISTORY_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return {"publications": []}


def _save_history(data: Dict[str, Any]) -> None:
    try:
        # Keep only the last 150 publications
        data["publications"] = data.get("publications", [])[-150:]
        with open(HISTORY_FILE, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
    except Exception as e:
        print(f"⚠️ [AntiDuplicateGuard] Erreur sauvegarde historique : {e}")


def check_duplicate_or_flood(
    channel_key: str,
    content: str,
    cooldown_minutes: int = 120,
    min_flood_interval_seconds: int = 120,
    force: bool = False,
) -> Tuple[bool, str]:
    """
    Checks if this publication is a duplicate or flood:
    - Returns (True, reason) if it should be blocked.
    - Returns (False, "OK") if allowed.
    """
    if force:
        return False, "Force flag enabled"

    history = _load_history()
    now = time.time()
    current_hash = _compute_hash(content)

    for entry in reversed(history.get("publications", [])):
        if entry.get("channel") != channel_key:
            continue

        entry_time = entry.get("timestamp", 0)
        elapsed_sec = now - entry_time

        # 1. Exact or near-identical duplicate check within cooldown_minutes
        if entry.get("hash") == current_hash:
            if elapsed_sec < cooldown_minutes * 60:
                elapsed_min = int(elapsed_sec / 60)
                msg = f"Message IDENTIQUE déjà publié sur '{channel_key}' il y a {elapsed_min} min (seuil: {cooldown_minutes} min)."
                return True, msg

        # 2. Anti-flood rapid fire check (prevent posting anything within min_flood_interval_seconds)
        if elapsed_sec < min_flood_interval_seconds:
            msg = f"Fréquence trop rapide sur '{channel_key}' (dernier post il y a {int(elapsed_sec)}s, min requis: {min_flood_interval_seconds}s)."
            return True, msg

    return False, "OK"


def record_publication(
    channel_key: str,
    content: str,
    post_id: str,
    metadata: Optional[Dict[str, Any]] = None,
) -> None:
    """Records a successful publication into history."""
    history = _load_history()
    entry = {
        "channel": channel_key,
        "hash": _compute_hash(content),
        "post_id": post_id,
        "preview": content[:100].replace("\n", " "),
        "timestamp": time.time(),
        "date_iso": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "metadata": metadata or {},
    }
    history.setdefault("publications", []).append(entry)
    _save_history(history)
