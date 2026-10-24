/**
 * =============================================================================
 * MEDSINA PLATFORM : GOOGLE DRIVE ARCHIVER & EMAIL DISPATCHER (APPS SCRIPT)
 * =============================================================================
 * Ce script s'exécute gratuitement sur Google Apps Script (script.google.com).
 * Il prend en charge :
 *   1. L'archivage automatique des reçus (Validés à +30j et Rejetés immédiats)
 *      dans des dossiers Google Drive dédiés pour libérer le Storage Supabase.
 *   2. L'envoi direct d'emails HTML officiels Medsina aux candidats :
 *      - Confirmation d'abonnement activé
 *      - Notification de reçu rejeté avec motif et avertissement (1/3 ou 2/3)
 *      - Notification de suspension de compte (3ème rejet)
 *   3. L'envoi d'alertes instantanées à l'administrateur (doc.hafedh26@gmail.com) :
 *      - Nouveau reçu soumis en attente de vérification
 *      - Alerte utilisateur banni
 * 
 * INSTRUCTIONS DE DÉPLOIEMENT EN 2 MINUTES :
 * 1. Ouvrez https://script.google.com avec votre compte Google (doc.hafedh26@gmail.com).
 * 2. Cliquez sur "Nouveau projet", collez l'intégralité de ce code et enregistrez (Ctrl+S).
 * 3. Cliquez sur "Déployer" > "Nouveau déploiement" > Type : "Application Web".
 * 4. Définissez :
 *    - Exécuter en tant que : "Moi (votre adresse email)"
 *    - Qui a accès : "Tout le monde" (Anyone)
 * 5. Cliquez sur "Déployer", autorisez les accès Google Drive & Gmail, puis copiez l'URL Webhook.
 * 6. Collez l'URL dans la console Admin Medsina (Onglet Système & Stockage).
 * =============================================================================
 */

// Clé secrète de signature pour sécuriser votre webhook
var WEBHOOK_SECRET = "MSN27_STORAGE_SECURE_TOKEN_2026";

// Dossiers Google Drive
var FOLDER_NAME_VALIDATED = "Medsina - Reçus Validés (Archives 30j)";
var FOLDER_NAME_REJECTED = "Medsina - Reçus Rejetés (Fraude & Non-conforme)";
var ADMIN_EMAIL = "doc.hafedh26@gmail.com";

