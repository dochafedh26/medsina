import os
import urllib.request
import json

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SUPABASE_URL = os.getenv('SUPABASE_URL', 'https://qzfssrhhuorljftpdvjm.supabase.co')
SUPABASE_KEY = os.getenv('SUPABASE_SERVICE_ROLE_KEY', '')

for env_candidate in [os.path.join(ROOT_DIR, '.env'), os.path.join(ROOT_DIR, 'medsina', '.env')]:
    if not SUPABASE_KEY and os.path.exists(env_candidate):
        with open(env_candidate, 'r', encoding='utf-8') as f:
            for line in f:
                line = line.strip()
                if line.startswith('SUPABASE_SERVICE_ROLE_KEY='):
                    SUPABASE_KEY = line.split('=', 1)[1].strip()
                elif line.startswith('SUPABASE_URL='):
                    SUPABASE_URL = line.split('=', 1)[1].strip()


req = urllib.request.Request(
    f'{SUPABASE_URL}/rest/v1/admin_system_settings?select=setting_key,setting_value',
    headers={'apikey': SUPABASE_KEY, 'Authorization': f'Bearer {SUPABASE_KEY}'}
)
with urllib.request.urlopen(req, timeout=10) as resp:
    data = json.loads(resp.read().decode('utf-8'))
for r in data:
    k = r.get('setting_key', '')
    if any(x in k.lower() for x in ['fb', 'facebook', 'telegram', 'token']):
        val = r.get('setting_value', '')
        print(f"{k}: {'SET (' + str(len(val)) + ' chars)' if val else 'EMPTY'}")

