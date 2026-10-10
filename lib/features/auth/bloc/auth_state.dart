import 'package:equatable/equatable.dart';
import '../models/user_model.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

class AuthState extends Equatable {
  final AuthStatus status;
  final UserModel? user;
  final String? errorMessage;
  final String? successMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
    this.successMessage,
  });

  bool get isAuthenticated => status == AuthStatus.authenticated && user != null;

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    String? errorMessage,
    String? successMessage,
    bool clearMessages = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: clearMessages ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearMessages ? null : (successMessage ?? this.successMessage),
    );
  }

  @override
  List<Object?> get props => [status, user, errorMessage, successMessage];
}
