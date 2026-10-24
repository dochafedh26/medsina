import requests
import json
import re
from pathlib import Path

content = Path('medsina/.env').read_text(encoding='utf-8')
m = re.search(r'SUPABASE_SERVICE_ROLE_KEY\s*=\s*[\'"]?([^\'"\r\n]+)[\'"]?', content)
key = m.group(1).strip()
url = 'https://qzfssrhhuorljftpdvjm.supabase.co/rest/v1/subscription_plans'

etudiant_plan = {
    "id": "etudiant",
    "name": "Pass Étudiant (1ère - 6ème)",
    "badge": "CURSUS UNIVERSITAIRE",
    "price_yearly": 3500.0,
    "price_monthly": 500.0,
    "currency": "DZD",
    "discount_percent": 25,
    "is_active": True,
    "features": [
        "Programme personnalisé selon votre année d'étude (1ère à 6ème)",
        "Banque QCMs d'examens ultérieurs & EMD de Faculté",
        "Exclusion des pièges hors-programme du résidanat",
        "Fiches de cours & résumés officiels de l'année",
        "Mode révision semestrielle & partiels"
    ]
}

res = requests.post(
    url,
    headers={
        'apikey': key,
        'Authorization': f'Bearer {key}',
        'Content-Type': 'application/json',
        'Prefer': 'resolution=merge-duplicates'
    },
    json=etudiant_plan
)
print('Status:', res.status_code, res.text)
