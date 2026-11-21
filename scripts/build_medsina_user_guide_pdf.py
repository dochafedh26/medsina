import base64
import os
import subprocess
from pathlib import Path

# Paths
ROOT = Path(__file__).resolve().parent.parent
MEDSINA = ROOT
ASSETS = MEDSINA / "assets"

def get_base64_img(rel_path):
    p = ASSETS / rel_path
    if not p.exists():
        p = ROOT / rel_path
    if p.exists():
        ext = p.suffix.lower().replace('.', '')
        if ext == 'jpg': ext = 'jpeg'
        encoded = base64.b64encode(p.read_bytes()).decode('utf-8')
        return f"data:image/{ext};base64,{encoded}"
    return ""

logo_b64 = get_base64_img("medsina-logo.png")
icon_b64 = get_base64_img("medsina-icon.png")
dashboard_b64 = get_base64_img("screenshots/desktop/Screenshot 2026-10-20 175342_dashboard.png")
cat_b64 = get_base64_img("screenshots/desktop/Screenshot 2026-10-20 230338_CAT.png")
memento_b64 = get_base64_img("screenshots/desktop/Screenshot 2026-10-20 232448_memento.png")
qcm_b64 = get_base64_img("screenshots/desktop/revision_qcm_pc.png")
prescription_b64 = get_base64_img("screenshots/desktop/prescription_audit_pc.png")
clinical_copilot_b64 = get_base64_img("screenshots/desktop/clinical_copilot_pc.png")

