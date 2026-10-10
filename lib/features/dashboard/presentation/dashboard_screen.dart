import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';
import '../../subscription/presentation/subscription_paywall_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        final user = authState.user;
        final tier = user?.tier ?? SubscriptionTier.free;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome & Subscription Banner
              _buildWelcomeBanner(context, user?.fullName ?? 'Docteur', tier, user?.daysRemaining ?? 0),
              const SizedBox(height: 24),

              // Overview Stats Grid
              _buildStatsGrid(context),
              const SizedBox(height: 28),

              // Clinical Tip of the Day
              _buildClinicalTipCard(context),
              const SizedBox(height: 28),

              // Quick Actions / Modules En Cours
              const Text(
                'Accès Rapide & Continuité de Révision',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              _buildQuickAccessCards(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWelcomeBanner(BuildContext context, String name, SubscriptionTier tier, int daysRemaining) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF0D9488), Color(0xFF0284C7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryTeal.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'RÉSIDANAT BLIDA 2027 • SUITE MÉDICALE PRO',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Bienvenue, $name',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Accès actif : ${tier.label} ($daysRemaining jours restants)',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.primaryDarkTeal,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SubscriptionPaywallScreen()),
                  );
                },
                icon: const Icon(Icons.star_rounded, size: 18, color: Color(0xFFF59E0B)),
                label: const Text('Gérer Offre', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 700 ? 3 : 1;

        if (crossAxisCount == 1) {
          return Column(
            children: [
              _buildStatCard(
                'Formation Résidanat',
                '47 Modules • 6 240 QCMs',
                'Banque complète Blida & National',
                Icons.school_rounded,
                AppTheme.primaryTeal,
              ),
              const SizedBox(height: 12),
              _buildStatCard(
                'Pratique Clinique',
                '18 CAT & Protocoles',
                'Arbres décisionnels d\'urgence',
                Icons.emergency_rounded,
                const Color(0xFFEF4444),
              ),
              const SizedBox(height: 12),
              _buildStatCard(
                'Calculateurs & Scores',
                'Glasgow, Wells, Cockcroft',
                'Calcul instantané au lit du malade',
                Icons.calculate_rounded,
                AppTheme.accentCyan,
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Formation Résidanat',
                '47 Modules • 6 240 QCMs',
                'Banque complète Blida & National',
                Icons.school_rounded,
                AppTheme.primaryTeal,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildStatCard(
                'Pratique Clinique',
                '18 CAT & Protocoles',
                'Arbres décisionnels d\'urgence',
                Icons.emergency_rounded,
                const Color(0xFFEF4444),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildStatCard(
                'Calculateurs & Scores',
                'Glasgow, Wells, Cockcroft',
                'Calcul instantané au lit du malade',
                Icons.calculate_rounded,
                AppTheme.accentCyan,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, String subtitle, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClinicalTipCard(BuildContext context) {
    return Card(
      color: AppTheme.accentCyan.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppTheme.accentCyan.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.tips_and_updates_rounded, color: AppTheme.accentCyan, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Perle Clinique du Jour : Décompensation Acido-Cétosique',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.accentCyan),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Règle vitale : Ne JAMAIS débuter l\'insuline si la kaliémie initiale est < 3,3 mmol/L. L\'insuline provoque une entrée massive de potassium dans les cellules et risque d\'entraîner un arrêt cardiaque en hypokaliémie foudroyante.',
                    style: TextStyle(fontSize: 13, height: 1.4, color: Theme.of(context).textTheme.bodyMedium?.color),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAccessCards(BuildContext context) {
    return Column(
      children: [
        ListTile(
          tileColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Theme.of(context).dividerColor),
          ),
          leading: const CircleAvatar(
            backgroundColor: Color(0xFFE0F2FE),
            child: Icon(Icons.favorite_rounded, color: AppTheme.primaryTeal),
          ),
          title: const Text('Cardiologie — HTA & Syndromes Coronariens Aigus', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          subtitle: const Text('Reprendre l\'entraînement : 340 questions disponibles • Fiche de cours PDF prête'),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Accédez à l\'onglet Résidanat pour lancer la session !')),
            );
          },
        ),
        const SizedBox(height: 10),
        ListTile(
          tileColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Theme.of(context).dividerColor),
          ),
          leading: const CircleAvatar(
            backgroundColor: Color(0xFFFEE2E2),
            child: Icon(Icons.flash_on_rounded, color: Color(0xFFEF4444)),
          ),
          title: const Text('CAT Urgence : Prise en charge SCA ST+ (IDM)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          subtitle: const Text('Arbre de décision reperfusion < 120 min • Posologies antithrombotiques'),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Accédez à l\'onglet Clinique pour consulter le protocole complet.')),
            );
          },
        ),
      ],
    );
  }
}
