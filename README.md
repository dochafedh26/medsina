# 🩺 Medsina 2027 — Plateforme Médicale Globale & Préparation Résidanat

<p align="center">
  <img src="assets/medsina-logo.png" alt="Medsina Logo" width="280">
</p>

<p align="center">
  <strong>La super-application médicale tout-en-un pour étudiants en médecine, internes, résidents, enseignants HU et médecins praticiens en Algérie.</strong><br>
  <em>Formation Résidanat & Externat • Suite Clinique & Urgences (ECG 12D, GDS, PSE) • Ordonnancier DZ & Vidal • Whiteboard Mindmap • Espace Prof 65/35 • 100 % Hors-Ligne</em>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Version-v1.0.102%20(Stable)-0D9488?style=for-the-badge" alt="Version">
  <img src="https://img.shields.io/badge/Plateformes-Android%20%7C%20Windows%20%7C%20Web-0284C7?style=for-the-badge" alt="Platforms">
  <img src="https://img.shields.io/badge/Mode-100%25%20Hors--Ligne-10B981?style=for-the-badge" alt="Offline">
  <img src="https://img.shields.io/badge/Architecture-Bento%20Pinterest%202027-6366F1?style=for-the-badge" alt="Design">
</p>

---

## 🌟 Présentation Générale

**Medsina** (développée par **MedevSync**) est la plateforme médicale de référence conçue sur mesure pour le cursus médical algérien (Faculté de Médecine de Blida et universités nationales).

