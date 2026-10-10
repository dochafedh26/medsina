import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_event.dart';
import '../../auth/bloc/auth_state.dart';

class SubscriptionPaywallScreen extends StatefulWidget {
  const SubscriptionPaywallScreen({super.key});

  @override
  State<SubscriptionPaywallScreen> createState() => _SubscriptionPaywallScreenState();
}

class _SubscriptionPaywallScreenState extends State<SubscriptionPaywallScreen> {
  final TextEditingController _licenseController = TextEditingController();

  @override
  void dispose() {
    _licenseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state.successMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF16A34A),
              content: Text(state.successMessage!),
            ),
          );
        } else if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFFDC2626),
              content: Text(state.errorMessage!),
            ),
          );
        }
      },
      builder: (context, state) {
        final currentTier = state.user?.tier ?? SubscriptionTier.free;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Plans d\'Abonnement Medsina'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Header
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryTeal.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.workspace_premium_rounded, size: 36, color: AppTheme.primaryTeal),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Choisissez la Formule Adaptée à Vos Ambitions',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Plateforme SaaS médicale tout-en-un • Accès sur Mobile (APK), Windows & Web',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Activation via Clé de Licence Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.accentCyan.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.accentCyan.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.vpn_key_rounded, size: 20, color: AppTheme.accentCyan),
                        SizedBox(width: 8),
                        Text(
                          'Vous avez déjà une clé de licence ?',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Saisissez votre code d\'activation d\'établissement ou de partenaire pour débloquer votre accès (Ex: MEDSINA-2027-VIP).',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _licenseController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              hintText: 'Ex: MEDSINA-2027-VIP',
                              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () {
                            if (_licenseController.text.trim().isNotEmpty) {
                              context.read<AuthBloc>().add(
                                    ActivateLicenseKeyEvent(licenseKey: _licenseController.text.trim()),
                                  );
                            }
                          },
                          child: const Text('Activer'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // 4 Tier Cards
              _buildPlanCard(
                context,
                tier: SubscriptionTier.allAccess,
                title: 'Medsina All-Access (VIP)',
                badge: 'RECOMMANDÉ • SUITE COMPLÈTE',
                price: '20 000 DZD / an (ou 2 500 DZD / mois)',
                color: const Color(0xFF8B5CF6),
                features: [
                  'Accès illimité aux 47 modules du Résidanat Blida & National',
                  'Banque complète de 6 240+ QCMs avec corrigés détaillés',
                  'Téléchargement de TOUS les supports officiels de cours en PDF',
                  'Accès complet au volet Pratique Clinique (CAT, protocoles d\'urgence)',
                  'Tous les calculateurs médicaux (Glasgow, Wells, Cockcroft)',
                  'Exports illimités vers Anki TSV et PDF imprimable sans watermark',
                  'Mode hors-ligne complet sur PC, Mobile et Web',
                ],
                isCurrent: currentTier == SubscriptionTier.allAccess,
              ),
              const SizedBox(height: 16),

              _buildPlanCard(
                context,
                tier: SubscriptionTier.residentElite,
                title: 'Pass Résident Élite',
                badge: 'SPÉCIAL CONCOURS',
                price: '15 000 DZD / an (ou 1 800 DZD / mois)',
                color: AppTheme.primaryTeal,
                features: [
                  'Les 47 modules officiels de préparation au Résidanat',
                  'Simulateur d\'examens blancs chronométrés',
                  'Téléchargement des cours PDF officiels',
                  'Exports Anki et PDF',
                  'CAT d\'urgences essentielles',
                ],
                isCurrent: currentTier == SubscriptionTier.residentElite,
              ),
              const SizedBox(height: 16),

              _buildPlanCard(
                context,
                tier: SubscriptionTier.clinicalPro,
                title: 'Pass Clinique Pro',
                badge: 'INTERNES & PRATICIENS',
                price: '10 000 DZD / an (ou 1 200 DZD / mois)',
                color: AppTheme.accentCyan,
                features: [
                  'Toutes les Conduites à Tenir (CAT) par spécialité',
                  'Arbres décisionnels et protocoles d\'urgence vitale',
                  'Tous les scores et calculateurs médicaux',
                  'Mémento de garde hospitalière et fiches réflexes',
                  'Normes de laboratoire complètes avec interprétations',
                ],
                isCurrent: currentTier == SubscriptionTier.clinicalPro,
              ),
              const SizedBox(height: 16),

              _buildPlanCard(
                context,
                tier: SubscriptionTier.free,
                title: 'Pass Découverte',
                badge: 'GRATUIT',
                price: '0 DZD',
                color: Colors.grey.shade600,
                features: [
                  '2 modules d\'initiation au résidanat (50 QCMs)',
                  'Scores médicaux de base',
                  'Consultation des cours PDF en ligne',
                ],
                isCurrent: currentTier == SubscriptionTier.free,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlanCard(
    BuildContext context, {
    required SubscriptionTier tier,
    required String title,
    required String badge,
    required String price,
    required Color color,
    required List<String> features,
    required bool isCurrent,
  }) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isCurrent ? color : color.withValues(alpha: 0.3), width: isCurrent ? 2.5 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                  child: Text(badge, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color)),
                ),
                const Spacer(),
                if (isCurrent)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
                    child: const Text('PLAN ACTIF', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(price, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 8),
            ...features.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 16, color: color),
                      const SizedBox(width: 8),
                      Expanded(child: Text(f, style: const TextStyle(fontSize: 12, height: 1.3))),
                    ],
                  ),
                )),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: isCurrent
                  ? OutlinedButton(
                      onPressed: null,
                      child: const Text('Votre Formule Actuelle'),
                    )
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: color),
                      onPressed: () {
                        context.read<AuthBloc>().add(UpgradeTierEvent(newTier: tier));
                      },
                      child: Text('Sélectionner $title'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
