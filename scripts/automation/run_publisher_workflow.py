#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Wrapper sécurisé pour l'exécution du workflow GitHub Actions de publication Facebook & Telegram.
Lit les variables d'environnement (INPUT_*) pour éviter tout problème d'échappement de quotes/apostrophes
dans les titres ou sujets en français (ex: "l'application", "d'urgence", etc.).
"""

import os
import sys
import subprocess
from pathlib import Path

def main():
    script_path = Path(__file__).resolve().parent / "facebook_post_generator.py"
    cmd = [sys.executable, str(script_path)]

    p_type = os.getenv("INPUT_TYPE", "").strip()
    topic = os.getenv("INPUT_TOPIC", "").strip()
    screenshot = os.getenv("INPUT_SCREENSHOT", "").strip()
    mockup_type = os.getenv("INPUT_MOCKUP_TYPE", "").strip()
    dry_run = os.getenv("INPUT_DRY_RUN", "").strip().lower()

    if p_type:
        cmd.extend(["--type", p_type])
    if topic:
        cmd.extend(["--topic", topic])
    if screenshot:
        cmd.extend(["--screenshot", screenshot])
    if mockup_type and mockup_type != "auto":
        cmd.extend(["--mockup-type", mockup_type])
    if dry_run in ("true", "1", "yes"):
        cmd.append("--dry-run")

    print(f"🚀 Lancement sécurisé : {cmd}")
    sys.stdout.flush()
    result = subprocess.run(cmd)
    sys.exit(result.returncode)

if __name__ == "__main__":
    main()

