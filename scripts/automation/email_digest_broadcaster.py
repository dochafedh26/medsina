#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
=============================================================================
MEDSINA - RECAPITULATIF HEBDOMADAIRE & NOTIFICATIONS EMAIL AUX MEDECINS
=============================================================================
Génère et envoie la Newsletter Médicale Medsina / Digest des Nouveautés
à l'ensemble des candidats et médecins inscrits :
- Nouveaux cours officiels et polycopiés indexés
- Nouvelles fiches résumées & livrets PDF de concours
- Perle clinique & piège de concours de la semaine
- Accès direct via bouton vers l'application Medsina
=============================================================================
"""

import os
import sys
import json
import time
import argparse
import requests
from pathlib import Path
from typing import List, Dict, Any, Optional

if sys.stdout and hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

SCRIPT_DIR = Path(__file__).resolve().parent
MEDSINA_DIR = SCRIPT_DIR.parents[1]
ASSETS_DIR = MEDSINA_DIR / "assets"

SUPABASE_URL = os.environ.get("SUPABASE_URL", "https://qzfssrhhuorljftpdvjm.supabase.co")
SERVICE_ROLE_KEY = os.environ.get(
    "SUPABASE_SERVICE_ROLE_KEY",
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF6ZnNzcmhodW9ybGpmdHBkdmptIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MTYxMjg1NCwiZXhwIjoyMTA3MTg4ODU0fQ.-KCUgZdY8RDUwvNOUAabDhQFwv5FFGHYz0J-dM7Cic4"
)

def get_headers():
    return {
        "apikey": SERVICE_ROLE_KEY,
        "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
        "Content-Type": "application/json"
    }

def fetch_recent_additions(limit: int = 5) -> List[Dict[str, Any]]:
    """Récupère les derniers cours ou résumés ajoutés récemment."""
    url = f"{SUPABASE_URL}/rest/v1/courses?select=id,name,module_id,pdf_url,created_at&order=created_at.desc&limit={limit}"
    try:
        r = requests.get(url, headers=get_headers(), timeout=10)
        if r.status_code == 200:
            return r.json()
    except Exception as e:
        print(f"⚠️ Erreur lors de la récupération des cours récents : {e}")
    return []

def fetch_latest_daily_pearl() -> Optional[Dict[str, Any]]:
    """Récupère la dernière perle clinique pour enrichir le digest."""
    url = f"{SUPABASE_URL}/rest/v1/daily_pearls?select=id,title,content,course_name,module_name&order=created_at.desc&limit=1"
    try:
        r = requests.get(url, headers=get_headers(), timeout=10)
        if r.status_code == 200 and r.json():
            return r.json()[0]
    except Exception:
        pass
    return None

def fetch_doctor_recipients() -> List[Dict[str, Any]]:
    """Récupère la liste des médecins et étudiants inscrits."""
    url = f"{SUPABASE_URL}/rest/v1/profiles?select=id,email,full_name,medical_role,faculty"
    try:
        r = requests.get(url, headers=get_headers(), timeout=10)
        if r.status_code == 200:
            profiles = r.json()
            # Filtre pour emails valides
            return [p for p in profiles if p.get("email") and "@" in p["email"]]
    except Exception as e:
        print(f"⚠️ Erreur récupération profils : {e}")
    return []

def build_email_digest_html(
    doctor_name: str,
    recent_courses: List[Dict[str, Any]],
    pearl: Optional[Dict[str, Any]] = None
) -> str:
    """Construit un e-mail HTML responsive et moderne."""
    courses_html = ""
    for c in recent_courses:
        c_name = c.get("name", "Nouveau cours")
        c_mod = c.get("module_id", "Médecine")
        courses_html += f"""
        <div style="background: #F8FAFC; border: 1px solid #E2E8F0; border-radius: 10px; padding: 14px; margin-bottom: 10px;">
          <div style="font-size: 11px; font-weight: 700; color: #0D9488; text-transform: uppercase; letter-spacing: 0.5px;">Module : {c_mod}</div>
          <div style="font-size: 15px; font-weight: 700; color: #0F172A; margin: 4px 0 2px 0;">{c_name}</div>
          <div style="font-size: 12px; color: #64748B;">Polycopié officiel assaini • Fiche synthèse & QCMs associés</div>
        </div>
        """

    pearl_html = ""
    if pearl:
        pearl_title = pearl.get("title", "Piège de Concours")
        pearl_course = pearl.get("course_name", "Clinique")
        pearl_content = pearl.get("content", "")
        if len(pearl_content) > 180:
            pearl_content = pearl_content[:180] + "..."
        pearl_html = f"""
        <div style="background: #FEF3C7; border-left: 4px solid #D97706; border-radius: 8px; padding: 16px; margin: 20px 0;">
          <div style="font-size: 12px; font-weight: 800; color: #B45309; text-transform: uppercase;">💡 Perle Clinique & Piège Concours ({pearl_course})</div>
          <div style="font-size: 14px; font-weight: 700; color: #78350F; margin: 6px 0;">{pearl_title}</div>
          <div style="font-size: 13px; color: #92400E; line-height: 1.4;">{pearl_content}</div>
        </div>
        """

    html = f"""<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Medsina - Nouveautés & Récapitulatif Médical</title>
