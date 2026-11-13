import 'package:flutter/material.dart';

/// Contract for feature packages to participate in cloud synchronization
/// without creating compile-time dependencies from `medsina_core`.
abstract class CloudSyncParticipant {
  String get participantId;
  Future<void> sync(
    String userId,
    Map<String, dynamic> remoteMap, {
    bool forceUpload = false,
  });
}

/// Contract for feature packages to expose recent activity items and handle navigation.
abstract class RecentActivityHandler {
  Future<List<Map<String, dynamic>>> loadRawActivities();
  Future<bool> handleOpen(BuildContext context, String typeId, Map<String, dynamic> data);
}

/// Contract for feature packages to report solved QCMs / completed courses
/// to `UserStudyProgressService`.
abstract class StudyProgressContributor {
  Future<({int solvedQcms, int completedCourses})> getProgressCounts();
}

/// Contract for feature packages to register navigation tabs in `MainScaffold`.
class AppTabDefinition {
  final String label;
  final String title;
  final IconData icon;
  final IconData selectedIcon;
  final Widget page;
  final bool isSpecial;

  const AppTabDefinition({
    required this.label,
    required this.title,
    required this.icon,
    required this.selectedIcon,
    required this.page,
    this.isSpecial = false,
  });
}

/// Central registry populated by each app shell (`medsina_residanat`,
/// `medsina_clinique`, `medsina_externat`, `medsina_all_in_one`) at startup.
class MedsinaFeatureRegistry {
  MedsinaFeatureRegistry._();
  static final MedsinaFeatureRegistry instance = MedsinaFeatureRegistry._();

  final List<CloudSyncParticipant> syncParticipants = [];
  final List<StudyProgressContributor> progressContributors = [];
  final Map<String, Future<bool> Function(BuildContext, Map<String, dynamic>)> _routeHandlers = {};

  String appId = 'medsina_all';
  String appDisplayName = 'Medsina';
  String iconAsset = 'assets/medsina-icon.png';

  void registerSyncParticipant(CloudSyncParticipant participant) {
    if (!syncParticipants.any((p) => p.participantId == participant.participantId)) {
      syncParticipants.add(participant);
    }
  }

  void registerProgressContributor(StudyProgressContributor contributor) {
    if (!progressContributors.contains(contributor)) {
      progressContributors.add(contributor);
    }
  }

  void registerRouteHandler(
    String routeKey,
    Future<bool> Function(BuildContext context, Map<String, dynamic> args) handler,
  ) {
    _routeHandlers[routeKey] = handler;
  }

  Future<bool> dispatchRoute(
    BuildContext context,
    String routeKey, [
    Map<String, dynamic> args = const {},
  ]) async {
    final handler = _routeHandlers[routeKey];
    if (handler == null) return false;
    return handler(context, args);
  }

  void clear() {
    syncParticipants.clear();
    progressContributors.clear();
    _routeHandlers.clear();
  }
}
