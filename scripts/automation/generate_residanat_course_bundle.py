#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
=============================================================================
MEDSINA — GÉNÉRATEUR AUTOMATIQUE DE LIVRETS DE RÉVISION « RÉSIDANAT 2027 »
=============================================================================
Crée un Livret PDF All-in-One pour chaque cours éligible (SI ET SEULEMENT SI
tous les éléments requis sont présents : Cours officiel, Fiche de synthèse,
Pièges concours, Mindmap, QCM et Corrigé type) :
1. Couverture Premium Concours 2027 avec Badge Hypertombable et années de concours
2. Section 1 : Fiche de Synthèse (Points Clés, Pièges Concours, Diagnostic & Traitement)
3. Section 2 : Mind Map Visuelle & Arbre Décisionnel
4. Section 3 : Cours Officiel complet (Polycopié de faculté / drive fusionné)
5. Section 4 : Banque de QCMs d'Entraînement SANS correction (Mode Examen Blanc)
6. Section 5 : Corrigé Type & Grille de Correction (Dernière Page avec Perles Cliniques)

Validation Humaine :
- Tout livret généré est enregistré avec `bundle_validation_status = 'pending_review'`.
- Il n'est publié aux étudiants et diffusé qu'après approbation de l'Admin.

Stockage :
- Google Drive / Supabase Storage : bucket 'residanat_2027_livrets'
- Table Supabase : 'courses' (bundle_pdf_url, bundle_validation_status, bundle_has_mindmap, ...)
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

try:
    from booklet_notification_broadcaster import broadcast_residanat_bundle
except ImportError:
    broadcast_residanat_bundle = None

try:
    from gdrive_booklets_manager import upload_booklet_to_gdrive, update_course_in_supabase_with_gdrive
except ImportError:
    upload_booklet_to_gdrive = None
    update_course_in_supabase_with_gdrive = None

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

QCMS_DIR = resolve_resource_path("database/raw_qcms")
if not QCMS_DIR.exists():
    QCMS_DIR = resolve_resource_path("assets/data/qcms")
SUMMARIES_FILE = resolve_resource_path("assets/data/course_summaries.json")
MINDMAPS_JSON_FILE = resolve_resource_path("assets/data/course_mindmaps.json")
MINDMAPS_DIR = resolve_resource_path("assets/mindmaps")

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

    url = (
        os.environ.get("SUPABASE_URL")
        or env_vars.get("SUPABASE_URL")
        or "https://qzfssrhhuorljftpdvjm.supabase.co"
    )
    key = (
        os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
        or os.environ.get("SUPABASE_KEY")
        or env_vars.get("SUPABASE_SERVICE_ROLE_KEY")
        or env_vars.get("SUPABASE_KEY")
        or "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF6ZnNzcmhodW9ybGpmdHBkdmptIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MTYxMjg1NCwiZXhwIjoyMTA3MTg4ODU0fQ.-KCUgZdY8RDUwvNOUAabDhQFwv5FFGHYz0J-dM7Cic4"
    )
    return url.strip().rstrip("/"), key.strip()


# -----------------------------------------------------------------------------
# 3. Téléchargement et Validation du PDF (Cours Officiel ou Mindmap)
# -----------------------------------------------------------------------------
def _is_valid_pdf_file(pdf_path: Path) -> bool:
    """Vérifie que le fichier existe, n'est pas vide et s'ouvre proprement avec PyMuPDF."""
    if not pdf_path.exists() or pdf_path.stat().st_size < 512:
        return False
    try:
        doc = pymupdf.open(str(pdf_path))
        page_count = len(doc)
        doc.close()
        return page_count > 0
    except Exception:
        return False


