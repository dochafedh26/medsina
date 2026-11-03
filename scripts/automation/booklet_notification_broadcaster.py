#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
=============================================================================
MEDSINA — DIFFUSEUR MULTICANAL DE LIVRETS DE RÉVISION RÉSIDANAT 2027
=============================================================================
1. Notification In-App (Supabase table: medical_notifications)
2. Diffusion Facebook sur les 4 Pages officielles (Medsina, MedevSync, Résidanat Blida 2027, CAT aux Urgences)
3. Diffusion Telegram (@medsina_officiel + MEDSINA-COMMUNITY Topic 4)

Politique Téléchargement :
- Par défaut : Téléchargement STRICTEMENT réservé à l'application Medsina
- Mode Showcase / Premier Exemple : Spécimen offert en téléchargement direct pour attirer et convertir !
=============================================================================
"""

import os
import sys
import json
import time
import urllib.request
import urllib.parse
from pathlib import Path
from typing import Dict, Any, List, Optional

# UTF-8 Fix
if sys.stdout and hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

SCRIPT_DIR = Path(__file__).resolve().parent
WORKSPACE_ROOT = SCRIPT_DIR.parents[1] if len(SCRIPT_DIR.parents) > 1 else SCRIPT_DIR
sys.path.insert(0, str(SCRIPT_DIR))

try:
    from facebook_publisher import get_all_facebook_pages, publish_to_page_feed
except ImportError:
    get_all_facebook_pages = None
    publish_to_page_feed = None

try:
    from telegram_publisher import send_telegram_broadcast
except ImportError:
    send_telegram_broadcast = None


def get_credentials():
    url = os.environ.get("SUPABASE_URL", "https://qzfssrhhuorljftpdvjm.supabase.co")
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY") or os.environ.get(
        "SUPABASE_KEY",
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF6ZnNzcmhodW9ybGpmdHBkdmptIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MTYxMjg1NCwiZXhwIjoyMTA3MTg4ODU0fQ.-KCUgZdY8RDUwvNOUAabDhQFwv5FFGHYz0J-dM7Cic4"
    )
    return url.strip().rstrip("/"), key.strip()


def send_in_app_notification(
    course_id: str,
    course_name: str,
    module_id: str,
    bundle_url: str,
    is_hypertombable: bool,
    residanat_sessions: List[str],
    qcm_count: int,
    supabase_url: str,
    supabase_key: str,
    dry_run: bool = False
) -> Dict[str, Any]:
    """Publie une notification in-app dans Supabase medical_notifications."""
    print("   📱 [In-App] Création de la notification dans medical_notifications...")
    sessions_str = ", ".join(residanat_sessions) if residanat_sessions else ""
    hyper_tag = f" 🔥 HYPERTOMBABLE ({sessions_str})" if is_hypertombable else ""

    notif_id = f"notif_bundle_{course_id.lower()}_{int(time.time())}"
    title = f"🔥 Livret Concours 2027 : {course_name}"
    message = (
        f"Nouveau livret All-in-One disponible pour vos révisions du Résidanat 2027 !\n"
        f"• Module : {module_id}{hyper_tag}\n"
        f"• Contenu : Fiche de synthèse (points clés & pièges), cours complet de faculté, "
        f"{qcm_count} QCMs classés sans correction et corrigé type officiel en dernière page."
    )

    payload = {
        "id": notif_id,
        "title": title,
        "message": message,
        "type": "course",
        "created_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "target_id": course_id,
        "metadata": {
            "bundle_pdf_url": bundle_url,
            "is_hypertombable": is_hypertombable,
            "residanat_years": residanat_sessions,
            "qcm_count": qcm_count,
            "badge": "Livret 2027 🔥",
            "action_label": "Télécharger le Livret 📑"
        },
        "target_role": "all"
    }

    if dry_run:
        print(f"      [Dry-Run] Notification In-App simulée : {title}")
        return {"success": True, "dry_run": True, "id": notif_id}

    url = f"{supabase_url}/rest/v1/medical_notifications"
    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "apikey": supabase_key,
            "Authorization": f"Bearer {supabase_key}",
            "Content-Type": "application/json",
            "Prefer": "return=representation"
        },
        method="POST"
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            print(f"      ✅ Notification In-App enregistrée avec succès (ID: {notif_id})")
            return {"success": True, "id": notif_id, "data": data}
    except Exception as e:
        print(f"      ⚠️ Erreur insertion notification in-app : {e}")
        return {"success": False, "error": str(e)}


def publish_to_facebook_pages(
    course_id: str,
    course_name: str,
    module_id: str,
    bundle_url: str,
    is_hypertombable: bool,
    residanat_sessions: List[str],
    qcm_count: int,
    is_showcase: bool = False,
    dry_run: bool = False
) -> List[Dict[str, Any]]:
    """Diffuse le teaser ou le livret complet sur les 4 pages Facebook."""
    print("   📢 [Facebook] Diffusion sur les 4 pages officielles...")
    if not get_all_facebook_pages or not publish_to_page_feed:
        print("      ⚠️ Module facebook_publisher non disponible.")
        return []

    pages = get_all_facebook_pages()
    if not pages:
        print("      ⚠️ Aucune page Facebook configurée.")
        return []

    sessions_str = ", ".join(residanat_sessions) if residanat_sessions else ""
    if is_hypertombable and sessions_str:
        status_line = f"🔥 STATUT HYPERTOMBABLE AU CONCOURS (Sessions : {sessions_str})"
    elif is_hypertombable:
        status_line = "🔥 STATUT HYPERTOMBABLE AU CONCOURS (Questions récurrentes)"
    else:
        status_line = "📘 COURS OFFICIEL DU PROGRAMME DE RÉSIDANAT"

    if is_showcase:
        cta_section = (
            f"🎁 EXEMPLAIRE SPÉCIMEN OFFERT POUR TESTER :\n"
            f"Téléchargez gratuitement ce premier livret complet All-in-One en accès libre ici :\n"
            f"👉 {bundle_url}\n\n"
            f"📲 Pour débloquer l'intégralité des livrets de révision (47 modules, 15 000+ QCMs et corrigés détaillés) :\n"
            f"👉 Rejoignez l'application Medsina : https://medsina.medevsync.com"
        )
    else:
        cta_section = (
            f"📲 CE LIVRET EST DISPONIBLE EXCLUSIVEMENT DANS L'APPLICATION MEDSINA :\n"
            f"👉 Accédez à vos livrets officiels All-in-One : https://medsina.medevsync.com\n\n"
            f"⚠️ Note de confraternité : Afin de préserver la rigueur pédagogique et l'actualisation continue des annales, les livrets All-in-One ne sont téléchargeables que depuis l'application Medsina."
        )

    fb_text = (
        f"🎯 NOUVEAU LIVRET OFFICIEL DE RÉVISION — CONCOURS RÉSIDANAT 2027\n\n"
        f"📚 Module : {module_id}\n"
        f"📖 Cours : {course_name}\n"
        f"{status_line}\n\n"
        f"Le livret tout-en-un de révision vient d'être généré par Medsina pour préparer le concours avec efficacité :\n"
        f"1️⃣ Fiche de Synthèse Express (Points clés, critères diagnostiques & pièges concours)\n"
        f"2️⃣ Support de Cours Intégral Officiel (Polycopié de référence)\n"
        f"3️⃣ Mode Examen Blanc : {qcm_count} QCMs d'Annales classés SANS correction\n"
        f"4️⃣ En Dernière Page : Grille Officielle du Corrigé Type & Perles Cliniques\n\n"
        f"{cta_section}\n\n"
        f"Besoin d'aide, d'informations ou parrainage d'amphi ?\n"
        f"📞 Contact & WhatsApp : 0770 25 84 53\n"
        f"✈️ Telegram direct : @docchikhtouami\n\n"
        f"#ResidanatBlida #ConcoursResidanat2027 #Medsina #MedecineAlgerie"
    )

    results = []
    for p in pages:
        p_name = p["name"]
        p_id = p["page_id"]
        p_token = p["token"]
        print(f"      🚀 Publication sur {p_name} ({p_id})...")

        if dry_run:
            print(f"         [Dry-Run] Publication simulée sur {p_name}.")
            results.append({"page": p["key"], "name": p_name, "success": True, "dry_run": True})
            continue

        try:
            res = publish_to_page_feed(
                page_id=p_id,
                token=p_token,
                message=fb_text,
                link=bundle_url if is_showcase else "https://medsina.medevsync.com"
            )
            post_id = res.get("id")
            print(f"         ✅ Succès sur {p_name} ! Post ID: {post_id}")
            results.append({"page": p["key"], "name": p_name, "id": post_id, "success": True})
        except Exception as e:
            print(f"         ⚠️ Erreur sur {p_name} : {e}")
            results.append({"page": p["key"], "name": p_name, "error": str(e), "success": False})

    return results


def publish_to_telegram(
    course_id: str,
    course_name: str,
    module_id: str,
    bundle_url: str,
    is_hypertombable: bool,
    residanat_sessions: List[str],
    qcm_count: int,
    is_showcase: bool = False,
    dry_run: bool = False
) -> Dict[str, Any]:
    """Diffuse l'annonce ou le spécimen sur Telegram (@medsina_officiel & Topic Résidanat)."""
    print("   ✈️ [Telegram] Diffusion sur le Canal Officiel & Supergroupe...")
    if not send_telegram_broadcast:
        print("      ⚠️ Module telegram_publisher non disponible.")
        return {"success": False, "error": "telegram_publisher missing"}

    sessions_str = ", ".join(residanat_sessions) if residanat_sessions else ""
    hyper_badge = f"🔥 <b>HYPERTOMBABLE</b> <i>(Sessions : {sessions_str})</i>" if is_hypertombable else "📘 <b>Cours Officiel</b>"

    if is_showcase:
        cta_html = (
            f"🎁 <b>EXEMPLAIRE SPÉCIMEN OFFERT AUX CANDIDATS :</b>\n"
            f"Téléchargez gratuitement le livret complet de ce cours :\n"
            f"👉 <a href=\"{bundle_url}\"><b>Télécharger le Livret PDF ({course_name})</b></a>\n\n"
            f"📲 <i>Débloquez la collection complète sur l'application Medsina :</i>\n"
            f"👉 <a href=\"https://medsina.medevsync.com\"><b>Accéder à Medsina Web & Mobile</b></a>"
        )
    else:
        cta_html = (
            f"📲 <b>DISPONIBLE EXCLUSIVEMENT DANS L'APPLICATION MEDSINA :</b>\n"
            f"Pour préserver le barème officiel du concours, ce livret est téléchargeable uniquement depuis l'application.\n\n"
            f"👉 <a href=\"https://medsina.medevsync.com\"><b>Télécharger l'Application Medsina</b></a>"
        )

    tg_text = (
        f"🎯 <b>NOUVEAU LIVRET OFFICIEL DE RÉVISION — RÉSIDANAT 2027</b>\n\n"
        f"📚 <b>Module :</b> {module_id}\n"
        f"📖 <b>Cours :</b> {course_name}\n"
        f"🏷️ <b>Statut :</b> {hyper_badge}\n\n"
        f"<b>Composition du Livret Tout-en-Un :</b>\n"
        f"1️⃣ Fiche de Synthèse Express (Points clés, pièges concours, CAT)\n"
        f"2️⃣ Support de Cours Magistral complet\n"
        f"3️⃣ Épreuve Blanche : {qcm_count} QCMs classés <b>sans correction</b>\n"
        f"4️⃣ Dernière Page : Grille Officielle du <b>Corrigé Type</b>\n\n"
        f"{cta_html}\n\n"
        f"📞 <b>Contact / WhatsApp :</b> 0770 25 84 53\n"
        f"👨‍⚕️ <b>Telegram direct :</b> @docchikhtouami\n\n"
        f"#Residanat2027 #LivretRevision #Blida #Medsina"
    )

    inline_keyboard = {
        "inline_keyboard": [
            [
                {
                    "text": "Télécharger le Livret Spécimen 📑" if is_showcase else "Ouvrir dans Medsina 📲",
                    "url": bundle_url if is_showcase else "https://medsina.medevsync.com"
                }
            ],
            [
                {
                    "text": "Plateforme Officielle 🚀",
                    "url": "https://medsina.medevsync.com"
                },
                {
                    "text": "Contact Dr Chikh Touami ✈️",
                    "url": "https://t.me/docchikhtouami"
                }
            ]
        ]
    }

    try:
        res = send_telegram_broadcast(
            message_text=tg_text,
            topic_id=4,  # Topic RESIDANAT-BLIDA-2027-COURS
            inline_keyboard=inline_keyboard,
            dry_run=dry_run,
            auto_pin=True,
            broadcast_to_community=True
        )
        print("      ✅ Diffusion Telegram réussie !")
        return {"success": True, "res": res}
    except Exception as e:
        print(f"      ⚠️ Erreur diffusion Telegram : {e}")
        return {"success": False, "error": str(e)}


