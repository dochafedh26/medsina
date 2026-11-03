#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
=============================================================================
MEDSINA — NETTOYEUR OFFICIEL DE LA BIBLIOTHÈQUE MÉDICALE (QCMS & COURS)
=============================================================================
Nettoie directement à la source l'ensemble des fichiers de la bibliothèque :
1. Les 53 fichiers JSON de QCMs (assets/data/qcms/*.json) : ~19 300 QCMs
   - Suppression des balises HTML parasites (span, font, div, table, td...)
   - Normalisation des balises <b>, <i>, <strong>, <em>
   - Équilibrage et fermeture automatique des balises non fermées
   - Correction des symboles mathématiques et seuils cliniques (<20 -> < 20)
   - Normalisation des entités HTML (&nbsp;, &rsquo;, &quot;, &amp;...)
   - Remplacement des indices/exposants chimiques par unicode (H₂O, CO₂...)
2. Le fichier course_summaries.json (fiches de synthèse, points clés, pièges)
3. La table Supabase 'course_summaries' pour synchroniser le Cloud !

Grâce à ce nettoyage global, le générateur de livret ReportLab et l'application
Flutter n'ont plus besoin d'altérer ou de réparer le texte à la volée !
=============================================================================
"""

import os
import sys
import glob
import json
import html
import re
import requests
from pathlib import Path
from typing import Dict, Any, List, Optional

if sys.stdout and hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

SCRIPT_DIR = Path(__file__).resolve().parent
WORKSPACE_ROOT = SCRIPT_DIR.parents[1] if len(SCRIPT_DIR.parents) > 1 else SCRIPT_DIR
sys.path.insert(0, str(SCRIPT_DIR))

from booklet_notification_broadcaster import get_credentials

def get_assets_data_dir() -> Path:
    candidates = [
        WORKSPACE_ROOT / "assets" / "data",
        WORKSPACE_ROOT / "medsina" / "assets" / "data",
        Path("assets/data"),
        Path("medsina/assets/data"),
        SCRIPT_DIR.parents[1] / "assets" / "data",
    ]
    for c in candidates:
        if c.exists() and (c / "qcms").exists():
            return c
    return candidates[0]

DATA_DIR = get_assets_data_dir()
QCMS_DIR = DATA_DIR / "qcms"
SUMMARIES_FILE = DATA_DIR / "course_summaries.json"

# Remplacements d'indices et exposants fréquents en médecine
UNICODE_SUBSCRIPTS = {
    "0": "₀", "1": "₁", "2": "₂", "3": "₃", "4": "₄",
    "5": "₅", "6": "₆", "7": "₇", "8": "₈", "9": "₉",
    "+": "₊", "-": "₋"
}
UNICODE_SUPERSCRIPTS = {
    "0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴",
    "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹",
    "+": "⁺", "-": "⁻"
}


def clean_medical_text(text: Any) -> str:
    """Nettoie en profondeur une chaîne de caractères médicale."""
    if text is None:
        return ""
    t = str(text)
    if not t.strip():
        return ""

    # 1. Décoder les entités HTML courantes
    t = t.replace("&nbsp;", " ").replace("\xa0", " ")
    t = t.replace("&rsquo;", "'").replace("&lsquo;", "'")
    t = t.replace("&rdquo;", '"').replace("&ldquo;", '"')
    t = t.replace("&quot;", '"').replace("&#39;", "'")
    t = t.replace("&ndash;", "–").replace("&mdash;", "—")
    t = t.replace("&hellip;", "...")
    t = t.replace("&bull;", "•")
    t = t.replace("&ge;", "≥").replace("&le;", "≤")
    t = t.replace("&gt;", ">").replace("&lt;", "<")

    # 2. Remplacer les indices et exposants par de l'Unicode propre
    def sub_repl(m):
        content = m.group(1).strip()
        return "".join(UNICODE_SUBSCRIPTS.get(c, c) for c in content)

    def sup_repl(m):
        content = m.group(1).strip()
        return "".join(UNICODE_SUPERSCRIPTS.get(c, c) for c in content)

    t = re.sub(r'<sub[^>]*>(.*?)</sub>', sub_repl, t, flags=re.IGNORECASE)
    t = re.sub(r'<sup[^>]*>(.*?)</sup>', sup_repl, t, flags=re.IGNORECASE)

    # 3. Corriger les comparaisons mathématiques collées aux chiffres (<20 -> < 20, >50 -> > 50)
    # afin que les parsers XML ne les prennent pas pour des balises
    t = re.sub(r'<([0-9])', r'< \1', t)
    t = re.sub(r'>([0-9])', r'> \1', t)
    t = re.sub(r'<=([0-9])', r'≤ \1', t)
    t = re.sub(r'>=([0-9])', r'≥ \1', t)
    t = re.sub(r'<([a-zA-Z]{1,2}[0-9])', r'< \1', t)

    # 4. Normaliser les balises de mise en gras et italique
    t = re.sub(r'<strong[^>]*>', '<b>', t, flags=re.IGNORECASE)
    t = re.sub(r'</strong>', '</b>', t, flags=re.IGNORECASE)
    t = re.sub(r'<em[^>]*>', '<i>', t, flags=re.IGNORECASE)
    t = re.sub(r'</em>', '</i>', t, flags=re.IGNORECASE)

    # 5. Remplacer les sauts de ligne HTML par de vrais retours à la ligne
    t = re.sub(r'<br\s*/?>', '\n', t, flags=re.IGNORECASE)

    # 6. Supprimer toutes les autres balises HTML parasites (span, font, div, table, td...)
    unwanted_tags = [
        'span', 'font', 'div', 'p', 'table', 'tr', 'td', 'th',
        'tbody', 'thead', 'tfoot', 'li', 'ul', 'ol', 'u', 'code',
        'section', 'article', 'header', 'footer', 'small', 'big',
        'center', 'hr'
    ]
    for tag in unwanted_tags:
        t = re.sub(rf'</?{tag}[^>]*>', ' ', t, flags=re.IGNORECASE)

    # 7. Équilibrer et fermer les balises <b> et <i> si ouvertes mais non fermées
    # Compter les occurrences
    open_b = len(re.findall(r'<b>', t, flags=re.IGNORECASE))
    close_b = len(re.findall(r'</b>', t, flags=re.IGNORECASE))
    if open_b > close_b:
        t += '</b>' * (open_b - close_b)
    elif close_b > open_b:
        # Enlever les fermetures orphelines en début
        while t.count('</b>') > t.count('<b>'):
            t = t.replace('</b>', '', 1)

    open_i = len(re.findall(r'<i>', t, flags=re.IGNORECASE))
    close_i = len(re.findall(r'</i>', t, flags=re.IGNORECASE))
    if open_i > close_i:
        t += '</i>' * (open_i - close_i)
    elif close_i > open_i:
        while t.count('</i>') > t.count('<i>'):
            t = t.replace('</i>', '', 1)

    # 8. Supprimer les balises vides <b></b> ou <i></i>
    t = re.sub(r'<b>\s*</b>', '', t, flags=re.IGNORECASE)
    t = re.sub(r'<i>\s*</i>', '', t, flags=re.IGNORECASE)

    # 9. Nettoyer les espaces multiples et sauts de ligne excessifs
    t = re.sub(r'[ \t]+', ' ', t)
    t = re.sub(r'\n\s*\n+', '\n\n', t)

    return t.strip()


def clean_qcms_library() -> Dict[str, Any]:
    """Nettoie l'intégralité des 53 fichiers JSON de QCMs."""
    print("=" * 70)
    print("🧹 ÉTAPE 1 : NETTOYAGE DES FICHIERS QCMS (assets/data/qcms/*.json)")
    print("=" * 70)

    json_files = sorted(list(QCMS_DIR.glob("*.json")))
    if not json_files:
        print(f"⚠️ Aucun fichier JSON trouvé dans {QCMS_DIR}")
        return {"files_cleaned": 0, "qcms_cleaned": 0}

    total_files = len(json_files)
    total_qcms = 0
    total_modified = 0

    for i, file_path in enumerate(json_files, 1):
        try:
            with open(file_path, "r", encoding="utf-8") as f:
                qcms = json.load(f)
        except Exception as e:
            print(f"❌ Erreur lecture {file_path.name}: {e}")
            continue

        file_modified = False
        for q in qcms:
            total_qcms += 1
            # Nettoyer question
            if "question" in q:
                c_q = clean_medical_text(q["question"])
                if c_q != q["question"]:
                    q["question"] = c_q
                    file_modified = True
                    total_modified += 1

            # Nettoyer clinical_case
            if q.get("clinical_case"):
                c_case = clean_medical_text(q["clinical_case"])
                if c_case != q["clinical_case"]:
                    q["clinical_case"] = c_case
                    file_modified = True

            # Nettoyer explanation
            if q.get("explanation"):
                c_exp = clean_medical_text(q["explanation"])
                if c_exp != q["explanation"]:
                    q["explanation"] = c_exp
                    file_modified = True

            # Nettoyer options
            if "options" in q and isinstance(q["options"], list):
                for opt in q["options"]:
                    if isinstance(opt, dict) and "text" in opt:
                        c_opt = clean_medical_text(opt["text"])
                        if c_opt != opt["text"]:
                            opt["text"] = c_opt
                            file_modified = True

        if file_modified:
            with open(file_path, "w", encoding="utf-8") as f:
                json.dump(qcms, f, indent=2, ensure_ascii=False)
            print(f"   [{i}/{total_files}] ✅ {file_path.name} nettoyé ({len(qcms)} QCMs)")
        else:
            print(f"   [{i}/{total_files}] 🆗 {file_path.name} déjà propre ({len(qcms)} QCMs)")

    print(f"\n📊 Bilan Nettoyage QCMs :")
    print(f"• Fichiers traités : {total_files}")
    print(f"• QCMs vérifiés   : {total_qcms}")
    print(f"• QCMs assainis   : {total_modified}")

    return {
        "total_files": total_files,
        "total_qcms": total_qcms,
        "total_modified": total_modified
    }


def clean_course_summaries_library() -> Dict[str, Any]:
    """Nettoie le fichier local course_summaries.json et synchronise Supabase."""
    print("\n" + "=" * 70)
    print("🧹 ÉTAPE 2 : NETTOYAGE DES FICHES DE SYNTHÈSE (course_summaries.json)")
    print("=" * 70)

    if not SUMMARIES_FILE.exists():
        print(f"⚠️ Fichier introuvable : {SUMMARIES_FILE}")
        return {"summaries_cleaned": 0}

    with open(SUMMARIES_FILE, "r", encoding="utf-8") as f:
        summaries = json.load(f)

    cleaned_count = 0
    cleaned_list = []

    for item in summaries:
        cid = item.get("course_id") or item.get("courseId")
        # Nettoyer markdown
        if item.get("summary_markdown"):
            item["summary_markdown"] = clean_medical_text(item["summary_markdown"])

        # Nettoyer key takeaways
        if item.get("key_takeaways") and isinstance(item["key_takeaways"], list):
            item["key_takeaways"] = [clean_medical_text(k) for k in item["key_takeaways"]]

        # Nettoyer exam traps
        if item.get("exam_traps") and isinstance(item["exam_traps"], list):
            item["exam_traps"] = [clean_medical_text(t) for t in item["exam_traps"]]

        # Nettoyer diagnostic & traitement
        if item.get("diagnostic_criteria"):
            item["diagnostic_criteria"] = clean_medical_text(item["diagnostic_criteria"])
        if item.get("treatment_summary"):
            item["treatment_summary"] = clean_medical_text(item["treatment_summary"])

        cleaned_count += 1
        cleaned_list.append(item)

    # Sauvegarder le JSON local
    with open(SUMMARIES_FILE, "w", encoding="utf-8") as f:
        json.dump(cleaned_list, f, indent=2, ensure_ascii=False)
    print(f"✅ {cleaned_count} fiches de synthèses nettoyées et enregistrées dans {SUMMARIES_FILE.name}")

    # Synchroniser Supabase Cloud
    print("\n☁️ Synchronisation Supabase de la table course_summaries...")
    supabase_url, supabase_key = get_credentials()
    headers = {
        "apikey": supabase_key,
        "Authorization": f"Bearer {supabase_key}",
        "Content-Type": "application/json",
        "Prefer": "resolution=merge-duplicates"
    }

    sync_success = 0
    for cs in cleaned_list:
        cid = cs.get("course_id")
        if not cid:
            continue
        row = {
            "course_id": cid,
            "course_name": cs.get("course_name") or cid,
            "module_id": cs.get("module_id") or "General",
            "module_name": cs.get("module_name") or cs.get("module_id") or "General",
            "summary_markdown": cs.get("summary_markdown"),
            "key_takeaways": cs.get("key_takeaways"),
            "exam_traps": cs.get("exam_traps"),
            "diagnostic_criteria": cs.get("diagnostic_criteria"),
            "treatment_summary": cs.get("treatment_summary"),
            "updated_at": "now()"
        }
        try:
            r = requests.post(
                f"{supabase_url}/rest/v1/course_summaries",
                headers=headers,
                json=row,
                timeout=10
            )
            if r.status_code in (200, 201, 204):
                sync_success += 1
        except Exception:
            pass

    print(f"✅ Synchronisation Supabase terminée : {sync_success}/{len(cleaned_list)} fiches à jour.")

    return {
        "summaries_cleaned": cleaned_count,
        "supabase_synced": sync_success
    }


def main():
    print("🚀 MEDSINA — DÉMARRAGE DU GRAND NETTOYAGE DE LA BIBLIOTHÈQUE")
    res_qcms = clean_qcms_library()
    res_summaries = clean_course_summaries_library()

    print("\n" + "=" * 70)
    print("🎉 LA BIBLIOTHÈQUE EST DÉSORMAIS INTÉGRALEMENT PROPRE ET OPTIMISÉE !")
    print(f"• Total QCMs assainis : {res_qcms.get('total_modified')} / {res_qcms.get('total_qcms')}")
    print(f"• Fiches de synthèse : {res_summaries.get('summaries_cleaned')} nettoyées")
    print("=" * 70)


if __name__ == "__main__":
    main()
