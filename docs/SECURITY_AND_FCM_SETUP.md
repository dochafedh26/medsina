# Sécurisation Keystore Android & Configuration FCM

## 1. Secrets GitHub Actions requis pour la signature Android

Les fichiers `upload-keystore.jks` ont été retirés du suivi Git et ne doivent jamais être commités.
Ajoutez ces 4 secrets dans **GitHub → Settings → Secrets and variables → Actions** :

| Secret | Description |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | Contenu encodé en Base64 de `upload-keystore.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | Mot de passe du keystore (`storePassword`) |
| `ANDROID_KEY_PASSWORD` | Mot de passe de l'alias (`keyPassword`) |
| `ANDROID_KEY_ALIAS` | Nom de l'alias (ex: `upload`) |

### Générer `ANDROID_KEYSTORE_BASE64` sous Windows (PowerShell)
```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("android\app\upload-keystore.jks")) | Set-Clipboard
```

## 2. Activer Firebase Cloud Messaging (FCM)

Le service `FcmService` (`lib/features/notifications/services/fcm_service.dart`) s'initialise de manière sécurisée sans bloquer l'application si Firebase n'est pas encore configuré.

Pour activer la réception réelle des notifications push :
1. Créez un projet sur [Firebase Console](https://console.firebase.google.com/) avec le package Android `com.medsina.medsina`.
2. Téléchargez `google-services.json` et placez-le dans `android/app/google-services.json` (ou injectez-le via secret CI `GOOGLE_SERVICES_JSON_BASE64`).
3. Appliquez la migration Supabase `supabase/migrations/20261112120000_fcm_and_clinical_atlas.sql` pour créer la table `fcm_tokens` et `clinical_atlas_cases`.
