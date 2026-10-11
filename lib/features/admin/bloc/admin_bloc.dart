import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/network/supabase_service.dart';
import '../models/admin_models.dart';
import 'admin_event.dart';
import 'admin_state.dart';

class AdminBloc extends Bloc<AdminEvent, AdminState> {
  AdminBloc() : super(const AdminState()) {
    on<LoadAdminDataEvent>(_onLoadAdminData);
    on<SearchUsersEvent>(_onSearchUsers);
    on<GenerateLicenseKeyEvent>(_onGenerateLicenseKey);
    on<UpgradeUserSubscriptionEvent>(_onUpgradeUserSubscription);
    on<ClearAdminMessageEvent>(_onClearAdminMessage);
  }

  void _onClearAdminMessage(ClearAdminMessageEvent event, Emitter<AdminState> emit) {
    emit(state.copyWith(clearMessages: true));
  }

  Future<void> _onLoadAdminData(LoadAdminDataEvent event, Emitter<AdminState> emit) async {
    emit(state.copyWith(status: AdminStatus.loading, clearMessages: true));
    try {
      final metricsData = await SupabaseService.fetchAdminMetrics();
      final usersData = await SupabaseService.fetchAdminUsers();
      final licensesData = await SupabaseService.fetchAdminLicenseKeys();

      final metrics = AdminMetrics.fromJson(metricsData);
      final users = usersData.map((u) => AdminUserItem.fromJson(u)).toList();
      final licenses = licensesData.map((l) => AdminLicenseItem.fromJson(l)).toList();

      emit(state.copyWith(
        status: AdminStatus.loaded,
        metrics: metrics,
        users: users,
        filteredUsers: users,
        licenses: licenses,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: AdminStatus.error,
        errorMessage: 'Erreur lors du chargement des données administrateur: $e',
      ));
    }
  }

  void _onSearchUsers(SearchUsersEvent event, Emitter<AdminState> emit) {
    final query = event.query.trim().toLowerCase();
    if (query.isEmpty) {
      emit(state.copyWith(searchQuery: query, filteredUsers: state.users));
      return;
    }

    final filtered = state.users.where((u) {
      return u.fullName.toLowerCase().contains(query) ||
          u.email.toLowerCase().contains(query) ||
          u.faculty.toLowerCase().contains(query) ||
          u.medicalRole.toLowerCase().contains(query);
    }).toList();

    emit(state.copyWith(searchQuery: query, filteredUsers: filtered));
  }

  Future<void> _onGenerateLicenseKey(GenerateLicenseKeyEvent event, Emitter<AdminState> emit) async {
    emit(state.copyWith(status: AdminStatus.loading, clearMessages: true));
    try {
      final result = await SupabaseService.generateLicenseKey(
        keyCode: event.keyCode,
        tier: event.tier,
        durationDays: event.durationDays,
      );

      if (result['success'] == true) {
        final licensesData = await SupabaseService.fetchAdminLicenseKeys();
        final metricsData = await SupabaseService.fetchAdminMetrics();

        final licenses = licensesData.map((l) => AdminLicenseItem.fromJson(l)).toList();
        final metrics = AdminMetrics.fromJson(metricsData);

        emit(state.copyWith(
          status: AdminStatus.loaded,
          licenses: licenses,
          metrics: metrics,
          successMessage: result['message'] ?? 'Clé générée avec succès !',
        ));
      } else {
        emit(state.copyWith(
          status: AdminStatus.loaded,
          errorMessage: result['message'] ?? 'Échec de génération de la clé.',
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        status: AdminStatus.loaded,
        errorMessage: 'Erreur lors de la création de la clé : $e',
      ));
    }
  }

  Future<void> _onUpgradeUserSubscription(UpgradeUserSubscriptionEvent event, Emitter<AdminState> emit) async {
    emit(state.copyWith(status: AdminStatus.loading, clearMessages: true));
    try {
      final result = await SupabaseService.updateUserSubscription(
        userId: event.userId,
        tier: event.tier,
        durationDays: event.durationDays,
      );

      if (result['success'] == true) {
        final usersData = await SupabaseService.fetchAdminUsers();
        final metricsData = await SupabaseService.fetchAdminMetrics();

        final users = usersData.map((u) => AdminUserItem.fromJson(u)).toList();
        final metrics = AdminMetrics.fromJson(metricsData);

        emit(state.copyWith(
          status: AdminStatus.loaded,
          users: users,
          filteredUsers: users,
          metrics: metrics,
          successMessage: 'Abonnement utilisateur mis à niveau avec succès !',
        ));
      } else {
        emit(state.copyWith(
          status: AdminStatus.loaded,
          errorMessage: result['message'] ?? 'Échec de mise à jour.',
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        status: AdminStatus.loaded,
        errorMessage: 'Erreur lors de la mise à jour : $e',
      ));
    }
  }
}

