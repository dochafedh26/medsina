import base64
import os
import subprocess
from pathlib import Path

# Paths
ROOT = Path(r"d:\REVISION RESIDANAT\ressources\residanat-blida-2027")
MEDSINA = ROOT / "medsina"
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

html_content = f"""<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<title>Medsina 2027 - Guide Officiel de Découverte</title>
<style>
  @import url('https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=Inter:wght@400;500;600;700&display=swap');

  @page {{
    size: A4;
    margin: 10mm 12mm 12mm 12mm;
    @bottom-right {{
      content: counter(page);
    }}
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
    font-size: 11pt;
    line-height: 1.5;
  }}

  .page {{
    page-break-after: always;
    break-after: page;
    position: relative;
    padding-bottom: 20px;
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
    padding-bottom: 8px;
    margin-bottom: 18px;
  }}

  .page-header .brand {{
    font-weight: 800;
    font-size: 13pt;
    color: #0F766E;
    display: flex;
    align-items: center;
    gap: 8px;
  }}

  .page-header .doc-tag {{
    font-size: 8.5pt;
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
    padding-top: 6px;
    font-size: 8pt;
    color: #94A3B8;
  }}

  /* COVER STYLING */
  .cover {{
    display: flex;
    flex-direction: column;
    justify-content: space-between;
    min-height: 960px;
    padding: 20px 10px;
    background: linear-gradient(170deg, #F0FDFA 0%, #FFFFFF 40%, #F8FAFC 100%);
    border-radius: 16px;
    border: 1.5px solid #CCFBF1;
  }}

  .cover-top {{
    text-align: center;
    padding-top: 20px;
  }}

  .cover-logo {{
    max-height: 70px;
    margin-bottom: 15px;
  }}

  .cover-badge {{
    display: inline-block;
    background: #0F766E;
    color: #FFFFFF;
    font-size: 9pt;
    font-weight: 800;
    letter-spacing: 1.2px;
    text-transform: uppercase;
    padding: 6px 16px;
    border-radius: 20px;
    margin-bottom: 18px;
  }}

  .cover-title {{
    font-size: 28pt;
    font-weight: 800;
    color: #0F172A;
    line-height: 1.15;
    margin: 0 0 12px 0;
  }}

  .cover-title span {{
    color: #0F766E;
  }}

  .cover-subtitle {{
    font-size: 13pt;
    font-weight: 500;
    color: #475569;
    max-width: 650px;
    margin: 0 auto 25px auto;
    line-height: 1.4;
  }}

  .cover-pills {{
    display: flex;
    justify-content: center;
    gap: 12px;
    margin-bottom: 30px;
  }}

  .cover-pill {{
    background: #FFFFFF;
    border: 1px solid #CBD5E1;
    padding: 6px 14px;
    border-radius: 30px;
    font-size: 9pt;
    font-weight: 600;
    color: #334155;
    box-shadow: 0 2px 4px rgba(0,0,0,0.03);
  }}

  .cover-preview {{
    text-align: center;
    margin: 10px auto;
  }}

  .cover-preview img {{
    max-width: 90%;
    max-height: 380px;
    border-radius: 12px;
    box-shadow: 0 12px 30px rgba(15, 118, 110, 0.18);
    border: 1.5px solid #CBD5E1;
  }}

  .cover-meta {{
    display: flex;
    justify-content: space-between;
    background: #FFFFFF;
    padding: 16px 24px;
    border-radius: 12px;
    border: 1px solid #E2E8F0;
    margin-top: 20px;
  }}

  .cover-meta-item strong {{
    display: block;
    font-size: 11pt;
    color: #0F766E;
  }}

  .cover-meta-item span {{
    font-size: 8.5pt;
    color: #64748B;
  }}

  /* GENERAL TYPOGRAPHY */
  h1 {{
    font-size: 18pt;
    font-weight: 800;
    color: #0F172A;
    margin: 0 0 8px 0;
    display: flex;
    align-items: center;
    gap: 10px;
  }}

  h2 {{
    font-size: 13pt;
    font-weight: 700;
    color: #0F766E;
    margin: 18px 0 8px 0;
    border-bottom: 1px solid #E2E8F0;
    padding-bottom: 4px;
  }}

  h3 {{
    font-size: 11pt;
    font-weight: 700;
    color: #1E293B;
    margin: 12px 0 4px 0;
  }}

  p {{
    margin: 0 0 10px 0;
    color: #334155;
    font-size: 10pt;
    line-height: 1.55;
  }}

  /* GRID & CARDS */
  .grid-2 {{
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 14px;
    margin-bottom: 14px;
  }}

  .grid-3 {{
    display: grid;
    grid-template-columns: 1fr 1fr 1fr;
    gap: 12px;
    margin-bottom: 14px;
  }}

  .card {{
    background: #F8FAFC;
    border: 1px solid #E2E8F0;
    border-radius: 10px;
    padding: 12px 14px;
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

  .card-title {{
    font-weight: 700;
    font-size: 10.5pt;
    color: #0F172A;
    margin-bottom: 4px;
    display: flex;
    align-items: center;
    gap: 6px;
  }}

  .card-body {{
    font-size: 9pt;
    color: #475569;
    line-height: 1.45;
  }}

  .badge {{
    display: inline-block;
    padding: 2px 8px;
    border-radius: 6px;
    font-size: 7.5pt;
    font-weight: 700;
    text-transform: uppercase;
  }}

  .badge-teal {{ background: #CCFBF1; color: #0F766E; }}
  .badge-blue {{ background: #E0F2FE; color: #0284C7; }}
  .badge-green {{ background: #DCFCE7; color: #16A34A; }}
  .badge-purple {{ background: #F3E8FF; color: #7E22CE; }}

  /* SCREENSHOT STYLING */
  .screenshot-box {{
    margin: 12px 0;
    text-align: center;
    background: #F1F5F9;
    padding: 8px;
    border-radius: 10px;
    border: 1px solid #E2E8F0;
  }}

  .screenshot-box img {{
    max-width: 100%;
    max-height: 220px;
    border-radius: 6px;
    border: 1px solid #CBD5E1;
    box-shadow: 0 4px 10px rgba(0,0,0,0.06);
  }}

  .screenshot-caption {{
    font-size: 8pt;
    color: #64748B;
    margin-top: 4px;
    font-weight: 500;
  }}

  /* PRICING TABLE */
  table.pricing-table {{
    width: 100%;
    border-collapse: collapse;
    margin: 12px 0 16px 0;
    font-size: 9pt;
  }}

  table.pricing-table th {{
    background: #0F766E;
    color: #FFFFFF;
    text-align: left;
    padding: 9px 10px;
    font-weight: 700;
  }}

  table.pricing-table td {{
    padding: 8px 10px;
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
    margin: 6px 0 12px 0;
    padding-left: 18px;
    font-size: 9.5pt;
  }}

  ul.feat-list li {{
    margin-bottom: 4px;
    color: #334155;
  }}

  .callout {{
    background: #FFFBEB;
    border-left: 4px solid #F59E0B;
    padding: 10px 14px;
    border-radius: 6px;
    font-size: 9pt;
    margin: 10px 0;
    color: #92400E;
  }}

  .callout strong {{
    color: #78350F;
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
    <div class="cover-badge">Documentation Officielle Utilisateur • 2026-2027</div>
    <h1 class="cover-title">Plateforme Médicale Globale & <span>Résidanat 2027</span></h1>
    <p class="cover-subtitle">Le guide de découverte complet pour maîtriser les 47 modules de révision, les banques de QCM, les protocoles d'urgence et la sécurité thérapeutique.</p>
    
    <div class="cover-pills">
      <div class="cover-pill">💻 Accès Web & Cloud</div>
      <div class="cover-pill">📱 Application Android APK</div>
      <div class="cover-pill">🖥️ Application Windows 64-bit</div>
      <div class="cover-pill">⚡ 100% Hors-Ligne</div>
      <div class="cover-pill" style="border-color:#F59E0B; color:#F59E0B;">🔍 Omnisearch Intégré (Ctrl+K)</div>
    </div>
  </div>

  <div class="cover-preview">
    {'<img src="' + dashboard_b64 + '" alt="Tableau de bord Medsina">' if dashboard_b64 else ''}
  </div>

  <div class="cover-meta">
    <div class="cover-meta-item">
      <strong>Public Visé</strong>
      <span>Externes (1ère - 6ème), Internes & Médecins Candidats</span>
    </div>
    <div class="cover-meta-item">
      <strong>Couverture Médicale</strong>
      <span>47 Modules Officiels • Nomenclature Vidal Algérie</span>
    </div>
    <div class="cover-meta-item">
      <strong>Version Système</strong>
      <span>Medsina v1.0.16 (Build Stable 2027)</span>
    </div>
    <div class="cover-meta-item">
      <strong>Portail Officiel</strong>
      <span>https://medsina.medevsync.com</span>
    </div>
  </div>
</div>

<!-- ========================================================================= -->
<!-- PAGE 2 : PRÉSENTATION GÉNÉRALE & ACCÈS MULTI-PLATEFORMES                  -->
<!-- ========================================================================= -->
<div class="page">
  <div class="page-header">
    <div class="brand">{'<img src="' + icon_b64 + '" height="20">' if icon_b64 else ''} Medsina • Guide Utilisateur</div>
    <div class="doc-tag">1. Présentation & Accès</div>
  </div>

  <h1>🌟 Qu'est-ce que Medsina ?</h1>
  <p><strong>Medsina</strong> est la première plateforme médicale globale et intégrée conçue spécialement pour les étudiants en médecine, les internes hospitaliers et les médecins préparant le concours de résidanat en Algérie (Faculté de Médecine de Blida et programme national). Elle unifie sur une interface fluide la révision théorique, les banques d'entraînement intensif, la prise en charge clinique d'urgence et l'audit d'ordonnances.</p>

  <h2>🚀 Les 3 Modes d'Accès de l'Application</h2>
  <div class="grid-3">
    <div class="card card-teal">
      <div class="card-title">🌐 1. Version Web (En Ligne)</div>
      <div class="card-body">
        Accessible directement depuis n'importe quel navigateur (Chrome, Firefox, Safari) sans installation préalable.<br/>
        <strong>Lien :</strong> <code>https://medsina.medevsync.com</code><br/>
        Idéal pour réviser sur tablette, iPad ou ordinateur partagé à l'hôpital.
      </div>
    </div>
    <div class="card card-blue">
      <div class="card-title">📱 2. Application Android (APK)</div>
      <div class="card-body">
        Package natif ultra-léger et autonome pour smartphones et tablettes Android.<br/>
        <strong>Téléchargement direct :</strong><br/>
        <code>medsina.medevsync.com/download/medsina.apk</code><br/>
        Intègre le mode <strong>100% hors-ligne</strong> pour les gardes sans réseau.
      </div>
    </div>
    <div class="card card-purple">
      <div class="card-title">💻 3. Application Windows PC</div>
      <div class="card-body">
        Installeur officiel 64-bit avec raccourci bureau et performances maximales.<br/>
        <strong>Téléchargement direct :</strong><br/>
        <code>medsina.medevsync.com/download/medsina-setup.exe</code><br/>
        Support du double écran et confort visuel de révision prolongée.
      </div>
    </div>
  </div>

  <h2>🔍 Medsina Omnisearch : Moteur de Recherche Médical Transversal (Ctrl+K)</h2>
  <p>Medsina intègre un moteur de recherche unifié capable d'interroger instantanément et simultanément <strong>toutes les bases de données</strong> de l'application en moins de 100 millisecondes :</p>
  <div class="grid-3" style="margin-bottom:10px;">
    <div class="card card-teal">
      <div class="card-title">📚 Cours & Fichiers PDF</div>
      <div class="card-body">
        Recherche plein texte dans les 47 modules. En cliquant sur un résultat, <strong>le PDF s'ouvre automatiquement avec le mot recherché surligné</strong> sur la bonne page.
      </div>
    </div>
    <div class="card card-blue">
      <div class="card-title">🚨 CAT & Mémentos de Garde</div>
      <div class="card-body">
        Localisez instantanément les conduites à tenir d'urgence, drapeaux rouges, étapes de réanimation et checklists réflexes d'astreinte hospitalière.
      </div>
    </div>
    <div class="card card-purple">
      <div class="card-title">🎯 QCMs, Doses & Scores</div>
      <div class="card-body">
        Retrouvez les questions d'annales de concours avec justifications, posologies d'urgence Saidal/IPA et calculateurs cliniques (Glasgow, Wells...).
      </div>
    </div>
  </div>

  <h2>⚡ Le Mode Hors-Ligne Total (Offline-First Architecture)</h2>
  <p>Contrairement aux sites web classiques qui cessent de fonctionner dès que le réseau 4G/Wi-Fi est instable, <strong>Medsina embarque toutes ses banques de données directement sur votre appareil</strong> :</p>
  <ul class="feat-list">
    <li><strong>Banque intégrale des QCMs :</strong> Entraînez-vous dans les couloirs de garde, le métro ou en salle d'étude sans aucune connexion.</li>
    <li><strong>Protocoles d'Urgence (CAT) & Mémentos :</strong> Retrouvez les conduites à tenir réflexes instantanément en cas d'urgence vitale.</li>
    <li><strong>Nomenclature des Médicaments d'Algérie :</strong> Consultez les posologies et DCI locales en tout temps.</li>
    <li><strong>Synchronisation Silencieuse :</strong> Vos scores, statistiques et états de lecture se synchronisent automatiquement dès le retour d'une connexion internet.</li>
  </ul>

  <div class="callout">
    <strong>🎁 Pass Découverte Offert (14 Jours Gratuits) :</strong> Dès la création de votre compte, Medsina active automatiquement une période d'essai gratuit de 14 jours complets sans engagement pour explorer l'ensemble des modules.
  </div>

  <div class="page-footer">
    <span>Medsina 2027 • Guide Officiel</span>
    <span>Page 2</span>
  </div>
</div>

<!-- ========================================================================= -->
<!-- PAGE 3 : FORMATION ACADÉMIQUE & PRÉPARATION AU RÉSIDANAT                  -->
<!-- ========================================================================= -->
<div class="page">
  <div class="page-header">
    <div class="brand">{'<img src="' + icon_b64 + '" height="20">' if icon_b64 else ''} Medsina • Guide Utilisateur</div>
    <div class="doc-tag">2. Révision & QCM Concours</div>
  </div>

  <h1>📚 Catalogue des 47 Modules & Banques QCM</h1>
  <p>Le module de révision constitue le cœur académique de Medsina. Il est structuré pour vous accompagner pas-à-pas depuis vos stages hospitaliers jusqu'au jour J du concours de résidanat.</p>

  <div class="grid-2">
    <div>
      <h3>📖 Fiches Synthèses de Concours</h3>
      <p>Chaque cours officiel dispose d'une fiche de révision à haut rendement élaborée selon le consensus le plus récent :</p>
      <ul class="feat-list">
        <li><strong>Rappels essentiels :</strong> Définitions consensuelles et physiopathologie.</li>
        <li><strong>Tableaux diagnostiques :</strong> Signes cardinaux, critères cliniques et scores.</li>
        <li><strong>Pièges de concours fréquents :</strong> Alertes sur les confusions classiques des questions de résidanat.</li>
        <li><strong>Mémorisation visuelle :</strong> Schémas et mémos mnémotechniques.</li>
      </ul>
    </div>
    <div>
      <h3>🎯 Banques de QCM Corrigés & Détaillés</h3>
      <p>Plus de <strong>15 000 QCMs</strong> tirés des annales officielles du concours et des examens facultaires :</p>
      <ul class="feat-list">
        <li><strong>Correction instantanée :</strong> Explications justifiant chaque proposition vraie ou fausse.</li>
        <li><strong>Mode Entraînement Libre :</strong> Session modulable par item ou par spécialité.</li>
        <li><strong>Mode Examen Chronométré :</strong> Simulation en conditions réelles avec timer et calcul de note.</li>
        <li><strong>Historique des Erreurs :</strong> Révisez spécifiquement les questions où vous avez hésité ou échoué.</li>
      </ul>
    </div>
  </div>

  <div class="screenshot-box">
    {'<img src="' + qcm_b64 + '" alt="Interface de Révision QCM">' if qcm_b64 else ''}
    <div class="screenshot-caption">Interface d'entraînement QCM avec justification pédagogique, timer et grille interactive</div>
  </div>

  <h2>🎓 NOUVEAUTÉ : Parcours Universitaire « Pass Étudiant » (1ère à 6ème Année)</h2>
  <p>Medsina s'adapte désormais précisément à votre niveau d'étude médicale :</p>
  <div class="grid-2">
    <div class="card card-blue">
      <div class="card-title">🏫 Filtrage Intelligent par Année</div>
      <div class="card-body">
        Lorsque vous sélectionnez votre année (ex: <em>3ème Année</em>), l'application filtre immédiatement le catalogue pour n'afficher que les modules de votre cursus (Sémiologie, Pharmacologie, Microbiologie, etc.).
      </div>
    </div>
    <div class="card card-teal">
      <div class="card-title">🛡️ Séparation Cursus vs Concours</div>
      <div class="card-body">
        Les étudiants bénéficient des questions adaptées aux examens de fin de rotation sans être surchargés par les questions pièges spécifiques au concours de résidanat.
      </div>
    </div>
  </div>

  <div class="page-footer">
    <span>Medsina 2027 • Guide Officiel</span>
    <span>Page 3</span>
  </div>
</div>

<!-- ========================================================================= -->
<!-- PAGE 4 : PRATIQUE CLINIQUE & PROTOCOLES D'URGENCE                         -->
<!-- ========================================================================= -->
<div class="page">
  <div class="page-header">
    <div class="brand">{'<img src="' + icon_b64 + '" height="20">' if icon_b64 else ''} Medsina • Guide Utilisateur</div>
    <div class="doc-tag">3. Clinique & Urgences</div>
  </div>

  <h1>🚨 Outils Pratiques pour l'Interne & Praticien</h1>
  <p>Lors d'une garde aux UMC ou en service d'hospitalisation, le temps et la précision diagnostique sont vitaux. Medsina met à votre disposition une suite d'outils décisionnels validés.</p>

  <div class="grid-2">
    <div class="card card-teal">
      <div class="card-title">🚨 Conduites à Tenir d'Urgence (CAT)</div>
      <div class="card-body">
        Protocoles de prise en charge étape par étape selon les recommandations nationales et internationales (SFMU, SRLF, AHA) :
        <ul style="margin:4px 0 0 0; padding-left:16px;">
          <li>SCA ST+ / Non-ST+ et protocoles de thrombolyse</li>
          <li>Accident Vasculaire Cérébral (AVC) et fenêtre de thrombolyse</li>
          <li>Hémorragie Digestive Haute (HDH) et stabilisation hémodynamique</li>
          <li>Choc anaphylactique, septique et cardiogénique</li>
          <li>Détresses respiratoires aiguës et crises d'asthme aigu grave</li>
        </ul>
      </div>
    </div>
    <div class="card card-purple">
      <div class="card-title">📋 Mémentos de Garde Réflexes</div>
      <div class="card-body">
        Fiches synthétiques ultra-rapides conçues pour consultation immédiate au lit du malade :
        <ul style="margin:4px 0 0 0; padding-left:16px;">
          <li>Syndrome méningé aigu & indications de la ponction lombaire</li>
          <li>Comas et échelle de Glasgow</li>
          <li>Acido-cétose diabétique et protocole d'insulinothérapie IV</li>
          <li>Troubles hydro-électrolytiques (Hyponatrémie, Hypo/Hyperkaliémie)</li>
          <li>Brûlures étendues et règle de Parkland</li>
        </ul>
      </div>
    </div>
  </div>

  <div class="screenshot-box">
    {'<img src="' + cat_b64 + '" alt="Interface CAT Urgence">' if cat_b64 else ''}
    <div class="screenshot-caption">Module Conduite à Tenir (CAT) avec arbre décisionnel et posologies thérapeutiques immédiates</div>
  </div>

  <h2>🧪 Constantes Biologiques & Médicaments d'Urgence</h2>
  <div class="grid-2">
    <div>
      <h3>📊 Normes & Constantes Biologiques</h3>
      <p>Plus de <strong>80 paramètres biologiques</strong> classés par spécialité (NFS, Ionogramme, Hémostase, Bilan hépatique, Gaz du sang, LCR) avec valeurs normales, conversions d'unités et conduites à tenir devant les anomalies critiques.</p>
    </div>
    <div>
      <h3>💊 Médicaments d'Urgence Algérie</h3>
      <p>Fiches détaillées sur les molécules injectables des urgences (Adrénaline, Noradrénaline, Amiodarone, Furosémide, Héparine, etc.) avec protocoles de dilution et débits en seringue électrique.</p>
    </div>
  </div>

  <div class="page-footer">
    <span>Medsina 2027 • Guide Officiel</span>
    <span>Page 4</span>
  </div>
</div>

<!-- ========================================================================= -->
<!-- PAGE 5 : SÉCURITÉ THÉRAPEUTIQUE & ORDONNANCES MÉDICALES                   -->
<!-- ========================================================================= -->
<div class="page">
  <div class="page-header">
    <div class="brand">{'<img src="' + icon_b64 + '" height="20">' if icon_b64 else ''} Medsina • Guide Utilisateur</div>
    <div class="doc-tag">4. Vidal & Sécurité Ordonnance</div>
  </div>

  <h1>💊 Nomenclature des Médicaments & Vidal Algérie</h1>
  <p>La prescription médicale engage la responsabilité du praticien. Medsina intègre un moteur d'audit d'ordonnances basé sur la nomenclature officielle algérienne et le thésaurus des interactions médicamenteuses.</p>

  <div class="screenshot-box">
    {'<img src="' + prescription_b64 + '" alt="Audit Ordonnance">' if prescription_b64 else ''}
    <div class="screenshot-caption">Analyseur d'ordonnance : détection des interactions médicamenteuses et alertes de contre-indications terrain</div>
  </div>

  <h2>🛡️ Les 3 Piliers de la Sécurité Thérapeutique</h2>
  <div class="grid-3">
    <div class="card card-blue">
      <div class="card-title">🇩🇿 1. Nomenclature Algérie</div>
      <div class="card-body">
        Base exhaustive des spécialités pharmaceutiques enregistrées en Algérie avec :
        <ul style="margin:4px 0 0 0; padding-left:14px;">
          <li>DCI et Marques commerciales</li>
          <li>Dosages et Formes (comprimés, injectables)</li>
          <li>Statut de remboursement Chifa</li>
          <li>Laboratoires producteurs (locaux et importés)</li>
        </ul>
      </div>
    </div>
    <div class="card card-teal">
      <div class="card-title">⚠️ 2. Interactions Vidal</div>
      <div class="card-body">
        Moteur d'analyse croisée des molécules prescrites avec classification par niveau de gravité :
        <ul style="margin:4px 0 0 0; padding-left:14px;">
          <li><strong>Contre-indication absolue (CI) :</strong> Risque létal ou torsade de pointes.</li>
          <li><strong>Association déconseillée :</strong> Surveillance clinique renforcée.</li>
          <li><strong>Précautions d'emploi :</strong> Adaptation posologique nécessaire.</li>
        </ul>
      </div>
    </div>
    <div class="card card-purple">
      <div class="card-title">🤰 3. Contre-indications Terrain</div>
      <div class="card-body">
        Validation instantanée des médicaments selon le profil physiologique du patient :
        <ul style="margin:4px 0 0 0; padding-left:14px;">
          <li>Grossesse (1er, 2ème, 3ème trimestre)</li>
          <li>Allaitement maternel</li>
          <li>Insuffisance Rénale (Clairance DFG)</li>
          <li>Insuffisance Hépatique sévère</li>
          <li>Antécédents d'ulcère gastro-duodénal</li>
        </ul>
      </div>
    </div>
  </div>

  <h2>📋 Générateur d'Ordonnances Médicales Conformité</h2>
  <p>Saisissez vos médicaments en quelques clics pour générer une ordonnance claire, sans ratures, conforme aux standards médicolégaux algériens avec mention des posologies précises, durées de traitement et conseils hygiéno-diététiques.</p>

  <div class="page-footer">
    <span>Medsina 2027 • Guide Officiel</span>
    <span>Page 5</span>
  </div>
</div>

<!-- ========================================================================= -->
<!-- PAGE 6 : FORMULES D'ABONNEMENT, TARIFS & ASSISTANCE                       -->
<!-- ========================================================================= -->
<div class="page">
  <div class="page-header">
    <div class="brand">{'<img src="' + icon_b64 + '" height="20">' if icon_b64 else ''} Medsina • Guide Utilisateur</div>
    <div class="doc-tag">5. Formules, Tarifs & Support</div>
  </div>

  <h1>💎 Formules d'Abonnement & Tarifs Algérie (DZD)</h1>
  <p>Medsina propose des formules claires et transparentes adaptées à chaque étape de votre parcours médical :</p>

  <table class="pricing-table">
    <thead>
      <tr>
        <th>Formule</th>
        <th>Public Idéal</th>
        <th>Contenu & Accès Inclus</th>
        <th>Tarif Annuel</th>
        <th>Tarif Mensuel</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td><strong>Pass Découverte</strong></td>
        <td>Tous les nouveaux inscrits</td>
        <td>14 jours d'accès complet à tous les modules sans carte bancaire</td>
        <td><span class="badge badge-teal">GRATUIT (14j)</span></td>
        <td>0 DZD</td>
      </tr>
      <tr>
        <td><strong>Pass Étudiant</strong></td>
        <td>Externes (1ère à 6ème Année)</td>
        <td>Modules spécifiques de l'année choisie, QCMs d'examens, fiches de rotation</td>
        <td><strong>3 500 DZD</strong> / an</td>
        <td>500 DZD / mois</td>
      </tr>
      <tr>
        <td><strong>Pass Clinique Pro</strong></td>
        <td>Internes & Praticiens UMC</td>
        <td>Protocoles CAT, Mémentos de garde, Vidal Algérie, Normes labo & Calculatrices</td>
        <td><strong>5 000 DZD</strong> / an</td>
        <td>800 DZD / mois</td>
      </tr>
      <tr class="highlight-row">
        <td><strong>Pass Résident Élite</strong> ⭐</td>
        <td>Candidats au Concours</td>
        <td>Catalogue 47 Modules, 15 000+ QCMs corrigés, annales classées, statistiques</td>
        <td><strong>5 600 DZD</strong> / an</td>
        <td>900 DZD / mois</td>
      </tr>
      <tr style="background:#FDF4FF;">
        <td><strong>Medsina All-Access VIP</strong> 👑</td>
        <td>Médecins & Candidats exigeants</td>
        <td>Accès total illimité : Concours + Clinique + Mémentos + Assistant IA Copilot</td>
        <td><strong>6 500 DZD</strong> / an</td>
        <td>1 000 DZD / mois</td>
      </tr>
    </tbody>
  </table>

  <h2>💳 Modalités de Règlement en Algérie</h2>
  <div class="grid-3">
    <div class="card">
      <div class="card-title">📱 BaridiMob (Algérie Poste)</div>
      <div class="card-body">
        Virement instantané vers le RIP officiel Medsina. Téléversez la capture d'écran du reçu pour activation rapide.<br/>
        <strong>RIP :</strong> <code>007999990009171614 93</code>
      </div>
    </div>
    <div class="card">
      <div class="card-title">📮 Virement CCP / Bureau de Poste</div>
      <div class="card-body">
        Versement direct en bureau de poste sur compte CCP :<br/>
        <strong>Compte :</strong> <code>9171614 Clé 19</code><br/>
        <strong>Titulaire :</strong> Chikh Touhami Hafed
      </div>
    </div>
    <div class="card">
      <div class="card-title">🔑 Clés de Licence Medsina</div>
      <div class="card-body">
        Bénéficiez d'une clé d'activation acquise lors d'événements, concours ou offres partenaires. Saisie directe dans l'application.
      </div>
    </div>
  </div>

  <h2>📞 Assistance & Canaux Officiels</h2>
  <div class="card card-teal" style="margin-top:10px;">
    <div class="grid-2">
      <div>
        <strong>💬 Support WhatsApp Administratif :</strong> +213 770 00 00 00<br/>
        <strong>📧 Email Officiel :</strong> doc.hafedh26@gmail.com / support@medsina.com<br/>
        <strong>🌐 Application Web :</strong> https://medsina.medevsync.com
      </div>
      <div>
        <strong>📢 Canal Telegram Officiel :</strong> @medsina_officiel<br/>
        <strong>📱 Téléchargement APK :</strong> https://medsina.medevsync.com/download/medsina.apk<br/>
        <strong>💻 Téléchargement Windows :</strong> https://medsina.medevsync.com/download/medsina-setup.exe
      </div>
    </div>
  </div>

  <div class="page-footer">
    <span>Medsina 2027 • Plateforme Médicale Globale • Tous droits réservés</span>
    <span>Page 6</span>
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

edge_path = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
cmd = [
    edge_path,
    "--headless",
    "--disable-gpu",
    "--no-pdf-header-footer",
    f"--print-to-pdf={pdf_output_user.resolve()}",
    str(html_path.resolve())
]

print("Compiling PDF with Edge Headless...")
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
