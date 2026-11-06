import '../../announcements/presentation/announcements_hub_screen.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/medsina_logo.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_event.dart';
import '../../auth/bloc/auth_state.dart';
import '../../auth/models/user_model.dart';
import '../../admin/presentation/admin_dashboard_screen.dart';
import '../../clinical/presentation/clinical_screen.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../../practical_tools/presentation/practical_tools_screen.dart';
import '../../prescription/presentation/prescription_analysis_screen.dart';
import '../../revision/presentation/revision_catalog_screen.dart';
import '../../externat/presentation/externat_catalog_screen.dart';
import '../../subscription/presentation/subscription_paywall_screen.dart';
import '../../subscription/presentation/referral_screen.dart';
import '../../notifications/models/medical_notification.dart';
import '../../notifications/presentation/notifications_modal_sheet.dart';
import '../../notifications/services/notification_navigation_service.dart';
import '../../notifications/services/realtime_notification_service.dart';
import '../../../core/services/ota_update_service.dart';
import 'ota_update_dialog.dart';
import '../../feedback/presentation/feedback_reviews_screen.dart';
import '../../help/presentation/user_guide_pdf_viewer_screen.dart';
import '../../search/presentation/global_search_screen.dart';
import 'package:flutter/services.dart';

class NavItemConfig {
  final String label;
  final String title;
  final IconData icon;
  final IconData selectedIcon;
  final Widget page;
  final bool isSpecial;

