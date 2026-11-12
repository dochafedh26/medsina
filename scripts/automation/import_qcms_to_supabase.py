#!/usr/bin/env python3
"""
Medsina Ultra — Import Sécurisé de la Banque de 19 305 QCMs vers Supabase Cloud
=============================================================================
Importe tous les fichiers JSON de `assets/data/qcms/*.json` dans la table PostgreSQL
`public.qcm_questions` de Supabase Cloud.

Fonctionnalités :
  - Détection automatique de l'année d'étude (1..6 pour l'Externat, 7 pour le Résidanat).
  - Échantillon gratuit (is_free_sample = True) assigné aux 2 premiers cours de chaque module.
  - Champ `options` sérialisé directement en JSONB (élimine ~96 000 lignes dans qcm_options).
  - Upsert par lots de 500 questions avec gestion d'erreurs et reprise.
  - Mode simulation (--dry-run) pour validation locale intégrale.
"""

import argparse
import glob
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any, Dict, List, Set, Tuple

DEFAULT_SUPABASE_URL = "https://qzfssrhhuorljftpdvjm.supabase.co"
BATCH_SIZE = 500
FREE_COURSES_PER_MODULE = 2

# Mapping précis des modules vers les années d'étude du cursus médical
YEAR_KEYWORDS = {
    1: [
        "ANATOMIE_1", "BIOCHIMIE_1", "BIOPHYSIQUE_1", "CYTOLOGIE",
        "EMBRYOLOGIE", "HISTOLOGIE_1", "PHYSIOLOGIE_1", "CHIMIE",
        "BIOSTATISTIQUE", "SSH",
    ],
    2: [
        "UNITE_1_2", "UNITE_2_2", "UNITE_3_2", "UNITE_4_2", "UNITE_5_2",
        "IMMUNOLOGIE_2", "GENETIQUE",
    ],
    3: [
        "UNITE_1_3", "UNITE_2_3", "UNITE_3_3", "UNITE_4_3", "PHARMACOLOGIE",
        "MICROBIOLOGIE", "PARASITOLOGIE", "ANAPATHOLOGIE", "IMMUNOLOGIE_3",
    ],
    4: [
        "CARDIOLOGIE", "PNEUMOLOGIE", "GASTRO", "NEUROLOGIE", "INFECTIEU",
        "APPAREIL_LOCOMOTEUR", "CARDIO", "PNEUMO", "NEURO",
    ],
    5: [
        "PEDIATRIE", "GYNECO", "URO_NEPHROLOGIE", "OPHTALMOLOGIE", "ORL",
        "DERMATOLOGIE", "PSYCHIATRIE", "ENDOCRINO", "HEMATOLOGIE", "SYSTEME",
    ],
    6: [
        "URGENCES", "MEDECINE_LEGALE", "TRAVAIL", "EPIDEMIOLOGIE", "GERIATRIE",
    ],
}


def detect_study_year(module_id: str) -> int:
    clean = module_id.upper()
    for yr, kws in YEAR_KEYWORDS.items():
        if any(kw in clean for kw in kws):
            return yr
    return 7  # 7 = Concours Résidanat


def resolve_supabase_credentials() -> Tuple[str, str]:
    url = os.environ.get("SUPABASE_URL", DEFAULT_SUPABASE_URL).rstrip("/")
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "").strip()

    if not key:
        root_dir = Path(__file__).resolve().parents[2]
        for p in [root_dir / ".env", root_dir / "admin-dashboard" / ".env"]:
            if p.exists():
                try:
                    content = p.read_text(encoding="utf-8")
                    m = re.search(r"SUPABASE_SERVICE_ROLE_KEY\s*=\s*['\"]?([^'\"\r\n;]+)['\"]?", content)
                    if m and not m.group(1).startswith("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF6"):
                        key = m.group(1).strip()
                        break
                except Exception:
                    pass

    return url, key


def process_qcm_file(
    file_path: Path,
    free_courses_count: int = FREE_COURSES_PER_MODULE,
) -> Tuple[List[Dict[str, Any]], int, int]:
    """Lit un fichier JSON et produit les lignes prêtes pour qcm_questions."""
    with open(file_path, "r", encoding="utf-8") as f:
        raw_questions = json.load(f)

    if not isinstance(raw_questions, list):
        return [], 0, 0

    # Identifier l'ordre des cours dans le module
    course_order: List[str] = []
    for q in raw_questions:
        c_id = q.get("courseId") or q.get("course_id") or ""
        if c_id and c_id not in course_order:
            course_order.append(c_id)

    free_courses: Set[str] = set(course_order[:free_courses_count])

    base_name = file_path.stem
    default_mod_id = base_name
    study_year = detect_study_year(default_mod_id)

    rows: List[Dict[str, Any]] = []
    free_count = 0

    for q in raw_questions:
        q_id = str(q.get("id") or "").strip()
        if not q_id:
            continue

        mod_id = str(q.get("moduleId") or q.get("module_id") or default_mod_id).strip()
        course_id = str(q.get("courseId") or q.get("course_id") or "").strip()
        course_name = q.get("courseName") or q.get("course_name") or ""
        q_type = str(q.get("type") or "qcm").strip().lower()
        clinical_case = q.get("clinicalCaseText") or q.get("clinical_case") or None
        question_text = str(q.get("questionText") or q.get("question_text") or "").strip()
        options = q.get("options") or []
        correct_answers = q.get("correctAnswers") or q.get("correct_answers") or []
        explanation = q.get("explanation") or ""
        source = q.get("source") or "Concours Résidanat Blida"
        year_val = q.get("year")
        try:
            year = int(year_val) if year_val else 2024
        except Exception:
            year = 2024

        is_free = course_id in free_courses
        if is_free:
            free_count += 1

        rows.append({
            "id": q_id,
            "module_id": mod_id,
            "course_id": course_id,
            "course_name": course_name,
            "study_year": study_year,
            "type": q_type,
            "clinical_case": clinical_case,
            "question_text": question_text,
            "options": options,
            "correct_answers": correct_answers,
            "explanation": explanation,
            "source": source,
            "year": year,
            "is_free_sample": is_free,
        })

    return rows, len(course_order), free_count


