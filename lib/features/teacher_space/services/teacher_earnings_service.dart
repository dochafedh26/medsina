import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_service.dart';
import '../models/teacher_earnings_model.dart';

/// Accès au programme de rémunération des enseignants (65 % auteurs / 35 % Medsina).
///
/// Toutes les règles sensibles (plafonds, anti-fraude, solde) sont appliquées
/// côté PostgreSQL ; ce service ne fait qu'orchestrer les appels.
class TeacherEarningsService {
  /// Charge le tableau de bord « Mes gains » de l'enseignant connecté.
  static Future<TeacherEarningsSummary> loadSummary() async {
    if (!SupabaseService.isAuthenticated) return TeacherEarningsSummary.empty;
    final client = SupabaseService.client;
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return TeacherEarningsSummary.empty;

    double balance = 0;
    List<TeacherLedgerEntry> ledger = const [];
    List<TeacherPayoutItem> payouts = const [];
    TeacherRevenueSettings settings = const TeacherRevenueSettings();

    try {
      final rawBalance = await client.rpc('teacher_available_balance');
      if (rawBalance is num) balance = rawBalance.toDouble();
    } catch (_) {
      // Migration non appliquée ou hors-ligne : on garde 0.
    }

    try {
      final rows = await client
          .from('teacher_earnings_ledger')
          .select()
          .eq('author_id', uid)
          .order('period_month', ascending: false)
          .limit(24);
      ledger = (rows as List)
          .whereType<Map>()
          .map((r) => TeacherLedgerEntry.fromJson(Map<String, dynamic>.from(r)))
          .toList();
    } catch (_) {}

    try {
      final rows = await client
          .from('teacher_payout_requests')
          .select()
          .eq('author_id', uid)
          .order('requested_at', ascending: false)
          .limit(24);
      payouts = (rows as List)
          .whereType<Map>()
          .map((r) => TeacherPayoutItem.fromJson(Map<String, dynamic>.from(r)))
          .toList();
    } catch (_) {}

    try {
      final row = await client
          .from('teacher_revenue_settings')
          .select()
          .eq('id', true)
          .maybeSingle();
      if (row != null) {
        settings = TeacherRevenueSettings.fromJson(Map<String, dynamic>.from(row));
      }
    } catch (_) {}

    return TeacherEarningsSummary(
      availableBalance: balance,
      ledger: ledger,
      payouts: payouts,
      settings: settings,
    );
  }

  /// Enregistre une consommation réelle (vue de publication, passage d'examen).
  /// Volontairement silencieux : ne doit jamais bloquer l'expérience utilisateur.
  static Future<void> recordConsumption({
    required String contentType,
    required String contentId,
    double units = 1,
  }) async {
    if (!SupabaseService.isAuthenticated) return;
    try {
      await SupabaseService.client.rpc(
        'record_teacher_consumption',
        params: {
          'p_content_type': contentType,
          'p_content_id': contentId,
          'p_units': units,
        },
      );
    } on PostgrestException {
      // Anti-fraude (doublon, auto-consommation) : réponse normale, on ignore.
    } catch (_) {
      // Hors-ligne ou migration absente.
    }
  }

  /// Crée une demande de retrait. Retourne un message d'erreur, ou `null` si OK.
  static Future<String?> requestPayout({
    required double amount,
    required String method,
    required String accountHolder,
    required String accountDetails,
    required TeacherRevenueSettings settings,
    required double availableBalance,
  }) async {
    if (!SupabaseService.isAuthenticated) {
      return 'Connexion requise.';
    }

    final validationError = validatePayoutAmount(
      amount: amount,
      availableBalance: availableBalance,
      minAmount: settings.minPayoutAmount,
    );
    if (validationError != null) return validationError;

    try {
      await SupabaseService.client.rpc(
        'request_teacher_payout',
        params: {
          'p_amount': amount,
          'p_method': method,
          'p_account_holder': accountHolder.trim(),
          'p_account_details': accountDetails.trim(),
        },
      );
      return null;
    } on PostgrestException catch (e) {
      return _humanizePayoutError(e.message);
    } catch (_) {
      return 'Demande impossible pour le moment. Réessayez plus tard.';
    }
  }

  static String _humanizePayoutError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('insufficient')) return 'Solde disponible insuffisant.';
    if (lower.contains('below minimum')) return 'Montant inférieur au retrait minimum.';
    if (lower.contains('verification required')) {
      return 'Votre grade académique doit être vérifié avant tout retrait.';
    }
    if (lower.contains('account details required')) {
      return 'Renseignez le titulaire et le numéro de compte.';
    }
    return 'Demande refusée : $message';
  }
}
