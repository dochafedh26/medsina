"""
Medsina - Google Drive & Supabase Incremental Sync Pipeline
Indexes existing files in medsina_ressources (courses / qcms) on Google Drive (5TB),
links them automatically to Supabase courses, and tracks sync status.
"""

import os
import sys
import time
import json
import re
import unicodedata
import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build

SCOPES = [
    'https://www.googleapis.com/auth/drive.file',
    'https://www.googleapis.com/auth/drive'
]

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
token_path = os.path.join(ROOT_DIR, 'token.json')
creds_path = os.path.join(ROOT_DIR, 'credentials.json')

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

SUPABASE_URL = "https://qzfssrhhuorljftpdvjm.supabase.co"
ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF6ZnNzcmhodW9ybGpmdHBkdmptIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE2MTI4NTQsImV4cCI6MjEwNzE4ODg1NH0.WnISReehubUWEcO485Ny1w8lIJZsp55QLqdj72hVyec"

KNOWN_MEDSINA_FOLDER_ID = '1___jg3oAyaBm-REwGb68q_XTN5dKWX2E'

# Robust HTTP session with auto-retries
session = requests.Session()
retries = Retry(total=5, backoff_factor=1, status_forcelist=[500, 502, 503, 504])
session.mount('https://', HTTPAdapter(max_retries=retries))

def normalize_text(text: str) -> str:
    """Normalize text for fuzzy matching (remove accents, lowercase, strip punctuation)."""
    if not text:
        return ""
    nfkd = unicodedata.normalize('NFKD', text)
    ascii_text = ''.join([c for c in nfkd if not unicodedata.combining(c)])
    return re.sub(r'[^a-zA-Z0-9]', '', ascii_text).lower()

def get_drive_service():
    """Authenticates and returns the Google Drive v3 API service."""
    if not os.path.exists(token_path):
        print(f"❌ token.json introuvable: {token_path}", flush=True)
        return None
    creds = Credentials.from_authorized_user_file(token_path, SCOPES)
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            print("🔄 Renouvellement du jeton OAuth Google Drive...", flush=True)
            creds.refresh(Request())
            with open(token_path, 'w', encoding='utf-8') as f:
                f.write(creds.to_json())
    return build('drive', 'v3', credentials=creds)

def list_all_files_in_folder_recursive(service, folder_id):
    """Crawl all files recursively inside folder."""
    all_files = []
    folders_to_scan = [folder_id]
    visited_folders = set()

    while folders_to_scan:
        current_folder = folders_to_scan.pop(0)
        if current_folder in visited_folders:
            continue
        visited_folders.add(current_folder)

        page_token = None
        while True:
            q = f"'{current_folder}' in parents and trashed = false"
            res = service.files().list(
                q=q,
                pageSize=100,
                fields='nextPageToken, files(id, name, mimeType, size, webViewLink)',
                pageToken=page_token
            ).execute()
            items = res.get('files', [])
            for item in items:
                if item['mimeType'] == 'application/vnd.google-apps.folder':
                    folders_to_scan.append(item['id'])
                elif item.get('mimeType') == 'application/pdf' or item.get('name', '').endswith('.pdf'):
                    all_files.append(item)
            page_token = res.get('nextPageToken')
            if not page_token:
                break

    return all_files

