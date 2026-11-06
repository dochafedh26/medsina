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

c = Credentials.from_authorized_user_file(token_path, SCOPES)
s = build('drive', 'v3', credentials=c)

target_id = '1___jg3oAyaBm-REwGb68q_XTN5dKWX2E'

print(f"Listing contents inside medsina_ressources ({target_id}):", flush=True)
q = f"'{target_id}' in parents and trashed = false"
res = s.files().list(q=q, pageSize=100, fields="files(id, name, mimeType)").execute()
files = res.get('files', [])
print(f"Total items directly in medsina_ressources: {len(files)}", flush=True)
for f in files:
    print(f" - {f['name']} ({f['mimeType']})", flush=True)

# Also check how many total PDFs exist across the entire drive
print("\nSearching for all PDFs on Google Drive...", flush=True)
res_pdf = s.files().list(q="mimeType = 'application/pdf' and trashed = false", pageSize=100, fields="nextPageToken, files(id, name, size, webViewLink)").execute()
pdfs = res_pdf.get('files', [])
print(f"Total PDFs found in first page: {len(pdfs)}", flush=True)
for p in pdfs[:15]:
    print(f" - PDF: {p['name']} ({p.get('size')} bytes)", flush=True)

