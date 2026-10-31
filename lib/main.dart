import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'core/constants/app_constants.dart';
import 'core/network/supabase_service.dart';
import 'core/services/user_loyalty_service.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/medsina_logo.dart';
import 'features/admin/bloc/admin_bloc.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/auth/bloc/auth_event.dart';
import 'features/auth/bloc/auth_state.dart';
import 'features/auth/presentation/auth_screen.dart';
import 'features/clinical/bloc/clinical_bloc.dart';
import 'features/navigation/presentation/main_scaffold.dart';
import 'features/notifications/services/realtime_notification_service.dart';
import 'features/revision/bloc/revision_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Full-Screen Edge-to-Edge display on Android
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

  try {
    await SupabaseService.initialize();
    // Track user connection session, daily streak and loyalty XP
    UserLoyaltyService.instance.initializeAndTrack();
  } catch (e) {
    debugPrint('Supabase initialization fallback: $e');
  }

  // Dynamically synchronize app version from runtime package info (web, android, windows)
  try {
    final pkg = await PackageInfo.fromPlatform();
    if (pkg.version.isNotEmpty) {
      AppConstants.appVersion = pkg.version;
    }
  } catch (e) {
    debugPrint('PackageInfo initialization notice: $e');
  }

  // Initialize Realtime Medical Notifications (CAT, Courses, QCM, Pearl) with active user context
  try {
    String? activeUserId;
    bool isAdmin = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('medsina_active_user');
      if (userJson != null) {
        final data = jsonDecode(userJson);
        activeUserId = data['id']?.toString();
        isAdmin = data['isAdmin'] == true || data['is_admin'] == true;
      }
    } catch (_) {}
    activeUserId ??= SupabaseService.currentSession?.user.id;
    await RealtimeNotificationService.instance.initialize(
      userId: activeUserId,
      isAdmin: isAdmin,
    );
  } catch (e) {
    debugPrint('Realtime Notification initialization notice: $e');
  }

  runApp(const MedsinaApp());
}

class MedsinaApp extends StatelessWidget {
  const MedsinaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (_) => AuthBloc()..add(AppStartedEvent()),
        ),
        BlocProvider<ClinicalBloc>(
          create: (_) => ClinicalBloc(),
        ),
        BlocProvider<RevisionBloc>(
          create: (_) => RevisionBloc(),
        ),
        BlocProvider<AdminBloc>(
          create: (_) => AdminBloc(),
        ),
      ],
      child: MaterialApp(
        title: 'Medsina — Plateforme Médicale Globale',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: const AuthGate(),
      ),
    );
  }
}

/// Dynamic routing gate based on Bloc Authentication status
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        switch (state.status) {
          case AuthStatus.authenticated:
            return const MainScaffold();
          case AuthStatus.unauthenticated:
          case AuthStatus.error:
            return const AuthScreen();
          case AuthStatus.loading:
          case AuthStatus.initial:
            return const MedicalSplashScreen();
        }
      },
    );
  }
}

/// Polished Medical Loading / Splash Screen
class MedicalSplashScreen extends StatelessWidget {
  const MedicalSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryTeal.withValues(alpha: 0.25),
                    blurRadius: 32,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const MedsinaLogo.icon(size: 68),
            ),
            const SizedBox(height: 24),
            const MedsinaLogo(height: 38),
            const SizedBox(height: 8),
            Text(
              'Plateforme Médicale & Résidanat Blida 2027',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 36),
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppTheme.primaryTeal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