  const NavItemConfig({
    required this.label,
    required this.title,
    required this.icon,
    required this.selectedIcon,
    required this.page,
    this.isSpecial = false,
  });
}

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;
  late final StreamSubscription<MedicalNotification> _notificationSub;

  @override
  void initState() {
    super.initState();
    final initialUser = context.read<AuthBloc>().state.user;
    RealtimeNotificationService.instance.setCurrentUser(
      initialUser?.id,
      isAdmin: initialUser?.isAdmin == true,
    );
    _notificationSub = RealtimeNotificationService.instance.onNewNotification.listen((notif) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: notif.type.color,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Row(
              children: [
                Icon(notif.type.icon, color: Colors.white, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notif.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                      ),
                      Text(
                        notif.message,
                        style: const TextStyle(fontSize: 11.5, color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            action: SnackBarAction(
              label: 'Voir',
              textColor: Colors.white,
              onPressed: () {
                NotificationNavigationService.handleNotificationTap(context, notif);
              },
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    });

    // Check for Over-The-Air updates after frame renders
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkOtaUpdateOnLaunch();
    });
  }

  Future<void> _checkOtaUpdateOnLaunch() async {
    // Delay slightly to not block initial home render
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final check = await OtaUpdateService.checkForUpdates();
    if (check.hasUpdate && check.latestRelease != null && mounted) {
      OtaUpdateDialog.show(
        context,
        release: check.latestRelease!,
        currentVersion: check.currentVersion,
        isMandatory: check.isMandatory,
      );
    }
  }

  @override
  void dispose() {
    _notificationSub.cancel();
    super.dispose();
  }

  List<NavItemConfig> _getNavItems(SubscriptionTier tier, bool isExpired, bool isAdmin) {
    final items = <NavItemConfig>[];

    // 1. Dashboard: Accueil adapté pour tout le monde
    items.add(const NavItemConfig(
      label: 'Accueil',
      title: 'Tableau de bord Medsina',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard_rounded,
      page: DashboardScreen(),
    ));

    if (isExpired) {
      // Pour compte expiré: garde la structure globale pour inciter au renouvellement
      items.add(const NavItemConfig(
        label: 'Clinique',
        title: 'Pratique Clinique & Protocoles d\'Urgence',
        icon: Icons.medical_services_outlined,
        selectedIcon: Icons.medical_services_rounded,
        page: ClinicalScreen(),
      ));
      items.add(const NavItemConfig(
        label: 'Résidanat',
        title: 'Formation & Préparation Résidanat 2027',
        icon: Icons.school_outlined,
        selectedIcon: Icons.school_rounded,
        page: RevisionCatalogScreen(),
      ));
      items.add(const NavItemConfig(
        label: 'Externat',
        title: 'Cursus Médical & Externat (1ère - 6ème Année)',
        icon: Icons.local_library_outlined,
        selectedIcon: Icons.local_library_rounded,
        page: ExternatCatalogScreen(),
      ));
      items.add(const NavItemConfig(
        label: 'Mémento',
        title: 'Mémento de Garde',
        icon: Icons.handyman_outlined,
        selectedIcon: Icons.handyman_rounded,
        page: PracticalToolsScreen(),
      ));
    } else {
      switch (tier) {
        case SubscriptionTier.etudiant:
          // Étudiant en Médecine: Hub complet Externat & EMDs (1ère à 6ème Année)
          items.add(const NavItemConfig(
            label: 'Externat',
            title: 'Cursus Médical & Externat (1ère - 6ème Année)',
            icon: Icons.school_outlined,
            selectedIcon: Icons.school_rounded,
            page: ExternatCatalogScreen(),
          ));
          items.add(const NavItemConfig(
            label: 'Outils & Normes',
            title: 'Normes Biologiques & Calculateurs',
            icon: Icons.calculate_outlined,
            selectedIcon: Icons.calculate_rounded,
            page: PracticalToolsScreen(),
          ));
          break;

        case SubscriptionTier.residentElite:
          // Dr. Amine: Uniquement Résidanat et ses outils de révision
          items.add(const NavItemConfig(
            label: 'Résidanat',
            title: 'Formation & Préparation Résidanat 2027',
            icon: Icons.school_outlined,
            selectedIcon: Icons.school_rounded,
            page: RevisionCatalogScreen(),
          ));
          items.add(const NavItemConfig(
            label: 'Mémento',
            title: 'Mémento de Garde',
            icon: Icons.handyman_outlined,
            selectedIcon: Icons.handyman_rounded,
            page: PracticalToolsScreen(),
          ));
          break;

        case SubscriptionTier.clinicalPro:
          // Dr. Yasmine: Pratique Clinique, Analyse Ordonnance (Vidal) et Mémento de garde
          items.add(const NavItemConfig(
            label: 'Clinique',
            title: 'Pratique Clinique & Protocoles d\'Urgence',
            icon: Icons.medical_services_outlined,
            selectedIcon: Icons.medical_services_rounded,
            page: ClinicalScreen(),
          ));
          items.add(const NavItemConfig(
            label: 'Ordonnance',
            title: 'Analyse d\'Ordonnance (Vidal)',
            icon: Icons.fact_check_outlined,
            selectedIcon: Icons.fact_check_rounded,
            page: PrescriptionAnalysisScreen(),
          ));
          items.add(const NavItemConfig(
            label: 'Mémento',
            title: 'Mémento de Garde',
            icon: Icons.handyman_outlined,
            selectedIcon: Icons.handyman_rounded,
            page: PracticalToolsScreen(),
          ));
          break;

        case SubscriptionTier.allAccess:
        case SubscriptionTier.free:
          // VIP Dr. Hafedh & Découverte Dr. Sarah: Vue complète
          items.add(const NavItemConfig(
            label: 'Clinique',
            title: 'Pratique Clinique & Protocoles d\'Urgence',
            icon: Icons.medical_services_outlined,
            selectedIcon: Icons.medical_services_rounded,
            page: ClinicalScreen(),
          ));
          items.add(const NavItemConfig(
            label: 'Ordonnance',
            title: 'Analyse d\'Ordonnance (Vidal)',
            icon: Icons.fact_check_outlined,
            selectedIcon: Icons.fact_check_rounded,
            page: PrescriptionAnalysisScreen(),
          ));
          items.add(const NavItemConfig(
            label: 'Résidanat',
            title: 'Formation & Préparation Résidanat 2027',
            icon: Icons.school_outlined,
            selectedIcon: Icons.school_rounded,
            page: RevisionCatalogScreen(),
          ));
          items.add(const NavItemConfig(
            label: 'Externat',
            title: 'Cursus Médical & Externat (1ère - 6ème Année)',
            icon: Icons.local_library_outlined,
            selectedIcon: Icons.local_library_rounded,
            page: ExternatCatalogScreen(),
          ));
          items.add(const NavItemConfig(
            label: 'Mémento',
            title: 'Mémento de Garde',
            icon: Icons.handyman_outlined,
            selectedIcon: Icons.handyman_rounded,
            page: PracticalToolsScreen(),
          ));
          break;
      }
    }

    if (isAdmin) {
      items.add(const NavItemConfig(
        label: 'Admin',
        title: 'Console d\'Administration Medsina',
        icon: Icons.admin_panel_settings_outlined,
        selectedIcon: Icons.admin_panel_settings_rounded,
        page: AdminDashboardScreen(),
        isSpecial: true,
      ));
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 850;

    return BlocConsumer<AuthBloc, AuthState>(
      listenWhen: (prev, current) => prev.user?.id != current.user?.id,
      listener: (context, authState) {
        final u = authState.user;
        RealtimeNotificationService.instance.setCurrentUser(
          u?.id,
          isAdmin: u?.isAdmin == true,
        );
      },
      builder: (context, authState) {
        final user = authState.user;
        final isAdmin = user?.isAdmin == true;
        final isExpired = user != null && !user.isSubscriptionActive;
        final tier = user?.tier ?? SubscriptionTier.free;
        final navItems = _getNavItems(tier, isExpired, isAdmin);
        final safeIndex = _currentIndex < navItems.length ? _currentIndex : 0;
        final currentItem = navItems[safeIndex];

        if (isDesktop) {
          return CallbackShortcuts(
            bindings: <ShortcutActivator, VoidCallback>{
              const SingleActivator(LogicalKeyboardKey.keyK, control: true): () => _openOmnisearch(context),
              const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () => _openOmnisearch(context),
            },
            child: Focus(
              autofocus: true,
              child: Scaffold(
            body: Row(
              children: [
                // Desktop Navigation Sidebar (Floating Bento Cards)
                _buildSidebar(context, tier, user, navItems, safeIndex),
                // Main Content
                Expanded(
                  child: Scaffold(
                    appBar: _buildDesktopTopBar(context, tier, user, currentItem.title),
                    body: currentItem.page,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

        // Mobile Layout (Android APK & small screens)
        final isDarkMobile = Theme.of(context).brightness == Brightness.dark;
        return Scaffold(
          appBar: _buildMobileTopBar(context, tier, user),
          body: IndexedStack(
            index: safeIndex,
            children: navItems.map((item) => item.page).toList(),
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: isDarkMobile ? AppTheme.darkSurface : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDarkMobile ? AppTheme.darkBorder : AppTheme.lightBorder,
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDarkMobile ? 0.25 : 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: NavigationBarTheme(
              data: NavigationBarThemeData(
                height: 66,
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                indicatorColor: isDarkMobile
                    ? AppTheme.primaryTeal.withValues(alpha: 0.22)
                    : AppTheme.clinicalNavy,
                indicatorShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>(
                  (states) => TextStyle(
                    fontSize: navItems.length >= 6 ? 9.5 : (navItems.length >= 5 ? 10 : 11.5),
                    fontWeight: states.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
                    letterSpacing: -0.2,
                    color: states.contains(WidgetState.selected)
                        ? (isDarkMobile ? Colors.white : AppTheme.clinicalNavy)
                        : (isDarkMobile ? Colors.white60 : const Color(0xFF64748B)),
                  ),
                ),
              ),
              child: NavigationBar(
                selectedIndex: safeIndex,
                onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
                labelBehavior: MediaQuery.of(context).size.width < 380 && navItems.length >= 6
                    ? NavigationDestinationLabelBehavior.onlyShowSelected
                    : NavigationDestinationLabelBehavior.alwaysShow,
                destinations: navItems.map((item) {
                  String displayLabel = item.label;
                  if (navItems.length >= 5 && displayLabel == 'Ordonnance') {
                    displayLabel = 'Ordo / Rx';
                  }
                  return NavigationDestination(
                    icon: Icon(
                      item.icon,
                      size: 21,
                      color: isDarkMobile ? Colors.white70 : const Color(0xFF64748B),
                    ),
                    selectedIcon: Icon(
                      item.selectedIcon,
                      size: 21,
                      color: item.isSpecial
                          ? const Color(0xFFEF4444)
                          : (isDarkMobile ? AppTheme.primaryTeal : Colors.white),
                    ),
                    label: displayLabel,
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSidebar(
    BuildContext context,
    SubscriptionTier tier,
    UserModel? user,
    List<NavItemConfig> navItems,
    int selectedIndex,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userName = user?.fullName ?? 'Médecin';

    return Material(
      color: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      child: SizedBox(
        width: 276,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
          child: Column(
            children: [
              // Floating Brand & User Header Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: AppTheme.bentoCardDecoration(context, radius: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const MedsinaLogo(height: 30),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryTeal.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            '2027',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primaryTeal,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: () => _showUserProfileModal(context, user),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkSurfaceElevated : AppTheme.lightSurfaceElevated,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [AppTheme.clinicalNavy, AppTheme.primaryTeal],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    userName.isNotEmpty ? userName[0].toUpperCase() : 'M',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        userName,
                                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        user?.medicalRole ?? 'Candidat Résidanat',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.unfold_more_rounded, size: 16, color: Colors.grey),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: tier.color.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    tier.badgeText,
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: tier.color,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${user?.daysRemaining ?? 14}j restants',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Floating Navigation Card (matches Pinterest/Dribbble UI concept)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  decoration: AppTheme.bentoCardDecoration(context, radius: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
                        child: Text(
                          'ESPACE MÉDICAL',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.9,
                            color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: navItems.length,
                          itemBuilder: (context, index) {
                            final item = navItems[index];
                            return _buildNavItem(
                              index: index,
                              selectedIndex: selectedIndex,
                              title: item.label,
                              subtitle: item.title,
                              icon: isSelectedIndex(index, selectedIndex) ? item.selectedIcon : item.icon,
                              isSpecial: item.isSpecial,
                            );
                          },
                        ),
                      ),
                      if (tier == SubscriptionTier.clinicalPro) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: AppTheme.heroNavyDecoration(radius: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.school_rounded, size: 14, color: Color(0xFF2DD4BF)),
                                  const SizedBox(width: 6),
                                  const Expanded(
                                    child: Text(
                                      'Concours Résidanat 2027',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF2DD4BF),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                '47 modules & Livrets All-in-One.',
                                style: TextStyle(fontSize: 10.5, color: Colors.white70),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryTeal,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                    minimumSize: const Size(0, 30),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => const RevisionCatalogScreen()),
                                    );
                                  },
                                  child: const Text(
                                    'Ouvrir le Catalogue',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Compact Bottom Quick-Action Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: AppTheme.bentoCardDecoration(context, radius: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Medsina Cloud',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white70 : AppTheme.clinicalNavy,
                            ),
                          ),
                          Text(
                            'v${AppConstants.appVersion}',
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.star_rounded, size: 18, color: Colors.amber),
                      tooltip: 'Avis & Évaluations Medsina',
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const FeedbackReviewsScreen()),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.menu_book_rounded, size: 17),
                      tooltip: 'Guide d\'utilisation (PDF)',
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const UserGuidePdfViewerScreen()),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.system_update_rounded, size: 17),
                      tooltip: 'Vérifier les mises à jour',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _manualCheckOtaUpdates(context),
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout_rounded, size: 17, color: Color(0xFFEF4444)),
                      tooltip: 'Déconnexion',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _confirmLogout(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool isSelectedIndex(int index, int selectedIndex) => index == selectedIndex;

  void _openOmnisearch(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const GlobalSearchScreen()),
    );
  }

  Future<void> _manualCheckOtaUpdates(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Recherche de mises à jour en cours...'),
        duration: Duration(seconds: 1),
      ),
    );

    final check = await OtaUpdateService.checkForUpdates(ignoreDismissed: true);
    if (!context.mounted) return;

    if (check.hasUpdate && check.latestRelease != null) {
      OtaUpdateDialog.show(
        context,
        release: check.latestRelease!,
        currentVersion: check.currentVersion,
        isMandatory: check.isMandatory,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Vous utilisez déjà la dernière version (v${check.currentVersion}) ✨'),
          backgroundColor: AppTheme.primaryTeal,
        ),
      );
    }
  }

  Widget _buildNavItem({
    required int index,
    required int selectedIndex,
    required String title,
    String? subtitle,
    required IconData icon,
    bool isSpecial = false,
  }) {
    final isSelected = selectedIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeBg = isSpecial
        ? const Color(0xFFDC2626)
        : (isDark ? AppTheme.primaryTeal : AppTheme.clinicalNavy);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _currentIndex = index),
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: isSelected ? activeBg : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: activeBg.withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected
                      ? Colors.white
                      : (isSpecial
                          ? const Color(0xFFDC2626)
                          : (isDark ? Colors.white60 : const Color(0xFF64748B))),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : (isSpecial
                              ? const Color(0xFFDC2626)
                              : (isDark ? Colors.white70 : const Color(0xFF1E293B))),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2DD4BF),
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildMobileTopBar(
    BuildContext context,
    SubscriptionTier tier,
    UserModel? user,
  ) {
    return AppBar(
      titleSpacing: 14,
      title: const MedsinaLogo(height: 31),
      actions: [
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildModernActionDock(context, includeSearch: true),
                const SizedBox(width: 6),
                _buildModernProfileAndTierPill(context, tier, user),
                const SizedBox(width: 12),
              ],
            ),
          ),
        ),
      ],
    );
  }

  PreferredSizeWidget _buildDesktopTopBar(
    BuildContext context,
    SubscriptionTier tier,
    UserModel? user,
    String pageTitle,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppBar(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      toolbarHeight: 68,
      titleSpacing: 20,
      title: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              pageTitle,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: isDark ? Colors.white : AppTheme.clinicalNavy,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 4,
            child: InkWell(
              onTap: () => _openOmnisearch(context),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.clinicalNavy.withValues(alpha: isDark ? 0.15 : 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, size: 18, color: AppTheme.primaryTeal),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Rechercher cours, QCMs, CAT, doses... (Omnisearch)',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white54 : const Color(0xFF64748B),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkSurfaceElevated : AppTheme.lightSurfaceElevated,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                        ),
                      ),
                      child: Text(
                        '⌘K',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white70 : AppTheme.clinicalNavy,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        const SizedBox(width: 12),
        _buildModernActionDock(context, includeSearch: false),
        const SizedBox(width: 10),
        _buildTierBadge(context, tier),
        const SizedBox(width: 8),
        _buildUserAvatarAction(context, user),
        const SizedBox(width: 20),
      ],
    );
  }

  Widget _buildModernActionDock(BuildContext context, {required bool includeSearch}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (includeSearch) ...[
            _buildDockIconButton(
              icon: Icons.search_rounded,
              tooltip: 'Recherche Globale (Omnisearch)',
              color: AppTheme.primaryTeal,
              bgTint: AppTheme.primaryTeal.withValues(alpha: 0.12),
              onTap: () => _openOmnisearch(context),
            ),
            _buildDockDivider(isDark),
          ],
          _buildDockIconButton(
            icon: Icons.star_rounded,
            tooltip: 'Avis & Évaluations Medsina (5★)',
            color: const Color(0xFFF59E0B),
            bgTint: const Color(0xFFF59E0B).withValues(alpha: 0.14),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FeedbackReviewsScreen()),
              );
            },
          ),
          const SizedBox(width: 3),
          _buildDockIconButton(
            icon: Icons.menu_book_rounded,
            tooltip: 'Guide d\'utilisation Medsina (PDF)',
            color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
            bgTint: const Color(0xFF6366F1).withValues(alpha: 0.11),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const UserGuidePdfViewerScreen()),
              );
            },
          ),
          const SizedBox(width: 3),
          _buildDockIconButton(
            icon: Icons.system_update_rounded,
            tooltip: 'Vérifier les mises à jour',
            color: const Color(0xFF0284C7),
            bgTint: const Color(0xFF0284C7).withValues(alpha: 0.11),
            onTap: () => _manualCheckOtaUpdates(context),
          ),
          _buildDockDivider(isDark),
          _buildDockIconButton(
            icon: Icons.campaign_rounded,
            tooltip: 'Annonces & Nouveautés Medsina',
            color: const Color(0xFF14B8A6),
            bgTint: const Color(0xFF14B8A6).withValues(alpha: 0.12),
            onTap: () => AnnouncementsHubScreen.push(context),
          ),
          const SizedBox(width: 3),
          _buildNotificationBellAction(context, compact: true),
        ],
      ),
    );
  }

  Widget _buildDockDivider(bool isDark) {
    return Container(
      width: 1,
      height: 18,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
    );
  }

  Widget _buildDockIconButton({
    required IconData icon,
    required String tooltip,
    required Color color,
    required Color bgTint,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: bgTint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17.5, color: color),
          ),
        ),
      ),
    );
  }

  Widget _buildModernProfileAndTierPill(
    BuildContext context,
    SubscriptionTier tier,
    UserModel? user,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userName = user?.fullName ?? 'M';
    final initial = userName.isNotEmpty ? userName[0].toUpperCase() : 'M';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: tier.color.withValues(alpha: 0.45),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: tier.color.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: 'Abonnement : ${tier.label}',
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SubscriptionPaywallScreen()),
                );
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                decoration: BoxDecoration(
                  color: tier.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.workspace_premium_rounded,
                  size: 15,
                  color: tier.color,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Tooltip(
            message: 'Mon Profil (${user?.fullName ?? "Médecin"})',
            child: InkWell(
              onTap: () => _showUserProfileModal(context, user),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationBellAction(BuildContext context, {bool compact = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ValueListenableBuilder<int>(
      valueListenable: RealtimeNotificationService.instance.unreadCountNotifier,
      builder: (context, unreadCount, _) {
        final hasUnread = unreadCount > 0;
        if (compact) {
          return Tooltip(
            message: 'Notifications & Mises à jour en direct',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => NotificationsModalSheet.show(context),
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 30,
                  height: 30,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: hasUnread
                              ? AppTheme.primaryTeal.withValues(alpha: 0.15)
                              : (isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          hasUnread ? Icons.notifications_active_rounded : Icons.notifications_outlined,
                          color: hasUnread
                              ? AppTheme.primaryTeal
                              : (isDark ? Colors.grey.shade300 : const Color(0xFF475569)),
                          size: 17.5,
                        ),
                      ),
                      if (hasUnread)
                        Positioned(
                          top: 2,
                          right: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 3.5, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                width: 1.2,
                              ),
                            ),
                            constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                            child: Center(
                              child: Text(
                                '$unreadCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: Icon(
                hasUnread ? Icons.notifications_active_rounded : Icons.notifications_outlined,
                color: hasUnread ? AppTheme.primaryTeal : Colors.grey.shade600,
                size: 22,
              ),
              tooltip: 'Notifications & Mises à jour en direct',
              onPressed: () => NotificationsModalSheet.show(context),
            ),
            if (hasUnread)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Center(
                    child: Text(
                      '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildUserAvatarAction(BuildContext context, UserModel? user) {
    final userName = user?.fullName ?? 'M';
    return InkWell(
      onTap: () => _showUserProfileModal(context, user),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: CircleAvatar(
          radius: 17,
          backgroundColor: AppTheme.primaryTeal,
          child: Text(
            userName.isNotEmpty ? userName[0].toUpperCase() : 'M',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
      ),
    );
  }

  Widget _buildTierBadge(BuildContext context, SubscriptionTier tier, {bool compact = false}) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SubscriptionPaywallScreen()),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12, vertical: compact ? 4 : 6),
        decoration: BoxDecoration(
          color: tier.color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: tier.color.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.workspace_premium_rounded, size: compact ? 15 : 16, color: tier.color),
            if (!compact) ...[
              const SizedBox(width: 6),
              Text(
                tier.badgeText,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: tier.color,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFFDC2626)),
            SizedBox(width: 8),
            Text('Déconnexion'),
          ],
        ),
        content: const Text(
          'Êtes-vous sûr de vouloir vous déconnecter de Medsina ? Vos données locales sont synchronisées sur le Cloud.',
          style: TextStyle(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AuthBloc>().add(LogoutEvent());
            },
            child: const Text('Se déconnecter', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showUserProfileModal(BuildContext context, UserModel? user) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final licenseController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppTheme.primaryTeal,
                    child: Text(
                      user?.fullName.isNotEmpty == true ? user!.fullName[0].toUpperCase() : 'M',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.fullName ?? 'Médecin',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          user?.email ?? '',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryTeal.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                user?.medicalRole ?? 'Candidat Résidanat',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryTeal,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                user?.faculty ?? 'Faculté de Médecine de Blida',
                                style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),

              // Subscription info card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: user?.tier.color.withValues(alpha: 0.1) ?? Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: user?.tier.color.withValues(alpha: 0.4) ?? Colors.grey.shade300,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.workspace_premium_rounded, color: user?.tier.color, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              user?.tier.label ?? 'Abonnement',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: user?.tier.color,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Actif',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Expire le : ${user?.subscriptionExpiry.day}/${user?.subscriptionExpiry.month}/${user?.subscriptionExpiry.year} (${user?.daysRemaining} jours restants)',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: user?.tier.color ?? AppTheme.primaryTeal),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const SubscriptionPaywallScreen()),
                          );
                        },
                        child: const Text('Voir toutes les formules et tarifs ➔', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D9488),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.group_add_rounded, size: 16),
                        label: const Text('Parrainer un confrère (+7j VIP offerts) 🤝', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ReferralScreen()),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFD97706),
                          side: const BorderSide(color: Color(0xFFF59E0B)),
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.star_rounded, size: 17, color: Color(0xFFF59E0B)),
                        label: const Text(
                          'Noter Medsina & Voir les Avis ⭐',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const FeedbackReviewsScreen()),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              if (user?.isAdmin == true) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.admin_panel_settings_rounded, size: 18),
                    label: const Text('Ouvrir la Console Admin 🛡️', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() => _currentIndex = 4);
                    },
                  ),
                ),
              ],

              const SizedBox(height: 20),
              // License Key Redemption Box
              const Text(
                'Activer une Clé de Licence Pro / VIP',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: licenseController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        hintText: 'Ex: MEDSINA-2027-VIP',
                        isDense: true,
                        prefixIcon: Icon(Icons.vpn_key_outlined, size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () {
                      final code = licenseController.text.trim();
                      if (code.isNotEmpty) {
                        Navigator.pop(ctx);
                        context.read<AuthBloc>().add(ActivateLicenseKeyEvent(licenseKey: code));
                      }
                    },
                    child: const Text('Activer'),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              // Cloud status indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurfaceElevated : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_done_rounded, color: Color(0xFF16A34A), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Serveur Medsina Cloud sécurisé et synchronisé.',
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.grey.shade700),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              const Center(child: MedsinaLogo(height: 28)),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('Se déconnecter de Medsina', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _confirmLogout(context);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