html_content = f"""<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<title>Medsina 2027 - Guide Officiel de Découverte (v1.0.102)</title>
<style>
  @import url('https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=Inter:wght@400;500;600;700&display=swap');

  @page {{
    size: A4;
    margin: 10mm 12mm 11mm 12mm;
  }}

  * {{
    box-sizing: border-box;
    -webkit-print-color-adjust: exact !important;
    print-color-adjust: exact !important;
  }}

  body {{
    font-family: 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
    color: #1E293B;
    background-color: #FFFFFF;
    margin: 0;
    padding: 0;
    font-size: 10pt;
    line-height: 1.45;
  }}

  .page {{
    page-break-after: always;
    break-after: page;
    position: relative;
    min-height: 274mm;
    padding-bottom: 14mm;
  }}

  .page:last-child {{
    page-break-after: avoid;
    break-after: avoid;
  }}

  /* HEADER & FOOTER */
  .page-header {{
    display: flex;
    justify-content: space-between;
    align-items: center;
    border-bottom: 1.5px solid #0F766E;
    padding-bottom: 6px;
    margin-bottom: 14px;
  }}

  .page-header .brand {{
    font-weight: 800;
    font-size: 12pt;
    color: #0F766E;
    display: flex;
    align-items: center;
    gap: 8px;
  }}

  .page-header .doc-tag {{
    font-size: 8pt;
    font-weight: 700;
    color: #64748B;
    text-transform: uppercase;
    letter-spacing: 0.8px;
  }}

  .page-footer {{
    position: absolute;
    bottom: 0;
    left: 0;
    right: 0;
    display: flex;
    justify-content: space-between;
    align-items: center;
    border-top: 1px solid #E2E8F0;
    padding-top: 5px;
    font-size: 7.8pt;
    color: #94A3B8;
  }}

  /* COVER STYLING */
  .cover {{
    display: flex;
    flex-direction: column;
    justify-content: space-between;
    min-height: 274mm;
    padding: 18px 14px;
    background: linear-gradient(170deg, #F0FDFA 0%, #FFFFFF 42%, #F8FAFC 100%);
    border-radius: 16px;
    border: 1.5px solid #CCFBF1;
  }}

  .cover-top {{
    text-align: center;
    padding-top: 12px;
  }}

  .cover-logo {{
    max-height: 66px;
    margin-bottom: 14px;
  }}

  .cover-badge {{
    display: inline-block;
    background: #0F766E;
    color: #FFFFFF;
    font-size: 8.5pt;
    font-weight: 800;
    letter-spacing: 1.1px;
    text-transform: uppercase;
    padding: 6px 16px;
    border-radius: 20px;
    margin-bottom: 14px;
  }}

  .cover-title {{
    font-size: 26pt;
    font-weight: 800;
    color: #0F172A;
    line-height: 1.15;
    margin: 0 0 10px 0;
    justify-content: center;
  }}

  .cover-title span {{
    color: #0F766E;
  }}

  .cover-subtitle {{
    font-size: 11.5pt;
    font-weight: 500;
    color: #475569;
    max-width: 640px;
    margin: 0 auto 18px auto;
    line-height: 1.45;
  }}

  .cover-pills {{
    display: flex;
    flex-wrap: wrap;
    justify-content: center;
    gap: 8px;
    margin-bottom: 18px;
  }}

  .cover-pill {{
    background: #FFFFFF;
    border: 1px solid #CBD5E1;
    padding: 5px 12px;
    border-radius: 30px;
    font-size: 8.5pt;
    font-weight: 600;
    color: #334155;
    box-shadow: 0 2px 4px rgba(0,0,0,0.03);
  }}

  .cover-preview {{
    text-align: center;
    margin: 6px auto;
  }}

  .cover-preview img {{
    max-width: 88%;
    max-height: 350px;
    border-radius: 12px;
    box-shadow: 0 12px 28px rgba(15, 118, 110, 0.16);
    border: 1.5px solid #CBD5E1;
  }}

  .cover-meta {{
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 12px;
    background: #FFFFFF;
    padding: 14px 18px;
    border-radius: 12px;
    border: 1px solid #E2E8F0;
    margin-top: 14px;
  }}

  .cover-meta-item strong {{
    display: block;
    font-size: 9.5pt;
    color: #0F766E;
    margin-bottom: 2px;
  }}

  .cover-meta-item span {{
    font-size: 8pt;
    color: #64748B;
    line-height: 1.3;
    display: block;
  }}

  /* GENERAL TYPOGRAPHY */
  h1 {{
    font-size: 16pt;
    font-weight: 800;
    color: #0F172A;
    margin: 0 0 6px 0;
    display: flex;
    align-items: center;
    gap: 8px;
  }}

  h2 {{
    font-size: 11.5pt;
    font-weight: 700;
    color: #0F766E;
    margin: 13px 0 6px 0;
    border-bottom: 1px solid #E2E8F0;
    padding-bottom: 3px;
  }}

  h3 {{
    font-size: 10pt;
    font-weight: 700;
    color: #1E293B;
    margin: 8px 0 3px 0;
  }}

  p {{
    margin: 0 0 8px 0;
    color: #334155;
    font-size: 9.2pt;
    line-height: 1.48;
  }}

  code {{
    background: #F1F5F9;
    padding: 1px 4px;
    border-radius: 4px;
    font-size: 8.2pt;
    color: #0F766E;
  }}

  /* GRID & CARDS */
  .grid-2 {{
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 11px;
    margin-bottom: 10px;
  }}

  .grid-3 {{
    display: grid;
    grid-template-columns: 1fr 1fr 1fr;
    gap: 10px;
    margin-bottom: 10px;
  }}

  .card {{
    background: #F8FAFC;
    border: 1px solid #E2E8F0;
    border-radius: 9px;
    padding: 10px 12px;
  }}

  .card-teal {{
    background: #F0FDFA;
    border-color: #99F6E4;
  }}

  .card-blue {{
    background: #F0F9FF;
    border-color: #BAE6FD;
  }}

  .card-purple {{
    background: #FAF5FF;
    border-color: #E9D5FF;
  }}

  .card-amber {{
    background: #FFFBEB;
    border-color: #FDE68A;
  }}

  .card-rose {{
    background: #FFF1F2;
    border-color: #FECDD3;
  }}

  .card-title {{
    font-weight: 700;
    font-size: 9.6pt;
    color: #0F172A;
    margin-bottom: 4px;
    display: flex;
    align-items: center;
    gap: 5px;
  }}

  .card-body {{
    font-size: 8.4pt;
    color: #475569;
    line-height: 1.42;
  }}

  .badge {{
    display: inline-block;
    padding: 2px 7px;
    border-radius: 6px;
    font-size: 7pt;
    font-weight: 700;
    text-transform: uppercase;
  }}

  .badge-teal {{ background: #CCFBF1; color: #0F766E; }}
  .badge-blue {{ background: #E0F2FE; color: #0284C7; }}
  .badge-green {{ background: #DCFCE7; color: #16A34A; }}
  .badge-purple {{ background: #F3E8FF; color: #7E22CE; }}
  .badge-amber {{ background: #FEF3C7; color: #B45309; }}

  /* SCREENSHOT STYLING */
  .screenshot-box {{
    margin: 9px 0;
    text-align: center;
    background: #F1F5F9;
    padding: 6px;
    border-radius: 9px;
    border: 1px solid #E2E8F0;
  }}

  .screenshot-box img {{
    max-width: 100%;
    max-height: 185px;
    border-radius: 6px;
    border: 1px solid #CBD5E1;
    box-shadow: 0 4px 10px rgba(0,0,0,0.06);
  }}

  .screenshot-caption {{
    font-size: 7.8pt;
    color: #64748B;
    margin-top: 3px;
    font-weight: 500;
  }}

  /* PRICING TABLE */
  table.pricing-table {{
    width: 100%;
    border-collapse: collapse;
    margin: 8px 0 12px 0;
    font-size: 8.4pt;
  }}

  table.pricing-table th {{
    background: #0F766E;
    color: #FFFFFF;
    text-align: left;
    padding: 7px 8px;
    font-weight: 700;
  }}

  table.pricing-table td {{
    padding: 6px 8px;
    border-bottom: 1px solid #E2E8F0;
  }}

  table.pricing-table tr:nth-child(even) {{
    background: #F8FAFC;
  }}

  .highlight-row {{
    background: #F0FDFA !important;
    font-weight: 600;
  }}

  /* BULLETS */
  ul.feat-list {{
    margin: 4px 0 8px 0;
    padding-left: 16px;
    font-size: 8.8pt;
  }}

  ul.feat-list li {{
    margin-bottom: 3px;
    color: #334155;
  }}

  .callout {{
    background: #FFFBEB;
    border-left: 4px solid #F59E0B;
    padding: 8px 12px;
    border-radius: 6px;
    font-size: 8.6pt;
    margin: 8px 0;
    color: #92400E;
  }}

  .callout strong {{
    color: #78350F;
  }}

  .callout-teal {{
    background: #F0FDFA;
    border-left: 4px solid #0F766E;
    padding: 8px 12px;
    border-radius: 6px;
    font-size: 8.6pt;
    margin: 8px 0;
    color: #115E59;
  }}
</style>
</head>
<body>

<!-- ========================================================================= -->
<!-- PAGE 1 : PAGE DE GARDE                                                    -->
<!-- ========================================================================= -->
<div class="page cover">
  <div class="cover-top">
    {'<img src="' + logo_b64 + '" class="cover-logo" alt="Medsina Logo">' if logo_b64 else '<h1 style="color:#0F766E;">Medsina</h1>'}
    <div class="cover-badge">Documentation Officielle Utilisateur • Édition 2026–2027</div>
    <h1 class="cover-title">Plateforme Médicale Globale &amp; <span>Résidanat 2027</span></h1>
    <p class="cover-subtitle">Le guide officiel complet pour maîtriser les 47 modules de révision, la banque de +19 000 QCMs, l'Assistant ECG 12 dérivations (PDF A4), les outils de garde (GDS, PSE, Ordonnancier DZ), le Whiteboard Mindmap et l'Espace Prof.</p>

    <div class="cover-pills">
      <div class="cover-pill">🌐 Web Cloud</div>
      <div class="cover-pill">📱 Android APK</div>
      <div class="cover-pill">🖥️ Windows 64-bit</div>
      <div class="cover-pill">⚡ 100 % Hors-Ligne</div>
      <div class="cover-pill" style="border-color:#0F766E; color:#0F766E;">🫀 ECG 12D &amp; PDF A4</div>
      <div class="cover-pill" style="border-color:#7E22CE; color:#7E22CE;">🎓 Espace Prof 65/35</div>
      <div class="cover-pill" style="border-color:#F59E0B; color:#B45309;">🔍 Omnisearch (Ctrl+K)</div>
    </div>
  </div>

  <div class="cover-preview">
    {'<img src="' + dashboard_b64 + '" alt="Tableau de bord Medsina">' if dashboard_b64 else ''}
  </div>

  <div class="cover-meta">
    <div class="cover-meta-item">
      <strong>Public Visé</strong>
      <span>Externes (1re–6e), Internes, Résidents, Praticiens &amp; Enseignants HU</span>
    </div>
    <div class="cover-meta-item">
      <strong>Couverture Médicale</strong>
      <span>47 Modules • +19 000 QCMs • Vidal DZ • Ordonnancier 2×/j</span>
    </div>
    <div class="cover-meta-item">
      <strong>Version Stable</strong>
      <span>Medsina v1.0.102 (Build 127 • Stable 2027)</span>
    </div>
    <div class="cover-meta-item">
      <strong>Portail Officiel</strong>
      <span>https://medsina.medevsync.com</span>
    </div>
  </div>
</div>

<!-- ========================================================================= -->
<!-- PAGE 2 : PRÉSENTATION GÉNÉRALE, ACCÈS & OMNISEARCH                        -->
<!-- ========================================================================= -->
<div class="page">
  <div class="page-header">
    <div class="brand">{'<img src="' + icon_b64 + '" height="18">' if icon_b64 else ''} Medsina • Guide Utilisateur v1.0.102</div>
    <div class="doc-tag">1. Présentation, Accès &amp; Omnisearch</div>
  </div>

  <h1>🌟 Qu'est-ce que Medsina ?</h1>
  <p><strong>Medsina</strong> (conçue par <strong>MedevSync</strong>) est la super-application médicale tout-en-un pensée sur mesure pour le cursus algérien (Faculté de Médecine de Blida et universités nationales). Elle rassemble sur une interface <strong>Bento 2027</strong> la préparation au Résidanat &amp; Externat, la suite clinique avancée de garde, l'Ordonnancier &amp; Vidal Algérie, le studio Whiteboard Mindmap et l'Espace Professeur HU.</p>

  <h2>🚀 Les 3 Modes d'Accès Multi-Plateformes &amp; Connexion Rapide</h2>
  <div class="grid-3">
    <div class="card card-teal">
      <div class="card-title">🌐 1. Version Web (SaaS)</div>
      <div class="card-body">
        Accessible depuis tout navigateur (Chrome, Safari, Firefox) sans installation.<br/>
        <strong>Lien :</strong> <code>medsina.medevsync.com</code><br/>
        Idéal sur iPad, tablette ou poste hospitalier partagé.
      </div>
    </div>
    <div class="card card-blue">
      <div class="card-title">📱 2. Application Android (APK)</div>
      <div class="card-body">
        Application native rapide pour smartphones &amp; tablettes avec mode <strong>100 % hors-ligne</strong>.<br/>
        <code>medsina.medevsync.com/download/medsina.apk</code><br/>
        Installation côte à côte possible entre <strong>Stable</strong> et <strong>Beta</strong>.
      </div>
    </div>
    <div class="card card-purple">
      <div class="card-title">💻 3. Windows Desktop (64-bit)</div>
      <div class="card-body">
        Installeur officiel Windows x64 avec raccourcis clavier et confort grand écran.<br/>
        <code>medsina.medevsync.com/download/medsina-setup.exe</code><br/>
        Mises à jour automatiques OTA par canal.
      </div>
    </div>
  </div>

  <h2>🔍 Medsina Omnisearch : Recherche Transversale Instantanée (Ctrl+K)</h2>
  <p>Interrogez simultanément <strong>toutes les bases de données</strong> de l'application en moins de 100 millisecondes :</p>
  <div class="grid-3">
    <div class="card card-teal">
      <div class="card-title">📚 Cours PDF &amp; Livrets</div>
      <div class="card-body">
        Recherche plein texte dans les 47 modules. Un clic ouvre le PDF <strong>directement sur la bonne page avec le terme surligné</strong>.
      </div>
    </div>
    <div class="card card-blue">
      <div class="card-title">🚨 CAT, Mémentos &amp; Outils</div>
      <div class="card-body">
        Accès réflexe aux conduites à tenir d'urgence, mémentos de garde, calculateurs PSE, ECG, GDS, normes labo et logbook.
      </div>
    </div>
    <div class="card card-purple">
      <div class="card-title">🎯 QCMs, Vidal, Ordonnances &amp; Mnémos</div>
      <div class="card-body">
        Retrouvez instantanément annales QCM, médicaments DZ, ordonnances types CNAS, mnémotechniques et témoignages de majors.
      </div>
    </div>
  </div>

  <h2>⚡ Architecture Hors-Ligne, Profil Bento &amp; Connexion Google</h2>
  <div class="grid-2">
    <div class="card">
      <div class="card-title">⚡ Mode 100 % Hors-Ligne &amp; OTA</div>
      <div class="card-body">
        <ul class="feat-list" style="margin:2px 0 0 0;">
          <li><strong>Données embarquées :</strong> QCMs, CATs, mémentos, Vidal DZ et ordonnances types restent disponibles aux UMC sans réseau.</li>
          <li><strong>Synchronisation silencieuse :</strong> scores, streaks, flashcards et whiteboards se synchronisent dès le retour du réseau.</li>
          <li><strong>Mises à jour OTA :</strong> détection et installation fluides des nouvelles versions depuis l'application.</li>
        </ul>
      </div>
    </div>
    <div class="card card-teal">
      <div class="card-title">👤 Profil Médical, Google OAuth &amp; Streak 🔥</div>
      <div class="card-body">
        <ul class="feat-list" style="margin:2px 0 0 0;">
          <li><strong>Connexion Google en 1 clic</strong> (OAuth Supabase) ou email.</li>
          <li><strong>Identité complète :</strong> rôle, faculté, wilaya (1–58), photo Cloud ou 8 avatars médicaux vectoriels.</li>
          <li><strong>« Accomplir le Jour » :</strong> +50 XP, streak hebdomadaire (L–D), objectifs quotidiens et parrainage (+7j VIP offerts).</li>
        </ul>
      </div>
    </div>
  </div>

  <div class="callout">
    <strong>🎁 Pass Découverte Offert (14 Jours Gratuits) :</strong> Dès votre inscription, profitez de 14 jours d'accès complet sans engagement pour tester tous les modules cliniques et pédagogiques.
  </div>

  <div class="page-footer">
    <span>Medsina 2027 • Guide Officiel Utilisateur (v1.0.102)</span>
    <span>Page 2 / 8</span>
  </div>
</div>

<!-- ========================================================================= -->
<!-- PAGE 3 : FORMATION ACADÉMIQUE, QCM & RÉSIDANAT                            -->
<!-- ========================================================================= -->
<div class="page">
  <div class="page-header">
    <div class="brand">{'<img src="' + icon_b64 + '" height="18">' if icon_b64 else ''} Medsina • Guide Utilisateur v1.0.102</div>
    <div class="doc-tag">2. Résidanat, Externat &amp; QCM</div>
  </div>

  <h1>📚 Catalogue des 47 Modules &amp; Moteur QCM « Ultra-Résidanat »</h1>
  <p>Le cœur académique de Medsina couvre l'intégralité du programme officiel de Résidanat et le cursus universitaire d'Externat (1re à 6e année) avec une approche orientée rendement d'examen.</p>

  <div class="grid-2">
    <div>
      <h3>📖 Fiches Synthèses &amp; 47 Livrets All-in-One</h3>
      <ul class="feat-list">
        <li><strong>47 Livrets All-in-One :</strong> synthèses condensées High-Yield téléchargeables hors-ligne avec QCMs intégrés.</li>
        <li><strong>Fiches consensuelles :</strong> physiopathologie, critères diagnostiques, scores, pièges classiques de concours.</li>
        <li><strong>Témoignages Majors (Cloud) :</strong> retours d'expérience authentiques (Dr Bentegri, Dr Djellata…) mis à jour sans rebuild.</li>
      </ul>
    </div>
    <div>
      <h3>🎯 +19 000 QCMs &amp; Examens Blancs</h3>
      <ul class="feat-list">
        <li><strong>Mode Révision &amp; Mode Examen :</strong> timer 15–120 min, barèmes <em>Tout ou Rien</em> ou <em>Notation Partielle</em>.</li>
        <li><strong>Filtres intelligents :</strong> jamais consultées, mes erreurs, favoris, notes personnelles, haute tombabilité.</li>
        <li><strong>Alertes Anti-Pièges :</strong> détection automatique des questions négatives (<em>SAUF / FAUSSE</em>) et statistiques communautaires.</li>
      </ul>
    </div>
  </div>

  <div class="screenshot-box">
    {'<img src="' + qcm_b64 + '" alt="Interface de Révision QCM">' if qcm_b64 else ''}
    <div class="screenshot-caption">Moteur QCM Medsina avec justifications pédagogiques, indicateurs de tombabilité, timer et grille interactive</div>
  </div>

  <h2>🎓 Parcours Universitaire Externat (1re à 6e Année) &amp; Méthodologie</h2>
  <div class="grid-3">
    <div class="card card-blue">
      <div class="card-title">🏫 Pass Étudiant &amp; EMD</div>
      <div class="card-body">
        Filtrage intelligent par année d'externat (Sémiologie, Pharma, Microbio, modules cliniques) et <strong>simulations EMD</strong> dédiées sans surcharge concours.
      </div>
    </div>
    <div class="card card-purple">
      <div class="card-title">🧠 Flashcards FSRS v4.5</div>
      <div class="card-body">
        Algorithme scientifique de répétition espacée calculant stabilité et rétention. <strong>Conversion de tout QCM en flashcard en 1 clic</strong> + widget dédié sur l'accueil.
      </div>
    </div>
    <div class="card card-teal">
      <div class="card-title">📅 Study Planner 3 Couches</div>
      <div class="card-body">
        Suivi <strong>Couche 1 (Lecture) • Couche 2 (Fiches) • Couche 3 (Annales)</strong>, compte à rebours J-X et priorités quotidiennes suggérées par IA.
      </div>
    </div>
  </div>

  <div class="page-footer">
    <span>Medsina 2027 • Guide Officiel Utilisateur (v1.0.102)</span>
    <span>Page 3 / 8</span>
  </div>
</div>

<!-- ========================================================================= -->
<!-- PAGE 4 : NOUVEAUTÉS PÉDAGOGIQUES, WHITEBOARD & COMPÉTITION                -->
<!-- ========================================================================= -->
<div class="page">
  <div class="page-header">
    <div class="brand">{'<img src="' + icon_b64 + '" height="18">' if icon_b64 else ''} Medsina • Guide Utilisateur v1.0.102</div>
    <div class="doc-tag">3. Whiteboard, Duel 1v1 &amp; Pédagogie</div>
  </div>

  <h1>🚀 Suite Pédagogique Avancée &amp; Outils de Performance</h1>
  <p>Les dernières versions (v1.0.93 → v1.0.102) enrichissent radicalement votre façon de mémoriser, visualiser vos cours et mesurer votre niveau face aux autres candidats.</p>

  <div class="grid-2">
    <div class="card card-purple">
      <div class="card-title">🎨 Whiteboard &amp; Studio Mindmap Interactif <span class="badge badge-purple">NOUVEAU</span></div>
      <div class="card-body">
        Accessible depuis la barre d'icônes (Accueil &amp; Révision) :
        <ul class="feat-list" style="margin:4px 0 0 0;">
          <li><strong>Modèles médicaux intégrés :</strong> Carte Mentale, Physiopathologie, Arbre Décisionnel.</li>
          <li><strong>Exportation directe en PDF</strong> pour imprimer ou partager vos schémas.</li>
          <li><strong>Synchronisation Cloud Supabase</strong> automatique entre PC, Android et Web.</li>
        </ul>
      </div>
    </div>
    <div class="card card-teal">
      <div class="card-title">🗺️ Mind Maps Décisionnelles Vectorielles <span class="badge badge-teal">CLOUD</span></div>
      <div class="card-body">
        Arborescences cliniques HD structurées en 6 branches (Physiopathologie, Diagnostic, Reperfusion/PEC, Urgence, Ordonnance, Pièges).
        <ul class="feat-list" style="margin:4px 0 0 0;">
          <li><strong>Vue hybride :</strong> arbre tactile interactif + visionneuse vectorielle plein écran hors-ligne.</li>
          <li><strong>Demande en 1 clic :</strong> demandez la génération d'une Mind Map sur tout cours qui n'en a pas encore.</li>
        </ul>
      </div>
    </div>
  </div>

  <div class="grid-2">
    <div class="card card-amber">
      <div class="card-title">⚔️ Mode Duel QCM 1v1 &amp; Défis Rapides <span class="badge badge-amber">NOUVEAU</span></div>
      <div class="card-body">
        Défiez un confrère en temps réel sur des manches chronométrées par spécialité ou en mode mixte. Classement des duels, précision et rapidité pour stimuler l'émulation de groupe.
      </div>
    </div>
    <div class="card card-blue">
      <div class="card-title">💡 Banque de Mnémotechniques &amp; Réflexes QCM <span class="badge badge-blue">NOUVEAU</span></div>
      <div class="card-body">
        Répertoire structuré de moyens mnémotechniques médicaux et d'associations réflexes incontournables (*mot-clé d'énoncé ➔ diagnostic / traitement immédiat*) indexé dans Omnisearch.
      </div>
    </div>
  </div>

  <div class="grid-2">
    <div class="card card-teal">
      <div class="card-title">🏆 Simulateur de Classement &amp; Choix de Spécialité <span class="badge badge-teal">NOUVEAU</span></div>
      <div class="card-body">
        Saisissez votre moyenne estimée sur 20 et votre faculté (<em>Blida, Alger, Oran, Constantine, Annaba / Sétif / Tlemcen</em>) pour visualiser immédiatement les spécialités médicales, chirurgicales et biologiques <strong>Accessibles</strong>, <strong>Compétitives</strong> ou <strong>À consolider</strong> avec rangs de clôture indicatifs.
      </div>
    </div>
    <div class="card card-rose">
      <div class="card-title">🎯 Mode Focus (Spécialité / Rotation) &amp; Pomodoro <span class="badge badge-amber">NOUVEAU</span></div>
      <div class="card-body">
        Activez le <strong>Mode Focus</strong> sur votre module ou stage actuel : toute l'application (Cours, Externat, CATs, Tableau de bord) se filtre automatiquement sur cette spécialité. Couplez-le au minuteur Pomodoro intégré.
      </div>
    </div>
  </div>

  <h2>🌐 Écosystème Collaboratif &amp; Révision Multimodale</h2>
  <div class="grid-3">
    <div class="card">
      <div class="card-title">🏅 Examens Nationaux &amp; Groupes</div>
      <div class="card-body">Participez aux examens blancs nationaux avec classement en direct et créez des groupes de révision privés entre amis.</div>
    </div>
    <div class="card">
      <div class="card-title">🎧 Révision Audio &amp; Carnet d'Erreurs</div>
      <div class="card-body">Écoutez vos résumés en déplacement, consultez les <em>Samedis Pédagogiques</em>, les <em>Perles du Jour</em> et votre carnet d'erreurs dédié.</div>
    </div>
    <div class="card">
      <div class="card-title">🤖 Coach d'Étude IA</div>
      <div class="card-body">Posez vos questions de cours, obtenez des explications ciblées sur un QCM litigieux et générez des plans de révision adaptés.</div>
    </div>
  </div>

  <div class="page-footer">
    <span>Medsina 2027 • Guide Officiel Utilisateur (v1.0.102)</span>
    <span>Page 4 / 8</span>
  </div>
</div>

<!-- ========================================================================= -->
<!-- PAGE 5 : PRATIQUE CLINIQUE, URGENCES, LOGBOOK & SYNAPSE                   -->
<!-- ========================================================================= -->
<div class="page">
  <div class="page-header">
    <div class="brand">{'<img src="' + icon_b64 + '" height="18">' if icon_b64 else ''} Medsina • Guide Utilisateur v1.0.102</div>
    <div class="doc-tag">4. Clinique, Urgences &amp; Garde</div>
  </div>

  <h1>🚨 Outils Pratiques pour l'Interne, le Résident &amp; le Praticien</h1>
  <p>Aux urgences (UMC) ou en service d'hospitalisation, Medsina met dans votre poche des protocoles validés, des check-lists de gestes techniques et des simulateurs de raisonnement clinique.</p>

  <div class="grid-2">
    <div class="card card-teal">
      <div class="card-title">🚨 Conduites à Tenir d'Urgence (CAT)</div>
      <div class="card-body">
        Protocoles pas-à-pas alignés SFMU / SRLF / AHA :
        <ul style="margin:3px 0 0 0; padding-left:15px;">
          <li>SCA ST+ / Non-ST+ et protocoles de thrombolyse</li>
          <li>AVC ischémique / hémorragique &amp; fenêtre thérapeutique</li>
          <li>Hémorragie Digestive Haute, chocs (septique, anaphylactique, cardiogénique)</li>
          <li>Asthme aigu grave, OAP, détresses respiratoires aiguës</li>
        </ul>
      </div>
    </div>
    <div class="card card-purple">
      <div class="card-title">📋 Mémentos de Garde Réflexes</div>
      <div class="card-body">
        Fiches synthétiques enrichies en continu pour le lit du malade :
        <ul style="margin:3px 0 0 0; padding-left:15px;">
          <li>Syndrome méningé aigu &amp; ponction lombaire</li>
          <li>Comas, échelle de Glasgow et états de mal épileptiques</li>
          <li>Acido-cétose diabétique &amp; protocole insuline IVSE</li>
          <li>Dysnatrémies, dyskaliémies et brûlures (Parkland)</li>
        </ul>
      </div>
    </div>
  </div>

  <div class="screenshot-box">
    {'<img src="' + cat_b64 + '" alt="Interface CAT Urgence">' if cat_b64 else ''}
    <div class="screenshot-caption">Module Conduite à Tenir (CAT) avec arbre décisionnel structuré et posologies thérapeutiques immédiates</div>
  </div>

  <div class="grid-3">
    <div class="card card-blue">
      <div class="card-title">✅ Logbook &amp; Gestes Pratiques <span class="badge badge-blue">NOUVEAU</span></div>
      <div class="card-body">
        Check-lists étape par étape (matériel, contre-indications, technique, complications) et suivi de vos gestes réalisés en garde : ponction lombaire, gazométrie, VVC, drainage pleural, intubation.
      </div>
    </div>
    <div class="card card-amber">
      <div class="card-title">🧠 Medsina Synapse &amp; Atlas</div>
      <div class="card-body">
        <strong>Synapse :</strong> simulateur de cas cliniques progressifs pour entraîner votre démarche diagnostique.<br/>
        <strong>Atlas Clinique :</strong> iconographie commentée de sémiologie, imagerie et dermatologie.
      </div>
    </div>
    <div class="card card-teal">
      <div class="card-title">🧪 Normes Labo &amp; Calculateurs</div>
      <div class="card-body">
        +80 constantes biologiques (NFS, iono, hémostase, bilan hépatique, LCR) avec seuils critiques et calculateurs intégrés (Glasgow, Wells, Cockcroft, CKD-EPI, IMC, SC).
      </div>
    </div>
  </div>

  <div class="page-footer">
    <span>Medsina 2027 • Guide Officiel Utilisateur (v1.0.102)</span>
    <span>Page 5 / 8</span>
  </div>
</div>

<!-- ========================================================================= -->
<!-- PAGE 6 : OUTILS CLINIQUES AVANCÉS (ECG 12D PDF A4, GDS & PSE)             -->
<!-- ========================================================================= -->
<div class="page">
  <div class="page-header">
    <div class="brand">{'<img src="' + icon_b64 + '" height="18">' if icon_b64 else ''} Medsina • Guide Utilisateur v1.0.102</div>
    <div class="doc-tag">5. ECG 12D (PDF A4), GDS &amp; PSE</div>
  </div>

  <h1>🫀 Suite Clinique Avancée : ECG 12 Dérivations, GDS &amp; PSE</h1>
  <p>Trois moteurs d'aide à la décision de niveau hospitalier, utilisables 100 % hors-ligne aux urgences, en réanimation et en cardiologie.</p>

  <div class="card card-rose" style="margin-bottom:10px;">
    <div class="card-title">🫀 Assistant ECG 12 Dérivations, QTc &amp; Compte Rendu Imprimable (PDF A4) <span class="badge badge-amber">v1.0.100–101</span></div>
    <div class="card-body">
      <div class="grid-2" style="margin-bottom:4px; margin-top:4px;">
        <div>
          <strong>Moteur d'Interprétation Structuré :</strong>
          <ul class="feat-list" style="margin:3px 0 0 0;">
            <li><strong>Lecture guidée 12 dérivations :</strong> contrôles techniques (aVR, D1, progression de R, calibrage), fréquence, rythme, axe, PR, QRS, ST par territoire, onde T et QTc.</li>
            <li><strong>Détection automatique :</strong> FA, Flutter (300/min), TV, BAV (1er, Wenckebach, Mobitz 2, 3e degré), BBDG/BBDD, HVG et ondes Q pathologiques.</li>
            <li><strong>SCA ST+ par territoire :</strong> critères consensuels (≥ 2 mm en V2–V3, ≥ 1 mm ailleurs, ≥ 2 dérivations contiguës) + alertes d'urgence hiérarchisées.</li>
          </ul>
        </div>
        <div>
          <strong>Compte Rendu ECG PDF A4 &amp; Référentiel :</strong>
          <ul class="feat-list" style="margin:3px 0 0 0;">
            <li><strong>Export PDF A4 rédigé :</strong> 6 rubriques médicales complètes (qualité technique, rythme, conduction, axe, repolarisation, QT), conclusion, conduite à tenir et note de confiance.</li>
            <li><strong>Fiche Patient :</strong> saisie nom, âge, indication, renseignements cliniques et visa praticien prêts à imprimer.</li>
            <li><strong>Référentiel de poche :</strong> normes, territoires coronaires, chronologie de l'infarctus, règles <em>WiLLiaM / MaRRoW</em>.</li>
          </ul>
        </div>
      </div>
    </div>
  </div>

  <div class="grid-2">
    <div class="card card-blue">
      <div class="card-title">🫁 Interpréteur Gaz du Sang (GDS / ABG) <span class="badge badge-blue">NOUVEAU</span></div>
      <div class="card-body">
        Saisissez pH, PaCO₂, HCO₃⁻, PaO₂/FiO₂ et ionogramme pour obtenir :
        <ul class="feat-list" style="margin:4px 0 0 0;">
          <li>Diagnostic du trouble primaire (acidose/alcalose respiratoire ou métabolique).</li>
          <li>Calcul automatique des <strong>compensations attendues</strong> et détection des troubles mixtes.</li>
          <li>Calcul du <strong>trou anionique</strong> et orientation étiologique immédiate.</li>
        </ul>
      </div>
    </div>
    <div class="card card-teal">
      <div class="card-title">💉 Calculateur PSE &amp; Dilutions d'Urgence <span class="badge badge-teal">NOUVEAU</span></div>
      <div class="card-body">
        Calcul ultra-fiable des débits en seringue électrique (mL/h) sans erreur de conversion :
        <ul class="feat-list" style="margin:4px 0 0 0;">
          <li><strong>Toutes les unités :</strong> <code>γ/kg/min</code>, <code>γ/kg/h</code>, <code>mg/h</code>, <code>UI/kg/h</code>, <code>UI/h</code>.</li>
          <li><strong>Dilutions prêtes (50 mL / 20 mL) :</strong> Noradrénaline, Adrénaline, Dobutamine, Dopamine, Nicardipine (Loxen), Amiodarone, Midazolam, Furosémide, Insuline IVSE, Héparine HNF.</li>
          <li>Indication du solvant adapté (NaCl 0,9 % ou SG 5 %) et instruction de préparation.</li>
        </ul>
      </div>
    </div>
  </div>

  {'<div class="screenshot-box"><img src="' + clinical_copilot_b64 + '" alt="Suite Clinique Medsina"><div class="screenshot-caption">Suite d\'aide à la décision clinique Medsina — accessible en 1 clic depuis l\'onglet Clinique et le menu rapide</div></div>' if clinical_copilot_b64 else ''}

  <div class="callout-teal">
    <strong>🔒 Fiabilité &amp; Sécurité :</strong> Chaque calculateur clinique affiche ses formules, ses seuils d'alerte et son indice de confiance afin de soutenir le jugement médical sans jamais s'y substituer.
  </div>

  <div class="page-footer">
    <span>Medsina 2027 • Guide Officiel Utilisateur (v1.0.102)</span>
    <span>Page 6 / 8</span>
  </div>
</div>

<!-- ========================================================================= -->
<!-- PAGE 7 : SÉCURITÉ THÉRAPEUTIQUE, VIDAL DZ & ORDONNANCIER TYPE             -->
<!-- ========================================================================= -->
<div class="page">
  <div class="page-header">
    <div class="brand">{'<img src="' + icon_b64 + '" height="18">' if icon_b64 else ''} Medsina • Guide Utilisateur v1.0.102</div>
    <div class="doc-tag">6. Vidal DZ, Ordonnancier &amp; Certificats</div>
  </div>

  <h1>💊 Vidal Algérie, Ordonnancier Type &amp; Certificats PDF A4</h1>
  <p>Sécurisez chaque prescription grâce à la nomenclature algérienne officielle, à l'audit d'interactions médicamenteuses et à la bibliothèque d'ordonnances types enrichie automatiquement deux fois par jour.</p>

  <div class="screenshot-box">
    {'<img src="' + prescription_b64 + '" alt="Audit Ordonnance">' if prescription_b64 else ''}
    <div class="screenshot-caption">Analyseur d'ordonnance : détection croisée des interactions médicamenteuses et alertes de contre-indications terrain</div>
  </div>

  <h2>🛡️ Les 3 Piliers de la Sécurité Thérapeutique</h2>
  <div class="grid-3">
    <div class="card card-blue">
      <div class="card-title">🇩🇿 1. Nomenclature Algérie</div>
      <div class="card-body">
        Base exhaustive des médicaments enregistrés en Algérie : DCI, noms commerciaux, formes, dosages, statut Chifa et laboratoires locaux/importés.
      </div>
    </div>
    <div class="card card-teal">
      <div class="card-title">⚠️ 2. Interactions Vidal</div>
      <div class="card-body">
        Analyse croisée classée par gravité : <strong>Contre-indication absolue</strong>, <strong>Association déconseillée</strong> et <strong>Précautions d'emploi</strong>.
      </div>
    </div>
    <div class="card card-purple">
      <div class="card-title">🤰 3. Contre-indications Terrain</div>
      <div class="card-body">
        Vérification instantanée selon le profil patient : Grossesse (T1–T3), Allaitement, Insuffisance rénale (DFG), Insuffisance hépatique, Ulcère GD.
      </div>
    </div>
  </div>

  <h2>📋 Ordonnancier Type DCI/CNAS (Sync 2×/jour) &amp; Certificats Médico-Légaux</h2>
  <div class="grid-2">
    <div class="card card-teal">
      <div class="card-title">📝 Ordonnances Types DCI/CNAS <span class="badge badge-teal">v1.0.102</span></div>
      <div class="card-body">
        <ul class="feat-list" style="margin:3px 0 0 0;">
          <li><strong>Enrichissement autonome 2×/jour :</strong> nouvelles pathologies synchronisées en direct depuis Supabase avec actualisation en 1 clic et cache hors-ligne.</li>
          <li><strong>Adulte &amp; Pédiatrie :</strong> posologies adaptées au poids (<code>mg/kg/j</code>) avec doses maximales de sécurité, durées, conseils patient et références scientifiques.</li>
        </ul>
      </div>
    </div>
    <div class="card card-amber">
      <div class="card-title">📄 Certificats Médico-Légaux PDF A4 <span class="badge badge-amber">NOUVEAU</span></div>
      <div class="card-body">
        <ul class="feat-list" style="margin:3px 0 0 0;">
          <li><strong>Modèles officiels Algérie :</strong> Certificat de Coups et Blessures Volontaires (<strong>CBV / ITT</strong>), Arrêt de travail, Certificat d'aptitude et descriptif médical.</li>
          <li><strong>Export PDF A4 propre :</strong> mise en page conforme, sans ratures, prête à signer et tamponner.</li>
        </ul>
      </div>
    </div>
  </div>

  <div class="page-footer">
    <span>Medsina 2027 • Guide Officiel Utilisateur (v1.0.102)</span>
    <span>Page 7 / 8</span>
  </div>
</div>

<!-- ========================================================================= -->
<!-- PAGE 8 : ESPACE PROF 65/35, FORMULES D'ABONNEMENT & ASSISTANCE            -->
<!-- ========================================================================= -->
<div class="page">
  <div class="page-header">
    <div class="brand">{'<img src="' + icon_b64 + '" height="18">' if icon_b64 else ''} Medsina • Guide Utilisateur v1.0.102</div>
    <div class="doc-tag">7. Espace Prof, Tarifs &amp; Support</div>
  </div>

  <h1>🎓 Espace Prof / Enseignant HU &amp; Partage de Revenus 65 / 35</h1>
  <div class="grid-2">
    <div class="card card-purple">
      <div class="card-title">🏅 Publication Réservée aux Grades Vérifiés <span class="badge badge-purple">v1.0.98</span></div>
      <div class="card-body">
        Les enseignants vérifiés par l'administration (<em>Professeur, MCA, Maître-Assistant, Assistant HU, Résident</em>) reçoivent un <strong>badge de grade vérifié</strong> et publient leurs cours, fiches, mindmaps, flashcards et examens EMD / QROC. Tous les étudiants conservent l'accès en lecture.
      </div>
    </div>
    <div class="card card-teal">
      <div class="card-title">💰 Monétisation 65 % Auteur / 35 % Plateforme</div>
      <div class="card-body">
        Onglet <strong>« Mes gains »</strong> dédié : suivi du solde disponible, comptabilisation équitable des lecteurs uniques et passages d'examens, clôtures mensuelles et demandes de retrait par <strong>CCP BaridiMob</strong> ou virement bancaire.
      </div>
    </div>
  </div>

  <h2>💎 Formules d'Abonnement &amp; Tarifs Algérie (DZD)</h2>
  <table class="pricing-table">
    <thead>
      <tr>
        <th>Formule</th>
        <th>Public Idéal</th>
        <th>Contenu &amp; Accès Inclus</th>
        <th>Tarif Annuel</th>
        <th>Tarif Mensuel</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td><strong>Pass Découverte</strong></td>
        <td>Nouveaux inscrits</td>
        <td>14 jours d'accès complet à tous les modules sans carte bancaire</td>
        <td><span class="badge badge-teal">GRATUIT (14j)</span></td>
        <td>0 DZD</td>
      </tr>
      <tr>
        <td><strong>Pass Étudiant</strong></td>
        <td>Externes (1re–6e Année)</td>
        <td>Modules de l'année choisie, simulations EMD, QCMs &amp; fiches de rotation</td>
        <td><strong>3 500 DZD</strong> / an</td>
        <td>500 DZD / mois</td>
      </tr>
      <tr>
        <td><strong>Pass Clinique Pro</strong></td>
        <td>Internes &amp; Praticiens UMC</td>
        <td>CAT, Mémentos, ECG 12D PDF, GDS, PSE, Ordonnancier DZ, Vidal &amp; Logbook</td>
        <td><strong>5 000 DZD</strong> / an</td>
        <td>800 DZD / mois</td>
      </tr>
      <tr class="highlight-row">
        <td><strong>Pass Résident Élite</strong> ⭐</td>
        <td>Candidats Résidanat</td>
        <td>47 Modules, +19 000 QCMs, Livrets, Mindmaps, FSRS, Duel 1v1 &amp; Simulateur</td>
        <td><strong>5 600 DZD</strong> / an</td>
        <td>900 DZD / mois</td>
      </tr>
      <tr style="background:#FDF4FF;">
        <td><strong>Medsina All-Access VIP</strong> 👑</td>
        <td>Médecins &amp; Candidats exigeants</td>
        <td>Accès total illimité : Résidanat + Suite Clinique Complète + Whiteboard + Coach IA</td>
        <td><strong>6 500 DZD</strong> / an</td>
        <td>1 000 DZD / mois</td>
      </tr>
    </tbody>
  </table>

  <h2>💳 Modalités de Règlement &amp; Assistance Officielle</h2>
  <div class="grid-3">
    <div class="card">
      <div class="card-title">📱 BaridiMob</div>
      <div class="card-body">
        Virement instantané + capture du reçu dans l'application :<br/>
        <strong>RIP :</strong> <code>007999990009171614 93</code>
      </div>
    </div>
    <div class="card">
      <div class="card-title">📮 Virement CCP</div>
      <div class="card-body">
        <strong>Compte :</strong> <code>9171614 Clé 19</code><br/>
        <strong>Titulaire :</strong> Chikh Touhami Hafed
      </div>
    </div>
    <div class="card">
      <div class="card-title">🔑 Clé de Licence</div>
      <div class="card-body">
        Activation instantanée d'une clé Medsina (ex: <code>MEDSINA-2027-VIP</code>) directement dans votre profil.
      </div>
    </div>
  </div>

  <div class="card card-teal" style="margin-top:6px;">
    <div class="grid-2" style="margin-bottom:0;">
      <div class="card-body">
        <strong>📧 Email Officiel :</strong> doc.hafedh26@gmail.com / support@medsina.com<br/>
        <strong>🌐 Portail Web :</strong> https://medsina.medevsync.com
      </div>
      <div class="card-body">
        <strong>📢 Canal Telegram Officiel :</strong> @medsina_officiel<br/>
        <strong>📱 APK / 💻 PC :</strong> medsina.medevsync.com/download/medsina.apk | medsina-setup.exe
      </div>
    </div>
  </div>

  <div class="page-footer">
    <span>Medsina 2027 • Plateforme Médicale Globale (v1.0.102) • MedevSync — Tous droits réservés</span>
    <span>Page 8 / 8</span>
  </div>
</div>

</body>
</html>
"""

