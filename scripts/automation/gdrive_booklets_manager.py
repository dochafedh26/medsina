#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
=============================================================================
MEDSINA — GESTIONNAIRE GOOGLE DRIVE POUR LES LIVRETS RÉSIDANAT 2027
=============================================================================
Héberge les livrets PDF complets sur le Google Drive officiel (5 To)
de Medsina (dossier 'Livrets_Residanat_2027') pour préserver le quota Supabase.
Rend les fichiers publiquement accessibles en lecture via Google Drive API.
=============================================================================
"""

import os
import sys
import json
import requests
from pathlib import Path
from typing import Dict, Any, Optional, Tuple

if sys.stdout and hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

SCRIPT_DIR = Path(__file__).resolve().parent
WORKSPACE_ROOT = SCRIPT_DIR.parents[1] if len(SCRIPT_DIR.parents) > 1 else SCRIPT_DIR
sys.path.insert(0, str(WORKSPACE_ROOT / "scripts"))

from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

SCOPES = [
    'https://www.googleapis.com/auth/drive.file',
    'https://www.googleapis.com/auth/drive'
]

def find_token_path() -> str:
    candidates = [
        os.path.join(str(WORKSPACE_ROOT), "token.json"),
        os.path.join(str(WORKSPACE_ROOT.parent), "token.json"),
        r"D:\REVISION RESIDANAT\ressources\residanat-blida-2027\token.json",
        os.path.join(os.getcwd(), "token.json"),
    ]
    for c in candidates:
        if os.path.exists(c):
            return c
    return candidates[0]

TOKEN_PATH = find_token_path()
CREDS_PATH = os.path.join(os.path.dirname(TOKEN_PATH), "credentials.json")

KNOWN_MEDSINA_FOLDER_ID = '1___jg3oAyaBm-REwGb68q_XTN5dKWX2E'
LIVRETS_ROOT_FOLDER_NAME = 'Livrets_Residanat_2027'


def get_drive_service():
    """Initialise et authentifie le service Google Drive v3."""
    if not os.path.exists(TOKEN_PATH):
        raise FileNotFoundError(f"token.json introuvable : {TOKEN_PATH}")

    creds = Credentials.from_authorized_user_file(TOKEN_PATH, SCOPES)
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
            with open(TOKEN_PATH, 'w', encoding='utf-8') as f:
                f.write(creds.to_json())
    return build('drive', 'v3', credentials=creds)


def get_or_create_folder(service, folder_name: str, parent_id: str) -> str:
    """Trouve ou crée un sous-dossier dans parent_id."""
    query = f"'{parent_id}' in parents and name = '{folder_name}' and mimeType = 'application/vnd.google-apps.folder' and trashed = false"
    res = service.files().list(q=query, fields='files(id, name)', pageSize=1).execute()
    files = res.get('files', [])
    if files:
        return files[0]['id']

    # Création du dossier
    metadata = {
        'name': folder_name,
        'mimeType': 'application/vnd.google-apps.folder',
        'parents': [parent_id]
    }
    folder = service.files().create(body=metadata, fields='id').execute()
    return folder.get('id')


def get_livrets_folder_id(service) -> str:
    """Récupère ou crée le dossier principal Livrets_Residanat_2027."""
    return get_or_create_folder(service, LIVRETS_ROOT_FOLDER_NAME, KNOWN_MEDSINA_FOLDER_ID)


def upload_booklet_to_gdrive(
    pdf_path: Path,
    module_id: str,
    course_id: str,
    make_public: bool = True
) -> Dict[str, Any]:
    """
    Téléverse le PDF généré sur Google Drive sous Livrets_Residanat_2027 / <module_id>
    Configure les permissions de lecture publique et renvoie les URLs de consultation et de téléchargement.
    """
    service = get_drive_service()
    root_livrets_id = get_livrets_folder_id(service)
    module_folder_id = get_or_create_folder(service, module_id, root_livrets_id)

    file_name = pdf_path.name
    print(f"   ☁️ [Google Drive] Recherche/Téléversement de {file_name} dans Google Drive...")

    # Vérifier si le fichier existe déjà dans ce sous-dossier
    query = f"'{module_folder_id}' in parents and name = '{file_name}' and trashed = false"
    existing = service.files().list(q=query, fields='files(id, name, webViewLink, webContentLink)').execute().get('files', [])

    media = MediaFileUpload(str(pdf_path), mimetype='application/pdf', resumable=True)

    if existing:
        file_id = existing[0]['id']
        print(f"   🔄 [Google Drive] Mise à jour du fichier existant (ID: {file_id})...")
        updated_file = service.files().update(
            fileId=file_id,
            media_body=media,
            fields='id, name, webViewLink, webContentLink'
        ).execute()
    else:
        file_metadata = {
            'name': file_name,
            'parents': [module_folder_id]
        }
        print(f"   ⬆️ [Google Drive] Création du fichier sur Google Drive...")
        updated_file = service.files().create(
            body=file_metadata,
            media_body=media,
            fields='id, name, webViewLink, webContentLink'
        ).execute()
        file_id = updated_file.get('id')

    # Rendre le fichier accessible en lecture publique
    if make_public:
        try:
            service.permissions().create(
                fileId=file_id,
                body={'type': 'anyone', 'role': 'reader'},
                fields='id'
            ).execute()
            print(f"   🔓 [Google Drive] Fichier partagé publiquement en lecture.")
        except Exception as e:
            print(f"   ℹ️ Permission Google Drive : {e}")

    view_link = f"https://drive.google.com/file/d/{file_id}/view?usp=sharing"
    download_link = f"https://drive.google.com/uc?export=download&id={file_id}"

    return {
        "file_id": file_id,
        "file_name": file_name,
        "view_link": view_link,
        "download_link": download_link,
        "folder_id": module_folder_id
    }


def update_course_in_supabase_with_gdrive(
    course_id: str,
    gdrive_link: str,
    file_id: str,
    supabase_url: str,
    supabase_key: str,
    is_hyper: bool,
    residanat_sessions: list,
    qcm_count: int,
    bundle_has_mindmap: bool = True
) -> bool:
    """Met à jour les colonnes bundle_pdf_url et métadonnées dans la table courses (en attente de validation Admin)."""
    headers = {
        "apikey": supabase_key,
        "Authorization": f"Bearer {supabase_key}",
        "Content-Type": "application/json",
        "Prefer": "return=minimal"
    }
    payload = {
        "bundle_pdf_url": gdrive_link,
        "bundle_generated_at": "now()",
        "is_hypertombable": is_hyper,
        "residanat_years": residanat_sessions,
        "qcm_count": qcm_count,
        "bundle_validation_status": "pending_review",
        "bundle_has_mindmap": bundle_has_mindmap,
        "bundle_reviewed_at": None
    }
    url = f"{supabase_url}/rest/v1/courses?id=eq.{course_id}"
    resp = requests.patch(url, headers=headers, json=payload, timeout=15)
    if resp.status_code in (200, 204):
        print(f"   ✅ [Supabase] Cours mis à jour (statut: pending_review) avec le lien Google Drive ({gdrive_link})")
        return True
    else:
        print(f"   ⚠️ [Supabase] Erreur mise à jour cours ({resp.status_code}) : {resp.text}")
        return False


if __name__ == "__main__":
    # Test upload with Cancer du pancréas
    sample_pdf = WORKSPACE_ROOT / "livrets_residanat_2027" / "Blida_HEPATO_GASTRO_ENTEROLOGIE_CANCER_DU_PANCREAS_Livret_Residanat_2027.pdf"
    if not sample_pdf.exists():
        sample_pdf = Path(r"C:\Users\PC-Service\.gemini\antigravity\brain\0752fc32-0933-427d-8738-1205d9f05bcf\Livret_Residanat_2027_Cancer_du_Pancreas.pdf")

    print(f"Testing upload of {sample_pdf} to Google Drive...")
    res = upload_booklet_to_gdrive(
        pdf_path=sample_pdf,
        module_id="Blida_HEPATO_GASTRO_ENTEROLOGIE",
        course_id="Blida_HEPATO_GASTRO_ENTEROLOGIE_CANCER_DU_PANCREAS"
    )
    print("Result:", json.dumps(res, indent=2))
