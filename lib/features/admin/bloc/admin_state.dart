import 'package:equatable/equatable.dart';
import '../models/admin_models.dart';

enum AdminStatus { initial, loading, loaded, error }

class AdminState extends Equatable {
  final AdminStatus status;
  final AdminMetrics? metrics;
  final List<AdminUserItem> users;
  final List<AdminUserItem> filteredUsers;
  final List<AdminLicenseItem> licenses;
  final List<SubscriptionPlanItem> plans;
  final List<PaymentItem> payments;
  final List<PaymentItem> filteredPayments;
  final String paymentStatusFilter;
  final FinancialMetrics? financialMetrics;
  final List<AnnouncementItem> announcements;
  final List<AdminFacebookPrompt> facebookPrompts;
  final String searchQuery;
  final String? errorMessage;
  final String? successMessage;

  const AdminState({
    this.status = AdminStatus.initial,
    this.metrics,
    this.users = const [],
    this.filteredUsers = const [],
    this.licenses = const [],
    this.plans = const [],
    this.payments = const [],
    this.filteredPayments = const [],
    this.paymentStatusFilter = 'all',
    this.financialMetrics,
    this.announcements = const [],
    this.facebookPrompts = const [],
    this.searchQuery = '',
    this.errorMessage,
    this.successMessage,
  });

  AdminState copyWith({
    AdminStatus? status,
    AdminMetrics? metrics,
    List<AdminUserItem>? users,
    List<AdminUserItem>? filteredUsers,
    List<AdminLicenseItem>? licenses,
    List<SubscriptionPlanItem>? plans,
    List<PaymentItem>? payments,
    List<PaymentItem>? filteredPayments,
    String? paymentStatusFilter,
    FinancialMetrics? financialMetrics,
    List<AnnouncementItem>? announcements,
    List<AdminFacebookPrompt>? facebookPrompts,
    String? searchQuery,
    String? errorMessage,
    String? successMessage,
    bool clearMessages = false,
  }) {
    return AdminState(
      status: status ?? this.status,
      metrics: metrics ?? this.metrics,
      users: users ?? this.users,
      filteredUsers: filteredUsers ?? this.filteredUsers,
      licenses: licenses ?? this.licenses,
      plans: plans ?? this.plans,
      payments: payments ?? this.payments,
      filteredPayments: filteredPayments ?? this.filteredPayments,
      paymentStatusFilter: paymentStatusFilter ?? this.paymentStatusFilter,
      financialMetrics: financialMetrics ?? this.financialMetrics,
      announcements: announcements ?? this.announcements,
      facebookPrompts: facebookPrompts ?? this.facebookPrompts,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: clearMessages ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearMessages ? null : (successMessage ?? this.successMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        metrics,
        users,
        filteredUsers,
        licenses,
        plans,
        payments,
        filteredPayments,
        paymentStatusFilter,
        financialMetrics,
        announcements,
        facebookPrompts,
        searchQuery,
        errorMessage,
        successMessage,
      ];
}

