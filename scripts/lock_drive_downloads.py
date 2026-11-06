"""
Applies copyRequiresWriterPermission=True to all files in medsina_ressources.
This prevents viewers from downloading, printing, or copying the files from Google Drive.
"""
import os
import sys
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build

SCOPES = [
    'https://www.googleapis.com/auth/drive.file',
    'https://www.googleapis.com/auth/drive'
]

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
token_path = os.path.join(ROOT_DIR, 'token.json')

if not os.path.exists(token_path):
    print("token.json introuvable.")
    sys.exit(1)

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

creds = Credentials.from_authorized_user_file(token_path, SCOPES)
service = build('drive', 'v3', credentials=creds)

target_folder_id = '1___jg3oAyaBm-REwGb68q_XTN5dKWX2E'
print(f"🔒 Verrouillage du téléchargement/copie sur les fichiers Google Drive...", flush=True)

# List all PDF files in medsina_ressources
folders_to_scan = [target_folder_id]
pdf_files = []
while folders_to_scan:
    folder = folders_to_scan.pop(0)
    page_token = None
    while True:
        res = service.files().list(
            q=f"'{folder}' in parents and trashed = false",
            pageSize=100,
            fields="nextPageToken, files(id, name, mimeType, copyRequiresWriterPermission)",
            pageToken=page_token
        ).execute()
        for f in res.get('files', []):
            if f['mimeType'] == 'application/vnd.google-apps.folder':
                folders_to_scan.append(f['id'])
            elif f.get('mimeType') == 'application/pdf' or f.get('name', '').endswith('.pdf'):
                if not f.get('copyRequiresWriterPermission'):
                    pdf_files.append(f)
        page_token = res.get('nextPageToken')
        if not page_token:
            break

print(f"📄 {len(pdf_files)} fichiers à verrouiller anti-téléchargement...", flush=True)

locked_count = 0
for f in pdf_files:
    try:
        service.files().update(
            fileId=f['id'],
            body={'copyRequiresWriterPermission': True}
        ).execute()
        locked_count += 1
    except Exception:
        pass

print(f"✅ Protection anti-téléchargement appliquée avec succès sur {locked_count} fichiers !")
