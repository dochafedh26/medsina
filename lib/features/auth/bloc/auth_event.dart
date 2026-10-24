import 'package:equatable/equatable.dart';
import '../../../../core/constants/app_constants.dart';
import '../models/user_model.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AppStartedEvent extends AuthEvent {}

class LoginSubmittedEvent extends AuthEvent {
  final String email;
  final String password;

  const LoginSubmittedEvent({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

class RegisterSubmittedEvent extends AuthEvent {
  final String fullName;
  final String email;
  final String password;
  final String medicalRole;
  final String faculty;
  final int? studyYear;

  const RegisterSubmittedEvent({
    required this.fullName,
    required this.email,
    required this.password,
    required this.medicalRole,
    required this.faculty,
    this.studyYear,
  });

  @override
  List<Object?> get props => [fullName, email, password, medicalRole, faculty, studyYear];
}

class DemoLoginEvent extends AuthEvent {
  final UserModel? targetUser;

  const DemoLoginEvent([this.targetUser]);

  @override
  List<Object?> get props => [targetUser];
}

class UpgradeTierEvent extends AuthEvent {
  final SubscriptionTier newTier;
  final int durationDays;

  const UpgradeTierEvent({required this.newTier, this.durationDays = 365});

  @override
  List<Object?> get props => [newTier, durationDays];
}

class ActivateLicenseKeyEvent extends AuthEvent {
  final String licenseKey;

  const ActivateLicenseKeyEvent({required this.licenseKey});

  @override
  List<Object?> get props => [licenseKey];
}

class LogoutEvent extends AuthEvent {}

class ClearAuthMessageEvent extends AuthEvent {}