def download_course_raw_pdf(
    pdf_url: Optional[str],
    dest_path: Path,
    supabase_url: str = "",
    pdf_drive_id: Optional[str] = None
) -> bool:
    raw_url = str(pdf_url).strip() if pdf_url and str(pdf_url).lower() != "none" else ""
    drive_id = str(pdf_drive_id).strip() if pdf_drive_id and str(pdf_drive_id).lower() != "none" else ""

    if not raw_url and drive_id:
        raw_url = f"https://drive.google.com/uc?export=download&id={drive_id}"

    if not raw_url:
        return False

    # Si chemin relatif Supabase Storage (ex: Blida_CARDIOLOGIE/cours.pdf)
    if not raw_url.startswith("http://") and not raw_url.startswith("https://"):
        if supabase_url:
            clean_rel = raw_url.lstrip("/")
            raw_url = f"{supabase_url}/storage/v1/object/public/course-documents/{clean_rel}"
        else:
            return False

    session = requests.Session()

    # Cas 1 : Lien Google Drive
    drive_match = re.search(r"(?:/d/|id=)([-_\w]{20,})", raw_url) or re.search(r"[-_\w]{25,}", raw_url)
    if ("drive.google.com" in raw_url or "docs.google.com" in raw_url) and drive_match:
        fid = drive_match.group(1) if drive_match.lastindex else drive_match.group(0)
        candidates = [
            f"https://drive.google.com/uc?export=download&id={fid}",
            f"https://drive.usercontent.google.com/download?id={fid}&export=download&confirm=t",
        ]
        for dl_url in candidates:
            try:
                r = session.get(dl_url, stream=True, timeout=30)
                for k, v in r.cookies.items():
                    if k.startswith("download_warning"):
                        confirm_url = f"https://drive.google.com/uc?export=download&confirm={v}&id={fid}"
                        r = session.get(confirm_url, stream=True, timeout=30)
                        break

                if r.status_code == 200 and (r.content.startswith(b"%PDF") or "application/pdf" in r.headers.get("content-type", "").lower()):
                    dest_path.write_bytes(r.content)
                    if _is_valid_pdf_file(dest_path):
                        return True
            except Exception as e:
                print(f"   ⚠️ Erreur téléchargement Google Drive ({fid}): {e}")
        return False

    # Cas 2 : Téléchargement direct HTTP/HTTPS
    try:
        r = session.get(raw_url, stream=True, timeout=30)
        if r.status_code == 200 and (r.content.startswith(b"%PDF") or "application/pdf" in r.headers.get("content-type", "").lower()):
            dest_path.write_bytes(r.content)
            return _is_valid_pdf_file(dest_path)
    except Exception as e:
        print(f"   ⚠️ Erreur téléchargement direct ({raw_url}): {e}")
        return False

    return False


_LOCAL_MINDMAPS_CACHE = None

