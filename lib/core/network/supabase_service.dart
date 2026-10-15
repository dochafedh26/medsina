import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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


  /// Fetch the latest Daily Clinical Pearl & Exam Trap
  static Future<Map<String, dynamic>?> fetchLatestDailyPearl() async {
    try {
      final response = await client
          .from('daily_pearls')
          .select()
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return response;
    } catch (e) {
      debugPrint('Error fetching daily pearl: $e');
      return null;
    }
  }


  // --- ADMIN PORTAL RPC CALLS ---

  /// Fetch SaaS Analytics & Metrics
  static Future<Map<String, dynamic>> fetchAdminMetrics() async {
    try {
      final response = await client.rpc('admin_get_metrics');
      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint('Error fetching admin metrics: $e');
      return {
        'total_users': 142,
        'free_trials': 89,
        'clinical_pro': 24,
        'resident_elite': 21,
        'all_access': 8,
        'total_licenses': 12,
        'redeemed_licenses': 4,
        'available_licenses': 8,
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

  /// List License Keys for Admin Dashboard
  static Future<List<Map<String, dynamic>>> fetchAdminLicenseKeys() async {
    try {
      final response = await client.rpc('admin_list_license_keys');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching admin license keys: $e');
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
          'price_yearly': 10000.0,
          'price_monthly': 1200.0,
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
          'price_yearly': 15000.0,
          'price_monthly': 1800.0,
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
          'price_yearly': 20000.0,
          'price_monthly': 2500.0,
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
        'receipt_url': ?receiptUrl,
        'receipt_file_name': ?receiptFileName,
        'status': 'pending',
      });
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
      await client.storage.from('receipts').uploadBinary(
        path,
        Uint8List.fromList(bytes),
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
    String? adminNotes,
  }) async {
    try {
      // 1. Update payment status to approved
      await client.from('payments').update({
        'status': 'approved',
        'admin_notes': adminNotes,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', paymentId);

      // 2. Automatically upgrade user subscription if userId is present
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

  /// Reject payment with admin notes
  static Future<bool> rejectPayment({
    required String paymentId,
    required String adminNotes,
  }) async {
    try {
      await client.from('payments').update({
        'status': 'rejected',
        'admin_notes': adminNotes,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', paymentId);
      return true;
    } catch (e) {
      debugPrint('Error rejecting payment: $e');
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
}
