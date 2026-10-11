import 'package:equatable/equatable.dart';

class AdminMetrics extends Equatable {
  final int totalUsers;
  final int freeTrials;
  final int clinicalPro;
  final int residentElite;
  final int allAccess;
  final int totalLicenses;
  final int redeemedLicenses;
  final int availableLicenses;

  const AdminMetrics({
    required this.totalUsers,
    required this.freeTrials,
    required this.clinicalPro,
    required this.residentElite,
    required this.allAccess,
    required this.totalLicenses,
    required this.redeemedLicenses,
    required this.availableLicenses,
  });

  factory AdminMetrics.fromJson(Map<String, dynamic> json) {
    return AdminMetrics(
      totalUsers: json['total_users'] ?? 0,
      freeTrials: json['free_trials'] ?? 0,
      clinicalPro: json['clinical_pro'] ?? 0,
      residentElite: json['resident_elite'] ?? 0,
      allAccess: json['all_access'] ?? 0,
      totalLicenses: json['total_licenses'] ?? 0,
      redeemedLicenses: json['redeemed_licenses'] ?? 0,
      availableLicenses: json['available_licenses'] ?? 0,
    );
  }

  @override
  List<Object?> get props => [
        totalUsers,
        freeTrials,
        clinicalPro,
        residentElite,
        allAccess,
        totalLicenses,
        redeemedLicenses,
        availableLicenses,
      ];
}

class AdminUserItem extends Equatable {
  final String id;
  final String email;
  final String fullName;
  final String medicalRole;
  final String faculty;
  final String tier;
  final String status;
  final DateTime? expiresAt;
  final bool isAdmin;
  final DateTime? createdAt;

  const AdminUserItem({
    required this.id,
    required this.email,
    required this.fullName,
    required this.medicalRole,
    required this.faculty,
    required this.tier,
    required this.status,
    this.expiresAt,
    this.isAdmin = false,
    this.createdAt,
  });

  factory AdminUserItem.fromJson(Map<String, dynamic> json) {
    return AdminUserItem(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      fullName: json['full_name'] ?? json['email'] ?? 'Médecin',
      medicalRole: json['medical_role'] ?? 'Candidat Résidanat',
      faculty: json['faculty'] ?? 'Faculté de Médecine de Blida',
      tier: json['tier'] ?? 'free',
      status: json['status'] ?? 'active',
      expiresAt: json['expires_at'] != null ? DateTime.tryParse(json['expires_at']) : null,
      isAdmin: json['is_admin'] == true,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
    );
  }

  @override
  List<Object?> get props => [id, email, fullName, medicalRole, faculty, tier, status, expiresAt, isAdmin, createdAt];
}

class AdminLicenseItem extends Equatable {
  final String keyCode;
  final String tier;
  final int durationDays;
  final bool isRedeemed;
  final String? redeemedBy;
  final DateTime? redeemedAt;
  final DateTime? createdAt;

  const AdminLicenseItem({
    required this.keyCode,
    required this.tier,
    required this.durationDays,
    required this.isRedeemed,
    this.redeemedBy,
    this.redeemedAt,
    this.createdAt,
  });

  factory AdminLicenseItem.fromJson(Map<String, dynamic> json) {
    return AdminLicenseItem(
      keyCode: json['key_code'] ?? '',
      tier: json['tier'] ?? 'all_access',
      durationDays: json['duration_days'] ?? 365,
      isRedeemed: json['is_redeemed'] == true,
      redeemedBy: json['redeemed_by'],
      redeemedAt: json['redeemed_at'] != null ? DateTime.tryParse(json['redeemed_at']) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
    );
  }

  @override
  List<Object?> get props => [keyCode, tier, durationDays, isRedeemed, redeemedBy, redeemedAt, createdAt];
}

class SubscriptionPlanItem extends Equatable {
  final String id;
  final String name;
  final String badge;
  final double priceYearly;
  final double priceMonthly;
  final String currency;
  final int discountPercent;
  final bool isActive;
  final List<String> features;
  final DateTime? updatedAt;

  const SubscriptionPlanItem({
    required this.id,
    required this.name,
    required this.badge,
    required this.priceYearly,
    required this.priceMonthly,
    this.currency = 'DZD',
    this.discountPercent = 0,
    this.isActive = true,
    this.features = const [],
    this.updatedAt,
  });

