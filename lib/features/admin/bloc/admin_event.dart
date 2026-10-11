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

  const UpgradeUserSubscriptionEvent({
    required this.userId,
    required this.tier,
    required this.durationDays,
  });

  @override
  List<Object?> get props => [userId, tier, durationDays];
}

class ClearAdminMessageEvent extends AdminEvent {}

