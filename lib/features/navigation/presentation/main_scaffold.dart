import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_event.dart';
import '../../auth/bloc/auth_state.dart';
import '../../clinical/presentation/clinical_screen.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../../practical_tools/presentation/practical_tools_screen.dart';
import '../../revision/presentation/revision_catalog_screen.dart';
import '../../subscription/presentation/subscription_paywall_screen.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    DashboardScreen(),
    ClinicalScreen(),
    RevisionCatalogScreen(),
    PracticalToolsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 850;

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        final user = authState.user;
        final tier = user?.tier ?? SubscriptionTier.free;

        if (isDesktop) {
          return Scaffold(
            body: Row(
              children: [
                // Desktop Navigation Sidebar
                _buildSidebar(context, tier, user?.fullName ?? 'Médecin'),
                const VerticalDivider(width: 1, thickness: 1),
                // Main Content
                Expanded(
                  child: Scaffold(
                    appBar: _buildDesktopTopBar(context, tier),
                    body: _pages[_currentIndex],
                  ),
                ),
              ],
            ),
          );
        }

        // Mobile Layout (Android APK & small screens)
        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryTeal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.local_hospital_rounded, color: AppTheme.primaryTeal, size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  AppConstants.appName,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
                ),
              ],
            ),
            actions: [
              _buildTierBadge(context, tier),
              const SizedBox(width: 12),
            ],
          ),
          body: IndexedStack(
            index: _currentIndex,
            children: _pages,
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard_rounded, color: AppTheme.primaryTeal),
                label: 'Accueil',
              ),
              NavigationDestination(
                icon: Icon(Icons.medical_services_outlined),
                selectedIcon: Icon(Icons.medical_services_rounded, color: AppTheme.primaryTeal),
                label: 'Clinique',
              ),
              NavigationDestination(
                icon: Icon(Icons.school_outlined),
                selectedIcon: Icon(Icons.school_rounded, color: AppTheme.primaryTeal),
                label: 'Résidanat',
              ),
              NavigationDestination(
                icon: Icon(Icons.handyman_outlined),
                selectedIcon: Icon(Icons.handyman_rounded, color: AppTheme.primaryTeal),
                label: 'Outils',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSidebar(BuildContext context, SubscriptionTier tier, String userName) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 260,
      color: isDark ? AppTheme.darkSurface : Colors.white,
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primaryTeal, AppTheme.accentCyan],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.local_hospital_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppConstants.appName,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'SaaS Médical Global',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // User & Subscription Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppTheme.primaryTeal,
                        child: Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : 'M',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userName,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              tier.label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: tier.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        side: BorderSide(color: tier.color),
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const SubscriptionPaywallScreen()),
                        );
                      },
                      child: Text(
                        tier == SubscriptionTier.allAccess ? 'Gérer Licence' : 'Mettre à niveau ⚡',
                        style: TextStyle(fontSize: 12, color: tier.color, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),

          // Nav Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              children: [
                _buildNavItem(0, 'Tableau de bord', Icons.dashboard_rounded),
                _buildNavItem(1, 'Pratique Clinique', Icons.medical_services_rounded),
                _buildNavItem(2, 'Formation Résidanat', Icons.school_rounded),
                _buildNavItem(3, 'Outils Pratiques & Garde', Icons.handyman_rounded),
              ],
            ),
          ),

          const Divider(height: 1),
          // Footer
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Blida Résidanat 2027 v${AppConstants.appVersion}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  tooltip: 'Déconnexion',
                  onPressed: () {
                    context.read<AuthBloc>().add(LogoutEvent());
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, String title, IconData icon) {
    final isSelected = _currentIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        selected: isSelected,
        selectedTileColor: AppTheme.primaryTeal.withValues(alpha: isDark ? 0.2 : 0.1),
        leading: Icon(
          icon,
          color: isSelected ? AppTheme.primaryTeal : Colors.grey.shade500,
          size: 20,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppTheme.primaryTeal : (isDark ? Colors.white70 : const Color(0xFF334155)),
          ),
        ),
        onTap: () => setState(() => _currentIndex = index),
      ),
    );
  }

  PreferredSizeWidget _buildDesktopTopBar(BuildContext context, SubscriptionTier tier) {
    return AppBar(
      title: Text(_getPageTitle(_currentIndex)),
      actions: [
        _buildTierBadge(context, tier),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildTierBadge(BuildContext context, SubscriptionTier tier) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SubscriptionPaywallScreen()),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: tier.color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: tier.color.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.workspace_premium_rounded, size: 16, color: tier.color),
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
        ),
      ),
    );
  }

  String _getPageTitle(int index) {
    switch (index) {
      case 0:
        return 'Tableau de bord Medsina';
      case 1:
        return 'Pratique Clinique & Protocoles d\'Urgence';
      case 2:
        return 'Formation & Préparation Résidanat 2027';
      case 3:
        return 'Applications Pratiques & Mémento de Garde';
      default:
        return AppConstants.appName;
    }
  }
}
