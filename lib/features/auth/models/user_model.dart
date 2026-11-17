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
  final bool _isAdmin;
  bool get isAdmin => _isAdmin || email.trim().toLowerCase() == 'doc.hafedh26@gmail.com';
  final bool isBetaTester;
  bool get canAccessBetaChannel => isAdmin || isBetaTester;
  final bool isBanned;
  final String? banReason;
  final bool isInactiveSuspended;
  final DateTime? inactiveSuspendedAt;
  final DateTime? lastReactivatedAt;
  final int reactivationCount;
  final int rejectedPaymentsCount;
  final int? studyYear; // 1 à 6 pour les étudiants en médecine
  final String? avatarUrl;
  final String? bio;
  final String? phone;
  final String? wilaya;
  final String? residencyTargetYear; // Ex: '2027', '2028'

  /// Grade académique vérifié par l'administration (resident, assistant,
  /// maitreAssistant, mca, professeur). `null` si non vérifié.
  final String? teacherRank;

  /// Vrai uniquement si l'administration a validé le grade académique.
  final bool teacherVerified;

  const UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.medicalRole,
    required this.faculty,
    required this.tier,
    required this.subscriptionExpiry,
    required this.token,
    bool isAdmin = false,
    this.isBetaTester = false,
    this.isBanned = false,
    this.banReason,
    this.isInactiveSuspended = false,
    this.inactiveSuspendedAt,
    this.lastReactivatedAt,
    this.reactivationCount = 0,
    this.rejectedPaymentsCount = 0,
    this.studyYear,
    this.avatarUrl,
    this.bio,
    this.phone,
    this.wilaya,
    this.residencyTargetYear,
    this.teacherRank,
    this.teacherVerified = false,
  }) : _isAdmin = isAdmin;

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

  /// Grades habilités à publier dans l'Espace Prof (décision produit) :
  /// Professeur, MCA, Maître-Assistant, Assistant HU et Résident.
  static const Set<String> publishableTeacherRanks = {
    'resident',
    'assistant',
    'maitreAssistant',
    'mca',
    'professeur',
  };

  /// Grade académique vérifié par l'administration. Un grade simplement
  /// déclaré dans le profil ne suffit pas.
  bool get isVerifiedTeacher => teacherVerified && (teacherRank?.isNotEmpty ?? false);

  /// Autorisation de publier cours, fiches, mindmaps, flashcards et examens.
  /// Les administrateurs conservent l'accès pour la modération.
  bool get canPublishTeacherContent {
    if (isAdmin) return true;
    return teacherVerified && publishableTeacherRanks.contains(teacherRank);
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
    bool? isBetaTester,
    bool? isBanned,
    String? banReason,
    bool? isInactiveSuspended,
    DateTime? inactiveSuspendedAt,
    DateTime? lastReactivatedAt,
    int? reactivationCount,
    int? rejectedPaymentsCount,
    int? studyYear,
    String? avatarUrl,
    String? bio,
    String? phone,
    String? wilaya,
    String? residencyTargetYear,
    String? teacherRank,
    bool? teacherVerified,
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
      isBetaTester: isBetaTester ?? this.isBetaTester,
      isBanned: isBanned ?? this.isBanned,
      banReason: banReason ?? this.banReason,
      isInactiveSuspended: isInactiveSuspended ?? this.isInactiveSuspended,
      inactiveSuspendedAt: inactiveSuspendedAt ?? this.inactiveSuspendedAt,
      lastReactivatedAt: lastReactivatedAt ?? this.lastReactivatedAt,
      reactivationCount: reactivationCount ?? this.reactivationCount,
      rejectedPaymentsCount: rejectedPaymentsCount ?? this.rejectedPaymentsCount,
      studyYear: studyYear ?? this.studyYear,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      phone: phone ?? this.phone,
      wilaya: wilaya ?? this.wilaya,
      residencyTargetYear: residencyTargetYear ?? this.residencyTargetYear,
      teacherRank: teacherRank ?? this.teacherRank,
      teacherVerified: teacherVerified ?? this.teacherVerified,
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
      'isBetaTester': isBetaTester,
      'is_beta_tester': isBetaTester,
      'isBanned': isBanned,
      'is_banned': isBanned,
      'banReason': banReason,
      'ban_reason': banReason,
      'isInactiveSuspended': isInactiveSuspended,
      'is_inactive_suspended': isInactiveSuspended,
      'inactiveSuspendedAt': inactiveSuspendedAt?.toIso8601String(),
      'inactive_suspended_at': inactiveSuspendedAt?.toIso8601String(),
      'lastReactivatedAt': lastReactivatedAt?.toIso8601String(),
      'last_reactivated_at': lastReactivatedAt?.toIso8601String(),
      'reactivationCount': reactivationCount,
      'reactivation_count': reactivationCount,
      'rejectedPaymentsCount': rejectedPaymentsCount,
      'rejected_payments_count': rejectedPaymentsCount,
      'studyYear': studyYear,
      'study_year': studyYear,
      'avatarUrl': avatarUrl,
      'avatar_url': avatarUrl,
      'bio': bio,
      'phone': phone,
      'wilaya': wilaya,
      'residencyTargetYear': residencyTargetYear,
      'residency_target_year': residencyTargetYear,
      'teacherRank': teacherRank,
      'teacher_rank': teacherRank,
      'teacherVerified': teacherVerified,
      'teacher_verified': teacherVerified,
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

    final emailVal = (json['email'] ?? '').toString().trim().toLowerCase();
    final isAdm = json['isAdmin'] == true || json['is_admin'] == true || emailVal == 'doc.hafedh26@gmail.com';
    final isBeta = json['isBetaTester'] == true || json['is_beta_tester'] == true;
    final isBan = json['isBanned'] == true || json['is_banned'] == true;
    final reason = json['banReason'] ?? json['ban_reason'];
    final isInactiveSusp = json['isInactiveSuspended'] == true ||
        json['is_inactive_suspended'] == true ||
        (isBan && (reason?.toString().toLowerCase().contains('inactiv') ?? false));
    final inactiveAtStr = json['inactiveSuspendedAt'] ?? json['inactive_suspended_at'];
    final reactivatedAtStr = json['lastReactivatedAt'] ?? json['last_reactivated_at'];
    final reactCount = (json['reactivationCount'] ?? json['reactivation_count'] as num?)?.toInt() ?? 0;
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
      isBetaTester: isBeta,
      isBanned: isBan,
      banReason: reason,
      isInactiveSuspended: isInactiveSusp,
      inactiveSuspendedAt: inactiveAtStr != null ? DateTime.tryParse(inactiveAtStr.toString()) : null,
      lastReactivatedAt: reactivatedAtStr != null ? DateTime.tryParse(reactivatedAtStr.toString()) : null,
      reactivationCount: reactCount,
      rejectedPaymentsCount: rejections,
      studyYear: year,
      avatarUrl: json['avatarUrl'] ?? json['avatar_url'],
      bio: json['bio'],
      phone: json['phone'],
      wilaya: json['wilaya'],
      residencyTargetYear: json['residencyTargetYear'] ?? json['residency_target_year'],
      teacherRank: (json['teacherRank'] ?? json['teacher_rank'])?.toString(),
      teacherVerified: json['teacherVerified'] == true || json['teacher_verified'] == true,
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
        isBetaTester,
        isBanned,
        banReason,
        isInactiveSuspended,
        inactiveSuspendedAt,
        lastReactivatedAt,
        reactivationCount,
        rejectedPaymentsCount,
        studyYear,
        avatarUrl,
        bio,
        phone,
        wilaya,
        residencyTargetYear,
        teacherRank,
        teacherVerified,
      ];
}
