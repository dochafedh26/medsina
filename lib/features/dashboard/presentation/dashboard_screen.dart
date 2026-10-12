import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';
import '../../auth/presentation/test_accounts_sheet.dart';
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
              _buildWelcomeBanner(
                context,
                user?.fullName ?? 'Docteur',
                tier,
                user?.daysRemaining ?? 0,
                user?.isSubscriptionActive == false,
              ),
              const SizedBox(height: 24),

              // Overview Stats Grid
              _buildStatsGrid(context, tier, user?.isSubscriptionActive == false),
              const SizedBox(height: 28),

              // Clinical Tip of the Day
              _buildClinicalTipCard(context, tier, user?.isSubscriptionActive ?? true),
              const SizedBox(height: 28),

              // Quick Actions / Modules En Cours
              Text(
                tier == SubscriptionTier.clinicalPro
                    ? 'Actions Rapides Urgences & Clinique'
                    : (tier == SubscriptionTier.residentElite
                        ? 'Continuité de Révision & Entraînement Résidanat'
                        : 'Accès Rapide & Continuité de Révision'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              _buildQuickAccessCards(context, tier, user?.isSubscriptionActive == false),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWelcomeBanner(
    BuildContext context,
    String name,
    SubscriptionTier tier,
    int daysRemaining,
    bool isExpired,
  ) {
    List<Color> gradientColors;
    String badgeText;
    String subtitleText;

    if (isExpired) {
      gradientColors = const [Color(0xFF991B1B), Color(0xFFDC2626), Color(0xFFB91C1C)];
      badgeText = '⚠️ ABONNEMENT EXPIRÉ • ACCÈS SUSPENDU';
      subtitleText = 'Votre licence a expiré. Renouvelez votre offre pour débloquer l\'accès complet.';
    } else {
      switch (tier) {
        case SubscriptionTier.allAccess:
          gradientColors = const [Color(0xFF4C1D95), Color(0xFF6D28D9), Color(0xFF8B5CF6)];
          badgeText = '🌟 MEDSINA ALL-ACCESS VIP • ACCÈS INTÉGRAL';
          subtitleText = 'Formule complète illimitée : 47 modules, QCMs, CATs & IA ($daysRemaining jours restants)';
          break;
        case SubscriptionTier.residentElite:
          gradientColors = const [Color(0xFF0F766E), Color(0xFF0D9488), Color(0xFF14B8A6)];
          badgeText = '🎯 PASS RÉSIDENT ÉLITE • SPÉCIAL CONCOURS 2027';
          subtitleText = 'Accès concours complet : 47 modules & 6 240+ QCMs ($daysRemaining jours restants)';
          break;
        case SubscriptionTier.clinicalPro:
          gradientColors = const [Color(0xFF0369A1), Color(0xFF0284C7), Color(0xFF38BDF8)];
          badgeText = '🩺 PASS CLINIQUE PRO • PRATIQUE HOSPITALIÈRE & UMC';
          subtitleText = 'Accès clinique complet : CAT urgences, scores & pharmacopée ($daysRemaining jours restants)';
          break;
        case SubscriptionTier.free:
          gradientColors = const [Color(0xFF334155), Color(0xFF475569), Color(0xFF64748B)];
          badgeText = '⚡ PASS DÉCOUVERTE • PÉRIODE D\'ESSAI (14J)';
          subtitleText = 'Accès d\'évaluation : $daysRemaining jours restants (1er module & calculateurs)';
          break;
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;

        final badge = Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            badgeText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        );

        final textColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            badge,
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
              subtitleText,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.95),
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );

        final actionButtons = Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: isNarrow ? WrapAlignment.start : WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: gradientColors.first,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SubscriptionPaywallScreen()),
                );
              },
              icon: const Icon(Icons.star_rounded, size: 18, color: Color(0xFFF59E0B)),
              label: const Text('Gérer Offre', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white70),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: const Size(0, 32),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.switch_account_rounded, size: 14),
              label: const Text('Tester un profil', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              onPressed: () => TestAccountsSheet.show(context),
            ),
          ],
        );

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: gradientColors.first.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: isNarrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    textColumn,
                    const SizedBox(height: 16),
                    actionButtons,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: textColumn),
                    const SizedBox(width: 14),
                    actionButtons,
                  ],
                ),
        );
      },
    );
  }

  Widget _buildStatsGrid(BuildContext context, SubscriptionTier tier, bool isExpired) {
    // Tailored stats according to user tier & access
    final List<Widget> cards = [];

    if (tier == SubscriptionTier.residentElite && !isExpired) {
      // Resident Elite: 100% focused on residency exam preparation
      cards.add(
        _buildStatCard(
          'Formation Résidanat',
          '47 Modules • 6 240 QCMs',
          'Banque complète Blida & Facultés Nationales',
          Icons.school_rounded,
          const Color(0xFF0D9488),
        ),
      );
      cards.add(
        _buildStatCard(
          'Examens & Entraînement',
          'Séries & Examens Blancs',
          'Chronométrés avec correction détaillée',
          Icons.quiz_rounded,
          AppTheme.accentCyan,
        ),
      );
      cards.add(
        _buildStatCard(
          'Cours PDF & Fiches',
          '1 205 Cours Officiels',
          'Lecture sécurisée & exports Anki',
          Icons.menu_book_rounded,
          const Color(0xFF2563EB),
        ),
      );
    } else if (tier == SubscriptionTier.clinicalPro && !isExpired) {
      // Clinique Pro: 100% focused on clinical & emergency practice
      cards.add(
        _buildStatCard(
          'Pratique Clinique',
          'Conduites à Tenir (CAT)',
          'Arbres décisionnels & consensus MSPRH',
          Icons.emergency_rounded,
          const Color(0xFF0284C7),
        ),
      );
      cards.add(
        _buildStatCard(
          'Urgences & DCI Algérie',
          'Pharmacopée Saidal / IPA',
          'Posologies d\'urgence & débits PSE',
          Icons.medication_liquid_rounded,
          const Color(0xFF10B981),
        ),
      );
      cards.add(
        _buildStatCard(
          'Scores Cliniques & Tri',
          'Glasgow, Wells, qSOFA',
          'Calculateurs au lit du malade',
          Icons.calculate_rounded,
          const Color(0xFFF59E0B),
        ),
      );
    } else {
      // All-Access VIP or Free Trial or Expired: comprehensive medical suite
      cards.add(
        _buildStatCard(
          'Formation Résidanat',
          '47 Modules • 6 240 QCMs',
          isExpired ? 'Accès suspendu • Renouveler' : 'Banque complète Blida & National',
          Icons.school_rounded,
          isExpired ? Colors.grey : AppTheme.primaryTeal,
        ),
      );
      cards.add(
        _buildStatCard(
          'Pratique Clinique',
          '18+ CAT & Protocoles',
          isExpired ? 'Accès suspendu • Renouveler' : 'Arbres décisionnels d\'urgence',
          Icons.emergency_rounded,
          isExpired ? Colors.grey : const Color(0xFFEF4444),
        ),
      );
      cards.add(
        _buildStatCard(
          'Calculateurs & Outils',
          'Scores, Labs & Normes',
          'Calcul instantané au lit du malade',
          Icons.calculate_rounded,
          isExpired ? Colors.grey : AppTheme.accentCyan,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;

        if (isMobile) {
          return Column(
            children: [
              for (int i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                cards[i],
              ],
            ],
          );
        }

        return Row(
          children: [
            for (int i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(width: 14),
              Expanded(child: cards[i]),
            ],
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

  Widget _buildClinicalTipCard(BuildContext context, SubscriptionTier tier, bool isSubscriptionActive) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasResidentAccess =
        (tier == SubscriptionTier.residentElite || tier == SubscriptionTier.allAccess) && isSubscriptionActive;

    return FutureBuilder<Map<String, dynamic>?>(
      future: SupabaseService.fetchLatestDailyPearl(),
      builder: (context, snapshot) {
        final pearl = snapshot.data;
        final title = pearl?['title'] ?? 'Perle Clinique du Jour : Décompensation Acido-Cétosique';
        final courseName = pearl?['course_name'] as String?;
        final moduleName = pearl?['module_name'] as String?;
        final pearlText = pearl?['pearl_text'] ??
            'Règle vitale : Ne JAMAIS débuter l\'insuline si la kaliémie initiale est < 3,3 mmol/L. L\'insuline provoque une entrée massive de potassium dans les cellules et risque d\'entraîner un arrêt cardiaque en hypokaliémie foudroyante.';
        final vitalRule = pearl?['vital_rule'] as String?;
        final examTrap = pearl?['exam_trap'] as String?;

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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.accentCyan),
                            ),
                          ),
                          if (moduleName != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryTeal.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                moduleName,
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.primaryTeal),
                              ),
                            ),
                        ],
                      ),
                      if (courseName != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          '📖 Cours : $courseName',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        pearlText,
                        style: TextStyle(fontSize: 13, height: 1.4, color: Theme.of(context).textTheme.bodyMedium?.color),
                      ),
                      if (vitalRule != null && vitalRule.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFD97706)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  vitalRule,
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (examTrap != null && examTrap.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        if (hasResidentAccess)
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.school_rounded, size: 16, color: Color(0xFFDC2626)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    examTrap,
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFFB91C1C)),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          LayoutBuilder(
                            builder: (context, box) {
                              final isCompact = box.maxWidth < 450;
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF9333EA).withValues(alpha: 0.3)),
                                ),
                                child: isCompact
                                    ? Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Icon(Icons.lock_rounded, size: 16, color: Color(0xFF9333EA)),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  '🎯 Piège de Concours Résidanat masqué • Réservé aux Pass Résident Élite & All-Access',
                                                  style: TextStyle(
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w600,
                                                    color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: TextButton.icon(
                                              onPressed: () {
                                                Navigator.of(context).push(
                                                  MaterialPageRoute(builder: (_) => const SubscriptionPaywallScreen()),
                                                );
                                              },
                                              style: TextButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                minimumSize: Size.zero,
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                foregroundColor: const Color(0xFF9333EA),
                                              ),
                                              icon: const Icon(Icons.lock_open_rounded, size: 14),
                                              label: const Text('Débloquer', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5)),
                                            ),
                                          ),
                                        ],
                                      )
                                    : Row(
                                        children: [
                                          const Icon(Icons.lock_rounded, size: 16, color: Color(0xFF9333EA)),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              '🎯 Piège de Concours Résidanat masqué • Réservé aux Pass Résident Élite & All-Access',
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w600,
                                                color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          TextButton(
                                            onPressed: () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(builder: (_) => const SubscriptionPaywallScreen()),
                                              );
                                            },
                                            style: TextButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              minimumSize: Size.zero,
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              foregroundColor: const Color(0xFF9333EA),
                                            ),
                                            child: const Text('Débloquer', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5)),
                                          ),
                                        ],
                                      ),
                              );
                            },
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickAccessCards(BuildContext context, SubscriptionTier tier, bool isExpired) {
    if (tier == SubscriptionTier.residentElite && !isExpired) {
      // Resident Elite: 100% residency exam cards
      return Column(
        children: [
          ListTile(
            tileColor: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Theme.of(context).dividerColor),
            ),
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFCCFBF1),
              child: Icon(Icons.school_rounded, color: Color(0xFF0D9488)),
            ),
            title: const Text('Entraînement QCM : Cardiologie & HTA', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            subtitle: const Text('Reprendre la session : 340 questions classées • Annales Blida 2024'),
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
              backgroundColor: Color(0xFFEDE9FE),
              child: Icon(Icons.timer_rounded, color: Color(0xFF8B5CF6)),
            ),
            title: const Text('Examen Blanc Chronométré : Concours National', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            subtitle: const Text('Épreuve type 100 questions multi-spécialités • Calcul de note en temps réel'),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Accédez à l\'onglet Résidanat pour lancer un examen blanc.')),
              );
            },
          ),
        ],
      );
    } else if (tier == SubscriptionTier.clinicalPro && !isExpired) {
      // Clinique Pro: 100% clinical and emergency hospital cards
      return Column(
        children: [
          ListTile(
            tileColor: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Theme.of(context).dividerColor),
            ),
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFFEE2E2),
              child: Icon(Icons.emergency_rounded, color: Color(0xFFEF4444)),
            ),
            title: const Text('CAT Urgence : Prise en charge SCA ST+ (IDM)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            subtitle: const Text('Arbre décisionnel reperfusion < 120 min • Posologies antithrombotiques'),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Accédez à l\'onglet Pratique Clinique pour consulter le protocole.')),
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
              backgroundColor: Color(0xFFE0F2FE),
              child: Icon(Icons.medication_rounded, color: Color(0xFF0284C7)),
            ),
            title: const Text('Mémento DCI Algérie : Adrénaline & Sérums IPA', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            subtitle: const Text('Recherche instantanée • Posologies d\'urgence et protocoles Saidal / IPA'),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Consultez l\'onglet Urgences & DCI dans Pratique Clinique.')),
              );
            },
          ),
        ],
      );
    }

    // All-Access VIP or Free Trial or Expired: General access cards
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