function doPost(e) {
  try {
    if (!e || !e.postData || !e.postData.contents) {
      return jsonResponse({ success: false, error: "No post data received" }, 400);
    }

    var payload = JSON.parse(e.postData.contents);

    // Vérification du token de sécurité
    if (payload.secret !== WEBHOOK_SECRET) {
      return jsonResponse({ success: false, error: "Unauthorized: Invalid secret token" }, 401);
    }

    var action = payload.action;

    // -------------------------------------------------------------------------
    // ACTION 1 : ARCHIVER UN REÇU DANS GOOGLE DRIVE
    // -------------------------------------------------------------------------
    if (action === "archive_receipt") {
      var folderType = payload.folder_type; // 'validated' ou 'rejected'
      var targetFolderName = folderType === "rejected" ? FOLDER_NAME_REJECTED : FOLDER_NAME_VALIDATED;
      var targetFolder = getOrCreateFolder(targetFolderName);

      var fileName = payload.file_name || "recu_paiement.pdf";
      var mimeType = payload.mime_type || (fileName.toLowerCase().indexOf(".pdf") !== -1 ? "application/pdf" : "image/jpeg");
      var fileBytes;

      if (payload.file_base64) {
        fileBytes = Utilities.base64Decode(payload.file_base64);
      } else if (payload.file_url) {
        var fetchResp = UrlFetchApp.fetch(payload.file_url);
        fileBytes = fetchResp.getBlob().getBytes();
      } else {
        return jsonResponse({ success: false, error: "No file content provided" }, 400);
      }

      var blob = Utilities.newBlob(fileBytes, mimeType, fileName);
      var driveFile = targetFolder.createFile(blob);
      
      // Rendre le fichier accessible en lecture via lien pour l'admin
      driveFile.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.VIEW);
      var fileUrl = driveFile.getUrl();

      return jsonResponse({
        success: true,
        file_id: driveFile.getId(),
        file_url: fileUrl,
        folder_name: targetFolderName
      });
    }

    // -------------------------------------------------------------------------
    // ACTION 2 : ENVOYER UN EMAIL OFFICIEL
    // -------------------------------------------------------------------------
    if (action === "send_email") {
      var emailType = payload.email_type; // 'approved', 'rejected', 'banned', 'admin_new_payment'
      var recipient = payload.recipient;
      var userName = payload.user_name || "Docteur";

      if (emailType === "welcome") {
        sendWelcomeEmail(recipient, userName, payload);
      } else if (emailType === "admin_new_subscriber") {
        sendAdminNewSubscriberAlert(payload);
      } else if (emailType === "approved") {
        sendApprovedEmail(recipient, userName, payload);
      } else if (emailType === "rejected") {
        sendRejectedEmail(recipient, userName, payload);
      } else if (emailType === "banned") {
        sendBannedEmail(recipient, userName, payload);
      } else if (emailType === "admin_new_payment") {
        sendAdminNewPaymentAlert(payload);
      }

      return jsonResponse({ success: true, message: "Email sent successfully" });
    }

    return jsonResponse({ success: false, error: "Unknown action" }, 400);

  } catch (err) {
    return jsonResponse({ success: false, error: err.toString() }, 500);
  }
}

// -----------------------------------------------------------------------------
// HELPERS : DOSSIERS DRIVE
// -----------------------------------------------------------------------------
function getOrCreateFolder(folderName) {
  var folders = DriveApp.getFoldersByName(folderName);
  if (folders.hasNext()) {
    return folders.next();
  }
  return DriveApp.createFolder(folderName);
}

function jsonResponse(data, code) {
  return ContentService.createTextOutput(JSON.stringify(data))
    .setMimeType(ContentService.MimeType.JSON);
}

// -----------------------------------------------------------------------------
// TEMPLATES D'EMAILS MEDSINA (HTML RESPONSIVE & STYLISÉS)
// -----------------------------------------------------------------------------

function sendApprovedEmail(toEmail, userName, data) {
  var tierName = data.tier_name || "All-Access VIP";
  var duration = data.duration_days ? (data.duration_days + " jours") : "1 an";
  var expiryDate = data.expiry_date || "Octobre 2027";
  var amount = data.amount || "6 500";

  var subject = "✅ Votre abonnement Medsina a été activé avec succès !";
  var htmlBody = "" +
    "<div style='font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; border: 1px solid #E2E8F0; border-radius: 12px; overflow: hidden;'>" +
    "  <div style='background-color: #0F766E; padding: 24px; text-align: center; color: white;'>" +
    "    <h1 style='margin: 0; font-size: 24px;'>Medsina Algérie</h1>" +
    "    <p style='margin: 6px 0 0 0; font-size: 14px; opacity: 0.9;'>Plateforme SaaS Médicale • Résidanat 2027 & Pratique Clinique</p>" +
    "  </div>" +
    "  <div style='padding: 24px; color: #1E293B; line-height: 1.6;'>" +
    "    <h2 style='color: #0F766E; margin-top: 0;'>Félicitations Docteur " + userName + " ! 🎉</h2>" +
    "    <p>Nous avons bien reçu et validé votre preuve de paiement. Votre formule a été immédiatement activée sur votre compte :</p>" +
    "    <div style='background-color: #F0FDF4; border-left: 4px solid #16A34A; padding: 14px; margin: 18px 0; border-radius: 4px;'>" +
    "      <p style='margin: 4px 0;'><strong>Formule :</strong> " + tierName + "</p>" +
    "      <p style='margin: 4px 0;'><strong>Durée de validité :</strong> " + duration + "</p>" +
    "      <p style='margin: 4px 0;'><strong>Date d'échéance :</strong> " + expiryDate + "</p>" +
    "      <p style='margin: 4px 0;'><strong>Montant réglé :</strong> " + amount + " DZD</p>" +
    "    </div>" +
    "    <p>Vous avez désormais un accès illimité à l'intégralité des modules, banques de QCM corrigés, CAT d'urgence et cours officiels.</p>" +
    "    <div style='text-align: center; margin: 26px 0;'>" +
    "      <a href='https://medsina.app' style='background-color: #0F766E; color: white; padding: 12px 24px; text-decoration: none; border-radius: 8px; font-weight: bold; font-size: 15px;'>Ouvrir Medsina ➔</a>" +
    "    </div>" +
    "    <p style='font-size: 12px; color: #64748B;'>Cet email fait office de confirmation officielle de votre abonnement. Pour toute question, répondez directement à cet email.</p>" +
    "  </div>" +
    "  <div style='background-color: #F8FAFC; padding: 14px; text-align: center; font-size: 11px; color: #94A3B8; border-top: 1px solid #E2E8F0;'>" +
    "    © 2026-2027 Medsina Algérie • Faculté de Médecine de Blida • Tous droits réservés." +
    "  </div>" +
    "</div>";

  MailApp.sendEmail({
    to: toEmail,
    subject: subject,
    htmlBody: htmlBody,
    name: "Medsina Administration"
  });
}

