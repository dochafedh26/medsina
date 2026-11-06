import pymupdf
import glob
import os
import hashlib
from collections import Counter

files = glob.glob('exports/courses/**/*.pdf', recursive=True)
print(f"Scanning {len(files)} course PDFs for logos and footer images...", flush=True)

hash_counter = Counter()
hash_info = {}
files_with_known_logo = 0
files_with_other_footer_imgs = []

KNOWN_LOGO_HASH = "305ffa802317fdfb043133d63373886d"

for idx, f in enumerate(files):
    try:
        doc = pymupdf.open(f)
        doc_has_known = False
        doc_has_other_footer = False
        
        # Check all unique images in the doc
        seen_xrefs = set()
        for p in doc:
            h = p.rect.height
            w = p.rect.width
            for img in p.get_images():
                xref = img[0]
                if xref in seen_xrefs:
                    continue
                seen_xrefs.add(xref)
                
                img_w, img_h = img[2], img[3]
                # Is it small or does it match the known logo?
                if (img_w <= 120 and img_h <= 100) or img[7] in ['Im2', 'mbset']:
                    try:
                        extracted = doc.extract_image(xref)
                        data = extracted['image']
                        hsh = hashlib.md5(data).hexdigest()
                        hash_counter[hsh] += 1
                        if hsh not in hash_info:
                            hash_info[hsh] = {
                                'w': img_w,
                                'h': img_h,
                                'ext': extracted['ext'],
                                'sample_file': os.path.basename(f),
                                'sample_path': f,
                                'xref': xref
                            }
                        if hsh == KNOWN_LOGO_HASH:
                            doc_has_known = True
                    except Exception:
                        pass
        if doc_has_known:
            files_with_known_logo += 1
    except Exception as e:
        print(f"Error reading {f}: {e}")

print(f"\nScan complete!", flush=True)
print(f"Files with KNOWN MBset logo ({KNOWN_LOGO_HASH}): {files_with_known_logo} / {len(files)}", flush=True)
print(f"Top 15 most frequent small image hashes across all PDFs:", flush=True)
for hsh, count in hash_counter.most_common(15):
    inf = hash_info[hsh]
    print(f" - Hash {hsh}: {count} files | {inf['w']}x{inf['h']} ({inf['ext']}) | Sample: {inf['sample_file']}")
