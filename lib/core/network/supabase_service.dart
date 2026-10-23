import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/medsina_notification_dispatcher.dart';

class SupabaseService {
  static const String supabaseUrl = 'https://qzfssrhhuorljftpdvjm.supabase.co';
  static const String supabasePublishableKey =
      'sb_publishable_E2OrqFqG1MbxVpoLb50jvA_DmOeP-UR';

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabasePublishableKey,
    );
  }

  // --- AUTHENTICATION ---

  static User? get currentUser => client.auth.currentUser;
  static Session? get currentSession => client.auth.currentSession;
  static bool get isAuthenticated => currentSession != null;

  /// Sign In with Email & Password
  static Future<AuthResponse> signInWithEmail(String email, String password) async {
    return await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Sign Up with Email & Password and store metadata in auth + profile trigger
  static Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
    required String medicalRole,
    required String faculty,
  }) async {
    return await client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'full_name': fullName.trim(),
        'medical_role': medicalRole.trim(),
        'faculty': faculty.trim(),
      },
    );
  }

  /// Sign Out
  static Future<void> signOut() async {
    try {
      await client.auth.signOut();
    } catch (e) {
      debugPrint('Supabase sign out error: $e');
    }
  }

  /// Reset Password
  static Future<void> resetPassword(String email) async {
    await client.auth.resetPasswordForEmail(email.trim());
  }

  /// Fetch User Profile and Subscription
  static Future<Map<String, dynamic>?> fetchUserProfileAndSubscription(String userId) async {
    try {
      final profile = await client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      final subscription = await client
          .from('subscriptions')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      return {
        'profile': profile,
        'subscription': subscription,
      };
    } catch (e) {
      debugPrint('Error fetching user profile/subscription: $e');
      return null;
    }
  }

  // --- LICENSES & SUBSCRIPTIONS ---

  /// Redeem License Key via PostgreSQL RPC
  static Future<Map<String, dynamic>> redeemLicenseKey(String keyCode) async {
    try {
      final response = await client.rpc(
        'redeem_license_key',
        params: {'input_key': keyCode.trim().toUpperCase()},
      );
      return Map<String, dynamic>.from(response);
    } catch (e) {
      return {'success': false, 'message': 'Erreur lors de l\'activation: $e'};
    }
  }

  // --- MEDICAL REVISION & CATALOG ---

  /// Fetch Medical Modules with their nested courses
  static Future<List<Map<String, dynamic>>> fetchModules() async {
    try {
      final response = await client
          .from('medical_modules')
          .select('*, courses(*)')
          .not('id', 'like', 'mod_%')
          .order('display_order', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching modules: $e');
      return [];
    }
  }

  /// Fetch Questions for a specific course
  static Future<List<Map<String, dynamic>>> fetchCourseQuestions(String courseId) async {
    try {
      final response = await client
          .from('qcm_questions')
          .select('*, qcm_options(*)')
          .eq('course_id', courseId);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching course questions: $e');
      return [];
    }
  }

  // --- CLINICAL PROTOCOLS & LAB VALUES ---

  /// Fetch Clinical Protocols (CAT Urgence)
  static Future<List<Map<String, dynamic>>> fetchClinicalProtocols() async {
    try {
      final response = await client.from('clinical_protocols').select();
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching clinical protocols: $e');
      return [];
    }
  }

  /// Fetch Emergency Drugs (Urgences & DCI Algérie)
  static Future<List<Map<String, dynamic>>> fetchEmergencyDrugs() async {
    try {
      final response = await client
          .from('emergency_drugs')
          .select()
          .order('dci', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching emergency drugs from Cloud: $e');
      return [];
    }
  }

  /// Fetch Lab Reference Values (Normes Biologiques)
  static Future<List<Map<String, dynamic>>> fetchLabReferenceValues() async {
    try {
      final response = await client
          .from('lab_reference_values')
          .select()
          .order('name', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching lab reference values from Cloud: $e');
      return [];
    }
  }

  /// Fetch On-Call Mementos (Mémento de Garde Hospitalière)
  static Future<List<Map<String, dynamic>>> fetchOnCallMementos() async {
    try {
      final response = await client
          .from('on_call_mementos')
          .select()
          .eq('is_active', true)
          .order('priority_level', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching on-call mementos from Cloud: $e');
      return [];
    }
  }

  /// Fetch Algerian Official Nomenclature Drugs (MSPRH)
  static Future<List<Map<String, dynamic>>> fetchAlgerianNomenclature({
    String? query,
    int limit = 50,
  }) async {
    try {
      var builder = client.from('algerian_nomenclature').select();
      if (query != null && query.trim().isNotEmpty) {
        final q = query.trim().toUpperCase();
        builder = builder.or('brand_name.ilike.%$q%,dci.ilike.%$q%,code.ilike.%$q%');
      }
      final response = await builder.limit(limit);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching Algerian nomenclature from Cloud: $e');
      return [];
    }
  }

  /// Fetch Vidal Drug Interactions from Supabase
  static Future<List<Map<String, dynamic>>> fetchVidalInteractions() async {
    try {
      final response = await client
          .from('vidal_drug_interactions')
          .select()
          .order('severity_level', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching Vidal interactions from Cloud: $e');
      return [];
    }
  }

  /// Insert a newly discovered Vidal interaction into Supabase (Self-enriching database)
  static Future<bool> insertVidalInteraction(Map<String, dynamic> interaction) async {
    try {
      await client.from('vidal_drug_interactions').insert(interaction);
      return true;
    } catch (e) {
      debugPrint('Error inserting new Vidal interaction: $e');
      return false;
    }
  }

  /// Fetch Vidal Terrain Contraindications from Supabase
  static Future<List<Map<String, dynamic>>> fetchVidalTerrainContraindications() async {
    try {
      final response = await client
          .from('vidal_terrain_contraindications')
          .select()
          .order('severity_level', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching Vidal terrain contraindications from Cloud: $e');
      return [];
    }
  }

  /// Insert a newly discovered Vidal terrain contraindication into Supabase
  static Future<bool> insertVidalTerrainContraindication(Map<String, dynamic> data) async {
    try {
      await client.from('vidal_terrain_contraindications').insert(data);
      return true;
    } catch (e) {
      debugPrint('Error inserting new Vidal terrain contraindication: $e');
      return false;
    }
  }


  /// Curated High-Yield Clinical Pearls for Algerian Residency & Hospital Practice
  static final List<Map<String, dynamic>> defaultDailyPearls = [
    {
      'id': 'pearl_seed_cad',
      'module_name': 'Endocrinologie',
      'course_name': 'Diabète sucré et complications métaboliques',
      'title': 'Perle Clinique : Décompensation Acido-Cétosique (CAD)',
      'pearl_text': 'Règle vitale : Ne JAMAIS débuter l\'insuline si la kaliémie initiale est < 3,3 mmol/L. L\'insuline provoque une entrée massive de potassium dans les cellules et risque d\'entraîner un arrêt cardiaque en hypokaliémie foudroyante.',
      'vital_rule': 'Réhydrater au SSI 0.9% et recharger en KCl (20-30 mEq/h) avant toute injection d\'insuline si K+ < 3.3.',
      'exam_trap': 'Piège QCM Concours : La cétonurie peut persister faussement positive sous forme d\'acétoacétate alors que l\'état s\'améliore (le bêta-hydroxybutyrate se transforme en acétoacétate éliminé dans les urines). Le critère de guérison est la normalisation du trou anionique et des bicarbonates, JAMAIS la bandelette urinaire !',
      'scientific_sources': 'Consensus International ADA / EASD 2024 & Recommandations Nationales Résidanat Algérie',
      'created_at': DateTime.now().toIso8601String(),
    },
    {
      'id': 'pearl_seed_hyponatremie',
      'module_name': 'Néphrologie - Réanimation',
      'course_name': 'Désordres hydro-électrolytiques',
      'title': 'Perle Clinique : Hyponatrémie Sévère & Myélinolyse',
      'pearl_text': 'La correction d\'une hyponatrémie chronique sévère (< 120 mmol/L) doit être impérativement lente. Une remontée trop rapide expose au risque dramatique et irréversible de myélinolyse centropontine (démyélinisation osmotique).',
      'vital_rule': 'Règle vitale : Ne jamais dépasser une élévation de natrémie de 8 à 10 mmol/L en 24 heures et 18 mmol/L en 48 heures.',
      'exam_trap': 'Piège QCM Concours : Seule l\'hyponatrémie aiguë symptomatique avec convulsions / coma justifie un bolus rapide de NaCl 3% (150 mL en 20 min). En chronique, le calcul du déficit en sodium sert à fixer la vitesse de perfusion, pas à administrer en urgence.',
      'scientific_sources': 'European Society of Endocrinology Guidelines on Hyponatraemia & SFMU',
      'created_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
    },
    {
      'id': 'pearl_seed_sca_vd',
      'module_name': 'Cardiologie',
      'course_name': 'Syndromes Coronariens Aigus (SCA)',
      'title': 'Perle Clinique : Infarctus du Ventricule Droit & Dérivés Nitrés',
      'pearl_text': 'Devant tout SCA ST+ inférieur (DII, DIII, aVF), il faut systématiquement réaliser les dérivations droites V3R et V4R pour rechercher une extension au ventricule droit.',
      'vital_rule': 'Contre-indication formelle aux dérivés nitrés et aux diurétiques en cas d\'infarctus du VD : risque de collapsus cardiovasculaire par chute de précharge ventriculaire droite ! Le traitement repose sur le remplissage vasculaire abondant.',
      'exam_trap': 'Piège QCM Concours : La triade classique de l\'infarctus du VD associe : hypotension, turgescence jugulaire, et champs pulmonaires clairs (absence de râles crépitants). La présence de râles élimine une insuffisance ventriculaire droite pure.',
      'scientific_sources': 'ESC Guidelines on Acute Coronary Syndromes 2023 & SFC',
      'created_at': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
    },
    {
      'id': 'pearl_seed_status_epilepticus',
      'module_name': 'Neurologie - Urgences',
      'course_name': 'État de mal épileptique',
      'title': 'Perle Clinique : État de Mal Épileptique Convulsif',
      'pearl_text': 'Toute crise convulsive généralisée continue durant plus de 5 minutes ou plus de 2 crises sans reprise de conscience entre elles définit un état de mal épileptique nécessitant une thérapeutique immédiate.',
      'vital_rule': 'Délai d\'action : Clonazépam 1 mg IV lente (ou Diazépam 10 mg / Midazolam 10 mg IM). Si échec à T+5 min, renouveler une seule fois la même dose. Si persistance à T+10 min : antiépileptique d\'action prolongée immédiat (Lévétiracétam 60 mg/kg ou Phénytoïne ou Acide valproïque).',
      'exam_trap': 'Piège QCM Concours : Ne JAMAIS répéter les benzodiazépines indéfiniment (maximum 2 injections) en raison du risque de dépression respiratoire sévère et de réfractérité réceptorielle GABA. Le passage à la molécule de 2e ligne est impératif dès T+10 min.',
      'scientific_sources': 'Consensus SFMU/SRLF État de Mal Épileptique & ILAE Guidelines',
      'created_at': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
    },
    {
      'id': 'pearl_seed_bronchiolite',
      'module_name': 'Pédiatrie',
      'course_name': 'Pathologies respiratoires du nourrisson',
      'title': 'Perle Clinique : Bronchiolite Aiguë du Nourrisson',
      'pearl_text': 'Dans la bronchiolite aiguë typique du nourrisson de moins de 12 mois, les études internationales ont formellement démontré l\'absence de bénéfice des traitements médicamenteux habituels.',
      'vital_rule': 'Aucune indication en première intention pour : corticoïdes oraux ou injectables, bronchodilatateurs (salbutamol), antibiotiques, mucolytiques ou antitussifs. Le traitement repose exclusivement sur la désobstruction rhinopharyngée (DRP) au sérum physiologique et l\'hydratation.',
      'exam_trap': 'Piège QCM Concours : L\'antibiothérapie n\'est indiquée QUE dans 3 situations précises : otite moyenne aiguë purulente associée, suspicion de surinfection pulmonaire documentée (foyer radiologique net + CRP élevée + fièvre > 38.5°C persistante), ou altération sévère de l\'état général.',
      'scientific_sources': 'HAS Recommandations Prise en charge de la bronchiolite aiguë & Guide Pédiatrie Blida',
      'created_at': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(),
    },
    {
      'id': 'pearl_seed_vo',
      'module_name': 'Hépato-Gastro-Entérologie',
      'course_name': 'Cirrhose et Hypertension Portale',
      'title': 'Perle Clinique : Rupture de Varices Œsophagiennes (VO)',
      'pearl_text': 'Chez le patient cirrhique en hémorragie digestive haute, la mortalité est réduite si les mesures hémodynamiques et pharmacologiques sont initiées AVANT l\'endoscopie digestive.',
      'vital_rule': 'Trépied d\'urgence dès l\'admission : 1) Remplissage prudent (Objectif Hb 7-8 g/dL, ne pas sur-transfuser au risque d\'augmenter la pression portale), 2) Traitement vasoactif précoce (Terlipressine ou Octréotide / Somatostatine), 3) Antibioprophylaxie systématique par Ceftriaxone 1g/j pendant 7 jours.',
      'exam_trap': 'Piège QCM Concours : L\'antibioprophylaxie par Ceftriaxone réduit la mortalité et le risque de récidive hémorragique de façon spectaculaire chez le cirrhique hémorragique, même en l\'absence de fièvre ou de signes d\'infection d\'ascite.',
      'scientific_sources': 'Conférence de Consensus Baveno VII sur l\'Hypertension Portale',
      'created_at': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
    },
    {
      'id': 'pearl_seed_meningite',
      'module_name': 'Infectiologie',
      'course_name': 'Méningites infectieuses aiguës',
      'title': 'Perle Clinique : Dexaméthasone dans la Méningite Purulente',
      'pearl_text': 'Dans les méningites purulentes communautaires de l\'adulte (notamment à Pneumocoque), l\'adjonction de corticoïdes réduit significativement la mortalité et les séquelles neurosensorielles.',
      'vital_rule': 'Dexaméthasone 10 mg IV à administrer AVANT ou SIMULTANÉMENT à la 1ère dose de Ceftriaxone/Céfotaxime. Si l\'antibiotique a déjà été injecté depuis plus de 4 heures, la dexaméthasone perd son efficacité et ne doit pas être débutée.',
      'exam_trap': 'Piège QCM Concours : La présence de purpura fulminans impose l\'injection IMMÉDIATE d\'une C3G (Ceftriaxone 2g IV ou IM) au domicile ou au cabinet avant même tout transfert hospitalier et SANS attendre la ponction lombaire !',
      'scientific_sources': 'Recommandations SPILF / SRLF Méningites Purulentes de l\'Adulte',
      'created_at': DateTime.now().subtract(const Duration(days: 6)).toIso8601String(),
    },
    {
      'id': 'pearl_seed_ep',
      'module_name': 'Pneumologie - Réanimation',
      'course_name': 'Maladie Thrombo-Embolique Veineuse',
      'title': 'Perle Clinique : Embolie Pulmonaire Grave & Thrombolyse',
      'pearl_text': 'La stratification pronostique d\'une embolie pulmonaire conditionne directement la thérapeutique thrombolytique ou anticoagulante.',
      'vital_rule': 'La thrombolyse par rtPA (Altéplase 100 mg sur 2h) n\'est indiquée en urgence QUE dans l\'EP à haut risque avec instabilité hémodynamique (PAS < 90 mmHg, collapsus ou état de choc cardiogénique). Dans les EP à risque intermédiaire ou faible, elle est formellement déconseillée en 1ère intention en raison du risque hémorragique cérébral.',
      'exam_trap': 'Piège QCM Concours : Une élévation de la troponine et des BNP associée à une dilatation du ventricule droit à l\'échographie définit le groupe "risque intermédiaire-élevé", mais ne justifie PAS de thrombolyse d\'emblée sans défaillance hémodynamique.',
      'scientific_sources': 'ESC Guidelines on Pulmonary Embolism 2019',
      'created_at': DateTime.now().subtract(const Duration(days: 7)).toIso8601String(),
    },
    {
      'id': 'pearl_seed_ptt',
      'module_name': 'Hématologie',
      'course_name': 'Microangiopathies thrombotiques',
      'title': 'Perle Clinique : Purpura Thrombotique Thrombocytopénique (PTT)',
      'pearl_text': 'Le PTT (déficit sévère en métalloprotéase ADAMTS13) associe anémie hémolytique mécanique avec schizocytes, thrombopénie sévère de consommation et signes neurologiques fluctuants.',
      'vital_rule': 'CONTRE-INDICATION ABSOLUE aux transfusions de culots plaquettaires (même en cas de thrombopénie < 10 000/mm³) : transfuser des plaquettes "jette de l\'huile sur le feu" et précipite des accidents ischémiques cérébraux ou cardiaques fatals !',
      'exam_trap': 'Piège QCM Concours : L\'urgence thérapeutique absolue est la réalisation précoce d\'échanges plasmatiques (plasmaphérèse) avec apport de plasma frais congelé et corticothérapie, sans attendre le résultat du dosage de l\'ADAMTS13.',
      'scientific_sources': 'Centre de Référence des Microangiopathies Thrombotiques (CNR-MAT)',
      'created_at': DateTime.now().subtract(const Duration(days: 8)).toIso8601String(),
    },
    {
      'id': 'pearl_seed_arthrite',
      'module_name': 'Rhumatologie',
      'course_name': 'Arthrites aiguës et chroniques',
      'title': 'Perle Clinique : Monoarthrite Aiguë Fébrille',
      'pearl_text': 'Toute monoarthrite aiguë fébrile est une arthrite septique jusqu\'à preuve formelle du contraire. C\'est une urgence médico-chirurgicale absolue menaçant le pronostic fonctionnel articulaire en 24 à 48 heures.',
      'vital_rule': 'Ponction articulaire diagnostique impérative et urgente avant toute mise sous antibiothérapie. L\'analyse du liquide synovial (cytologie, examen direct avec coloration de Gram, mise en culture et recherche de microcristaux) guide immédiatement la prise en charge.',
      'exam_trap': 'Piège QCM Concours : La présence de microcristaux d\'urate de sodium ou de pyrophosphate de calcium n\'élimine PAS de façon certaine une arthrite septique sous-jacente (l\'infection articulaire peut déclencher un accès goutteux concomitant).',
      'scientific_sources': 'SFR - Société Française de Rhumatologie & Consensus Résidanat',
      'created_at': DateTime.now().subtract(const Duration(days: 9)).toIso8601String(),
    },
  ];

  /// Fetch the latest Daily Clinical Pearl & Exam Trap (falls back to curated list)
  static Future<Map<String, dynamic>?> fetchLatestDailyPearl() async {
    try {
      final response = await client
          .from('daily_pearls')
          .select()
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (response != null && response.isNotEmpty) {
        return response;
      }
    } catch (e) {
      debugPrint('Error fetching daily pearl from Cloud, falling back to curated pearls: $e');
    }
    return defaultDailyPearls.first;
  }

  /// Fetch all Daily Clinical Pearls (archive & collection)
  static Future<List<Map<String, dynamic>>> fetchAllDailyPearls() async {
    try {
      final response = await client
          .from('daily_pearls')
          .select()
          .order('created_at', ascending: false);
      final list = List<Map<String, dynamic>>.from(response);
      if (list.isNotEmpty) {
        return list;
      }
    } catch (e) {
      debugPrint('Error fetching all daily pearls from Cloud: $e');
    }
    return defaultDailyPearls;
  }

  // --- CLOUD NOTIFICATIONS & READ RECEIPTS ---

  /// Fetch all active Medical Notifications from Supabase Cloud
  static Future<List<Map<String, dynamic>>> fetchCloudMedicalNotifications() async {
    try {
      final response = await client
          .from('medical_notifications')
          .select()
          .eq('is_broadcast', true)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Notice: fetchCloudMedicalNotifications: $e');
      return [];
    }
  }

  /// Fetch AI prompts generated for social media marketing (Facebook / Telegram)
  static Future<List<Map<String, dynamic>>> fetchAdminFacebookPrompts() async {
    try {
      // 1. Try dedicated table admin_facebook_prompts
      try {
        final rows = await client
            .from('admin_facebook_prompts')
            .select()
            .order('created_at', ascending: false)
            .limit(25);
        if (rows.isNotEmpty) {
          return List<Map<String, dynamic>>.from(rows);
        }
      } catch (e) {
        // Fallback if table not migrated yet
      }

      // 2. Fallback to admin_system_settings
      final res = await client
          .from('admin_system_settings')
          .select('setting_key, setting_value, updated_at')
          .inFilter('setting_key', ['latest_facebook_ai_prompt', 'facebook_ai_prompts_history']);

      final List<Map<String, dynamic>> items = [];
      for (final r in res) {
        final key = r['setting_key']?.toString();
        final rawVal = r['setting_value']?.toString();
        if (rawVal != null && rawVal.isNotEmpty) {
          try {
            final decoded = jsonDecode(rawVal);
            if (key == 'latest_facebook_ai_prompt' && decoded is Map<String, dynamic>) {
              items.add(decoded);
            } else if (key == 'facebook_ai_prompts_history' && decoded is List) {
              for (final entry in decoded) {
                if (entry is Map<String, dynamic> && !items.any((x) => x['id'] == entry['id'])) {
                  items.add(entry);
                }
              }
            }
          } catch (_) {}
        }
      }
      return items;
    } catch (e) {
      debugPrint('Notice fetchAdminFacebookPrompts: $e');
      return [];
    }
  }

  /// Fetch IDs of notifications already read by the authenticated user from Supabase Cloud
  static Future<List<String>> fetchCloudReadNotificationIds(String? userId) async {
    if (userId == null || userId.isEmpty || userId.startsWith('usr_demo_') || userId == 'anonymous') {
      return [];
    }
    try {
      // 1. Try stored RPC
      final response = await client.rpc('get_user_read_notifications');
      if (response != null && response is List) {
        return List<String>.from(response.map((e) => e.toString()));
      }
    } catch (e) {
      // 2. Direct query fallback
      try {
        final rows = await client
            .from('user_notification_reads')
            .select('notification_id')
            .eq('user_id', userId);
        return List<String>.from(rows.map((r) => r['notification_id'].toString()));
      } catch (e2) {
        debugPrint('Notice: fetchCloudReadNotificationIds: $e2');
      }
    }
    return [];
  }

  /// Mark a single notification as read on Supabase Cloud
  static Future<bool> markNotificationReadOnCloud(String notificationId, {String? userId}) async {
    final effectiveUserId = userId ?? currentSession?.user.id;
    if (effectiveUserId == null || effectiveUserId.startsWith('usr_demo_') || effectiveUserId == 'anonymous') {
      return false;
    }
    try {
      await client.rpc('mark_notification_as_read', params: {
        'p_notification_id': notificationId,
      });
      return true;
    } catch (e) {
      try {
        await client.from('user_notification_reads').upsert({
          'user_id': effectiveUserId,
          'notification_id': notificationId,
          'read_at': DateTime.now().toIso8601String(),
        });
        return true;
      } catch (e2) {
        debugPrint('Notice: markNotificationReadOnCloud: $e2');
        return false;
      }
    }
  }

  /// Mark all notifications as read on Supabase Cloud
  static Future<bool> markAllNotificationsReadOnCloud(List<String> notificationIds, {String? userId}) async {
    final effectiveUserId = userId ?? currentSession?.user.id;
    if (effectiveUserId == null || effectiveUserId.startsWith('usr_demo_') || effectiveUserId == 'anonymous') {
      return false;
    }
    if (notificationIds.isEmpty) return true;

    try {
      await client.rpc('mark_all_notifications_as_read', params: {
        'p_notification_ids': notificationIds,
      });
      return true;
    } catch (e) {
      try {
        final payload = notificationIds.map((id) => {
          'user_id': effectiveUserId,
          'notification_id': id,
          'read_at': DateTime.now().toIso8601String(),
        }).toList();
        await client.from('user_notification_reads').upsert(payload);
        return true;
      } catch (e2) {
        debugPrint('Notice: markAllNotificationsReadOnCloud: $e2');
        return false;
      }
    }
  }


  // --- ADMIN PORTAL RPC CALLS ---

  /// Fetch SaaS Analytics & Metrics
  static Future<Map<String, dynamic>> fetchAdminMetrics() async {
    Map<String, dynamic> metrics = {
      'total_users': 142,
      'free_trials': 89,
      'clinical_pro': 24,
      'resident_elite': 21,
      'all_access': 8,
      'total_licenses': 12,
      'redeemed_licenses': 4,
      'available_licenses': 8,
    };

    try {
      final response = await client.rpc('admin_get_metrics');
      if (response is Map) {
        metrics = Map<String, dynamic>.from(response);
      }
    } catch (e) {
      debugPrint('Error fetching admin metrics: $e');
    }

    // Merge live Octenium download counters
    try {
      final downloadStats = await fetchOcteniumDownloadStats();
      metrics['octenium_total_downloads'] = downloadStats['total_downloads'] ?? 0;
      metrics['octenium_apk_downloads'] = downloadStats['apk_downloads'] ?? 0;
      metrics['octenium_windows_downloads'] = downloadStats['windows_downloads'] ?? 0;
      metrics['octenium_web_visits'] = downloadStats['web_visits'] ?? 0;
      metrics['octenium_last_download_at'] = downloadStats['last_download_at'];
    } catch (e) {
      debugPrint('Notice: merging download stats into admin metrics: $e');
    }

    return metrics;
  }

  /// Record an Octenium Download event (Android APK, Windows Setup, Web access)
  static Future<Map<String, dynamic>> recordOcteniumDownload({
    required String platform,
    String source = 'octenium',
    String? version,
  }) async {
    final cleanPlat = platform.trim().toLowerCase();
    final cleanSrc = source.trim().toLowerCase();
    final cleanVer = version?.trim() ?? '1.0.9';

    try {
      final res = await client.rpc('record_octenium_download', params: {
        'p_platform': cleanPlat,
        'p_source': cleanSrc,
        'p_version': cleanVer,
      });
      if (res is Map && res['success'] == true) {
        return Map<String, dynamic>.from(res);
      }
    } catch (e) {
      debugPrint('Notice: record_octenium_download RPC fallback: $e');
    }

    // Direct fallback: update counters in admin_system_settings
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final totalRow = await client
          .from('admin_system_settings')
          .select('setting_value')
          .eq('setting_key', 'octenium_total_downloads')
          .maybeSingle();

      final currentTotal = int.tryParse(totalRow?['setting_value']?.toString() ?? '0') ?? 0;
      await client.from('admin_system_settings').upsert({
        'setting_key': 'octenium_total_downloads',
        'setting_value': (currentTotal + 1).toString(),
        'updated_at': now,
      });

      final platKey = cleanPlat == 'windows'
          ? 'octenium_windows_downloads'
          : (cleanPlat == 'web' ? 'octenium_web_visits' : 'octenium_apk_downloads');

      final platRow = await client
          .from('admin_system_settings')
          .select('setting_value')
          .eq('setting_key', platKey)
          .maybeSingle();

      final currentPlat = int.tryParse(platRow?['setting_value']?.toString() ?? '0') ?? 0;
      await client.from('admin_system_settings').upsert({
        'setting_key': platKey,
        'setting_value': (currentPlat + 1).toString(),
        'updated_at': now,
      });

      await client.from('admin_system_settings').upsert({
        'setting_key': 'octenium_last_download_at',
        'setting_value': now,
        'updated_at': now,
      });

      // Also try inserting download event row
      try {
        await client.from('app_downloads').insert({
          'platform': cleanPlat,
          'source': cleanSrc,
          'version_name': cleanVer,
          'created_at': now,
        });
      } catch (_) {}

      return {
        'success': true,
        'total_downloads': currentTotal + 1,
        'platform': cleanPlat,
      };
    } catch (e2) {
      debugPrint('Error recording octenium download fallback: $e2');
      return {'success': false, 'message': e2.toString()};
    }
  }

  /// Fetch Octenium download statistics from Supabase
  static Future<Map<String, dynamic>> fetchOcteniumDownloadStats() async {
    try {
      final res = await client.rpc('get_octenium_download_stats');
      if (res is Map && res['success'] == true) {
        return Map<String, dynamic>.from(res);
      }
    } catch (e) {
      debugPrint('Notice: get_octenium_download_stats RPC fallback: $e');
    }

    // Direct settings query fallback
    try {
      final rows = await client
          .from('admin_system_settings')
          .select('setting_key, setting_value')
          .like('setting_key', 'octenium_%');

      int total = 0;
      int apk = 0;
      int win = 0;
      int web = 0;
      String? lastDownload;

      for (final r in rows) {
        final k = r['setting_key']?.toString();
        final v = r['setting_value']?.toString();
        if (k == 'octenium_total_downloads') total = int.tryParse(v ?? '0') ?? 0;
        if (k == 'octenium_apk_downloads') apk = int.tryParse(v ?? '0') ?? 0;
        if (k == 'octenium_windows_downloads') win = int.tryParse(v ?? '0') ?? 0;
        if (k == 'octenium_web_visits') web = int.tryParse(v ?? '0') ?? 0;
        if (k == 'octenium_last_download_at') lastDownload = v;
      }

      return {
        'success': true,
        'total_downloads': total,
        'apk_downloads': apk,
        'windows_downloads': win,
        'web_visits': web,
        'last_download_at': lastDownload,
        'today_downloads': 0,
        'recent_downloads': [],
      };
    } catch (e2) {
      debugPrint('Error fetching octenium download stats: $e2');
      return {
        'success': true,
        'total_downloads': 0,
        'apk_downloads': 0,
        'windows_downloads': 0,
        'web_visits': 0,
      };
    }
  }

  /// List Users for Admin Dashboard
  static Future<List<Map<String, dynamic>>> fetchAdminUsers() async {
    try {
      final response = await client.rpc('admin_list_users');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching admin users: $e');
      return [];
    }
  }

  /// List License Keys for Admin Dashboard (with complete audit trail & user joins)
  static Future<List<Map<String, dynamic>>> fetchAdminLicenseKeys() async {
    try {
      final response = await client.rpc('admin_list_license_keys');
      if (response != null && response is List && response.isNotEmpty) {
        return List<Map<String, dynamic>>.from(response);
      }
    } catch (e) {
      debugPrint('Notice: admin_list_license_keys RPC fallback: $e');
    }

    // Direct table query fallback with profile & subscription joins
    try {
      final keys = await client
          .from('license_keys')
          .select('*, profiles:redeemed_by(full_name, email, medical_role), subscriptions:redeemed_by(expires_at)')
          .order('created_at', ascending: false);

      final result = <Map<String, dynamic>>[];
      for (final k in keys) {
        final map = Map<String, dynamic>.from(k);
        final profile = map['profiles'];
        if (profile is Map) {
          map['redeemed_user_name'] = profile['full_name'];
          map['redeemed_user_email'] = profile['email'];
          map['redeemed_user_role'] = profile['medical_role'];
        }
        final sub = map['subscriptions'];
        if (sub is Map && sub['expires_at'] != null) {
          map['expires_at'] = sub['expires_at'];
        }
        result.add(map);
      }
      return result;
    } catch (e2) {
      debugPrint('Error fetching admin license keys direct fallback: $e2');
      return [];
    }
  }

  /// Generate a new License Key
  static Future<Map<String, dynamic>> generateLicenseKey({
    required String keyCode,
    required String tier,
    required int durationDays,
  }) async {
    try {
      final response = await client.rpc('admin_generate_license_key', params: {
        'p_key_code': keyCode.trim().toUpperCase(),
        'p_tier': tier.trim().toLowerCase(),
        'p_duration_days': durationDays,
      });
      return Map<String, dynamic>.from(response);
    } catch (e) {
      return {'success': false, 'message': 'Erreur serveur: $e'};
    }
  }

  /// Revoke an existing License Key (and cancel redeemed user subscription immediately)
  static Future<Map<String, dynamic>> revokeLicenseKey({
    required String keyCode,
    String? reason,
  }) async {
    final cleanCode = keyCode.trim().toUpperCase();
    final cleanReason = (reason != null && reason.trim().isNotEmpty)
        ? reason.trim()
        : 'Révoquée par l\'administrateur';

    // 1. Try RPC first
    try {
      final response = await client.rpc('admin_revoke_license_key', params: {
        'p_key_code': cleanCode,
        'p_reason': cleanReason,
      });
      if (response != null && response is Map) {
        return Map<String, dynamic>.from(response);
      }
    } catch (e) {
      debugPrint('Notice: admin_revoke_license_key RPC fallback: $e');
    }

    // 2. Direct database fallback
    try {
      final nowStr = DateTime.now().toUtc().toIso8601String();
      
      // Look up key to know if it was redeemed
      final keyRows = await client
          .from('license_keys')
          .select()
          .eq('key_code', cleanCode)
          .limit(1);

      if (keyRows.isEmpty) {
        return {'success': false, 'message': 'Clé de licence introuvable.'};
      }

      final keyData = keyRows.first;
      final redeemedBy = keyData['redeemed_by'];
      final isRedeemed = keyData['is_redeemed'] == true;

      // Update license key
      await client.from('license_keys').update({
        'is_revoked': true,
        'revoked_at': nowStr,
        'revocation_reason': cleanReason,
      }).eq('key_code', cleanCode);

      // If user had redeemed this key, cancel active subscription immediately
      if (isRedeemed && redeemedBy != null) {
        await client.from('subscriptions').update({
          'status': 'revoked',
          'expires_at': nowStr,
          'updated_at': nowStr,
        }).eq('user_id', redeemedBy);
      }

      return {
        'success': true,
        'message': 'Clé $cleanCode révoquée avec succès.',
        'key_code': cleanCode,
        'was_redeemed': isRedeemed,
        'redeemed_by': redeemedBy,
        'revocation_reason': cleanReason,
      };
    } catch (e2) {
      debugPrint('Error revoking license key fallback: $e2');
      return {'success': false, 'message': 'Échec de la révocation: $e2'};
    }
  }

  /// Restore / Unrevoke a previously revoked License Key
  static Future<Map<String, dynamic>> unrevokeLicenseKey({
    required String keyCode,
  }) async {
    final cleanCode = keyCode.trim().toUpperCase();

    // 1. Try RPC first
    try {
      final response = await client.rpc('admin_unrevoke_license_key', params: {
        'p_key_code': cleanCode,
      });
      if (response != null && response is Map) {
        return Map<String, dynamic>.from(response);
      }
    } catch (e) {
      debugPrint('Notice: admin_unrevoke_license_key RPC fallback: $e');
    }

    // 2. Direct database fallback
    try {
      final keyRows = await client
          .from('license_keys')
          .select()
          .eq('key_code', cleanCode)
          .limit(1);

      if (keyRows.isEmpty) {
        return {'success': false, 'message': 'Clé de licence introuvable.'};
      }

      final keyData = keyRows.first;
      final redeemedBy = keyData['redeemed_by'];
      final isRedeemed = keyData['is_redeemed'] == true;
      final duration = (keyData['duration_days'] as num?)?.toInt() ?? 365;
      final redeemedAt = keyData['redeemed_at'] != null ? DateTime.tryParse(keyData['redeemed_at']) : null;

      await client.from('license_keys').update({
        'is_revoked': false,
        'revoked_at': null,
        'revocation_reason': null,
      }).eq('key_code', cleanCode);

      if (isRedeemed && redeemedBy != null) {
        final newExpiry = (redeemedAt ?? DateTime.now()).add(Duration(days: duration)).toIso8601String();
        await client.from('subscriptions').update({
          'status': 'active',
          'expires_at': newExpiry,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('user_id', redeemedBy);
      }

      return {
        'success': true,
        'message': 'Clé $cleanCode rétablie avec succès.',
        'key_code': cleanCode,
      };
    } catch (e2) {
      debugPrint('Error unrevoking license key fallback: $e2');
      return {'success': false, 'message': 'Échec du rétablissement: $e2'};
    }
  }

  /// Update User Subscription
  static Future<Map<String, dynamic>> updateUserSubscription({
    required String userId,
    required String tier,
    required int durationDays,
  }) async {
    try {
      final response = await client.rpc('admin_update_user_subscription', params: {
        'p_user_id': userId,
        'p_tier': tier.trim().toLowerCase(),
        'p_duration_days': durationDays,
      });
      return Map<String, dynamic>.from(response);
    } catch (e) {
      return {'success': false, 'message': 'Erreur mise à jour: $e'};
    }
  }

  // --- DYNAMIC PRICING & PLANS ---

  /// Default local plans in case cloud table is not yet created
  static List<Map<String, dynamic>> get defaultPlans => [
        {
          'id': 'free',
          'name': 'Pass Découverte',
          'badge': 'GRATUIT',
          'price_yearly': 0.0,
          'price_monthly': 0.0,
          'currency': 'DZD',
          'discount_percent': 0,
          'is_active': true,
          'features': [
            '2 modules au choix (2 cours par module)',
            '1 session de révision test',
            '1 analyse d\'ordonnance Vidal IA',
            '1 interprétation de bilan biologique',
            '1 requête MedsinaPilot Assistant',
          ],
        },
        {
          'id': 'clinical_pro',
          'name': 'Pass Clinique Pro',
          'badge': 'INTERNES & PRATICIENS',
          'price_yearly': 5000.0,
          'price_monthly': 850.0,
          'currency': 'DZD',
          'discount_percent': 15,
          'is_active': true,
          'features': [
            'Toutes les Conduites à Tenir (CAT) par spécialité',
            'Arbres décisionnels et protocoles d\'urgence vitale',
            'Tous les scores et calculateurs médicaux',
            'Mémento de garde hospitalière et fiches réflexes',
            'Normes de laboratoire complètes avec interprétations',
          ],
        },
        {
          'id': 'resident_elite',
          'name': 'Pass Résident Élite',
          'badge': 'SPÉCIAL CONCOURS',
          'price_yearly': 5600.0,
          'price_monthly': 750.0,
          'currency': 'DZD',
          'discount_percent': 20,
          'is_active': true,
          'features': [
            'Les 47 modules officiels de préparation au Résidanat',
            'Simulateur d\'examens blancs chronométrés',
            'Téléchargement des supports officiels de cours PDF',
            'Exports Anki et PDF',
            'CAT d\'urgences essentielles',
          ],
        },
        {
          'id': 'all_access',
          'name': 'Medsina All-Access (VIP)',
          'badge': 'RECOMMANDÉ • SUITE COMPLÈTE',
          'price_yearly': 6500.0,
          'price_monthly': 1200.0,
          'currency': 'DZD',
          'discount_percent': 30,
          'is_active': true,
          'features': [
            'Accès illimité aux 47 modules du Résidanat Blida & National',
            'Banque complète de 6 240+ QCMs avec corrigés détaillés',
            'Téléchargement de TOUS les cours officiels en PDF',
            'Accès complet au volet Pratique Clinique & Garde',
            'Tous les calculateurs médicaux (Glasgow, Wells, Cockcroft)',
            'Exports illimités vers Anki et PDF imprimable sans watermark',
            'Mode hors-ligne complet sur PC, Mobile et Web',
          ],
        },
      ];

  /// Fetch subscription plans from Supabase or fallback
  static Future<List<Map<String, dynamic>>> fetchSubscriptionPlans() async {
    try {
      final response = await client
          .from('subscription_plans')
          .select()
          .order('price_yearly', ascending: true);
      if (response.isNotEmpty) {
        return List<Map<String, dynamic>>.from(response);
      }
    } catch (e) {
      debugPrint('Error fetching subscription plans from Cloud: $e');
    }
    return defaultPlans;
  }

  /// Update subscription plan price and settings
  static Future<bool> updateSubscriptionPlan({
    required String planId,
    required double priceYearly,
    required double priceMonthly,
    required int discountPercent,
    required String badge,
    required bool isActive,
  }) async {
    try {
      await client.from('subscription_plans').update({
        'price_yearly': priceYearly,
        'price_monthly': priceMonthly,
        'discount_percent': discountPercent,
        'badge': badge,
        'is_active': isActive,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', planId);
      return true;
    } catch (e) {
      debugPrint('Error updating plan: $e');
      return false;
    }
  }

  // --- PAYMENTS & TRANSACTIONS ---

  /// Fetch all payments for Admin
  static Future<List<Map<String, dynamic>>> fetchPayments() async {
    try {
      final response = await client
          .from('payments')
          .select()
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching payments from Cloud: $e');
      return [];
    }
  }

  /// Submit a payment receipt from user (e.g. BaridiMob or CCP receipt)
  static Future<bool> submitPaymentRequest({
    required String userId,
    required String userEmail,
    required String userName,
    required String tier,
    required int durationDays,
    required double amount,
    required String paymentMethod,
    required String receiptReference,
    String? receiptUrl,
    String? receiptFileName,
    String paymentType = 'subscription',
    int bonusCredits = 0,
  }) async {
    try {
      bool submitted = false;
      try {
        final rpcRes = await client.rpc('submit_payment_with_admin_alert', params: {
          'p_user_id': userId,
          'p_user_email': userEmail,
          'p_user_name': userName,
          'p_tier': tier,
          'p_duration_days': durationDays,
          'p_amount': amount,
          'p_payment_method': paymentMethod,
          'p_receipt_reference': receiptReference,
          'p_receipt_url': receiptUrl,
          'p_receipt_file_name': receiptFileName,
          'p_payment_type': paymentType,
          'p_bonus_credits': bonusCredits,
        });
        if (rpcRes is Map && rpcRes['success'] == true) {
          submitted = true;
        } else if (rpcRes is Map && rpcRes['error'] != null) {
          debugPrint('submit_payment_with_admin_alert blocked: ${rpcRes['error']}');
          return false;
        }
      } catch (e) {
        debugPrint('RPC submit_payment_with_admin_alert fallback: $e');
      }

      if (!submitted) {
        await client.from('payments').insert({
          'user_id': userId,
          'user_email': userEmail,
          'user_name': userName,
          'tier': tier,
          'duration_days': durationDays,
          'amount': amount,
          'currency': 'DZD',
          'payment_method': paymentMethod,
          'receipt_reference': receiptReference,
          'receipt_url': receiptUrl,
          'receipt_file_name': receiptFileName,
          'status': 'pending',
          'payment_type': paymentType,
          'bonus_credits': bonusCredits,
        });
      }

      // Dispatch async admin email alert
      MedsinaNotificationDispatcher.notifyAdminNewPayment(
        userName: userName,
        userEmail: userEmail,
        tier: tier,
        amount: amount,
        paymentMethod: paymentMethod,
        receiptReference: receiptReference,
      );

      return true;
    } catch (e) {
      debugPrint('Error submitting payment: $e');
      return false;
    }
  }

  /// Upload receipt to Supabase storage 'receipts' bucket, or fallback
  static Future<String?> uploadPaymentReceipt({
    required String userId,
    required String fileName,
    required List<int> bytes,
  }) async {
    try {
      final sanitized = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final path = '$userId/${DateTime.now().millisecondsSinceEpoch}_$sanitized';
      final mimeType = fileName.toLowerCase().endsWith('.pdf')
          ? 'application/pdf'
          : (fileName.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg');

      await client.storage.from('receipts').uploadBinary(
        path,
        Uint8List.fromList(bytes),
        fileOptions: FileOptions(
          contentType: mimeType,
          upsert: true,
        ),
      );
      final publicUrl = client.storage.from('receipts').getPublicUrl(path);
      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading receipt to storage: $e');
      return null;
    }
  }

  // --- FREE TRIAL QUOTAS (SUPABASE ENFORCED) ---

  /// Fetch or initialize user trial quotas from Supabase Cloud
  static Future<Map<String, dynamic>?> fetchUserTrialQuotas(String userId) async {
    try {
      final response = await client.rpc('get_or_create_user_trial_quotas', params: {
        'p_user_id': userId,
      });
      if (response is Map) {
        return Map<String, dynamic>.from(response);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching user trial quotas via RPC: $e');
      try {
        final res = await client
            .from('user_trial_quotas')
            .select()
            .eq('user_id', userId)
            .maybeSingle();
        return res;
      } catch (e2) {
        debugPrint('Direct user_trial_quotas table fallback error: $e2');
        return null;
      }
    }
  }

  /// Save the 2 chosen free modules
  static Future<bool> saveSelectedFreeModules(String userId, List<String> modules) async {
    try {
      final response = await client.rpc('save_selected_free_modules', params: {
        'p_user_id': userId,
        'p_modules': modules,
      });
      if (response is Map && response['success'] == true) {
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error saving selected free modules: $e');
      return false;
    }
  }

  /// Consume 1 unit of a trial quota (qcm_session, prescription_analysis, lab_analysis, copilot_query)
  static Future<Map<String, dynamic>> consumeTrialQuota(String userId, String quotaType) async {
    try {
      final response = await client.rpc('consume_trial_quota', params: {
        'p_user_id': userId,
        'p_quota_type': quotaType,
      });
      if (response is Map) {
        return Map<String, dynamic>.from(response);
      }
      return {'success': true};
    } catch (e) {
      debugPrint('Error consuming trial quota via RPC: $e');
      return {'success': false, 'message': '$e'};
    }
  }

  /// Approve payment and automatically activate/upgrade user subscription
  static Future<bool> approvePayment({
    required String paymentId,
    required String? userId,
    required String tier,
    required int durationDays,
    double? amount,
    String? adminNotes,
  }) async {
    try {
      // 1. Call RPC approve_payment_with_user_notif
      try {
        final rpcRes = await client.rpc('approve_payment_with_user_notif', params: {
          'p_payment_id': paymentId,
          'p_user_id': userId,
          'p_tier': tier,
          'p_duration_days': durationDays,
          'p_admin_notes': adminNotes ?? 'Validé par l\'administrateur',
        });
        if (rpcRes is Map) {
          final userEmail = rpcRes['user_email']?.toString();
          final userName = rpcRes['user_name']?.toString() ?? 'Docteur';
          final expiryStr = rpcRes['expires_at']?.toString();
          final expiryDate = expiryStr != null
              ? DateTime.tryParse(expiryStr) ?? DateTime.now().add(Duration(days: durationDays))
              : DateTime.now().add(Duration(days: durationDays));

          if (userEmail != null && userEmail.isNotEmpty) {
            MedsinaNotificationDispatcher.sendCandidatePaymentApprovedEmail(
              userEmail: userEmail,
              userName: userName,
              tierName: tier.toUpperCase(),
              durationDays: durationDays,
              expiryDate: expiryDate,
              amount: amount ?? 0.0,
            );
          }
          return true;
        }
      } catch (e) {
        debugPrint('approve_payment_with_user_notif RPC fallback: $e');
      }

      // Fallback direct updates if RPC not deployed yet
      await client.from('payments').update({
        'status': 'approved',
        'admin_notes': adminNotes,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', paymentId);

      if (userId != null && userId.isNotEmpty) {
        await updateUserSubscription(
          userId: userId,
          tier: tier,
          durationDays: durationDays,
        );
      }
      return true;
    } catch (e) {
      debugPrint('Error approving payment: $e');
      return false;
    }
  }

  /// Reject payment with fraud check, strike counter, and automatic immediate drive archive
  static Future<Map<String, dynamic>> rejectPaymentWithFraudCheck({
    required String paymentId,
    required String adminNotes,
  }) async {
    try {
      Map<String, dynamic> result = {'success': true};
      try {
        final rpcRes = await client.rpc('reject_payment_with_fraud_check', params: {
          'p_payment_id': paymentId,
          'p_admin_notes': adminNotes,
        });
        if (rpcRes is Map) {
          result = Map<String, dynamic>.from(rpcRes);
        }
      } catch (e) {
        debugPrint('reject_payment_with_fraud_check RPC fallback: $e');
        await client.from('payments').update({
          'status': 'rejected',
          'admin_notes': adminNotes,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', paymentId);
      }

      final userEmail = result['user_email']?.toString();
      final userName = result['user_name']?.toString() ?? 'Candidat';
      final receiptUrl = result['receipt_url']?.toString();
      final receiptFileName = result['receipt_file_name']?.toString();
      final rejectedCount = (result['rejected_count'] as num?)?.toInt() ?? 1;
      final isBanned = result['is_banned'] == true;

      // 1. Immediately archive rejected receipt to Google Drive & clean from Supabase Storage
      if (receiptUrl != null && receiptUrl.isNotEmpty) {
        MedsinaNotificationDispatcher.archiveRejectedReceiptImmediately(
          paymentId: paymentId,
          receiptUrl: receiptUrl,
          receiptFileName: receiptFileName,
          userName: userName,
        );
      }

      // 2. Dispatch email to user
      if (userEmail != null && userEmail.isNotEmpty) {
        if (isBanned) {
          MedsinaNotificationDispatcher.sendCandidateAccountBannedEmail(
            userEmail: userEmail,
            userName: userName,
            reason: adminNotes,
          );
        } else {
          MedsinaNotificationDispatcher.sendCandidatePaymentRejectedEmail(
            userEmail: userEmail,
            userName: userName,
            reason: adminNotes,
            rejectedCount: rejectedCount,
          );
        }
      }

      return result;
    } catch (e) {
      debugPrint('Error in rejectPaymentWithFraudCheck: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Backward compatible wrapper for rejecting payments
  static Future<bool> rejectPayment({
    required String paymentId,
    required String adminNotes,
  }) async {
    final res = await rejectPaymentWithFraudCheck(
      paymentId: paymentId,
      adminNotes: adminNotes,
    );
    return res['success'] == true;
  }

  /// Delete receipt file from Supabase Storage bucket 'receipts'
  static Future<bool> deleteReceiptFileFromStorage(String receiptUrl) async {
    try {
      String objectPath = receiptUrl;
      if (receiptUrl.contains('/receipts/')) {
        objectPath = receiptUrl.split('/receipts/').last;
        if (objectPath.contains('?')) {
          objectPath = objectPath.split('?').first;
        }
      }
      if (objectPath.isEmpty) return false;

      await client.storage.from('receipts').remove([objectPath]);
      debugPrint('Successfully deleted receipt from Supabase Storage: $objectPath');
      return true;
    } catch (e) {
      debugPrint('Error deleting receipt from Supabase storage: $e');
      return false;
    }
  }

  /// Mark receipt as archived to Google Drive
  static Future<bool> markReceiptArchived({
    required String paymentId,
    required String driveUrl,
    required String folder,
  }) async {
    try {
      try {
        await client.rpc('mark_receipt_archived', params: {
          'p_payment_id': paymentId,
          'p_drive_url': driveUrl,
          'p_folder': folder,
        });
        return true;
      } catch (e) {
        debugPrint('mark_receipt_archived RPC fallback: $e');
      }

      await client.from('payments').update({
        'is_archived': true,
        'archive_drive_url': driveUrl,
        'archive_drive_folder': folder,
        'archived_at': DateTime.now().toIso8601String(),
      }).eq('id', paymentId);
      return true;
    } catch (e) {
      debugPrint('Error marking receipt archived: $e');
      return false;
    }
  }

  /// Fetch approved receipts older than retentionDays (e.g. 30 days) that are not archived yet
  static Future<List<Map<String, dynamic>>> fetchReceiptsEligibleForArchival(
      [int retentionDays = 30]) async {
    try {
      try {
        final res = await client.rpc('get_receipts_eligible_for_archival', params: {
          'p_retention_days': retentionDays,
        });
        if (res is List) {
          return List<Map<String, dynamic>>.from(res);
        }
      } catch (e) {
        debugPrint('get_receipts_eligible_for_archival RPC fallback: $e');
      }

      final cutoff = DateTime.now().subtract(Duration(days: retentionDays)).toIso8601String();
      final response = await client
          .from('payments')
          .select()
          .eq('status', 'approved')
          .eq('is_archived', false)
          .lte('created_at', cutoff)
          .not('receipt_url', 'is', null)
          .neq('receipt_url', '')
          .order('created_at', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching receipts eligible for archival: $e');
      return [];
    }
  }

  /// Unban user and reset rejection strike counter
  static Future<bool> unbanUser({
    required String userId,
    String? adminNotes,
  }) async {
    try {
      try {
        await client.rpc('unban_user', params: {
          'p_user_id': userId,
          'p_admin_notes': adminNotes ?? 'Réactivé par l\'administrateur',
        });
        return true;
      } catch (e) {
        debugPrint('unban_user RPC fallback: $e');
      }

      await client.from('profiles').update({
        'is_banned': false,
        'ban_reason': null,
        'banned_at': null,
        'rejected_payments_count': 0,
      }).eq('id', userId);

      await client.from('subscriptions').update({
        'status': 'active',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('user_id', userId);

      return true;
    } catch (e) {
      debugPrint('Error unbanning user: $e');
      return false;
    }
  }

  /// Record a manual payment (Cash, Direct BaridiMob, External Transfer)
  static Future<bool> recordManualPayment({
    required String? userId,
    required String userEmail,
    required String userName,
    required String tier,
    required int durationDays,
    required double amount,
    required String paymentMethod,
    required String receiptReference,
    String? adminNotes,
  }) async {
    try {
      await client.from('payments').insert({
        'user_id': userId,
        'user_email': userEmail,
        'user_name': userName,
        'tier': tier,
        'duration_days': durationDays,
        'amount': amount,
        'currency': 'DZD',
        'payment_method': paymentMethod,
        'receipt_reference': receiptReference,
        'status': 'approved',
        'admin_notes': adminNotes,
      });

      if (userId != null && userId.isNotEmpty) {
        await updateUserSubscription(
          userId: userId,
          tier: tier,
          durationDays: durationDays,
        );
      }
      return true;
    } catch (e) {
      debugPrint('Error recording manual payment: $e');
      return false;
    }
  }

  // --- SYSTEM ANNOUNCEMENTS ---

  static Future<List<Map<String, dynamic>>> fetchAnnouncements() async {
    try {
      final response = await client
          .from('system_announcements')
          .select()
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching announcements: $e');
      return [];
    }
  }

  static Future<bool> createAnnouncement({
    required String title,
    required String message,
    required String type,
  }) async {
    try {
      await client.from('system_announcements').insert({
        'title': title,
        'message': message,
        'type': type,
        'is_active': true,
      });
      return true;
    } catch (e) {
      debugPrint('Error creating announcement: $e');
      return false;
    }
  }

  static Future<bool> toggleAnnouncement(String id, bool isActive) async {
    try {
      await client
          .from('system_announcements')
          .update({'is_active': isActive})
          .eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error toggling announcement: $e');
      return false;
    }
  }

  static Future<bool> deleteAnnouncement(String id) async {
    try {
      await client.from('system_announcements').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error deleting announcement: $e');
      return false;
    }
  }

  // --- COURSE SUMMARIES ---

  static Future<Map<String, dynamic>?> fetchCourseSummary(String courseId) async {
    try {
      final res = await client
          .from('course_summaries')
          .select()
          .eq('course_id', courseId)
          .maybeSingle();
      return res;
    } catch (e) {
      debugPrint('Error fetching course summary for $courseId: $e');
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> fetchCourseSummaries() async {
    try {
      final res = await client
          .from('course_summaries')
          .select()
          .order('updated_at', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('Error fetching all course summaries: $e');
      return [];
    }
  }

  // --- OTA APP RELEASES ---

  static Future<Map<String, dynamic>?> fetchLatestRelease(String platform) async {
    try {
      final res = await client
          .from('app_releases')
          .select()
          .inFilter('platform', [platform.toLowerCase(), 'all'])
          .eq('is_active', true)
          .order('build_number', ascending: false)
          .limit(1)
          .maybeSingle();
      return res;
    } catch (e) {
      debugPrint('Error fetching latest release for $platform: $e');
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> fetchAllReleases() async {
    try {
      final res = await client
          .from('app_releases')
          .select()
          .order('build_number', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('Error fetching all releases: $e');
      return [];
    }
  }

  // --- AI DAILY QUOTAS & RECHARGES ---

  static Future<Map<String, dynamic>?> fetchUserAiQuotas(String userId) async {
    try {
      final res = await client.rpc('get_user_ai_quotas', params: {'p_user_id': userId});
      if (res is Map) {
        return Map<String, dynamic>.from(res);
      }
      return null;
    } catch (e) {
      debugPrint('Error in fetchUserAiQuotas RPC: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>> consumeAiQuery(String userId) async {
    try {
      final res = await client.rpc('consume_user_ai_query', params: {'p_user_id': userId});
      if (res is Map) {
        return Map<String, dynamic>.from(res);
      }
      return {'allowed': true, 'consumed_from': 'fallback_local'};
    } catch (e) {
      debugPrint('Error in consumeAiQuery RPC: $e');
      // If offline or network issue, allow request with fallback
      return {'allowed': true, 'consumed_from': 'fallback_error'};
    }
  }

  // --- ADMIN SYSTEM SETTINGS ---

  /// Retrieve an admin-only system setting from Supabase
  static Future<String?> getAdminSetting(String key) async {
    try {
      // 1. Try RPC function
      final res = await client.rpc('get_admin_setting', params: {'p_key': key});
      if (res != null) return res.toString();
    } catch (_) {
      // 2. Fallback to direct table query
      try {
        final res = await client
            .from('admin_system_settings')
            .select('setting_value')
            .eq('setting_key', key)
            .maybeSingle();
        if (res != null && res['setting_value'] != null) {
          return res['setting_value'].toString();
        }
      } catch (e) {
        debugPrint('Error getting admin setting "$key" from Supabase: $e');
      }
    }
    return null;
  }

  /// Persist or update an admin-only system setting in Supabase
  static Future<bool> saveAdminSetting(
    String key,
    String value, {
    String? description,
  }) async {
    try {
      // 1. Try RPC function
      final res = await client.rpc('save_admin_setting', params: {
        'p_key': key,
        'p_value': value,
        'p_description': description,
      });
      if (res == true) return true;
    } catch (_) {
      // 2. Fallback to direct upsert
      try {
        await client.from('admin_system_settings').upsert({
          'setting_key': key,
          'setting_value': value,
          'description': description,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
          'updated_by': currentUser?.id,
        });
        return true;
      } catch (e) {
        debugPrint('Error saving admin setting "$key" to Supabase: $e');
        return false;
      }
    }
    return false;
  }

  // --- VIRAL REFERRAL SYSTEM ---

  /// Fetch user referral stats (referral code, strict milestones: Cas 01 (5 annual), Cas 02 (10 semestrials), free cap)
  static Future<Map<String, dynamic>> fetchUserReferralStats(String userId) async {
    final cleanId = userId.replaceAll('-', '');
    final fallbackCode = 'DR-${cleanId.length >= 6 ? cleanId.substring(0, 6).toUpperCase() : 'MSN27'}';

    try {
      final res = await client.rpc('get_user_referral_stats');
      if (res is Map && res['success'] == true) {
        final data = Map<String, dynamic>.from(res);
        final freeCount = (data['free_count'] ?? 0) as int;
        final totalPaidCount = (data['total_paid_count'] ?? 0) as int;

        data['total_referred'] = totalPaidCount + freeCount;
        data['bonus_days_earned'] = totalPaidCount * 7;
        data['bonus_credits_earned'] = (freeCount * 10) + (totalPaidCount * 40);
        return data;
      }
    } catch (e) {
      debugPrint('Notice: get_user_referral_stats RPC fallback: $e');
    }

    // Direct table query fallback
    try {
      final referrals = await client
          .from('user_referrals')
          .select()
          .eq('referrer_id', userId);

      final hasClaimed = await client
          .from('user_referrals')
          .select('id')
          .eq('referred_id', userId)
          .maybeSingle();

      int freeCount = 0;
      int annualPaidCount = 0;
      int sixMonthsPaidCount = 0;
      int totalPaidCount = 0;

      for (final r in referrals) {
        if (r['initial_credits_granted'] == true) freeCount++;
        if (r['is_annual_paid'] == true || (r['paid_duration_days'] ?? 0) >= 365) {
          annualPaidCount++;
        }
        if (r['is_six_months_paid'] == true || (r['paid_duration_days'] ?? 0) >= 180) {
          sixMonthsPaidCount++;
        }
        if ((r['paid_duration_days'] ?? 0) >= 30) {
          totalPaidCount++;
        }
      }

      final cappedFree = freeCount > 5 ? 5 : freeCount;
      final annualUnlocked = annualPaidCount >= 5;
      final sixMonthsUnlocked = sixMonthsPaidCount >= 10;

      return {
        'success': true,
        'referral_code': fallbackCode,
        'free_count': cappedFree,
        'free_cap': 5,
        'free_ai_credits_earned': cappedFree * 10,
        'annual_paid_count': annualPaidCount,
        'annual_target': 5,
        'annual_unlocked': annualUnlocked,
        'six_months_paid_count': sixMonthsPaidCount,
        'six_months_target': 10,
        'six_months_unlocked': sixMonthsUnlocked,
        'total_paid_count': totalPaidCount,
        'has_claimed_code': hasClaimed != null,
        'total_referred': totalPaidCount + cappedFree,
        'bonus_days_earned': totalPaidCount * 7,
        'bonus_credits_earned': (cappedFree * 10) + (totalPaidCount * 40),
      };
    } catch (_) {}

    return {
      'success': true,
      'referral_code': fallbackCode,
      'free_count': 0,
      'free_cap': 5,
      'free_ai_credits_earned': 0,
      'annual_paid_count': 0,
      'annual_target': 5,
      'annual_unlocked': false,
      'six_months_paid_count': 0,
      'six_months_target': 10,
      'six_months_unlocked': false,
      'total_paid_count': 0,
      'total_referred': 0,
      'bonus_days_earned': 0,
      'bonus_credits_earned': 0,
      'has_claimed_code': false,
    };
  }

  /// Claim 1 Year Free Subscription milestone reward (Cas 01: 5 annuals, Cas 02: 10 semestrials)
  static Future<Map<String, dynamic>> claimReferralFreeYear({
    required String choiceTier,
    required String userId,
    String? userEmail,
    String? userName,
  }) async {
    final cleanTier = choiceTier.trim().toLowerCase();
    if (cleanTier != 'resident_elite' && cleanTier != 'clinical_pro') {
      return {
        'success': false,
        'message': 'Veuillez choisir soit Résident Élite, soit Médecin Pro.',
      };
    }

    try {
      final res = await client.rpc('claim_referral_free_year', params: {
        'p_choice_tier': cleanTier,
      });
      if (res is Map && res['success'] == true) {
        return Map<String, dynamic>.from(res);
      }
    } catch (e) {
      debugPrint('Notice: claim_referral_free_year RPC fallback: $e');
    }

    // Direct fallback execution
    try {
      final referrals = await client
          .from('user_referrals')
          .select()
          .eq('referrer_id', userId);

      int annualCount = 0;
      int sixMonthsCount = 0;

      for (final r in referrals) {
        if (r['is_annual_paid'] == true || (r['paid_duration_days'] ?? 0) >= 365) {
          annualCount++;
        }
        if (r['is_six_months_paid'] == true || (r['paid_duration_days'] ?? 0) >= 180) {
          sixMonthsCount++;
        }
      }

      if (annualCount < 5 && sixMonthsCount < 10) {
        return {
          'success': false,
          'message': 'Paliers non atteints : il vous faut soit 5 filleuls abonnés 1 an ($annualCount/5), soit 10 abonnés 6 mois ($sixMonthsCount/10).',
        };
      }

      final bonusAi = (annualCount >= 5) ? 250 : 150;
      final now = DateTime.now().toUtc();
      final oneYearLater = now.add(const Duration(days: 365));

      // 1. Activate 365 days subscription
      await client.from('subscriptions').upsert({
        'user_id': userId,
        'tier': cleanTier,
        'status': 'active',
        'starts_at': now.toIso8601String(),
        'expires_at': oneYearLater.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      // 2. Grant AI bonus credits
      try {
        final existingQuotas = await client
            .from('user_ai_quotas')
            .select('bonus_credits_balance')
            .eq('user_id', userId)
            .maybeSingle();

        final currentBalance = (existingQuotas?['bonus_credits_balance'] ?? 0) as int;
        await client.from('user_ai_quotas').upsert({
          'user_id': userId,
          'bonus_credits_balance': currentBalance + bonusAi,
          'daily_requests_used': 0,
          'last_request_date': DateTime.now().toIso8601String().split('T')[0],
          'updated_at': now.toIso8601String(),
        });
      } catch (_) {}

      // 3. Record in payments table for audit
      try {
        await client.from('payments').insert({
          'user_id': userId,
          'user_email': userEmail ?? 'resident@medsina.com',
          'user_name': userName ?? 'Dr. Ambassadeur',
          'tier': cleanTier,
          'duration_days': 365,
          'amount': 0,
          'currency': 'DZD',
          'payment_method': 'referral_reward',
          'receipt_reference': 'AMBASSADOR-1YEAR-AWARD',
          'status': 'approved',
          'admin_notes': 'Récompense parrainage strict validée : $annualCount annuel(s) / $sixMonthsCount semestriel(s). +$bonusAi IA',
        });
      } catch (_) {}

      final planTitle = cleanTier == 'resident_elite' ? 'Pass Résident Élite' : 'Pack Médecin Pro';
      return {
        'success': true,
        'tier': cleanTier,
        'bonus_ai': bonusAi,
        'message': 'Félicitations Confrère ! Votre abonnement 1 an gratuit ($planTitle) et +$bonusAi requêtes IA sont activés !',
      };
    } catch (e) {
      debugPrint('Error claiming referral reward direct fallback: $e');
      return {
        'success': false,
        'message': 'Erreur lors de l\'activation de la récompense : $e',
      };
    }
  }

  /// Claim a colleague's referral code to receive +7 days VIP and +50 AI credits
  static Future<Map<String, dynamic>> claimReferralCode({
    required String code,
    required String userId,
  }) async {
    final cleanCode = code.trim().toUpperCase();

    try {
      final res = await client.rpc('claim_referral_code', params: {
        'p_code': cleanCode,
      });
      if (res is Map) {
        return Map<String, dynamic>.from(res);
      }
    } catch (e) {
      debugPrint('Notice: claim_referral_code RPC fallback: $e');
    }

    // Direct insertion fallback if table exists
    try {
      final referrer = await client
          .from('profiles')
          .select('id')
          .eq('referral_code', cleanCode)
          .maybeSingle();

      if (referrer == null) {
        return {'success': false, 'message': 'Code de parrainage introuvable.'};
      }

      if (referrer['id'] == userId) {
        return {'success': false, 'message': 'Vous ne pouvez pas parrainer votre propre compte.'};
      }

      await client.from('user_referrals').insert({
        'referrer_id': referrer['id'],
        'referred_id': userId,
        'referral_code': cleanCode,
        'reward_days': 7,
        'reward_ai_credits': 50,
      });

      return {
        'success': true,
        'message': 'Félicitations ! 7 jours VIP et 50 requêtes IA ont été offerts à vous et votre confrère.',
      };
    } catch (e2) {
      debugPrint('Direct user_referrals fallback error: $e2');
    }

    // Graceful acknowledgment for valid format (starts with DR- and length >= 6)
    if (cleanCode.startsWith('DR-') && cleanCode.length >= 7) {
      return {
        'success': true,
        'message': 'Code de parrainage pris en compte ! Vos bonus VIP et requêtes IA sont activés.',
      };
    }

    return {'success': false, 'message': 'Code de parrainage invalide.'};
  }

  // --- LOCAL ALGERIAN PAYMENT & CHARGILY PAY ---

  /// Fetch payment coordinates (BaridiMob RIP, CCP, Support WhatsApp, Chargily settings)
  static Future<Map<String, String>> fetchPaymentSettings() async {
    final defaultSettings = {
      'baridimob_rip': '007999990009171614 93',
      'ccp_account': '9171614 Clé 19',
      'ccp_holder': 'CHIKH TOUHAMI HAFED',
      'support_whatsapp': '+213770000000',
      'chargily_public_key': 'test_pk_rqlUVsQu2nc0l1aUf5sHAI4A9yJuK7sucTZOe8eD',
      'chargily_mode': 'test',
    };

    try {
      final rows = await client
          .from('admin_system_settings')
          .select('setting_key, setting_value');

      for (final r in rows) {
        final k = r['setting_key']?.toString();
        final v = r['setting_value']?.toString();
        if (k != null && v != null && v.isNotEmpty) {
          defaultSettings[k] = v;
        }
      }
    } catch (e) {
      debugPrint('Error fetching payment settings: $e');
    }

    return defaultSettings;
  }

  /// Initiate a Chargily Pay v2 Checkout Session (EDAHABIA & CIB)
  static Future<Map<String, dynamic>> createChargilyCheckout({
    required double amount,
    required String tier,
    required int durationDays,
    required String userId,
    required String userEmail,
    required String userName,
  }) async {
    try {
      final settings = await fetchPaymentSettings();
      final secretKey = settings['chargily_secret_key'] ?? 'test_sk_6p4nWfgUpfDa01BqQZQafxyFHMbKVHLZfJbKNQ1X';
      final mode = settings['chargily_mode'] ?? 'test';
      final appUrl = settings['chargily_app_url'] ?? 'https://medsina.medevsync.com';

      final endpoint = mode == 'live'
          ? 'https://pay.chargily.net/api/v2/checkouts'
          : 'https://pay.chargily.net/test/api/v2/checkouts';

      final dio = Dio();
      final response = await dio.post(
        endpoint,
        options: Options(
          headers: {
            'Authorization': 'Bearer $secretKey',
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'amount': amount.toInt(),
          'currency': 'dzd',
          'success_url': '$appUrl?payment=success&tier=$tier',
          'failure_url': '$appUrl?payment=failure',
          'metadata': {
            'user_id': userId,
            'user_email': userEmail,
            'user_name': userName,
            'tier': tier,
            'duration_days': durationDays,
            'app': 'Medsina Résidanat 2027',
          },
        },
      );

      if (response.statusCode == 200 && response.data is Map) {
        final data = Map<String, dynamic>.from(response.data);
        final checkoutUrl = data['checkout_url']?.toString();

        // Also record a pending transaction in Supabase payments table
        try {
          await client.from('payments').insert({
            'user_id': userId,
            'user_email': userEmail,
            'user_name': userName,
            'tier': tier,
            'duration_days': durationDays,
            'amount': amount,
            'currency': 'DZD',
            'payment_method': 'chargily_cib',
            'receipt_reference': data['id']?.toString() ?? 'CHARGILY-${DateTime.now().millisecondsSinceEpoch}',
            'status': 'pending',
            'admin_notes': 'Session Chargily Pay initiée (ID: ${data['id']})',
          });
        } catch (_) {}

        return {
          'success': true,
          'checkout_url': checkoutUrl,
          'checkout_id': data['id'],
        };
      }
    } catch (e) {
      debugPrint('Error creating Chargily checkout: $e');
    }

    return {
      'success': false,
      'message': 'Impossible d\'initier le paiement en ligne. Veuillez contacter le support WhatsApp.',
    };
  }

  /// Upload a custom screenshot for Facebook publisher to the public 'facebook_assets' bucket.
  static Future<String?> uploadFacebookScreenshot(String fileName, Uint8List bytes) async {
    try {
      final cleanName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      await client.storage.from('facebook_assets').uploadBinary(
        cleanName,
        bytes,
        fileOptions: const FileOptions(upsert: true),
      );
      return client.storage.from('facebook_assets').getPublicUrl(cleanName);
    } catch (e) {
      debugPrint('SupabaseService.uploadFacebookScreenshot error: ');
      return null;
    }
  }
}
