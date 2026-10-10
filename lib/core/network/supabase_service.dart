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

  // Redeem License Key via PostgreSQL RPC
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

  // Fetch Medical Modules from Supabase
  static Future<List<Map<String, dynamic>>> fetchModules() async {
    final response = await client
        .from('medical_modules')
        .select('*, courses(*)')
        .order('display_order', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  // Fetch Questions for a course
  static Future<List<Map<String, dynamic>>> fetchCourseQuestions(String courseId) async {
    final response = await client
        .from('qcm_questions')
        .select('*, qcm_options(*)')
        .eq('course_id', courseId);
    return List<Map<String, dynamic>>.from(response);
  }

  // Fetch Clinical Protocols
  static Future<List<Map<String, dynamic>>> fetchClinicalProtocols() async {
    final response = await client.from('clinical_protocols').select();
    return List<Map<String, dynamic>>.from(response);
  }
}