def push_batch_to_supabase(
    supabase_url: str,
    supabase_key: str,
    batch: List[Dict[str, Any]],
) -> bool:
    """Envoie un lot de questions vers Supabase via PostgREST avec merge-duplicates."""
    headers = {
        "apikey": supabase_key,
        "Authorization": f"Bearer {supabase_key}",
        "Content-Type": "application/json",
        "Prefer": "resolution=merge-duplicates",
    }

    req = urllib.request.Request(
        f"{supabase_url}/rest/v1/qcm_questions",
        data=json.dumps(batch, ensure_ascii=False).encode("utf-8"),
        headers=headers,
        method="POST",
    )

    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return resp.status in (200, 201)
    except urllib.error.HTTPError as err:
        err_msg = err.read().decode("utf-8", errors="ignore")
        print(f"❌ Erreur HTTP ({err.code}): {err_msg[:300]}")
        return False
    except Exception as e:
        print(f"❌ Exception lors de l'envoi du lot: {e}")
        return False


def main():
    parser = argparse.ArgumentParser(description="Medsina — Import des 19 305 QCM vers Supabase")
    parser.add_argument("folder", nargs="?", default="database/raw_qcms", help="Dossier contenant les fichiers JSON")
    parser.add_argument("--dry-run", action="store_true", help="Valide l'import localement sans envoyer au Cloud")
    parser.add_argument("--batch-size", type=int, default=BATCH_SIZE, help="Taille des lots d'insertion")
    parser.add_argument("--limit-files", type=int, default=0, help="Limiter le nombre de fichiers à importer (tests)")
    args = parser.parse_args()

    supabase_url, supabase_key = resolve_supabase_credentials()

    folder_path = Path(args.folder)
    if not folder_path.exists():
        print(f"❌ Erreur : Le dossier {folder_path} n'existe pas.")
        sys.exit(1)

    json_files = sorted(folder_path.glob("*.json"))
    if not json_files:
        print(f"❌ Erreur : Aucun fichier JSON trouvé dans {folder_path}.")
        sys.exit(1)

    if args.limit_files > 0:
        json_files = json_files[: args.limit_files]

    print("=" * 70)
    print("🚀 MEDSINA ULTRA — IMPORT SÉCURISÉ DES 19 305 QCM VERS SUPABASE CLOUD")
    print("=" * 70)
    print(f"📁 Fichiers JSON détectés : {len(json_files)}")
    print(f"🌐 Supabase URL            : {supabase_url}")
    print(f"🔑 Clé Service Role        : {'Fournie (OK)' if supabase_key else 'ABSENTE'}")
    print(f"🧪 Mode Simulation (Dry)  : {args.dry_run}")
    print("=" * 70)

    if not args.dry_run and not supabase_key:
        print("⚠️ Attention : Aucune clé SUPABASE_SERVICE_ROLE_KEY n'a été trouvée.")
        print("Pour injecter dans Supabase avec contournement RLS, fournissez la clé via :")
        print("  export SUPABASE_SERVICE_ROLE_KEY='<clé_secrète_supabase>'")
        print("Puis relancez ce script.")
        print("\nExécution automatique basculée en mode --dry-run pour validation locale...")
        args.dry_run = True

    total_questions = 0
    total_free_sample = 0
    all_rows: List[Dict[str, Any]] = []

    for idx, f in enumerate(json_files, 1):
        rows, courses_count, free_count = process_qcm_file(f)
        if not rows:
            continue

        study_yr = rows[0]["study_year"]
        year_label = f"Année {study_yr}" if study_yr < 7 else "Résidanat"
        print(f"[{idx:02d}/{len(json_files):02d}] {f.name:<38} : {len(rows):>5} QCMs ({courses_count:>2} cours, {free_count:>3} gratuits) [{year_label}]")

        all_rows.extend(rows)
        total_questions += len(rows)
        total_free_sample += free_count

    print("=" * 70)
    print(f"📊 RÉCAPITULATIF :")
    print(f"   • Total questions analysées : {total_questions}")
    print(f"   • Total questions gratuites : {total_free_sample} (Pass Découverte)")
    print(f"   • Total questions payantes  : {total_questions - total_free_sample}")
    print("=" * 70)

    if args.dry_run:
        print("✅ Validation locale terminée avec succès ! Aucune donnée envoyée.")
        return

    # Envoi par lots
    print(f"🚀 Début de l'envoi vers Supabase Cloud par lots de {args.batch_size}...")
    success_count = 0
    start_time = time.time()

    for i in range(0, len(all_rows), args.batch_size):
        chunk = all_rows[i : i + args.batch_size]
        ok = push_batch_to_supabase(supabase_url, supabase_key, chunk)
        if ok:
            success_count += len(chunk)
            print(f"  ✓ Lot {i // args.batch_size + 1:>3} / {(len(all_rows) - 1) // args.batch_size + 1} ({success_count}/{total_questions} QCMs insérés)")
        else:
            print(f"  ✗ Échec du lot {i // args.batch_size + 1}")
        time.sleep(0.1)

    duration = time.time() - start_time
    print("=" * 70)
    print(f"🎉 IMPORT TERMINÉ en {duration:.1f} secondes !")
    print(f"   • Questions insérées avec succès : {success_count} / {total_questions}")
    print("=" * 70)


if __name__ == "__main__":
    main()