def get_course_mindmap_data(
    course: Dict[str, Any],
    supabase_url: str,
    supabase_key: str
) -> Optional[Dict[str, Any]]:
    """Récupère les données Mindmap depuis Supabase `course_mindmaps`, `courses`, ou `course_mindmaps.json`."""
    global _LOCAL_MINDMAPS_CACHE
    course_id = course["id"]
    course_name = course.get("name", "")
    result: Dict[str, Any] = {}

    # 1. Supabase table course_mindmaps
    if supabase_url and supabase_key:
        try:
            headers = {"apikey": supabase_key, "Authorization": f"Bearer {supabase_key}"}
            r = requests.get(f"{supabase_url}/rest/v1/course_mindmaps?course_id=eq.{course_id}", headers=headers, timeout=10)
            if r.status_code == 200 and r.json():
                result = dict(r.json()[0])
        except Exception:
            pass

    # 2. Fallback local course_mindmaps.json
    if not result and MINDMAPS_JSON_FILE.exists():
        if _LOCAL_MINDMAPS_CACHE is None:
            try:
                _LOCAL_MINDMAPS_CACHE = json.loads(MINDMAPS_JSON_FILE.read_text(encoding="utf-8"))
            except Exception:
                _LOCAL_MINDMAPS_CACHE = {}

        if isinstance(_LOCAL_MINDMAPS_CACHE, dict):
            if course_id in _LOCAL_MINDMAPS_CACHE:
                result = dict(_LOCAL_MINDMAPS_CACHE[course_id])
            else:
                c_id_lower = course_id.lower().strip()
                c_name_lower = course_name.lower().strip()
                for k, v in _LOCAL_MINDMAPS_CACHE.items():
                    if not isinstance(v, dict):
                        continue
                    v_id = str(v.get("course_id", k)).lower().strip()
                    v_name = str(v.get("course_name", "")).lower().strip()
                    if v_id == c_id_lower or (c_name_lower and v_name == c_name_lower):
                        result = dict(v)
                        break

    # Compléter avec les champs de la table `courses`
    mm_pdf_url = result.get("mindmap_pdf_url") or course.get("mindmap_pdf_url")
    mm_drive_id = result.get("mindmap_drive_id") or course.get("mindmap_drive_id")
    pdf_file = result.get("pdf_file")
    local_pdf_path: Optional[Path] = None
    if pdf_file:
        cand = MINDMAPS_DIR / pdf_file
        if cand.exists():
            local_pdf_path = cand
    if not local_pdf_path and MINDMAPS_DIR.exists():
        cand = MINDMAPS_DIR / f"{course_id}_mindmap.pdf"
        if cand.exists():
            local_pdf_path = cand

    branches = result.get("branches") or []
    if isinstance(branches, str):
        try:
            branches = json.loads(branches)
        except Exception:
            branches = []

    has_branches = isinstance(branches, list) and len(branches) > 0
    has_pdf_ref = bool(mm_pdf_url or mm_drive_id or local_pdf_path)

    if not has_branches and not has_pdf_ref:
        return None

    return {
        "branches": branches,
        "diagnostic_criteria": result.get("diagnostic_criteria"),
        "treatment_summary": result.get("treatment_summary"),
        "mindmap_pdf_url": mm_pdf_url,
        "mindmap_drive_id": mm_drive_id,
        "local_pdf_path": str(local_pdf_path) if local_pdf_path else None,
    }


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
        [Paragraph("<b>Section 2 :</b> Mind Map Visuelle & Arbre Décisionnel", body_style)],
        [Paragraph("<b>Section 3 :</b> Cours & Polycopié Officiel de la Faculté", body_style)],
        [Paragraph(f"<b>Section 4 :</b> Entraînement QCMs SANS correction ({len(qcms)} Questions réelles)", body_style)],
        [Paragraph("<b>Section 5 :</b> Grille Officielle du Corrigé Type & Perles Cliniques (Dernière Page)", body_style)],
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

    story.append(Spacer(1, 20))
    story.append(PageBreak())

    # =========================================================================
    # SECTION 2 : MIND MAP VISUELLE & ARBRE DÉCISIONNEL
    # =========================================================================
    story.append(Paragraph("SECTION 2 — MIND MAP VISUELLE & ARBRE DÉCISIONNEL", section_h1))
    story.append(HRFlowable(width="100%", thickness=1.5, color=COLOR_CYAN_ACCENT, spaceAfter=10))
    story.append(Paragraph(
        f"<b>Carte Mentale Structurée :</b> {clean_reportlab_text(course_name)}",
        ParagraphStyle("MMSub", fontName="Helvetica-Bold", fontSize=10.5, textColor=COLOR_PRIMARY_NAVY, spaceAfter=10)
    ))

    branches = (mindmap_data or {}).get("branches") or []
    if branches:
        for b_idx, branch in enumerate(branches, start=1):
            b_title = clean_reportlab_text(branch.get("title", f"Branche {b_idx}"))
            b_items = branch.get("items") or []
            branch_rows = [[Paragraph(f"<b>{b_idx}. {b_title}</b>", ParagraphStyle("MMBranchH", fontName="Helvetica-Bold", fontSize=10, textColor=COLOR_WHITE))]]
            for it in b_items:
                branch_rows.append([Paragraph(f"• {clean_reportlab_text(it)}", bullet_style)])
            t_branch = Table(branch_rows, colWidths=[500])
            t_branch.setStyle(TableStyle([
                ("BACKGROUND", (0, 0), (-1, 0), COLOR_ROYAL_BLUE),
                ("BACKGROUND", (0, 1), (-1, -1), COLOR_CARD_BG),
                ("BOX", (0, 0), (-1, -1), 1, COLOR_CARD_BORDER),
                ("TOPPADDING", (0, 0), (-1, -1), 5),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
                ("LEFTPADDING", (0, 0), (-1, -1), 10),
                ("RIGHTPADDING", (0, 0), (-1, -1), 10),
                ("ROUNDEDCORNERS", [6, 6, 6, 6]),
            ]))
            story.append(KeepTogether([t_branch, Spacer(1, 8)]))
    else:
        story.append(Paragraph("<i>La carte mentale HD vectorielle est jointe ci-après.</i>", body_style))

    story.append(PageBreak())

    # =========================================================================
    # SECTION 3 : COURS & POLYCOPIÉ OFFICIEL DE LA FACULTÉ
    # =========================================================================
    story.append(Paragraph("SECTION 3 — COURS & POLYCOPIÉ OFFICIEL DE LA FACULTÉ", section_h1))
    story.append(HRFlowable(width="100%", thickness=1.5, color=COLOR_ROYAL_BLUE, spaceAfter=12))
    story.append(Paragraph(
        f"Support officiel complet pour <b>{clean_reportlab_text(course_name)}</b> (Module : {clean_reportlab_text(module_name)}). "
        "Les pages suivantes reproduisent intégralement le polycopié officiel de la faculté.",
        body_style
    ))
    story.append(PageBreak())
    # (Les pages du cours officiel seront intercalées ici lors de la fusion PyMuPDF, juste avant la Section 4)

    # =========================================================================
    # SECTION 4 : QCMs D'ENTRAÎNEMENT SANS CORRECTION
    # =========================================================================
    story.append(Paragraph("SECTION 4 — BANQUE DE QCMs D'ENTRAÎNEMENT", section_h1))
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
    # SECTION 5 : DERNIÈRE PAGE — GRILLE DE CORRECTION OFFICIELLE (CORRIGÉ TYPE)
    # =========================================================================
    story.append(Paragraph("SECTION 5 — CORRIGÉ TYPE & GRILLE OFFICIELLE", section_h1))
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
def _clean_third_party_footers(doc_course: Any):
    """Purge automatique des pieds de page tiers (MBset / liens / logos)."""
    white_pix = pymupdf.Pixmap(pymupdf.csRGB, pymupdf.IRect(0, 0, 30, 25), 0)
    white_pix.clear_with(255)
    for page in doc_course:
        for img in page.get_images():
            if img[2] == 30 and img[3] == 25:
                try:
                    page.replace_image(img[0], pixmap=white_pix)
                except Exception:
                    pass
        for r in page.search_for("mbset"):
            if r.y1 > page.rect.height * 0.65:
                page.draw_rect(pymupdf.Rect(r.x0 - 3, r.y0 - 3, r.x1 + 3, r.y1 + 3), color=(1, 1, 1), fill=(1, 1, 1), overlay=True)
        pw, ph = page.rect.width, page.rect.height
        page.draw_rect(pymupdf.Rect(pw / 2 - 60, ph - 30, pw / 2 + 60, ph - 5), color=(1, 1, 1), fill=(1, 1, 1), overlay=True)
        for l in page.get_links():
            if "mbset" in l.get("uri", "").lower():
                page.delete_link(l)


