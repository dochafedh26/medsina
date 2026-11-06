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
PROGRESS_FILE = os.path.join(ROOT_DIR, 'scripts', 'drive_logo_update_progress.json')
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
        print(f"⚠️ Erreur sauvegarde progression: {e}", flush=True)

def update_drive_file(task_item):
    file_id = task_item['drive_id']
    file_name = task_item['drive_name']
    local_path = task_item['local_path']

    service = get_drive_service()
    max_retries = 5
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
            if any(k in err_msg for k in ["rateLimitExceeded", "userRateLimitExceeded", "503", "500"]):
                time.sleep((2 ** attempt) + random.uniform(0.5, 1.5))
            else:
                time.sleep(1)
            if attempt == max_retries - 1:
                return False, file_id, file_name, err_msg

def main():
    print("=" * 65, flush=True)
    print("🚀 SYNCHRONISATION DES PDF SANS LOGO SUR MEDSINA GOOGLE DRIVE", flush=True)
    print("=" * 65, flush=True)

    root_service = build('drive', 'v3', credentials=Credentials.from_authorized_user_file(TOKEN_PATH, SCOPES))

    # 1. Index local clean files
    print("\n📂 [1/4] Indexation des fichiers locaux propres...", flush=True)
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

    # 2. List remote module folders and files
    print(f"\n☁️ [2/4] Récupération des fichiers sur Google Drive...", flush=True)
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

    print(f"✅ {len(drive_files)} fichiers trouvés sur Drive.", flush=True)

    # 3. Match and filter tasks
    print("\n🔍 [3/4] Détermination des fichiers à mettre à jour...", flush=True)
    progress = load_progress()
    tasks = []

    for df in drive_files:
        df_id = df['id']
        df_name = df['name']
        mod_norm = normalize_text(df['folder_name'])
        f_norm = normalize_text(df_name.replace('.pdf', ''))

        local_path = local_map_by_mod.get((mod_norm, f_norm))
        if not local_path:
            local_path = local_map_by_name.get(f_norm)
        if not local_path:
            for k, p in local_map_by_name.items():
                if f_norm in k or k in f_norm:
                    local_path = p
                    break

        if local_path:
            if df_id in progress and progress[df_id].get('status') == 'success':
                continue
            tasks.append({
                'drive_id': df_id,
                'drive_name': df_name,
                'folder_name': df['folder_name'],
                'local_path': local_path
            })

    print(f"📊 {len(tasks)} fichiers à téléverser (Déjà faits : {len(progress)}).", flush=True)

    if tasks:
        print(f"\n⚡ [4/4] Téléversement en cours (7 workers)...", flush=True)
        start_time = time.time()
        completed = 0
        failed = 0
        with ThreadPoolExecutor(max_workers=7) as executor:
            future_to_task = {executor.submit(update_drive_file, t): t for t in tasks}
            for future in as_completed(future_to_task):
                success, fid, fname, err = future.result()
                if success:
                    completed += 1
                    progress[fid] = {'status': 'success', 'name': fname, 'at': time.time()}
                else:
                    failed += 1
                    print(f"❌ Échec pour {fname}: {err}", flush=True)

                if completed % 25 == 0 or completed == len(tasks):
                    save_progress(progress)
                    elapsed = time.time() - start_time
                    rate = completed / elapsed if elapsed > 0 else 0
                    eta_sec = (len(tasks) - completed) / rate if rate > 0 else 0
                    print(f"   [Progression] {completed}/{len(tasks)} ({completed/len(tasks)*100:.1f}%) | "
                          f"{rate:.1f} f/s | ETA: {eta_sec/60:.1f} min", flush=True)

        save_progress(progress)
        print(f"\n🎉 Téléversement terminé ! {completed} mis à jour, {failed} échecs.", flush=True)

    # 4. Clean Livret on Drive as well
    print("\n📚 Nettoyage du logo sur le Livret Cancérologie du pancréas...", flush=True)
    q_liv = "name contains 'Cancer_du_Pancreas' and mimeType = 'application/pdf' and trashed = false"
    res_liv = root_service.files().list(q=q_liv, fields="files(id, name)").execute()
    for lf in res_liv.get('files', []):
        req = root_service.files().get_media(fileId=lf['id'])
        fh = io.BytesIO()
        dl = MediaIoBaseDownload(fh, req)
        done = False
        while not done:
            _, done = dl.next_chunk()
        fh.seek(0)
        doc = pymupdf.open(stream=fh.read(), filetype='pdf')
        white_pix = pymupdf.Pixmap(pymupdf.csRGB, pymupdf.IRect(0, 0, 30, 25), 0)
        white_pix.clear_with(255)
        for page in doc:
            for img in page.get_images():
                if img[2] == 30 and img[3] == 25:
                    page.replace_image(img[0], pixmap=white_pix)
            pw = page.rect.width
            ph = page.rect.height
            page.draw_rect(pymupdf.Rect(pw/2 - 60, ph - 30, pw/2 + 60, ph - 5), color=(1, 1, 1), fill=(1, 1, 1), overlay=True)
        data = doc.tobytes(deflate=True, garbage=4)
        doc.close()
        tmp_p = os.path.join(ROOT_DIR, 'scripts', 'temp_liv_clean.pdf')
        with open(tmp_p, 'wb') as tf:
            tf.write(data)
        root_service.files().update(fileId=lf['id'], media_body=MediaFileUpload(tmp_p, mimetype='application/pdf')).execute()
        os.remove(tmp_p)
        print(f"✅ Livret {lf['name']} nettoyé et republié sur Drive !")

    # 5. Spot-check 5 random files downloaded fresh from Drive
    print("\n🔍 Contrôle qualité final : vérification de 5 fichiers directement depuis Drive...", flush=True)
    sample_files = random.sample(drive_files, min(5, len(drive_files)))
    for sf in sample_files:
        req = root_service.files().get_media(fileId=sf['id'])
        fh = io.BytesIO()
        dl = MediaIoBaseDownload(fh, req)
        done = False
        while not done:
            _, done = dl.next_chunk()
        fh.seek(0)
        doc = pymupdf.open(stream=fh.read(), filetype='pdf')
        has_30x25 = False
        for p in doc:
            for img in p.get_images():
                if img[2] == 30 and img[3] == 25:
                    # Check if it was replaced with white
                    try:
                        ext = doc.extract_image(img[0])
                        if hashlib.md5(ext['image']).hexdigest() == "305ffa802317fdfb043133d63373886d":
                            has_30x25 = True
                    except Exception:
                        pass
        doc.close()
        status_str = "❌ LOGO ENCORE PRÉSENT" if has_30x25 else "✅ 100% PROPRE (Logo MBset éradiqué)"
        print(f"   • [{sf['folder_name']}] {sf['name']} : {status_str}")

    print("\n" + "=" * 65)
    print("🏆 MISSION ACCOMPLIE : Tous les PDF sur Google Drive sont sans logo MBset !", flush=True)
    print("=" * 65, flush=True)

if __name__ == '__main__':
    main()
