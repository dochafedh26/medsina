# 🩺 Medsina 2027 — Plateforme Médicale Globale & Préparation Résidanat

<p align="center">
  <img src="assets/medsina-logo.png" alt="Medsina Logo" width="280">
</p>

<p align="center">
  <strong>La super-application médicale tout-en-un pour étudiants en médecine, internes, résidents et médecins praticiens en Algérie.</strong><br>
  <em>Formation Résidanat • Pratique Clinique • Mémentos de Garde • Vidal Algérie • IA Médicale • 100 % Hors-Ligne</em>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Version-v1.0.57-0D9488?style=for-the-badge" alt="Version">
  <img src="https://img.shields.io/badge/Plateformes-Android%20%7C%20Windows%20%7C%20Web-0284C7?style=for-the-badge" alt="Platforms">
  <img src="https://img.shields.io/badge/Mode-100%25%20Hors--Ligne-10B981?style=for-the-badge" alt="Offline">
  <img src="https://img.shields.io/badge/Architecture-Bento%20Pinterest%202027-6366F1?style=for-the-badge" alt="Design">
</p>

---

## 🌟 Présentation Générale

**Medsina** (développée par **MedevSync**) est la plateforme médicale de référence conçue sur mesure pour le cursus médical algérien (Faculté de Médecine de Blida et universités nationales). 