def merge_reportlab_and_course_pdf(
    reportlab_pdf_path: Path,
    course_raw_pdf_path: Optional[Path],
    final_output_path: Path,
    mindmap_pdf_path: Optional[Path] = None
):
    """
    Insère :
    1. La Mind Map PDF (si disponible) dans la Section 2 (juste avant "SECTION 3 — COURS").
    2. Le Cours Officiel PDF dans la Section 3 (juste avant "SECTION 4 — BANQUE DE QCMs").
    """
    doc_main = pymupdf.open(str(reportlab_pdf_path))

    try:
        # 1. Insertion Mind Map PDF avant Section 3
        if mindmap_pdf_path and mindmap_pdf_path.exists() and _is_valid_pdf_file(mindmap_pdf_path):
            doc_mm = pymupdf.open(str(mindmap_pdf_path))
            mm_insert_idx = None
            for page_idx in range(len(doc_main)):
                txt = doc_main[page_idx].get_text("text")
                if "SECTION 3" in txt and "COURS" in txt:
                    mm_insert_idx = page_idx
                    break
            if mm_insert_idx is not None:
                doc_main.insert_pdf(doc_mm, start_at=mm_insert_idx)
            doc_mm.close()

        # 2. Insertion Cours Officiel PDF avant Section 4
        if course_raw_pdf_path and course_raw_pdf_path.exists() and _is_valid_pdf_file(course_raw_pdf_path):
            doc_course = pymupdf.open(str(course_raw_pdf_path))
            course_insert_idx = None
            for page_idx in range(len(doc_main)):
                txt = doc_main[page_idx].get_text("text")
                if "SECTION 4" in txt and "QCM" in txt:
                    course_insert_idx = page_idx
                    break
            if course_insert_idx is None:
                # Fallback : après la page Section 3
                for page_idx in range(len(doc_main)):
                    txt = doc_main[page_idx].get_text("text")
                    if "SECTION 3" in txt and "COURS" in txt:
                        course_insert_idx = page_idx + 1
                        break
            if course_insert_idx is None:
                course_insert_idx = min(3, len(doc_main))

            _clean_third_party_footers(doc_course)
            doc_main.insert_pdf(doc_course, start_at=course_insert_idx)
            doc_course.close()

        doc_main.save(str(final_output_path))
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
    qcm_count: int,
    bundle_has_mindmap: bool = True
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

        # Mise à jour de la table courses (statut pending_review pour validation humaine Admin)
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
            "bundle_validation_status": "pending_review",
            "bundle_has_mindmap": bundle_has_mindmap,
            "bundle_reviewed_at": None,
        }
        r_db = requests.patch(patch_url, headers=patch_headers, json=patch_body, timeout=15)
        if r_db.status_code in (200, 204):
            print(f"   ✅ Table courses mise à jour (statut: pending_review) pour {course_id} !")
        else:
            print(f"   ⚠️ Avis mise à jour DB ({r_db.status_code}): {r_db.text}")

        return public_url
    except Exception as e:
        print(f"   ❌ Exception upload Supabase : {e}")
        return None


