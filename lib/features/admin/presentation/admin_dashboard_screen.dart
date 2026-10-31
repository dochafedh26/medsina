import 'package:file_picker/file_picker.dart';
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
import '../../../core/services/github_actions_service.dart';
import '../../../core/services/medsina_notification_dispatcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/license_key_formatter.dart';
import '../bloc/admin_bloc.dart';
import '../bloc/admin_event.dart';
import '../bloc/admin_state.dart';
import 'admin_national_exams_tab.dart';
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
  final TextEditingController _licenseSearchController = TextEditingController();
  String _licenseFilterStatus = 'all';

  bool _isLoadingRuns = false;
  List<GitHubWorkflowRun> _recentWorkflowRuns = [];
  String? _triggeringAgentId;
  bool _isGitHubConfigured = false;

  bool _isLoadingBlidaQueue = false;
  List<Map<String, dynamic>> _discoveredBlidaResources = [];
  String _blidaQueueFilterStatus = 'pending';
  final Set<String> _selectedBlidaResourceIds = {};
  bool _isProcessingBatchBlida = false;

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return 'Non renseigné';
    final local = dt.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    final y = local.year.toString();
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    final s = local.second.toString().padLeft(2, '0');
    return '$d/$m/$y à $h:$min:$s';
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
    context.read<AdminBloc>().add(LoadAdminDataEvent());
    _checkGitHubConfigAndLoadRuns();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _licenseSearchController.dispose();
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
                Tab(icon: Icon(Icons.emoji_events_outlined), text: 'Concours Blancs & Examens 🏆'),
                Tab(icon: Icon(Icons.smart_toy_rounded), text: 'Agents IA GitHub 🤖'),
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
                    AdminNationalExamsTab(isDark: isDark),
                    _buildGitHubAgentsTab(context, state, isDark),
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
        const SizedBox(height: 18),

        // Recent Subscribers & Member Activity Live Widget
        _buildRecentSubscribersCard(context, state, isDark),
        const SizedBox(height: 18),

        // Compteur de Téléchargements Octenium (Task 01)
        Card(
          elevation: isDark ? 0 : 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: const Color(0xFF0284C7).withValues(alpha: 0.3), width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.cloud_download_rounded, color: Color(0xFF0284C7), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Téléchargements Octenium & Distribution 📥',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                          ),
                          Text(
                            'Serveur MedevSync / Octenium • medsina.medevsync.com',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${m.octeniumTotalDownloads} TOTAL',
                        style: const TextStyle(
                          color: Color(0xFF0284C7),
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildDownloadPlatformMiniCard(
                      icon: Icons.android_rounded,
                      title: 'Android APK',
                      count: m.octeniumApkDownloads,
                      color: const Color(0xFF10B981),
                      subtitle: 'medsina.apk',
                      isDark: isDark,
                    ),
                    const SizedBox(width: 10),
                    _buildDownloadPlatformMiniCard(
                      icon: Icons.window_rounded,
                      title: 'Windows PC',
                      count: m.octeniumWindowsDownloads,
                      color: const Color(0xFF0284C7),
                      subtitle: 'medsina-setup.exe',
                      isDark: isDark,
                    ),
                    const SizedBox(width: 10),
                    _buildDownloadPlatformMiniCard(
                      icon: Icons.language_rounded,
                      title: 'Accès Web',
                      count: m.octeniumWebVisits,
                      color: const Color(0xFF8B5CF6),
                      subtitle: 'Version en ligne',
                      isDark: isDark,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.history_rounded, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Dernier téléchargement : ${_formatDateTime(m.octeniumLastDownloadAt)}',
                          style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : const Color(0xFF475569)),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline_rounded, size: 16, color: AppTheme.primaryTeal),
                        tooltip: 'Simuler un téléchargement APK (+1)',
                        onPressed: () async {
                          await SupabaseService.recordOcteniumDownload(platform: 'android', source: 'admin_test');
                          if (context.mounted) {
                            context.read<AdminBloc>().add(LoadAdminDataEvent());
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                backgroundColor: Color(0xFF10B981),
                                content: Text('Téléchargement APK enregistré avec succès (+1) sur Supabase !'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.grey),
                        tooltip: 'Copier le lien direct APK Octenium',
                        onPressed: () {
                          Clipboard.setData(const ClipboardData(text: 'https://medsina.medevsync.com/download/medsina.apk'));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: AppTheme.primaryTeal,
                              content: Text('Lien APK Octenium copié dans le presse-papier !'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

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
                _buildTierRow('Pass Étudiant (1ère - 6ème)', m.etudiant, const Color(0xFF2563EB), '3 500 DZD / an'),
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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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

  Widget _buildTierPill(Color tierColor, String tierLabel, {bool isNarrow = false}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isNarrow ? 6 : 8, vertical: isNarrow ? 2 : 3),
      decoration: BoxDecoration(
        color: tierColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tierColor.withValues(alpha: 0.4)),
      ),
      child: Text(
        tierLabel,
        style: TextStyle(
          fontSize: isNarrow ? 9.5 : 10.5,
          fontWeight: FontWeight.w800,
          color: tierColor,
        ),
      ),
    );
  }

  Widget _buildPromoHunterBanner(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 620;

        final button = ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0284C7),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 2,
            minimumSize: isNarrow ? const Size(double.infinity, 42) : null,
          ),
          icon: _triggeringAgentId == 'telegram_promo_hunter'
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.radar_rounded, size: 18),
          label: Text(
            _triggeringAgentId == 'telegram_promo_hunter' ? 'Recherche en cours...' : 'Lancer le Chasseur 🎯',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          onPressed: _triggeringAgentId != null ? null : () => _showPromoHunterDialog(),
        );

        final textContent = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Chasseur Promo Telegram & Assistant Réponses Facebook',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            const SizedBox(height: 3),
            Text(
              'Scanne en temps réel les questions d étudiants (résidanat, QCMs, cours) et poste des réponses ciblées avec les liens Medsina (sans MBset).',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          ],
        );

        final iconBox = Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF0284C7),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.forum_rounded, color: Colors.white, size: 22),
        );

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF0284C7).withValues(alpha: 0.3),
              width: 1.2,
            ),
          ),
          child: isNarrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        iconBox,
                        const SizedBox(width: 12),
                        Expanded(child: textContent),
                      ],
                    ),
                    const SizedBox(height: 12),
                    button,
                  ],
                )
              : Row(
                  children: [
                    iconBox,
                    const SizedBox(width: 14),
                    Expanded(child: textContent),
                    const SizedBox(width: 14),
                    button,
                  ],
                ),
        );
      },
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
      case 'etudiant':
        tierColor = const Color(0xFF2563EB);
        tierLabel = 'Pass Étudiant';
        break;
      default:
        tierColor = Colors.grey;
        tierLabel = 'Essai Gratuit';
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 460;

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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: isNarrow ? 16 : 18,
                      backgroundColor: AppTheme.primaryTeal,
                      child: Text(
                        u.fullName.isNotEmpty ? u.fullName[0].toUpperCase() : 'M',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: isNarrow ? 13 : 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  u.fullName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: isNarrow ? 13.5 : 14.5,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isNarrow) ...[
                                const SizedBox(width: 6),
                                _buildTierPill(tierColor, tierLabel, isNarrow: true),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            u.email,
                            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (u.isAdmin || u.isBanned || u.rejectedPaymentsCount > 0) ...[
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (u.isAdmin)
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
                                if (u.isBanned)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDC2626).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: const Color(0xFFDC2626)),
                                    ),
                                    child: const Text(
                                      'SUSPENDU (3 rejets) ⛔',
                                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                                    ),
                                  )
                                else if (u.rejectedPaymentsCount > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${u.rejectedPaymentsCount}/3 Rejets ⚠️',
                                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.orange),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                          if (u.isBanned && u.banReason != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              'Motif : ${u.banReason}',
                              style: const TextStyle(fontSize: 10.5, color: Color(0xFFDC2626), fontStyle: FontStyle.italic),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (!isNarrow) ...[
                      const SizedBox(width: 8),
                      _buildTierPill(tierColor, tierLabel, isNarrow: false),
                    ],
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
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Text(
                      u.expiresAt != null
                          ? 'Expire le : ${u.expiresAt!.day}/${u.expiresAt!.month}/${u.expiresAt!.year}'
                          : 'Durée illimitée',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (u.isBanned)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              backgroundColor: const Color(0xFF16A34A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            ),
                            icon: const Icon(Icons.lock_open_rounded, size: 14),
                            label: const Text('Débannir', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                            onPressed: () => _confirmUnbanUser(context, u),
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
              ],
            ),
          ),
        );
      },
    );
  }

  void _showUpgradeUserModal(BuildContext context, AdminUserItem user) {
    String selectedTier = ['all_access', 'resident_elite', 'clinical_pro', 'etudiant', 'free'].contains(user.tier.toLowerCase())
        ? user.tier.toLowerCase()
        : 'all_access';
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
                  DropdownMenuItem(value: 'etudiant', child: Text('Pass Étudiant (1ère - 6ème Année)', overflow: TextOverflow.ellipsis)),
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

  void _confirmUnbanUser(BuildContext context, AdminUserItem user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock_open_rounded, color: Color(0xFF16A34A)),
            SizedBox(width: 8),
            Text('Débannir le Médecin'),
          ],
        ),
        content: Text('Voulez-vous réactiver le compte de ${user.fullName} (${user.email}) ? Son compteur de rejets sera réinitialisé à zéro et ses accès rétablis.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AdminBloc>().add(UnbanUserEvent(userId: user.id));
            },
            child: const Text('Confirmer le Déblocage'),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadPlatformMiniCard({
    required IconData icon,
    required String title,
    required int count,
    required Color color,
    required String subtitle,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              subtitle,
              style: TextStyle(fontSize: 9.5, color: Colors.grey.shade500),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // --- TAB 3 : LICENSES & GENERATOR (TASK 02: DÉTAILS COMPLETS) ---
  Widget _buildLicensesTab(BuildContext context, AdminState state, bool isDark) {
    final allLicenses = state.licenses;
    final query = _licenseSearchController.text.trim().toLowerCase();

    final filteredLicenses = allLicenses.where((lic) {
      if (query.isNotEmpty) {
        final matchCode = lic.keyCode.toLowerCase().contains(query);
        final matchUser = (lic.redeemedUserName?.toLowerCase() ?? '').contains(query);
        final matchEmail = (lic.redeemedUserEmail?.toLowerCase() ?? '').contains(query);
        final matchTier = lic.tier.toLowerCase().contains(query);
        if (!matchCode && !matchUser && !matchEmail && !matchTier) return false;
      }

      if (_licenseFilterStatus == 'available') {
        return !lic.isRedeemed && !lic.isRevoked;
      } else if (_licenseFilterStatus == 'active') {
        return lic.isRedeemed && !lic.isExpired && !lic.isRevoked;
      } else if (_licenseFilterStatus == 'expired') {
        return lic.isRedeemed && lic.isExpired && !lic.isRevoked;
      } else if (_licenseFilterStatus == 'revoked') {
        return lic.isRevoked;
      }
      return true;
    }).toList();

    final availableCount = allLicenses.where((l) => !l.isRedeemed && !l.isRevoked).length;
    final activeCount = allLicenses.where((l) => l.isRedeemed && !l.isExpired && !l.isRevoked).length;
    final expiredCount = allLicenses.where((l) => l.isRedeemed && l.isExpired && !l.isRevoked).length;
    final revokedCount = allLicenses.where((l) => l.isRevoked).length;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_admin_generate_key',
        backgroundColor: AppTheme.primaryTeal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Générer une Clé VIP', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _showGenerateKeyModal(context),
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            color: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
            child: Column(
              children: [
                TextField(
                  controller: _licenseSearchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Rechercher par code (MSN27-...), nom de médecin ou email...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _licenseSearchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _licenseSearchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildLicenseFilterChip('Toutes (${allLicenses.length})', 'all', isDark),
                      const SizedBox(width: 8),
                      _buildLicenseFilterChip('Disponibles ($availableCount)', 'available', isDark, color: const Color(0xFF16A34A)),
                      const SizedBox(width: 8),
                      _buildLicenseFilterChip('Actives ($activeCount)', 'active', isDark, color: const Color(0xFF0284C7)),
                      const SizedBox(width: 8),
                      _buildLicenseFilterChip('Expirées ($expiredCount)', 'expired', isDark, color: const Color(0xFFDC2626)),
                      const SizedBox(width: 8),
                      _buildLicenseFilterChip('Révoquées ($revokedCount)', 'revoked', isDark, color: const Color(0xFFE11D48)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // License Cards List
          Expanded(
            child: filteredLicenses.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.vpn_key_off_rounded, size: 48, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text(
                          allLicenses.isEmpty
                              ? 'Aucune clé de licence générée pour l\'instant.'
                              : 'Aucune clé ne correspond à vos filtres.',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Créer une première clé'),
                          onPressed: () => _showGenerateKeyModal(context),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredLicenses.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 14),
                    itemBuilder: (ctx, i) {
                      final lic = filteredLicenses[i];
                      return _buildLicenseCard(context, lic, isDark);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLicenseFilterChip(String label, String value, bool isDark, {Color? color}) {
    final isSelected = _licenseFilterStatus == value;
    final activeColor = color ?? AppTheme.primaryTeal;

    return InkWell(
      onTap: () => setState(() => _licenseFilterStatus = value),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : (isDark ? AppTheme.darkSurfaceElevated : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : (isDark ? AppTheme.darkBorder : Colors.grey.shade300),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.grey.shade800),
          ),
        ),
      ),
    );
  }

  Widget _buildLicenseCard(BuildContext context, AdminLicenseItem lic, bool isDark) {
    final isRevoked = lic.isRevoked;
    final isAvailable = !lic.isRedeemed && !isRevoked;
    final isExpired = lic.isExpired && !isRevoked;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (isRevoked) {
      statusColor = const Color(0xFFDC2626);
      statusText = 'RÉVOQUÉE';
      statusIcon = Icons.block_rounded;
    } else if (isAvailable) {
      statusColor = const Color(0xFF16A34A);
      statusText = 'DISPONIBLE';
      statusIcon = Icons.vpn_key_rounded;
    } else if (isExpired) {
      statusColor = const Color(0xFFDC2626);
      statusText = 'UTILISÉE • EXPIRÉE';
      statusIcon = Icons.event_busy_rounded;
    } else {
      statusColor = const Color(0xFF0284C7);
      statusText = 'UTILISÉE • ACTIVE';
      statusIcon = Icons.verified_rounded;
    }

    return Card(
      elevation: isDark ? 0 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: statusColor.withValues(alpha: isDark ? (isRevoked ? 0.6 : 0.4) : (isRevoked ? 0.4 : 0.25)),
          width: isRevoked ? 2.0 : 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Key Code & Status Badges & Action Buttons
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(
                        lic.keyCode,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: 0.8,
                          decoration: isRevoked ? TextDecoration.lineThrough : null,
                          decorationColor: const Color(0xFFDC2626),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryTeal.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              lic.tier.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryTeal,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${lic.durationDays} JOURS',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white70 : Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Action Buttons: Copy & Revoke/Restore
                IconButton.filledTonal(
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  tooltip: 'Copier la clé',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: lic.keyCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppTheme.primaryTeal,
                        content: Text('Clé ${lic.keyCode} copiée dans le presse-papier !'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 4),
                if (isRevoked)
                  IconButton.filledTonal(
                    icon: const Icon(Icons.restore_rounded, size: 18, color: Color(0xFF16A34A)),
                    tooltip: 'Rétablir cette clé',
                    onPressed: () => _confirmUnrevokeKey(context, lic),
                  )
                else
                  IconButton.filledTonal(
                    icon: const Icon(Icons.block_rounded, size: 18, color: Color(0xFFDC2626)),
                    tooltip: 'Révoquer cette clé',
                    onPressed: () => _showRevokeKeyModal(context, lic),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Detailed Audit Grid (Génération, Activation, Utilisateur, Expiration, Révocation)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                children: [
                  // Detail 1: Datetime de Génération
                  _buildLicenseDetailRow(
                    icon: Icons.calendar_today_rounded,
                    color: const Color(0xFF64748B),
                    title: 'Génération :',
                    value: _formatDateTime(lic.createdAt),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 8),

                  // Detail 2: Datetime d'Activation
                  _buildLicenseDetailRow(
                    icon: Icons.bolt_rounded,
                    color: isAvailable ? Colors.grey : const Color(0xFF10B981),
                    title: 'Activation :',
                    value: isAvailable ? 'Non activée (Clé disponible)' : _formatDateTime(lic.redeemedAt),
                    isHighlight: !isAvailable && !isRevoked,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 8),

                  // Detail 3: Quel Utilisateur l'a Activée
                  _buildLicenseDetailRow(
                    icon: Icons.person_rounded,
                    color: isAvailable ? Colors.grey : const Color(0xFF0284C7),
                    title: 'Activée par :',
                    value: isAvailable
                        ? 'En attente d\'attribution'
                        : '${lic.redeemedUserName ?? 'Dr. Utilisateur'}${lic.redeemedUserEmail != null ? ' (${lic.redeemedUserEmail})' : ''}',
                    subtitle: !isAvailable && lic.redeemedBy != null ? 'ID Utilisateur: ${lic.redeemedBy}' : null,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 8),

                  // Detail 4: Délais / Datetime de l'Expiration
                  _buildLicenseDetailRow(
                    icon: Icons.timer_outlined,
                    color: isRevoked
                        ? const Color(0xFFDC2626)
                        : (isAvailable
                            ? const Color(0xFFD97706)
                            : (isExpired ? const Color(0xFFDC2626) : const Color(0xFF16A34A))),
                    title: 'Expiration :',
                    value: isAvailable
                        ? '${lic.durationDays} jours de validité (dès activation)'
                        : _formatDateTime(lic.expiresAt),
                    badge: isRevoked
                        ? 'ANNULÉE'
                        : (!isAvailable
                            ? (isExpired ? 'EXPIRÉE' : '${lic.daysRemaining} jour(s) restants')
                            : null),
                    badgeColor: (isRevoked || isExpired) ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                    isDark: isDark,
                  ),

                  // Detail 5: Revocation audit details (if revoked)
                  if (isRevoked) ...[
                    const SizedBox(height: 8),
                    _buildLicenseDetailRow(
                      icon: Icons.block_rounded,
                      color: const Color(0xFFDC2626),
                      title: 'Révocation :',
                      value: _formatDateTime(lic.revokedAt),
                      subtitle: 'Motif: ${lic.revocationReason ?? "Révoquée par l'administrateur"}',
                      badge: 'RÉVOQUÉE',
                      badgeColor: const Color(0xFFDC2626),
                      isHighlight: true,
                      isDark: isDark,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLicenseDetailRow({
    required IconData icon,
    required Color color,
    required String title,
    required String value,
    String? subtitle,
    String? badge,
    Color? badgeColor,
    bool isHighlight = false,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        SizedBox(
          width: 95,
          child: Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white60 : const Color(0xFF64748B),
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
                        color: isHighlight
                            ? (isDark ? Colors.white : const Color(0xFF0F172A))
                            : (isDark ? Colors.white70 : const Color(0xFF334155)),
                      ),
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (badgeColor ?? color).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: badgeColor ?? color,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 9.5, color: Colors.grey.shade500),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _showRevokeKeyModal(BuildContext context, AdminLicenseItem lic) {
    final reasonCtrl = TextEditingController(text: 'Paiement contesté ou non honoré');
    final reasons = [
      'Paiement contesté ou non honoré',
      'Usage frauduleux / partagé',
      'Erreur d\'attribution de formule',
      'Demande explicite du médecin',
      'Autre motif administratif',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.block_rounded, color: Color(0xFFDC2626)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Révoquer la Clé VIP',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Key badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.vpn_key_rounded, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          lic.keyCode,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Warning if redeemed
                if (lic.isRedeemed)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFDC2626)),
                            SizedBox(width: 6),
                            Text(
                              'ATTENTION : Clé déjà activée !',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Activée par : ${lic.redeemedUserName ?? "Dr. Inconnu"}${lic.redeemedUserEmail != null ? ' (${lic.redeemedUserEmail})' : ''}\n'
                          'La souscription active de cet utilisateur sera IMMÉDIATEMENT ANNULÉE et son accès VIP coupé.',
                          style: const TextStyle(fontSize: 11, height: 1.3),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.3)),
                    ),
                    child: const Text(
                      'Cette clé n\'a pas encore été activée. Sa révocation bloquera toute tentative d\'utilisation future.',
                      style: TextStyle(fontSize: 11, height: 1.3),
                    ),
                  ),
                const SizedBox(height: 14),

                const Text('Motif de la révocation :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),

                // Preset reason chips
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: reasons.map((r) {
                    final isSel = reasonCtrl.text == r;
                    return ChoiceChip(
                      label: Text(r, style: TextStyle(fontSize: 11, color: isSel ? Colors.white : null)),
                      selected: isSel,
                      selectedColor: const Color(0xFFDC2626),
                      onSelected: (val) {
                        if (val) {
                          setDialogState(() {
                            reasonCtrl.text = r;
                          });
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: reasonCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Précision / Commentaire',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.block_rounded, size: 16),
              label: const Text('Confirmer la Révocation', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                final reason = reasonCtrl.text.trim();
                Navigator.pop(ctx);
                context.read<AdminBloc>().add(
                      RevokeLicenseKeyEvent(
                        keyCode: lic.keyCode,
                        reason: reason.isNotEmpty ? reason : null,
                      ),
                    );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmUnrevokeKey(BuildContext context, AdminLicenseItem lic) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.restore_rounded, color: Color(0xFF16A34A)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Rétablir la Clé VIP',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          'Voulez-vous rétablir la validité de la clé ${lic.keyCode} ?\n\n'
          '${lic.isRedeemed ? "L'accès et la souscription du médecin (${lic.redeemedUserEmail ?? ''}) seront réactivés." : "La clé redeviendra utilisable par n'importe quel médecin."}',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
            label: const Text('Rétablir la clé', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AdminBloc>().add(
                    UnrevokeLicenseKeyEvent(keyCode: lic.keyCode),
                  );
            },
          ),
        ],
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
                  DropdownMenuItem(value: 'etudiant', child: Text('Pass Étudiant', overflow: TextOverflow.ellipsis)),
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

    final isQuotaTopup = payment.paymentType == 'quota_topup' || payment.tier.startsWith('pack_') || payment.tier.startsWith('quota_');
    final bonusCount = payment.bonusCredits > 0 ? payment.bonusCredits : 50;

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
                if (isQuotaTopup) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.flash_on_rounded, size: 13, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          '+$bonusCount REQUÊTES IA',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.amber),
                        ),
                      ],
                    ),
                  ),
                ],
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
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  isQuotaTopup
                      ? 'Recharge IA : +$bonusCount requêtes permanentes'
                      : 'Formule : ${payment.tier.toUpperCase()} (${SubscriptionDuration.formatDays(payment.durationDays)})',
                  style: TextStyle(fontSize: 11.5, color: isQuotaTopup ? AppTheme.primaryTeal : Colors.grey.shade600, fontWeight: isQuotaTopup ? FontWeight.bold : FontWeight.normal),
                ),
                if (payment.receiptReference != null && payment.receiptReference!.isNotEmpty)
                  Text('• Réf: ${payment.receiptReference}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Date : ${payment.createdAt.day}/${payment.createdAt.month}/${payment.createdAt.year} à ${payment.createdAt.hour}h${payment.createdAt.minute.toString().padLeft(2, '0')}',
              style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500),
            ),
            if (payment.isArchived) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F9D58).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF0F9D58).withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_done_rounded, size: 15, color: Color(0xFF0F9D58)),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Archivé sur Google Drive ☁️ (${payment.archiveDriveFolder ?? 'Drive'})',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F9D58)),
                      ),
                    ),
                    if (payment.archiveDriveUrl != null && payment.archiveDriveUrl!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () async {
                          final uri = Uri.tryParse(payment.archiveDriveUrl!);
                          if (uri != null) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                        child: const Icon(Icons.open_in_new_rounded, size: 14, color: Color(0xFF0F9D58)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
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
                    label: Text(
                      isQuotaTopup
                          ? 'Valider & Créditer +$bonusCount Requêtes'
                          : 'Valider & Activer l\'Abonnement',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    onPressed: () {
                      context.read<AdminBloc>().add(
                            ApprovePaymentEvent(
                              paymentId: payment.id,
                              userId: payment.userId,
                              tier: payment.tier,
                              durationDays: payment.durationDays,
                              adminNotes: isQuotaTopup
                                  ? 'Recharge validée (+ $bonusCount requêtes IA)'
                                  : 'Validé par Admin via console',
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
            const SubscriptionPlanItem(id: 'etudiant', name: 'Pass Étudiant', badge: 'PROMO CURSUS • ÉTUDIANTS', priceYearly: 2500, priceMonthly: 500, discountPercent: 58),
            const SubscriptionPlanItem(id: 'clinical_pro', name: 'Pass Clinique Pro', badge: 'PROMO CLINIQUE • INTERNAT & UMC', priceYearly: 3000, priceMonthly: 600, discountPercent: 58),
            const SubscriptionPlanItem(id: 'resident_elite', name: 'Pass Résident Élite', badge: 'PROMO CONCOURS • RÉSIDANAT 2027', priceYearly: 3500, priceMonthly: 700, discountPercent: 58),
            const SubscriptionPlanItem(id: 'all_access', name: 'Medsina All-Access (VIP)', badge: 'PROMO ALL-ACCESS • SUITE COMPLÈTE VIP', priceYearly: 4500, priceMonthly: 800, discountPercent: 53),
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
      case 'etudiant':
        planColor = const Color(0xFF2563EB);
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

        // Google Drive Archival & Storage Manager Card
        Card(
          elevation: isDark ? 0 : 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.cloud_sync_rounded, color: Color(0xFF0F9D58)),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Stockage Supabase & Archivage Google Drive ☁️',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0F9D58),
                        side: const BorderSide(color: Color(0xFF0F9D58)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                      icon: const Icon(Icons.settings_ethernet_rounded, size: 16),
                      label: const Text('Webhook Drive & Email', style: TextStyle(fontSize: 11.5)),
                      onPressed: () => _showConfigureWebhookDialog(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Politique de rétention zéro-coût : les reçus approuvés sont conservés 30 jours dans Supabase Storage pour consultation rapide, puis archivés sur Google Drive ("Medsina - Reçus Validés (Archives 30j)") et nettoyés de Supabase. Les reçus rejetés sont archivés immédiatement. Le quota Supabase reste ainsi perpétuellement libre.',
                  style: TextStyle(fontSize: 12, height: 1.45, color: isDark ? Colors.white70 : Colors.grey.shade700),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F9D58),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      icon: const Icon(Icons.archive_rounded, size: 16),
                      label: const Text(
                        'Archiver les Reçus Validés (+30 jours)',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        context.read<AdminBloc>().add(const ArchiveEligibleReceiptsEvent(retentionDays: 30));
                      },
                    ),
                    Text(
                      'Règle de rétention : 30 jours',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
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
                _buildContentRow('MedsinaPilot (Copilote Médical IA)', 'Google Gemini 3.8 Flash & Argon', Icons.auto_awesome_rounded),
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
    final adminState = context.read<AdminBloc>().state;
    final matchingUser = adminState.users.where((u) => u.id == payment.userId || u.email == payment.userEmail).firstOrNull;
    final currentRejections = matchingUser?.rejectedPaymentsCount ?? 0;
    final willBeBanned = currentRejections >= 2;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: willBeBanned ? const Color(0xFFDC2626) : Colors.orange),
            const SizedBox(width: 8),
            Text(willBeBanned ? 'Rejet & Bannissement Auto' : 'Rejeter la Preuve de Paiement'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Médecin : ${payment.userName} (${payment.userEmail})', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: willBeBanned ? const Color(0xFFDC2626).withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: willBeBanned ? const Color(0xFFDC2626) : Colors.orange),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    willBeBanned
                        ? '🚨 ATTENTION : Ce médecin a déjà $currentRejections rejet(s) enregistré(s). Ce rejet portera son total à ${currentRejections + 1}/3 et déclenchera son BANNISSEMENT AUTOMATIQUE IMMÉDIAT.'
                        : '⚠️ Avertissement : Ce sera le rejet n°${currentRejections + 1}/3 pour ce médecin. À 3 rejets, son compte sera automatiquement suspendu.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: willBeBanned ? const Color(0xFFDC2626) : Colors.orange.shade800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '☁️ Le reçu sera immédiatement transféré sur Google Drive ("Medsina - Reçus Rejetés") et purgé du stockage Supabase.',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(labelText: 'Motif du rejet (notifié par email au candidat)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AdminBloc>().add(
                    RejectPaymentEvent(
                      paymentId: payment.id,
                      adminNotes: noteCtrl.text.trim(),
                    ),
                  );
            },
            child: Text(willBeBanned ? 'Confirmer & Bannir' : 'Confirmer le Rejet'),
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
                  isExpanded: true,
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

  void _showConfigureWebhookDialog(BuildContext context) async {
    final currentUrl = await MedsinaNotificationDispatcher.getWebhookUrl() ?? '';
    if (!mounted) return;
    final ctrl = TextEditingController(text: currentUrl);

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.webhook_rounded, color: Color(0xFF0F9D58)),
            SizedBox(width: 8),
            Text('Webhook Google Apps Script'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'URL du Webhook Google Apps Script (Drive + Email sans frais externes) :',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                hintText: 'https://script.google.com/macros/s/.../exec',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Fichier script : supabase/google_drive_and_email_dispatcher.js',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F9D58), foregroundColor: Colors.white),
            onPressed: () async {
              await MedsinaNotificationDispatcher.setWebhookUrl(ctrl.text.trim());
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('URL du Webhook Google Apps Script enregistrée avec succès !'),
                    backgroundColor: Color(0xFF0F9D58),
                  ),
                );
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkGitHubConfigAndLoadRuns() async {
    var configured = await GitHubActionsService.isConfigured();
    // Auto-recover from Supabase Cloud if local preferences are empty (e.g. after reinstall/update)
    if (!configured) {
      final syncRes = await GitHubActionsService.syncFromSupabase();
      configured = syncRes['token'] != null && syncRes['token']!.isNotEmpty;
    }
    if (mounted) {
      setState(() => _isGitHubConfigured = configured);
    }
    await Future.wait([
      _refreshRecentWorkflowRuns(),
      _loadDiscoveredBlidaResources(),
    ]);
  }

  Future<void> _loadDiscoveredBlidaResources({String? status}) async {
    if (_isLoadingBlidaQueue) return;
    final targetStatus = status ?? _blidaQueueFilterStatus;
    setState(() {
      _isLoadingBlidaQueue = true;
      _blidaQueueFilterStatus = targetStatus;
      _selectedBlidaResourceIds.clear();
    });
    try {
      final items = await SupabaseService.fetchDiscoveredBlidaResources(
        status: targetStatus,
      );
      if (mounted) {
        setState(() {
          _discoveredBlidaResources = items;
          _isLoadingBlidaQueue = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingBlidaQueue = false);
      }
    }
  }

  Future<void> _handleBatchBlidaValidation(String newStatus) async {
    if (_selectedBlidaResourceIds.isEmpty || _isProcessingBatchBlida) return;
    final idsToProcess = _selectedBlidaResourceIds.toList();
    final count = idsToProcess.length;
    setState(() {
      _isProcessingBatchBlida = true;
    });

    try {
      await SupabaseService.updateDiscoveredBlidaResourcesBatch(
        idsOrHashes: idsToProcess,
        newStatus: newStatus,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: newStatus == 'approved' ? const Color(0xFF10B981) : const Color(0xFFEF4444),
          content: Text(
            newStatus == 'approved'
                ? '$count ressource(s) Blida approuvée(s) avec succès !'
                : '$count ressource(s) Blida rejetée(s).',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
      setState(() {
        _selectedBlidaResourceIds.clear();
      });
      await _loadDiscoveredBlidaResources();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
            content: Text('Erreur lors de la validation par lot : $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingBatchBlida = false;
        });
      }
    }
  }

  Future<void> _refreshRecentWorkflowRuns() async {
    if (_isLoadingRuns) return;
    setState(() => _isLoadingRuns = true);
    try {
      final runs = await GitHubActionsService.fetchRecentRuns(perPage: 15);
      if (mounted) {
        setState(() {
          _recentWorkflowRuns = runs;
          _isLoadingRuns = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingRuns = false);
    }
  }

  // --- TAB 7 : AGENTS IA & GITHUB ACTIONS AUTOMATION ---
  Widget _buildGitHubAgentsTab(BuildContext context, AdminState state, bool isDark) {
    return RefreshIndicator(
      onRefresh: () async {
        await _checkGitHubConfigAndLoadRuns();
        if (context.mounted) {
          context.read<AdminBloc>().add(LoadAdminDataEvent());
        }
      },
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 1. Header Banner & Connection Status
          Card(
            elevation: isDark ? 0 : 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.smart_toy_rounded, color: Color(0xFF6366F1), size: 30),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Supervision des Agents IA GitHub',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Déclenchez manuellement les agents autonomes MedsinaPilot sur GitHub Actions sans attendre les planificateurs cron.',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 520;
                      if (isNarrow) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: _isGitHubConfigured
                                          ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                          : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: _isGitHubConfigured ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _isGitHubConfigured ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                                          size: 14,
                                          color: _isGitHubConfigured ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                        ),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            _isGitHubConfigured ? 'GitHub PAT Connecté' : 'PAT GitHub Non Configuré',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: _isGitHubConfigured ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Actualiser le statut et les exécutions',
                                  icon: _isLoadingRuns
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.refresh_rounded),
                                  onPressed: () {
                                    _refreshRecentWorkflowRuns();
                                    context.read<AdminBloc>().add(LoadAdminDataEvent());
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.settings_rounded, size: 16),
                              label: const Text('Configurer Token PAT'),
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                foregroundColor: isDark ? Colors.white : Colors.black87,
                              ),
                              onPressed: _showConfigureGitHubTokenDialog,
                            ),
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: _isGitHubConfigured
                                  ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                  : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _isGitHubConfigured ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isGitHubConfigured ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                                  size: 14,
                                  color: _isGitHubConfigured ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _isGitHubConfigured ? 'GitHub PAT Connecté' : 'PAT GitHub Non Configuré',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _isGitHubConfigured ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.settings_rounded, size: 16),
                            label: const Text('Configurer Token PAT'),
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              foregroundColor: isDark ? Colors.white : Colors.black87,
                            ),
                            onPressed: _showConfigureGitHubTokenDialog,
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: 'Actualiser le statut et les exécutions',
                            icon: _isLoadingRuns
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.refresh_rounded),
                            onPressed: () {
                              _refreshRecentWorkflowRuns();
                              context.read<AdminBloc>().add(LoadAdminDataEvent());
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 1.4. Chasseur Promo Telegram & Assistant Réponses Facebook
          _buildPromoHunterBanner(isDark),
          const SizedBox(height: 24),

          // 1.5. Facebook AI Prompts Section (New)
          _buildFacebookPublisherSection(context, isDark),
          const SizedBox(height: 24),

          // 1.6. Blida Telegram & Google Drive Validation Queue Section
          _buildBlidaValidationQueueSection(context, isDark),
          const SizedBox(height: 28),

          // 2. Agents List Section Title
          const Row(
            children: [
              Icon(Icons.bolt_rounded, color: Color(0xFFF59E0B), size: 22),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Lancer un Agent Automatique (À la demande)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Cards of Available Agents
          ...GitHubActionsService.availableAgents.map((agent) {
            final isTriggering = _triggeringAgentId == agent.id;

            return Card(
              elevation: isDark ? 0 : 1.5,
              margin: const EdgeInsets.only(bottom: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: isDark ? Colors.white12 : Colors.grey.shade200,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: agent.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(agent.icon, color: agent.color, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      agent.title,
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.white10 : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      agent.workflowFile,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontFamily: 'monospace',
                                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                agent.description,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.schedule_rounded, size: 13, color: Colors.grey.shade500),
                                  const SizedBox(width: 4),
                                  Text(
                                    agent.defaultCadence,
                                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: agent.color,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: isTriggering
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.play_arrow_rounded, size: 18),
                          label: Text(
                            isTriggering ? 'Déclenchement en cours...' : 'Lancer l\'Agent 🚀',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          onPressed: isTriggering ? null : () => _onTriggerAgentPressed(agent),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 24),

          // 3. Live Runs History Section
          Row(
            children: [
              const Icon(Icons.history_rounded, color: Color(0xFF0284C7), size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Historique des Exécutions Récentes (GitHub Actions)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              if (_recentWorkflowRuns.isNotEmpty)
                Text(
                  '${_recentWorkflowRuns.length} runs',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (_isLoadingRuns && _recentWorkflowRuns.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_recentWorkflowRuns.isEmpty)
            Card(
              elevation: 0,
              color: isDark ? Colors.white10 : Colors.grey.shade100,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.cloud_off_rounded, size: 36, color: Colors.grey.shade400),
                    const SizedBox(height: 10),
                    const Text(
                      'Aucune exécution récente récupérée.',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Vérifiez la configuration de votre Token PAT ou cliquez sur "Actualiser".',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recentWorkflowRuns.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final run = _recentWorkflowRuns[index];

                Color statusColor = Colors.grey;
                IconData statusIcon = Icons.hourglass_empty_rounded;
                String statusLabel = 'En attente';

                if (run.isRunning) {
                  statusColor = const Color(0xFFF59E0B);
                  statusIcon = Icons.sync_rounded;
                  statusLabel = 'En cours ⏳';
                } else if (run.isSuccess) {
                  statusColor = const Color(0xFF10B981);
                  statusIcon = Icons.check_circle_rounded;
                  statusLabel = 'Succès ✅';
                } else if (run.isFailure) {
                  statusColor = const Color(0xFFEF4444);
                  statusIcon = Icons.cancel_rounded;
                  statusLabel = 'Échec ❌';
                } else if (run.conclusion == 'cancelled') {
                  statusColor = Colors.grey;
                  statusIcon = Icons.do_not_disturb_on_rounded;
                  statusLabel = 'Annulé';
                }

                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isDark ? Colors.white12 : Colors.grey.shade200,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: statusColor.withValues(alpha: 0.15),
                      child: Icon(statusIcon, color: statusColor, size: 20),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            run.name,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              run.event == 'schedule' ? '⏰ Automatique (Cron)' : '👤 Manuel (App/Dispatch)',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                              ),
                            ),
                          ),
                          Text(
                            '#${run.runNumber} • ${run.createdAt.day.toString().padLeft(2, '0')}/${run.createdAt.month.toString().padLeft(2, '0')} à ${run.createdAt.hour.toString().padLeft(2, '0')}:${run.createdAt.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      tooltip: 'Consulter les logs sur GitHub Actions',
                      onPressed: () async {
                        if (run.htmlUrl.isNotEmpty) {
                          final uri = Uri.parse(run.htmlUrl);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        }
                      },
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  void _onTriggerAgentPressed(GitHubAgentDefinition agent) async {
    if (agent.id == 'facebook') {
      _showFacebookPublisherDialog();
      return;
    }

    final configured = await GitHubActionsService.isConfigured();
    if (!mounted) return;
    if (!configured) {
      _showConfigureGitHubTokenDialog();
      return;
    }

    final inputCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: agent.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(agent.icon, color: agent.color, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Lancer ${agent.title}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              agent.description,
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Colors.blue, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Workflow cible : ${agent.workflowFile}\nBranche : main',
                      style: const TextStyle(fontSize: 11.5, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
            if (agent.inputFieldKey != null) ...[
              const SizedBox(height: 16),
              Text(
                '${agent.inputFieldLabel} :',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: inputCtrl,
                decoration: InputDecoration(
                  hintText: agent.inputFieldHint,
                  hintStyle: const TextStyle(fontSize: 12),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Laissez le champ vide pour laisser l\'agent IA sélectionner automatiquement le cours / DCI prioritaire.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          if (agent.id == 'facebook') ...[
            OutlinedButton.icon(
              icon: const Icon(Icons.psychology_rounded, size: 16),
              label: const Text('Générer Prompt Seul'),
              onPressed: () async {
                Navigator.pop(ctx);
                setState(() => _triggeringAgentId = agent.id);

                final val = inputCtrl.text.trim();
                final inputs = <String, String>{'publish': 'false'};
                if (val.isNotEmpty) inputs['topic'] = val;

                final result = await GitHubActionsService.triggerWorkflow(
                  workflowFileName: agent.workflowFile,
                  inputs: inputs,
                );

                if (!mounted) return;
                setState(() => _triggeringAgentId = null);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: result.isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    content: Text(result.message),
                    duration: const Duration(seconds: 4),
                  ),
                );

                await Future.delayed(const Duration(seconds: 2));
                if (mounted) _refreshRecentWorkflowRuns();
              },
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1877F2),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.rocket_launch_rounded, size: 16),
              label: const Text('Tout Créer & Publier Directement 🚀'),
              onPressed: () async {
                Navigator.pop(ctx);
                setState(() => _triggeringAgentId = agent.id);

                final val = inputCtrl.text.trim();
                final inputs = <String, String>{'publish': 'true'};
                if (val.isNotEmpty) inputs['topic'] = val;

                final result = await GitHubActionsService.triggerWorkflow(
                  workflowFileName: agent.workflowFile,
                  inputs: inputs,
                );

                if (!mounted) return;
                setState(() => _triggeringAgentId = null);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: result.isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    content: Text(
                      result.isSuccess
                          ? '🚀 Publication directe lancée ! L\'infographie et le texte seront en ligne sur Facebook sous peu.'
                          : result.message,
                    ),
                    duration: const Duration(seconds: 5),
                  ),
                );

                await Future.delayed(const Duration(seconds: 2));
                if (mounted) _refreshRecentWorkflowRuns();
              },
            ),
          ] else ...[
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: agent.color,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.rocket_launch_rounded, size: 18),
              label: const Text('Confirmer & Lancer'),
              onPressed: () async {
                Navigator.pop(ctx);
                setState(() => _triggeringAgentId = agent.id);

                final val = inputCtrl.text.trim();
                final inputs = val.isNotEmpty && agent.inputFieldKey != null ? {agent.inputFieldKey!: val} : null;

                final result = await GitHubActionsService.triggerWorkflow(
                  workflowFileName: agent.workflowFile,
                  inputs: inputs,
                );

                if (!mounted) return;
                setState(() => _triggeringAgentId = null);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: result.isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    content: Text(result.message),
                    duration: const Duration(seconds: 4),
                  ),
                );

                // Wait 2s and refresh runs so the queued run shows up
                await Future.delayed(const Duration(seconds: 2));
                if (mounted) _refreshRecentWorkflowRuns();
              },
            ),
          ],
        ],
      ),
    );
  }

  void _showConfigureGitHubTokenDialog() async {
    final currentToken = await GitHubActionsService.getGitHubToken() ?? '';
    final currentRepo = await GitHubActionsService.getRepo();

    if (!mounted) return;
    final tokenCtrl = TextEditingController(text: currentToken);
    final repoCtrl = TextEditingController(text: currentRepo);
    bool obscureToken = true;
    bool isSyncing = false;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.vpn_key_rounded, color: Color(0xFF6366F1)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Configuration GitHub Actions PAT',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pour permettre le déclenchement des agents depuis l\'application, renseignez un Personal Access Token (PAT) avec la permission "workflow" ou "actions:write" :',
                style: TextStyle(fontSize: 12.5),
              ),
              const SizedBox(height: 12),
              // Cloud Persistence Notice
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.2)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.cloud_done_rounded, color: Color(0xFF6366F1), size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Sauvegarde Cloud Supabase (RLS Admin) : Le token et le dépôt sont conservés sur votre base. En cas de désinstallation ou mise à jour, ils sont récupérés automatiquement !',
                        style: TextStyle(fontSize: 11, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: tokenCtrl,
                obscureText: obscureToken,
                decoration: InputDecoration(
                  labelText: 'GitHub Personal Access Token (ghp_...)',
                  hintText: 'ghp_xxxxxxxxxxxxxxxxxxxx',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: IconButton(
                    icon: Icon(obscureToken ? Icons.visibility_rounded : Icons.visibility_off_rounded, size: 20),
                    onPressed: () => setDialogState(() => obscureToken = !obscureToken),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: repoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Dépôt GitHub (owner/repo)',
                  hintText: 'dochafedh26/medsina',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    icon: const Icon(Icons.open_in_new_rounded, size: 14),
                    label: const Text('Générer sur GitHub', style: TextStyle(fontSize: 11.5)),
                    onPressed: () async {
                      final uri = Uri.parse('https://github.com/settings/tokens/new?scopes=repo,workflow');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    icon: isSyncing
                        ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.cloud_download_rounded, size: 14, color: Color(0xFF10B981)),
                    label: Text(
                      isSyncing ? 'Récupération...' : 'Récupérer depuis Cloud ☁️',
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
                    ),
                    onPressed: isSyncing
                        ? null
                        : () async {
                            setDialogState(() => isSyncing = true);
                            final syncRes = await GitHubActionsService.syncFromSupabase();
                            if (syncRes['token'] != null && syncRes['token']!.isNotEmpty) {
                              tokenCtrl.text = syncRes['token']!;
                            }
                            if (syncRes['repo'] != null && syncRes['repo']!.isNotEmpty) {
                              repoCtrl.text = syncRes['repo']!;
                            }
                            setDialogState(() => isSyncing = false);
                          },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
              ),
              onPressed: isSaving
                  ? null
                  : () async {
                      setDialogState(() => isSaving = true);
                      await GitHubActionsService.setGitHubToken(tokenCtrl.text.trim(), syncSupabase: true);
                      await GitHubActionsService.setRepo(repoCtrl.text.trim(), syncSupabase: true);
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (!mounted) return;
                      _checkGitHubConfigAndLoadRuns();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: Color(0xFF10B981),
                          content: Text('Configuration enregistrée localement et synchronisée sur Supabase Cloud ☁️ !'),
                        ),
                      );
                    },
              child: isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Enregistrer & Sauvegarder Cloud'),
            ),
          ],
        ),
      ),
    );
  }

  // --- SECTION : PUBLICATION OFFICIELLE FACEBOOK & TELEGRAM ---
  Widget _buildFacebookPublisherSection(BuildContext context, bool isDark) {
    return Card(
      elevation: isDark ? 0 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: const Color(0xFF1877F2).withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      color: isDark ? const Color(0xFF111827) : const Color(0xFFF0F5FF),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1877F2).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.facebook_rounded, color: Color(0xFF1877F2), size: 28),
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
                          const Text(
                            'Publication Officielle Facebook & Telegram',
                            style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Direct & Automatique',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Concevez une infographie 1080x1080 avec votre capture d\'écran réelle, texte rédigé par IA et diffusion immédiate sur les réseaux sociaux.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF1877F2).withValues(alpha: 0.3),
                  width: 1.2,
                ),
              ),
              child: LayoutBuilder(
                builder: (context, boxConstraints) {
                  final isNarrow = boxConstraints.maxWidth < 540;
                  final actionButton = ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1877F2),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 2,
                    ),
                    icon: _triggeringAgentId == 'facebook'
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.rocket_launch_rounded, size: 18),
                    label: Text(
                      _triggeringAgentId == 'facebook' ? 'Publication...' : 'Créer une Publication 🚀',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    onPressed: _triggeringAgentId == 'facebook' ? null : _showFacebookPublisherDialog,
                  );

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1877F2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.add_photo_alternate_rounded, color: Colors.white, size: 22),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Nouvelle Publication avec Capture d\'Écran',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sélectionnez une capture existante ou importez-en une nouvelle depuis votre appareil via le sélecteur de fichiers.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 14),
                        actionButton,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1877F2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.add_photo_alternate_rounded, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Nouvelle Publication avec Capture d\'Écran',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Sélectionnez une capture existante ou importez-en une nouvelle depuis votre appareil via le sélecteur de fichiers.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      actionButton,
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFacebookPublisherDialog() async {
    final configured = await GitHubActionsService.isConfigured();
    if (!mounted) return;
    if (!configured) {
      _showConfigureGitHubTokenDialog();
      return;
    }

    final topicCtrl = TextEditingController();
    String selectedType = 'auto';
    String? selectedScreenshot;
    String? pickedLocalPath;
    String mockupType = 'auto';
    bool isUploadingFile = false;

    final Map<String, String> standardScreenshots = {
      '': 'Sélection automatique / Assets standards',
      'Screenshot 2026-10-20 175342_dashboard.png': 'Tableau de Bord Récent Medsina (Desktop)',
      'desktop/prescription_audit_pc.png': 'Audit Ordonnance & Vidal PC',
      'desktop/revision_qcm_pc.png': 'Révision QCM & Concours PC',
      'desktop/clinical_copilot_pc.png': 'Copilote Clinique PC',
      'desktop/admin_analytics_pc.png': 'Analytics Administrateur PC',
      'mobile/clinical_copilot_mobile.png': 'Copilote Clinique Mobile',
      'mobile/ai_copilot_mobile.png': 'Assistant IA Mobile',
      'mobile/prescription_mobile.png': 'Prescription Mobile',
      'mobile/qcm_session_mobile.png': 'Session QCM Mobile',
    };

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1877F2).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.facebook_rounded, color: Color(0xFF1877F2), size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Créer une Publication Facebook & Telegram',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Le robot Medsina génère l\'infographie haute définition 1080x1080 avec votre capture d\'écran réelle et diffuse le post directement sur la page Facebook et le canal Telegram.',
                    style: TextStyle(fontSize: 12.5, height: 1.35),
                  ),
                  const SizedBox(height: 16),

                  // 1. Type de publication
                  const Text(
                    'Type de publication :',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedType,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'auto',
                        child: Text('Automatique (Médical le matin / Promo le soir)', overflow: TextOverflow.ellipsis),
                      ),
                      DropdownMenuItem(
                        value: 'commercial',
                        child: Text('Promotion Commerciale (Téléchargement de Medsina)', overflow: TextOverflow.ellipsis),
                      ),
                      DropdownMenuItem(
                        value: 'medical',
                        child: Text('Médicale Clinique & Concours (Fiches, CAT, Pièges)', overflow: TextOverflow.ellipsis),
                      ),
                      DropdownMenuItem(
                        value: 'qcm',
                        child: Text('🎯 QCM Annales Réelles (Source & Date Concours)', overflow: TextOverflow.ellipsis),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setDlgState(() => selectedType = val);
                    },
                  ),
                  const SizedBox(height: 14),

                  // 2. Thème / Sujet
                  const Text(
                    'Thème ou sujet spécifique (optionnel) :',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: topicCtrl,
                    decoration: const InputDecoration(
                      hintText: 'ex: Cardiologie, Pneumologie, Arrêt cardiaque, Blida 2023, Urgences...',
                      hintStyle: TextStyle(fontSize: 12),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 3. Capture d'écran
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      const Text(
                        'Capture d\'écran de l\'application :',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: const Color(0xFF1877F2),
                        ),
                        icon: isUploadingFile
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.file_upload_rounded, size: 16),
                        label: const Text('Importer une capture 📁'),
                        onPressed: isUploadingFile
                            ? null
                            : () async {
                                setDlgState(() => isUploadingFile = true);
                                try {
                                  final pickedFile = await FilePicker.pickFile(
                                    type: FileType.custom,
                                    allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
                                  );

                                  if (pickedFile != null) {
                                    final fileName = pickedFile.name;
                                    final path = pickedFile.path;

                                    if (path != null) {
                                      // 1. Sauvegarde locale sur Windows
                                      try {
                                        final targetDir = Directory('assets/screenshots/desktop');
                                        if (!targetDir.existsSync()) {
                                          targetDir.createSync(recursive: true);
                                        }
                                        File(path).copySync('${targetDir.path}/$fileName');
                                      } catch (e) {
                                        debugPrint('Copie locale screenshot: $e');
                                      }

                                      // 2. Upload dans Supabase Storage 'facebook_assets'
                                      final bytes = await pickedFile.readAsBytes();
                                      await SupabaseService.uploadFacebookScreenshot(fileName, bytes);

                                      setDlgState(() {
                                        selectedScreenshot = fileName;
                                        pickedLocalPath = path;
                                        isUploadingFile = false;
                                      });
                                    }
                                  } else {
                                    setDlgState(() => isUploadingFile = false);
                                  }
                                } catch (e) {
                                  debugPrint('File picker error: $e');
                                  setDlgState(() => isUploadingFile = false);
                                }
                              },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  DropdownButtonFormField<String>(
                    initialValue: selectedScreenshot ?? '',
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: [
                      ...standardScreenshots.entries.map((e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value, style: const TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis),
                          )),
                      if (selectedScreenshot != null &&
                          selectedScreenshot!.isNotEmpty &&
                          !standardScreenshots.containsKey(selectedScreenshot))
                        DropdownMenuItem(
                          value: selectedScreenshot,
                          child: Text('📁 $selectedScreenshot (Importé)', style: const TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (val) {
                      setDlgState(() {
                        selectedScreenshot = val;
                        pickedLocalPath = null;
                      });
                    },
                  ),

                  if (selectedScreenshot != null && selectedScreenshot!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF1877F2).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              width: 50,
                              height: 50,
                              color: Colors.black12,
                              child: pickedLocalPath != null && File(pickedLocalPath!).existsSync()
                                  ? Image.file(File(pickedLocalPath!), fit: BoxFit.cover)
                                  : Image.asset(
                                      'assets/screenshots/desktop/$selectedScreenshot',
                                      fit: BoxFit.cover,
                                      errorBuilder: (ctx, err, stack) => const Icon(Icons.image_rounded, size: 28),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  selectedScreenshot!,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Sera intégrée dans la maquette graphique 1080x1080',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF10B981)),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            tooltip: 'Retirer',
                            onPressed: () {
                              setDlgState(() {
                                selectedScreenshot = '';
                                pickedLocalPath = null;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),

                  // 4. Format de la maquette
                  const Text(
                    'Format du cadre de la maquette :',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: mockupType,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'auto',
                        child: Text('Automatique (Adapté selon l\'orientation de l\'image)', overflow: TextOverflow.ellipsis),
                      ),
                      DropdownMenuItem(
                        value: 'desktop',
                        child: Text('PC Desktop (Moniteur haute fidélité)', overflow: TextOverflow.ellipsis),
                      ),
                      DropdownMenuItem(
                        value: 'phone',
                        child: Text('Smartphone (Châssis mobile titanium)', overflow: TextOverflow.ellipsis),
                      ),
                      DropdownMenuItem(
                        value: 'none',
                        child: Text('Sans maquette (Infographie pleine largeur avec points clés)', overflow: TextOverflow.ellipsis),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setDlgState(() => mockupType = val);
                    },
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1877F2).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF1877F2).withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: Color(0xFF1877F2), size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Le post et l\'image seront directement mis en ligne sur la page Facebook Residanat Blida 2027 et Telegram.',
                            style: TextStyle(fontSize: 11.5, color: Color(0xFF1877F2), fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1877F2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              icon: const Icon(Icons.rocket_launch_rounded, size: 16),
              label: const Text('Tout Créer & Publier Directement 🚀'),
              onPressed: () {
                Navigator.pop(ctx);
                _triggerFacebookPublish(
                  topic: topicCtrl.text.trim(),
                  type: selectedType,
                  screenshot: selectedScreenshot,
                  mockupType: mockupType,
                );
              },
            ),
          ],
        );
      },
    ),
  );
  }

  void _triggerFacebookPublish({
    required String topic,
    required String type,
    String? screenshot,
    String? mockupType,
  }) async {
    setState(() => _triggeringAgentId = 'facebook');

    final inputs = <String, String>{
      'type': type,
    };
    if (topic.isNotEmpty) {
      inputs['topic'] = topic;
    }
    if (screenshot != null && screenshot.isNotEmpty) {
      inputs['screenshot'] = screenshot;
    }
    if (mockupType != null && mockupType != 'auto') {
      inputs['mockup_type'] = mockupType;
    }

    final result = await GitHubActionsService.triggerWorkflow(
      workflowFileName: 'medsina_facebook.yml',
      inputs: inputs,
    );

    if (!mounted) return;
    setState(() => _triggeringAgentId = null);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: result.isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444),
        content: Text(
          result.isSuccess
              ? '🚀 Publication Facebook et Telegram lancée ! L\'infographie 1080x1080 et le texte seront en ligne dans ~1 minute.'
              : result.message,
        ),
        duration: const Duration(seconds: 5),
      ),
    );

    await Future.delayed(const Duration(seconds: 2));
    if (mounted) _refreshRecentWorkflowRuns();
  }

  void _showPromoHunterDialog({String initialTarget = 'telegram'}) async {
    final configured = await GitHubActionsService.isConfigured();
    if (!mounted) return;
    if (!configured) {
      _showConfigureGitHubTokenDialog();
      return;
    }

    String selectedTarget = initialTarget;
    int maxReplies = 2;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.forum_rounded, color: Color(0xFF0284C7)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Chasseur Promo & Entraide (Telegram & FB)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Recherche en direct les questions d étudiants et concours sur Telegram (Résidanat, QCMs, annales, cours) et y répond poliment avec les liens officiels Medsina.',
                      style: TextStyle(fontSize: 12.5, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.shield_outlined, color: Color(0xFF10B981), size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Sécurité garantie : canaux MBset strictement exclus + temporisation anti-flood de 180s.',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Cible de l exécution :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedTarget,
                      decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                      items: const [
                        DropdownMenuItem(value: 'telegram', child: Text('Telegram Option B (Discussions & Entraide)')),
                        DropdownMenuItem(value: 'facebook', child: Text('Facebook Pages (Réponses aux Commentaires)')),
                        DropdownMenuItem(value: 'all', child: Text('Tout Exécuter (Telegram + Facebook)')),
                      ],
                      onChanged: (val) => setDlgState(() => selectedTarget = val ?? 'telegram'),
                    ),
                    const SizedBox(height: 16),
                    const Text('Plafond de réponses Telegram :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      initialValue: maxReplies,
                      decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('1 réponse ciblée')),
                        DropdownMenuItem(value: 2, child: Text('2 réponses (Recommandé)')),
                        DropdownMenuItem(value: 3, child: Text('3 réponses')),
                        DropdownMenuItem(value: 5, child: Text('5 réponses maximum')),
                      ],
                      onChanged: (val) => setDlgState(() => maxReplies = val ?? 2),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.rocket_launch_rounded, size: 16),
                label: const Text('Lancer la Campagne 🚀'),
                onPressed: () {
                  Navigator.pop(ctx);
                  _triggerPromoHunter(target: selectedTarget, maxReplies: maxReplies);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _triggerPromoHunter({required String target, required int maxReplies}) async {
    setState(() => _triggeringAgentId = 'telegram_promo_hunter');

    final inputs = <String, String>{
      'target': target,
      'max_replies': maxReplies.toString(),
    };

    final result = await GitHubActionsService.triggerWorkflow(
      workflowFileName: 'medsina_promo_hunter.yml',
      inputs: inputs,
    );

    if (!mounted) return;
    setState(() => _triggeringAgentId = null);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: result.isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444),
        content: Text(
          result.isSuccess
              ? '🎯 Chasseur Promo déclenché ! Détection et réponses en cours.'
              : result.message,
        ),
        duration: const Duration(seconds: 5),
      ),
    );

    await Future.delayed(const Duration(seconds: 2));
    if (mounted) _refreshRecentWorkflowRuns();
  }

  Widget _buildRecentSubscribersCard(BuildContext context, AdminState state, bool isDark) {
    // Sort users by createdAt descending
    final recentUsers = List<AdminUserItem>.from(state.users)
      ..sort((a, b) {
        if (a.createdAt == null && b.createdAt == null) return 0;
        if (a.createdAt == null) return 1;
        if (b.createdAt == null) return -1;
        return b.createdAt!.compareTo(a.createdAt!);
      });

    final topUsers = recentUsers.take(6).toList();

    return Card(
      elevation: isDark ? 0 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: AppTheme.primaryTeal.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Top Row: Icon + Title + Badge + Tab button
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryTeal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.person_add_alt_1_rounded, color: AppTheme.primaryTeal, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      const Text(
                        'Dernières Inscriptions',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'EN DIRECT ⚡',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF059669),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => _tabController.animateTo(1),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurfaceElevated : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Tab 2', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        SizedBox(width: 2),
                        Icon(Icons.arrow_forward_rounded, size: 13),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Alertes temps réel sur les nouveaux comptes et abonnements actifs',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),

            if (topUsers.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'Aucune inscription enregistrée pour le moment.',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: topUsers.length,
                separatorBuilder: (_, _) => const Divider(height: 12),
                itemBuilder: (ctx, i) {
                  final u = topUsers[i];
                  return _buildRecentSubscriberRow(context, u, isDark);
                },
              ),

            const SizedBox(height: 10),
            InkWell(
              onTap: () => _tabController.animateTo(1),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.primaryTeal.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        'Gérer tous les comptes dans Médecins & Comptes',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.primaryTeal),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded, size: 14, color: AppTheme.primaryTeal),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentSubscriberRow(BuildContext context, AdminUserItem u, bool isDark) {
    final initials = u.fullName.trim().isNotEmpty
        ? u.fullName.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
        : 'DR';

    final isPaid = u.tier != 'free';
    final tierColor = isPaid ? const Color(0xFF10B981) : const Color(0xFF0284C7);
    final tierLabel = isPaid ? u.tier.toUpperCase() : 'Essai Gratuit 14j';

    return InkWell(
      onTap: () {
        _searchController.text = u.email;
        context.read<AdminBloc>().add(SearchUsersEvent(u.email));
        _tabController.animateTo(1);
      },
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.primaryTeal.withValues(alpha: 0.15),
              child: Text(
                initials,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryTeal),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          u.fullName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (u.isAdmin) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('ADMIN', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.red)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${u.medicalRole} • ${u.faculty}',
                    style: TextStyle(fontSize: 10.5, color: isDark ? Colors.white60 : Colors.grey.shade700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    u.email,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: tierColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: tierColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    tierLabel,
                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: tierColor),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatRelativeTime(u.createdAt),
                  style: TextStyle(fontSize: 9.5, color: Colors.grey.shade500),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatRelativeTime(DateTime? dt) {
    if (dt == null) return 'Date inconnue';
    final local = dt.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);

    if (diff.inMinutes < 1) return 'À l\'instant';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays}j';
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }

  // --- BLIDA TELEGRAM & GOOGLE DRIVE VALIDATION QUEUE UI ---

  Widget _buildBlidaValidationQueueSection(BuildContext context, bool isDark) {
    const accentColor = Color(0xFF0EA5E9);

    return Card(
      elevation: isDark ? 0 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: accentColor.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.radar_rounded, color: accentColor, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text(
                            'File d\'Attente de Validation Blida (Telegram & Drive)',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${_discoveredBlidaResources.length} élément(s)',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: accentColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ressources PDF, QCM, EMD et Drives détectés automatiquement sur les canaux Telegram et Google Drive de Médecine Blida. Aucune ressource n\'est publiée sans votre validation.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Filter chips + Action buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildBlidaFilterChip('pending', 'En attente ⏳', const Color(0xFFF59E0B), isDark),
                    _buildBlidaFilterChip('approved', 'Approuvés ✅', const Color(0xFF10B981), isDark),
                    _buildBlidaFilterChip('rejected', 'Rejetés ❌', const Color(0xFFEF4444), isDark),
                    _buildBlidaFilterChip('all', 'Tous', accentColor, isDark),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.tune_rounded, size: 16),
                      label: const Text('Sources Surveillées', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: accentColor,
                        side: BorderSide(color: accentColor.withValues(alpha: 0.5)),
                      ),
                      onPressed: () => _showConfigureBlidaSourcesDialog(context),
                    ),
                    ElevatedButton.icon(
                      icon: _triggeringAgentId == 'blida_scanner'
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.radar_rounded, size: 16),
                      label: const Text('Scanner Maintenant', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: _triggeringAgentId == 'blida_scanner'
                          ? null
                          : () {
                              final scannerAgent = GitHubActionsService.availableAgents
                                  .where((a) => a.id == 'blida_scanner')
                                  .firstOrNull;
                              if (scannerAgent != null) {
                                _onTriggerAgentPressed(scannerAgent);
                              }
                            },
                    ),
                    IconButton(
                      tooltip: 'Actualiser la file d\'attente',
                      visualDensity: VisualDensity.compact,
                      icon: _isLoadingBlidaQueue
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh_rounded, size: 20),
                      onPressed: () => _loadDiscoveredBlidaResources(),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),

            if (_isLoadingBlidaQueue && _discoveredBlidaResources.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_discoveredBlidaResources.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Icon(Icons.inbox_rounded, size: 34, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    Text(
                      _blidaQueueFilterStatus == 'pending'
                          ? 'Aucune ressource en attente de validation.'
                          : 'Aucune ressource dans ce filtre.',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Lancez le "Scanner Maintenant" ou configurez de nouveaux canaux Telegram / dossiers Google Drive.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              )
            else ...[
              // Multi-selection action toolbar
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _selectedBlidaResourceIds.isNotEmpty
                        ? accentColor.withValues(alpha: 0.4)
                        : (isDark ? Colors.white10 : Colors.grey.shade300),
                  ),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: _discoveredBlidaResources.isNotEmpty &&
                          _selectedBlidaResourceIds.length == _discoveredBlidaResources.length,
                      tristate: _selectedBlidaResourceIds.isNotEmpty &&
                          _selectedBlidaResourceIds.length < _discoveredBlidaResources.length,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedBlidaResourceIds.clear();
                            for (final r in _discoveredBlidaResources) {
                              final k = (r['id'] ?? r['external_id_hash'] ?? '').toString();
                              if (k.isNotEmpty) _selectedBlidaResourceIds.add(k);
                            }
                          } else {
                            _selectedBlidaResourceIds.clear();
                          }
                        });
                      },
                      activeColor: accentColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      visualDensity: VisualDensity.compact,
                    ),
                    Text(
                      _selectedBlidaResourceIds.isEmpty
                          ? 'Tout sélectionner (${_discoveredBlidaResources.length})'
                          : '${_selectedBlidaResourceIds.length}/${_discoveredBlidaResources.length} sélectionné(s)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: _selectedBlidaResourceIds.isNotEmpty ? FontWeight.w800 : FontWeight.w600,
                        color: _selectedBlidaResourceIds.isNotEmpty
                            ? accentColor
                            : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                    const Spacer(),
                    if (_selectedBlidaResourceIds.isNotEmpty) ...[
                      TextButton(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        onPressed: () {
                          setState(() {
                            _selectedBlidaResourceIds.clear();
                          });
                        },
                        child: const Text('Désélectionner', style: TextStyle(fontSize: 11)),
                      ),
                      const SizedBox(width: 4),
                      ElevatedButton.icon(
                        icon: _isProcessingBatchBlida
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check_circle_rounded, size: 14),
                        label: Text(
                          'Approuver (${_selectedBlidaResourceIds.length})',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        ),
                        onPressed: _isProcessingBatchBlida
                            ? null
                            : () => _handleBatchBlidaValidation('approved'),
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.close_rounded, size: 14, color: Color(0xFFEF4444)),
                        label: Text(
                          'Rejeter (${_selectedBlidaResourceIds.length})',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFEF4444)),
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        ),
                        onPressed: _isProcessingBatchBlida
                            ? null
                            : () => _handleBatchBlidaValidation('rejected'),
                      ),
                    ],
                  ],
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 460),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _discoveredBlidaResources.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (ctx, index) {
                    final item = _discoveredBlidaResources[index];
                    return _buildDiscoveredBlidaResourceCard(context, item, isDark);
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBlidaFilterChip(String statusKey, String label, Color color, bool isDark) {
    final isSelected = _blidaQueueFilterStatus == statusKey;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          color: isSelected ? color : (isDark ? Colors.white70 : Colors.grey.shade700),
        ),
      ),
      selected: isSelected,
      selectedColor: color.withValues(alpha: 0.18),
      backgroundColor: isDark ? Colors.white10 : Colors.grey.shade100,
      side: BorderSide(
        color: isSelected ? color : Colors.transparent,
      ),
      visualDensity: VisualDensity.compact,
      onSelected: (_) => _loadDiscoveredBlidaResources(status: statusKey),
    );
  }

  Widget _buildDiscoveredBlidaResourceCard(
    BuildContext context,
    Map<String, dynamic> item,
    bool isDark,
  ) {
    final idOrHash = (item['id'] ?? item['external_id_hash'] ?? '').toString();
    final title = (item['title'] ?? 'Ressource sans titre').toString();
    final sourceType = (item['source_type'] ?? 'telegram').toString();
    final sourceChannel = (item['source_channel_or_folder'] ?? '').toString();
    final resourceType = (item['resource_type'] ?? 'other').toString();
    final url = (item['url'] ?? '').toString();
    final module = (item['suggested_module'] ?? 'Médecine Blida').toString();
    final year = (item['study_year'] ?? '').toString();
    final summary = (item['ai_summary'] ?? item['description'] ?? '').toString();
    final status = (item['status'] ?? 'pending').toString();

    final isDrive = sourceType.contains('drive');
    final sourceColor = isDrive ? const Color(0xFF10B981) : const Color(0xFF0EA5E9);
    final sourceIcon = isDrive ? Icons.add_to_drive_rounded : Icons.telegram_rounded;
    final sourceLabel = isDrive ? 'Google Drive' : 'Telegram';

    String typeLabel = 'Ressource';
    Color typeColor = const Color(0xFF6366F1);
    if (resourceType == 'qcm_exam') {
      typeLabel = 'QCM / EMD';
      typeColor = const Color(0xFFF59E0B);
    } else if (resourceType == 'pdf_course') {
      typeLabel = 'Cours PDF';
      typeColor = const Color(0xFFEC4899);
    } else if (resourceType == 'drive_folder') {
      typeLabel = 'Dossier Drive';
      typeColor = const Color(0xFF10B981);
    }

    final isSelected = _selectedBlidaResourceIds.contains(idOrHash);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isSelected
            ? AppTheme.primaryTeal.withValues(alpha: isDark ? 0.12 : 0.06)
            : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? AppTheme.primaryTeal
              : (isDark ? Colors.white12 : Colors.grey.shade200),
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: isSelected,
            onChanged: (val) {
              setState(() {
                if (val == true) {
                  _selectedBlidaResourceIds.add(idOrHash);
                } else {
                  _selectedBlidaResourceIds.remove(idOrHash);
                }
              });
            },
            activeColor: AppTheme.primaryTeal,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          // Top badges + Title
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: sourceColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(sourceIcon, size: 13, color: sourceColor),
                    const SizedBox(width: 4),
                    Text(
                      sourceChannel.isNotEmpty ? '$sourceLabel • $sourceChannel' : sourceLabel,
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: sourceColor),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  typeLabel,
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: typeColor),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primaryTeal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  year.isNotEmpty ? '$module ($year)' : module,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryTeal,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (summary.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              summary,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              if (url.isNotEmpty)
                OutlinedButton.icon(
                  icon: const Icon(Icons.open_in_new_rounded, size: 15),
                  label: const Text('Inspecter Lien', style: TextStyle(fontSize: 11.5)),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () async {
                    final uri = Uri.tryParse(url);
                    if (uri != null && await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                ),
              if (status != 'approved')
                ElevatedButton.icon(
                  icon: const Icon(Icons.check_rounded, size: 15),
                  label: const Text('Approuver', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () async {
                    final ok = await SupabaseService.updateDiscoveredBlidaResourceStatus(
                      idOrHash: idOrHash,
                      newStatus: 'approved',
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: ok ? const Color(0xFF10B981) : Colors.orange,
                        content: Text(
                          ok
                              ? '✅ Ressource "$title" approuvée avec succès !'
                              : 'Mise à jour locale effectuée.',
                        ),
                      ),
                    );
                    _loadDiscoveredBlidaResources();
                  },
                ),
              if (status != 'rejected')
                OutlinedButton.icon(
                  icon: const Icon(Icons.close_rounded, size: 15, color: Color(0xFFEF4444)),
                  label: const Text(
                    'Rejeter',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFFEF4444), fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    side: const BorderSide(color: Color(0xFFEF4444)),
                  ),
                  onPressed: () async {
                    final ok = await SupabaseService.updateDiscoveredBlidaResourceStatus(
                      idOrHash: idOrHash,
                      newStatus: 'rejected',
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: ok ? const Color(0xFF64748B) : Colors.orange,
                        content: Text('Ressource "$title" écartée de la file.'),
                      ),
                    );
                    _loadDiscoveredBlidaResources();
                  },
                ),
            ],
          ),
        ],
      ),
    ),
  ],
),
    );
  }

  void _showConfigureBlidaSourcesDialog(BuildContext context) async {
    final currentConfig = await SupabaseService.getBlidaScannerSources();
    if (!context.mounted) return;

    final ctrl = TextEditingController(text: currentConfig);
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.radar_rounded, color: Color(0xFF0EA5E9)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Sources Telegram & Google Drive (Médecine Blida)',
                  style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Configurez la liste JSON des canaux Telegram publics (@handle), des dossiers Google Drive partagés et des mots-clés surveillés par le robot GitHub Actions :',
                    style: TextStyle(fontSize: 12.5),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ctrl,
                    maxLines: 14,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: '{\n  "telegram_channels": ["fmb_blida"],\n  "google_drive_folders": ["https://drive.google.com/..."]\n}',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0EA5E9),
                foregroundColor: Colors.white,
              ),
              icon: isSaving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_rounded, size: 16),
              label: const Text('Enregistrer sur Supabase Cloud'),
              onPressed: isSaving
                  ? null
                  : () async {
                      final raw = ctrl.text.trim();
                      try {
                        jsonDecode(raw);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: Colors.red,
                            content: Text('Format JSON invalide : $e'),
                          ),
                        );
                        return;
                      }
                      setDlgState(() => isSaving = true);
                      final ok = await SupabaseService.saveBlidaScannerSources(raw);
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: ok ? const Color(0xFF10B981) : Colors.red,
                          content: Text(
                            ok
                                ? '✅ Sources Telegram & Google Drive sauvegardées sur Supabase Cloud !'
                                : 'Erreur lors de la sauvegarde des sources.',
                          ),
                        ),
                      );
                    },
            ),
          ],
        ),
      ),
    );
  }
}
