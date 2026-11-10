import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../subscription/presentation/subscription_paywall_screen.dart';

class MedsinaSynapseScreen extends StatelessWidget {
  final bool isEmbedded;
  const MedsinaSynapseScreen({super.key, this.isEmbedded = false});

  static const String synapseUrl = 'https://medsina.medevsync.com/synapse/';

  Future<void> _launchSimulation(BuildContext context) async {
    final user = context.read<AuthBloc>().state.user;
    final bool hasAccess = user != null &&
        (user.isAdmin || user.tier.canAccessSynapse()) &&
        user.isSubscriptionActive;

    if (!hasAccess) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SubscriptionPaywallScreen()),
      );
      return;
    }

    final token = SupabaseService.client.auth.currentSession?.accessToken;
    final finalUrl = (token != null && token.isNotEmpty)
        ? '$synapseUrl?token=${Uri.encodeComponent(token)}'
        : synapseUrl;

    final uri = Uri.parse(finalUrl);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible d\'ouvrir le simulateur Medsina Synapse sur https://medsina.medevsync.com/synapse'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du lancement : $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = context.watch<AuthBloc>().state.user;
    final bool isAuthenticated = user != null;
    final bool hasAccess = isAuthenticated &&
        (user.isAdmin || user.tier.canAccessSynapse()) &&
        user.isSubscriptionActive;

    final casesList = [
      {
        'title': 'SCA ST+ (Infarctus du Myocarde)',
        'patient': 'Ahmed Benkhedda, 54 ans · Chauffeur de taxi',
        'specialty': 'Cardiologie & UMC',
        'desc': 'Prise en charge de la reperfusion en Algérie : angioplastie primaire vs thrombolyse (Ténectéplase) selon délai d\'accès.',
        'color': const Color(0xFFEF4444),
        'icon': Icons.favorite_rounded,
      },
      {
        'title': 'Envenimation Scorpionique (Classe III)',
        'patient': 'Sofiane Chaoui, 29 ans · Djelfa / Biskra',
        'specialty': 'Toxicologie & Réanimation',
        'desc': 'Protocole national IPA : Sérum Anti-Scorpionique, support Dobutamine pour le choc cardiogénique, éviction du garrot.',
        'color': const Color(0xFFF59E0B),
        'icon': Icons.warning_amber_rounded,
      },
      {
        'title': 'Kyste Hydatique du Foie Rompu',
        'patient': 'Fatima Zohra, 48 ans · Médéa',
        'specialty': 'Gastro-Hépatologie',
        'desc': 'Rupture kysto-biliaire, triade de Villard, classification de Gharbi (Types I à V), chirurgie sous Albendazole (Zentel).',
        'color': const Color(0xFF10B981),
        'icon': Icons.water_drop_rounded,
      },
      {
        'title': 'Pleurésie Tuberculeuse',
        'patient': 'Yacine Bouzid, 23 ans · Cité Universitaire Alger',
        'specialty': 'Pneumo-Phtisiologie',
        'desc': 'Exsudat lymphocytaire, GeneXpert MTB/RIF positif, Programme National Antituberculeux (PNT Algérie : 2RHZE / 4RH).',
        'color': const Color(0xFF06B6D4),
        'icon': Icons.air_rounded,
      },
      {
        'title': 'Brucellose Aiguë Septicémique',
        'patient': 'Abdelkader Belhadj, 36 ans · Éleveur à Sétif',
        'specialty': 'Maladies Infectieuses',
        'desc': 'Fièvre ondulante sudoro-algique, notion de lait cru / Klila, Wright / Rose Bengale, Doxycycline + Rifampicine 6 semaines.',
        'color': const Color(0xFF8B5CF6),
        'icon': Icons.bug_report_rounded,
      },
      {
        'title': 'Rétrécissement Mitral Rhumatismal (RAA)',
        'patient': 'Meriem Khellil, 27 ans · Tizi Ouzou',
        'specialty': 'Cardiologie & Valvulopathies',
        'desc': 'Séquelle de RAA, décompensation en FA, anticoagulation Sintrom (AOD interdits), Extencilline toutes les 3 semaines.',
        'color': const Color(0xFFEC4899),
        'icon': Icons.monitor_heart_rounded,
      },
    ];

    final content = SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Paywall Locked Strip if user is not authorized
          if (!hasAccess)
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber.shade600.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lock_rounded, color: Colors.amber.shade700, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'INTÉGRÉ AUX PASS CLINIQUE PRO & RÉSIDENT ÉLITE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.amber.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'L\'accès complet aux simulations ECOS (interrogatoire dynamique IA, constantes en temps réel et chariot d\'urgences réelles en Algérie) est réservé aux formules professionnelles de Medsina.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey.shade300 : const Color(0xFF78350F),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.star_rounded, size: 18),
                    label: const Text('Débloquer avec le Pass Clinique Pro ➔', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SubscriptionPaywallScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),

          // Hero Banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF0F172A), const Color(0xFF134E4A)]
                    : [const Color(0xFFF0FDFA), const Color(0xFFCCFBF1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.primaryTeal.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryTeal,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'NOUVEAU · MEDSINA SYNAPSE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.bolt_rounded, color: Colors.amber, size: 20),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Simulateur Clinique Immersif & Préparation Résidanat',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Prenez en charge des patients virtuels aux UMC algériennes : moniteur ECG en temps réel, interrogatoire interactif par IA (Gemini 3.8 Flash), bilans biologiques, imageries et chronomètre de station ECOS (10 min).',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hasAccess ? AppTheme.primaryTeal : const Color(0xFFD97706),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    icon: Icon(hasAccess ? Icons.play_circle_fill_rounded : Icons.lock_open_rounded, size: 22),
                    label: Text(
                      hasAccess ? 'Lancer la Station Medsina Synapse (ECOS)' : 'Débloquer l\'Accès au Simulateur (Pass Pro / Élite)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    onPressed: () => _launchSimulation(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Features Checklist Strip
          Row(
            children: [
              _buildFeatureBadge(Icons.timeline_rounded, 'Moniteur ECG Live'),
              const SizedBox(width: 8),
              _buildFeatureBadge(Icons.timer_outlined, 'Chrono ECOS 10m'),
              const SizedBox(width: 8),
              _buildFeatureBadge(Icons.school_rounded, 'Flashcards SM-2'),
            ],
          ),
          const SizedBox(height: 28),

          // Cases Section Title
          Row(
            children: [
              const Icon(Icons.local_hospital_rounded, color: AppTheme.primaryTeal, size: 22),
              const SizedBox(width: 8),
              const Text(
                'Cas Cliniques Réels Disponibles (Algérie)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryTeal.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${casesList.length} stations',
                  style: const TextStyle(
                    color: AppTheme.primaryTeal,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Cases Grid / List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: casesList.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final c = casesList[index];
              final color = c['color'] as Color;

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(c['icon'] as IconData, color: color, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c['title'] as String,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                c['patient'] as String,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            c['specialty'] as String,
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      c['desc'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey.shade300 : const Color(0xFF475569),
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.primaryTeal,
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                        label: Text(hasAccess ? 'Entrer dans la Station' : 'Débloquer (Pass Pro)'),
                        onPressed: () => _launchSimulation(context),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );

    if (isEmbedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Medsina Synapse · ECOS'),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Lancer dans le navigateur',
            icon: const Icon(Icons.open_in_browser_rounded),
            onPressed: () => _launchSimulation(context),
          ),
        ],
      ),
      body: content,
    );
  }

  Widget _buildFeatureBadge(IconData icon, String text) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: AppTheme.primaryTeal.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppTheme.primaryTeal.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: AppTheme.primaryTeal),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryTeal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
