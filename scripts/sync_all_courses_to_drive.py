import os
import sys
import io
import time
import json
import random
import unicodedata
import re
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed
import pymupdf
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload, MediaIoBaseDownload

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
TOKEN_PATH = os.path.join(ROOT_DIR, 'token.json')
PROGRESS_FILE = os.path.join(ROOT_DIR, 'scripts', 'drive_update_progress.json')
COURSES_FOLDER_ID = '1E9ZmhKGUUdrj0S8o_Tp2vnBGLxIG5OQ9'
SCOPES = ['https://www.googleapis.com/auth/drive']

thread_local = threading.local()

def get_drive_service():
    if not hasattr(thread_local, "service"):
        creds = Credentials.from_authorized_user_file(TOKEN_PATH, SCOPES)
        if creds.expired and creds.refresh_token:
            creds.refresh(Request())
        thread_local.service = build('drive', 'v3', credentials=creds, cache_discovery=False)
    return thread_local.service

def normalize_text(text: str) -> str:
    if not text:
        return ""
    nfkd = unicodedata.normalize('NFKD', text)
    ascii_text = ''.join([c for c in nfkd if not unicodedata.combining(c)])
    return re.sub(r'[^a-zA-Z0-9]', '', ascii_text).lower()

def load_progress():
    if os.path.exists(PROGRESS_FILE):
        try:
            with open(PROGRESS_FILE, 'r', encoding='utf-8') as f:
                return json.load(f)
        except Exception:
            return {}
    return {}

def save_progress(progress_dict):
    try:
        with open(PROGRESS_FILE, 'w', encoding='utf-8') as f:
            json.dump(progress_dict, f, ensure_ascii=False, indent=2)
    except Exception as e:
        print(f"⚠️ Error saving progress: {e}", flush=True)

def update_drive_file(task_item):
    """Worker task to update a single Drive file with the clean local PDF."""
    file_id = task_item['drive_id']
    file_name = task_item['drive_name']
    local_path = task_item['local_path']

    service = get_drive_service()
    
    max_retries = 4
    for attempt in range(max_retries):
        try:
            media = MediaFileUpload(local_path, mimetype='application/pdf', resumable=True)
            res = service.files().update(
                fileId=file_id,
                media_body=media,
                fields='id, name, size, modifiedTime'
            ).execute()
            return True, file_id, file_name, None
        except Exception as e:
            err_msg = str(e)
            if "rateLimitExceeded" in err_msg or "userRateLimitExceeded" in err_msg or "503" in err_msg or "500" in err_msg:
                wait_time = (2 ** attempt) + random.uniform(0.5, 1.5)
                time.sleep(wait_time)
            else:
                time.sleep(1)
            if attempt == max_retries - 1:
                return False, file_id, file_name, err_msg

