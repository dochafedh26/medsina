import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../bloc/admin_bloc.dart';
import '../bloc/admin_event.dart';
import '../bloc/admin_state.dart';
import '../models/admin_models.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    context.read<AdminBloc>().add(LoadAdminDataEvent());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocConsumer<AdminBloc, AdminState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFFDC2626),
              content: Text(state.errorMessage!),
            ),
          );
          context.read<AdminBloc>().add(ClearAdminMessageEvent());
        } else if (state.successMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF16A34A),
              content: Text(state.successMessage!),
            ),
          );
          context.read<AdminBloc>().add(ClearAdminMessageEvent());
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFFDC2626), size: 20),
                ),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Console d\'Administration Medsina',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    Text(
                      'Supervision SaaS • Utilisateurs & Licences',
                      style: TextStyle(fontSize: 10.5, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Actualiser les données',
                onPressed: () => context.read<AdminBloc>().add(LoadAdminDataEvent()),
              ),
              const SizedBox(width: 8),
            ],
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: AppTheme.primaryTeal,
              unselectedLabelColor: isDark ? Colors.white60 : Colors.grey.shade600,
              indicatorColor: AppTheme.primaryTeal,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              tabs: const [
                Tab(icon: Icon(Icons.analytics_outlined), text: 'Métriques & KPIs'),
                Tab(icon: Icon(Icons.people_outline_rounded), text: 'Médecins & Abonnements'),
                Tab(icon: Icon(Icons.vpn_key_outlined), text: 'Générateur de Licences'),
                Tab(icon: Icon(Icons.library_books_outlined), text: 'Catalogue Médical'),
              ],
            ),
          ),
          body: state.status == AdminStatus.loading && state.metrics == null
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(context, state, isDark),
                    _buildUsersTab(context, state, isDark),
                    _buildLicensesTab(context, state, isDark),
                    _buildContentTab(context, isDark),
                  ],
                ),
        );
      },
    );
  }

  // --- TAB 1 : METRICS & KPIS ---
  Widget _buildOverviewTab(BuildContext context, AdminState state, bool isDark) {
    final m = state.metrics ??
        const AdminMetrics(
          totalUsers: 0,
          freeTrials: 0,
          clinicalPro: 0,
          residentElite: 0,
          allAccess: 0,
          totalLicenses: 0,
          redeemedLicenses: 0,
          availableLicenses: 0,
        );

    final totalPaying = m.clinicalPro + m.residentElite + m.allAccess;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Top 4 Metric Cards
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Médecins Inscrits',
                '${m.totalUsers}',
                Icons.people_alt_rounded,
                const Color(0xFF0F766E),
                isDark,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildMetricCard(
                'Abonnés Actifs',
                '$totalPaying',
                Icons.workspace_premium_rounded,
                const Color(0xFFD97706),
                isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Licences Créées',
                '${m.totalLicenses}',
                Icons.vpn_key_rounded,
                const Color(0xFF2563EB),
                isDark,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildMetricCard(
                'Licences Disponibles',
                '${m.availableLicenses}',
                Icons.check_circle_outline_rounded,
                const Color(0xFF16A34A),
                isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Subscription Tier Distribution Card
        Card(
          elevation: isDark ? 0 : 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.pie_chart_outline_rounded, color: AppTheme.primaryTeal),
                    SizedBox(width: 8),
                    Text(
                      'Répartition par Formule d\'Abonnement',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildTierRow('All-Access VIP (Complet)', m.allAccess, const Color(0xFFEAB308), '19 900 DZD'),
                const Divider(height: 20),
                _buildTierRow('Résident Élite (47 Modules)', m.residentElite, const Color(0xFF9333EA), '12 900 DZD'),
                const Divider(height: 20),
                _buildTierRow('Clinical Pro (Pratique)', m.clinicalPro, const Color(0xFF0284C7), '6 900 DZD'),
                const Divider(height: 20),
                _buildTierRow('Essai Gratuit (14 jours)', m.freeTrials, Colors.grey, 'Gratuit'),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // System Health & Security Status
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: const Row(
            children: [
              Icon(Icons.verified_user_rounded, color: Color(0xFF16A34A), size: 24),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Serveur de Base de Données Sécurisé & RLS Actif',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF166534)),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Toutes les procédures administratives et les activations de licences sont exécutées avec chiffrement.',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF15803D)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade500),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: color),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildTierRow(String title, int count, Color color, String price) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
        Text(
          price,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
        const SizedBox(width: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count actifs',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
          ),
        ),
      ],
    );
  }

  // --- TAB 2 : USERS & SUBSCRIPTIONS ---
  Widget _buildUsersTab(BuildContext context, AdminState state, bool isDark) {
    final users = state.filteredUsers;

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Rechercher un médecin par nom, email, rôle ou faculté...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _searchController.clear();
                        context.read<AdminBloc>().add(const SearchUsersEvent(''));
                      },
                    )
                  : null,
            ),
            onChanged: (val) => context.read<AdminBloc>().add(SearchUsersEvent(val)),
          ),
        ),

        // Count header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              Text(
                '${users.length} médecin(s) trouvé(s)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),

        // List
        Expanded(
          child: users.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_off_rounded, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text('Aucun médecin ne correspond à la recherche.'),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: users.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final u = users[i];
                    return _buildUserTile(context, u, isDark);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildUserTile(BuildContext context, AdminUserItem u, bool isDark) {
    Color tierColor;
    String tierLabel;

    switch (u.tier.toLowerCase()) {
      case 'all_access':
        tierColor = const Color(0xFFEAB308);
        tierLabel = 'All-Access VIP';
        break;
      case 'resident_elite':
        tierColor = const Color(0xFF9333EA);
        tierLabel = 'Résident Élite';
        break;
      case 'clinical_pro':
        tierColor = const Color(0xFF0284C7);
        tierLabel = 'Clinical Pro';
        break;
      default:
        tierColor = Colors.grey;
        tierLabel = 'Essai Gratuit';
    }

    return Card(
      elevation: isDark ? 0 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppTheme.primaryTeal,
                  child: Text(
                    u.fullName.isNotEmpty ? u.fullName[0].toUpperCase() : 'M',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              u.fullName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (u.isAdmin) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDC2626).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'ADMIN',
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        u.email,
                        style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: tierColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: tierColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    tierLabel,
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: tierColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.school_outlined, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${u.medicalRole} • ${u.faculty}',
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.grey.shade700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  u.expiresAt != null
                      ? 'Expire le : ${u.expiresAt!.day}/${u.expiresAt!.month}/${u.expiresAt!.year}'
                      : 'Durée illimitée',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppTheme.primaryTeal,
                  ),
                  icon: const Icon(Icons.edit_note_rounded, size: 16),
                  label: const Text('Gérer Abonnement', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () => _showUpgradeUserModal(context, u),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showUpgradeUserModal(BuildContext context, AdminUserItem user) {
    String selectedTier = 'all_access';
    int durationDays = 365;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.manage_accounts_rounded, color: AppTheme.primaryTeal),
              const SizedBox(width: 10),
              Flexible(child: Text('Abonnement de ${user.fullName}')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Email: ${user.email}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 16),
              const Text('Formule Cible :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: selectedTier,
                decoration: const InputDecoration(isDense: true),
                items: const [
                  DropdownMenuItem(value: 'all_access', child: Text('All-Access VIP (Complet)')),
                  DropdownMenuItem(value: 'resident_elite', child: Text('Résident Élite (47 Modules)')),
                  DropdownMenuItem(value: 'clinical_pro', child: Text('Clinical Pro (Pratique)')),
                  DropdownMenuItem(value: 'free', child: Text('Essai Gratuit')),
                ],
                onChanged: (val) => setDialogState(() => selectedTier = val ?? selectedTier),
              ),
              const SizedBox(height: 14),
              const Text('Durée de validité :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              DropdownButtonFormField<int>(
                initialValue: durationDays,
                decoration: const InputDecoration(isDense: true),
                items: const [
                  DropdownMenuItem(value: 30, child: Text('30 jours (1 mois)')),
                  DropdownMenuItem(value: 90, child: Text('90 jours (3 mois)')),
                  DropdownMenuItem(value: 365, child: Text('365 jours (Concours 2027)')),
                  DropdownMenuItem(value: 730, child: Text('730 jours (2 ans)')),
                ],
                onChanged: (val) => setDialogState(() => durationDays = val ?? durationDays),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.read<AdminBloc>().add(
                      UpgradeUserSubscriptionEvent(
                        userId: user.id,
                        tier: selectedTier,
                        durationDays: durationDays,
                      ),
                    );
              },
              child: const Text('Appliquer'),
            ),
          ],
        ),
      ),
    );
  }

  // --- TAB 3 : LICENSES & GENERATOR ---
  Widget _buildLicensesTab(BuildContext context, AdminState state, bool isDark) {
    final licenses = state.licenses;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryTeal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Générer une Clé', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _showGenerateKeyModal(context),
      ),
      body: licenses.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.vpn_key_off_rounded, size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text('Aucune clé de licence générée pour l\'instant.'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _showGenerateKeyModal(context),
                    child: const Text('Créer une première clé'),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: licenses.length,
              separatorBuilder: (_, index) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
                final lic = licenses[i];
                return _buildLicenseCard(context, lic, isDark);
              },
            ),
    );
  }

  Widget _buildLicenseCard(BuildContext context, AdminLicenseItem lic, bool isDark) {
    final isAvailable = !lic.isRedeemed;

    return Card(
      elevation: isDark ? 0 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isAvailable ? const Color(0xFF16A34A).withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isAvailable ? Icons.vpn_key_rounded : Icons.check_circle_rounded,
                color: isAvailable ? const Color(0xFF16A34A) : Colors.grey,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SelectableText(
                        lic.keyCode,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isAvailable ? const Color(0xFF16A34A).withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isAvailable ? 'DISPONIBLE' : 'UTILISÉE',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: isAvailable ? const Color(0xFF16A34A) : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Formule : ${lic.tier.toUpperCase()} • Validité : ${lic.durationDays} jours',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 18),
              tooltip: 'Copier la clé',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: lic.keyCode));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF16A34A),
                    content: Text('Clé ${lic.keyCode} copiée dans le presse-papier !'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showGenerateKeyModal(BuildContext context) {
    final keyCtrl = TextEditingController(
      text: 'MEDSINA-2027-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
    );
    String targetTier = 'all_access';
    int duration = 365;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.add_circle_outline_rounded, color: AppTheme.primaryTeal),
              SizedBox(width: 10),
              Text('Générer une Clé de Licence'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Code de la Clé :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: keyCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(isDense: true),
              ),
              const SizedBox(height: 14),
              const Text('Formule Débloquée :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: targetTier,
                decoration: const InputDecoration(isDense: true),
                items: const [
                  DropdownMenuItem(value: 'all_access', child: Text('All-Access VIP')),
                  DropdownMenuItem(value: 'resident_elite', child: Text('Résident Élite')),
                  DropdownMenuItem(value: 'clinical_pro', child: Text('Clinical Pro')),
                ],
                onChanged: (val) => setDialogState(() => targetTier = val ?? targetTier),
              ),
              const SizedBox(height: 14),
              const Text('Durée de Validité :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              DropdownButtonFormField<int>(
                initialValue: duration,
                decoration: const InputDecoration(isDense: true),
                items: const [
                  DropdownMenuItem(value: 30, child: Text('30 jours')),
                  DropdownMenuItem(value: 90, child: Text('90 jours')),
                  DropdownMenuItem(value: 365, child: Text('365 jours (Concours 2027)')),
                  DropdownMenuItem(value: 500, child: Text('500 jours (VIP)')),
                ],
                onChanged: (val) => setDialogState(() => duration = val ?? duration),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () {
                final code = keyCtrl.text.trim();
                if (code.isNotEmpty) {
                  Navigator.pop(ctx);
                  context.read<AdminBloc>().add(
                        GenerateLicenseKeyEvent(
                          keyCode: code,
                          tier: targetTier,
                          durationDays: duration,
                        ),
                      );
                }
              },
              child: const Text('Créer la Clé'),
            ),
          ],
        ),
      ),
    );
  }

  // --- TAB 4 : CONTENT & HEALTH ---
  Widget _buildContentTab(BuildContext context, bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          elevation: isDark ? 0 : 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.inventory_2_outlined, color: AppTheme.primaryTeal),
                    SizedBox(width: 8),
                    Text(
                      'Catalogue Médical Indexé',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildContentRow('Modules Officiels Résidanat Blida 2027', '47 Modules', Icons.school_rounded),
                const Divider(height: 20),
                _buildContentRow('Questions QCM & Cas Cliniques Détaillés', '2 500+ Questions', Icons.quiz_rounded),
                const Divider(height: 20),
                _buildContentRow('Protocoles Conduite à Tenir (CAT) Urgence', '12 Protocoles Essentiels', Icons.emergency_rounded),
                const Divider(height: 20),
                _buildContentRow('Calculateurs Cliniques Validés (Wells, Glasgow...)', '4 Calculateurs', Icons.calculate_rounded),
                const Divider(height: 20),
                _buildContentRow('Tuteur Médical IA (Consensus Algériens)', 'Google Gemini 3.5 Flash', Icons.auto_awesome_rounded),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurfaceElevated : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Informations Système Medsina',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Text(
                'Version App : v${AppConstants.appVersion}\nArchitecture : Flutter Multiplateforme (Windows Desktop, Android APK, Web)\nSécurité : Chiffrement des clés de licence et contrôle d\'accès basé sur les rôles (RBAC).',
                style: TextStyle(fontSize: 12, height: 1.5, color: isDark ? Colors.white70 : Colors.grey.shade700),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContentRow(String title, String count, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryTeal),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
        Text(
          count,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primaryTeal),
        ),
      ],
    );
  }
}
