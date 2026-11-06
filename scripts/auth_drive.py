import os
import sys
import subprocess
import webbrowser
from google_auth_oauthlib.flow import InstalledAppFlow

SCOPES = [
    'https://www.googleapis.com/auth/drive.file',
    'https://www.googleapis.com/auth/drive'
]

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
creds_path = os.path.join(ROOT_DIR, 'credentials.json')
token_path = os.path.join(ROOT_DIR, 'token.json')
url_file_path = os.path.join(ROOT_DIR, 'auth_url.txt')

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

class DesktopBrowser(webbrowser.BaseBrowser):
    def open(self, url, new=0, autoraise=True):
        print(f"\n==================================================", flush=True)
        print(f"LIEN D'AUTHENTIFICATION OFFICIEL:\n{url}", flush=True)
        print(f"==================================================\n", flush=True)
        with open(url_file_path, "w", encoding="utf-8") as f:
            f.write(url)
        try:
            subprocess.Popen(f'explorer "{url}"', shell=True)
        except Exception as e:
            print(f"Could not open explorer directly: {e}", flush=True)
        return True

def main():
    print("=== INITIALISATION AUTH GOOGLE DRIVE ===", flush=True)
    if not os.path.exists(creds_path):
        print(f"ERREUR: Fichier introuvable: {creds_path}", flush=True)
        sys.exit(1)

    webbrowser.register('desktop_opener', DesktopBrowser, preferred=True)

    flow = InstalledAppFlow.from_client_secrets_file(creds_path, SCOPES)
    
    port = 8088
    # Using browser='desktop_opener' ensures flow.authorization_url() is called ONLY ONCE by run_local_server
    creds = flow.run_local_server(
        port=port,
        browser='desktop_opener',
        open_browser=True,
        prompt='consent',
        access_type='offline'
    )

    with open(token_path, 'w', encoding='utf-8') as f:
        f.write(creds.to_json())

    if os.path.exists(url_file_path):
        try:
            os.remove(url_file_path)
        except Exception:
            pass

    print("SUCCESS: token.json créé avec succès !", flush=True)

if __name__ == "__main__":
    main()
