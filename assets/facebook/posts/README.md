# Pack Publications Vidéo Facebook — 3 Pages Officielles

Ce dossier regroupe le matériel prêt à l'emploi pour publier le spot vidéo promotionnel de 58 secondes sur les 3 pages Facebook officielles.

## 📹 Fichier Vidéo Source
- Emplacement : [`../medsina_spot_deux_etudiants_1080p.mp4`](../medsina_spot_deux_etudiants_1080p.mp4)
- Résolution : Full HD 1080p (1920x1080)
- Durée : 58 secondes
- Audio : Voix & musique stéréo

---

## 📄 Les 3 Publications par Page

### 1. Page : Résidanat Blida 2027 (ID: 1405719695953624)
- **Fichier** : [`post_residanat_blida.txt`](post_residanat_blida.txt)
- **Angle** : Concours & Pièges d'Examen (éliminer les erreurs classiques, annales, méthodologie).

### 2. Page : Medsina (ID: 1449308354921826)
- **Fichier** : [`post_medsina.txt`](post_medsina.txt)
- **Angle** : Storytelling & Découverte Produit (la nuit de 23h47, les 5 fonctionnalités de la plateforme).

### 3. Page : MedevSync (ID: 1329939320211198)
- **Fichier** : [`post_medevsync.txt`](post_medevsync.txt)
- **Angle** : Choc Méthode & Innovation HealthTech (Étudiant A vs Étudiant B, impact sur l'apprentissage médical).

---

## 🚀 Utilisation Manuelle (Meta Business Suite)
1. Ouvrez [Meta Business Suite](https://business.facebook.com/).
2. Sélectionnez la page cible.
3. Cliquez sur **Créer une publication** > **Ajouter une vidéo**.
4. Sélectionnez `medsina_spot_deux_etudiants_1080p.mp4`.
5. Copiez-collez le texte du fichier `.txt` correspondant dans le champ texte.
6. Cliquez sur **Publier**.

---

## 🤖 Publication Automatisée (Script Python)
Pour publier directement via l'API Graph :
```bash
# Tester sans publier (simulation)
python medsina/scripts/automation/publish_multi_page_video.py --dry-run

# Publier sur une page spécifique
python medsina/scripts/automation/publish_multi_page_video.py --page blida --publish
python medsina/scripts/automation/publish_multi_page_video.py --page medevsync --publish
python medsina/scripts/automation/publish_multi_page_video.py --page medsina --token <VOTRE_TOKEN_PAGE_MEDSINA> --publish

# Publier sur toutes les pages
python medsina/scripts/automation/publish_multi_page_video.py --page all --publish
```
