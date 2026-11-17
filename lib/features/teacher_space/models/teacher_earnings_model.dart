/// Modèles du programme de rémunération des enseignants Medsina.
///
/// Règle économique : 65 % du revenu net mensuel constitue le pool des auteurs,
/// réparti au prorata des unités de consommation réelles (attribution
/// « user-centric »), 35 % restant à la plateforme.
library;

class TeacherRevenueSettings {
  final double authorSharePct;
  final double minPayoutAmount;
  final int holdbackDays;
  final int minUniqueReaders;
  final double maxAuthorPoolPct;
  final int minAuthorsForCap;
  final bool isEnabled;

  const TeacherRevenueSettings({
    this.authorSharePct = 65,
    this.minPayoutAmount = 3000,
    this.holdbackDays = 30,
    this.minUniqueReaders = 10,
    this.maxAuthorPoolPct = 20,
    this.minAuthorsForCap = 5,
    this.isEnabled = true,
  });

  double get platformSharePct => 100 - authorSharePct;

  factory TeacherRevenueSettings.fromJson(Map<String, dynamic> json) {
    double num_(Object? v, double fallback) => (v as num?)?.toDouble() ?? fallback;
    int int_(Object? v, int fallback) => (v as num?)?.toInt() ?? fallback;

    return TeacherRevenueSettings(
      authorSharePct: num_(json['author_share_pct'], 65),
      minPayoutAmount: num_(json['min_payout_amount'], 3000),
      holdbackDays: int_(json['holdback_days'], 30),
      minUniqueReaders: int_(json['min_unique_readers'], 10),
      maxAuthorPoolPct: num_(json['max_author_pool_pct'], 20),
      minAuthorsForCap: int_(json['min_authors_for_cap'], 5),
      isEnabled: json['is_enabled'] != false,
    );
  }
}

class TeacherLedgerEntry {
  final DateTime periodMonth;
  final double units;
  final double grossAttributed;
  final double earnings;
  final String status;
  final DateTime? availableAt;

  const TeacherLedgerEntry({
    required this.periodMonth,
    required this.units,
    required this.grossAttributed,
    required this.earnings,
    required this.status,
    this.availableAt,
  });

  bool get isAvailable =>
      status != 'clawed_back' &&
      (availableAt == null || !availableAt!.isAfter(DateTime.now()));

  factory TeacherLedgerEntry.fromJson(Map<String, dynamic> json) {
    return TeacherLedgerEntry(
      periodMonth: DateTime.tryParse(json['period_month']?.toString() ?? '') ?? DateTime.now(),
      units: (json['attributed_units'] as num?)?.toDouble() ?? 0,
      grossAttributed: (json['gross_attributed'] as num?)?.toDouble() ?? 0,
      earnings: (json['author_earnings'] as num?)?.toDouble() ?? 0,
      status: json['status']?.toString() ?? 'accrued',
      availableAt: json['available_at'] != null
          ? DateTime.tryParse(json['available_at'].toString())
          : null,
    );
  }
}

class TeacherPayoutItem {
  final String id;
  final double amount;
  final String method;
  final String status;
  final DateTime requestedAt;
  final DateTime? paidAt;
  final String? adminNote;

  const TeacherPayoutItem({
    required this.id,
    required this.amount,
    required this.method,
    required this.status,
    required this.requestedAt,
    this.paidAt,
    this.adminNote,
  });

  String get methodLabel {
    switch (method) {
      case 'ccp':
        return 'CCP';
      case 'baridimob':
        return 'BaridiMob';
      case 'virement':
        return 'Virement bancaire';
      default:
        return method;
    }
  }

  String get statusLabel {
    switch (status) {
      case 'requested':
        return 'En attente';
      case 'approved':
        return 'Validé';
      case 'paid':
        return 'Payé';
      case 'rejected':
        return 'Refusé';
      case 'cancelled':
        return 'Annulé';
      default:
        return status;
    }
  }

  factory TeacherPayoutItem.fromJson(Map<String, dynamic> json) {
    return TeacherPayoutItem(
      id: json['id']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      method: json['method']?.toString() ?? 'ccp',
      status: json['status']?.toString() ?? 'requested',
      requestedAt: DateTime.tryParse(json['requested_at']?.toString() ?? '') ?? DateTime.now(),
      paidAt: json['paid_at'] != null ? DateTime.tryParse(json['paid_at'].toString()) : null,
      adminNote: json['admin_note']?.toString(),
    );
  }
}

class TeacherEarningsSummary {
  final double availableBalance;
  final List<TeacherLedgerEntry> ledger;
  final List<TeacherPayoutItem> payouts;
  final TeacherRevenueSettings settings;

  const TeacherEarningsSummary({
    required this.availableBalance,
    required this.ledger,
    required this.payouts,
    required this.settings,
  });

  /// Gains acquis mais encore sous délai de rétention (holdback).
  double get pendingBalance => ledger
      .where((e) => !e.isAvailable && e.status != 'clawed_back')
      .fold(0.0, (sum, e) => sum + e.earnings);

  /// Total cumulé généré par les publications, toutes périodes confondues.
  double get lifetimeEarnings =>
      ledger.where((e) => e.status != 'clawed_back').fold(0.0, (sum, e) => sum + e.earnings);

  /// Somme des retraits non refusés (déjà réservés sur le solde).
  double get reservedPayouts => payouts
      .where((p) => p.status == 'requested' || p.status == 'approved' || p.status == 'paid')
      .fold(0.0, (sum, p) => sum + p.amount);

  static const empty = TeacherEarningsSummary(
    availableBalance: 0,
    ledger: [],
    payouts: [],
    settings: TeacherRevenueSettings(),
  );
}

/// Validation côté client de la même règle que la fonction SQL
/// `request_teacher_payout` (le serveur reste l'autorité).
String? validatePayoutAmount({
  required double amount,
  required double availableBalance,
  required double minAmount,
}) {
  if (amount.isNaN || amount <= 0) return 'Montant invalide.';
  if (amount < minAmount) {
    return 'Le retrait minimum est de ${minAmount.toStringAsFixed(0)} DZD.';
  }
  if (amount > availableBalance) {
    return 'Montant supérieur à votre solde disponible.';
  }
  return null;
}

/// Formatage monétaire algérien : 65 000 DZD.
String formatDzd(double amount) {
  final rounded = amount.round();
  final digits = rounded.abs().toString();
  final buffer = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    final fromEnd = digits.length - i;
    buffer.write(digits[i]);
    if (fromEnd > 1 && fromEnd % 3 == 1) buffer.write(' ');
  }
  return '${rounded < 0 ? '-' : ''}${buffer.toString()} DZD';
}