# -----------------------------------------------------------------------------
# 9. Pipeline Principal de Traitement d'un Cours
# -----------------------------------------------------------------------------
def _parse_json_list(val: Any) -> List[Any]:
    if isinstance(val, list):
        return [x for x in val if str(x).strip()]
    if isinstance(val, str) and val.strip():
        try:
            parsed = json.loads(val)
            if isinstance(parsed, list):
                return [x for x in parsed if str(x).strip()]
        except Exception:
            return [val.strip()]
    return []


def process_single_course(
    course: Dict[str, Any],
    supabase_url: str,
    supabase_key: str,
    output_dir: Path,
    dry_run: bool = False,
    broadcast: bool = False,
    showcase: bool = False,
    hypertombable_only: bool = False
) -> Optional[Dict[str, Any]]:
    cid = course["id"]
    cname = course.get("name", cid)
    mid = course.get("module_id", "Module")

    print("\n" + "=" * 65)
    print(f"📖 TRAITEMENT DU COURS : {cname} (ID: {cid})")
    print(f"   Module : {mid}")
    print("=" * 65)

    # 1. Extraction Fiche de Synthèse & Pièges Concours
    summary = get_course_summary_data(cid, cname, supabase_url, supabase_key)
    summary_md = str((summary or {}).get("summary_markdown") or "").strip()
    has_fiche_synthese = (
        summary is not None
        and len(summary_md) >= 30
        and "en cours d'enrichissement" not in summary_md.lower()
    )
    exam_traps = _parse_json_list((summary or {}).get("exam_traps"))
    has_piege_concours = len(exam_traps) > 0

    print(f"   • Fiche de Synthèse : {'✅ Présente' if has_fiche_synthese else '❌ Absente / Incomplète'}")
    print(f"   • Pièges Concours   : {'✅ Présents (' + str(len(exam_traps)) + ')' if has_piege_concours else '❌ Absents'}")

    # 2. Extraction Mindmap
    mindmap_data = get_course_mindmap_data(course, supabase_url, supabase_key)
    has_mindmap_branches = bool(mindmap_data and isinstance(mindmap_data.get("branches"), list) and len(mindmap_data["branches"]) > 0)

    # 3. Extraction QCMs & Corrigé Type
    qcms = get_course_qcms(cid, cname, mid)
    valid_qcms = [
        q for q in qcms
        if (q.get("questionText") or q.get("question")) and (q.get("options") or [])
    ]
    qcms_with_answers = [
        q for q in valid_qcms
        if (q.get("correctAnswers") or q.get("answer"))
    ]
    has_qcm = len(valid_qcms) > 0
    has_corrige_type = has_qcm and (len(qcms_with_answers) == len(valid_qcms))

    print(f"   • Banque de QCMs    : {'✅ ' + str(len(valid_qcms)) + ' QCMs' if has_qcm else '❌ Aucun QCM'}")
    print(f"   • Corrigé Type      : {'✅ Complet (' + str(len(qcms_with_answers)) + '/' + str(len(valid_qcms)) + ')' if has_corrige_type else '❌ Manquant ou incomplet'}")

    # 4. Analyse Tombabilité
    is_hyper, sessions, _ = analyze_hypertombable(valid_qcms)
    if hypertombable_only and not is_hyper:
        print("   ⏭️ Cours ignoré (--hypertombable-only actif).")
        return None

    if is_hyper:
        print(f"   🔥 STATUT : HYPERTOMBABLE AU CONCOURS ({len(sessions)} sessions : {', '.join(sessions[:5])})")
    else:
        print("   📘 STATUT : Standard du Programme")

    # Vérification préalable rapide avant téléchargement si un des éléments textuels manque déjà
    pre_missing = []
    if not has_fiche_synthese:
        pre_missing.append("Fiche de synthèse")
    if not has_piege_concours:
        pre_missing.append("Piège Concours")
    if not has_qcm:
        pre_missing.append("QCM")
    if not has_corrige_type:
        pre_missing.append("Corrigé type")
    if not mindmap_data:
        pre_missing.append("Mindmap")

    if pre_missing:
        print(f"   ⛔ GÉNÉRATION REFUSÉE — Éléments requis manquants : {', '.join(pre_missing)}")
        return None

    # Création du dossier temporaire pour télécharger & vérifier le PDF du Cours Officiel + Mindmap PDF
    with tempfile.TemporaryDirectory() as tmp_dir:
        tmp_path = Path(tmp_dir)

        # 5. Téléchargement & Validation du Cours Officiel PDF
        course_pdf_url = course.get("pdf_url") or course.get("pdf_storage_path")
        course_drive_id = course.get("pdf_drive_id")
        course_raw_pdf = tmp_path / "course_raw.pdf"
        has_cours_officiel = False
        if course_pdf_url or course_drive_id:
            print("   📥 Téléchargement et vérification du polycopié officiel...")
            has_cours_officiel = download_course_raw_pdf(
                pdf_url=course_pdf_url,
                dest_path=course_raw_pdf,
                supabase_url=supabase_url,
                pdf_drive_id=course_drive_id,
            )
            if has_cours_officiel:
                print(f"   ✅ Cours Officiel validé ({course_raw_pdf.stat().st_size} octets)")
            else:
                print("   ❌ Cours Officiel introuvable ou PDF invalide")

        # 6. Téléchargement / Résolution du Mindmap PDF (si disponible)
        mindmap_pdf_path: Optional[Path] = None
        if mindmap_data:
            local_mm = mindmap_data.get("local_pdf_path")
            if local_mm and _is_valid_pdf_file(Path(local_mm)):
                mindmap_pdf_path = Path(local_mm)
            elif mindmap_data.get("mindmap_pdf_url") or mindmap_data.get("mindmap_drive_id"):
                mm_dl = tmp_path / "mindmap_raw.pdf"
                if download_course_raw_pdf(
                    pdf_url=mindmap_data.get("mindmap_pdf_url"),
                    dest_path=mm_dl,
                    supabase_url=supabase_url,
                    pdf_drive_id=mindmap_data.get("mindmap_drive_id"),
                ):
                    mindmap_pdf_path = mm_dl

        has_mindmap = has_mindmap_branches or (mindmap_pdf_path is not None)
        print(f"   • Mindmap           : {'✅ Présente' if has_mindmap else '❌ Absente'}")

        # CONDITION STRICTE : SI ET SEULEMENT SI TOUS LES 6 ÉLÉMENTS SONT PRÉSENTS
        missing_final = []
        if not has_cours_officiel:
            missing_final.append("Cours officiel")
        if not has_fiche_synthese:
            missing_final.append("Fiche de synthèse")
        if not has_piege_concours:
            missing_final.append("Piège Concours")
        if not has_mindmap:
            missing_final.append("Mindmap")
        if not has_qcm:
            missing_final.append("QCM")
        if not has_corrige_type:
            missing_final.append("Corrigé type")

        if missing_final:
            print(f"   ⛔ GÉNÉRATION REFUSÉE — Éléments requis manquants : {', '.join(missing_final)}")
            return None

        # 7. Rendu ReportLab
        reportlab_out = tmp_path / "reportlab_sections.pdf"
        print("   🎨 Génération ReportLab (Couverture + Synthèse + Mindmap + Transition Cours + QCMs + Corrigé type)...")
        build_reportlab_booklet(
            output_pdf_path=reportlab_out,
            course_data={"name": cname, "module_name": mid, "module_id": mid},
            summary_data=summary,
            qcms=valid_qcms,
            is_hyper=is_hyper,
            residanat_sessions=sessions,
            mindmap_data=mindmap_data
        )

        # 8. Fusion avec le Mindmap PDF et le Polycopié Officiel
        final_filename = f"{mid}_{cid}_Livret_Residanat_2027.pdf"
        final_filename = re.sub(r'[\\/*?:"<>| ]', "_", final_filename)
        final_local_pdf = output_dir / final_filename

        print("   📑 Fusion finale du Livret (Mindmap + Cours Officiel)...")
        merge_reportlab_and_course_pdf(
            reportlab_pdf_path=reportlab_out,
            course_raw_pdf_path=course_raw_pdf,
            final_output_path=final_local_pdf,
            mindmap_pdf_path=mindmap_pdf_path
        )

        print(f"   🎉 Livret PDF généré avec succès ({final_local_pdf.stat().st_size} octets) : {final_local_pdf.name}")

        # 9. Upload & Hébergement Google Drive (Prioritaire pour économiser Supabase)
        bundle_url = None
        if not dry_run:
            if upload_booklet_to_gdrive:
                try:
                    g_res = upload_booklet_to_gdrive(
                        pdf_path=final_local_pdf,
                        module_id=mid,
                        course_id=cid
                    )
                    bundle_url = g_res.get("view_link")
                    file_id = g_res.get("file_id")
                    if supabase_url and supabase_key and update_course_in_supabase_with_gdrive:
                        update_course_in_supabase_with_gdrive(
                            course_id=cid,
                            gdrive_link=bundle_url,
                            file_id=file_id,
                            supabase_url=supabase_url,
                            supabase_key=supabase_key,
                            is_hyper=is_hyper,
                            residanat_sessions=sessions,
                            qcm_count=len(valid_qcms),
                            bundle_has_mindmap=True
                        )
                except Exception as e:
                    print(f"   ⚠️ Upload Google Drive notice : {e}")

            # Fallback vers Supabase Storage si Google Drive non disponible
            if not bundle_url and supabase_url and supabase_key:
                print("   ☁️ Fallback vers Supabase Storage...")
                bundle_url = upload_bundle_to_supabase(
                    pdf_path=final_local_pdf,
                    module_id=mid,
                    course_id=cid,
                    supabase_url=supabase_url,
                    supabase_key=supabase_key,
                    is_hyper=is_hyper,
                    residanat_sessions=sessions,
                    qcm_count=len(valid_qcms),
                    bundle_has_mindmap=True
                )

        # 10. Validation Humaine Obligatoire avant Publication / Diffusion
        broadcast_res = None
        if broadcast and bundle_url:
            print("   ⏸️ Diffusion publique différée : le livret est en attente de validation humaine par l'Admin (statut: pending_review).")

        return {
            "course_id": cid,
            "course_name": cname,
            "module_id": mid,
            "is_hypertombable": is_hyper,
            "residanat_sessions": sessions,
            "qcms_count": len(valid_qcms),
            "has_course_pdf": has_cours_officiel,
            "has_mindmap": has_mindmap,
            "validation_status": "pending_review",
            "local_path": str(final_local_pdf),
            "bundle_url": bundle_url,
            "broadcast": broadcast_res
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
    parser.add_argument("--broadcast", action="store_true", default=False, help="Diffuser in-app, Facebook (4 pages) et Telegram (uniquement après validation Admin)")
    parser.add_argument("--showcase", action="store_true", default=False, help="Mode Showcase : inclure le lien direct du livret dans le post public")
    parser.add_argument("--output-dir", type=str, default=str(WORKSPACE_ROOT / "livrets_residanat_2027"), help="Dossier de sortie local")
    args = parser.parse_args()

    out_dir = Path(args.output_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    supabase_url, supabase_key = get_supabase_credentials()

    print("=" * 70)
    print("🚀 MEDSINA — AGENT GÉNÉRATEUR DE LIVRETS DE RÉVISION RÉSIDANAT 2027")
    print(f"📁 Dossier de sortie : {out_dir.resolve()}")
    print(f"⚙️ Mode              : {'DRY RUN (Local uniquement)' if args.dry_run else 'OFFICIEL (Upload Supabase en attente de validation Admin)'}")
    print("=" * 70)

    # Récupérer les cours
    headers = {"apikey": supabase_key, "Authorization": f"Bearer {supabase_key}"}
    select_cols = "id,name,module_id,has_pdf,pdf_url,pdf_drive_id,pdf_storage_path,questions_count,mindmap_pdf_url,mindmap_drive_id,has_mindmap"
    if args.course_id:
        r = requests.get(f"{supabase_url}/rest/v1/courses?id=eq.{args.course_id}&select={select_cols}", headers=headers).json()
        target_courses = r if isinstance(r, list) and r else [{"id": args.course_id, "name": args.course_id, "module_id": "General"}]
    else:
        limit_query = 1000 if args.all else args.limit * 4
        r = requests.get(f"{supabase_url}/rest/v1/courses?select={select_cols}&limit={limit_query}", headers=headers).json()
        target_courses = r if isinstance(r, list) else []

    results = []
    processed_count = 0
    for c in target_courses:
        if not args.all and processed_count >= args.limit:
            break
        res = process_single_course(
            course=c,
            supabase_url=supabase_url,
            supabase_key=supabase_key,
            output_dir=out_dir,
            dry_run=args.dry_run,
            broadcast=args.broadcast,
            showcase=args.showcase,
            hypertombable_only=args.hypertombable_only
        )
        if res:
            results.append(res)
            processed_count += 1

    print("\n" + "=" * 70)
    print("📊 BILAN DE LA GÉNÉRATION DES LIVRETS :")
    print(f"• Cours éligibles générés : {len(results)}")
    print(f"• Livrets Hypertombables 🔥 : {sum(1 for r in results if r['is_hypertombable'])}")
    for r in results:
        status_tag = "🔥 HYPERTOMBABLE" if r["is_hypertombable"] else "📘 Standard"
        print(f"  - [{status_tag}] {r['course_name']} ({r['qcms_count']} QCMs) [Statut: {r['validation_status']}]")
        if r["bundle_url"]:
            print(f"    ☁️ URL : {r['bundle_url']}")
    print("=" * 70)


if __name__ == "__main__":
    main()
