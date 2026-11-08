import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';

class MedsinaSynapseScreen extends StatelessWidget {
  final bool isEmbedded;
  const MedsinaSynapseScreen({super.key, this.isEmbedded = false});

  static const String synapseUrl = 'https://medsina.medevsync.com/synapse';

  Future<void> _launchSimulation(BuildContext context) async {
    final uri = Uri.parse(synapseUrl);
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
        'title': 'Brucellose Aiguë Sudoro-Algique',
        'patient': 'Abdelkader Belhadj, 36 ans · Sétif',
        'specialty': 'Maladies Infectieuses',
        'desc': 'Consommation de lait cru / Klila, fièvre ondulante, sérodiagnostic de Wright, Doxycycline + Rifampicine pendant 6 semaines.',
        'color': const Color(0xFF8B5CF6),
        'icon': Icons.coronavirus_rounded,
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
                        backgroundColor: AppTheme.primaryTeal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      icon: const Icon(Icons.play_circle_fill_rounded, size: 22),
                      label: const Text(
                        'Ouvrir le Simulateur Medsina Synapse',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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

            // Section: Cas Cliniques Pratique Algérie
            const Text(
              'Cas Cliniques UMC Disponibles',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Scénarios progressifs conformes à l\'épidémiologie et aux consensus nationaux',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 14),

            ...casesList.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    elevation: 0.5,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: (c['color'] as Color).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(c['icon'] as IconData, color: c['color'] as Color, size: 22),
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
                                        c['title'] as String,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      c['specialty'] as String,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: c['color'] as Color,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  c['patient'] as String,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  c['desc'] as String,
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.35,
                                    color: isDark ? Colors.white70 : Colors.grey.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )),
          ],
        ),
      );

    if (isEmbedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Medsina Synapse',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              'Simulateur ECOS & Cas Cliniques (Pratique Algérie)',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
      body: content,
    );
  }

  Widget _buildFeatureBadge(IconData icon, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: AppTheme.primaryTeal.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: AppTheme.primaryTeal),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
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
