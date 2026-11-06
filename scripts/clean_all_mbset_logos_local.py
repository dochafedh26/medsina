import os
import sys
import glob
import time
import hashlib
from concurrent.futures import ThreadPoolExecutor, as_completed
import pymupdf

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
COURSES_DIR = os.path.join(ROOT_DIR, "exports", "courses")
KNOWN_LOGO_HASH = "305ffa802317fdfb043133d63373886d"

def clean_file_logos(fpath):
    try:
        doc = pymupdf.open(fpath)
        doc_modified = False
        logos_replaced = 0
        seen_xrefs = set()

        white_pix = pymupdf.Pixmap(pymupdf.csRGB, pymupdf.IRect(0, 0, 30, 25), 0)
        white_pix.clear_with(255)

        for page in doc:
            page_had_logo = False
            for img in page.get_images():
                xref = img[0]
                if xref in seen_xrefs:
                    continue
                seen_xrefs.add(xref)

                is_logo = False
                # 30x25 is the exact dimensions of the MBset teal logo
                if img[2] == 30 and img[3] == 25:
                    is_logo = True
                else:
                    try:
                        extracted = doc.extract_image(xref)
                        if hashlib.md5(extracted['image']).hexdigest() == KNOWN_LOGO_HASH:
                            is_logo = True
                    except Exception:
                        pass

                if is_logo:
                    page.replace_image(xref, pixmap=white_pix)
                    logos_replaced += 1
                    doc_modified = True
                    page_had_logo = True

            # If page had logo or MBset, ensure center bottom footer is painted white
            if page_had_logo or any("mbset" in w[4].lower() for w in page.get_text("words") if w[3] > page.rect.height * 0.7):
                pw = page.rect.width
                ph = page.rect.height
                # Center patch covers where logo and MBset text sit
                footer_patch = pymupdf.Rect(pw/2 - 60, ph - 30, pw/2 + 60, ph - 5)
                page.draw_rect(footer_patch, color=(1, 1, 1), fill=(1, 1, 1), overlay=True)
                doc_modified = True

        if doc_modified:
            tmp_path = fpath + ".clean_tmp"
            doc.save(tmp_path, deflate=True, garbage=4)
            doc.close()
            os.replace(tmp_path, fpath)
            return True, os.path.basename(fpath), logos_replaced
        else:
            doc.close()
            return False, os.path.basename(fpath), 0
    except Exception as e:
        return None, os.path.basename(fpath), str(e)

def main():
    print("=" * 65)
    print("🧼 NETTOYAGE EN MASSE DU LOGO MBSET SUR TOUS LES COURS LOCAUX")
    print("=" * 65)

    all_files = glob.glob(os.path.join(COURSES_DIR, "**", "*.pdf"), recursive=True)
    print(f"Total de fichiers à traiter : {len(all_files)}")

    t0 = time.time()
    modified_count = 0
    clean_count = 0
    error_count = 0
    total_logos = 0

    with ThreadPoolExecutor(max_workers=8) as executor:
        futures = {executor.submit(clean_file_logos, f): f for f in all_files}
        done_count = 0
        for f in as_completed(futures):
            done_count += 1
            success, fname, result = f.result()
            if success is True:
                modified_count += 1
                total_logos += result
            elif success is False:
                clean_count += 1
            else:
                error_count += 1
                print(f"⚠️ Erreur sur {fname}: {result}")

            if done_count % 100 == 0 or done_count == len(all_files):
                print(f"   [{done_count}/{len(all_files)}] traités... ({modified_count} modifiés, {clean_count} déjà sans logo)")

    elapsed = time.time() - t0
    print("\n" + "=" * 65)
    print(f"✨ NETTOYAGE LOCAL TERMINÉ EN {elapsed:.1f}s !")
    print(f" • Fichiers avec logo MBset supprimé : {modified_count}")
    print(f" • Fichiers déjà sains (sans logo)  : {clean_count}")
    print(f" • Total logos MBset neutralisés   : {total_logos}")
    print(f" • Erreurs                         : {error_count}")
    print("=" * 65)

if __name__ == "__main__":
    main()
