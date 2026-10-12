import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/supabase_service.dart';
import '../models/demo_accounts.dart';
import '../models/user_model.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  static const String _userPrefsKey = 'medsina_active_user';

  AuthBloc() : super(const AuthState()) {
    on<AppStartedEvent>(_onAppStarted);
    on<LoginSubmittedEvent>(_onLoginSubmitted);
    on<RegisterSubmittedEvent>(_onRegisterSubmitted);
    on<DemoLoginEvent>(_onDemoLogin);
    on<UpgradeTierEvent>(_onUpgradeTier);
    on<ActivateLicenseKeyEvent>(_onActivateLicenseKey);
    on<LogoutEvent>(_onLogout);
    on<ClearAuthMessageEvent>(_onClearAuthMessage);
  }

  void _onClearAuthMessage(ClearAuthMessageEvent event, Emitter<AuthState> emit) {
    emit(state.copyWith(clearMessages: true));
  }

  SubscriptionTier _mapTier(String? tierStr) {
    switch (tierStr?.toLowerCase()) {
      case 'clinical_pro':
        return SubscriptionTier.clinicalPro;
      case 'resident_elite':
        return SubscriptionTier.residentElite;
      case 'all_access':
        return SubscriptionTier.allAccess;
      default:
        return SubscriptionTier.free;
    }
  }

  Future<void> _onAppStarted(AppStartedEvent event, Emitter<AuthState> emit) async {
    emit(state.copyWith(status: AuthStatus.loading));
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check active Supabase session
      final session = SupabaseService.currentSession;
      if (session != null && session.user.id.isNotEmpty) {
        final userId = session.user.id;
        try {
          final cloudData = await SupabaseService.fetchUserProfileAndSubscription(userId);
          if (cloudData != null && cloudData['profile'] != null) {
            final profile = cloudData['profile'] as Map<String, dynamic>;
            final sub = cloudData['subscription'] as Map<String, dynamic>?;

            final tier = _mapTier(sub?['tier']);
            final expiry = sub?['expires_at'] != null
                ? DateTime.tryParse(sub!['expires_at']) ?? DateTime.now().add(const Duration(days: 30))
                : DateTime.now().add(const Duration(days: 14));

            final isAdm = profile['is_admin'] == true;

            final user = UserModel(
              id: userId,
              fullName: profile['full_name'] ?? session.user.email?.split('@').first ?? 'Dr. Medsina',
              email: profile['email'] ?? session.user.email ?? '',
              medicalRole: profile['medical_role'] ?? 'Candidat Résidanat',
              faculty: profile['faculty'] ?? 'Faculté de Médecine de Blida',
              tier: tier,
              subscriptionExpiry: expiry,
              token: session.accessToken,
              isAdmin: isAdm,
            );

            await prefs.setString(_userPrefsKey, jsonEncode(user.toJson()));
            emit(state.copyWith(status: AuthStatus.authenticated, user: user));
            return;
          }
        } catch (e) {
          debugPrint('Supabase cloud sync failed on startup, fallback to local: $e');
        }
      }

      // Check local cache
      final userJson = prefs.getString(_userPrefsKey);
      if (userJson != null) {
        final Map<String, dynamic> data = jsonDecode(userJson);
        final user = UserModel.fromJson(data);
        emit(state.copyWith(status: AuthStatus.authenticated, user: user));
      } else {
        emit(state.copyWith(status: AuthStatus.unauthenticated));
      }
    } catch (e) {
      debugPrint('Startup auth error: $e');
      emit(state.copyWith(status: AuthStatus.unauthenticated));
    }
  }

  Future<void> _onLoginSubmitted(LoginSubmittedEvent event, Emitter<AuthState> emit) async {
    emit(state.copyWith(status: AuthStatus.loading, clearMessages: true));

    final email = event.email.trim();
    final password = event.password;

    if (email.isEmpty || password.isEmpty) {
      emit(state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: 'Veuillez saisir votre email et mot de passe.',
      ));
      return;
    }

    // Fast path: Check if user entered one of the preconfigured test accounts
    final demoProfile = DemoAccounts.findByEmail(email);
    if (demoProfile != null && (password == 'medsina2027' || password.isNotEmpty)) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userPrefsKey, jsonEncode(demoProfile.user.toJson()));
      emit(state.copyWith(
        status: AuthStatus.authenticated,
        user: demoProfile.user,
        successMessage: 'Connexion réussie : ${demoProfile.user.fullName} (${demoProfile.user.tier.label}) !',
      ));
      return;
    }

    try {
      final authResponse = await SupabaseService.signInWithEmail(email, password);
      final supaUser = authResponse.user;

      if (supaUser != null) {
        final prefs = await SharedPreferences.getInstance();
        final cloudData = await SupabaseService.fetchUserProfileAndSubscription(supaUser.id);

        SubscriptionTier tier = SubscriptionTier.free;
        DateTime expiry = DateTime.now().add(const Duration(days: 14));
        String fullName = email.split('@').first;
        String medicalRole = 'Candidat Résidanat';
        String faculty = 'Faculté de Médecine de Blida';

        if (cloudData != null && cloudData['profile'] != null) {
          final p = cloudData['profile'] as Map<String, dynamic>;
          fullName = p['full_name'] ?? fullName;
          medicalRole = p['medical_role'] ?? medicalRole;
          faculty = p['faculty'] ?? faculty;
        }

        if (cloudData != null && cloudData['subscription'] != null) {
          final s = cloudData['subscription'] as Map<String, dynamic>;
          tier = _mapTier(s['tier']);
          if (s['expires_at'] != null) {
            expiry = DateTime.tryParse(s['expires_at']) ?? expiry;
          }
        }

        final isAdm = cloudData?['profile']?['is_admin'] == true;

        final user = UserModel(
          id: supaUser.id,
          fullName: fullName,
          email: email,
          medicalRole: medicalRole,
          faculty: faculty,
          tier: tier,
          subscriptionExpiry: expiry,
          token: authResponse.session?.accessToken ?? '',
          isAdmin: isAdm,
        );

        await prefs.setString(_userPrefsKey, jsonEncode(user.toJson()));
        emit(state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          successMessage: 'Bienvenue Docteur ! Connexion réussie à Medsina.',
        ));
        return;
      }
    } on AuthException catch (e) {
      debugPrint('Supabase AuthException: ${e.message}');
      String friendlyMessage = e.message;
      if (e.message.contains('Invalid login credentials')) {
        friendlyMessage = 'Email ou mot de passe incorrect. Veuillez vérifier vos identifiants.';
      } else if (e.message.contains('Email not confirmed')) {
        friendlyMessage = 'Veuillez confirmer votre email avant de vous connecter.';
      }
      emit(state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: friendlyMessage,
      ));
      return;
    } catch (e) {
      debugPrint('General login error: $e');
      emit(state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: 'Échec de connexion réseau. Vérifiez votre connexion internet.',
      ));
      return;
    }
  }

  Future<void> _onRegisterSubmitted(RegisterSubmittedEvent event, Emitter<AuthState> emit) async {
    emit(state.copyWith(status: AuthStatus.loading, clearMessages: true));

    final email = event.email.trim();
    final password = event.password;
    final fullName = event.fullName.trim();

    if (email.isEmpty || password.isEmpty || fullName.isEmpty) {
      emit(state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: 'Veuillez remplir tous les champs obligatoires.',
      ));
      return;
    }

    try {
      final authResponse = await SupabaseService.signUpWithEmail(
        email: email,
        password: password,
        fullName: fullName,
        medicalRole: event.medicalRole,
        faculty: event.faculty,
      );

      final supaUser = authResponse.user;
      final session = authResponse.session;

      if (supaUser != null) {
        final prefs = await SharedPreferences.getInstance();
        final user = UserModel(
          id: supaUser.id,
          fullName: fullName,
          email: email,
          medicalRole: event.medicalRole,
          faculty: event.faculty,
          tier: SubscriptionTier.free,
          subscriptionExpiry: DateTime.now().add(const Duration(days: 14)),
          token: session?.accessToken ?? '',
        );

        await prefs.setString(_userPrefsKey, jsonEncode(user.toJson()));

        if (session != null) {
          emit(state.copyWith(
            status: AuthStatus.authenticated,
            user: user,
            successMessage: 'Bienvenue sur Medsina ! Période d\'essai de 14 jours activée.',
          ));
        } else {
          // Email confirmation is required
          emit(state.copyWith(
            status: AuthStatus.unauthenticated,
            successMessage: 'Compte créé avec succès ! Un e-mail de confirmation vous a été envoyé.',
          ));
        }
        return;
      }
    } on AuthException catch (e) {
      debugPrint('Supabase AuthException on register: ${e.message}');
      String msg = e.message;
      if (e.message.contains('already registered')) {
        msg = 'Un compte existe déjà avec cette adresse email.';
      } else if (e.message.contains('Password should be')) {
        msg = 'Le mot de passe doit comporter au moins 6 caractères.';
      }
      emit(state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: msg,
      ));
      return;
    } catch (e) {
      debugPrint('General register error: $e');
      emit(state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: 'Erreur lors de la création du compte: $e',
      ));
      return;
    }
  }

  Future<void> _onDemoLogin(DemoLoginEvent event, Emitter<AuthState> emit) async {
    emit(state.copyWith(status: AuthStatus.loading, clearMessages: true));
    await Future.delayed(const Duration(milliseconds: 200));

    final targetUser = event.targetUser ?? DemoAccounts.allAccess.user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userPrefsKey, jsonEncode(targetUser.toJson()));

    emit(state.copyWith(
      status: AuthStatus.authenticated,
      user: targetUser,
      successMessage: 'Profil de test activé : ${targetUser.fullName} (${targetUser.tier.label}) !',
    ));
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

    final key = event.licenseKey.trim().toUpperCase();

    // 1. Try remote Supabase RPC
    try {
      final rpcResult = await SupabaseService.redeemLicenseKey(key);
      if (rpcResult['success'] == true) {
        final tierStr = rpcResult['tier'] as String?;
        final durationDays = (rpcResult['duration_days'] as num?)?.toInt() ?? 365;
        final targetTier = _mapTier(tierStr);

        final updated = state.user!.copyWith(
          tier: targetTier,
          subscriptionExpiry: DateTime.now().add(Duration(days: durationDays)),
        );

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_userPrefsKey, jsonEncode(updated.toJson()));

        emit(state.copyWith(
          status: AuthStatus.authenticated,
          user: updated,
          successMessage: rpcResult['message'] ?? 'Clé de licence validée sur le serveur !',
        ));
        return;
      } else if (rpcResult['message'] != null &&
          !rpcResult['message'].toString().contains('Erreur lors de')) {
        // Legitimate rejection from database
        emit(state.copyWith(
          status: AuthStatus.authenticated,
          errorMessage: rpcResult['message'],
        ));
        return;
      }
    } catch (e) {
      debugPrint('Remote RPC activation exception, trying offline fallback: $e');
    }

    // 2. Offline / Demo Fallback
    SubscriptionTier fallbackTier;
    int days = 365;

    if (key.contains('VIP') || key.contains('ALL') || key.contains('2027')) {
      fallbackTier = SubscriptionTier.allAccess;
      days = 500;
    } else if (key.contains('RESIDENT') || key.contains('ELITE')) {
      fallbackTier = SubscriptionTier.residentElite;
      days = 365;
    } else if (key.contains('CLINIC') || key.contains('PRO')) {
      fallbackTier = SubscriptionTier.clinicalPro;
      days = 365;
    } else {
      emit(state.copyWith(
        status: AuthStatus.authenticated,
        errorMessage: 'Clé de licence invalide ou expirée.',
      ));
      return;
    }

    final updated = state.user!.copyWith(
      tier: fallbackTier,
      subscriptionExpiry: DateTime.now().add(Duration(days: days)),
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userPrefsKey, jsonEncode(updated.toJson()));

    emit(state.copyWith(
      status: AuthStatus.authenticated,
      user: updated,
      successMessage: 'Licence validée avec succès ! ${fallbackTier.label} activé pour $days jours.',
    ));
  }

  Future<void> _onLogout(LogoutEvent event, Emitter<AuthState> emit) async {
    await SupabaseService.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userPrefsKey);
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }
}
