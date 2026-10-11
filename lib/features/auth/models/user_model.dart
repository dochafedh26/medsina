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
  });

  bool get isSubscriptionActive {
    return DateTime.now().isBefore(subscriptionExpiry);
  }

  int get daysRemaining {
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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'email': email,
      'medicalRole': medicalRole,
      'faculty': faculty,
      'tier': tier.id,
      'subscriptionExpiry': subscriptionExpiry.toIso8601String(),
      'token': token,
      'isAdmin': isAdmin,
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    SubscriptionTier parseTier(String? val) {
      switch (val) {
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

    return UserModel(
      id: json['id'] ?? '',
      fullName: json['fullName'] ?? '',
      email: json['email'] ?? '',
      medicalRole: json['medicalRole'] ?? 'Candidat Résidanat',
      faculty: json['faculty'] ?? 'Faculté de Médecine de Blida',
      tier: parseTier(json['tier']),
      subscriptionExpiry: json['subscriptionExpiry'] != null
          ? DateTime.tryParse(json['subscriptionExpiry']) ?? DateTime.now().add(const Duration(days: 30))
          : DateTime.now().add(const Duration(days: 30)),
      token: json['token'] ?? '',
      isAdmin: isAdm,
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
      ];
}
