import 'package:equatable/equatable.dart';
import '../../../../core/constants/app_constants.dart';

class UserModel extends Equatable {
  final String id;
  final String fullName;
  final String email;
  final String medicalRole;
  final String faculty;
  final SubscriptionTier tier;
  final DateTime subscriptionExpiry;
  final String token;
  final bool isAdmin;
  final bool isBanned;
  final String? banReason;
  final int rejectedPaymentsCount;
  final int? studyYear; // 1 à 6 pour les étudiants en médecine

  const UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.medicalRole,
    required this.faculty,
    required this.tier,
    required this.subscriptionExpiry,
    required this.token,
    this.isAdmin = false,
    this.isBanned = false,
    this.banReason,
    this.rejectedPaymentsCount = 0,
    this.studyYear,
  });

  bool get isStudent {
    final role = medicalRole.toLowerCase();
    return role.contains('étudiant') ||
        role.contains('etudiant') ||
        role.contains('externe') ||
        (studyYear != null && studyYear! >= 1 && studyYear! <= 6);
  }

  bool get isInternOrDoctor {
    final role = medicalRole.toLowerCase();
    return role.contains('interne') ||
        role.contains('médecin') ||
        role.contains('medecin') ||
        role.contains('praticien') ||
        role.contains('résident') ||
        role.contains('resident');
  }

  bool get isResidencyCandidate {
    final role = medicalRole.toLowerCase();
    return role.contains('candidat') ||
        role.contains('concours') ||
        (role.contains('résidanat') && !role.contains('médecin résid'));
  }

  bool get isSubscriptionActive {
    return !isBanned && DateTime.now().isBefore(subscriptionExpiry);
  }

  int get daysRemaining {
    if (isBanned) return 0;
    final diff = subscriptionExpiry.difference(DateTime.now()).inDays;
    return diff > 0 ? diff : 0;
  }

  UserModel copyWith({
    String? id,
    String? fullName,
    String? email,
    String? medicalRole,
    String? faculty,
    SubscriptionTier? tier,
    DateTime? subscriptionExpiry,
    String? token,
    bool? isAdmin,
    bool? isBanned,
    String? banReason,
    int? rejectedPaymentsCount,
    int? studyYear,
  }) {
    return UserModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      medicalRole: medicalRole ?? this.medicalRole,
      faculty: faculty ?? this.faculty,
      tier: tier ?? this.tier,
      subscriptionExpiry: subscriptionExpiry ?? this.subscriptionExpiry,
      token: token ?? this.token,
      isAdmin: isAdmin ?? this.isAdmin,
      isBanned: isBanned ?? this.isBanned,
      banReason: banReason ?? this.banReason,
      rejectedPaymentsCount: rejectedPaymentsCount ?? this.rejectedPaymentsCount,
      studyYear: studyYear ?? this.studyYear,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'full_name': fullName,
      'email': email,
      'medicalRole': medicalRole,
      'medical_role': medicalRole,
      'faculty': faculty,
      'tier': tier.id,
      'subscriptionExpiry': subscriptionExpiry.toIso8601String(),
      'token': token,
      'isAdmin': isAdmin,
      'is_admin': isAdmin,
      'isBanned': isBanned,
      'is_banned': isBanned,
      'banReason': banReason,
      'ban_reason': banReason,
      'rejectedPaymentsCount': rejectedPaymentsCount,
      'rejected_payments_count': rejectedPaymentsCount,
      'studyYear': studyYear,
      'study_year': studyYear,
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    SubscriptionTier parseTier(String? val) {
      switch (val) {
        case AppConstants.tierEtudiant:
          return SubscriptionTier.etudiant;
        case AppConstants.tierClinicalPro:
          return SubscriptionTier.clinicalPro;
        case AppConstants.tierResidentElite:
          return SubscriptionTier.residentElite;
        case AppConstants.tierAllAccess:
          return SubscriptionTier.allAccess;
        default:
          return SubscriptionTier.free;
      }
    }

    final isAdm = json['isAdmin'] == true || json['is_admin'] == true;
    final isBan = json['isBanned'] == true || json['is_banned'] == true;
    final reason = json['banReason'] ?? json['ban_reason'];
    final rejections = (json['rejectedPaymentsCount'] ?? json['rejected_payments_count'] as num?)?.toInt() ?? 0;
    
    // Parse study year from direct property or derive from role
    int? year = (json['studyYear'] ?? json['study_year'] as num?)?.toInt();
    if (year == null) {
      final role = (json['medicalRole'] ?? json['medical_role'] ?? '').toString();
      final match = RegExp(r'([1-6])(?:[eè]re|[eè]me)?\s*ann[eé]e', caseSensitive: false).firstMatch(role);
      if (match != null) {
        year = int.tryParse(match.group(1) ?? '');
      }
    }

    return UserModel(
      id: json['id'] ?? '',
      fullName: json['fullName'] ?? json['full_name'] ?? '',
      email: json['email'] ?? '',
      medicalRole: json['medicalRole'] ?? json['medical_role'] ?? 'Candidat Résidanat',
      faculty: json['faculty'] ?? 'Faculté de Médecine de Blida',
      tier: parseTier(json['tier']),
      subscriptionExpiry: json['subscriptionExpiry'] != null
          ? DateTime.tryParse(json['subscriptionExpiry']) ?? DateTime.now().add(const Duration(days: 30))
          : DateTime.now().add(const Duration(days: 30)),
      token: json['token'] ?? '',
      isAdmin: isAdm,
      isBanned: isBan,
      banReason: reason,
      rejectedPaymentsCount: rejections,
      studyYear: year,
    );
  }

  @override
  List<Object?> get props => [
        id,
        fullName,
        email,
        medicalRole,
        faculty,
        tier,
        subscriptionExpiry,
        token,
        isAdmin,
        isBanned,
        banReason,
        rejectedPaymentsCount,
        studyYear,
      ];
}
