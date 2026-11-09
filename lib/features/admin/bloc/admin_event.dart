import 'package:equatable/equatable.dart';

abstract class AdminEvent extends Equatable {
  const AdminEvent();

  @override
  List<Object?> get props => [];
}

class LoadAdminDataEvent extends AdminEvent {}

class SearchUsersEvent extends AdminEvent {
  final String query;
  const SearchUsersEvent(this.query);

  @override
  List<Object?> get props => [query];
}

class GenerateLicenseKeyEvent extends AdminEvent {
  final String keyCode;
  final String tier;
  final int durationDays;

  const GenerateLicenseKeyEvent({
    required this.keyCode,
    required this.tier,
    required this.durationDays,
  });

  @override
  List<Object?> get props => [keyCode, tier, durationDays];
}

class UpgradeUserSubscriptionEvent extends AdminEvent {
  final String userId;
  final String tier;
  final int durationDays;
  final String calculationMode; // 'replace', 'extend', 'exact_date'
  final DateTime? targetExpiresAt;

  const UpgradeUserSubscriptionEvent({
    required this.userId,
    required this.tier,
    required this.durationDays,
    this.calculationMode = 'replace',
    this.targetExpiresAt,
  });

  @override
  List<Object?> get props => [userId, tier, durationDays, calculationMode, targetExpiresAt];
}

class ClearAdminMessageEvent extends AdminEvent {}

class UpdatePlanPriceEvent extends AdminEvent {
  final String planId;
  final double priceYearly;
  final double priceMonthly;
  final int discountPercent;
  final String badge;
  final bool isActive;

  const UpdatePlanPriceEvent({
    required this.planId,
    required this.priceYearly,
    required this.priceMonthly,
    required this.discountPercent,
    required this.badge,
    required this.isActive,
  });

  @override
  List<Object?> get props => [planId, priceYearly, priceMonthly, discountPercent, badge, isActive];
}

class ApprovePaymentEvent extends AdminEvent {
  final String paymentId;
  final String? userId;
  final String tier;
  final int durationDays;
  final String? adminNotes;

  const ApprovePaymentEvent({
    required this.paymentId,
    this.userId,
    required this.tier,
    required this.durationDays,
    this.adminNotes,
  });

  @override
  List<Object?> get props => [paymentId, userId, tier, durationDays, adminNotes];
}

class RejectPaymentEvent extends AdminEvent {
  final String paymentId;
  final String adminNotes;

  const RejectPaymentEvent({
    required this.paymentId,
    required this.adminNotes,
  });

  @override
  List<Object?> get props => [paymentId, adminNotes];
}

class RecordManualPaymentEvent extends AdminEvent {
  final String? userId;
  final String userEmail;
  final String userName;
  final String tier;
  final int durationDays;
  final double amount;
  final String paymentMethod;
  final String receiptReference;
  final String? adminNotes;

  const RecordManualPaymentEvent({
    this.userId,
    required this.userEmail,
    required this.userName,
    required this.tier,
    required this.durationDays,
    required this.amount,
    required this.paymentMethod,
    required this.receiptReference,
    this.adminNotes,
  });

  @override
  List<Object?> get props => [
        userId,
        userEmail,
        userName,
        tier,
        durationDays,
        amount,
        paymentMethod,
        receiptReference,
        adminNotes,
      ];
}

class FilterPaymentsEvent extends AdminEvent {
  final String status;
  const FilterPaymentsEvent(this.status);

  @override
  List<Object?> get props => [status];
}

class CreateAnnouncementEvent extends AdminEvent {
  final String title;
  final String message;
  final String type;

  const CreateAnnouncementEvent({
    required this.title,
    required this.message,
    required this.type,
  });

  @override
  List<Object?> get props => [title, message, type];
}

class ToggleAnnouncementEvent extends AdminEvent {
  final String id;
  final bool isActive;

  const ToggleAnnouncementEvent({
    required this.id,
    required this.isActive,
  });

  @override
  List<Object?> get props => [id, isActive];
}

class DeleteAnnouncementEvent extends AdminEvent {
  final String id;
  const DeleteAnnouncementEvent(this.id);

  @override
  List<Object?> get props => [id];
}

class BanUserEvent extends AdminEvent {
  final String userId;
  final String reason;

  const BanUserEvent({
    required this.userId,
    required this.reason,
  });

  @override
  List<Object?> get props => [userId, reason];
}

class UnbanUserEvent extends AdminEvent {
  final String userId;
  final String? adminNotes;

  const UnbanUserEvent({
    required this.userId,
    this.adminNotes,
  });

  @override
  List<Object?> get props => [userId, adminNotes];
}

class ArchiveEligibleReceiptsEvent extends AdminEvent {
  final int retentionDays;

  const ArchiveEligibleReceiptsEvent({this.retentionDays = 30});

  @override
  List<Object?> get props => [retentionDays];
}

class RevokeLicenseKeyEvent extends AdminEvent {
  final String keyCode;
  final String? reason;

  const RevokeLicenseKeyEvent({
    required this.keyCode,
    this.reason,
  });

  @override
  List<Object?> get props => [keyCode, reason];
}

class UnrevokeLicenseKeyEvent extends AdminEvent {
  final String keyCode;

  const UnrevokeLicenseKeyEvent({required this.keyCode});

  @override
  List<Object?> get props => [keyCode];
}

class UpdateUserSortAndFilterEvent extends AdminEvent {
  final String? sortBy;
  final String? roleFilter;
  final String? tierFilter;
  final String? statusFilter;
  final int? studyYearFilter;
  final bool resetFilters;

  const UpdateUserSortAndFilterEvent({
    this.sortBy,
    this.roleFilter,
    this.tierFilter,
    this.statusFilter,
    this.studyYearFilter,
    this.resetFilters = false,
  });

  @override
  List<Object?> get props => [sortBy, roleFilter, tierFilter, statusFilter, studyYearFilter, resetFilters];
}

class AdminEditUserProfileEvent extends AdminEvent {
  final String userId;
  final String fullName;
  final String medicalRole;
  final String faculty;
  final int? studyYear;
  final String? wilaya;
  final String? phone;
  final String? residencyTargetYear;
  final String? bio;

  const AdminEditUserProfileEvent({
    required this.userId,
    required this.fullName,
    required this.medicalRole,
    required this.faculty,
    this.studyYear,
    this.wilaya,
    this.phone,
    this.residencyTargetYear,
    this.bio,
  });

  @override
  List<Object?> get props => [
        userId,
        fullName,
        medicalRole,
        faculty,
        studyYear,
        wilaya,
        phone,
        residencyTargetYear,
        bio,
      ];
}


