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
  final int octeniumTotalDownloads;
  final int octeniumApkDownloads;
  final int octeniumWindowsDownloads;
  final int octeniumWebVisits;
  final DateTime? octeniumLastDownloadAt;

  const AdminMetrics({
    required this.totalUsers,
    required this.freeTrials,
    required this.clinicalPro,
    required this.residentElite,
    required this.allAccess,
    required this.totalLicenses,
    required this.redeemedLicenses,
    required this.availableLicenses,
    this.octeniumTotalDownloads = 0,
    this.octeniumApkDownloads = 0,
    this.octeniumWindowsDownloads = 0,
    this.octeniumWebVisits = 0,
    this.octeniumLastDownloadAt,
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
      octeniumTotalDownloads: (json['octenium_total_downloads'] as num?)?.toInt() ?? 0,
      octeniumApkDownloads: (json['octenium_apk_downloads'] as num?)?.toInt() ?? 0,
      octeniumWindowsDownloads: (json['octenium_windows_downloads'] as num?)?.toInt() ?? 0,
      octeniumWebVisits: (json['octenium_web_visits'] as num?)?.toInt() ?? 0,
      octeniumLastDownloadAt: json['octenium_last_download_at'] != null
          ? DateTime.tryParse(json['octenium_last_download_at'].toString())
          : null,
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
        octeniumTotalDownloads,
        octeniumApkDownloads,
        octeniumWindowsDownloads,
        octeniumWebVisits,
        octeniumLastDownloadAt,
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
  final bool isBanned;
  final String? banReason;
  final int rejectedPaymentsCount;
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
    this.isBanned = false,
    this.banReason,
    this.rejectedPaymentsCount = 0,
    this.createdAt,
  });

  factory AdminUserItem.fromJson(Map<String, dynamic> json) {
    final isBan = json['is_banned'] == true || json['isBanned'] == true;
    final reason = json['ban_reason'] ?? json['banReason'];
    final rejections = (json['rejected_payments_count'] ?? json['rejectedPaymentsCount'] as num?)?.toInt() ?? 0;

    return AdminUserItem(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      fullName: json['full_name'] ?? json['email'] ?? 'Médecin',
      medicalRole: json['medical_role'] ?? 'Candidat Résidanat',
      faculty: json['faculty'] ?? 'Faculté de Médecine de Blida',
      tier: json['tier'] ?? 'free',
      status: json['status'] ?? (isBan ? 'suspended' : 'active'),
      expiresAt: json['expires_at'] != null ? DateTime.tryParse(json['expires_at']) : null,
      isAdmin: json['is_admin'] == true,
      isBanned: isBan,
      banReason: reason,
      rejectedPaymentsCount: rejections,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
    );
  }

  @override
  List<Object?> get props => [id, email, fullName, medicalRole, faculty, tier, status, expiresAt, isAdmin, isBanned, banReason, rejectedPaymentsCount, createdAt];
}

class AdminLicenseItem extends Equatable {
  final String keyCode;
  final String tier;
  final int durationDays;
  final bool isRedeemed;
  final String? redeemedBy;
  final DateTime? redeemedAt;
  final DateTime? createdAt;
  final String? redeemedUserName;
  final String? redeemedUserEmail;
  final String? redeemedUserRole;
  final DateTime? expiresAt;
  final bool isExpired;
  final int daysRemaining;
  final bool isRevoked;
  final DateTime? revokedAt;
  final String? revocationReason;

  const AdminLicenseItem({
    required this.keyCode,
    required this.tier,
    required this.durationDays,
    required this.isRedeemed,
    this.redeemedBy,
    this.redeemedAt,
    this.createdAt,
    this.redeemedUserName,
    this.redeemedUserEmail,
    this.redeemedUserRole,
    this.expiresAt,
    this.isExpired = false,
    this.daysRemaining = 0,
    this.isRevoked = false,
    this.revokedAt,
    this.revocationReason,
  });

  factory AdminLicenseItem.fromJson(Map<String, dynamic> json) {
    final redeemedAtDate = json['redeemed_at'] != null ? DateTime.tryParse(json['redeemed_at'].toString()) : null;
    final createdAtDate = json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null;
    final revokedAtDate = json['revoked_at'] != null ? DateTime.tryParse(json['revoked_at'].toString()) : null;
    final duration = (json['duration_days'] as num?)?.toInt() ?? 365;
    final isRedeemed = json['is_redeemed'] == true;
    final isRevoked = json['is_revoked'] == true;
    final reason = json['revocation_reason']?.toString();

    // Compute expiration date if not provided directly
    DateTime? expDate;
    if (json['expires_at'] != null) {
      expDate = DateTime.tryParse(json['expires_at'].toString());
    } else if (isRedeemed && redeemedAtDate != null) {
      expDate = redeemedAtDate.add(Duration(days: duration));
    }

    final isExp = isRevoked || json['is_expired'] == true || (expDate != null && DateTime.now().isAfter(expDate));
    int remaining = 0;
    if (isRevoked) {
      remaining = 0;
    } else if (json['days_remaining'] != null) {
      remaining = (json['days_remaining'] as num).toInt();
    } else if (expDate != null) {
      final diff = expDate.difference(DateTime.now()).inDays;
      remaining = diff > 0 ? diff : 0;
    } else {
      remaining = duration;
    }

    return AdminLicenseItem(
      keyCode: json['key_code'] ?? '',
      tier: json['tier'] ?? 'all_access',
      durationDays: duration,
      isRedeemed: isRedeemed,
      redeemedBy: json['redeemed_by']?.toString(),
      redeemedAt: redeemedAtDate,
      createdAt: createdAtDate,
      redeemedUserName: json['redeemed_user_name'] ?? json['user_full_name'] ?? json['full_name'],
      redeemedUserEmail: json['redeemed_user_email'] ?? json['user_email'] ?? json['email'],
      redeemedUserRole: json['redeemed_user_role'] ?? json['medical_role'],
      expiresAt: expDate,
      isExpired: isExp,
      daysRemaining: remaining,
      isRevoked: isRevoked,
      revokedAt: revokedAtDate,
      revocationReason: reason,
    );
  }

