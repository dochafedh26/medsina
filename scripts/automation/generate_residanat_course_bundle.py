#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
=============================================================================
MEDSINA — GÉNÉRATEUR AUTOMATIQUE DE LIVRETS DE RÉVISION « RÉSIDANAT 2027 »
=============================================================================
Crée un Livret PDF All-in-One pour chaque cours éligible :
1. Couverture Premium Concours 2027 avec Badge Hypertombable et années de concours
2. Fiche de Synthèse (Points Clés, Pièges Concours, Diagnostic & Traitement)
3. Cours Officiel complet (Polycopié de faculté / drive fusionné)
4. Banque de QCMs d'Entraînement SANS correction (Mode Examen Blanc)
5. Corrigé Type & Grille de Correction (Dernière Page avec Perles Cliniques)

Stockage :
- Supabase Storage : bucket 'residanat_2027_livrets'
- Table Supabase : 'courses' (bundle_pdf_url, is_hypertombable, residanat_years, qcm_count)
=============================================================================
"""

import os
import re
import sys
import json
import time
import argparse
import tempfile
import requests
from pathlib import Path
from typing import Dict, Any, List, Optional, Tuple

# Fix Windows console UTF-8 output
if sys.stdout and hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

# ReportLab & PDF Tools
from reportlab.lib.pagesizes import A4
from reportlab.lib import colors
from reportlab.platypus import (
    SimpleDocTemplate,
    Paragraph,
    Spacer,
    Table,
    TableStyle,
    PageBreak,
    KeepTogether,
    HRFlowable,
)
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.enums import TA_CENTER, TA_LEFT, TA_RIGHT, TA_JUSTIFY
from reportlab.pdfgen import canvas
import pymupdf  # fitz

SCRIPT_DIR = Path(__file__).resolve().parent
WORKSPACE_ROOT = SCRIPT_DIR.parents[1] if len(SCRIPT_DIR.parents) > 1 else SCRIPT_DIR

def resolve_resource_path(sub_rel: str) -> Path:
    candidates = [
        SCRIPT_DIR.parents[1] / sub_rel,
        SCRIPT_DIR.parents[1] / "medsina" / sub_rel,
        Path(sub_rel),
        Path("medsina") / sub_rel,
    ]
    if len(SCRIPT_DIR.parents) > 2:
        candidates.append(SCRIPT_DIR.parents[2] / sub_rel)
        candidates.append(SCRIPT_DIR.parents[2] / "medsina" / sub_rel)
    for c in candidates:
        if c.exists():
            return c
    return candidates[0]

QCMS_DIR = resolve_resource_path("assets/data/qcms")
SUMMARIES_FILE = resolve_resource_path("assets/data/course_summaries.json")

# Palette de couleurs Medsina Résidanat 2027
COLOR_WHITE = colors.HexColor("#FFFFFF")
COLOR_PRIMARY_NAVY = colors.HexColor("#0B2545")
COLOR_ROYAL_BLUE = colors.HexColor("#0A5DC2")
COLOR_CYAN_ACCENT = colors.HexColor("#0EA5E9")
COLOR_EMERALD = colors.HexColor("#10B981")
COLOR_EMERALD_BG = colors.HexColor("#ECFDF5")
COLOR_GOLD = colors.HexColor("#D97706")
COLOR_GOLD_BG = colors.HexColor("#FEF3C7")
COLOR_CRIMSON = colors.HexColor("#DC2626")
COLOR_CRIMSON_BG = colors.HexColor("#FEE2E2")
COLOR_SLATE_DARK = colors.HexColor("#1E293B")
COLOR_SLATE_MUTED = colors.HexColor("#64748B")
COLOR_CARD_BG = colors.HexColor("#F8FAFC")
COLOR_CARD_BORDER = colors.HexColor("#E2E8F0")


# -----------------------------------------------------------------------------
# 1. Canvas Numéroté Personnalisé (En-tête et Pied de Page Dynamiques)
# -----------------------------------------------------------------------------
class NumberedCanvas(canvas.Canvas):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._saved_page_states = []

    def showPage(self):
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()

    def save(self):
        num_pages = len(self._saved_page_states)
        for state in self._saved_page_states:
            self.__dict__.update(state)
            self.draw_page_decorations(num_pages)
            super().showPage()
        super().save()

    def draw_page_decorations(self, page_count: int):
        self.saveState()
        self.setFont("Helvetica", 8)
        self.setFillColor(COLOR_SLATE_MUTED)

        # Pas d'en-tête sur la couverture (page 1)
        if self._pageNumber > 1:
            # Header
            self.drawString(45, 805, "MEDSINA ULTRA  •  Livret de Révision Officiel Concours Résidanat 2027")
            self.setStrokeColor(COLOR_CARD_BORDER)
            self.setLineWidth(0.6)
            self.line(45, 800, 550, 800)

        # Footer sur toutes les pages
        self.setStrokeColor(COLOR_CARD_BORDER)
        self.setLineWidth(0.6)
        self.line(45, 35, 550, 35)

        self.drawString(45, 24, "medsina.medevsync.com  •  Document strictement réservé aux candidats de préparation")
        page_str = f"Page {self._pageNumber} / {page_count}"
        self.drawRightString(550, 24, page_str)
        self.restoreState()


# -----------------------------------------------------------------------------
# 2. Configuration Supabase
# -----------------------------------------------------------------------------
def get_supabase_credentials() -> Tuple[str, str]:
    env_path = WORKSPACE_ROOT / "medsina" / ".env"
    if not env_path.exists():
        env_path = WORKSPACE_ROOT / ".env"

    env_vars = {}
    if env_path.exists():
        for line in env_path.read_text(encoding="utf-8").splitlines():
            if "=" in line and not line.strip().startswith("#"):
                k, v = line.split("=", 1)
                env_vars[k.strip()] = v.strip().strip("\"'")

    url = env_vars.get("SUPABASE_URL", "https://qzfssrhhuorljftpdvjm.supabase.co")
    key = env_vars.get("SUPABASE_SERVICE_ROLE_KEY", "")
    return url, key


# -----------------------------------------------------------------------------
# 3. Téléchargement du PDF de cours (Google Drive ou URL directe)
# -----------------------------------------------------------------------------
def download_course_raw_pdf(pdf_url: str, dest_path: Path) -> bool:
    if not pdf_url or str(pdf_url).lower() == "none":
        return False

    session = requests.Session()
    # Cas 1 : Lien Google Drive
    drive_match = re.search(r"[-_\w]{25,}", pdf_url)
    if "drive.google.com" in pdf_url and drive_match:
        fid = drive_match.group(0)
        dl_url = f"https://drive.google.com/uc?export=download&id={fid}"
        try:
            r = session.get(dl_url, stream=True, timeout=25)
            # Gestion du token de confirmation pour gros fichiers
            for k, v in r.cookies.items():
                if k.startswith("download_warning"):
                    dl_url = f"https://drive.google.com/uc?export=download&confirm={v}&id={fid}"
                    r = session.get(dl_url, stream=True, timeout=25)
                    break

            if r.status_code == 200 and (r.content.startswith(b"%PDF") or "pdf" in r.headers.get("content-type", "")):
                dest_path.write_bytes(r.content)
                return True
        except Exception as e:
            print(f"   ⚠️ Erreur téléchargement Google Drive ({fid}): {e}")
            return False

    # Cas 2 : Téléchargement direct
    try:
        r = session.get(pdf_url, stream=True, timeout=25)
        if r.status_code == 200 and (r.content.startswith(b"%PDF") or "pdf" in r.headers.get("content-type", "")):
            dest_path.write_bytes(r.content)
            return True
    except Exception as e:
        print(f"   ⚠️ Erreur téléchargement direct ({pdf_url}): {e}")
        return False

    return False


# -----------------------------------------------------------------------------
# 4. Extraction des Fiches de Synthèse et QCMs
# -----------------------------------------------------------------------------
_LOCAL_SUMMARIES_CACHE = None

def get_course_summary_data(course_id: str, course_name: str, supabase_url: str, supabase_key: str) -> Optional[Dict[str, Any]]:
    global _LOCAL_SUMMARIES_CACHE
    # 1. Chercher dans Supabase table course_summaries
    if supabase_url and supabase_key:
        try:
            headers = {"apikey": supabase_key, "Authorization": f"Bearer {supabase_key}"}
            r = requests.get(f"{supabase_url}/rest/v1/course_summaries?course_id=eq.{course_id}", headers=headers, timeout=10)
            if r.status_code == 200 and r.json():
                return r.json()[0]
        except Exception:
            pass

    # 2. Chercher dans le fichier local course_summaries.json
    if _LOCAL_SUMMARIES_CACHE is None and SUMMARIES_FILE.exists():
        try:
            _LOCAL_SUMMARIES_CACHE = json.loads(SUMMARIES_FILE.read_text(encoding="utf-8"))
        except Exception:
            _LOCAL_SUMMARIES_CACHE = []

    if _LOCAL_SUMMARIES_CACHE:
        c_id_lower = course_id.lower().strip()
        c_name_lower = course_name.lower().strip()
        for s in _LOCAL_SUMMARIES_CACHE:
            s_id = str(s.get("course_id", "")).lower().strip()
            s_name = str(s.get("course_name", "")).lower().strip()
            if s_id == c_id_lower or (s_name and s_name == c_name_lower):
                return s

    return None


def get_course_qcms(course_id: str, course_name: str, module_id: str) -> List[Dict[str, Any]]:
    qcms = []
    # Chercher dans le fichier module correspondant
    module_files = [
        QCMS_DIR / f"{module_id}.json",
        QCMS_DIR / f"Blida_{module_id}.json",
    ]
    if not any(f.exists() for f in module_files):
        # Explorer tous les fichiers JSON du dossier
        module_files = list(QCMS_DIR.glob("*.json"))

    c_id_lower = course_id.lower().strip()
    c_name_lower = course_name.lower().strip()

    for mf in module_files:
        if not mf.exists():
            continue
        try:
            data = json.loads(mf.read_text(encoding="utf-8"))
            if isinstance(data, list):
                for q in data:
                    q_cid = str(q.get("courseId", "")).lower().strip()
                    q_cname = str(q.get("courseName", "")).lower().strip()
                    if q_cid == c_id_lower or (c_name_lower and q_cname == c_name_lower):
                        qcms.append(q)
            if qcms:
                break
        except Exception:
            pass

    return qcms


# -----------------------------------------------------------------------------
# 5. Détection de la Tombabilité & Sessions de Concours de Résidanat
# -----------------------------------------------------------------------------
def analyze_hypertombable(qcms: List[Dict[str, Any]]) -> Tuple[bool, List[str], int]:
    """
    Règle validée :
    Un cours est classé HYPERTOMBABLE dès qu'il comporte au moins 2 questions issues
    d'annales de Résidanat/Concours.
    Retourne (is_hypertombable, liste_annees_concours, total_qcms)
    """
    residanat_count = 0
    sessions_found = set()

    for q in qcms:
        source = str(q.get("source", ""))
        src_lower = source.lower()
        year = q.get("year")

        if any(term in src_lower for term in ["résidanat", "residanat", "concours"]):
            residanat_count += 1
            # Extraire les années mentionnées
            years_in_src = re.findall(r"(?:19|20)\d{2}", source)
            if years_in_src:
                for y in years_in_src:
                    sessions_found.add(f"Session {y}")
            elif year:
                sessions_found.add(f"Session {year}")
            else:
                sessions_found.add(source.strip())

    is_hyper = residanat_count >= 2
    sorted_sessions = sorted(list(sessions_found), key=lambda x: re.findall(r"\d+", x)[0] if re.findall(r"\d+", x) else x)
    return is_hyper, sorted_sessions, len(qcms)


# -----------------------------------------------------------------------------
# 6. Génération ReportLab des Sections du Livret
# -----------------------------------------------------------------------------

def clean_reportlab_text(text: Any, max_len: Optional[int] = None) -> str:
    """
    Nettoie et sécurise les textes pour le parser XML de ReportLab.
    Supprime les balises HTML/Markdown risquant de causer des balises non fermées,
    normalise les caractères typographiques et échappe les entités XML.
    """
    if not text:
        return ""
    import html
    t = str(text)
    # 1. Normaliser les symboles médicaux et guillemets pour Helvetica
    t = (
        t.replace("≥", ">=")
        .replace("≤", "<=")
        .replace("≠", "!=")
        .replace("±", "+/-")
        .replace("→", "->")
        .replace("•", "-")
        .replace("’", "'")
        .replace("‘", "'")
        .replace("«", '"')
        .replace("»", '"')
    )
    # 2. Retirer les émojis
    t = re.sub(r'[𐀀-􏿿]', '', t)
    # 3. Retirer les headers markdown
    t = re.sub(r'#{1,6}\s*', '', t)
    # 4. Retirer toutes les balises HTML existantes pour éviter les balises non fermées
    t = re.sub(r'<[^>]*>', '', t)
    # 5. Nettoyer les astérisques markdown
    t = re.sub(r'\*+', '', t)
    # 6. Tronquer si nécessaire
    if max_len and len(t) > max_len:
        t = t[:max_len].rsplit('.', 1)[0] + '.'
    # 7. Échapper XML proprement
    return html.escape(t.strip())

def build_reportlab_booklet(
    output_pdf_path: Path,
    course_data: Dict[str, Any],
    summary_data: Optional[Dict[str, Any]],
    qcms: List[Dict[str, Any]],
    is_hyper: bool,
    residanat_sessions: List[str]
):
    doc = SimpleDocTemplate(
        str(output_pdf_path),
        pagesize=A4,
        leftMargin=45,
        rightMargin=45,
        topMargin=50,
        bottomMargin=50,
    )

    styles = getSampleStyleSheet()

    # Styles personnalisés
    title_style = ParagraphStyle(
        "CoverTitle",
        parent=styles["Heading1"],
        fontName="Helvetica-Bold",
        fontSize=24,
        leading=28,
        textColor=COLOR_PRIMARY_NAVY,
        alignment=TA_CENTER,
        spaceAfter=12,
    )
    module_badge_style = ParagraphStyle(
        "ModuleBadge",
        parent=styles["Normal"],
        fontName="Helvetica-Bold",
        fontSize=12,
        leading=16,
        textColor=COLOR_ROYAL_BLUE,
        alignment=TA_CENTER,
        spaceAfter=15,
    )
    hyper_badge_style = ParagraphStyle(
        "HyperBadge",
        parent=styles["Normal"],
        fontName="Helvetica-Bold",
        fontSize=12,
        leading=16,
        textColor=COLOR_CRIMSON,
        alignment=TA_CENTER,
    )
    hyper_sub_style = ParagraphStyle(
        "HyperSub",
        parent=styles["Normal"],
        fontName="Helvetica",
        fontSize=10,
        leading=14,
        textColor=COLOR_SLATE_DARK,
        alignment=TA_CENTER,
    )
    section_h1 = ParagraphStyle(
        "SectionH1",
        parent=styles["Heading2"],
        fontName="Helvetica-Bold",
        fontSize=16,
        leading=20,
        textColor=COLOR_PRIMARY_NAVY,
        spaceBefore=14,
        spaceAfter=10,
    )
    section_h2 = ParagraphStyle(
        "SectionH2",
        parent=styles["Heading3"],
        fontName="Helvetica-Bold",
        fontSize=12,
        leading=16,
        textColor=COLOR_ROYAL_BLUE,
        spaceBefore=10,
        spaceAfter=6,
    )
    body_style = ParagraphStyle(
        "BodyDark",
        parent=styles["Normal"],
        fontName="Helvetica",
        fontSize=10,
        leading=14,
        textColor=COLOR_SLATE_DARK,
        spaceAfter=6,
    )
    bullet_style = ParagraphStyle(
        "KeyBullet",
        parent=styles["Normal"],
        fontName="Helvetica",
        fontSize=10,
        leading=14,
        textColor=COLOR_SLATE_DARK,
        leftIndent=15,
        spaceAfter=4,
    )
    qcm_title_style = ParagraphStyle(
        "QCMTitle",
        parent=styles["Normal"],
        fontName="Helvetica-Bold",
        fontSize=11,
        leading=15,
        textColor=COLOR_PRIMARY_NAVY,
        spaceBefore=8,
        spaceAfter=4,
    )
    qcm_opt_style = ParagraphStyle(
        "QCMOpt",
        parent=styles["Normal"],
        fontName="Helvetica",
        fontSize=9.5,
        leading=13.5,
        textColor=COLOR_SLATE_DARK,
        leftIndent=15,
        spaceAfter=3,
    )
    qcm_meta_style = ParagraphStyle(
        "QCMMeta",
        parent=styles["Italic"],
        fontName="Helvetica-Oblique",
        fontSize=8.5,
        leading=11,
        textColor=COLOR_SLATE_MUTED,
        spaceAfter=8,
    )

    story = []

    # =========================================================================
    # PAGE 1 : COUVERTURE OFFICIELLE « RÉSIDANAT 2027 »
    # =========================================================================
    story.append(Spacer(1, 20))
    header_banner = [
        [
            Paragraph("<b>MEDSINA ULTRA</b> • PROGRAMME NATIONAL D'EXCELLENCE", ParagraphStyle("B1", fontName="Helvetica-Bold", fontSize=11, textColor=COLOR_WHITE, alignment=TA_CENTER)),
        ],
        [
            Paragraph("COLLECTION OFFICIELLE DE PRÉPARATION AU CONCOURS DE RÉSIDANAT 2027", ParagraphStyle("B2", fontName="Helvetica-Bold", fontSize=9, textColor=COLOR_GOLD_BG, alignment=TA_CENTER)),
        ]
    ]
    t_banner = Table(header_banner, colWidths=[500])
    t_banner.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), COLOR_PRIMARY_NAVY),
        ("TOPPADDING", (0, 0), (-1, -1), 10),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 10),
        ("ROUNDEDCORNERS", [8, 8, 8, 8]),
    ]))
    story.append(t_banner)
    story.append(Spacer(1, 40))

    # Module & Titre
    module_name = course_data.get("module_name") or course_data.get("module_id") or "Module Médical"
    course_name = course_data.get("name") or "Cours Officiel"

    story.append(Paragraph(f"MODULE : {module_name.upper()}", module_badge_style))
    story.append(Paragraph(course_name, title_style))
    story.append(Spacer(1, 15))

    # Macaron Hypertombable
    if is_hyper:
        sessions_str = ", ".join(residanat_sessions) if residanat_sessions else "Multiples sessions répertoriées"
        hyper_box = [
            [
                Paragraph("<b>[!] COURS HYPERTOMBABLE AU CONCOURS DE RÉSIDANAT</b>", hyper_badge_style)
            ],
            [
                Paragraph(f"<b>Sessions officielles répertoriées :</b> {sessions_str}", hyper_sub_style)
            ],
            [
                Paragraph("Ce sujet fait partie du top 20% des cours les plus tombés au concours. Maîtrise absolue recommandée.", ParagraphStyle("HypDesc", fontName="Helvetica-Oblique", fontSize=9, textColor=COLOR_SLATE_MUTED, alignment=TA_CENTER))
            ]
        ]
        t_hyper = Table(hyper_box, colWidths=[500])
        t_hyper.setStyle(TableStyle([
            ("BACKGROUND", (0, 0), (-1, -1), COLOR_CRIMSON_BG),
            ("BOX", (0, 0), (-1, -1), 1.5, COLOR_CRIMSON),
            ("TOPPADDING", (0, 0), (-1, -1), 8),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 8),
            ("ROUNDEDCORNERS", [8, 8, 8, 8]),
        ]))
        story.append(t_hyper)
        story.append(Spacer(1, 25))
    else:
        norm_box = [
            [
                Paragraph("<b>COURS DU PROGRAMME OFFICIEL DE RÉSIDANAT</b>", ParagraphStyle("NormBadge", fontName="Helvetica-Bold", fontSize=11, textColor=COLOR_ROYAL_BLUE, alignment=TA_CENTER))
            ]
        ]
        t_norm = Table(norm_box, colWidths=[500])
        t_norm.setStyle(TableStyle([
            ("BACKGROUND", (0, 0), (-1, -1), COLOR_CARD_BG),
            ("BOX", (0, 0), (-1, -1), 1, COLOR_ROYAL_BLUE),
            ("TOPPADDING", (0, 0), (-1, -1), 8),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 8),
            ("ROUNDEDCORNERS", [6, 6, 6, 6]),
        ]))
        story.append(t_norm)
        story.append(Spacer(1, 25))

    # Sommaire du Livret All-in-One
    toc_data = [
        [Paragraph("<b>STRUCTURE DU LIVRET DE RÉVISION :</b>", ParagraphStyle("TOCHead", fontName="Helvetica-Bold", fontSize=11, textColor=COLOR_PRIMARY_NAVY))],
        [Paragraph("<b>Section 1 :</b> Fiche de Synthèse & Pièges Concours (Mémorisation rapide)", body_style)],
        [Paragraph("<b>Section 2 :</b> Cours & Polycopié Officiel de la Faculté", body_style)],
        [Paragraph(f"<b>Section 3 :</b> Entraînement QCMs SANS correction ({len(qcms)} Questions réelles)", body_style)],
        [Paragraph("<b>Section 4 :</b> Grille Officielle du Corrigé Type & Perles Cliniques (Dernière Page)", body_style)],
    ]
    t_toc = Table(toc_data, colWidths=[500])
    t_toc.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), COLOR_CARD_BG),
        ("BOX", (0, 0), (-1, -1), 1, COLOR_CARD_BORDER),
        ("TOPPADDING", (0, 0), (-1, -1), 10),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 10),
        ("LEFTPADDING", (0, 0), (-1, -1), 18),
        ("RIGHTPADDING", (0, 0), (-1, -1), 18),
        ("ROUNDEDCORNERS", [8, 8, 8, 8]),
    ]))
    story.append(t_toc)
    story.append(Spacer(1, 35))

    story.append(Paragraph("<i>Medsina © 2026-2027 — Conçu pour l'excellence et la réussite aux concours médicaux.</i>", ParagraphStyle("FootCover", fontName="Helvetica-Oblique", fontSize=8.5, textColor=COLOR_SLATE_MUTED, alignment=TA_CENTER)))
    story.append(PageBreak())

    # =========================================================================
    # SECTION 1 : FICHE DE SYNTHÈSE, POINTS CLÉS & PIÈGES
    # =========================================================================
    story.append(Paragraph("SECTION 1 — FICHE DE SYNTHÈSE & PIÈGES DE CONCOURS", section_h1))
    story.append(HRFlowable(width="100%", thickness=1.5, color=COLOR_ROYAL_BLUE, spaceAfter=12))

    if summary_data:
        # Résumé général / Intro
        sum_md = summary_data.get("summary_markdown")
        if sum_md:
            clean_md = clean_reportlab_text(sum_md, max_len=550)
            # Tronquage propre si trop long
            if len(clean_md) > 600:
                clean_md = clean_md[:580].rsplit(".", 1)[0] + "."
            story.append(Paragraph(f"<b>Synthèse Clinique :</b> {clean_md}", body_style))
            story.append(Spacer(1, 8))

        # Points clés
        takeaways = summary_data.get("key_takeaways") or []
        if isinstance(takeaways, str):
            try:
                takeaways = json.loads(takeaways)
            except Exception:
                takeaways = [takeaways]
        if takeaways:
            story.append(Paragraph("Points Clés Incontournables :", section_h2))
            takeaway_rows = []
            for item in takeaways:
                takeaway_rows.append([Paragraph(f"<b>+</b>  {clean_reportlab_text(item)}", bullet_style)])
            t_take = Table(takeaway_rows, colWidths=[500])
            t_take.setStyle(TableStyle([
                ("BACKGROUND", (0, 0), (-1, -1), COLOR_EMERALD_BG),
                ("BOX", (0, 0), (-1, -1), 1, COLOR_EMERALD),
                ("TOPPADDING", (0, 0), (-1, -1), 5),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
                ("LEFTPADDING", (0, 0), (-1, -1), 10),
                ("ROUNDEDCORNERS", [6, 6, 6, 6]),
            ]))
            story.append(t_take)
            story.append(Spacer(1, 10))

        # Pièges Typiques de Concours
        traps = summary_data.get("exam_traps") or []
        if isinstance(traps, str):
            try:
                traps = json.loads(traps)
            except Exception:
                traps = [traps]
        if traps:
            story.append(Paragraph("Pièges Fréquents en QCM :", section_h2))
            trap_rows = []
            for item in traps:
                trap_rows.append([Paragraph(f"<b>[ATTENTION]</b>  {clean_reportlab_text(item)}", bullet_style)])
            t_traps = Table(trap_rows, colWidths=[500])
            t_traps.setStyle(TableStyle([
                ("BACKGROUND", (0, 0), (-1, -1), COLOR_GOLD_BG),
                ("BOX", (0, 0), (-1, -1), 1, COLOR_GOLD),
                ("TOPPADDING", (0, 0), (-1, -1), 5),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
                ("LEFTPADDING", (0, 0), (-1, -1), 10),
                ("ROUNDEDCORNERS", [6, 6, 6, 6]),
            ]))
            story.append(t_traps)
            story.append(Spacer(1, 10))

        # Diagnostic & Traitement si disponibles
        diag = summary_data.get("diagnostic_criteria")
        trait = summary_data.get("treatment_summary")
        if diag or trait:
            dt_rows = []
            if diag:
                dt_rows.append([Paragraph("<b>Critères Diagnostiques / Normes :</b>", section_h2)])
                dt_rows.append([Paragraph(clean_reportlab_text(diag), body_style)])
            if trait:
                dt_rows.append([Paragraph("<b>Lignes Thérapeutiques & Posologies :</b>", section_h2)])
                dt_rows.append([Paragraph(clean_reportlab_text(trait), body_style)])
            t_dt = Table(dt_rows, colWidths=[500])
            t_dt.setStyle(TableStyle([
                ("BACKGROUND", (0, 0), (-1, -1), COLOR_CARD_BG),
                ("BOX", (0, 0), (-1, -1), 1, COLOR_CARD_BORDER),
                ("TOPPADDING", (0, 0), (-1, -1), 6),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
                ("LEFTPADDING", (0, 0), (-1, -1), 10),
                ("ROUNDEDCORNERS", [6, 6, 6, 6]),
            ]))
            story.append(t_dt)
    else:
        story.append(Paragraph("<i>Fiche de synthèse en cours d'enrichissement pour ce cours. Référez-vous au polycopié complet ci-dessous.</i>", body_style))

    story.append(Spacer(1, 20))
    story.append(PageBreak())

    # =========================================================================
    # SECTION 2 : TRANSITION VERS LE COURS OFFICIEL
    # =========================================================================
    # (Le cours officiel sera intercalé ici lors de la fusion PyMuPDF)

    # =========================================================================
    # SECTION 3 : QCMs D'ENTRAÎNEMENT SANS CORRECTION
    # =========================================================================
    story.append(Paragraph("SECTION 3 — BANQUE DE QCMs D'ENTRAÎNEMENT", section_h1))
    story.append(HRFlowable(width="100%", thickness=1.5, color=COLOR_ROYAL_BLUE, spaceAfter=8))
    story.append(Paragraph("<b>Mode Examen Blanc :</b> Répondez aux questions en cochant les cases sans consulter la dernière page. Notez vos réponses sur une feuille séparée pour mesurer votre score brut.", ParagraphStyle("ModeExamen", fontName="Helvetica-Oblique", fontSize=9.5, textColor=COLOR_SLATE_MUTED, spaceAfter=14)))

    if not qcms:
        story.append(Paragraph("<i>Aucun QCM spécifique rattaché à ce cours pour l'instant.</i>", body_style))
    else:
        for idx, q in enumerate(qcms, start=1):
            q_elements = []
            q_text = q.get("questionText") or q.get("question") or "Question sans libellé"
            case = q.get("clinicalCase")
            if case:
                q_elements.append(Paragraph(f"<b>Cas Clinique :</b> <i>{clean_reportlab_text(case)}</i>", ParagraphStyle("CaseText", fontName="Helvetica", fontSize=9, textColor=COLOR_SLATE_DARK, spaceAfter=4)))

            q_elements.append(Paragraph(f"<b>QCM {idx}.</b> {clean_reportlab_text(q_text)}", qcm_title_style))

            options = q.get("options") or []
            for opt in options:
                opt_key = opt.get("key", "")
                opt_txt = opt.get("text", "")
                q_elements.append(Paragraph(f"<b>[  ] {opt_key}.</b> {clean_reportlab_text(opt_txt)}", qcm_opt_style))

            src = q.get("source") or "Concours Officiel"
            yr = q.get("year")
            yr_str = f" • Année {yr}" if yr and str(yr) not in src else ""
            q_elements.append(Paragraph(f"Source : {src}{yr_str}", qcm_meta_style))
            q_elements.append(Spacer(1, 4))

            story.append(KeepTogether(q_elements))

    story.append(Spacer(1, 15))
    story.append(PageBreak())

    # =========================================================================
    # SECTION 4 : DERNIÈRE PAGE — GRILLE DE CORRECTION OFFICIELLE (CORRIGÉ TYPE)
    # =========================================================================
    story.append(Paragraph("SECTION 4 — CORRIGÉ TYPE & GRILLE OFFICIELLE", section_h1))
    story.append(HRFlowable(width="100%", thickness=1.5, color=COLOR_EMERALD, spaceAfter=8))
    story.append(Paragraph("<b>Auto-évaluation :</b> Vérifiez vos réponses ci-dessous. Calculez votre score selon le barème officiel du Concours (Tout ou Rien ou Pondéré).", ParagraphStyle("AutoEval", fontName="Helvetica-Oblique", fontSize=9.5, textColor=COLOR_SLATE_MUTED, spaceAfter=14)))

    if qcms:
        # Tableau récapitulatif compact des réponses
        table_data = [
            [
                Paragraph("<b>N°</b>", ParagraphStyle("TH", fontName="Helvetica-Bold", fontSize=9, textColor=COLOR_WHITE, alignment=TA_CENTER)),
                Paragraph("<b>Type</b>", ParagraphStyle("TH", fontName="Helvetica-Bold", fontSize=9, textColor=COLOR_WHITE, alignment=TA_CENTER)),
                Paragraph("<b>Réponse Correcte</b>", ParagraphStyle("TH", fontName="Helvetica-Bold", fontSize=9, textColor=COLOR_WHITE, alignment=TA_CENTER)),
                Paragraph("<b>Source Officielle</b>", ParagraphStyle("TH", fontName="Helvetica-Bold", fontSize=9, textColor=COLOR_WHITE)),
            ]
        ]

        for idx, q in enumerate(qcms, start=1):
            q_type = str(q.get("type", "QCM")).upper()
            corr = q.get("correctAnswers") or q.get("answer") or []
            if isinstance(corr, list):
                corr_str = ", ".join(corr)
            else:
                corr_str = str(corr)

            src = q.get("source") or "Annales"
            yr = q.get("year")
            if yr and str(yr) not in src:
                src += f" ({yr})"

            row_bg = COLOR_WHITE if idx % 2 == 1 else COLOR_CARD_BG
            table_data.append([
                Paragraph(f"<b>Q{idx}</b>", ParagraphStyle("TC1", fontName="Helvetica-Bold", fontSize=9, textColor=COLOR_PRIMARY_NAVY, alignment=TA_CENTER)),
                Paragraph(q_type, ParagraphStyle("TC2", fontName="Helvetica", fontSize=8.5, textColor=COLOR_SLATE_MUTED, alignment=TA_CENTER)),
                Paragraph(f"<b>{corr_str}</b>", ParagraphStyle("TC3", fontName="Helvetica-Bold", fontSize=10, textColor=COLOR_EMERALD, alignment=TA_CENTER)),
                Paragraph(src, ParagraphStyle("TC4", fontName="Helvetica", fontSize=8.5, textColor=COLOR_SLATE_DARK)),
            ])

        t_corr = Table(table_data, colWidths=[40, 55, 125, 280])
        t_corr.setStyle(TableStyle([
            ("BACKGROUND", (0, 0), (-1, 0), COLOR_PRIMARY_NAVY),
            ("BOX", (0, 0), (-1, -1), 1, COLOR_CARD_BORDER),
            ("INNERGRID", (0, 0), (-1, -1), 0.5, COLOR_CARD_BORDER),
            ("TOPPADDING", (0, 0), (-1, -1), 4),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
        ]))
        story.append(t_corr)
        story.append(Spacer(1, 15))

        # Perles et explications sélectionnées
        has_explanations = any(q.get("explanation") for q in qcms)
        if has_explanations:
            story.append(Paragraph("Perles Cliniques & Justifications Clés :", section_h2))
            for idx, q in enumerate(qcms, start=1):
                exp = q.get("explanation")
                if exp:
                    clean_exp = clean_reportlab_text(exp, max_len=260)
                    if len(clean_exp) > 280:
                        clean_exp = clean_exp[:260].rsplit(".", 1)[0] + "."
                    story.append(Paragraph(f"<b>Q{idx} :</b> {clean_exp}", ParagraphStyle("Exp", fontName="Helvetica", fontSize=8.5, leading=12, textColor=COLOR_SLATE_DARK, spaceAfter=4)))

    doc.build(story, canvasmaker=NumberedCanvas)


# -----------------------------------------------------------------------------
# 7. Fusion avec le Cours Officiel (PyMuPDF)
# -----------------------------------------------------------------------------
def merge_reportlab_and_course_pdf(
    reportlab_pdf_path: Path,
    course_raw_pdf_path: Optional[Path],
    final_output_path: Path
):
    """
    Insère le cours officiel (PDF) immédiatement après la Section 1 (Fiche de Synthèse)
    et avant la Section 3 (QCMs d'Entraînement).
    """
    doc_main = pymupdf.open(str(reportlab_pdf_path))

    if not course_raw_pdf_path or not course_raw_pdf_path.exists():
        # Pas de cours officiel à fusionner : sauvegarder directement
        doc_main.save(str(final_output_path))
        doc_main.close()
        return

    try:
        doc_course = pymupdf.open(str(course_raw_pdf_path))
        # Déterminer où commence la Section 3
        # On recherche le texte "SECTION 3" dans doc_main
        insert_page_idx = 2  # Par défaut après la page 2 (Couverture + Fiche)
        for page_idx in range(len(doc_main)):
            txt = doc_main[page_idx].get_text("text")
            if "SECTION 3" in txt:
                insert_page_idx = page_idx
                break

        # Insérer les pages du polycopié à insert_page_idx
        doc_main.insert_pdf(doc_course, start_at=insert_page_idx)
        doc_main.save(str(final_output_path))
        doc_course.close()
        doc_main.close()
    except Exception as e:
        print(f"   ⚠️ Erreur lors de la fusion PyMuPDF : {e}. Utilisation du PDF généré direct.")
        doc_main.save(str(final_output_path))
        doc_main.close()


# -----------------------------------------------------------------------------
# 8. Téléversement Supabase Storage & Mise à jour de la Table `courses`
# -----------------------------------------------------------------------------
def upload_bundle_to_supabase(
    pdf_path: Path,
    module_id: str,
    course_id: str,
    supabase_url: str,
    supabase_key: str,
    is_hyper: bool,
    residanat_sessions: List[str],
    qcm_count: int
) -> Optional[str]:
    bucket = "residanat_2027_livrets"
    storage_filename = f"{module_id}/{course_id}_Livret_Residanat_2027.pdf"
    upload_url = f"{supabase_url}/storage/v1/object/{bucket}/{storage_filename}"

    headers = {
        "apikey": supabase_key,
        "Authorization": f"Bearer {supabase_key}",
        "Content-Type": "application/pdf",
        "x-upsert": "true",
    }

    try:
        pdf_bytes = pdf_path.read_bytes()
        r_up = requests.post(upload_url, headers=headers, data=pdf_bytes, timeout=45)
        if r_up.status_code not in (200, 201):
            print(f"   ❌ Échec upload Supabase Storage ({r_up.status_code}): {r_up.text}")
            return None

        public_url = f"{supabase_url}/storage/v1/object/public/{bucket}/{storage_filename}"
        print(f"   ☁️ Livret téléversé avec succès dans Supabase Storage : {public_url}")

        # Mise à jour de la table courses
        patch_url = f"{supabase_url}/rest/v1/courses?id=eq.{course_id}"
        patch_headers = {
            "apikey": supabase_key,
            "Authorization": f"Bearer {supabase_key}",
            "Content-Type": "application/json",
            "Prefer": "return=minimal"
        }
        patch_body = {
            "bundle_pdf_url": public_url,
            "bundle_generated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "is_hypertombable": is_hyper,
            "residanat_years": residanat_sessions,
            "qcm_count": qcm_count,
        }
        r_db = requests.patch(patch_url, headers=patch_headers, json=patch_body, timeout=15)
        if r_db.status_code in (200, 204):
            print(f"   ✅ Table courses mise à jour pour {course_id} !")
        else:
            print(f"   ⚠️ Avis mise à jour DB ({r_db.status_code}): {r_db.text}")

        return public_url
    except Exception as e:
        print(f"   ❌ Exception upload Supabase : {e}")
        return None


# -----------------------------------------------------------------------------
# 9. Pipeline Principal de Traitement d'un Cours
# -----------------------------------------------------------------------------
def process_single_course(
    course: Dict[str, Any],
    supabase_url: str,
    supabase_key: str,
    output_dir: Path,
    dry_run: bool = False
) -> Optional[Dict[str, Any]]:
    cid = course["id"]
    cname = course.get("name", cid)
    mid = course.get("module_id", "Module")

    print("\n" + "=" * 65)
    print(f"📖 TRAITEMENT DU COURS : {cname} (ID: {cid})")
    print(f"   Module : {mid}")
    print("=" * 65)

    # 1. Extraction Fiche de Synthèse
    summary = get_course_summary_data(cid, cname, supabase_url, supabase_key)
    has_summary = summary is not None
    print(f"   • Fiche de Synthèse : {'Présente' if has_summary else 'Absente'}")

    # 2. Extraction QCMs
    qcms = get_course_qcms(cid, cname, mid)
    print(f"   • Banque de QCMs : {len(qcms)} QCMs trouvés")

    # 3. Analyse Tombabilité
    is_hyper, sessions, total_qcms = analyze_hypertombable(qcms)
    if is_hyper:
        print(f"   🔥 STATUT : HYPERTOMBABLE AU CONCOURS ({len(sessions)} sessions : {', '.join(sessions[:5])})")
    else:
        print("   📘 STATUT : Standard du Programme")

    # Création du dossier temporaire
    with tempfile.TemporaryDirectory() as tmp_dir:
        tmp_path = Path(tmp_dir)

        # 4. Téléchargement du cours PDF officiel
        course_pdf_url = course.get("pdf_url") or course.get("pdf_storage_path")
        course_raw_pdf = tmp_path / "course_raw.pdf"
        downloaded = False
        if course_pdf_url:
            print(f"   📥 Téléchargement du polycopié officiel...")
            downloaded = download_course_raw_pdf(course_pdf_url, course_raw_pdf)
            if downloaded:
                print(f"   ✅ Polycopié téléchargé ({course_raw_pdf.stat().st_size} octets)")

        # 5. Rendu ReportLab
        reportlab_out = tmp_path / "reportlab_sections.pdf"
        print(f"   🎨 Génération ReportLab (Couverture + Synthèse + QCMs + Corrigé type)...")
        build_reportlab_booklet(
            output_pdf_path=reportlab_out,
            course_data={"name": cname, "module_name": mid, "module_id": mid},
            summary_data=summary,
            qcms=qcms,
            is_hyper=is_hyper,
            residanat_sessions=sessions
        )

        # 6. Fusion avec le polycopié
        final_filename = f"{mid}_{cid}_Livret_Residanat_2027.pdf"
        final_filename = re.sub(r'[\\/*?:"<>| ]', "_", final_filename)
        final_local_pdf = output_dir / final_filename

        print(f"   📑 Fusion finale du Livret...")
        merge_reportlab_and_course_pdf(
            reportlab_pdf_path=reportlab_out,
            course_raw_pdf_path=course_raw_pdf if downloaded else None,
            final_output_path=final_local_pdf
        )

        print(f"   🎉 Livret PDF généré avec succès ({final_local_pdf.stat().st_size} octets) : {final_local_pdf.name}")

        # 7. Upload & Synchronisation Supabase
        bundle_url = None
        if not dry_run and supabase_url and supabase_key:
            bundle_url = upload_bundle_to_supabase(
                pdf_path=final_local_pdf,
                module_id=mid,
                course_id=cid,
                supabase_url=supabase_url,
                supabase_key=supabase_key,
                is_hyper=is_hyper,
                residanat_sessions=sessions,
                qcm_count=len(qcms)
            )

        return {
            "course_id": cid,
            "course_name": cname,
            "module_id": mid,
            "is_hypertombable": is_hyper,
            "residanat_sessions": sessions,
            "qcms_count": len(qcms),
            "has_course_pdf": downloaded,
            "local_path": str(final_local_pdf),
            "bundle_url": bundle_url
        }


# -----------------------------------------------------------------------------
# 10. CLI & Déclenchement Automatisé
# -----------------------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(description="Medsina — Générateur de Livrets de Révision Résidanat 2027")
    parser.add_argument("--course-id", type=str, default=None, help="ID spécifique du cours à générer")
    parser.add_argument("--all", action="store_true", default=False, help="Traiter tous les cours éligibles")
    parser.add_argument("--limit", type=int, default=10, help="Nombre max de cours à traiter en mode batch (défaut: 10)")
    parser.add_argument("--hypertombable-only", action="store_true", default=False, help="Filtrer uniquement les cours hypertombables")
    parser.add_argument("--dry-run", action="store_true", default=False, help="Générer en local sans upload Supabase")
    parser.add_argument("--output-dir", type=str, default=str(WORKSPACE_ROOT / "livrets_residanat_2027"), help="Dossier de sortie local")
    args = parser.parse_args()

    out_dir = Path(args.output_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    supabase_url, supabase_key = get_supabase_credentials()

    print("=" * 70)
    print("🚀 MEDSINA — AGENT GÉNÉRATEUR DE LIVRETS DE RÉVISION RÉSIDANAT 2027")
    print(f"📁 Dossier de sortie : {out_dir.resolve()}")
    print(f"⚙️ Mode              : {'DRY RUN (Local uniquement)' if args.dry_run else 'OFFICIEL (Upload Supabase actif)'}")
    print("=" * 70)

    # Récupérer les cours
    headers = {"apikey": supabase_key, "Authorization": f"Bearer {supabase_key}"}
    if args.course_id:
        r = requests.get(f"{supabase_url}/rest/v1/courses?id=eq.{args.course_id}", headers=headers).json()
        target_courses = r if isinstance(r, list) and r else [{"id": args.course_id, "name": args.course_id, "module_id": "General"}]
    else:
        # Récupérer les cours ayant soit un pdf soit des QCMs
        r = requests.get(f"{supabase_url}/rest/v1/courses?select=id,name,module_id,has_pdf,pdf_url,pdf_storage_path,questions_count&limit={args.limit * 3}", headers=headers).json()
        target_courses = r if isinstance(r, list) else []

    results = []
    processed_count = 0
    for c in target_courses:
        if processed_count >= args.limit:
            break
        res = process_single_course(
            course=c,
            supabase_url=supabase_url,
            supabase_key=supabase_key,
            output_dir=out_dir,
            dry_run=args.dry_run
        )
        if res:
            results.append(res)
            processed_count += 1

    print("\n" + "=" * 70)
    print("📊 BILAN DE LA GÉNÉRATION DES LIVRETS :")
    print(f"• Cours traités : {len(results)}")
    print(f"• Livrets Hypertombables 🔥 : {sum(1 for r in results if r['is_hypertombable'])}")
    for r in results:
        status_tag = "🔥 HYPERTOMBABLE" if r["is_hypertombable"] else "📘 Standard"
        print(f"  - [{status_tag}] {r['course_name']} ({r['qcms_count']} QCMs)")
        if r["bundle_url"]:
            print(f"    ☁️ URL : {r['bundle_url']}")
    print("=" * 70)


if __name__ == "__main__":
    main()
