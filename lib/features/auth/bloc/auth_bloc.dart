import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/supabase_service.dart';
import '../../../../core/services/cloud_sync_service.dart';
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
    on<UpdateUserProfileEvent>(_onUpdateUserProfile);
    on<LogoutEvent>(_onLogout);
    on<ClearAuthMessageEvent>(_onClearAuthMessage);
    on<ReactivateAccountRequestedEvent>(_onReactivateAccountRequested);
  }

  void _onClearAuthMessage(ClearAuthMessageEvent event, Emitter<AuthState> emit) {
    emit(state.copyWith(clearMessages: true));
  }

  SubscriptionTier _mapTier(String? tierStr) {
    switch (tierStr?.toLowerCase()) {
      case 'etudiant':
        return SubscriptionTier.etudiant;
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

            final userEmail = (profile['email'] ?? session.user.email ?? '').toString().trim().toLowerCase();
            final isAdm = profile['is_admin'] == true || userEmail == 'doc.hafedh26@gmail.com';
            final isBanned = profile['is_banned'] == true && userEmail != 'doc.hafedh26@gmail.com';
            final banReason = profile['ban_reason']?.toString();
            final isInactiveSuspended = profile['is_inactive_suspended'] == true ||
                (isBanned && (banReason?.toLowerCase().contains('inactiv') ?? false));

            if (isBanned) {
              if (isInactiveSuspended) {
                final suspendedUser = UserModel(
                  id: userId,
                  fullName: profile['full_name'] ?? session.user.email?.split('@').first ?? 'Dr. Medsina',
                  email: profile['email'] ?? session.user.email ?? '',
                  medicalRole: profile['medical_role'] ?? 'Candidat Résidanat',
                  faculty: profile['faculty'] ?? 'Faculté de Médecine de Blida',
                  tier: tier,
                  subscriptionExpiry: expiry,
                  token: session.accessToken,
                  isAdmin: isAdm,
                  isBanned: true,
                  banReason: banReason,
                  isInactiveSuspended: true,
                  reactivationCount: (profile['reactivation_count'] as num?)?.toInt() ?? 0,
                  rejectedPaymentsCount: (profile['rejected_payments_count'] as num?)?.toInt() ?? 0,
                  studyYear: (profile['study_year'] as num?)?.toInt() ?? (session.user.userMetadata?['study_year'] as num?)?.toInt(),
                  avatarUrl: profile['avatar_url'] ?? (session.user.userMetadata?['avatar_url'] as String?),
                  bio: profile['bio'] ?? (session.user.userMetadata?['bio'] as String?),
                  phone: profile['phone'] ?? (session.user.userMetadata?['phone'] as String?),
                  wilaya: profile['wilaya'] ?? (session.user.userMetadata?['wilaya'] as String?),
                  residencyTargetYear: profile['residency_target_year'] ?? (session.user.userMetadata?['residency_target_year'] as String?),
                );
                emit(state.copyWith(
                  status: AuthStatus.inactivitySuspended,
                  user: suspendedUser,
                  errorMessage: 'Votre compte Medsina est momentanément suspendu suite à 7 jours d\'inactivité.',
                ));
                return;
              }

              await SupabaseService.signOut();
              await prefs.remove(_userPrefsKey);
              emit(state.copyWith(
                status: AuthStatus.unauthenticated,
                errorMessage: 'Votre compte Medsina est suspendu suite à des tentatives de paiement non conformes répétées. Contact : doc.hafedh26@gmail.com',
              ));
              return;
            }

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
              isBanned: isBanned,
              banReason: profile['ban_reason'],
              rejectedPaymentsCount: (profile['rejected_payments_count'] as num?)?.toInt() ?? 0,
              studyYear: (profile['study_year'] as num?)?.toInt() ?? (session.user.userMetadata?['study_year'] as num?)?.toInt(),
              avatarUrl: profile['avatar_url'] ?? (session.user.userMetadata?['avatar_url'] as String?),
              bio: profile['bio'] ?? (session.user.userMetadata?['bio'] as String?),
              phone: profile['phone'] ?? (session.user.userMetadata?['phone'] as String?),
              wilaya: profile['wilaya'] ?? (session.user.userMetadata?['wilaya'] as String?),
              residencyTargetYear: profile['residency_target_year'] ?? (session.user.userMetadata?['residency_target_year'] as String?),
            );

            await prefs.setString(_userPrefsKey, jsonEncode(user.toJson()));
            emit(state.copyWith(status: AuthStatus.authenticated, user: user));
            CloudSyncService.instance.syncAll().catchError((e) {
              debugPrint('[CloudSync] Startup sync error: $e');
              return false;
            });
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
        if (user.isBanned) {
          await prefs.remove(_userPrefsKey);
          emit(state.copyWith(
            status: AuthStatus.unauthenticated,
            errorMessage: 'Votre compte Medsina a été suspendu.',
          ));
          return;
        }
        if (session != null && session.user.id == user.id) {
          if (data['is_admin'] != user.isAdmin || data['isAdmin'] != user.isAdmin) {
            await prefs.setString(_userPrefsKey, jsonEncode(user.toJson()));
          }
          emit(state.copyWith(status: AuthStatus.authenticated, user: user));
          CloudSyncService.instance.syncAll().catchError((e) {
            debugPrint('[CloudSync] Startup sync error: $e');
            return false;
          });
          return;
        } else if (user.id.startsWith('demo_')) {
          emit(state.copyWith(status: AuthStatus.authenticated, user: user));
          return;
        } else {
          // Stale cache without an active matching Supabase session
          await prefs.remove(_userPrefsKey);
          emit(state.copyWith(status: AuthStatus.unauthenticated));
          return;
        }
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

        final profileMap = cloudData?['profile'] as Map<String, dynamic>?;
        final emailClean = email.trim().toLowerCase();
        final isAdm = profileMap?['is_admin'] == true || emailClean == 'doc.hafedh26@gmail.com';
        final isBanned = profileMap?['is_banned'] == true && emailClean != 'doc.hafedh26@gmail.com';
        final banReason = profileMap?['ban_reason']?.toString();
        final isInactiveSuspended = profileMap?['is_inactive_suspended'] == true ||
            (isBanned && (banReason?.toLowerCase().contains('inactiv') ?? false));

        if (isBanned) {
          if (isInactiveSuspended) {
            final suspendedUser = UserModel(
              id: supaUser.id,
              fullName: fullName,
              email: email,
              medicalRole: medicalRole,
              faculty: faculty,
              tier: tier,
              subscriptionExpiry: expiry,
              token: authResponse.session?.accessToken ?? '',
              isAdmin: isAdm,
              isBanned: true,
              banReason: banReason,
              isInactiveSuspended: true,
              reactivationCount: (profileMap?['reactivation_count'] as num?)?.toInt() ?? 0,
              rejectedPaymentsCount: (profileMap?['rejected_payments_count'] as num?)?.toInt() ?? 0,
              studyYear: (profileMap?['study_year'] as num?)?.toInt() ?? (supaUser.userMetadata?['study_year'] as num?)?.toInt(),
              avatarUrl: profileMap?['avatar_url'] ?? (supaUser.userMetadata?['avatar_url'] as String?),
              bio: profileMap?['bio'] ?? (supaUser.userMetadata?['bio'] as String?),
              phone: profileMap?['phone'] ?? (supaUser.userMetadata?['phone'] as String?),
              wilaya: profileMap?['wilaya'] ?? (supaUser.userMetadata?['wilaya'] as String?),
              residencyTargetYear: profileMap?['residency_target_year'] ?? (supaUser.userMetadata?['residency_target_year'] as String?),
            );
            emit(state.copyWith(
              status: AuthStatus.inactivitySuspended,
              user: suspendedUser,
              errorMessage: 'Votre compte Medsina est momentanément suspendu suite à 7 jours d\'inactivité.',
            ));
            return;
          }

          await SupabaseService.signOut();
          await prefs.remove(_userPrefsKey);
          emit(state.copyWith(
            status: AuthStatus.unauthenticated,
            errorMessage: 'Votre compte est suspendu suite à 3 rejets consécutifs de preuve de paiement. Contactez le support : doc.hafedh26@gmail.com',
          ));
          return;
        }

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
          isBanned: isBanned,
          banReason: profileMap?['ban_reason'],
          rejectedPaymentsCount: (profileMap?['rejected_payments_count'] as num?)?.toInt() ?? 0,
          studyYear: (profileMap?['study_year'] as num?)?.toInt() ?? (supaUser.userMetadata?['study_year'] as num?)?.toInt(),
          avatarUrl: profileMap?['avatar_url'] ?? (supaUser.userMetadata?['avatar_url'] as String?),
          bio: profileMap?['bio'] ?? (supaUser.userMetadata?['bio'] as String?),
          phone: profileMap?['phone'] ?? (supaUser.userMetadata?['phone'] as String?),
          wilaya: profileMap?['wilaya'] ?? (supaUser.userMetadata?['wilaya'] as String?),
          residencyTargetYear: profileMap?['residency_target_year'] ?? (supaUser.userMetadata?['residency_target_year'] as String?),
        );

        await prefs.setString(_userPrefsKey, jsonEncode(user.toJson()));
        emit(state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          successMessage: 'Bienvenue Docteur ! Connexion réussie à Medsina.',
        ));
        CloudSyncService.instance.syncAll().catchError((e) {
          debugPrint('[CloudSync] Login sync error: $e');
          return false;
        });
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
        studyYear: event.studyYear,
      );

      final supaUser = authResponse.user;
      final session = authResponse.session;

      if (supaUser != null) {
        final prefs = await SharedPreferences.getInstance();
        final isPromo = AppConstants.isNovemberPromoActive;
        final initialTier = isPromo ? SubscriptionTier.allAccess : SubscriptionTier.free;
        final initialExpiry = DateTime.now().add(Duration(days: isPromo ? 30 : 14));
        final expiryFormatted = '${initialExpiry.day.toString().padLeft(2, "0")}/${initialExpiry.month.toString().padLeft(2, "0")}/${initialExpiry.year}';
        final welcomeMsg = isPromo
            ? '🎉 Bienvenue sur Medsina ! Votre Pass All-Access VIP (1 Mois Offert) est activé jusqu\'au $expiryFormatted !'
            : 'Bienvenue sur Medsina ! Période d\'essai de 14 jours activée.';

        final user = UserModel(
          id: supaUser.id,
          fullName: fullName,
          email: email,
          medicalRole: event.medicalRole,
          faculty: event.faculty,
          tier: initialTier,
          subscriptionExpiry: initialExpiry,
          token: session?.accessToken ?? '',
          studyYear: event.studyYear,
        );

        if (session != null) {
          await prefs.setString(_userPrefsKey, jsonEncode(user.toJson()));
          emit(state.copyWith(
            status: AuthStatus.authenticated,
            user: user,
            successMessage: welcomeMsg,
          ));
        } else {
          // Email confirmation is required
          await prefs.remove(_userPrefsKey);
          emit(state.copyWith(
            status: AuthStatus.unauthenticated,
            successMessage: isPromo
                ? 'Compte créé avec succès ! Votre Pass All-Access VIP 1 mois offert vous attend. Veuillez vérifier votre boîte mail pour confirmer votre compte.'
                : 'Compte créé avec succès ! Veuillez vérifier votre boîte mail et cliquer sur le lien de confirmation avant de vous connecter.',
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

  Future<void> _onUpdateUserProfile(UpdateUserProfileEvent event, Emitter<AuthState> emit) async {
    final currentUser = state.user;
    if (currentUser == null) return;

    emit(state.copyWith(status: AuthStatus.loading, clearMessages: true));

    final updated = currentUser.copyWith(
      fullName: event.fullName.trim(),
      medicalRole: event.medicalRole.trim(),
      faculty: event.faculty.trim(),
      studyYear: event.studyYear,
      avatarUrl: event.avatarUrl,
      bio: event.bio?.trim(),
      phone: event.phone?.trim(),
      wilaya: event.wilaya?.trim(),
      residencyTargetYear: event.residencyTargetYear?.trim(),
    );

    // 1. Update local cache immediately
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userPrefsKey, jsonEncode(updated.toJson()));
    } catch (e) {
      debugPrint('Local profile cache update error: $e');
    }

    // 2. Sync to Supabase Cloud profiles table if logged in
    try {
      if (currentUser.id.isNotEmpty && !currentUser.id.startsWith('demo_')) {
        await SupabaseService.updateUserProfile(
          userId: currentUser.id,
          fullName: updated.fullName,
          medicalRole: updated.medicalRole,
          faculty: updated.faculty,
          studyYear: updated.studyYear,
          avatarUrl: updated.avatarUrl,
          bio: updated.bio,
          phone: updated.phone,
          wilaya: updated.wilaya,
          residencyTargetYear: updated.residencyTargetYear,
        );
      }
    } catch (e) {
      debugPrint('Cloud profile sync warning: $e');
    }

    emit(state.copyWith(
      status: AuthStatus.authenticated,
      user: updated,
      successMessage: 'Votre profil médical a été mis à jour avec succès !',
    ));
  }

  Future<void> _onLogout(LogoutEvent event, Emitter<AuthState> emit) async {
    await SupabaseService.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userPrefsKey);
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }

  Future<void> _onReactivateAccountRequested(
    ReactivateAccountRequestedEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading));
    try {
      final res = await SupabaseService.requestAccountReactivation(event.userId);
      if (res['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        final cloudData = await SupabaseService.fetchUserProfileAndSubscription(event.userId);
        final profile = cloudData?['profile'] as Map<String, dynamic>? ?? {};
        final sub = cloudData?['subscription'] as Map<String, dynamic>?;

        final current = state.user;
        final updatedUser = (current ?? UserModel(
          id: event.userId,
          fullName: profile['full_name'] ?? 'Dr. Medsina',
          email: profile['email'] ?? '',
          medicalRole: profile['medical_role'] ?? 'Médecin Généraliste',
          faculty: profile['faculty'] ?? 'Faculté de Médecine de Blida',
          tier: _mapTier(sub?['tier']),
          subscriptionExpiry: DateTime.now().add(const Duration(days: 30)),
          token: SupabaseService.currentSession?.accessToken ?? '',
        )).copyWith(
          isBanned: false,
          isInactiveSuspended: false,
          banReason: null,
          reactivationCount: (current?.reactivationCount ?? 0) + 1,
        );

        await prefs.setString(_userPrefsKey, jsonEncode(updatedUser.toJson()));
        emit(state.copyWith(
          status: AuthStatus.authenticated,
          user: updatedUser,
          successMessage: res['message'] ?? 'Ravi de vous revoir Docteur ! Votre compte a été réactivé avec succès.',
        ));

        CloudSyncService.instance.syncAll().catchError((e) {
          debugPrint('[CloudSync] Post-reactivation sync error: $e');
          return false;
        });
      } else {
        emit(state.copyWith(
          status: AuthStatus.inactivitySuspended,
          errorMessage: res['message'] ?? 'Impossible de réactiver automatiquement ce compte.',
        ));
      }
    } catch (e) {
      debugPrint('Reactivation error: $e');
      emit(state.copyWith(
        status: AuthStatus.inactivitySuspended,
        errorMessage: 'Erreur lors de la réactivation : $e',
      ));
    }
  }
}