function sendRejectedEmail(toEmail, userName, data) {
  var reason = data.reason || "Reçu illisible ou montant non correspondant.";
  var strikeCount = data.rejected_count || 1;
  var strikesRemaining = 3 - strikeCount;

  var subject = "⚠️ Information importante : Preuve de paiement Medsina refusée (Avertissement " + strikeCount + "/3)";
  var htmlBody = "" +
    "<div style='font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; border: 1px solid #E2E8F0; border-radius: 12px; overflow: hidden;'>" +
    "  <div style='background-color: #DC2626; padding: 24px; text-align: center; color: white;'>" +
    "    <h1 style='margin: 0; font-size: 24px;'>Medsina Algérie</h1>" +
    "    <p style='margin: 6px 0 0 0; font-size: 14px; opacity: 0.9;'>Service Administratif & Vérification des Reçus</p>" +
    "  </div>" +
    "  <div style='padding: 24px; color: #1E293B; line-height: 1.6;'>" +
    "    <h2 style='color: #DC2626; margin-top: 0;'>Bonjour Docteur " + userName + ",</h2>" +
    "    <p>Après vérification par notre service comptabilité, votre reçu de paiement n'a pas pu être validé pour le motif suivant :</p>" +
    "    <div style='background-color: #FEF2F2; border-left: 4px solid #DC2626; padding: 14px; margin: 18px 0; border-radius: 4px;'>" +
    "      <p style='margin: 0; color: #991B1B;'><strong>Motif du rejet :</strong> " + reason + "</p>" +
    "    </div>" +
    "    <div style='background-color: #FFFBEB; border: 1px solid #FDE68A; padding: 12px; border-radius: 6px; margin: 16px 0;'>" +
    "      <p style='margin: 0; font-size: 13px; color: #92400E;'><strong>Rappel de Sécurité Anti-Fraude :</strong> Vous avez reçu <strong>" + strikeCount + " sur 3</strong> avertissements. Conformément à nos règles de sécurité, à 3 rejets non justifiés, le compte est automatiquement suspendu.</p>" +
    "    </div>" +
    "    <p>Veuillez vous reconnecter sur l'application Medsina et soumettre une nouvelle photo nette ou PDF officiel de votre virement BaridiMob ou bordereau CCP.</p>" +
    "    <div style='text-align: center; margin: 24px 0;'>" +
    "      <a href='https://medsina.app' style='background-color: #DC2626; color: white; padding: 12px 24px; text-decoration: none; border-radius: 8px; font-weight: bold; font-size: 14px;'>Régulariser ma Preuve sur Medsina ➔</a>" +
    "    </div>" +
    "  </div>" +
    "  <div style='background-color: #F8FAFC; padding: 14px; text-align: center; font-size: 11px; color: #94A3B8; border-top: 1px solid #E2E8F0;'>" +
    "    © 2026-2027 Medsina Algérie • Service Vérification" +
    "  </div>" +
    "</div>";

  MailApp.sendEmail({
    to: toEmail,
    subject: subject,
    htmlBody: htmlBody,
    name: "Medsina Vérification"
  });
}

