import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_constants.dart';
import '../models/user_model.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  static const String _userPrefsKey = 'medsina_active_user';

  AuthBloc() : super(const AuthState()) {
    on<AppStartedEvent>(_onAppStarted);
    on<LoginSubmittedEvent>(_onLoginSubmitted);
    on<RegisterSubmittedEvent>(_onRegisterSubmitted);
    on<UpgradeTierEvent>(_onUpgradeTier);
    on<ActivateLicenseKeyEvent>(_onActivateLicenseKey);
    on<LogoutEvent>(_onLogout);
  }

  Future<void> _onAppStarted(AppStartedEvent event, Emitter<AuthState> emit) async {
    emit(state.copyWith(status: AuthStatus.loading));
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_userPrefsKey);

      if (userJson != null) {
        final Map<String, dynamic> data = jsonDecode(userJson);
        final user = UserModel.fromJson(data);
        emit(state.copyWith(status: AuthStatus.authenticated, user: user));
      } else {
        // Default initialized session for seamless demonstration
        final demoUser = UserModel(
          id: 'user_resident_001',
          fullName: 'Dr. Hafedh (Résidanat Blida)',
          email: 'doc.hafedh14@medsina.com',
          medicalRole: 'Candidat Résidanat 2027',
          faculty: 'Faculté de Médecine de Blida',
          tier: SubscriptionTier.allAccess,
          subscriptionExpiry: DateTime(2027, 10, 31),
          token: 'medsina_jwt_token_demo_987654',
        );
        await prefs.setString(_userPrefsKey, jsonEncode(demoUser.toJson()));
        emit(state.copyWith(status: AuthStatus.authenticated, user: demoUser));
      }
    } catch (e) {
      emit(state.copyWith(status: AuthStatus.unauthenticated));
    }
  }

  Future<void> _onLoginSubmitted(LoginSubmittedEvent event, Emitter<AuthState> emit) async {
    emit(state.copyWith(status: AuthStatus.loading, clearMessages: true));
    await Future.delayed(const Duration(milliseconds: 600));

    if (event.email.trim().isEmpty || event.password.trim().isEmpty) {
      emit(state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: 'Veuillez saisir votre email et mot de passe.',
      ));
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final user = UserModel(
        id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
        fullName: event.email.split('@').first,
        email: event.email.trim(),
        medicalRole: 'Médecin / Résident',
        faculty: 'Faculté de Médecine de Blida',
        tier: SubscriptionTier.allAccess,
        subscriptionExpiry: DateTime.now().add(const Duration(days: 365)),
        token: 'medsina_token_${DateTime.now().millisecondsSinceEpoch}',
      );

      await prefs.setString(_userPrefsKey, jsonEncode(user.toJson()));
      emit(state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        successMessage: 'Connexion réussie à Medsina.',
      ));
    } catch (e) {
      emit(state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: 'Échec de connexion : $e',
      ));
    }
  }

  Future<void> _onRegisterSubmitted(RegisterSubmittedEvent event, Emitter<AuthState> emit) async {
    emit(state.copyWith(status: AuthStatus.loading, clearMessages: true));
    await Future.delayed(const Duration(milliseconds: 700));

    try {
      final prefs = await SharedPreferences.getInstance();
      final user = UserModel(
        id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
        fullName: event.fullName.trim(),
        email: event.email.trim(),
        medicalRole: event.medicalRole,
        faculty: event.faculty,
        tier: SubscriptionTier.free,
        subscriptionExpiry: DateTime.now().add(const Duration(days: 14)), // 14 jours d'essai
        token: 'medsina_token_${DateTime.now().millisecondsSinceEpoch}',
      );

      await prefs.setString(_userPrefsKey, jsonEncode(user.toJson()));
      emit(state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        successMessage: 'Bienvenue sur Medsina ! Période d\'essai activée.',
      ));
    } catch (e) {
      emit(state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: 'Erreur lors de l\'inscription : $e',
      ));
    }
  }

  Future<void> _onUpgradeTier(UpgradeTierEvent event, Emitter<AuthState> emit) async {
    if (state.user == null) return;
    emit(state.copyWith(status: AuthStatus.loading));

    final updated = state.user!.copyWith(
      tier: event.newTier,
      subscriptionExpiry: DateTime.now().add(Duration(days: event.durationDays)),
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userPrefsKey, jsonEncode(updated.toJson()));

    emit(state.copyWith(
      status: AuthStatus.authenticated,
      user: updated,
      successMessage: 'Abonnement mis à niveau avec succès : ${event.newTier.label} !',
    ));
  }

  Future<void> _onActivateLicenseKey(ActivateLicenseKeyEvent event, Emitter<AuthState> emit) async {
    if (state.user == null) return;
    emit(state.copyWith(status: AuthStatus.loading, clearMessages: true));
    await Future.delayed(const Duration(milliseconds: 500));

    final key = event.licenseKey.trim().toUpperCase();
    SubscriptionTier targetTier;
    int days = 365;

    if (key.contains('VIP') || key.contains('ALL') || key.contains('2027')) {
      targetTier = SubscriptionTier.allAccess;
      days = 500;
    } else if (key.contains('RESIDENT') || key.contains('ELITE')) {
      targetTier = SubscriptionTier.residentElite;
      days = 365;
    } else if (key.contains('CLINIC') || key.contains('PRO')) {
      targetTier = SubscriptionTier.clinicalPro;
      days = 365;
    } else {
      emit(state.copyWith(
        status: AuthStatus.authenticated,
        errorMessage: 'Clé de licence invalide ou expirée.',
      ));
      return;
    }

    final updated = state.user!.copyWith(
      tier: targetTier,
      subscriptionExpiry: DateTime.now().add(Duration(days: days)),
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userPrefsKey, jsonEncode(updated.toJson()));

    emit(state.copyWith(
      status: AuthStatus.authenticated,
      user: updated,
      successMessage: 'Clé de licence activée avec succès ! ${targetTier.label} débloqué.',
    ));
  }

  Future<void> _onLogout(LogoutEvent event, Emitter<AuthState> emit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userPrefsKey);
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }
}