def broadcast_residanat_bundle(
    course_id: str,
    course_name: str,
    module_id: str,
    bundle_url: str,
    is_hypertombable: bool,
    residanat_sessions: List[str],
    qcm_count: int,
    is_showcase: bool = False,
    dry_run: bool = False
) -> Dict[str, Any]:
    """Coordonne la notification in-app, les 4 pages Facebook et Telegram."""
    supabase_url, supabase_key = get_credentials()

    print("\n" + "=" * 65)
    print(f"🚀 MULTICANAL BROADCAST : {course_name}")
    print(f"   Mode Showcase (Spécimen public) : {'OUI 🎁' if is_showcase else 'NON (App Exclusive 🔒)'}")
    print(f"   URL Livret : {bundle_url}")
    print("=" * 65)

    # 1. In-App Notification
    in_app_res = send_in_app_notification(
        course_id=course_id,
        course_name=course_name,
        module_id=module_id,
        bundle_url=bundle_url,
        is_hypertombable=is_hypertombable,
        residanat_sessions=residanat_sessions,
        qcm_count=qcm_count,
        supabase_url=supabase_url,
        supabase_key=supabase_key,
        dry_run=dry_run
    )

    # 2. Facebook 4 Pages
    fb_res = publish_to_facebook_pages(
        course_id=course_id,
        course_name=course_name,
        module_id=module_id,
        bundle_url=bundle_url,
        is_hypertombable=is_hypertombable,
        residanat_sessions=residanat_sessions,
        qcm_count=qcm_count,
        is_showcase=is_showcase,
        dry_run=dry_run
    )

    # 3. Telegram
    tg_res = publish_to_telegram(
        course_id=course_id,
        course_name=course_name,
        module_id=module_id,
        bundle_url=bundle_url,
        is_hypertombable=is_hypertombable,
        residanat_sessions=residanat_sessions,
        qcm_count=qcm_count,
        is_showcase=is_showcase,
        dry_run=dry_run
    )

    return {
        "course_id": course_id,
        "is_showcase": is_showcase,
        "in_app": in_app_res,
        "facebook": fb_res,
        "telegram": tg_res
    }


