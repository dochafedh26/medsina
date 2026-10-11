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
