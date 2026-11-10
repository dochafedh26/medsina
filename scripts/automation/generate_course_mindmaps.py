#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
=============================================================================
MEDSINA — GÉNÉRATEUR OFFICIEL DE MIND MAPS MÉDICALES « RÉSIDANAT 2027 »
=============================================================================
Crée une Carte Mentale Visuelle Vectorielle HD (Format Paysage) pour chaque
cours officiel du programme du Résidanat en Algérie (Faculté de Blida).

Fonctionnalités :
1. Extraction et structuration des branches cliniques (Physiopathologie,
   Démarche Diagnostique, Arbre Décisionnel, Traitements d'Urgence, Ordonnance
   au Long Cours, Pièges Concours / High-Yield).
2. Génération d'un PDF Vectoriel ReportLab au format Paysage A3/A4 avec nœuds
   arrondis, connecteurs courbes, badges de couleur et typographie soignée.
3. Exportation d'un fichier JSON interactif pour le composant Flutter Mind Map.
4. Téléversement automatique sur Google Drive (dossier 'Mindmaps_Residanat_2027')
   avec partage public en lecture seule et streaming direct.
5. Mise à jour de la bibliothèque Medsina (Supabase & assets locaux).
=============================================================================
"""

import os
import re
import sys
import json
import time
import argparse
import subprocess
import requests
from pathlib import Path
from typing import Dict, Any, List, Optional, Tuple

# Fix Windows console UTF-8 output
if sys.stdout and hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

# ReportLab Graphics & Canvas
from reportlab.lib.pagesizes import A3, A4, landscape
from reportlab.lib import colors
from reportlab.pdfgen import canvas
from reportlab.lib.units import mm, inch

SCRIPT_DIR = Path(__file__).resolve().parent
WORKSPACE_ROOT = SCRIPT_DIR.parents[1] if len(SCRIPT_DIR.parents) > 1 else SCRIPT_DIR

GDRIVE_MINDMAPS_FOLDER_ID = os.getenv("GDRIVE_MINDMAPS_FOLDER_ID", "1N0FwWtB1i9SDP8LVE0RqcFmx7chckTeC")
CATALOG_PATH = WORKSPACE_ROOT / "assets" / "data" / "modules_catalog_47.json"
SUMMARIES_PATH = WORKSPACE_ROOT / "assets" / "data" / "course_summaries.json"
MINDMAPS_JSON_PATH = WORKSPACE_ROOT / "assets" / "data" / "course_mindmaps.json"
OUTPUT_DIR = WORKSPACE_ROOT / "assets" / "mindmaps"

# Palette Graphique Medsina 2027
COLOR_BG = colors.HexColor("#0B132B")
COLOR_HEADER_BG = colors.HexColor("#1C2541")
COLOR_CARD_DARK = colors.HexColor("#1E293B")
COLOR_BORDER = colors.HexColor("#334155")
COLOR_WHITE = colors.HexColor("#FFFFFF")
COLOR_MUTED = colors.HexColor("#94A3B8")
COLOR_GOLD = colors.HexColor("#F59E0B")
COLOR_TEAL = colors.HexColor("#0D9488")
COLOR_CYAN = colors.HexColor("#0284C7")
COLOR_CRIMSON = colors.HexColor("#EF4444")
COLOR_EMERALD = colors.HexColor("#10B981")
COLOR_PURPLE = colors.HexColor("#8B5CF6")
COLOR_AMBER = colors.HexColor("#D97706")

BRANCH_THEMES = [
    {
        "name": "Physiopathologie & Définition",
        "border": colors.HexColor("#0284C7"),
        "bg": colors.HexColor("#0F172A"),
        "header_bg": colors.HexColor("#0369A1"),
        "badge_bg": colors.HexColor("#38BDF8"),
        "text_color": colors.HexColor("#F0F9FF"),
        "icon": "🔬"
    },
    {
        "name": "Démarche Diagnostique & ECG",
        "border": colors.HexColor("#8B5CF6"),
        "bg": colors.HexColor("#0F172A"),
        "header_bg": colors.HexColor("#6D28D9"),
        "badge_bg": colors.HexColor("#A78BFA"),
        "text_color": colors.HexColor("#F5F3FF"),
        "icon": "🩺"
    },
    {
        "name": "Arbre Décisionnel de Reperfusion",
        "border": colors.HexColor("#EF4444"),
        "bg": colors.HexColor("#0F172A"),
        "header_bg": colors.HexColor("#B91C1C"),
        "badge_bg": colors.HexColor("#F87171"),
        "text_color": colors.HexColor("#FEF2F2"),
        "icon": "⚡"
    },
    {
        "name": "Thérapeutique d'Urgence",
        "border": colors.HexColor("#10B981"),
        "bg": colors.HexColor("#0F172A"),
        "header_bg": colors.HexColor("#047857"),
        "badge_bg": colors.HexColor("#34D399"),
        "text_color": colors.HexColor("#ECFDF5"),
        "icon": "💊"
    },
    {
        "name": "Traitement Long Cours (BASIC)",
        "border": colors.HexColor("#0D9488"),
        "bg": colors.HexColor("#0F172A"),
        "header_bg": colors.HexColor("#0F766E"),
        "badge_bg": colors.HexColor("#2DD4BF"),
        "text_color": colors.HexColor("#F0FDFA"),
        "icon": "📋"
    },
    {
        "name": "Pièges Concours & High-Yield",
        "border": colors.HexColor("#F59E0B"),
        "bg": colors.HexColor("#0F172A"),
        "header_bg": colors.HexColor("#B45309"),
        "badge_bg": colors.HexColor("#FBBF24"),
        "text_color": colors.HexColor("#FFFBEB"),
        "icon": "⚠️"
    }
]


def load_course_summary(course_id: str) -> Optional[Dict[str, Any]]:
    """Charge les données synthétiques d'un cours depuis le fichier JSON."""
    if not SUMMARIES_PATH.exists():
        return None
    try:
        with open(SUMMARIES_PATH, "r", encoding="utf-8") as f:
            summaries = json.load(f)
        for s in summaries:
            if s.get("course_id") == course_id:
                return s
    except Exception as e:
        print(f"Erreur lecture summaries: {e}")
    return None