Elle fusionne en une interface unique, moderne et ultra-fluide :
1. La **préparation au Concours de Résidanat** (47 modules officiels, +19 000 QCMs corrigés et commentés, fiches de synthèse, flashcards FSRS, banques d'annales).
2. La **pratique clinique et de garde hospitalière** (protocoles d'urgences vitales, conduites à tenir CAT, mémentos de garde, calculateurs de scores, normes biologiques).
3. La **sécurité thérapeutique & Vidal Algérie** (nomenclature nationale des médicaments, analyse d'ordonnances assistée par IA, alertes de contre-indications terrain).
4. L'**espace profil & suivi d'entraînement en temps réel** (validation journalière des révisions, objectifs quotidiens, habit loop hebdomadaire, synchronisation cloud sécurisée).

---

## 🚀 Fonctionnalités Majeures de Medsina

### 1. 👤 Espace Profil Médical Moderne (Design Bento 2026/2027)
- **Identité Médicale Complète** :
  - Nom & prénom, rôle médical (*Candidat Résidanat, Externe 1e-6e année, Interne des Hôpitaux, Résident, Généraliste, Spécialiste*).
  - Faculté de rattachement (*Blida, Alger, Constantine, Oran, etc.*), Wilaya de résidence (1 à 58), téléphone et session cible (*ex: Résidanat 2027*).
  - Bio et devise médicale de motivation personnalisée.
- **Sélection de Photo de Profil & Avatars Médicaux** :
  - **Importation de Photo** : sélection d'image depuis la galerie ou les fichiers avec upload Cloud Supabase Storage et aperçu local instantané.
  - **Avatars Médicaux Préréglés** : 8 avatars vectoriels soignés aux couleurs médicales (*Praticien Hospitalier, Clinicien Généraliste, Résident Élite, Chirurgien / Urgences, Externe, Pédiatrie, Cardiologie, Neuro*).
- **Statut d'Abonnement & Licence VIP** :
  - Visualisation du badge de formule (*All-Access VIP, Résident Élite, Clinique Pro, Étudiant*).
  - Compteur de jours restants avec activation instantanée de clé de licence (*ex: `MEDSINA-2027-VIP`*).

---

### 2. 📊 Activité, Progrès & Validation Journalière (« Accomplir le Jour »)
- **🌟 Validation Interactive de la Journée d'Étude** :
  - Bouton interactif pour **valider son jour de révision** en un clic.
  - Attribution automatique de **+50 XP** au compte de fidélité.
  - Incrémentation dynamique de la **série de jours consécutifs (Streak 🔥)**.
  - Badge de célébration vert émeraude avec option de modification.
- **📅 Tracker Visuel d'Assiduité Hebdomadaire** :
  - Calendrier visuel des 7 jours de la semaine (`L M M J V S D`) avec coches vertes pour les jours accomplis.
  - Calcul en direct du pourcentage d'assiduité hebdomadaire.
- **📈 Compteurs Réels de Progrès** :
  - **QCMs Réalisés** : décompte automatique de tous les QCMs résolus dans l'application avec badge d'activité journalier.
  - **Cours & Livrets Accomplis** : compteur des modules maîtrisés avec consultation de la **liste détaillée des cours validés**.
  - **Objectifs Quotidiens Personnalisables** : jauges de progression vers l'objectif journalier (ex: 25 QCMs / 1 cours par jour).
- **➕ Enregistrement de Révisions Externes** :
  - Dialogue permettant d'enregistrer des QCMs ou cours travaillés hors application (sur polycopiés de fac, en stage de garde ou à la bibliothèque).

---

### 3. 📖 Catalogue Spécifique des Livrets All-in-One (47 Modules)
- **Livrets de Révision Haute Densité** :
  - 47 livrets complets téléchargeables et consultables hors-ligne avec validation de conformité `%PDF`.
  - Synthèses High-Yield condensées regroupant les notions clés, pièges d'examen et schémas cliniques.
  - QCMs d'entraînement intégrés directement à la fin de chaque chapitre.
  - Cache hors-ligne isolé pour consultation instantanée sans connexion Internet.

---

### 4. 🏆 Témoignages & Conseils Concours Résidanat (Base Cloud Supabase)
- **Retours d'Expérience Authentiques** :
  - Témoignages détaillés de majors de promotion et de résidents (*Dr. Bentegri, Dr. Djellata, etc.*).
  - Conseils méthodologiques : organisation des couches de révision, gestion du stress, choix des sources par module, gestion du temps le jour J.
- **Architecture Cloud Zéro-Rebuild** :
  - Données hébergées sur Supabase Cloud (`public.temoignages_conseils`) permettant l'ajout continu de nouveaux témoignages sans besoin de mettre à jour l'application.
  - Indexation automatique dans **Medsina Omnisearch (`Ctrl+K`)** avec consultation PDF ou vue modale interactive.

---

### 5. 🎯 Moteur QCM « Ultra-Résidanat » & Examens Blancs
- **Plus de 19 000 QCMs & Cas Cliniques** :
  - Questions classées par spécialité, module et cours officiel de Blida / Alger.
- **Modes d'Entraînement Avancés** :
  - **Mode Révision Immédiate** : explications complètes, rappels de cours et justifications après chaque question.
  - **Mode Examen Blanc Chronométré** : simulation réelle de concours (15 à 120 minutes) avec barèmes configurables : **⚖️ Tout ou Rien** ou **📊 Notation Partielle**.
- **Filtres Intelligents** :
  - *Jamais consultées* • *Mes erreurs à retravailler* • *Mes favoris* • *Questions avec notes personnelles* • *Haute tombabilité d'examen*.
- **Indicateurs Anti-Pièges & Statistiques** :
  - Alerte automatique sur les questions négatives (*« Vigilance Piège : cherchant la proposition FAUSSE / SAUF UNE »*).
  - Badge de tombabilité indiquant les années où la question est tombée aux épreuves officielles.
  - Statistiques de choix par proposition (% A, B, C, D, E) issues de la communauté.

---

### 6. 🧠 Répétition Espacée FSRS v4.5 & Flashcards Médicales
- Algorithme de pointe **FSRS (Free Spaced Repetition Scheduler)** calculant la **Stabilité ($S$)**, la **Difficulté ($D$)** et la **Rétention mémorielle estimée ($R$)**.
- **Conversion en 1 Clic** : transformez n'importe quel QCM manqué ou piège d'annale en carte Recto/Verso FSRS.
- Évaluation intuitive en 4 niveaux (*À revoir, Difficile, Bien, Facile*) avec prévisualisation des prochains intervalles de révision.

---

### 7. 📅 Study Planner Matriciel (3 Couches)
- Suivi rigoureux de l'avancement par module :
  - `☑️ Couche 1 : Lecture & Compréhension globale`
  - `☑️ Couche 2 : Fiches de Synthèse & Mémorisation active`
  - `☑️ Couche 3 : Révision Finale, Annales & Cas Cliniques`
- **Compte à Rebours & Simulateur J-X** : indique le rythme quotidien cible (nombre de cours par jour) jusqu'à la date du concours.
- **Priorités du Jour par IA** : suggestion automatique des 3 cours les plus rentables à travailler en fonction de leur coefficient d'examen.

---

### 8. 🚨 Pratique Clinique, Urgences & Mémentos de Garde
- **Conduites à Tenir d'Urgence (CAT)** :
  - Protocoles standardisés pour les urgences vitales (Arrêt cardiaque, Choc anaphylactique, SCA, AVC, Détresse respiratoire, etc.).
- **Mémento de Garde Hospitalière** :
  - Guide pratique de poche pour l'interne et le résident de garde (prescriptions d'urgence, gestes techniques, posologies pédiatriques).
- **Normes Biologiques & Calculateurs Médicaux** :
  - Normes sanguines et urinaires de référence.
  - Calculateurs automatisés : Glasgow, Wells, Cockcroft-Gault, IMC, Surface corporelle, DFG, etc.

---

### 9. 💊 Sécurité Thérapeutique & Vidal Algérie
- **Nomenclature Nationale Algérienne** :
  - Base de données exhaustive des médicaments commercialisés en Algérie (DCI, noms commerciaux, formes, dosages).
- **Analyse d'Ordonnance Intelligente** :
  - Détection automatique des interactions médicamenteuses potentielles.
  - Alertes de contre-indications terrain (Grossesse, Allaitement, Insuffisance rénale, Insuffisance hépatique).

---

### 10. 🔍 Medsina Omnisearch (`Ctrl+K` / `⌘K`)
- Moteur de recherche transversale ultra-rapide indexant simultanément :
  - Les cours officiels et fiches de synthèse,
  - La banque de QCMs et annales,
  - Les protocoles de CAT clinique et mémentos,
  - Le Vidal des médicaments algériens,
  - Les témoignages et conseils de résidanat.

---

### 11. 🔄 Mises à Jour Automatiques Over-The-Air (OTA)
- Détection automatique des nouvelles versions publiées sur GitHub Releases.
- Téléchargement et installation transparents directement depuis l'application sans manipulation complexe.

---

### 12. 🤝 Fidélité & Programme de Parrainage
- **Système de Rangs Médicaux** : progression au fil des révisions :
  - *Externe Studieux* ➔ *Interne Assidu* ➔ *Résident Major* ➔ *Chef de Clinique Élite* ➔ *Légende Médicale*.
- **Parrainage Confraternel** : partagez votre code de parrainage et bénéficiez de **+7 jours d'accès All-Access VIP offerts** pour chaque confrère parrainé.

---

## 🎨 Conception Graphique & Ergonomie

L'interface de Medsina adopte le design **Bento / Pinterest UI 2026/2027** :
- **Dock Flottant Mobile** : navigation par pilule dynamique ergonomique à une main.
- **Sidebar Bento Desktop** : organisation modulaire avec cartes d'identité, raccourcis et statut de synchronisation.
- **Mode Sombre & Mode Clair** : thèmes contrastés étudiés pour réduire la fatigue oculaire lors des longues gardes de nuit ou séances de bibliothèque.

---

## 💻 Téléchargement & Accès Multiplateforme

| Plateforme | Format | Lien d'accès |
| :--- | :--- | :--- |
| **Android** | APK / AAB | [Télécharger Medsina Android](https://medsina.medevsync.com/download/medsina.apk) |
| **Windows Desktop** | Setup x64 (Hors-Ligne) | [Télécharger Medsina Windows](https://medsina.medevsync.com/download/medsina-setup.exe) |
| **Web SaaS** | Navigateurs modernes | [Ouvrir Medsina Web](https://medsina.medevsync.com) |
| **Canal Telegram Officiel** | Annonces & Échanges | [Rejoindre @medsina_officiel](https://t.me/medsina_officiel) |

---

## 🛠️ Stack Technique

- **Framework** : Flutter 3 (Dart) avec compilation multiplateforme (Android, Windows Desktop, Web).
- **Architecture** : BLoC Pattern (`flutter_bloc`), Clean Architecture, Equatable.
- **Base de Données & Cloud** : Supabase (PostgreSQL, Auth, Storage, Edge Functions, Row Level Security).
- **Cache & Persistance Locale** : `SharedPreferences`, `Syncfusion Flutter PDF`, SQLite/Memory Storage.
- **Algorithmes** : Free Spaced Repetition Scheduler (FSRS v4.5), Omnisearch In-Memory Indexer.
- **CI/CD & DevOps** : GitHub Actions (Pipelines automatiques de release Android, Windows, Web et scanners Telegram/GDrive).

---

<p align="center">
  <em>Conçu avec passion par l'équipe <strong>MedevSync</strong> pour les futurs spécialistes d'Algérie 🇩🇿</em>
</p>
