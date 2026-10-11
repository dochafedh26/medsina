import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/constants/app_constants.dart';
import 'core/network/supabase_service.dart';
import 'core/theme/app_theme.dart';
import 'features/admin/bloc/admin_bloc.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/auth/bloc/auth_event.dart';
import 'features/auth/bloc/auth_state.dart';
import 'features/auth/presentation/auth_screen.dart';
import 'features/clinical/bloc/clinical_bloc.dart';
import 'features/navigation/presentation/main_scaffold.dart';
import 'features/revision/bloc/revision_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await SupabaseService.initialize();
  } catch (e) {
    debugPrint('Supabase initialization fallback: $e');
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
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryTeal, AppTheme.accentCyan],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryTeal.withValues(alpha: 0.35),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.local_hospital_rounded,
                color: Colors.white,
                size: 52,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              AppConstants.appName,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
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