def extract_mindmap_structure(summary: Dict[str, Any]) -> Dict[str, Any]:
    """Parse le résumé médical pour construire une arborescence Mind Map riche."""
    course_id = summary.get("course_id", "")
    course_name = summary.get("course_name", "Cours Médical")
    module_name = summary.get("module_name", "Cardiologie")
    markdown_text = summary.get("summary_markdown", "")
    key_takeaways = summary.get("key_takeaways", [])
    exam_traps = summary.get("exam_traps", [])
    diag = summary.get("diagnostic_criteria", "")
    treat = summary.get("treatment_summary", "")

    # Découpage du markdown par sections
    sections = re.split(r'\n(?=##\s+)', markdown_text)
    branches = []

    for idx, sec in enumerate(sections):
        if not sec.strip():
            continue
        lines = sec.strip().split("\n")
        raw_title = lines[0].replace("#", "").strip()
        # Supprime la numérotation initiale éventuelle
        clean_title = re.sub(r'^\d+[\.\)]\s*', '', raw_title)
        
        items = []
        for l in lines[1:]:
            l_clean = l.strip()
            if l_clean.startswith("- ") or l_clean.startswith("* ") or l_clean.startswith("• "):
                item_text = l_clean[2:].strip()
                # Nettoyer un peu le markdown
                item_text = item_text.replace("**", "").replace("*", "")
                if item_text:
                    items.append(item_text)
            elif l_clean.startswith("1.") or l_clean.startswith("2.") or l_clean.startswith("3.") or l_clean.startswith("4.") or l_clean.startswith("5."):
                item_text = l_clean[2:].strip().replace("**", "").replace("*", "")
                if item_text:
                    items.append(item_text)

        theme = BRANCH_THEMES[idx % len(BRANCH_THEMES)]
        branches.append({
            "title": clean_title,
            "theme_index": idx % len(BRANCH_THEMES),
            "items": items[:5]  # Prendre les 5 items les plus percutants
        })

    # Si nous avons des pièges et points clés, assurons-nous qu'ils sont bien en branches
    if exam_traps and not any("Piège" in b["title"] for b in branches):
        clean_traps = [t.replace("**", "").replace("*", "") for t in exam_traps[:4]]
        branches.append({
            "title": "Pièges Concours & Vigilance Annales",
            "theme_index": 5,
            "items": clean_traps
        })

    if key_takeaways and not any("Clé" in b["title"] or "Takeaway" in b["title"] for b in branches):
        clean_keys = [k.replace("**", "").replace("*", "") for k in key_takeaways[:4]]
        branches.append({
            "title": "Points Clés Incontournables",
            "theme_index": 4,
            "items": clean_keys
        })

    return {
        "course_id": course_id,
        "course_name": course_name,
        "module_name": module_name,
        "diagnostic_criteria": diag,
        "treatment_summary": treat,
        "branches": branches
    }