function sendBannedEmail(toEmail, userName, data) {
  var reason = data.reason || "3 preuves de paiement consécutives non conformes.";

  var subject = "⛔ Notification officielle : Suspension de votre compte Medsina";
  var htmlBody = "" +
    "<div style='font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; border: 1px solid #E2E8F0; border-radius: 12px; overflow: hidden;'>" +
    "  <div style='background-color: #1E293B; padding: 24px; text-align: center; color: white;'>" +
    "    <h1 style='margin: 0; font-size: 24px;'>Medsina Algérie</h1>" +
    "    <p style='margin: 6px 0 0 0; font-size: 14px; color: #EF4444;'>Notification de Sécurité • Compte Suspendu</p>" +
    "  </div>" +
    "  <div style='padding: 24px; color: #1E293B; line-height: 1.6;'>" +
    "    <h2 style='color: #1E293B; margin-top: 0;'>Bonjour Docteur " + userName + ",</h2>" +
    "    <p>Nous vous informons que votre compte Medsina a été <strong>automatiquement suspendu</strong> conformément à la politique anti-fraude de la plateforme :</p>" +
    "    <div style='background-color: #FEF2F2; border-left: 4px solid #EF4444; padding: 14px; margin: 18px 0; border-radius: 4px;'>" +
    "      <p style='margin: 0; color: #991B1B;'><strong>Cause :</strong> Atteinte du seuil de 3 preuves de paiement rejetées pour non-conformité (" + reason + ").</p>" +
    "    </div>" +
    "    <p>L'accès aux modules et aux services a été restreint. Si vous estimez qu'il s'agit d'une erreur ou si vous possédez un justificatif postal original, veuillez contacter directement l'administrateur en répondant à ce message avec vos pièces justificatives.</p>" +
    "  </div>" +
    "  <div style='background-color: #F8FAFC; padding: 14px; text-align: center; font-size: 11px; color: #94A3B8; border-top: 1px solid #E2E8F0;'>" +
    "    © 2026-2027 Medsina Algérie • Sécurité & Conformité" +
    "  </div>" +
    "</div>";

  MailApp.sendEmail({
    to: toEmail,
    subject: subject,
    htmlBody: htmlBody,
    name: "Medsina Sécurité"
  });
}

function sendAdminNewPaymentAlert(data) {
  var candidateName = data.user_name || "Candidat";
  var candidateEmail = data.user_email || "N/A";
  var tier = data.tier || "All-Access";
  var amount = data.amount || "0";
  var method = data.payment_method || "BaridiMob";
  var ref = data.receipt_reference || "N/A";

  var subject = "🔔 [ADMIN] Nouveau paiement en attente : " + candidateName + " (" + amount + " DZD)";
  var htmlBody = "" +
    "<div style='font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; border: 1px solid #E2E8F0; border-radius: 12px; padding: 20px;'>" +
    "  <h2 style='color: #0F766E; margin-top: 0;'>Nouveau Règlement à Valider</h2>" +
    "  <p>Un candidat a soumis un reçu de paiement sur Medsina :</p>" +
    "  <ul>" +
    "    <li><strong>Candidat :</strong> " + candidateName + " (" + candidateEmail + ")</li>" +
    "    <li><strong>Formule :</strong> " + tier + "</li>" +
    "    <li><strong>Montant :</strong> " + amount + " DZD</li>" +
    "    <li><strong>Moyen :</strong> " + method + "</li>" +
    "    <li><strong>Référence :</strong> " + ref + "</li>" +
    "  </ul>" +
    "  <p>Veuillez ouvrir votre <strong>Console Administrateur Medsina</strong> pour inspecter le reçu et activer l'abonnement.</p>" +
    "</div>";

  MailApp.sendEmail({
    to: ADMIN_EMAIL,
    subject: subject,
    htmlBody: htmlBody,
    name: "Medsina Bot"
  });
}