  factory SubscriptionPlanItem.fromJson(Map<String, dynamic> json) {
    List<String> feats = [];
    if (json['features'] != null) {
      if (json['features'] is List) {
        feats = (json['features'] as List).map((e) => e.toString()).toList();
      }
    }

    return SubscriptionPlanItem(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      badge: json['badge'] ?? '',
      priceYearly: (json['price_yearly'] as num?)?.toDouble() ?? 0.0,
      priceMonthly: (json['price_monthly'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] ?? 'DZD',
      discountPercent: (json['discount_percent'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] ?? true,
      features: feats,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'badge': badge,
      'price_yearly': priceYearly,
      'price_monthly': priceMonthly,
      'currency': currency,
      'discount_percent': discountPercent,
      'is_active': isActive,
      'features': features,
    };
  }

  SubscriptionPlanItem copyWith({
    String? name,
    String? badge,
    double? priceYearly,
    double? priceMonthly,
    int? discountPercent,
    bool? isActive,
    List<String>? features,
  }) {
    return SubscriptionPlanItem(
      id: id,
      name: name ?? this.name,
      badge: badge ?? this.badge,
      priceYearly: priceYearly ?? this.priceYearly,
      priceMonthly: priceMonthly ?? this.priceMonthly,
      currency: currency,
      discountPercent: discountPercent ?? this.discountPercent,
      isActive: isActive ?? this.isActive,
      features: features ?? this.features,
      updatedAt: DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [id, name, badge, priceYearly, priceMonthly, currency, discountPercent, isActive, features, updatedAt];
}

class PaymentItem extends Equatable {
  final String id;
  final String? userId;
  final String userEmail;
  final String userName;
  final String tier;
  final int durationDays;
  final double amount;
  final String currency;
  final String paymentMethod;
  final String? receiptReference;
  final String status; // 'pending', 'approved', 'rejected'
  final String? adminNotes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const PaymentItem({
    required this.id,
    this.userId,
    required this.userEmail,
    required this.userName,
    required this.tier,
    required this.durationDays,
    required this.amount,
    this.currency = 'DZD',
    required this.paymentMethod,
    this.receiptReference,
    required this.status,
    this.adminNotes,
    required this.createdAt,
    this.updatedAt,
  });

  factory PaymentItem.fromJson(Map<String, dynamic> json) {
    return PaymentItem(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString(),
      userEmail: json['user_email'] ?? '',
      userName: json['user_name'] ?? json['user_email'] ?? 'Médecin',
      tier: json['tier'] ?? 'all_access',
      durationDays: (json['duration_days'] as num?)?.toInt() ?? 365,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] ?? 'DZD',
      paymentMethod: json['payment_method'] ?? 'baridimob',
      receiptReference: json['receipt_reference'],
      status: json['status'] ?? 'pending',
      adminNotes: json['admin_notes'],
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) ?? DateTime.now() : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null,
    );
  }

  PaymentItem copyWith({
    String? status,
    String? adminNotes,
  }) {
    return PaymentItem(
      id: id,
      userId: userId,
      userEmail: userEmail,
      userName: userName,
      tier: tier,
      durationDays: durationDays,
      amount: amount,
      currency: currency,
      paymentMethod: paymentMethod,
      receiptReference: receiptReference,
      status: status ?? this.status,
      adminNotes: adminNotes ?? this.adminNotes,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        userEmail,
        userName,
        tier,
        durationDays,
        amount,
        currency,
        paymentMethod,
        receiptReference,
        status,
        adminNotes,
        createdAt,
        updatedAt,
      ];
}

class FinancialMetrics extends Equatable {
  final double totalRevenue;
  final double pendingRevenue;
  final int totalTransactions;
  final int approvedCount;
  final int pendingCount;
  final int rejectedCount;

  const FinancialMetrics({
    required this.totalRevenue,
    required this.pendingRevenue,
    required this.totalTransactions,
    required this.approvedCount,
    required this.pendingCount,
    required this.rejectedCount,
  });

  factory FinancialMetrics.fromPayments(List<PaymentItem> list) {
    double total = 0;
    double pending = 0;
    int approved = 0;
    int pend = 0;
    int rej = 0;

    for (final p in list) {
      if (p.status == 'approved') {
        total += p.amount;
        approved++;
      } else if (p.status == 'pending') {
        pending += p.amount;
        pend++;
      } else if (p.status == 'rejected') {
        rej++;
      }
    }

    return FinancialMetrics(
      totalRevenue: total,
      pendingRevenue: pending,
      totalTransactions: list.length,
      approvedCount: approved,
      pendingCount: pend,
      rejectedCount: rej,
    );
  }

  @override
  List<Object?> get props => [totalRevenue, pendingRevenue, totalTransactions, approvedCount, pendingCount, rejectedCount];
}

class AnnouncementItem extends Equatable {
  final String id;
  final String title;
  final String message;
  final String type; // 'info', 'warning', 'urgent', 'success'
  final bool isActive;
  final DateTime createdAt;

  const AnnouncementItem({
    required this.id,
    required this.title,
    required this.message,
    this.type = 'info',
    this.isActive = true,
    required this.createdAt,
  });

  factory AnnouncementItem.fromJson(Map<String, dynamic> json) {
    return AnnouncementItem(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      type: json['type'] ?? 'info',
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) ?? DateTime.now() : DateTime.now(),
    );
  }

  AnnouncementItem copyWith({
    String? title,
    String? message,
    String? type,
    bool? isActive,
  }) {
    return AnnouncementItem(
      id: id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [id, title, message, type, isActive, createdAt];
}

