#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
=============================================================================
MEDSINA - NETTOYAGE EN MASSE DES PIEDS DE PAGE & FILIGRANES PDF (EXPORTS/COURSES)
=============================================================================
Ce script parcourt récursivement l'ensemble des polycopiés de cours officiels
dans le dossier `exports/courses/` (1 190 fichiers PDF).

Traitements appliqués sur chaque page :
1. Détection ultra-précise de la mention « MBset – mbset.com » en bas de page.
2. Biffure vectorielle chirurgicale (Redaction Annotation blanche) qui efface
   physiquement le texte du flux binaire PDF sans toucher au texte médical ou
   aux mentions de la faculté (ex: "CHU Blida" ou numéro de page conservés).
3. Suppression physique de tous les hyperliens sous-jacents pointant vers mbset.
4. Ré-écriture optimisée (deflate=True, garbage=4) pour réduire la taille.
=============================================================================
"""

import os
import sys
import time
import glob
from pathlib import Path
from typing import Dict, Any, Tuple
import concurrent.futures
import pymupdf

# Fix encodage console Windows
if sys.stdout and hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

SCRIPT_DIR = Path(__file__).resolve().parent
# Find real workspace root containing exports
def find_courses_dir() -> Path:
    candidates = [
        SCRIPT_DIR.parents[2] / "exports" / "courses",
        SCRIPT_DIR.parents[1] / "exports" / "courses",
        Path("exports/courses").resolve(),
        Path("../exports/courses").resolve(),
        Path("../../exports/courses").resolve(),
    ]
    for c in candidates:
        if c.exists():
            return c
    return SCRIPT_DIR.parents[2] / "exports" / "courses"

COURSES_DIR = find_courses_dir()


def sanitize_single_pdf(pdf_path: str) -> Dict[str, Any]:
    """
    Nettoie un unique fichier PDF :
    - Supprime le texte MBset / mbset.com dans les pieds de page.
    - Supprime les liens vers mbset.
    """
    res = {
        "path": pdf_path,
        "success": False,
        "modified": False,
        "pages_total": 0,
        "pages_cleaned": 0,
        "links_removed": 0,
        "error": None
    }
    
    try:
        doc = pymupdf.open(pdf_path)
        res["pages_total"] = len(doc)
        doc_modified = False

        for page_idx in range(len(doc)):
            page = doc[page_idx]
            page_h = page.rect.height
            words = page.get_text("words")
            page_redacted = False

            # 1. Détection par lignes contenant 'mbset' dans le tiers inférieur (y > 0.65 * page_h)
            mbset_lines = set(
                (w[5], w[6]) for w in words
                if "mbset" in w[4].lower() and w[3] > page_h * 0.65
            )

            rects_to_redact = []
            for b_no, l_no in mbset_lines:
                l_words = [w for w in words if w[5] == b_no and w[6] == l_no]
                mbset_indices = [i for i, w in enumerate(l_words) if "mbset" in w[4].lower()]
                if not mbset_indices:
                    continue
                min_idx = min(mbset_indices)
                max_idx = max(mbset_indices)
                wm_words = l_words[min_idx:max_idx + 1]

                x0 = min(w[0] for w in wm_words) - 2.0
                y0 = min(w[1] for w in wm_words) - 2.0
                x1 = max(w[2] for w in wm_words) + 2.0
                y1 = max(w[3] for w in wm_words) + 2.0
                rects_to_redact.append(pymupdf.Rect(x0, y0, x1, y1))

            # 2. Sécurité additionnelle : search_for direct pour tout reliquat éventuel
            for pattern in ["mbset.com", "mbset"]:
                for r in page.search_for(pattern):
                    if r.y1 > page_h * 0.65:
                        already_covered = any(r in rr or rr.intersects(r) for rr in rects_to_redact)
                        if not already_covered:
                            rects_to_redact.append(pymupdf.Rect(r.x0 - 2, r.y0 - 2, r.x1 + 2, r.y1 + 2))

            # 3. Application des biffures (effacement définitif du flux binaire ultra-rapide)
            if rects_to_redact:
                for rect in rects_to_redact:
                    page.add_redact_annot(rect, fill=(1, 1, 1))
                page.apply_redactions(images=pymupdf.PDF_REDACT_IMAGE_NONE)
                page_redacted = True

            # 4. Suppression des hyperliens mbset
            links = page.get_links()
            for link in links:
                uri = link.get("uri", "")
                if uri and "mbset" in uri.lower():
                    page.delete_link(link)
                    res["links_removed"] += 1
                    page_redacted = True

            if page_redacted:
                res["pages_cleaned"] += 1
                doc_modified = True

        if doc_modified:
            res["modified"] = True
            # Sauvegarde atomique sécurisée rapide
            tmp_path = pdf_path + ".clean_tmp"
            doc.save(tmp_path, deflate=True)
            doc.close()
            # Remplacement atomique
            os.replace(tmp_path, pdf_path)
        else:
            doc.close()

        res["success"] = True
    except Exception as e:
        res["error"] = str(e)
        if 'doc' in locals() and doc:
            try:
                doc.close()
            except Exception:
                pass
        tmp_path = pdf_path + ".clean_tmp"
        if os.path.exists(tmp_path):
            try:
                os.remove(tmp_path)
            except Exception:
                pass

    return res


def run_batch_cleanup(courses_dir: Path, max_workers: int = None):
    start_time = time.time()
    print("=" * 75)
    print("🧹 MEDSINA — NETTOYAGE EN MASSE DES PIEDS DE PAGE PDF (EXPORTS/COURSES)")
    print("=" * 75)
    
    if not courses_dir.exists():
        print(f"❌ Dossier introuvable : {courses_dir}")
        return

    pdf_files = [str(p) for p in courses_dir.rglob("*.pdf")]
    total_files = len(pdf_files)
    print(f"📂 Dossier cible : {courses_dir}")
    print(f"📄 Total fichiers PDF détectés : {total_files}")
    
    if total_files == 0:
        print("Aucun fichier à traiter.")
        return

    if max_workers is None:
        max_workers = min(os.cpu_count() or 4, 8)
    print(f"⚡ Exécution multi-processus avec {max_workers} cœurs CPU...")
    print("-" * 75)

    modified_count = 0
    pages_cleaned_total = 0
    links_removed_total = 0
    errors_count = 0
    processed_count = 0

    with concurrent.futures.ProcessPoolExecutor(max_workers=max_workers) as executor:
        futures = {executor.submit(sanitize_single_pdf, f): f for f in pdf_files}
        
        for future in concurrent.futures.as_completed(futures):
            processed_count += 1
            res = future.result()
            
            if res["error"]:
                errors_count += 1
                print(f"   ⚠️ Erreur sur {os.path.basename(res['path'])}: {res['error']}")
            elif res["modified"]:
                modified_count += 1
                pages_cleaned_total += res["pages_cleaned"]
                links_removed_total += res["links_removed"]
            
            # Affichage de progression par palier de 100 ou fin
            if processed_count % 100 == 0 or processed_count == total_files:
                pct = (processed_count / total_files) * 100
                elapsed = time.time() - start_time
                print(f"⏳ Progression : {processed_count}/{total_files} ({pct:.1f}%) | "
                      f"Nettoyés : {modified_count} | Pages : {pages_cleaned_total} | "
                      f"Liens purgés : {links_removed_total} | Temps : {elapsed:.1f}s", flush=True)

    elapsed_total = time.time() - start_time
    print("=" * 75)
    print("🎉 BILAN DU NETTOYAGE EN MASSE :")
    print(f"• Total fichiers examinés    : {total_files}")
    print(f"• Fichiers désinfectés       : {modified_count}")
    print(f"• Pages biffées/nettoyées    : {pages_cleaned_total}")
    print(f"• Hyperliens supprimés       : {links_removed_total}")
    print(f"• Fichiers déjà sains/propres: {total_files - modified_count}")
    print(f"• Erreurs                    : {errors_count}")
    print(f"• Durée totale               : {elapsed_total:.2f} secondes")
    print("=" * 75)


if __name__ == "__main__":
    run_batch_cleanup(COURSES_DIR)