function sendWelcomeEmail(toEmail, userName, data) {
  var role = data.medical_role || "Médecin";
  var faculty = data.faculty || "Faculté de Médecine de Blida";
  var year = data.study_year ? " (" + data.study_year + "e Année)" : "";

  var subject = "🎉 Bienvenue sur Medsina, Dr. " + userName + " ! Votre accès est activé";
  var htmlBody = "" +
    "<div style='font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; border: 1px solid #E2E8F0; border-radius: 12px; overflow: hidden;'>" +
    "  <div style='background: linear-gradient(135deg, #0F766E 0%, #0D9488 100%); padding: 28px; text-align: center; color: white;'>" +
    "    <h1 style='margin: 0; font-size: 26px; font-weight: 800;'>Medsina</h1>" +
    "    <p style='margin: 6px 0 0 0; font-size: 14px; opacity: 0.95;'>Plateforme Médicale Globale & Résidanat 2027</p>" +
    "  </div>" +
    "  <div style='padding: 26px; color: #1E293B; line-height: 1.6;'>" +
    "    <h2 style='color: #0F766E; margin-top: 0;'>Bienvenue, Dr. " + userName + " !</h2>" +
    "    <p>Nous sommes ravis de vous compter parmi les membres de la communauté <strong>Medsina</strong>.</p>" +
    "    <div style='background-color: #F0FDF4; border-left: 4px solid #16A34A; padding: 14px 18px; margin: 18px 0; border-radius: 6px;'>" +
    "      <p style='margin: 0 0 6px 0; font-weight: bold; color: #166534;'>⚡ Pass Découverte Gratuit (14 Jours Offerts)</p>" +
    "      <p style='margin: 0; font-size: 13px; color: #15803D;'>Votre période d'essai gratuit est immédiatement active avec accès complet aux modules et simulateurs.</p>" +
    "    </div>" +
    "    <h3 style='color: #334155; font-size: 15px; margin-bottom: 8px;'>Ce qui vous attend sur Medsina :</h3>" +
    "    <ul style='padding-left: 20px; font-size: 13.5px; color: #475569;'>" +
    "      <li><strong>47 Modules de Concours :</strong> Cours officiels conformes au programme national & Blida 2027.</li>" +
    "      <li><strong>Banques de QCM Corrigés :</strong> Questions classées par item avec pièges fréquents.</li>" +
    "      <li><strong>Conduites à Tenir d'Urgence (CAT) :</strong> Protocoles SFMU & UMC validés.</li>" +
    "      <li><strong>Mode Hors-Ligne Total :</strong> Continuez vos révisions même sans connexion internet.</li>" +
    "    </ul>" +
    "    <div style='text-align: center; margin: 26px 0 10px 0;'>" +
    "      <a href='https://medsina.medevsync.com' style='background-color: #0F766E; color: white; padding: 12px 24px; text-decoration: none; border-radius: 8px; font-weight: bold; font-size: 14px; display: inline-block; margin-bottom: 8px;'>Accéder à la Plateforme Web ➔</a>" +
    "      <br/>" +
    "      <a href='https://medsina.medevsync.com/download/medsina.apk' style='color: #0F766E; font-size: 12px; font-weight: 600; text-decoration: underline; margin-right: 12px;'>📱 Télécharger l'APK Android</a>" +
    "      <a href='https://medsina.medevsync.com/download/medsina-setup.exe' style='color: #0284C7; font-size: 12px; font-weight: 600; text-decoration: underline;'>💻 Télécharger l'App Windows PC</a>" +
    "    </div>" +
    "  </div>" +
    "  <div style='background-color: #F8FAFC; padding: 14px; text-align: center; font-size: 11px; color: #94A3B8; border-top: 1px solid #E2E8F0;'>" +
    "    © 2026-2027 Medsina Algérie • Dédié à la formation médicale continue" +
    "  </div>" +
    "</div>";

  MailApp.sendEmail({
    to: toEmail,
    subject: subject,
    htmlBody: htmlBody,
    name: "Medsina Équipe"
  });
}

