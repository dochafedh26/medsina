import 'package:equatable/equatable.dart';
import '../models/admin_models.dart';

enum AdminStatus { initial, loading, loaded, error }

class AdminState extends Equatable {
  final AdminStatus status;
  final AdminMetrics? metrics;
  final List<AdminUserItem> users;
  final List<AdminUserItem> filteredUsers;
  final List<AdminLicenseItem> licenses;
  final String searchQuery;
  final String? errorMessage;
  final String? successMessage;

  const AdminState({
    this.status = AdminStatus.initial,
    this.metrics,
    this.users = const [],
    this.filteredUsers = const [],
    this.licenses = const [],
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
        searchQuery,
        errorMessage,
        successMessage,
      ];
}