if __name__ == "__main__":
    # Test runner CLI
    import argparse
    parser = argparse.ArgumentParser(description="Diffuseur Multicanal de Livret Résidanat 2027")
    parser.add_argument("--course-id", type=str, default="Blida_HEPATO_GASTRO_ENTEROLOGIE_CANCER_DU_PANCREAS")
    parser.add_argument("--course-name", type=str, default="Cancer du pancréas")
    parser.add_argument("--module-id", type=str, default="Hépato-Gastro-Entérologie")
    parser.add_argument("--bundle-url", type=str, default="https://qzfssrhhuorljftpdvjm.supabase.co/storage/v1/object/public/residanat_2027_livrets/Blida_HEPATO_GASTRO_ENTEROLOGIE/Blida_HEPATO_GASTRO_ENTEROLOGIE_CANCER_DU_PANCREAS_Livret_Residanat_2027.pdf")
    parser.add_argument("--hypertombable", action="store_true", default=True)
    parser.add_argument("--sessions", nargs="*", default=["2017", "2018", "2021"])
    parser.add_argument("--qcm-count", type=int, default=24)
    parser.add_argument("--showcase", action="store_true", default=True)
    parser.add_argument("--dry-run", action="store_true", default=False)
    args = parser.parse_args()

    broadcast_residanat_bundle(
        course_id=args.course_id,
        course_name=args.course_name,
        module_id=args.module_id,
        bundle_url=args.bundle_url,
        is_hypertombable=args.hypertombable,
        residanat_sessions=args.sessions,
        qcm_count=args.qcm_count,
        is_showcase=args.showcase,
        dry_run=args.dry_run
    )