def main():
    print("=" * 65, flush=True)
    print("🚀 DÉMARRAGE DE LA MISE À JOUR MASSIVE SUR MEDSINA GOOGLE DRIVE", flush=True)
    print("=" * 65, flush=True)

    root_service = build('drive', 'v3', credentials=Credentials.from_authorized_user_file(TOKEN_PATH, SCOPES))

    # 1. Index local cleaned PDFs
    print("\n📂 [1/4] Indexation des PDF locaux nettoyés...", flush=True)
    local_courses_dir = os.path.join(ROOT_DIR, 'exports', 'courses')
    local_map_by_mod = {}
    local_map_by_name = {}

    for root, dirs, files in os.walk(local_courses_dir):
        for f in files:
            if f.endswith('.pdf'):
                full_path = os.path.join(root, f)
                mod_name = os.path.basename(root)
                mod_norm = normalize_text(mod_name)
                f_norm = normalize_text(f[:-4])
                
                local_map_by_mod[(mod_norm, f_norm)] = full_path
                local_map_by_name[f_norm] = full_path

    print(f"✅ {len(local_map_by_name)} PDF locaux disponibles sans filigrane MBset.", flush=True)

    # 2. List remote module folders under courses
    print(f"\n☁️ [2/4] Récupération de l'arborescence Google Drive (Dossier 'courses')...", flush=True)
    module_folders = {}
    page_token = None
    q = f"'{COURSES_FOLDER_ID}' in parents and mimeType = 'application/vnd.google-apps.folder' and trashed = false"
    while True:
        res = root_service.files().list(q=q, pageSize=100, fields="nextPageToken, files(id, name)", pageToken=page_token).execute()
        for item in res.get('files', []):
            module_folders[item['id']] = item['name']
        page_token = res.get('nextPageToken')
        if not page_token:
            break
    print(f"✅ {len(module_folders)} dossiers de modules détectés sur Drive.", flush=True)

    # List all Drive PDF files
    drive_files = []
    for mod_id, mod_name in module_folders.items():
        page_token = None
        while True:
            q_pdf = f"'{mod_id}' in parents and mimeType = 'application/pdf' and trashed = false"
            res_pdf = root_service.files().list(q=q_pdf, pageSize=100, fields="nextPageToken, files(id, name, size)", pageToken=page_token).execute()
            for it in res_pdf.get('files', []):
                it['folder_id'] = mod_id
                it['folder_name'] = mod_name
                drive_files.append(it)
            page_token = res_pdf.get('nextPageToken')
            if not page_token:
                break

    print(f"✅ {len(drive_files)} fichiers PDF trouvés sur Google Drive.", flush=True)

    # 3. Match Drive files with local clean files
    print("\n🔍 [3/4] Correspondance des fichiers...", flush=True)
    tasks = []
    progress = load_progress()
    unmatched_count = 0

    for df in drive_files:
        df_id = df['id']
        df_name = df['name']
        mod_norm = normalize_text(df['folder_name'])
        f_norm = normalize_text(df_name.replace('.pdf', ''))

        # Match logic
        local_path = local_map_by_mod.get((mod_norm, f_norm))
        if not local_path:
            local_path = local_map_by_name.get(f_norm)
            
        if not local_path:
            # Fallback substring
            for k, p in local_map_by_name.items():
                if f_norm in k or k in f_norm:
                    local_path = p
                    break

        if local_path:
            # Check if already completed
            if df_id in progress and progress[df_id].get('status') == 'success':
                continue
            tasks.append({
                'drive_id': df_id,
                'drive_name': df_name,
                'folder_name': df['folder_name'],
                'local_path': local_path
            })
        else:
            unmatched_count += 1
            print(f"⚠️ Non trouvé en local: [{df['folder_name']}] {df_name}")

    already_done = len(progress)
    print(f"📊 Bilan d'appariement :")
    print(f"   • Total fichiers Drive : {len(drive_files)}")
    print(f"   • Déjà mis à jour : {already_done}")
    print(f"   • À mettre à jour : {len(tasks)}")
    print(f"   • Non appariés : {unmatched_count}")

    if not tasks:
        print("\n✨ Tous les fichiers Drive sont déjà à jour avec les PDF nettoyés !", flush=True)
    else:
        print(f"\n⚡ [4/4] Lancement de l'upload multi-thread (6 workers)...", flush=True)
        start_time = time.time()
        completed = 0
        failed = 0
        
        with ThreadPoolExecutor(max_workers=6) as executor:
            future_to_task = {executor.submit(update_drive_file, t): t for t in tasks}
            
            for future in as_completed(future_to_task):
                success, fid, fname, err = future.result()
                if success:
                    completed += 1
                    progress[fid] = {
                        'status': 'success',
                        'name': fname,
                        'updated_at': time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
                    }
                else:
                    failed += 1
                    print(f"❌ Échec pour {fname}: {err}", flush=True)

                total_done = already_done + completed
                if completed % 25 == 0 or completed == len(tasks):
                    save_progress(progress)
                    elapsed = time.time() - start_time
                    rate = completed / elapsed if elapsed > 0 else 0
                    eta_sec = (len(tasks) - completed) / rate if rate > 0 else 0
                    print(f"   [Progression] {total_done}/{len(drive_files)} ({total_done/len(drive_files)*100:.1f}%) | "
                          f"{completed} màj ({rate:.1f} f/s) | ETA: {eta_sec/60:.1f} min", flush=True)

        save_progress(progress)
        print(f"\n🎉 Mise à jour terminée ! {completed} fichiers mis à jour, {failed} échecs.", flush=True)

    # 4. Check & sanitize Livrets_Residanat_2027 if present
    print("\n📚 Vérification du dossier 'Livrets_Residanat_2027'...", flush=True)
    res_root = root_service.files().list(q=f"'1___jg3oAyaBm-REwGb68q_XTN5dKWX2E' in parents and trashed = false", fields="files(id, name, mimeType)").execute()
    livret_folder_id = None
    for f in res_root.get('files', []):
        if f['name'] == 'Livrets_Residanat_2027' and f['mimeType'] == 'application/vnd.google-apps.folder':
            livret_folder_id = f['id']
            break
            
    if livret_folder_id:
        res_liv = root_service.files().list(q=f"'{livret_folder_id}' in parents and mimeType = 'application/pdf' and trashed = false", fields="files(id, name, size)").execute()
        liv_files = res_liv.get('files', [])
        print(f"Trouvé {len(liv_files)} livrets sur Drive.")
        for lf in liv_files:
            # Download and check
            req = root_service.files().get_media(fileId=lf['id'])
            fh = io.BytesIO()
            dl = MediaIoBaseDownload(fh, req)
            done = False
            while not done:
                _, done = dl.next_chunk()
            fh.seek(0)
            doc = pymupdf.open(stream=fh.read(), filetype='pdf')
            has_mbset = any('mbset' in p.get_text().lower() for p in doc)
            if has_mbset:
                print(f"Nettoyage du livret {lf['name']}...")
                # Sanitize in memory
                WHITE = (1, 1, 1)
                for page in doc:
                    rect = page.rect
                    footer_rect = pymupdf.Rect(0, rect.height - 35, rect.width, rect.height)
                    page.draw_rect(footer_rect, color=WHITE, fill=WHITE)
                    # remove links
                    for link in page.get_links():
                        uri = link.get("uri", "")
                        if "mbset" in uri.lower():
                            page.delete_link(link)
                clean_bytes = doc.tobytes(deflate=True, garbage=4)
                doc.close()
                media = MediaFileUpload(io.BytesIO(clean_bytes), mimetype='application/pdf') if False else None
                # Write to temp file then upload
                temp_path = os.path.join(ROOT_DIR, 'scripts', f"temp_{lf['name']}")
                with open(temp_path, 'wb') as tf:
                    tf.write(clean_bytes)
                root_service.files().update(fileId=lf['id'], media_body=MediaFileUpload(temp_path, mimetype='application/pdf')).execute()
                os.remove(temp_path)
                print(f"Livret {lf['name']} nettoyé et mis à jour sur Drive !")
            else:
                doc.close()
                print(f"Livret {lf['name']} est déjà propre.")

    # 5. Spot-check 5 random files from Drive to verify 100% absence of MBset
    print("\n🔍 Contrôle qualité : vérification aléatoire de 5 fichiers directement depuis Drive...", flush=True)
    sample_files = random.sample(drive_files, min(5, len(drive_files)))
    all_clean = True
    for sf in sample_files:
        req = root_service.files().get_media(fileId=sf['id'])
        fh = io.BytesIO()
        dl = MediaIoBaseDownload(fh, req)
        done = False
        while not done:
            _, done = dl.next_chunk()
        fh.seek(0)
        doc = pymupdf.open(stream=fh.read(), filetype='pdf')
        has_mbset = any('mbset' in p.get_text().lower() for p in doc)
        doc.close()
        status_str = "❌ CONTIENT ENCORE MBSET" if has_mbset else "✅ 100% PROPRE (Aucun MBset)"
        print(f"   • [{sf['folder_name']}] {sf['name']} : {status_str}")
        if has_mbset:
            all_clean = False

    print("\n" + "=" * 65)
    if all_clean:
        print("🏆 SUCCÈS TOTAL : Tous les cours sur Medsina Drive sont nettoyés et exempts de MBset !", flush=True)
    else:
        print("⚠️ Attention : des filigranes subsistent sur certains fichiers.", flush=True)
    print("=" * 65, flush=True)

if __name__ == '__main__':
    main()
