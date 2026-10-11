import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_event.dart';
import '../../auth/bloc/auth_state.dart';
import '../../auth/models/user_model.dart';
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
                _buildSidebar(context, tier, user),
                const VerticalDivider(width: 1, thickness: 1),
                // Main Content
                Expanded(
                  child: Scaffold(
                    appBar: _buildDesktopTopBar(context, tier, user),
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
                const Text(
                  AppConstants.appName,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
                ),
              ],
            ),
            actions: [
              _buildTierBadge(context, tier),
              const SizedBox(width: 8),
              _buildUserAvatarAction(context, user),
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

  Widget _buildSidebar(BuildContext context, SubscriptionTier tier, UserModel? user) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userName = user?.fullName ?? 'Médecin';

    return Container(
      width: 270,
      color: isDark ? AppTheme.darkSurface : Colors.white,
      child: Column(
        children: [
          // Header Logo
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primaryTeal, AppTheme.accentCyan],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
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
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'SaaS Médical & Résidanat',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // User & Subscription Card (Clickable to open profile)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: InkWell(
              onTap: () => _showUserProfileModal(context, user),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFF1F5F9),
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
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppTheme.primaryTeal,
                          child: Text(
                            userName.isNotEmpty ? userName[0].toUpperCase() : 'M',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
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
                                user?.medicalRole ?? 'Candidat Résidanat',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: isDark ? Colors.white60 : Colors.grey.shade600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: tier.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: tier.color.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            tier.badgeText,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: tier.color,
                            ),
                          ),
                        ),
                        Text(
                          '${user?.daysRemaining ?? 14}j restants',
                          style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Résidanat Blida 2027',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade500),
                      ),
                      Text(
                        'v${AppConstants.appVersion} • Cloud Medsina',
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  tooltip: 'Déconnexion',
                  onPressed: () => _confirmLogout(context),
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

  PreferredSizeWidget _buildDesktopTopBar(BuildContext context, SubscriptionTier tier, UserModel? user) {
    return AppBar(
      title: Text(_getPageTitle(_currentIndex)),
      actions: [
        _buildTierBadge(context, tier),
        const SizedBox(width: 8),
        _buildUserAvatarAction(context, user),
        const SizedBox(width: 16),
      ],
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
                  ],
                ),
              ),

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

              const SizedBox(height: 20),
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