html_path = ROOT / "medsina_guide_decouverte_temp.html"
html_path.write_text(html_content, encoding="utf-8")

pdf_output_user = ROOT / "Medsina_Guide_Decouverte_Fonctionnalites.pdf"
pdf_output_web = MEDSINA / "web" / "Medsina_Guide_Decouverte_Fonctionnalites.pdf"
pdf_output_assets = MEDSINA / "assets" / "data" / "Medsina_Guide_Decouverte_Fonctionnalites.pdf"

browser_candidates = [
    "/usr/bin/chromium",
    "/usr/bin/chromium-browser",
    "/usr/bin/google-chrome",
    r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
    r"C:\Program Files\Google\Chrome\Application\chrome.exe",
]
browser_path = None
for b in browser_candidates:
    if os.path.exists(b):
        browser_path = b
        break

if not browser_path:
    import shutil
    for b_name in ["chromium", "chromium-browser", "google-chrome", "msedge"]:
        which_b = shutil.which(b_name)
        if which_b:
            browser_path = which_b
            break

if not browser_path:
    raise RuntimeError("No headless Chromium or Edge browser found to render PDF.")

cmd = [
    browser_path,
    "--headless",
    "--no-sandbox",
    "--disable-gpu",
    "--no-pdf-header-footer",
    f"--print-to-pdf={pdf_output_user.resolve()}",
    str(html_path.resolve())
]

print(f"Compiling PDF with {browser_path} Headless...")
res = subprocess.run(cmd, capture_output=True, text=True)

if pdf_output_user.exists():
    size_mb = pdf_output_user.stat().st_size / (1024 * 1024)
    print(f"SUCCESS: Generated {pdf_output_user} ({size_mb:.2f} MB)")

    # Copy to web and assets
    pdf_output_web.parent.mkdir(parents=True, exist_ok=True)
    pdf_output_web.write_bytes(pdf_output_user.read_bytes())

    pdf_output_assets.parent.mkdir(parents=True, exist_ok=True)
    pdf_output_assets.write_bytes(pdf_output_user.read_bytes())
    print("Copied to web/ and assets/data/ successfully!")
else:
    print("FAILED to create PDF:", res.stderr)

if html_path.exists():
    html_path.unlink()