def draw_rounded_rect(c: canvas.Canvas, x: float, y: float, w: float, h: float, r: float, fill_color, stroke_color, stroke_width: float = 1):
    c.saveState()
    c.setFillColor(fill_color)
    c.setStrokeColor(stroke_color)
    c.setLineWidth(stroke_width)
    c.roundRect(x, y, w, h, r, stroke=1 if stroke_width > 0 else 0, fill=1)
    c.restoreState()


def wrap_text(text: str, max_chars: int) -> List[str]:
    """Découpe proprement le texte en lignes sans couper les mots."""
    words = text.split()
    lines = []
    current_line = []
    current_len = 0

    for word in words:
        if current_len + len(word) + 1 <= max_chars:
            current_line.append(word)
            current_len += len(word) + 1
        else:
            if current_line:
                lines.append(" ".join(current_line))
            current_line = [word]
            current_len = len(word)
    if current_line:
        lines.append(" ".join(current_line))
    return lines


def generate_mindmap_pdf(mindmap_data: Dict[str, Any], output_pdf_path: Path) -> Path:
    """Génère le PDF vectoriel grand format (Paysage A3) de la Mind Map."""
    output_pdf_path.parent.mkdir(parents=True, exist_ok=True)

    # Format A3 Paysage pour lisibilité optimale
    width, height = landscape(A3)
    c = canvas.Canvas(str(output_pdf_path), pagesize=(width, height))

    # 1. Arrière-plan stylé
    c.saveState()
    c.setFillColor(COLOR_BG)
    c.rect(0, 0, width, height, fill=1, stroke=0)

    # Grille subtile d'arrière-plan (lignes fines d'ingénierie médicale)
    c.setStrokeColor(colors.HexColor("#131D3B"))
    c.setLineWidth(0.5)
    step = 40
    for x in range(0, int(width), step):
        c.line(x, 0, x, height)
    for y in range(0, int(height), step):
        c.line(0, y, width, y)
    c.restoreState()

    # 2. Header & Banner Supérieur
    header_h = 70
    draw_rounded_rect(c, 25, height - header_h - 20, width - 50, header_h, 12, COLOR_HEADER_BG, COLOR_BORDER, 1.5)

    # Badge de gauche : Medsina 2027
    draw_rounded_rect(c, 45, height - 72, 140, 34, 8, COLOR_TEAL, COLOR_TEAL, 0)
    c.setFillColor(COLOR_WHITE)
    c.setFont("Helvetica-Bold", 13)
    c.drawCentredString(115, height - 51, "MEDSINA 2027")

    # Titre du Cours au Centre
    c.setFont("Helvetica-Bold", 19)
    c.setFillColor(COLOR_WHITE)
    course_title = mindmap_data["course_name"]
    c.drawCentredString(width / 2, height - 48, f"MIND MAP : {course_title.upper()}")

    # Module & Catégorie
    c.setFont("Helvetica", 11)
    c.setFillColor(COLOR_GOLD)
    module_label = f"Module de {mindmap_data['module_name']} • Préparation Officielle Concours de Résidanat"
    c.drawCentredString(width / 2, height - 70, module_label)

    # Badge de droite : Mode 100% Hors-Ligne & Cloud Drive
    draw_rounded_rect(c, width - 215, height - 72, 170, 34, 8, colors.HexColor("#065F46"), colors.HexColor("#10B981"), 1)
    c.setFillColor(colors.HexColor("#A7F3D0"))
    c.setFont("Helvetica-Bold", 10)
    c.drawCentredString(width - 130, height - 51, "GOOGLE DRIVE CLOUD")

    # 3. NŒUD CENTRAL (Hub Principal)
    cx = width / 2
    cy = height / 2 - 20
    hub_w = 260
    hub_h = 100

    draw_rounded_rect(c, cx - hub_w / 2, cy - hub_h / 2, hub_w, hub_h, 16, colors.HexColor("#1E293B"), COLOR_GOLD, 3)

    # Contenu du Hub
    draw_rounded_rect(c, cx - hub_w / 2 + 10, cy + hub_h / 2 - 28, hub_w - 20, 20, 6, COLOR_GOLD, COLOR_GOLD, 0)
    c.setFillColor(colors.HexColor("#78350F"))
    c.setFont("Helvetica-Bold", 10)
    c.drawCentredString(cx, cy + hub_h / 2 - 23, "CŒUR DU SUJET CLINIQUE")

    c.setFillColor(COLOR_WHITE)
    c.setFont("Helvetica-Bold", 13)
    wrapped_hub_title = wrap_text(mindmap_data["course_name"], 26)
    title_start_y = cy + 10 if len(wrapped_hub_title) == 1 else cy + 18
    for line in wrapped_hub_title[:2]:
        c.drawCentredString(cx, title_start_y, line)
        title_start_y -= 16

    c.setFont("Helvetica", 9)
    c.setFillColor(COLOR_MUTED)
    c.drawCentredString(cx, cy - 35, "Algorithme & Notions Haute Tombabilité")

    # 4. DISPOSITION DES BRANCHES AUTOUR DU HUB
    branches = mindmap_data["branches"]
    total_branches = len(branches)

    # Répartition 3 à gauche et 3 à droite pour une clarté maximale
    left_branches = branches[:(total_branches + 1) // 2]
    right_branches = branches[(total_branches + 1) // 2:]

    card_w = 330
    card_h = 160
    
    # Hauteur disponible entre le header et le footer
    content_top = height - header_h - 40
    content_bottom = 85
    available_h = content_top - content_bottom
    
    # 3 branches par colonne
    n_left = len(left_branches)
    n_right = len(right_branches)
    
    gap_left = (available_h - (n_left * card_h)) / (n_left + 1) if n_left > 0 else 20
    gap_right = (available_h - (n_right * card_h)) / (n_right + 1) if n_right > 0 else 20

    # Coordonnées des colonnes
    left_x = 40
    right_x = width - card_w - 40

    def draw_branch_card(c: canvas.Canvas, branch: Dict[str, Any], bx: float, by: float, is_left: bool, branch_num: int):
        t_idx = branch.get("theme_index", 0)
        theme = BRANCH_THEMES[t_idx % len(BRANCH_THEMES)]

        # Trait de connexion courbe vers le Hub
        c.saveState()
        c.setStrokeColor(theme["border"])
        c.setLineWidth(2.2)
        path = c.beginPath()
        if is_left:
            start_x = bx + card_w
            start_y = by + card_h / 2
            path.moveTo(start_x, start_y)
            path.curveTo(start_x + 90, start_y, cx - hub_w / 2 - 90, cy, cx - hub_w / 2, cy)
        else:
            start_x = bx
            start_y = by + card_h / 2
            path.moveTo(start_x, start_y)
            path.curveTo(start_x - 90, start_y, cx + hub_w / 2 + 90, cy, cx + hub_w / 2, cy)
        c.drawPath(path)
        c.restoreState()

        # Boîte de la Branche
        draw_rounded_rect(c, bx, by, card_w, card_h, 10, theme["bg"], theme["border"], 1.5)

        # En-tête de la Branche
        header_height = 28
        draw_rounded_rect(c, bx, by + card_h - header_height, card_w, header_height, 10, theme["header_bg"], theme["border"], 1)
        # Recouvrir les coins inférieurs de l'en-tête pour un look net
        c.setFillColor(theme["header_bg"])
        c.rect(bx + 1, by + card_h - header_height, card_w - 2, 6, fill=1, stroke=0)

        # Badge indicateur de branche
        draw_rounded_rect(c, bx + 10, by + card_h - 22, 20, 16, 4, theme["badge_bg"], theme["badge_bg"], 0)
        c.setFillColor(colors.HexColor("#0B132B"))
        c.setFont("Helvetica-Bold", 9)
        c.drawCentredString(bx + 20, by + card_h - 18, str(branch_num))

        # Titre de branche (sans émojis parasites pour police Helvetica standard)
        c.setFillColor(COLOR_WHITE)
        c.setFont("Helvetica-Bold", 10.5)
        branch_title = branch.get("title", "Branche")
        c.drawString(bx + 36, by + card_h - 19, branch_title[:40])

        # Items & Puces de la branche
        cur_y = by + card_h - header_height - 18
        items = branch.get("items", [])
        c.setFont("Helvetica", 8.5)
        c.setFillColor(theme["text_color"])

        for it in items[:4]:
            wrapped = wrap_text(it, 50)
            for l_idx, line in enumerate(wrapped[:2]):
                if l_idx == 0:
                    # Puce graphique circulaire colorée
                    c.saveState()
                    c.setFillColor(theme["badge_bg"])
                    c.circle(bx + 16, cur_y + 3, 2.5, fill=1, stroke=0)
                    c.restoreState()
                    c.setFillColor(theme["text_color"])
                    c.drawString(bx + 26, cur_y, line)
                else:
                    c.setFillColor(theme["text_color"])
                    c.drawString(bx + 26, cur_y, line)
                cur_y -= 12
            cur_y -= 3

    # Tracer les branches de gauche (du haut vers le bas)
    for i, b in enumerate(left_branches):
        y_pos = content_top - gap_left - ((i + 1) * card_h) - (i * gap_left)
        draw_branch_card(c, b, left_x, y_pos, is_left=True, branch_num=i + 1)

    # Tracer les branches de droite (du haut vers le bas)
    for i, b in enumerate(right_branches):
        y_pos = content_top - gap_right - ((i + 1) * card_h) - (i * gap_right)
        draw_branch_card(c, b, right_x, y_pos, is_left=False, branch_num=n_left + i + 1)

    # 5. Bandeau Inférieur de Synthèse & Mémento Diagnostic / Traitement
    footer_h = 52
    draw_rounded_rect(c, 25, 20, width - 50, footer_h, 10, COLOR_HEADER_BG, COLOR_BORDER, 1)

    c.setFont("Helvetica-Bold", 9)
    c.setFillColor(COLOR_GOLD)
    c.drawString(45, 52, "CRITÈRES DIAGNOSTIQUES :")
    c.setFont("Helvetica", 8.5)
    c.setFillColor(COLOR_WHITE)
    diag_str = mindmap_data.get("diagnostic_criteria", "Diagnostic clinique et paraclinique selon les critères de consensus")
    c.drawString(200, 52, diag_str[:120])

    c.setFont("Helvetica-Bold", 9)
    c.setFillColor(COLOR_EMERALD)
    c.drawString(45, 34, "TRAITEMENT CLÉ :")
    c.setFont("Helvetica", 8.5)
    c.setFillColor(COLOR_WHITE)
    treat_str = mindmap_data.get("treatment_summary", "Thérapeutique d'urgence standardisée et traitement de fond")
    c.drawString(200, 34, treat_str[:120])

    # Watermark / Footer signature
    c.setFont("Helvetica", 8)
    c.setFillColor(COLOR_MUTED)
    c.drawRightString(width - 45, 34, "Plateforme Medsina 2027 • Google Drive Cloud • 100% Conforme Résidanat")

    c.showPage()
    c.save()
    print(f"✅ Mind Map PDF généré avec succès : {output_pdf_path}")
    return output_pdf_path


def upload_to_google_drive(file_path: Path, folder_id: str) -> Optional[Tuple[str, str]]:
    """
    Téléverse le PDF généré sur Google Drive via la CLI gdrive officielle du système.
    Retourne (file_id, web_view_link).
    """
    try:
        cmd = ["gdrive", "mutate", "upload", str(file_path), "--parent", folder_id]
        print(f"🚀 Téléversement vers Google Drive : {' '.join(cmd)}")
        res = subprocess.run(cmd, capture_output=True, text=True, check=True)
        out = res.stdout + res.stderr
        print(f"Sortie gdrive : {out.strip()}")

        # Extraction de l'ID du fichier
        # Sortie type: Uploaded file: c_cardio_sca_mindmap.pdf (ID: 1abc...)
        match = re.search(r"ID:\s*([a-zA-Z0-9_-]+)", out)
        if match:
            file_id = match.group(1)
            # Rendre accessible en lecture publique
            subprocess.run(["gdrive", "mutate", "share", file_id, "--type", "anyone", "--role", "reader"], capture_output=True)
            view_url = f"https://drive.google.com/file/d/{file_id}/view?usp=drivesdk"
            return file_id, view_url
    except Exception as e:
        print(f"⚠️ Erreur téléversement Google Drive : {e}")
    return None


def update_local_catalog(course_id: str, mindmap_drive_id: str, mindmap_url: str):
    """Met à jour le fichier assets/data/modules_catalog_47.json avec les données du Mind Map."""
    if not CATALOG_PATH.exists():
        print("⚠️ Fichier catalog introuvable.")
        return

    try:
        with open(CATALOG_PATH, "r", encoding="utf-8") as f:
            modules = json.load(f)

        updated = False
        for mod in modules:
            for c in mod.get("courses", []):
                if c.get("id") == course_id:
                    c["mindmap_drive_id"] = mindmap_drive_id
                    c["mindmap_pdf_url"] = mindmap_url
                    c["has_mindmap"] = True
                    c["mindmap_generated_at"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
                    updated = True
                    break
            if updated:
                break

        if updated:
            with open(CATALOG_PATH, "w", encoding="utf-8") as f:
                json.dump(modules, f, indent=2, ensure_ascii=False)
            print(f"✅ Catalogue mis à jour pour le cours {course_id}")
    except Exception as e:
        print(f"⚠️ Erreur mise à jour catalogue : {e}")


def update_mindmaps_registry(mindmap_dict: Dict[str, Any]):
    """Enregistre la structure du Mind Map dans assets/data/course_mindmaps.json."""
    registry = {}
    if MINDMAPS_JSON_PATH.exists():
        try:
            with open(MINDMAPS_JSON_PATH, "r", encoding="utf-8") as f:
                registry = json.load(f)
        except Exception:
            registry = {}

    course_id = mindmap_dict["course_id"]
    registry[course_id] = mindmap_dict

    with open(MINDMAPS_JSON_PATH, "w", encoding="utf-8") as f:
        json.dump(registry, f, indent=2, ensure_ascii=False)
    print(f"✅ Registre JSON Mind Map mis à jour pour {course_id}")


def main():
    parser = argparse.ArgumentParser(description="Générateur de Mind Maps Medsina 2027")
    parser.add_argument("--course-id", default="c_cardio_sca", help="ID du cours à traiter (ex: c_cardio_sca ou all)")
    parser.add_argument("--limit", type=int, default=5, help="Nombre max de cours à traiter si 'all'")
    parser.add_argument("--skip-upload", action="store_true", help="Ne pas uploader vers Google Drive")
    args = parser.parse_args()

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    target_ids = []
    if args.course_id == "all":
        if SUMMARIES_PATH.exists():
            with open(SUMMARIES_PATH, "r", encoding="utf-8") as f:
                summaries = json.load(f)
            target_ids = [s["course_id"] for s in summaries[:args.limit]]
    else:
        target_ids = [args.course_id]

    print(f"🌟 Génération des Mind Maps pour {len(target_ids)} cours...")

    for cid in target_ids:
        print(f"\n=======================================================")
        print(f"📖 Traitement du cours : {cid}")
        summary = load_course_summary(cid)
        if not summary:
            print(f"❌ Résumé introuvable pour {cid}, passage au suivant.")
            continue

        mm_data = extract_mindmap_structure(summary)
        pdf_file_name = f"{cid}_mindmap_residanat_2027.pdf"
        output_pdf = OUTPUT_DIR / pdf_file_name

        generate_mindmap_pdf(mm_data, output_pdf)

        drive_id = None
        drive_url = f"assets/mindmaps/{pdf_file_name}"

        if not args.skip_upload:
            upload_res = upload_to_google_drive(output_pdf, GDRIVE_MINDMAPS_FOLDER_ID)
            if upload_res:
                drive_id, drive_url = upload_res
                print(f"🎉 Téléversé avec succès sur Google Drive ! ID: {drive_id}")

        mm_data["pdf_file"] = pdf_file_name
        mm_data["mindmap_drive_id"] = drive_id
        mm_data["mindmap_pdf_url"] = drive_url

        update_mindmaps_registry(mm_data)
        if drive_id:
            update_local_catalog(cid, drive_id, drive_url)
            sync_to_supabase_resources(mm_data, drive_id, drive_url)

    print("\n=======================================================")
    print("🏆 Génération et intégration terminées avec succès !")


def sync_to_supabase_resources(mm_data: Dict[str, Any], drive_id: str, drive_url: str):
    """Enregistre le Mind Map dans Supabase (table discovered_blida_resources et courses)."""
    supabase_url = os.environ.get("SUPABASE_URL", "https://qzfssrhhuorljftpdvjm.supabase.co")
    service_key = os.environ.get(
        "SUPABASE_SERVICE_ROLE_KEY",
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF6ZnNzcmhodW9ybGpmdHBkdmptIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MTYxMjg1NCwiZXhwIjoyMTA3MTg4ODU0fQ.-KCUgZdY8RDUwvNOUAabDhQFwv5FFGHYz0J-dM7Cic4"
    )

    cid = mm_data["course_id"]
    cname = mm_data["course_name"]

    headers = {
        "apikey": service_key,
        "Authorization": f"Bearer {service_key}",
        "Content-Type": "application/json",
        "Prefer": "resolution=merge-duplicates"
    }

    # 1. Enregistrement dans discovered_blida_resources
    payload = [{
        "id": f"res_mm_{cid}",
        "title": f"Mind Map : {cname}",
        "resource_type": "mindmap",
        "source_type": "gdrive",
        "source_origin": "Medsina Mindmap Pipeline",
        "source_url": drive_url,
        "gdrive_file_id": drive_id,
        "suggested_course_id": cid,
        "status": "approved"
    }]

    try:
        url = f"{supabase_url}/rest/v1/discovered_blida_resources"
        res = requests.post(url, headers=headers, json=payload, timeout=10)
        if res.status_code in (200, 201):
            print(f"☁️ [Supabase] Synchronisé dans discovered_blida_resources (id: res_mm_{cid})")
    except Exception as e:
        print(f"⚠️ Erreur sync Supabase discovered_blida_resources: {e}")

    # 2. Mise à jour dans courses si colonnes existantes
    try:
        patch_payload = {
            "mindmap_pdf_url": drive_url,
            "mindmap_drive_id": drive_id,
            "has_mindmap": True,
            "mindmap_generated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        }
        patch_url = f"{supabase_url}/rest/v1/courses?id=eq.{cid}"
        requests.patch(patch_url, headers=headers, json=patch_payload, timeout=10)
    except Exception:
        pass


if __name__ == "__main__":
    main()