def update_supabase_course(course_id, drive_file_id, drive_url, file_size):
    """Updates course in Supabase with retry logic."""
    headers = {
        "apikey": ANON_KEY,
        "Authorization": f"Bearer {ANON_KEY}",
        "Content-Type": "application/json",
        "Prefer": "return=minimal"
    }
    payload = {
        "pdf_drive_id": drive_file_id,
        "pdf_url": drive_url,
        "pdf_file_size": int(file_size) if file_size else 0,
        "sync_status": "synced",
        "last_synced_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    }
    url = f"{SUPABASE_URL}/rest/v1/courses?id=eq.{course_id}"
    
    for attempt in range(3):
        try:
            res = session.patch(url, headers=headers, json=payload, timeout=20)
            if res.status_code in [200, 204]:
                return True
        except Exception as e:
            time.sleep(1)
    return False

def fetch_all_supabase_courses():
    """Fetch all courses using pagination."""
    headers = {
        "apikey": ANON_KEY,
        "Authorization": f"Bearer {ANON_KEY}",
    }
    all_courses = []
    offset = 0
    limit = 1000
    while True:
        url = f"{SUPABASE_URL}/rest/v1/courses?select=id,module_id,name,pdf_drive_id,sync_status&limit={limit}&offset={offset}"
        res = session.get(url, headers=headers, timeout=25).json()
        if not res or not isinstance(res, list):
            break
        all_courses.extend(res)
        if len(res) < limit:
            break
        offset += limit
    return all_courses

def update_local_catalog_backup():
    """Exports updated catalog with PDF links to Flutter asset file."""
    headers = {
        "apikey": ANON_KEY,
        "Authorization": f"Bearer {ANON_KEY}",
    }
    try:
        mod_res = session.get(f"{SUPABASE_URL}/rest/v1/medical_modules?select=*&order=display_order.asc", headers=headers, timeout=25).json()
        courses_res = fetch_all_supabase_courses()
        
        # Group courses by module_id
        module_courses = {}
        for c in courses_res:
            m_id = c.get('module_id')
            if m_id not in module_courses:
                module_courses[m_id] = []
            module_courses[m_id].append(c)

        for m in mod_res:
            m['courses'] = module_courses.get(m['id'], [])

        asset_path = os.path.join(ROOT_DIR, "medsina", "assets", "data", "modules_catalog_47.json")
        with open(asset_path, 'w', encoding='utf-8') as f:
            json.dump(mod_res, f, ensure_ascii=False, indent=2)
        print(f"📦 Catalogue hors-ligne mis à jour : {asset_path}", flush=True)
    except Exception as e:
        print(f"⚠️ Erreur mise à jour catalogue local: {e}", flush=True)

def main():
    print("🚀 Démarrage du pipeline d'indexation Google Drive (5 To)...", flush=True)
    service = get_drive_service()
    if not service:
        return

    folder_id = KNOWN_MEDSINA_FOLDER_ID
    print(f"📂 Indexation récursive de 'medsina_ressources' (ID: {folder_id})...", flush=True)
    drive_files = list_all_files_in_folder_recursive(service, folder_id)
    print(f"✅ {len(drive_files)} fichiers PDF trouvés sur Google Drive !", flush=True)

    # Separate course PDFs and QCM PDFs
    course_pdfs = []
    qcm_pdfs = []
    for f in drive_files:
        name = f.get('name', '')
        if '_qcm' in name.lower():
            qcm_pdfs.append(f)
        else:
            course_pdfs.append(f)

    print(f"   • PDF de cours : {len(course_pdfs)}", flush=True)
    print(f"   • PDF de QCMs  : {len(qcm_pdfs)}", flush=True)

    # Fetch all courses from Supabase
    print("\n📥 Récupération du catalogue complet depuis Supabase...", flush=True)
    courses = fetch_all_supabase_courses()
    print(f"📚 {len(courses)} cours au total dans Supabase.", flush=True)

    # Build lookup map of course PDFs by normalized name
    drive_map = {}
    for f in course_pdfs:
        raw_name = f.get('name', '').replace('.pdf', '')
        norm = normalize_text(raw_name)
        if norm:
            drive_map[norm] = f

    matched_count = 0
    already_synced = 0

    print("\n🔗 Liaison des cours restants Supabase <-> Google Drive :", flush=True)
    for c in courses:
        c_name = c.get('name', '')
        c_id = c.get('id', '')
        current_status = c.get('sync_status')
        current_drive_id = c.get('pdf_drive_id')

        norm_name = normalize_text(c_name)

        # Check if already synced
        if current_status == 'synced' and current_drive_id:
            already_synced += 1
            continue

        # Try exact match first
        matched_file = drive_map.get(norm_name)
        
        # Try substring match if not found
        if not matched_file and len(norm_name) > 4:
            for k, f in drive_map.items():
                if norm_name in k or (len(k) > 4 and k in norm_name):
                    matched_file = f
                    break

        if matched_file:
            file_id = matched_file.get('id')
            file_link = matched_file.get('webViewLink') or f"https://drive.google.com/file/d/{file_id}/view"
            file_size = matched_file.get('size', 0)

            if update_supabase_course(c_id, file_id, file_link, file_size):
                matched_count += 1
                print(f"  [+] Relié: {c_name} -> {matched_file.get('name')}", flush=True)
        else:
            if current_status == 'synced':
                already_synced += 1

    print(f"\n" + "="*50, flush=True)
    print(f"🎉 BILAN DE LA SYNCHRONISATION :", flush=True)
    print(f" • Déjà synchronisés auparavant : {already_synced}", flush=True)
    print(f" • Nouveaux cours reliés : {matched_count}", flush=True)
    print(f" • Total cours avec PDF Drive opérationnels : {already_synced + matched_count} / {len(courses)}", flush=True)
    print(f"="*50, flush=True)

    # Update local asset backup so offline mode also benefits
    update_local_catalog_backup()

if __name__ == "__main__":
    main()