function sendAdminNewSubscriberAlert(data) {
  var userName = data.user_name || "Nouveau Médecin";
  var userEmail = data.user_email || "N/A";
  var role = data.medical_role || "Médecin";
  var faculty = data.faculty || "Faculté de Médecine";
  var year = data.study_year ? " (" + data.study_year + "e Année)" : "";
  var dateStr = data.registered_at || "Aujourd'hui";

  var subject = "👤 [ADMIN] Nouvelle Inscription Medsina : " + userName + " (" + role + ")";
  var htmlBody = "" +
    "<div style='font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; border: 1px solid #E2E8F0; border-radius: 12px; padding: 22px;'>" +
    "  <div style='display: flex; align-items: center; margin-bottom: 16px;'>" +
    "    <h2 style='color: #0F766E; margin: 0;'>👤 Nouveau Membre Inscrit</h2>" +
    "  </div>" +
    "  <p>Un nouveau médecin vient de créer son compte sur la plateforme Medsina :</p>" +
    "  <table style='width: 100%; border-collapse: collapse; margin: 16px 0; font-size: 13.5px;'>" +
    "    <tr style='border-bottom: 1px solid #E2E8F0;'><td style='padding: 8px 0; color: #64748B;'>Nom :</td><td style='padding: 8px 0; font-weight: bold; color: #1E293B;'>Dr. " + userName + "</td></tr>" +
    "    <tr style='border-bottom: 1px solid #E2E8F0;'><td style='padding: 8px 0; color: #64748B;'>Email :</td><td style='padding: 8px 0; font-weight: bold; color: #0284C7;'>" + userEmail + "</td></tr>" +
    "    <tr style='border-bottom: 1px solid #E2E8F0;'><td style='padding: 8px 0; color: #64748B;'>Statut Médical :</td><td style='padding: 8px 0; font-weight: bold; color: #1E293B;'>" + role + year + "</td></tr>" +
    "    <tr style='border-bottom: 1px solid #E2E8F0;'><td style='padding: 8px 0; color: #64748B;'>Faculté :</td><td style='padding: 8px 0; color: #1E293B;'>" + faculty + "</td></tr>" +
    "    <tr style='border-bottom: 1px solid #E2E8F0;'><td style='padding: 8px 0; color: #64748B;'>Formule :</td><td style='padding: 8px 0; color: #16A34A; font-weight: bold;'>Essai Gratuit Actif (14j)</td></tr>" +
    "    <tr><td style='padding: 8px 0; color: #64748B;'>Date d'inscription :</td><td style='padding: 8px 0; color: #64748B;'>" + dateStr + "</td></tr>" +
    "  </table>" +
    "  <div style='margin-top: 20px; text-align: center;'>" +
    "    <a href='https://medsina.medevsync.com/#/admin' style='background-color: #0F766E; color: white; padding: 10px 20px; text-decoration: none; border-radius: 8px; font-weight: bold; font-size: 13px; display: inline-block;'>Ouvrir la Console Admin Medsina ➔</a>" +
    "  </div>" +
    "</div>";

  MailApp.sendEmail({
    to: ADMIN_EMAIL,
    subject: subject,
    htmlBody: htmlBody,
    name: "Medsina Bot"
  });
}