  @override
  List<Object?> get props => [
        keyCode,
        tier,
        durationDays,
        isRedeemed,
        redeemedBy,
        redeemedAt,
        createdAt,
        redeemedUserName,
        redeemedUserEmail,
        redeemedUserRole,
        expiresAt,
        isExpired,
        daysRemaining,
        isRevoked,
        revokedAt,
        revocationReason,
      ];
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
  final String? receiptUrl;
  final String? receiptFileName;
  final String status; // 'pending', 'approved', 'rejected'
  final String paymentType; // 'subscription', 'quota_topup'
  final int bonusCredits; // e.g. 50, 150, 500
  final String? adminNotes;
  final bool isArchived;
  final String? archiveDriveUrl;
  final String? archiveDriveFolder;
  final DateTime? archivedAt;
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
    this.receiptUrl,
    this.receiptFileName,
    required this.status,
    this.paymentType = 'subscription',
    this.bonusCredits = 0,
    this.adminNotes,
    this.isArchived = false,
    this.archiveDriveUrl,
    this.archiveDriveFolder,
    this.archivedAt,
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
      receiptUrl: json['receipt_url'],
      receiptFileName: json['receipt_file_name'],
      status: json['status'] ?? 'pending',
      paymentType: json['payment_type'] ?? 'subscription',
      bonusCredits: (json['bonus_credits'] as num?)?.toInt() ?? 0,
      adminNotes: json['admin_notes'],
      isArchived: json['is_archived'] == true,
      archiveDriveUrl: json['archive_drive_url'],
      archiveDriveFolder: json['archive_drive_folder'],
      archivedAt: json['archived_at'] != null ? DateTime.tryParse(json['archived_at']) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) ?? DateTime.now() : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null,
    );
  }

  PaymentItem copyWith({
    String? status,
    String? paymentType,
    int? bonusCredits,
    String? adminNotes,
    String? receiptUrl,
    String? receiptFileName,
    bool? isArchived,
    String? archiveDriveUrl,
    String? archiveDriveFolder,
    DateTime? archivedAt,
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
      receiptUrl: receiptUrl ?? this.receiptUrl,
      receiptFileName: receiptFileName ?? this.receiptFileName,
      status: status ?? this.status,
      paymentType: paymentType ?? this.paymentType,
      bonusCredits: bonusCredits ?? this.bonusCredits,
      adminNotes: adminNotes ?? this.adminNotes,
      isArchived: isArchived ?? this.isArchived,
      archiveDriveUrl: archiveDriveUrl ?? this.archiveDriveUrl,
      archiveDriveFolder: archiveDriveFolder ?? this.archiveDriveFolder,
      archivedAt: archivedAt ?? this.archivedAt,
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
        receiptUrl,
        receiptFileName,
        status,
        paymentType,
        bonusCredits,
        adminNotes,
        isArchived,
        archiveDriveUrl,
        archiveDriveFolder,
        archivedAt,
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

class AdminFacebookPrompt extends Equatable {
  final String id;
  final String topic;
  final String postType; // 'commercial', 'medical', 'auto'
  final String title;
  final String summary;
  final String fullPrompt;
  final String suggestedMockup;
  final String theme;
  final String status;
  final DateTime createdAt;
  final Map<String, dynamic> metadata;

  const AdminFacebookPrompt({
    required this.id,
    required this.topic,
    required this.postType,
    required this.title,
    required this.summary,
    required this.fullPrompt,
    this.suggestedMockup = 'desktop',
    this.theme = 'blue',
    this.status = 'pending',
    required this.createdAt,
    this.metadata = const {},
  });

  bool get isCommercial => postType.toLowerCase() == 'commercial';
  bool get isMedical => postType.toLowerCase() == 'medical';

  String get formattedCreatedAt {
    final d = createdAt.day.toString().padLeft(2, '0');
    final m = createdAt.month.toString().padLeft(2, '0');
    final y = createdAt.year.toString();
    final h = createdAt.hour.toString().padLeft(2, '0');
    final min = createdAt.minute.toString().padLeft(2, '0');
    return '$d/$m/$y à $h:$min';
  }

  factory AdminFacebookPrompt.fromJson(Map<String, dynamic> json) {
    return AdminFacebookPrompt(
      id: json['id']?.toString() ?? '',
      topic: json['topic']?.toString() ?? '',
      postType: json['post_type']?.toString() ?? json['type']?.toString() ?? 'auto',
      title: json['title']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      fullPrompt: json['full_prompt']?.toString() ?? json['prompt']?.toString() ?? '',
      suggestedMockup: json['suggested_mockup']?.toString() ?? 'desktop',
      theme: json['theme']?.toString() ?? 'blue',
      status: json['status']?.toString() ?? 'pending',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      metadata: json['metadata'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['metadata'])
          : const {},
    );
  }

  @override
  List<Object?> get props => [
        id,
        topic,
        postType,
        title,
        summary,
        fullPrompt,
        suggestedMockup,
        theme,
        status,
        createdAt,
        metadata,
      ];
}

