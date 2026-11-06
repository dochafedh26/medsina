import os
import sys
import json
import re

# Add parent directory to sys.path to import mbset_client
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from mbset_client import MBSetClient

def get_module_cycle(name: str) -> str:
    n = name.lower()
    if "(1 ère)" in n or any(w in n for w in ["chimie", "cytologie", "embryologie", "biostatistique", "ssh"]):
        return "1ère Année (Fondamental)"
    if "(2 ème)" in n or "génétique" in n:
        return "2ème Année (Fondamental)"
    if "(3 éme)" in n or "(3 ème)" in n or any(w in n for w in ["anapathologie", "microbiologie", "parasitologie", "pharmacologie"]):
        return "3ème Année (Pré-clinique)"
    return "Clinique & Concours Résidanat"

def get_module_icon(name: str) -> str:
    n = name.lower()
    if "cardio" in n: return "favorite"
    if "pneumo" in n or "respiratoire" in n: return "air"
    if "neuro" in n: return "psychology"
    if "gastro" in n or "digestive" in n: return "restaurant"
    if "pédiatrie" in n or "pediatrie" in n: return "child_care"
    if "infectieuse" in n or "microbio" in n or "parasito" in n: return "coronavirus"
    if "urgence" in n or "umc" in n: return "emergency"
    if "anat" in n or "locomoteur" in n: return "accessibility_new"
    if "gynéco" in n or "obstétrique" in n: return "pregnant_woman"
    if "ophtalmo" in n: return "visibility"
    if "orl" in n: return "hearing"
    if "uro" in n or "urinaire" in n or "néphro" in n: return "water_drop"
    if "dermato" in n: return "spa"
    if "hemato" in n or "onco" in n: return "bloodtype"
    if "endo" in n: return "medication"
    if "psy" in n: return "self_improvement"
    if "immuno" in n: return "shield"
    if "pharmaco" in n or "biochimie" in n or "chimie" in n: return "science"
    return "school"

def main():
    print("🚀 Connexion au client MBset...")
    client = MBSetClient()
    client.login()

    print("📥 Récupération des catégories et sous-catégories officielles...")
    categories = client.get_categories()
    print(f"✅ {len(categories)} modules officiels trouvés.")

    modules_data = []
    sql_modules = []
    sql_courses = []

    total_courses_count = 0
    total_questions_count = 0

    for idx, cat in enumerate(categories, 1):
        mod_id = cat.get("id")
        mod_name = cat.get("name", "").strip()
        cycle = get_module_cycle(mod_name)
        icon = get_module_icon(mod_name)
        subcategories = cat.get("subcategories", [])

        mod_questions = cat.get("questionsCount", 0)
        total_questions_count += mod_questions
        total_courses_count += len(subcategories)

        courses_list = []
        for c_idx, sub in enumerate(subcategories, 1):
            course_id = sub.get("id")
            course_name = sub.get("name", "").strip()
            course_tag = sub.get("tag", "").strip()
            course_q_count = sub.get("questionsCount", 0)
            order_index = sub.get("orderIndex", c_idx * 10)

            courses_list.append({
                "id": course_id,
                "moduleId": mod_id,
                "name": course_name,
                "tag": course_tag,
                "questionsCount": course_q_count,
                "hasPdf": True,
                "displayOrder": order_index
            })

            clean_cname = course_name.replace("'", "''")
            clean_tag = course_tag.replace("'", "''")
            sql_courses.append(
                f"('{course_id}', '{mod_id}', '{clean_cname}', '{clean_tag}', {course_q_count}, true, {order_index}, 'pending')"
            )

        modules_data.append({
            "id": mod_id,
            "name": mod_name,
            "category": cycle,
            "totalQuestions": mod_questions,
            "totalCourses": len(subcategories),
            "iconName": icon,
            "displayOrder": idx * 10,
            "courses": courses_list
        })

        clean_mname = mod_name.replace("'", "''")
        clean_cycle = cycle.replace("'", "''")
        sql_modules.append(
            f"('{mod_id}', '{clean_mname}', '{clean_cycle}', '{icon}', {idx * 10}, true, {len(subcategories)}, {mod_questions})"
        )

    # 1. Save local JSON cache for Flutter
    output_json = os.path.abspath(os.path.join(os.path.dirname(__file__), "../medsina/assets/data/modules_catalog_47.json"))
    with open(output_json, "w", encoding="utf-8") as f:
        json.dump(modules_data, f, ensure_ascii=False, indent=2)
    print(f"📦 Catalogue JSON exporté: {output_json} ({len(modules_data)} modules, {total_courses_count} cours, {total_questions_count} QCMs)")

    # 2. Write SQL Migration file
    output_sql = os.path.abspath(os.path.join(os.path.dirname(__file__), "seed_modules.sql"))
    with open(output_sql, "w", encoding="utf-8") as f:
        f.write("-- Seed Medical Modules (47 official modules)\n")
        f.write("INSERT INTO public.medical_modules (id, name, category, icon_name, display_order, is_free_preview, total_courses, total_questions)\nVALUES\n")
        f.write(",\n".join(sql_modules))
        f.write("\nON CONFLICT (id) DO UPDATE SET\n")
        f.write("  name = EXCLUDED.name,\n  category = EXCLUDED.category,\n  icon_name = EXCLUDED.icon_name,\n  display_order = EXCLUDED.display_order,\n  total_courses = EXCLUDED.total_courses,\n  total_questions = EXCLUDED.total_questions;\n\n")

        f.write("-- Seed Courses (1 205 official courses)\n")
        # Split into batches of 100 for safety
        batch_size = 100
        for b_start in range(0, len(sql_courses), batch_size):
            batch = sql_courses[b_start : b_start + batch_size]
            f.write("INSERT INTO public.courses (id, module_id, name, tag, questions_count, has_pdf, display_order, sync_status)\nVALUES\n")
            f.write(",\n".join(batch))
            f.write("\nON CONFLICT (id) DO UPDATE SET\n")
            f.write("  name = EXCLUDED.name,\n  tag = EXCLUDED.tag,\n  questions_count = EXCLUDED.questions_count,\n  display_order = EXCLUDED.display_order;\n\n")

    print(f"📝 Fichier SQL généré: {output_sql}")

if __name__ == "__main__":
    main()

