import json
import os
import requests

SUPABASE_URL = "https://qzfssrhhuorljftpdvjm.supabase.co"
ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF6ZnNzcmhodW9ybGpmdHBkdmptIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE2MTI4NTQsImV4cCI6MjEwNzE4ODg1NH0.WnISReehubUWEcO485Ny1w8lIJZsp55QLqdj72hVyec"

def main():
    json_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "../medsina/assets/data/modules_catalog_47.json"))
    with open(json_path, "r", encoding="utf-8") as f:
        modules = json.load(f)

    all_courses = []
    for mod in modules:
        for c in mod.get("courses", []):
            all_courses.append({
                "id": c["id"],
                "module_id": c["moduleId"],
                "name": c["name"],
                "tag": c.get("tag", ""),
                "questions_count": c.get("questionsCount", 0),
                "has_pdf": True,
                "display_order": c.get("displayOrder", 0),
                "sync_status": "pending"
            })

    print(f"Total courses to upload: {len(all_courses)}")

    headers = {
        "apikey": ANON_KEY,
        "Authorization": f"Bearer {ANON_KEY}",
        "Content-Type": "application/json",
        "Prefer": "resolution=merge-duplicates"
    }

    endpoint = f"{SUPABASE_URL}/rest/v1/courses"
    batch_size = 100
    uploaded = 0

    for i in range(0, len(all_courses), batch_size):
        batch = all_courses[i : i + batch_size]
        res = requests.post(endpoint, headers=headers, json=batch, timeout=20)
        if res.status_code in [200, 201]:
            uploaded += len(batch)
            print(f"Uploaded batch {i // batch_size + 1}: {uploaded}/{len(all_courses)} courses")
        else:
            print(f"Error on batch {i}: {res.status_code} - {res.text}")
            break

    print(f"✅ Terminé avec succès: {uploaded} cours insérés dans Supabase.")

if __name__ == "__main__":
    main()

