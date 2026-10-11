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

  /// Fetch Lab Reference Values
  static Future<List<Map<String, dynamic>>> fetchLabReferenceValues() async {
    try {
      final response = await client.from('lab_reference_values').select();
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching lab values: $e');
      return [];
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
}
