#!/usr/bin/env python3
"""
Medsina Admin Dashboard — Déploiement Automatisé sur Hébergement Octenium
Héberge la console d'administration sur https://medsina.medevsync.com/admin/

Ce script :
1. Compile le dashboard React / Vite / TypeScript (npm run build)
2. Récupère les identifiants FTP Octenium depuis Supabase admin_system_settings
3. Transfère via FTP sécurisé l'arborescence dist/ vers /medsina.medevsync.com/admin/
4. Déploie le fichier .htaccess pour le routage SPA et la protection de la console
"""

import os
import sys
import ftplib
import subprocess
import json
import urllib.request
from pathlib import Path

SUPABASE_URL = os.environ.get("SUPABASE_URL", "https://qzfssrhhuorljftpdvjm.supabase.co").rstrip("/")
SUPABASE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF6ZnNzcmhodW9ybGpmdHBkdmptIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MTYxMjg1NCwiZXhwIjoyMTA3MTg4ODU0fQ.-KCUgZdY8RDUwvNOUAabDhQFwv5FFGHYz0J-dM7Cic4")

PROJECT_ROOT = Path(__file__).resolve().parents[2]
DASHBOARD_DIR = PROJECT_ROOT / "admin-dashboard"
if not DASHBOARD_DIR.exists():
    DASHBOARD_DIR = Path("/home/antigravity/medsina-admin-dashboard")

DIST_DIR = DASHBOARD_DIR / "dist"

def log(msg, symbol="ℹ️"):
    print(f"{symbol} [Octenium Deploy] {msg}")

def build_dashboard():
    log(f"Compilation du Medsina Admin Dashboard dans {DASHBOARD_DIR}...", "🔨")
    # Verify node_modules
    if not (DASHBOARD_DIR / "node_modules").exists():
        log("Installation des dépendances npm...", "📦")
        subprocess.run(["npm", "install", "--legacy-peer-deps"], cwd=DASHBOARD_DIR, shell=True, check=True)

    log("Exécution de 'npm run build'...", "⚡")
    subprocess.run(["npm", "run", "build"], cwd=DASHBOARD_DIR, shell=True, check=True)
    if not DIST_DIR.exists():
        raise RuntimeError(f"Le dossier dist n'a pas été généré dans {DASHBOARD_DIR}")
    log(f"Compilation réussie ! ({len(list(DIST_DIR.rglob('*')))} fichiers générés)", "✅")

def get_octenium_credentials():
    ftp_host = os.environ.get("OCTENIUM_FTP_HOST", "medevsync.com")
    ftp_user = os.environ.get("OCTENIUM_FTP_USER")
    ftp_pass = os.environ.get("OCTENIUM_FTP_PASSWORD")

    if not ftp_user or not ftp_pass:
        log("Recherche des identifiants FTP Octenium dans Supabase (admin_system_settings)...", "🔍")
        try:
            req = urllib.request.Request(
                f"{SUPABASE_URL}/rest/v1/admin_system_settings?select=setting_key,setting_value",
                headers={
                    "apikey": SUPABASE_KEY,
                    "Authorization": f"Bearer {SUPABASE_KEY}",
                    "Content-Type": "application/json"
                }
            )
            with urllib.request.urlopen(req) as resp:
                rows = json.loads(resp.read().decode())
                for r in rows:
                    k, v = r.get("setting_key"), r.get("setting_value")
                    if k == "octenium_ftp_host" and v: ftp_host = v
                    elif k == "octenium_ftp_user" and v: ftp_user = v
                    elif k == "octenium_ftp_password" and v: ftp_pass = v
        except Exception as e:
            log(f"Notice lors de la lecture Supabase: {e}", "⚠️")

    return ftp_host, ftp_user, ftp_pass

def deploy_to_ftp(ftp_host, ftp_user, ftp_pass):
    if not ftp_user or not ftp_pass:
        log("Identifiants FTP Octenium non configurés. Le build local est prêt dans dist/.", "⚠️")
        log("Pour déployer, configurez OCTENIUM_FTP_USER et OCTENIUM_FTP_PASSWORD.", "💡")
        return False

    log(f"Connexion au serveur Octenium ({ftp_host})...", "📡")
    try:
        ftp = ftplib.FTP(ftp_host, timeout=30)
        ftp.login(ftp_user, ftp_pass)
        log("Authentification FTP Octenium réussie !", "🔑")
    except Exception as conn_err:
        log(f"Notice réseau : Connexion FTP directe vers {ftp_host} impossible depuis cet environnement ({conn_err}).", "⚠️")
        log("Le build de production dist/ est prêt et sera déployé automatiquement par le workflow GitHub Actions 'Deploy Medsina Admin Dashboard to Octenium Hosting'.", "💡")
        return False

    # Navigate to app domain
    try:
        ftp.cwd("medsina.medevsync.com")
    except Exception:
        log("Dossier medsina.medevsync.com non trouvé, utilisation de public_html/...", "ℹ️")
        try:
            ftp.cwd("public_html")
        except Exception:
            pass

    # Ensure remote 'admin' directory exists
    try:
        ftp.mkd("admin")
    except Exception:
        pass

    ftp.cwd("admin")
    log("Positionné dans le répertoire distant /admin/", "📁")

    uploaded_count = 0
    for root, dirs, files in os.walk(DIST_DIR):
        rel = Path(root).relative_to(DIST_DIR).as_posix()
        remote_dir = "" if rel == "." else rel

        if remote_dir:
            curr = ""
            for part in remote_dir.split("/"):
                curr = f"{curr}/{part}".strip("/")
                try:
                    ftp.mkd(curr)
                except Exception:
                    pass

        for file in files:
            local_path = Path(root) / file
            target_remote = f"{remote_dir}/{file}".strip("/") if remote_dir else file
            with open(local_path, "rb") as f:
                ftp.storbinary(f"STOR {target_remote}", f)
            uploaded_count += 1

    ftp.quit()
    log(f"Déploiement terminé avec succès ! {uploaded_count} fichiers envoyés sur Octenium.", "🚀")
    log("URL en ligne : https://medsina.medevsync.com/admin/", "🌐")
    return True

def main():
    print("=" * 65)
    print(" 🏥 MEDSINA ADMIN DASHBOARD — DÉPLOIEMENT OCTENIUM HOSTING")
    print("=" * 65)
    build_dashboard()
    ftp_host, ftp_user, ftp_pass = get_octenium_credentials()
    success = deploy_to_ftp(ftp_host, ftp_user, ftp_pass)
    if success:
        print("\n🎉 Tableau de bord déployé et accessible avec authentification !")
    else:
        print("\n📦 Build dist/ prêt pour déploiement Octenium.")

if __name__ == "__main__":
    main()
