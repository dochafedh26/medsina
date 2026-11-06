"""
Medsina - Google Drive & Supabase Integrated Storage Pipeline
1. Uses Google Drive API (5TB) to store and stream all pedagogical PDFs (Samedis Pédagogiques, Témoignages, Courses).
2. Updates Supabase database (table discovered_blida_resources) with realtime WebSocket notifications.
3. Automatically avoids duplicate uploads by inspecting existing remote file IDs and names.
"""

import os
import sys
import json
import time
import requests
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
TOKEN_PATH = os.path.join(ROOT_DIR, "token.json")
CREDS_PATH = os.path.join(ROOT_DIR, "credentials.json")

SUPABASE_URL = os.getenv("SUPABASE_URL", "https://qzfssrhhuorljftpdvjm.supabase.co")
ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF6ZnNzcmhodW9ybGpmdHBkdmptIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE2MTI4NTQsImV4cCI6MjEwNzE4ODg1NH0.WnISReehubUWEcO485Ny1w8lIJZsp55QLqdj72hVyec"
SERVICE_ROLE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

for env_path in [os.path.join(ROOT_DIR, ".env"), os.path.join(ROOT_DIR, "medsina", ".env")]:
    if not SERVICE_ROLE_KEY and os.path.exists(env_path):
        with open(env_path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line.startswith("SUPABASE_SERVICE_ROLE_KEY="):
                    SERVICE_ROLE_KEY = line.split("=", 1)[1]
                elif line.startswith("SUPABASE_URL="):
                    SUPABASE_URL = line.split("=", 1)[1]

ACTIVE_SUPABASE_KEY = SERVICE_ROLE_KEY if SERVICE_ROLE_KEY else ANON_KEY

KNOWN_MEDSINA_FOLDER_ID = "1___jg3oAyaBm-REwGb68q_XTN5dKWX2E"

SCOPES = [
    "https://www.googleapis.com/auth/drive.file",
    "https://www.googleapis.com/auth/drive"
]

def get_drive_service():
    """Initializes and returns the Google Drive v3 API service."""
    if not os.path.exists(TOKEN_PATH):
        print(f"❌ token.json introuvable : {TOKEN_PATH}")
        return None
    try:
        creds = Credentials.from_authorized_user_file(TOKEN_PATH, SCOPES)
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
            with open(TOKEN_PATH, "w", encoding="utf-8") as f:
                f.write(creds.to_json())
        return build("drive", "v3", credentials=creds)
    except Exception as e:
        print(f"❌ Erreur lors de l'initialisation du service Drive : {e}")
        return None

def find_or_create_subfolder(service, parent_id, folder_name):
    """Finds an existing folder inside parent_id or creates it if absent."""
    q = f"'{parent_id}' in parents and name = '{folder_name}' and mimeType = 'application/vnd.google-apps.folder' and trashed = false"
    res = service.files().list(q=q, fields="files(id, name)").execute()
    files = res.get("files", [])
    if files:
        print(f"📁 Dossier existant sur Google Drive : {folder_name} ({files[0]['id']})")
        return files[0]["id"]

    metadata = {
        "name": folder_name,
        "mimeType": "application/vnd.google-apps.folder",
        "parents": [parent_id]
    }
    created = service.files().create(body=metadata, fields="id, name").execute()
    print(f"📁 Nouveau dossier créé sur Google Drive : {folder_name} ({created['id']})")
    return created["id"]

def get_existing_files_in_folder(service, folder_id):
    """Returns a dict mapping filename -> {id, webViewLink, size}."""
    existing = {}
    page_token = None
    while True:
        res = service.files().list(
            q=f"'{folder_id}' in parents and trashed = false",
            pageSize=100,
            fields="nextPageToken, files(id, name, size, webViewLink)",
            pageToken=page_token
        ).execute()
        for f in res.get("files", []):
            existing[f["name"]] = f
        page_token = res.get("nextPageToken")
        if not page_token:
            break
    return existing

def upload_file_if_not_exists(service, folder_id, local_file_path, existing_files):
    """Uploads a local file to Google Drive folder if not already uploaded (zero duplicate)."""
    filename = os.path.basename(local_file_path)
    if filename in existing_files:
        print(f"  ⚡ Déjà présent sur Drive : {filename} (ID: {existing_files[filename]['id']})")
        return existing_files[filename]

    file_metadata = {
        "name": filename,
        "parents": [folder_id]
    }
    media = MediaFileUpload(local_file_path, mimetype="application/pdf", resumable=True)
    try:
        print(f"  ⬆️ Envoi vers Google Drive : {filename}...", flush=True)
        uploaded = service.files().create(
            body=file_metadata,
            media_body=media,
            fields="id, name, size, webViewLink"
        ).execute()

        try:
            service.permissions().create(
                fileId=uploaded["id"],
                body={"role": "reader", "type": "anyone"}
            ).execute()
        except Exception:
            pass

        print(f"  ✅ Uploadé avec succès : {filename} -> ID: {uploaded['id']}")
        existing_files[filename] = uploaded
        return uploaded
    except Exception as e:
        print(f"  ❌ Erreur upload {filename} : {e}")
        return None

def make_supabase_record(rec_id, title, res_type, origin, url, gdrive_id=None, module_id=None, summary=""):
    return {
        "id": rec_id,
        "title": title,
        "resource_type": res_type,
        "source_type": "google_drive",
        "source_origin": origin,
        "source_url": url,
        "gdrive_file_id": gdrive_id,
        "suggested_module_id": module_id,
        "suggested_course_id": None,
        "study_year": None,
        "ai_summary": summary,
        "status": "approved",
        "discovered_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    }

def sync_to_supabase_realtime(records):
    """Upserts records into Supabase discovered_blida_resources for Realtime broadcast."""
    headers = {
        "apikey": ACTIVE_SUPABASE_KEY,
        "Authorization": f"Bearer {ACTIVE_SUPABASE_KEY}",
        "Content-Type": "application/json",
        "Prefer": "resolution=merge-duplicates"
    }
    url = f"{SUPABASE_URL}/rest/v1/discovered_blida_resources"
    try:
        res = requests.post(url, headers=headers, json=records, timeout=25)
        if res.status_code in [200, 201]:
            print(f"📡 Synchronisation Supabase Realtime réussie ({len(records)} ressources) !")
            return True
        else:
            print(f"⚠️ Erreur sync Supabase : {res.status_code} - {res.text}")
            return False
    except Exception as e:
        print(f"❌ Exception Supabase : {e}")
        return False

def sync_catalog_to_supabase():
    """Syncs existing Samedis Pedagogiques and Temoignages to Supabase."""
    supabase_records = []

    # 1. Samedis Pedagogiques
    sp_json_path = os.path.join(ROOT_DIR, "medsina", "assets", "data", "samedis_pedagogiques.json")
    if os.path.exists(sp_json_path):
        with open(sp_json_path, "r", encoding="utf-8") as f:
            sp_items = json.load(f)
        for it in sp_items:
            supabase_records.append(make_supabase_record(
                rec_id=f"sp_{it['id']}",
                title=f"Samedi Pédagogique : {it['title']}",
                res_type="pdf_course",
                origin="Samedis Pédagogiques Dr KARE & Enseignants",
                url=it.get("gdrive_link") or "https://drive.google.com/drive/folders/1___jg3oAyaBm-REwGb68q_XTN5dKWX2E",
                gdrive_id=it.get("gdrive_id"),
                module_id=it.get("module"),
                summary=it.get("description", "")
            ))

    # 2. Temoignages & Conseils
    tem_json_path = os.path.join(ROOT_DIR, "medsina", "assets", "data", "temoignages_conseils.json")
    if os.path.exists(tem_json_path):
        with open(tem_json_path, "r", encoding="utf-8") as f:
            tem_items = json.load(f)
        for it in tem_items:
            supabase_records.append(make_supabase_record(
                rec_id=f"tem_{it['id']}",
                title=f"Témoignage Major : {it['name']} ({it['rank_badge']})",
                res_type="testimonial_advice",
                origin=it.get("faculty", "Faculté de Médecine"),
                url=it.get("target_url") or "https://drive.google.com/drive/folders/1___jg3oAyaBm-REwGb68q_XTN5dKWX2E",
                gdrive_id=it.get("gdrive_id"),
                summary=it.get("summary", "")
            ))

    if supabase_records:
        return sync_to_supabase_realtime(supabase_records)
    return False

def main():
    print("==================================================")
    print("🚀 MEDSINA CLOUD STORAGE & SUPABASE REALTIME PIPELINE")
    print("==================================================")

    # First, guarantee Supabase sync is active
    print("\n⚡ Phase 1 : Synchronisation du catalogue vers Supabase Realtime...")
    sync_catalog_to_supabase()

    # Second, check Drive connection
    print("\n⚡ Phase 2 : Connexion Google Drive Storage (5TB)...")
    service = get_drive_service()
    if not service:
        print("ℹ️ Google Drive attend l'autorisation. Ouvrez le lien d'authentification pour finaliser le stockage cloud.")
        return

    # Prepare Google Drive folders
    sp_folder_id = find_or_create_subfolder(service, KNOWN_MEDSINA_FOLDER_ID, "02- Samedis Pedagogiques")
    tem_folder_id = find_or_create_subfolder(service, KNOWN_MEDSINA_FOLDER_ID, "01- Temoignages et Conseils")

    existing_sp_files = get_existing_files_in_folder(service, sp_folder_id)
    existing_tem_files = get_existing_files_in_folder(service, tem_folder_id)

    # Upload Samedis Pedagogiques
    sp_local_dir = os.path.join(ROOT_DIR, "medsina", "assets", "data", "samedis_pedagogiques")
    sp_json_path = os.path.join(ROOT_DIR, "medsina", "assets", "data", "samedis_pedagogiques.json")
    if os.path.exists(sp_json_path):
        with open(sp_json_path, "r", encoding="utf-8") as f:
            sp_items = json.load(f)
        print(f"\n📂 Upload des Samedis Pédagogiques ({len(sp_items)} items)...")
        updated_sp = False
        for item in sp_items:
            pdf_name = item.get("pdf_file")
            if not pdf_name:
                continue
            local_path = os.path.join(sp_local_dir, pdf_name)
            if os.path.exists(local_path):
                file_info = upload_file_if_not_exists(service, sp_folder_id, local_path, existing_sp_files)
                if file_info:
                    item["gdrive_id"] = file_info.get("id")
                    item["gdrive_link"] = file_info.get("webViewLink") or f"https://drive.google.com/file/d/{file_info['id']}/view?usp=sharing"
                    updated_sp = True
        if updated_sp:
            with open(sp_json_path, "w", encoding="utf-8") as f:
                json.dump(sp_items, f, ensure_ascii=False, indent=2)

    # Upload Temoignages & Conseils
    tem_local_dir = os.path.join(ROOT_DIR, "medsina", "assets", "data", "temoignages")
    tem_json_path = os.path.join(ROOT_DIR, "medsina", "assets", "data", "temoignages_conseils.json")
    if os.path.exists(tem_json_path):
        with open(tem_json_path, "r", encoding="utf-8") as f:
            tem_items = json.load(f)
        print(f"\n📂 Upload des Témoignages & Conseils ({len(tem_items)} items)...")
        updated_tem = False
        for item in tem_items:
            for field in ["pdf_file", "extra_pdf_file"]:
                pdf_name = item.get(field)
                if not pdf_name:
                    continue
                local_path = os.path.join(tem_local_dir, pdf_name)
                if os.path.exists(local_path):
                    file_info = upload_file_if_not_exists(service, tem_folder_id, local_path, existing_tem_files)
                    if file_info:
                        link = file_info.get("webViewLink") or f"https://drive.google.com/file/d/{file_info['id']}/view?usp=sharing"
                        if field == "pdf_file":
                            item["gdrive_id"] = file_info.get("id")
                            if not item.get("target_url") or item.get("document_type") == "pdf_local":
                                item["target_url"] = link
                                item["document_type"] = "pdf_local_and_drive"
                        else:
                            item["extra_gdrive_id"] = file_info.get("id")
                            item["extra_gdrive_link"] = link
                        updated_tem = True
        if updated_tem:
            with open(tem_json_path, "w", encoding="utf-8") as f:
                json.dump(tem_items, f, ensure_ascii=False, indent=2)

    # Re-sync updated links to Supabase Realtime
    print("\n⚡ Re-synchronisation des liens Drive finaux vers Supabase Realtime...")
    sync_catalog_to_supabase()

    print("\n🎉 Opération terminée avec succès !")

if __name__ == "__main__":
    main()