Elle fusionne en une interface unique, moderne et ultra-fluide :
1. La **préparation au Concours de Résidanat & Externat** (47 modules officiels, +19 000 QCMs corrigés et commentés, livrets All-in-One, flashcards FSRS v4.5, Mode Duel 1v1, Whiteboard & Studio Mindmap, simulateur de classement et choix de spécialité).
2. La **pratique clinique et de garde hospitalière avancée** (protocoles CAT d'urgences vitales, mémentos de garde, **Assistant ECG 12 dérivations avec compte rendu PDF A4 imprimable**, **Interpréteur Gaz du Sang GDS**, **Calculateur PSE & dilutions d'urgence**, **Logbook des gestes pratiques**, **Medsina Synapse** & **Atlas Clinique**).
3. La **sécurité thérapeutique, Ordonnancier DZ & Vidal Algérie** (nomenclature nationale des médicaments, **Ordonnances Types DCI/CNAS enrichies automatiquement 2×/jour via Supabase**, générateur de certificats médico-légaux CBV/ITT en PDF A4, analyse d'ordonnances et contre-indications terrain).
4. L'**Espace Prof / Enseignant HU** (publication réservée aux grades hospitalo-universitaires vérifiés avec **partage de revenus 65 / 35**).
5. L'**espace profil, suivi d'entraînement en temps réel & Mode Focus** (validation journalière, objectifs quotidiens, habit loop hebdomadaire, connexion Google OAuth, synchronisation cloud sécurisée).

---

## 🚀 Fonctionnalités Majeures de Medsina (v1.0.102)

### 1. 🫀 Assistant ECG 12 Dérivations, QTc & Compte Rendu Imprimable (PDF A4)
- **Moteur d'Interprétation Structuré en 12 Dérivations** :
  - Lecture guidée complète : contrôles techniques (aVR, D1, progression de l'onde R, calibrage), fréquence cardiaque, rythme, axe électrique, espace PR, durée/morphologie QRS, segment ST par territoire, onde T et QTc (Bazett / Fridericia).
  - **Détection Automatisée des Troubles Majeurs** : Fibrillation Atriale (FA), Flutter atrial (300/min), Tachycardie Ventriculaire (TV), Blocs Auriculo-Ventriculaires (BAV 1er, Wenckebach, Mobitz 2, 3e degré), Blocs de Branche (BBDG / BBDD), Hypertrophie Ventriculaire Gauche (HVG) et ondes Q pathologiques.
  - **Seuils de SCA ST+ par Territoire** : détection selon les critères consensuels (≥ 2 mm en V2–V3, ≥ 1 mm dans les autres dérivations, sur ≥ 2 dérivations contiguës) avec alertes d'urgence hiérarchisées.
  - **Indicateur de Confiance** calculé selon la qualité technique du tracé et l'exhaustivité des mesures saisies.
  - **Référentiel de Poche Intégré** : valeurs normales, territoires coronaires, chronologie de l'infarctus, règles *WiLLiaM / MaRRoW*.
- **Compte Rendu ECG Imprimable (PDF A4)** :
  - Rédaction médicale structurée en 6 rubriques (*qualité technique, rythme, conduction, axe, repolarisation, QT*), conclusion synthétique, conduite à tenir et note de confiance.
  - Formulaire d'identité patient (nom, âge, indication, renseignements cliniques) et export PDF A4 mis en page avec en-tête Medsina, bandeau de verdict, mesures et visa praticien.

---

### 2. 🧪 Interpréteur Gaz du Sang (GDS / ABG) & Calculateur PSE d'Urgence
- **Interpréteur Gaz du Sang (GDS)** :
  - Analyse acido-basique rapide (pH, PaCO₂, HCO₃⁻, PaO₂/FiO₂, trou anionique) avec identification des troubles simples ou mixtes et calcul des compensations attendues.
- **Calculateur PSE & Dilutions d'Urgence** :
  - Calcul instantané des débits en pousse-seringue électrique (mL/h) selon le poids et l'unité clinique : `γ/kg/min`, `γ/kg/h`, `mg/h`, `UI/kg/h`, `UI/h`.
  - Protocoles de dilution prêts à l'emploi en seringue de garde (50 mL / 20 mL, solvant NaCl 0,9 % ou SG 5 %) : *Noradrénaline, Adrénaline, Dobutamine, Dopamine, Nicardipine (Loxen), Amiodarone, Midazolam, Furosémide, Insuline IVSE, Héparine HNF*.

---

### 3. 📋 Ordonnancier Type Algérie (DCI/CNAS) & Certificats Médico-Légaux PDF A4
- **Ordonnances Types DCI/CNAS (Enrichissement Autonome 2×/jour)** :
  - Bibliothèque d'ordonnances types prêtes à l'emploi adaptées à la pratique algérienne (DCI, noms commerciaux DZ, formulations, posologies adultes et pédiatriques en `mg/kg/j` avec plafonds de sécurité, durées, conseils patient et références scientifiques).
  - **Synchronisation Dynamique Supabase + Cache Hors-Ligne** : actualisation en 1 clic directement dans l'application, alimentée automatiquement 2 fois par jour par pipeline GitHub Actions (`medsina_ordonnances.yml`).
- **Certificats Médico-Légaux (PDF A4)** :
  - Générateur conforme aux standards algériens pour les certificats de coups et blessures volontaires (**CBV / ITT**), arrêts de travail, certificats d'aptitude et certificats médicaux descriptifs avec export PDF A4 prêt à imprimer.

---

### 4. 💊 Sécurité Thérapeutique & Vidal Algérie
- **Nomenclature Nationale Algérienne** :
  - Base exhaustive des spécialités pharmaceutiques commercialisées en Algérie (DCI, noms commerciaux, formes, dosages, statut Chifa, laboratoires).
- **Analyse d'Ordonnance Intelligente** :
  - Détection automatique des interactions médicamenteuses par niveau de gravité (*Contre-indication absolue, Association déconseillée, Précaution d'emploi*).
  - Alertes de contre-indications terrain (*Grossesse par trimestre, Allaitement, Insuffisance rénale / DFG, Insuffisance hépatique, Ulcère gastro-duodénal*).

---

### 5. 🚨 Pratique Clinique, Urgences, Logbook & Medsina Synapse
- **Conduites à Tenir d'Urgence (CAT)** & **Mémentos de Garde** :
  - Protocoles standardisés pour les urgences vitales (SCA, AVC, choc anaphylactique/septique/cardiogénique, HDH, asthme aigu grave, acido-cétose, troubles ioniques) avec mises à jour autonomes.
- **Logbook & Check-lists des Gestes Pratiques de Garde** :
  - Carnet de suivi et check-lists pas-à-pas des gestes techniques hospitaliers (ponction lombaire, gazométrie artérielle, pose de VVC, drainage thoracique, suture, intubation) avec validation des actes réalisés en stage.
- **Medsina Synapse & Atlas Clinique** :
  - Simulateur de cas cliniques interactifs progressifs pour raisonnement diagnostique et thérapeutique.
  - Atlas clinique visuel (sémiologie, imagerie, dermatologie, ECG).
- **Normes Biologiques & Calculateurs Médicaux** :
  - +80 constantes biologiques avec valeurs de référence et conduites devant les valeurs critiques.
  - Calculateurs automatisés : Glasgow, Wells, Cockcroft-Gault, MDRD/CKD-EPI, IMC, Surface corporelle, Parkland, etc.

---

### 6. 🎓 Espace Prof / Enseignant HU & Partage de Revenus 65 / 35
- **Publication Réservée aux Grades Académiques Vérifiés** :
  - Espace dédié aux enseignants hospitalo-universitaires vérifiés par l'administration (*Professeur, MCA, Maître-Assistant / MAHU, Assistant HU, Médecin Résident*) avec badge de grade vérifié.
  - Création et publication de **cours / polycopiés, fiches de synthèse, mindmaps, flashcards, banques QCM et examens EMD & QROC** ; accès en lecture pour tous les étudiants.
- **Programme de Partage de Revenus 65 / 35** :
  - **65 % des revenus nets** reversés aux auteurs enseignants, 35 % à la plateforme, avec comptabilisation des lecteurs uniques, des passages d'examens et plafond équitable par auteur.
  - Nouvel onglet **« Mes gains »** : suivi du solde disponible, historique des clôtures mensuelles et demandes de retrait (*CCP BaridiMob, virement bancaire*).

---

### 7. 🎨 Whiteboard & Studio Mindmap Interactif + Mind Maps Décisionnelles
- **Whiteboard & Studio Mindmap Intégré** :
  - Tableau blanc médical accessible depuis la barre d'icônes (Accueil & Révision) avec modèles pré-construits (*Carte Mentale, Physiopathologie, Arbre Décisionnel*), export direct en PDF et synchronisation Cloud Supabase.
- **Mind Maps Décisionnelles Vectorielles (Google Drive Cloud)** :
  - Arborescences cliniques haute résolution structurées en 6 branches pour les cours du programme de Résidanat.
  - **Demande de Mind Map en 1 Clic** directement depuis n'importe quel cours ou fiche de synthèse qui n'en dispose pas encore.
  - Expérience hybride : arbre interactif tactile + visionneuse vectorielle HD plein écran hors-ligne.

---

### 8. 🎯 Moteur QCM « Ultra-Résidanat », Duel 1v1, Mnémos & Simulateur de Classement
- **Plus de 19 000 QCMs & Cas Cliniques** :
  - Mode Révision Immédiate (explications détaillées) et Mode Examen Blanc Chronométré (15 à 120 min, barèmes **Tout ou Rien** ou **Notation Partielle**).
  - Filtres intelligents (*Jamais consultées, Mes erreurs, Favoris, Notes personnelles, Haute tombabilité*) et alertes anti-pièges (*SAUF / FAUSSE*).
- **Mode Duel QCM 1v1 & Défis Rapides** :
  - Affrontez vos confrères en temps réel sur des séries de QCMs chronométrées et suivez votre score de duel.
- **Banque de Mnémotechniques & Associations Réflexes QCM** :
  - Fiches mnémotechniques classées par spécialité et associations réflexes incontournables pour déjouer les pièges d'annales.
- **Simulateur de Classement & Choix de Spécialité Résidanat** :
  - Estimez votre rang et visualisez les spécialités *Accessibles*, *Compétitives* ou *À consolider* selon votre note et votre faculté (*Blida, Alger, Oran, Constantine, Annaba / Sétif / Tlemcen*).
- **Examens Nationaux Blancs, Groupes de Révision, Révision Audio, Carnet d'Erreurs, Samedis Pédagogiques & Coach IA**.

---

### 9. 🧠 Flashcards FSRS v4.5, Study Planner 3 Couches & Mode Focus
- **Répétition Espacée FSRS v4.5** : calcul scientifique de la stabilité ($S$), difficulté ($D$) et rétention ($R$), conversion d'un QCM en flashcard en 1 clic et widget FSRS sur le tableau de bord.
- **Study Planner Matriciel (3 Couches)** : suivi *Couche 1 (Lecture) / Couche 2 (Fiches) / Couche 3 (Annales)*, compte à rebours J-X et priorités du jour par IA.
- **Mode Focus (Spécialité / Rotation de Module) & Minuteur Pomodoro** : filtrez instantanément Cours, Externat, CATs et Tableau de bord sur la spécialité de votre stage ou rotation en cours.
- **Catalogue des 47 Livrets All-in-One** & **Parcours Externat (1re à 6e Année)** avec filtrage dédié par année universitaire et simulations EMD.
- **Témoignages & Conseils Majors Résidanat** hébergés sur Supabase Cloud (zéro rebuild, indexés dans Omnisearch).

---

### 10. 👤 Espace Profil Bento 2027, Suivi Quotidien & Connexion Google
- **Authentification Rapide avec Google (OAuth Supabase)** en plus de la connexion par email.
- **Identité Médicale & Avatars** : rôle médical, faculté, wilaya (1 à 58), session cible, upload photo Supabase Storage et 8 avatars médicaux vectoriels.
- **Validation Journalière (« Accomplir le Jour »)** : +50 XP fidélité, série active (Streak 🔥), tracker hebdomadaire 7 jours (`L M M J V S D`), objectifs quotidiens et enregistrement des révisions externes.
- **Fidélité & Parrainage Confraternel** : progression en rangs médicaux et **+7 jours All-Access VIP offerts** par confrère parrainé.

---

### 11. 🔍 Medsina Omnisearch (`Ctrl+K` / `⌘K`) & Mises à Jour OTA (Stable & Bêta)
- **Omnisearch Transversal** : recherche instantanée (< 100 ms) dans les cours PDF (avec surlignage automatique sur la page), QCMs, CATs, mémentos, Vidal Algérie, ordonnances types, mnémos, outils cliniques et témoignages.
- **Canaux Stable & Bêta Côte à Côte** : installation simultanée possible de **Medsina (Stable)** et **Medsina Beta** sur Android & Windows, avec mises à jour automatiques Over-The-Air (OTA) dédiées par canal.

---

## 🎨 Conception Graphique & Ergonomie

L'interface de Medsina adopte le design **Bento / Pinterest UI 2026/2027** :
- **Dock Flottant Mobile** : navigation par pilule dynamique ergonomique à une main, accès rapide Espace Prof, Whiteboard et Outils Cliniques.
- **Sidebar Bento Desktop** : organisation modulaire avec cartes d'identité, raccourcis clavier et statut de synchronisation.
- **Mode Sombre & Mode Clair** : thèmes contrastés étudiés pour les longues gardes de nuit et séances de bibliothèque.

---

## 💻 Téléchargement & Accès Multiplateforme

| Plateforme | Format | Lien d'accès |
| :--- | :--- | :--- |
| **Android (Stable)** | APK / AAB | [Télécharger Medsina Android](https://medsina.medevsync.com/download/medsina.apk) |
| **Windows Desktop (Stable)** | Setup x64 (Hors-Ligne) | [Télécharger Medsina Windows](https://medsina.medevsync.com/download/medsina-setup.exe) |
| **Web SaaS** | Navigateurs modernes | [Ouvrir Medsina Web](https://medsina.medevsync.com) |
| **Guide Découverte PDF** | Documentation Officielle | [Consulter le Guide PDF](https://medsina.medevsync.com/Medsina_Guide_Decouverte_Fonctionnalites.pdf) |
| **Canal Telegram Officiel** | Annonces & Échanges | [Rejoindre @medsina_officiel](https://t.me/medsina_officiel) |

---

## 🛠️ Stack Technique

- **Framework** : Flutter 3 (Dart) — Workspace modulaire multi-plateforme (Android, Windows Desktop, Web).
- **Architecture** : BLoC Pattern (`flutter_bloc`), Clean Architecture, Equatable.
- **Base de Données & Cloud** : Supabase (PostgreSQL, Auth + Google OAuth, Storage, Edge Functions, Row Level Security).
- **Cache, PDF & Persistance Locale** : `SharedPreferences`, `Syncfusion Flutter PDF` (lecture + génération A4 ECG/Ordonnances/Certificats), SQLite/JSON Offline Cache.
- **Algorithmes & Moteurs** : Interpréteur ECG 12 dérivations, Analyseur GDS & PSE, FSRS v4.5, Omnisearch In-Memory Indexer.
- **CI/CD & Automatisation** : GitHub Actions (Release & OTA multi-canal, enrichissement autonome 2×/jour des Ordonnances Types, CATs, Mémentos, Normes Biologiques, Résumés de cours et Mind Maps).

---

<p align="center">
  <em>Conçu avec passion par l'équipe <strong>MedevSync</strong> pour les étudiants, enseignants et médecins d'Algérie 🇩🇿</em>
</p>