</head>
<body style="margin: 0; padding: 0; background-color: #F1F5F9; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;">
  <div style="max-width: 600px; margin: 30px auto; background: #FFFFFF; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 20px rgba(0,0,0,0.06);">
    <!-- Header -->
    <div style="background: #0B132B; padding: 32px 24px; text-align: center;">
      <div style="display: inline-block; background: linear-gradient(135deg, #0D9488, #0EA5E9); border-radius: 10px; padding: 8px 12px; color: white; font-size: 20px; font-weight: 900; letter-spacing: -0.5px;">
        ⚕️ MEDSINA ULTRA
      </div>
      <div style="color: #94A3B8; font-size: 12px; font-weight: 700; letter-spacing: 1.5px; text-transform: uppercase; margin-top: 8px;">
        Concours Résidanat 2027 & Faculté de Médecine de Blida
      </div>
    </div>

    <!-- Body -->
    <div style="padding: 32px 28px;">
      <h2 style="color: #0F172A; font-size: 20px; font-weight: 800; margin-top: 0;">
        Bonjour Docteur {doctor_name},
      </h2>
      <p style="color: #475569; font-size: 14px; line-height: 1.6; margin-bottom: 24px;">
        Voici le récapitulatif des <strong>dernières ressources officielles</strong> ajoutées cette semaine à votre plateforme de révision Medsina. Tous ces documents sont disponibles dès maintenant en illimité et hors-ligne dans votre application.
      </p>

      <!-- Recent additions -->
      <h3 style="color: #0F172A; font-size: 15px; font-weight: 800; border-bottom: 2px solid #E2E8F0; padding-bottom: 8px; margin-bottom: 14px;">
        📚 NOUVEAUX SUPPORTS DE RÉVISION DISPONIBLES :
      </h3>
      {courses_html}

      {pearl_html}

      <!-- CTA Button -->
      <div style="text-align: center; margin: 32px 0 16px 0;">
        <a href="https://medsina.medevsync.com" target="_blank" style="display: inline-block; background: #0D9488; color: #FFFFFF; text-decoration: none; font-size: 15px; font-weight: 800; padding: 14px 28px; border-radius: 100px; box-shadow: 0 4px 14px rgba(13,148,136,0.35);">
          🚀 Consulter les Nouveautés dans l'Application
        </a>
      </div>
      <div style="text-align: center; color: #94A3B8; font-size: 12px;">
        Disponible sur Android (APK), Windows (Desktop) et Web App.
      </div>
    </div>

    <!-- Footer -->
    <div style="background: #F8FAFC; border-top: 1px solid #E2E8F0; padding: 20px 24px; text-align: center; color: #94A3B8; font-size: 11px;">
      <p style="margin: 0 0 6px 0;">Medsina Ultra • Plateforme Indépendante d'Accompagnement Médical</p>
      <p style="margin: 0;">Vous recevez cet e-mail car vous êtes membre inscrit sur Medsina.</p>
    </div>
  </div>
</body>
</html>
"""
    return html

def main():
    parser = argparse.ArgumentParser(description="Générateur et diffuseur de Digest Médical par e-mail.")
    parser.add_argument("--dry-run", action="store_true", help="Générer l'aperçu sans envoyer d'e-mails")
    parser.add_argument("--test-email", type=str, default=None, help="Envoyer un e-mail test à une seule adresse")
    args = parser.parse_args()

    print("=" * 65)
    print("📧 MEDSINA - DISPATCHER EMAIL DIGEST AUX MÉDECINS")
    print("=" * 65)

    recent_courses = fetch_recent_additions(limit=4)
    pearl = fetch_latest_daily_pearl()

    print(f"✅ {len(recent_courses)} cours récents récupérés.")
    if pearl:
        print(f"💡 Perle clinique intégrée : {pearl.get('title')}")

    recipients = fetch_doctor_recipients()
    print(f"👥 {len(recipients)} médecins/étudiants inscrits trouvés dans la base.")

    # Generate sample HTML
    sample_name = "Confrère"
    sample_html = build_email_digest_html(sample_name, recent_courses, pearl)

    preview_path = os.path.join(MEDSINA_DIR, "assets", "email_digest_preview.html")
    with open(preview_path, "w", encoding="utf-8") as f:
        f.write(sample_html)
    print(f"📄 Aperçu HTML généré : {preview_path}")

    if args.dry_run:
        print("\n🔎 Mode --dry-run activé : aucun e-mail envoyé.")
        print(f"Destinataires cibles : {[r['email'] for r in recipients[:10]]} ...")
        return

    if args.test_email:
        print(f"\n📨 Envoi d'un e-mail test vers : {args.test_email}...")
        # Via Apps Script webhook si configuré
        webhook_url = "https://script.google.com/macros/s/..." # configurable
        print("Pour activer l'envoi direct, configurez votre clé API Resend ou webhook Apps Script.")

    print("=" * 65)

if __name__ == "__main__":
    main()
