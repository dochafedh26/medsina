import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/announcements/presentation/announcements_hub_screen.dart';
import '../../features/auth/bloc/auth_bloc.dart';
import '../../features/auth/bloc/auth_event.dart';
import '../../features/auth/bloc/auth_state.dart';
import '../../features/auth/models/user_model.dart';
import '../../features/auth/presentation/auth_screen.dart';
import '../../features/notifications/services/fcm_service.dart';
import '../../features/notifications/services/realtime_notification_service.dart';
import '../../features/notifications/services/smart_reminder_service.dart';
import '../../features/profile/presentation/modern_user_profile_screen.dart';
import '../../features/subscription/presentation/subscription_paywall_screen.dart';
import '../constants/app_constants.dart';
import '../interfaces/feature_contracts.dart';
import '../network/supabase_service.dart';
import '../services/ota_update_service.dart';
import '../services/user_loyalty_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import 'medsina_logo.dart';

/// Shared bootstrap helper for all Medsina app shells (`medsina_residanat`,
/// `medsina_clinique`, `medsina_externat`, `medsina_all_in_one`).
Future<void> initializeMedsinaCore({
  required String appId,
  required String appDisplayName,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  MedsinaFeatureRegistry.instance.appId = appId;
  MedsinaFeatureRegistry.instance.appDisplayName = appDisplayName;

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
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
    UserLoyaltyService.instance.initializeAndTrack();
  } catch (e) {
    debugPrint('Supabase initialization fallback: $e');
  }

  try {
    final pkg = await PackageInfo.fromPlatform();
    if (pkg.version.isNotEmpty) {
      AppConstants.appVersion = pkg.version;
    }
  } catch (e) {
    debugPrint('PackageInfo initialization notice: $e');
  }

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
    await SmartReminderService.instance.initialize();
    await FcmService.instance.initialize(userId: activeUserId);
  } catch (e) {
    debugPrint('Realtime Notification initialization notice: $e');
  }

  await ThemeController.instance.initialize();
}

/// Reusable modular app shell for focused Medsina applications.
class MedsinaModularApp extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<BlocProvider> extraBlocProviders;
  final List<AppTabDefinition> Function(BuildContext context, UserModel user) tabsBuilder;
  final bool Function(UserModel user)? hasAppAccess;

  const MedsinaModularApp({
    super.key,
    required this.title,
    required this.subtitle,
    required this.tabsBuilder,
    this.extraBlocProviders = const [],
    this.hasAppAccess,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (_) => AuthBloc()..add(AppStartedEvent()),
        ),
        ...extraBlocProviders,
      ],
      child: AnimatedBuilder(
        animation: ThemeController.instance,
        builder: (context, _) {
          final tc = ThemeController.instance;
          return MaterialApp(
            title: title,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: tc.isNightShiftActive
                ? AppTheme.nightShiftTheme
                : AppTheme.darkTheme,
            themeMode: tc.themeMode,
            home: BlocBuilder<AuthBloc, AuthState>(
              builder: (context, state) {
                switch (state.status) {
                  case AuthStatus.authenticated:
                    final user = state.user!;
                    if (hasAppAccess != null && !hasAppAccess!(user)) {
                      return const SubscriptionPaywallScreen();
                    }
                    return _ModularScaffold(
                      appTitle: title,
                      tabs: tabsBuilder(context, user),
                    );
                  case AuthStatus.unauthenticated:
                  case AuthStatus.error:
                  case AuthStatus.inactivitySuspended:
                    return const AuthScreen();
                  case AuthStatus.loading:
                  case AuthStatus.initial:
                    return _ModularSplashScreen(subtitle: subtitle);
                }
              },
            ),
          );
        },
      ),
    );
  }
}

class _ModularScaffold extends StatefulWidget {
  final String appTitle;
  final List<AppTabDefinition> tabs;

  const _ModularScaffold({
    required this.appTitle,
    required this.tabs,
  });

  @override
  State<_ModularScaffold> createState() => _ModularScaffoldState();
}

class _ModularScaffoldState extends State<_ModularScaffold> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      final check = await OtaUpdateService.checkForUpdates();
      if (check.hasUpdate && check.latestRelease != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Mise à jour ${check.latestRelease!.versionName} disponible pour ${widget.appTitle}',
            ),
            action: SnackBarAction(
              label: 'Télécharger',
              onPressed: () {
                OtaUpdateService.startUpdateProcess(
                  check.latestRelease!,
                  onProgress: (_) {},
                  onStatusChange: (_) {},
                );
              },
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final safeIndex = _index.clamp(0, widget.tabs.length - 1);
    final current = widget.tabs[safeIndex];
    final isWide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const MedsinaLogo.icon(size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                current.title,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Annonces',
            icon: const Icon(Icons.campaign_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AnnouncementsHubScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Profil & Abonnement',
            icon: const Icon(Icons.person_outline_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ModernUserProfileScreen()),
            ),
          ),
        ],
      ),
      body: isWide
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: safeIndex,
                  onDestinationSelected: (i) => setState(() => _index = i),
                  labelType: NavigationRailLabelType.all,
                  destinations: widget.tabs
                      .map((t) => NavigationRailDestination(
                            icon: Icon(t.icon),
                            selectedIcon: Icon(t.selectedIcon),
                            label: Text(t.label),
                          ))
                      .toList(),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: current.page),
              ],
            )
          : current.page,
      bottomNavigationBar: isWide || widget.tabs.length < 2
          ? null
          : NavigationBar(
              selectedIndex: safeIndex,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: widget.tabs
                  .map((t) => NavigationDestination(
                        icon: Icon(t.icon),
                        selectedIcon: Icon(t.selectedIcon),
                        label: t.label,
                      ))
                  .toList(),
            ),
    );
  }
}

class _ModularSplashScreen extends StatelessWidget {
  final String subtitle;

  const _ModularSplashScreen({required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const MedsinaLogo.icon(size: 68),
            const SizedBox(height: 20),
            const MedsinaLogo(height: 36),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white70 : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(color: AppTheme.primaryTeal),
          ],
        ),
      ),
    );
  }
}
