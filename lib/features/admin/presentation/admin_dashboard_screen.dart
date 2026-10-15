import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/license_key_formatter.dart';
import '../bloc/admin_bloc.dart';
import '../bloc/admin_event.dart';
import '../bloc/admin_state.dart';
import '../models/admin_models.dart';
import '../../subscription/models/subscription_duration.dart';

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
    _tabController = TabController(length: 6, vsync: this);
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
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Console d\'Administration Medsina',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Supervision SaaS • Utilisateurs & Tarifs',
                        style: TextStyle(fontSize: 10.5, color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
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
              tabAlignment: TabAlignment.start,
              labelColor: AppTheme.primaryTeal,
              unselectedLabelColor: isDark ? Colors.white60 : Colors.grey.shade600,
              indicatorColor: AppTheme.primaryTeal,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              tabs: const [
                Tab(icon: Icon(Icons.analytics_outlined), text: 'Métriques & KPIs'),
                Tab(icon: Icon(Icons.people_outline_rounded), text: 'Médecins & Comptes'),
                Tab(icon: Icon(Icons.payments_outlined), text: 'Paiements & Facturation 💳'),
                Tab(icon: Icon(Icons.sell_outlined), text: 'Tarifs & Formules 🏷️'),
                Tab(icon: Icon(Icons.vpn_key_outlined), text: 'Clés de Licence VIP'),
                Tab(icon: Icon(Icons.campaign_outlined), text: 'Annonces & Système 📢'),
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
                    _buildPaymentsTab(context, state, isDark),
                    _buildPricingPlansTab(context, state, isDark),
                    _buildLicensesTab(context, state, isDark),
                    _buildSystemAndAnnouncementsTab(context, state, isDark),
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
        // Financial Revenue Banner
        Card(
          elevation: isDark ? 0 : 2,
          color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.3) : const Color(0xFFF0FDF4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: const Color(0xFF16A34A).withValues(alpha: 0.4)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF16A34A), size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Chiffre d\'Affaires Encaissé',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                      ),
                      Text(
                        '${(state.financialMetrics?.totalRevenue ?? 0).toStringAsFixed(0)} DZD',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF16A34A)),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('En attente', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    Text(
                      '${(state.financialMetrics?.pendingRevenue ?? 0).toStringAsFixed(0)} DZD',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

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
                    Expanded(
                      child: Text(
                        'Répartition par Formule d\'Abonnement',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildTierRow('All-Access VIP (Complet)', m.allAccess, const Color(0xFFEAB308), '6 500 DZD / an'),
                const Divider(height: 20),
                _buildTierRow('Résident Élite (47 Modules)', m.residentElite, const Color(0xFF9333EA), '5 600 DZD / an'),
                const Divider(height: 20),
                _buildTierRow('Clinical Pro (Pratique)', m.clinicalPro, const Color(0xFF0284C7), '5 000 DZD / an'),
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
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
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
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: color),
            ),
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
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
                isExpanded: true,
                decoration: const InputDecoration(isDense: true),
                items: const [
                  DropdownMenuItem(value: 'all_access', child: Text('All-Access VIP (Complet)', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'resident_elite', child: Text('Résident Élite (47 Modules)', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'clinical_pro', child: Text('Clinical Pro (Pratique)', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'free', child: Text('Essai Gratuit', overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (val) => setDialogState(() => selectedTier = val ?? selectedTier),
              ),
              const SizedBox(height: 14),
              const Text('Durée de validité :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              DropdownButtonFormField<int>(
                initialValue: durationDays,
                isExpanded: true,
                decoration: const InputDecoration(isDense: true),
                items: const [
                  DropdownMenuItem(value: 30, child: Text('30 jours (1 mois)', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 90, child: Text('90 jours (3 mois)', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 180, child: Text('180 jours (6 mois)', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 365, child: Text('365 jours (1 an / Concours 2027)', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 730, child: Text('730 jours (2 ans - Réduction -20%)', overflow: TextOverflow.ellipsis)),
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
        heroTag: 'fab_admin_generate_key',
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
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SelectableText(
                        lic.keyCode,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, letterSpacing: 0.5),
                      ),
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
      text: LicenseKeyFormatter.generateKey(),
    );
    String targetTier = 'all_access';
    int duration = 365;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.vpn_key_rounded, color: AppTheme.primaryTeal),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Générer Clé VIP Sécurisée',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Format Pro (Windows Style) :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: keyCtrl,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [LicenseKeyInputFormatter()],
                      style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1, fontSize: 13.5),
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: 'MSN27-XXXXX-XXXXX-XXXXX-XXXXX',
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryTeal),
                    tooltip: 'Régénérer une clé',
                    onPressed: () {
                      setDialogState(() {
                        keyCtrl.text = LicenseKeyFormatter.generateKey();
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text('Formule Débloquée :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: targetTier,
                isExpanded: true,
                decoration: const InputDecoration(isDense: true),
                items: const [
                  DropdownMenuItem(value: 'all_access', child: Text('All-Access VIP', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'resident_elite', child: Text('Résident Élite', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'clinical_pro', child: Text('Clinical Pro', overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (val) => setDialogState(() => targetTier = val ?? targetTier),
              ),
              const SizedBox(height: 14),
              const Text('Durée de Validité :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              DropdownButtonFormField<int>(
                initialValue: duration,
                isExpanded: true,
                decoration: const InputDecoration(isDense: true),
                items: const [
                  DropdownMenuItem(value: 30, child: Text('30 jours', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 90, child: Text('90 jours', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 365, child: Text('365 jours (Concours 2027)', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 500, child: Text('500 jours (VIP)', overflow: TextOverflow.ellipsis)),
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

  // --- TAB 3 : PAYMENTS & TRANSACTIONS ---
  Widget _buildPaymentsTab(BuildContext context, AdminState state, bool isDark) {
    final fm = state.financialMetrics ??
        const FinancialMetrics(
          totalRevenue: 0,
          pendingRevenue: 0,
          totalTransactions: 0,
          approvedCount: 0,
          pendingCount: 0,
          rejectedCount: 0,
        );

    final payments = state.filteredPayments;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 650;

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Financial Metrics Header
            if (isNarrow)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    SizedBox(
                      width: 180,
                      child: _buildMetricCard(
                        'Revenu Total Encaissé',
                        '${fm.totalRevenue.toStringAsFixed(0)} DZD',
                        Icons.check_circle_rounded,
                        const Color(0xFF16A34A),
                        isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 180,
                      child: _buildMetricCard(
                        'En Attente de Validation',
                        '${fm.pendingRevenue.toStringAsFixed(0)} DZD',
                        Icons.pending_actions_rounded,
                        const Color(0xFFD97706),
                        isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 150,
                      child: _buildMetricCard(
                        'Transactions',
                        '${fm.totalTransactions}',
                        Icons.receipt_long_rounded,
                        const Color(0xFF2563EB),
                        isDark,
                      ),
                    ),
                  ],
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      'Revenu Total Encaissé',
                      '${fm.totalRevenue.toStringAsFixed(0)} DZD',
                      Icons.check_circle_rounded,
                      const Color(0xFF16A34A),
                      isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      'En Attente de Validation',
                      '${fm.pendingRevenue.toStringAsFixed(0)} DZD',
                      Icons.pending_actions_rounded,
                      const Color(0xFFD97706),
                      isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      'Transactions',
                      '${fm.totalTransactions}',
                      Icons.receipt_long_rounded,
                      const Color(0xFF2563EB),
                      isDark,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 18),

            // Action & Filter Bar
            if (isNarrow) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryTeal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Enregistrer Paiement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  onPressed: () => _showManualPaymentDialog(context),
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip(context, 'Tous (${state.payments.length})', 'all', state.paymentStatusFilter),
                    const SizedBox(width: 8),
                    _buildFilterChip(context, 'En attente (${fm.pendingCount})', 'pending', state.paymentStatusFilter),
                    const SizedBox(width: 8),
                    _buildFilterChip(context, 'Validés (${fm.approvedCount})', 'approved', state.paymentStatusFilter),
                    const SizedBox(width: 8),
                    _buildFilterChip(context, 'Rejetés (${fm.rejectedCount})', 'rejected', state.paymentStatusFilter),
                  ],
                ),
              ),
            ] else
              Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip(context, 'Tous (${state.payments.length})', 'all', state.paymentStatusFilter),
                          const SizedBox(width: 8),
                          _buildFilterChip(context, 'En attente (${fm.pendingCount})', 'pending', state.paymentStatusFilter),
                          const SizedBox(width: 8),
                          _buildFilterChip(context, 'Validés (${fm.approvedCount})', 'approved', state.paymentStatusFilter),
                          const SizedBox(width: 8),
                          _buildFilterChip(context, 'Rejetés (${fm.rejectedCount})', 'rejected', state.paymentStatusFilter),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryTeal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Enregistrer Paiement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                    onPressed: () => _showManualPaymentDialog(context),
                  ),
                ],
              ),
            const SizedBox(height: 16),

        if (payments.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            alignment: Alignment.center,
            child: Column(
              children: [
                Icon(Icons.payment_outlined, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text(
                  state.payments.isEmpty
                      ? 'Aucun paiement enregistré pour l\'instant.'
                      : 'Aucun paiement dans cette catégorie.',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ],
            ),
          )
        else
          ...payments.map((p) => _buildPaymentCard(context, p, isDark)),
      ],
    );
  },
);
  }

  Widget _buildFilterChip(BuildContext context, String label, String statusKey, String currentFilter) {
    final isSelected = currentFilter == statusKey;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500)),
      selected: isSelected,
      selectedColor: AppTheme.primaryTeal.withValues(alpha: 0.2),
      onSelected: (_) => context.read<AdminBloc>().add(FilterPaymentsEvent(statusKey)),
    );
  }

  Widget _buildPaymentCard(BuildContext context, PaymentItem payment, bool isDark) {
    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    switch (payment.status) {
      case 'approved':
        statusColor = const Color(0xFF16A34A);
        statusLabel = 'Validé & Actif';
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'rejected':
        statusColor = const Color(0xFFDC2626);
        statusLabel = 'Rejeté';
        statusIcon = Icons.cancel_rounded;
        break;
      default:
        statusColor = const Color(0xFFD97706);
        statusLabel = 'En attente de vérification';
        statusIcon = Icons.hourglass_top_rounded;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: payment.status == 'pending' ? const Color(0xFFD97706).withValues(alpha: 0.5) : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
          width: payment.status == 'pending' ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Method badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance_rounded, size: 14, color: Color(0xFF2563EB)),
                      const SizedBox(width: 4),
                      Text(
                        payment.paymentMethod.toUpperCase(),
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF2563EB)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${payment.amount.toStringAsFixed(0)} ${payment.currency}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(statusIcon, size: 13, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${payment.userName} • ${payment.userEmail}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  'Formule : ${payment.tier.toUpperCase()} (${SubscriptionDuration.formatDays(payment.durationDays)})',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                ),
                if (payment.receiptReference != null && payment.receiptReference!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text('• Réf: ${payment.receiptReference}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Date : ${payment.createdAt.day}/${payment.createdAt.month}/${payment.createdAt.year} à ${payment.createdAt.hour}h${payment.createdAt.minute.toString().padLeft(2, '0')}',
              style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500),
            ),
            if (payment.receiptUrl != null && payment.receiptUrl!.isNotEmpty) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2563EB),
                  side: const BorderSide(color: Color(0xFF2563EB)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: const Size(0, 32),
                ),
                icon: const Icon(Icons.attachment_rounded, size: 16),
                label: Text(
                  payment.receiptFileName != null && payment.receiptFileName!.isNotEmpty
                      ? 'Inspecter le Reçu (${payment.receiptFileName})'
                      : 'Inspecter le Reçu Joint',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
                onPressed: () => _showReceiptViewerModal(context, payment),
              ),
            ],
            if (payment.status == 'pending') ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 10,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFDC2626)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Rejeter', style: TextStyle(fontSize: 12)),
                    onPressed: () => _showRejectPaymentDialog(context, payment),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Valider & Activer l\'Abonnement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    onPressed: () {
                      context.read<AdminBloc>().add(
                            ApprovePaymentEvent(
                              paymentId: payment.id,
                              userId: payment.userId,
                              tier: payment.tier,
                              durationDays: payment.durationDays,
                              adminNotes: 'Validé par Admin via console',
                            ),
                          );
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showReceiptViewerModal(BuildContext context, PaymentItem payment) {
    final url = payment.receiptUrl ?? '';
    final isPdf = (payment.receiptFileName?.toLowerCase().endsWith('.pdf') == true) ||
        url.startsWith('data:application/pdf') ||
        url.toLowerCase().contains('.pdf');
    final isBase64 = url.startsWith('data:');

    Uint8List? base64Bytes;
    if (isBase64) {
      try {
        base64Bytes = base64Decode(url.contains(',') ? url.split(',')[1] : url);
      } catch (e) {
        debugPrint('Error decoding base64 receipt: $e');
      }
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final dialogWidth = (screenWidth * 0.85).clamp(380.0, 780.0);
    final viewerHeight = (screenHeight * 0.70).clamp(380.0, 600.0);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isPdf ? Colors.red.withValues(alpha: 0.12) : AppTheme.primaryTeal.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                color: isPdf ? Colors.red.shade700 : AppTheme.primaryTeal,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    payment.receiptFileName ?? 'Reçu de paiement',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Candidat : ${payment.userName} (${payment.userEmail})\nMontant : ${payment.amount.toStringAsFixed(0)} ${payment.currency} • Formule : ${payment.tier.toUpperCase()}',
                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600, height: 1.3),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: dialogWidth,
          height: viewerHeight,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(10),
              color: Colors.grey.shade50,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: _buildReceiptContent(
                url: url,
                isPdf: isPdf,
                isBase64: isBase64,
                base64Bytes: base64Bytes,
                fileName: payment.receiptFileName ?? 'recu_paiement.pdf',
              ),
            ),
          ),
        ),
        actions: [
          if (url.isNotEmpty)
            OutlinedButton.icon(
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: Text(isPdf ? 'Ouvrir dans le lecteur PDF' : 'Ouvrir en externe'),
              onPressed: () => _openReceiptExternally(
                context: ctx,
                url: url,
                fileName: payment.receiptFileName ?? (isPdf ? 'recu.pdf' : 'recu.jpg'),
                bytes: base64Bytes,
              ),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptContent({
    required String url,
    required bool isPdf,
    required bool isBase64,
    required Uint8List? base64Bytes,
    required String fileName,
  }) {
    if (url.isEmpty && base64Bytes == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('Aucune preuve ou URL de reçu disponible.', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (isPdf) {
      if (isBase64 && base64Bytes != null) {
        return SfPdfViewer.memory(
          base64Bytes,
          canShowScrollHead: true,
          canShowScrollStatus: true,
          enableDoubleTapZooming: true,
          onDocumentLoadFailed: (details) {
            debugPrint('SfPdfViewer memory load error: ${details.error}');
          },
        );
      } else if (url.startsWith('http')) {
        return SfPdfViewer.network(
          url,
          canShowScrollHead: true,
          canShowScrollStatus: true,
          enableDoubleTapZooming: true,
          onDocumentLoadFailed: (details) {
            debugPrint('SfPdfViewer network load error: ${details.error}');
          },
        );
      }
    }

    // Image rendering
    if (isBase64 && base64Bytes != null) {
      return InteractiveViewer(
        maxScale: 4.0,
        child: Image.memory(
          base64Bytes,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const Center(
            child: Text('Impossible d\'afficher l\'image du reçu.'),
          ),
        ),
      );
    } else if (url.startsWith('http')) {
      return InteractiveViewer(
        maxScale: 4.0,
        child: Image.network(
          url,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const Center(child: CircularProgressIndicator());
          },
          errorBuilder: (_, _, _) => const Center(
            child: Text('Impossible de charger l\'image du reçu depuis le serveur.'),
          ),
        ),
      );
    }

    return Center(
      child: Text('Format de reçu non pris en charge ($fileName)'),
    );
  }

  Future<void> _openReceiptExternally({
    required BuildContext context,
    required String url,
    required String fileName,
    required Uint8List? bytes,
  }) async {
    try {
      if (url.startsWith('http')) {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
      }

      if (bytes != null && bytes.isNotEmpty) {
        final tempDir = await getTemporaryDirectory();
        final sanitized = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
        final file = File('${tempDir.path}/$sanitized');
        await file.writeAsBytes(bytes);
        final result = await OpenFilex.open(file.path);
        if (result.type != ResultType.done && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ouverture du fichier : ${result.message}')),
          );
        }
        return;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'ouvrir ce fichier en externe.')),
        );
      }
    } catch (e) {
      debugPrint('Error opening receipt externally: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'ouverture : $e')),
        );
      }
    }
  }

  // --- TAB 4 : PRICING PLANS & OFFERS ---
  Widget _buildPricingPlansTab(BuildContext context, AdminState state, bool isDark) {
    final plans = state.plans.isNotEmpty
        ? state.plans
        : [
            const SubscriptionPlanItem(id: 'free', name: 'Pass Découverte', badge: 'GRATUIT', priceYearly: 0, priceMonthly: 0),
            const SubscriptionPlanItem(id: 'clinical_pro', name: 'Pass Clinique Pro', badge: 'INTERNES & PRATICIENS', priceYearly: 5000, priceMonthly: 850, discountPercent: 15),
            const SubscriptionPlanItem(id: 'resident_elite', name: 'Pass Résident Élite', badge: 'SPÉCIAL CONCOURS', priceYearly: 5600, priceMonthly: 750, discountPercent: 20),
            const SubscriptionPlanItem(id: 'all_access', name: 'Medsina All-Access (VIP)', badge: 'RECOMMANDÉ • SUITE COMPLÈTE', priceYearly: 6500, priceMonthly: 1200, discountPercent: 30),
          ];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          elevation: isDark ? 0 : 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryTeal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.price_change_rounded, color: AppTheme.primaryTeal, size: 28),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gestionnaire Dynamique des Tarifs & Offres',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Modifiez les prix annuels/mensuels, remises et badges en temps réel sans mise à jour de l\'application.',
                        style: TextStyle(fontSize: 11.5, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),

        ...plans.map((plan) => _buildPlanEditorCard(context, plan, isDark)),
      ],
    );
  }

  Widget _buildPlanEditorCard(BuildContext context, SubscriptionPlanItem plan, bool isDark) {
    Color planColor;
    switch (plan.id) {
      case 'all_access':
        planColor = const Color(0xFF8B5CF6);
        break;
      case 'resident_elite':
        planColor = AppTheme.primaryTeal;
        break;
      case 'clinical_pro':
        planColor = AppTheme.accentCyan;
        break;
      default:
        planColor = Colors.grey.shade600;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: planColor.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: planColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(plan.badge, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: planColor)),
                    ),
                    if (plan.discountPercent > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('-${plan.discountPercent}%', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                      ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: plan.isActive ? Colors.green.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    plan.isActive ? 'Actif' : 'Masqué',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: plan.isActive ? Colors.green : Colors.grey),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(plan.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 24,
              runSpacing: 8,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tarif Annuel', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    Text(
                      '${plan.priceYearly.toStringAsFixed(0)} ${plan.currency} / an',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: planColor),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tarif Mensuel', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    Text(
                      '${plan.priceMonthly.toStringAsFixed(0)} ${plan.currency} / mois',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: planColor),
                  foregroundColor: planColor,
                ),
                icon: const Icon(Icons.edit_note_rounded, size: 18),
                label: const Text('Modifier les tarifs de cette formule'),
                onPressed: () => _showEditPlanDialog(context, plan),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- TAB 6 : ANNOUNCEMENTS & SYSTEM ---
  Widget _buildSystemAndAnnouncementsTab(BuildContext context, AdminState state, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 500;

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Announcements Section
            Card(
              elevation: isDark ? 0 : 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isNarrow) ...[
                      const Row(
                        children: [
                          Icon(Icons.campaign_rounded, color: AppTheme.primaryTeal),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Diffusion d\'Annonces & Messages',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryTeal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Publier une Annonce', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                          onPressed: () => _showCreateAnnouncementDialog(context),
                        ),
                      ),
                    ] else
                      Row(
                        children: [
                          const Icon(Icons.campaign_rounded, color: AppTheme.primaryTeal),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Diffusion d\'Annonces & Messages Généraux',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                            ),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryTeal, foregroundColor: Colors.white),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Publier', style: TextStyle(fontSize: 12)),
                            onPressed: () => _showCreateAnnouncementDialog(context),
                          ),
                        ],
                      ),
                    const SizedBox(height: 14),
                    if (state.announcements.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text('Aucune annonce active diffusée pour l\'instant.', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                      )
                    else
                      ...state.announcements.map((a) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(a.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                            subtitle: Text(a.message, style: const TextStyle(fontSize: 12)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Switch(
                                  value: a.isActive,
                                  activeThumbColor: AppTheme.primaryTeal,
                                  onChanged: (val) => context.read<AdminBloc>().add(ToggleAnnouncementEvent(id: a.id, isActive: val)),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 18),
                                  onPressed: () => context.read<AdminBloc>().add(DeleteAnnouncementEvent(a.id)),
                                ),
                              ],
                            ),
                          )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // OTA Releases Management Card
            Card(
              elevation: isDark ? 0 : 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isNarrow) ...[
                      const Row(
                        children: [
                          Icon(Icons.system_update_rounded, color: AppTheme.primaryTeal),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Mises à Jour OTA & Versions en Ligne',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryTeal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                          icon: const Icon(Icons.publish_rounded, size: 16),
                          label: const Text('Publier une Version', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                          onPressed: () => _showPublishReleaseDialog(context),
                        ),
                      ),
                    ] else
                      Row(
                        children: [
                          const Icon(Icons.system_update_rounded, color: AppTheme.primaryTeal),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Mises à Jour OTA & Versions en Ligne',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                            ),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryTeal, foregroundColor: Colors.white),
                            icon: const Icon(Icons.publish_rounded, size: 16),
                            label: const Text('Publier une Version', style: TextStyle(fontSize: 12)),
                            onPressed: () => _showPublishReleaseDialog(context),
                          ),
                        ],
                      ),
                const SizedBox(height: 12),
                Text(
                  'Déployez instantanément une nouvelle version sans passer par les stores. L\'application vérifie chaque version au lancement et invite les résidents à installer l\'APK ou télécharger le binaire.',
                  style: TextStyle(fontSize: 12, height: 1.45, color: isDark ? Colors.white70 : Colors.grey.shade700),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 20, color: Colors.blue),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Version actuelle en production : v${AppConstants.appVersion} (Build 1) • Android APK + Windows x64 + Web',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Medical Content Index Card
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
                _buildContentRow('MedsinaPilot (Copilote Médical IA)', 'Google Gemini 3.5 Flash', Icons.auto_awesome_rounded),
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
  },
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

  // --- DIALOGS FOR EDITING PLANS, PAYMENTS & ANNOUNCEMENTS ---

  void _showEditPlanDialog(BuildContext context, SubscriptionPlanItem plan) {
    final yearlyCtrl = TextEditingController(text: plan.priceYearly.toStringAsFixed(0));
    final monthlyCtrl = TextEditingController(text: plan.priceMonthly.toStringAsFixed(0));
    final badgeCtrl = TextEditingController(text: plan.badge);
    final discountCtrl = TextEditingController(text: plan.discountPercent.toString());
    bool isActive = plan.isActive;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text('Modifier les Tarifs • ${plan.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: yearlyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Prix Annuel (DZD)', suffixText: 'DZD'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: monthlyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Prix Mensuel (DZD)', suffixText: 'DZD'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: discountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Remise Promotionnelle (%)', suffixText: '%'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: badgeCtrl,
                  decoration: const InputDecoration(labelText: 'Badge Marketing', hintText: 'Ex: PROMO 2027'),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Formule visible & active', style: TextStyle(fontSize: 13)),
                  value: isActive,
                  onChanged: (val) => setDlgState(() => isActive = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () {
                final yearly = double.tryParse(yearlyCtrl.text.trim()) ?? plan.priceYearly;
                final monthly = double.tryParse(monthlyCtrl.text.trim()) ?? plan.priceMonthly;
                final discount = int.tryParse(discountCtrl.text.trim()) ?? plan.discountPercent;
                final badge = badgeCtrl.text.trim();

                Navigator.pop(ctx);
                context.read<AdminBloc>().add(
                      UpdatePlanPriceEvent(
                        planId: plan.id,
                        priceYearly: yearly,
                        priceMonthly: monthly,
                        discountPercent: discount,
                        badge: badge.isNotEmpty ? badge : plan.badge,
                        isActive: isActive,
                      ),
                    );
              },
              child: const Text('Enregistrer les Nouveaux Tarifs'),
            ),
          ],
        ),
      ),
    );
  }

  void _showManualPaymentDialog(BuildContext context) {
    final state = context.read<AdminBloc>().state;
    final plans = state.plans.isNotEmpty
        ? state.plans
        : SupabaseService.defaultPlans.map((m) => SubscriptionPlanItem.fromJson(m)).toList();
    final defaultPlan = plans.firstWhere((p) => p.id == 'all_access', orElse: () => plans.first);

    final emailCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    SubscriptionDuration selectedDuration = SubscriptionDuration.oneYear;
    String tier = 'all_access';
    final amountCtrl = TextEditingController(
      text: selectedDuration.calculatePrice(defaultPlan).toStringAsFixed(0),
    );
    final refCtrl = TextEditingController();
    String method = 'baridimob';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Enregistrer un Paiement Manuel'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email du Médecin', hintText: 'docteur@exemple.com'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nom Complet', hintText: 'Dr. Karim Benali'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: tier,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Formule Choisie'),
                  items: plans.where((p) => p.id != 'free').map((p) => DropdownMenuItem(
                    value: p.id,
                    child: Text('${p.name} (${selectedDuration.calculatePrice(p).toStringAsFixed(0)} DZD)', overflow: TextOverflow.ellipsis),
                  )).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDlgState(() {
                        tier = val;
                        final p = plans.firstWhere((item) => item.id == val, orElse: () => defaultPlan);
                        amountCtrl.text = selectedDuration.calculatePrice(p).toStringAsFixed(0);
                      });
                    }
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<SubscriptionDuration>(
                  initialValue: selectedDuration,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Durée de l\'Abonnement'),
                  items: SubscriptionDuration.values.map((d) => DropdownMenuItem(
                    value: d,
                    child: Text('${d.label} (${d.days} jours)${d.badge != null ? ' - ${d.badge}' : ''}'),
                  )).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDlgState(() {
                        selectedDuration = val;
                        final p = plans.firstWhere((item) => item.id == tier, orElse: () => defaultPlan);
                        amountCtrl.text = selectedDuration.calculatePrice(p).toStringAsFixed(0);
                      });
                    }
                  },
                ),
                if (selectedDuration == SubscriptionDuration.twoYears) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Remise de -20% appliquée sur l\'abonnement 2 ans',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: method,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Mode de Paiement'),
                  items: const [
                    DropdownMenuItem(value: 'baridimob', child: Text('BaridiMob (RIP / Virement)', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'ccp', child: Text('Versement CCP (Bordereau)', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'cash', child: Text('Espèces / En main propre', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'virement', child: Text('Virement Bancaire', overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (val) => setDlgState(() => method = val ?? method),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Montant (DZD)', suffixText: 'DZD'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: refCtrl,
                  decoration: const InputDecoration(labelText: 'N° Reçu / Réf. Transaction', hintText: 'Ex: TRX-98421'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () {
                final email = emailCtrl.text.trim();
                final name = nameCtrl.text.trim();
                final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
                final ref = refCtrl.text.trim();

                if (email.isNotEmpty && amount > 0) {
                  Navigator.pop(ctx);
                  context.read<AdminBloc>().add(
                        RecordManualPaymentEvent(
                          userEmail: email,
                          userName: name.isNotEmpty ? name : email.split('@').first,
                          tier: tier,
                          durationDays: selectedDuration.days,
                          amount: amount,
                          paymentMethod: method,
                          receiptReference: ref.isNotEmpty ? ref : 'MANUAL-${DateTime.now().millisecondsSinceEpoch}',
                        ),
                      );
                }
              },
              child: const Text('Valider & Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRejectPaymentDialog(BuildContext context, PaymentItem payment) {
    final noteCtrl = TextEditingController(text: 'Reçu non conforme ou illisible');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rejeter la Preuve de Paiement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Médecin : ${payment.userName} (${payment.userEmail})'),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(labelText: 'Motif du rejet (visible par l\'admin)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AdminBloc>().add(
                    RejectPaymentEvent(
                      paymentId: payment.id,
                      adminNotes: noteCtrl.text.trim(),
                    ),
                  );
            },
            child: const Text('Confirmer le Rejet'),
          ),
        ],
      ),
    );
  }

  void _showCreateAnnouncementDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final messageCtrl = TextEditingController();
    String type = 'info';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Diffuser une Annonce Médicale'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Titre de l\'annonce', hintText: 'Ex: Concours Blanc Medsina'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: messageCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Message complet', hintText: 'Détails de l\'annonce...'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: type,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Niveau d\'importance'),
                items: const [
                  DropdownMenuItem(value: 'info', child: Text('Information standard', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'success', child: Text('Bonne nouvelle / Succès', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'warning', child: Text('Avertissement / Rappel', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'urgent', child: Text('Urgent / Critique', overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (val) => setDlgState(() => type = val ?? type),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () {
                final title = titleCtrl.text.trim();
                final msg = messageCtrl.text.trim();
                if (title.isNotEmpty && msg.isNotEmpty) {
                  Navigator.pop(ctx);
                  context.read<AdminBloc>().add(
                        CreateAnnouncementEvent(
                          title: title,
                          message: msg,
                          type: type,
                        ),
                      );
                }
              },
              child: const Text('Publier l\'Annonce'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPublishReleaseDialog(BuildContext context) {
    final versionCtrl = TextEditingController(text: '1.0.1');
    final buildCtrl = TextEditingController(text: '2');
    final notesCtrl = TextEditingController(
      text: '### Nouveautés de Medsina ✨\n- Améliorations de performance et fiches de cours enrichies.\n- Nouveaux mementos de garde et protocoles cliniques.',
    );
    final urlCtrl = TextEditingController(
      text: 'https://qzfssrhhuorljftpdvjm.supabase.co/storage/v1/object/public/releases/Medsina_v1.0.1_Android_Release.apk',
    );
    String platform = 'android';
    bool isMandatory = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.system_update_rounded, color: AppTheme.primaryTeal),
              SizedBox(width: 8),
              Text('Diffuser une Version OTA'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: platform,
                  decoration: const InputDecoration(labelText: 'Plateforme Cible'),
                  items: const [
                    DropdownMenuItem(value: 'android', child: Text('Android (APK Direct)')),
                    DropdownMenuItem(value: 'windows', child: Text('Windows (Desktop x64)')),
                    DropdownMenuItem(value: 'web', child: Text('Web Production')),
                    DropdownMenuItem(value: 'all', child: Text('Toutes les plateformes')),
                  ],
                  onChanged: (val) => setDlgState(() => platform = val ?? platform),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: versionCtrl,
                        decoration: const InputDecoration(labelText: 'Version (ex: 1.0.1)'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: buildCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Build Number (ex: 2)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: urlCtrl,
                  decoration: const InputDecoration(labelText: 'URL de Téléchargement Direct (APK / ZIP)'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notesCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Notes de Version (Markdown)'),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Mise à jour obligatoire (Bloquante)'),
                  subtitle: const Text('Empêche l\'accès aux anciennes versions tant que la mise à jour n\'est pas faite.'),
                  value: isMandatory,
                  activeThumbColor: Colors.red,
                  onChanged: (val) => setDlgState(() => isMandatory = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryTeal, foregroundColor: Colors.white),
              onPressed: () async {
                final vName = versionCtrl.text.trim();
                final bNum = int.tryParse(buildCtrl.text.trim()) ?? 2;
                final url = urlCtrl.text.trim();
                final notes = notesCtrl.text.trim();

                if (vName.isNotEmpty && url.isNotEmpty) {
                  Navigator.pop(ctx);
                  try {
                    await SupabaseService.client.from('app_releases').insert({
                      'platform': platform,
                      'version_name': vName,
                      'build_number': bNum,
                      'release_notes': notes,
                      'download_url': url,
                      'is_mandatory': isMandatory,
                      'min_supported_build': isMandatory ? bNum : 1,
                      'is_active': true,
                    });
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Version OTA publiée avec succès sur Supabase Cloud ! 🚀'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Erreur lors de la publication : $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
              child: const Text('Publier la Version'),
            ),
          ],
        ),
      ),
    );
  }
}
