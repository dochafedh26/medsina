import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/license_key_formatter.dart';
import '../../../core/widgets/medsina_logo.dart';
import '../../admin/bloc/admin_bloc.dart';
import '../../admin/models/admin_models.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_event.dart';
import '../../auth/bloc/auth_state.dart';
import '../../auth/models/user_model.dart';
import '../models/subscription_duration.dart';
import 'referral_screen.dart';

class SubscriptionPaywallScreen extends StatefulWidget {
  const SubscriptionPaywallScreen({super.key});

  @override
  State<SubscriptionPaywallScreen> createState() => _SubscriptionPaywallScreenState();
}

class _SubscriptionPaywallScreenState extends State<SubscriptionPaywallScreen> {
  final TextEditingController _licenseController = TextEditingController();
  List<SubscriptionPlanItem> _fetchedPlans = [];
  SubscriptionDuration _selectedDuration = SubscriptionDuration.oneYear;
  Map<String, String> _paymentSettings = {};

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    try {
      final raw = await SupabaseService.fetchSubscriptionPlans();
      final settings = await SupabaseService.fetchPaymentSettings();
      if (mounted) {
        setState(() {
          if (raw.isNotEmpty) {
            _fetchedPlans = raw.map((m) => SubscriptionPlanItem.fromJson(m)).toList();
          }
          _paymentSettings = settings;
        });
      }
    } catch (e) {
      debugPrint('Error loading plans on paywall screen: $e');
    }
  }

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
        final adminPlans = context.watch<AdminBloc>().state.plans;

        SubscriptionPlanItem? getPlan(String id) {
          try {
            if (_fetchedPlans.isNotEmpty) {
              return _fetchedPlans.firstWhere((p) => p.id == id);
            }
            return adminPlans.firstWhere((p) => p.id == id);
          } catch (_) {
            try {
              final def = SupabaseService.defaultPlans.firstWhere((p) => p['id'] == id);
              return SubscriptionPlanItem.fromJson(def);
            } catch (_) {
              return null;
            }
          }
        }

        final allAccessPlan = getPlan('all_access');
        final residentElitePlan = getPlan('resident_elite');
        final clinicalProPlan = getPlan('clinical_pro');
        final etudiantPlan = getPlan('etudiant');

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
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryTeal.withValues(alpha: 0.2),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const MedsinaLogo.icon(size: 46),
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
                      'Saisissez votre clé de licence sécurisée pour débloquer immédiatement votre abonnement (Format : MSN27-XXXXX-XXXXX-XXXXX-XXXXX).',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _licenseController,
                            textCapitalization: TextCapitalization.characters,
                            inputFormatters: [LicenseKeyInputFormatter()],
                            decoration: const InputDecoration(
                              hintText: 'MSN27-XXXXX-XXXXX-XXXXX-XXXXX',
                              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () {
                            final rawKey = _licenseController.text.trim();
                            if (rawKey.isNotEmpty) {
                              context.read<AuthBloc>().add(
                                    ActivateLicenseKeyEvent(licenseKey: rawKey),
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
              const SizedBox(height: 16),

              // Ambassador & Referral Gamification Banner
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F766E), Color(0xFF0D9488)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0D9488).withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.group_add_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Programme Parrainage Confrères 🤝',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Obtenez du VIP gratuit (+7 jours & 50 requêtes IA par confrère invité) !',
                            style: TextStyle(fontSize: 11, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF0F766E),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: const Size(0, 32),
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ReferralScreen()),
                        );
                      },
                      child: const Text('Parrainer ➔', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),

              // EDAHABIA & CIB (Chargily Pay) Instant Option Card
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.credit_card_rounded, color: Color(0xFF0284C7), size: 24),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('Carte EDAHABIA & CIB', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                              SizedBox(width: 6),
                              Text('⚡ Instantané', style: TextStyle(color: Color(0xFF0284C7), fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          SizedBox(height: 3),
                          Text('Paiement sécurisé en ligne via Chargily Pay sans déplacement.', style: TextStyle(fontSize: 11.5, color: Colors.grey)),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      onPressed: () => _showChargilyPayDialog(context, state.user, initialDuration: _selectedDuration),
                      child: const Text('Payer par Carte ➔', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),

              // BaridiMob & CCP Payment Option Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.payment_rounded, color: Color(0xFF16A34A), size: 24),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Paiement par BaridiMob ou CCP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                          SizedBox(height: 3),
                          Text('Réglez et envoyez votre numéro de reçu pour activation rapide.', style: TextStyle(fontSize: 11.5, color: Colors.grey)),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      onPressed: () => _showPaymentSubmissionDialog(context, state.user, initialDuration: _selectedDuration),
                      child: const Text('Payer ➔', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Duration Selector Segmented Bar
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_month_rounded, size: 18, color: AppTheme.primaryTeal),
                      const SizedBox(width: 8),
                      const Text(
                        'Choisissez votre durée d\'abonnement :',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                      const Spacer(),
                      if (_selectedDuration == SubscriptionDuration.twoYears)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.4)),
                          ),
                          child: const Text(
                            '-20% ÉCONOMISÉS',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF7C3AED)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: SubscriptionDuration.values.map((d) {
                        final isSelected = _selectedDuration == d;
                        final isTwoYears = d == SubscriptionDuration.twoYears;
                        final isOneYear = d == SubscriptionDuration.oneYear;
                        final primaryColor = isTwoYears
                            ? const Color(0xFF8B5CF6)
                            : (isOneYear ? AppTheme.primaryTeal : const Color(0xFF0284C7));

                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => setState(() => _selectedDuration = d),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? primaryColor
                                    : (Theme.of(context).brightness == Brightness.dark
                                        ? const Color(0xFF1E293B)
                                        : Colors.white),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? primaryColor
                                      : (isTwoYears
                                          ? const Color(0xFF8B5CF6).withValues(alpha: 0.5)
                                          : Colors.grey.shade300),
                                  width: isSelected || isTwoYears ? 1.5 : 1,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: primaryColor.withValues(alpha: 0.35),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    d.label,
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87),
                                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (d.badge != null) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? Colors.white.withValues(alpha: 0.25)
                                            : (isTwoYears
                                                ? const Color(0xFF8B5CF6).withValues(alpha: 0.15)
                                                : const Color(0xFF16A34A).withValues(alpha: 0.15)),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        d.badge!,
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: isSelected
                                              ? Colors.white
                                              : (isTwoYears ? const Color(0xFF7C3AED) : const Color(0xFF16A34A)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  if (_selectedDuration == SubscriptionDuration.twoYears) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.stars_rounded, color: Color(0xFF8B5CF6), size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Remise spéciale 2 ans appliquée : -20% de réduction immédiate sur tous les abonnements !',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF6D28D9)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 18),

              // 4 Tier Cards
              _buildPlanCard(
                context,
                user: state.user,
                tier: SubscriptionTier.allAccess,
                title: allAccessPlan?.name ?? 'Medsina All-Access (VIP)',
                badge: allAccessPlan?.badge ?? 'RECOMMANDÉ • SUITE COMPLÈTE',
                color: const Color(0xFF8B5CF6),
                planItem: allAccessPlan,
                duration: _selectedDuration,
                features: allAccessPlan?.features.isNotEmpty == true
                    ? allAccessPlan!.features
                    : [
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
                user: state.user,
                tier: SubscriptionTier.residentElite,
                title: residentElitePlan?.name ?? 'Pass Résident Élite',
                badge: residentElitePlan?.badge ?? 'SPÉCIAL CONCOURS',
                color: AppTheme.primaryTeal,
                planItem: residentElitePlan,
                duration: _selectedDuration,
                features: residentElitePlan?.features.isNotEmpty == true
                    ? residentElitePlan!.features
                    : [
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
                user: state.user,
                tier: SubscriptionTier.clinicalPro,
                title: clinicalProPlan?.name ?? 'Pass Clinique Pro',
                badge: clinicalProPlan?.badge ?? 'INTERNES & PRATICIENS',
                color: AppTheme.accentCyan,
                planItem: clinicalProPlan,
                duration: _selectedDuration,
                features: clinicalProPlan?.features.isNotEmpty == true
                    ? clinicalProPlan!.features
                    : [
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
                user: state.user,
                tier: SubscriptionTier.etudiant,
                title: etudiantPlan?.name ?? 'Pass Étudiant (1ère - 6ème)',
                badge: etudiantPlan?.badge ?? 'CURSUS UNIVERSITAIRE',
                color: const Color(0xFF2563EB),
                planItem: etudiantPlan,
                duration: _selectedDuration,
                features: etudiantPlan?.features.isNotEmpty == true
                    ? etudiantPlan!.features
                    : [
                        'Programme personnalisé selon votre année d\'étude (1ère à 6ème)',
                        'Banque QCMs d\'examens ultérieurs & EMD de Faculté',
                        'Exclusion des pièges hors-programme du résidanat',
                        'Fiches de cours & résumés officiels de l\'année',
                        'Mode révision semestrielle & partiels',
                      ],
                isCurrent: currentTier == SubscriptionTier.etudiant,
              ),
              const SizedBox(height: 16),
              _buildPlanCard(
                context,
                user: state.user,
                tier: SubscriptionTier.free,
                title: 'Pass Découverte',
                badge: 'GRATUIT',
                color: Colors.grey.shade600,
                planItem: null,
                duration: _selectedDuration,
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
    required UserModel? user,
    required SubscriptionTier tier,
    required String title,
    required String badge,
    required Color color,
    required List<String> features,
    required bool isCurrent,
    SubscriptionPlanItem? planItem,
    required SubscriptionDuration duration,
  }) {
    String priceText;
    String? periodSubtext;
    double savings = 0;

    if (tier == SubscriptionTier.free) {
      priceText = '0 DZD';
      periodSubtext = 'Accès Découverte Gratuit';
    } else if (planItem != null) {
      final calculated = duration.calculatePrice(planItem);
      savings = duration.calculateSavings(planItem);
      priceText = '${calculated.toStringAsFixed(0)} DZD';
      switch (duration) {
        case SubscriptionDuration.oneMonth:
          periodSubtext = 'pour 1 mois';
          break;
        case SubscriptionDuration.threeMonths:
          periodSubtext = 'pour 3 mois (soit ${(calculated / 3).toStringAsFixed(0)} DZD/mois)';
          break;
        case SubscriptionDuration.sixMonths:
          periodSubtext = 'pour 6 mois (soit ${(calculated / 6).toStringAsFixed(0)} DZD/mois)';
          break;
        case SubscriptionDuration.oneYear:
          periodSubtext = 'pour 1 an (soit ${(calculated / 12).toStringAsFixed(0)} DZD/mois)';
          break;
        case SubscriptionDuration.twoYears:
          periodSubtext = 'pour 2 ans (soit ${(calculated / 24).toStringAsFixed(0)} DZD/mois)';
          break;
      }
    } else {
      priceText = '-- DZD';
    }

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
                if (duration == SubscriptionDuration.twoYears && tier != SubscriptionTier.free) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('-20% PROMO 2 ANS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF7C3AED))),
                  ),
                ],
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
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Text(priceText, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
                if (periodSubtext != null)
                  Text(periodSubtext, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey.shade600)),
              ],
            ),
            if (savings > 0) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.savings_outlined, size: 13, color: Color(0xFF16A34A)),
                    const SizedBox(width: 4),
                    Text(
                      'Économisez ${savings.toStringAsFixed(0)} DZD ${duration == SubscriptionDuration.twoYears ? '(-20% spécial 2 ans)' : ''}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                    ),
                  ],
                ),
              ),
            ],
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
                        if (tier == SubscriptionTier.free) {
                          context.read<AuthBloc>().add(UpgradeTierEvent(newTier: tier));
                        } else {
                          _showPaymentSubmissionDialog(
                            context,
                            user,
                            initialTier: tier.id,
                            initialDuration: duration,
                          );
                        }
                      },
                      child: Text('Souscrire à $title'),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentSubmissionDialog(
    BuildContext context,
    UserModel? user, {
    String initialTier = 'all_access',
    SubscriptionDuration initialDuration = SubscriptionDuration.oneYear,
  }) {
    final availablePlans = (_fetchedPlans.isNotEmpty
            ? _fetchedPlans
            : SupabaseService.defaultPlans.map((m) => SubscriptionPlanItem.fromJson(m)).toList())
        .where((p) => p.id != 'free')
        .toList();

    String selectedTier = availablePlans.any((p) => p.id == initialTier)
        ? initialTier
        : (availablePlans.isNotEmpty ? availablePlans.first.id : 'all_access');
    SubscriptionDuration selectedDuration = initialDuration;
    String paymentMethod = 'baridimob';
    final refController = TextEditingController();

    SubscriptionPlanItem getSelectedPlanObj() {
      try {
        return availablePlans.firstWhere((p) => p.id == selectedTier);
      } catch (_) {
        return availablePlans.first;
      }
    }

    final amountController = TextEditingController(
      text: selectedDuration.calculatePrice(getSelectedPlanObj()).toStringAsFixed(0),
    );
    bool isSubmitting = false;

    PlatformFile? pickedReceiptFile;
    Uint8List? receiptBytes;
    String? receiptFileName;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.payment_rounded, color: Color(0xFF16A34A)),
              SizedBox(width: 8),
              Text('Paiement BaridiMob / CCP', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Payment Coordinates Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Coordonnées Officielles de Règlement :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF166534))),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '📱 RIP BaridiMob : ${_paymentSettings['baridimob_rip'] ?? '007999990009171614 93'}',
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF166534)),
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Copier le RIP',
                            onPressed: () {
                              final rip = _paymentSettings['baridimob_rip'] ?? '007999990009171614 93';
                              Clipboard.setData(ClipboardData(text: rip.replaceAll(' ', '')));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('RIP BaridiMob copié : $rip')),
                              );
                            },
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '🏛️ Compte CCP : ${_paymentSettings['ccp_account'] ?? '9171614 Clé 19'}',
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF166534)),
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Copier le CCP',
                            onPressed: () {
                              final ccp = _paymentSettings['ccp_account'] ?? '9171614 Clé 19';
                              Clipboard.setData(ClipboardData(text: ccp));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Compte CCP copié : $ccp')),
                              );
                            },
                          ),
                        ],
                      ),
                      Text(
                        '👤 Titulaire : ${_paymentSettings['ccp_holder'] ?? 'CHIKH TOUHAMI HAFED'}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                const Text('Formule Souscrite :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: selectedTier,
                  isExpanded: true,
                  decoration: const InputDecoration(isDense: true),
                  items: availablePlans.map((plan) {
                    final price = selectedDuration.calculatePrice(plan);
                    return DropdownMenuItem<String>(
                      value: plan.id,
                      child: Text(
                        '${plan.name} (${price.toStringAsFixed(0)} DZD)',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDlgState(() {
                        selectedTier = val;
                        final p = getSelectedPlanObj();
                        amountController.text = selectedDuration.calculatePrice(p).toStringAsFixed(0);
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),

                const Text('Durée de l\'Abonnement :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                const SizedBox(height: 6),
                DropdownButtonFormField<SubscriptionDuration>(
                  initialValue: selectedDuration,
                  isExpanded: true,
                  decoration: const InputDecoration(isDense: true),
                  items: SubscriptionDuration.values.map((d) {
                    return DropdownMenuItem<SubscriptionDuration>(
                      value: d,
                      child: Row(
                        children: [
                          Text(d.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          if (d.badge != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: d == SubscriptionDuration.twoYears
                                    ? const Color(0xFF8B5CF6).withValues(alpha: 0.15)
                                    : const Color(0xFF16A34A).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                d.badge!,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: d == SubscriptionDuration.twoYears ? const Color(0xFF7C3AED) : const Color(0xFF16A34A),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDlgState(() {
                        selectedDuration = val;
                        final p = getSelectedPlanObj();
                        amountController.text = selectedDuration.calculatePrice(p).toStringAsFixed(0);
                      });
                    }
                  },
                ),
                if (selectedDuration == SubscriptionDuration.twoYears) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.discount_rounded, size: 16, color: Color(0xFF8B5CF6)),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Remise exclusive de -20% appliquée sur l\'abonnement 2 ans !',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6D28D9)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),

                const Text('Montant à Régler (DZD) :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                const SizedBox(height: 6),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    suffixText: 'DZD',
                    prefixIcon: Icon(Icons.attach_money_rounded, size: 18),
                  ),
                ),
                const SizedBox(height: 12),

                const Text('Mode de Règlement :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: paymentMethod,
                  isExpanded: true,
                  decoration: const InputDecoration(isDense: true),
                  items: const [
                    DropdownMenuItem(value: 'baridimob', child: Text('Virement BaridiMob', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'ccp', child: Text('Versement CCP au Bureau de Poste', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'virement', child: Text('Virement Bancaire', overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (val) => setDlgState(() => paymentMethod = val ?? paymentMethod),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: refController,
                  decoration: const InputDecoration(
                    labelText: 'N° de Reçu ou Transaction BaridiMob',
                    hintText: 'Ex: TRX-2026-98124 ou N° Bordereau',
                    prefixIcon: Icon(Icons.receipt_outlined, size: 18),
                  ),
                ),
                const SizedBox(height: 12),

                // Upload Receipt Section
                const Text('Preuve de Paiement (Reçu ou Relevé) :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: pickedReceiptFile != null
                        ? const Color(0xFFF0FDF4)
                        : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: pickedReceiptFile != null ? const Color(0xFF16A34A) : Colors.grey.shade300,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (pickedReceiptFile == null) ...[
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                                icon: const Icon(Icons.upload_file_rounded, size: 18),
                                label: const Text('Scanner / Joindre Reçu (PDF ou Image)', style: TextStyle(fontSize: 12)),
                                onPressed: () async {
                                  final file = await FilePicker.pickFile(
                                    type: FileType.custom,
                                    allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
                                  );
                                  if (file != null) {
                                    final bytes = await file.readAsBytes();
                                    setDlgState(() {
                                      pickedReceiptFile = file;
                                      receiptBytes = bytes;
                                      receiptFileName = file.name;
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Formats acceptés : PDF, JPG, PNG (Max 10 Mo)',
                          style: TextStyle(fontSize: 10.5, color: Colors.grey),
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Icon(
                              receiptFileName?.toLowerCase().endsWith('.pdf') == true
                                  ? Icons.picture_as_pdf_rounded
                                  : Icons.image_rounded,
                              color: const Color(0xFF16A34A),
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    receiptFileName ?? 'Reçu sélectionné',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (receiptBytes != null && receiptBytes!.isNotEmpty)
                                    Text(
                                      '${(receiptBytes!.length / 1024).toStringAsFixed(1)} Ko',
                                      style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18, color: Colors.red),
                              tooltip: 'Supprimer ce fichier',
                              onPressed: () {
                                setDlgState(() {
                                  pickedReceiptFile = null;
                                  receiptBytes = null;
                                  receiptFileName = null;
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Une fois soumis, l\'administrateur validera votre transaction après vérification du reçu pour activer votre formule.',
                  style: TextStyle(fontSize: 10.5, color: Colors.grey),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final ref = refController.text.trim();
                      if (ref.isEmpty && pickedReceiptFile == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Veuillez renseigner le numéro de transaction ou joindre une preuve.')),
                        );
                        return;
                      }

                      setDlgState(() => isSubmitting = true);
                      final amount = double.tryParse(amountController.text) ?? selectedDuration.calculatePrice(getSelectedPlanObj());

                      String? uploadedReceiptUrl;
                      if (receiptBytes != null && receiptFileName != null) {
                        try {
                          uploadedReceiptUrl = await SupabaseService.uploadPaymentReceipt(
                            userId: user?.id ?? 'guest',
                            fileName: receiptFileName!,
                            bytes: receiptBytes!,
                          );
                        } catch (_) {}

                        if (uploadedReceiptUrl == null || uploadedReceiptUrl.isEmpty) {
                          final mime = receiptFileName!.toLowerCase().endsWith('.pdf') ? 'application/pdf' : 'image/jpeg';
                          final b64 = base64Encode(receiptBytes!);
                          uploadedReceiptUrl = 'data:$mime;base64,$b64';
                        }
                      }

                      final success = await SupabaseService.submitPaymentRequest(
                        userId: user?.id ?? '',
                        userEmail: user?.email ?? 'resident@medsina.com',
                        userName: user?.fullName ?? 'Médecin Résident',
                        tier: selectedTier,
                        durationDays: selectedDuration.days,
                        amount: amount,
                        paymentMethod: paymentMethod,
                        receiptReference: ref.isNotEmpty ? ref : (receiptFileName ?? 'Reçu numérique'),
                        receiptUrl: uploadedReceiptUrl,
                        receiptFileName: receiptFileName,
                      );

                      if (context.mounted) {
                        Navigator.pop(ctx);
                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: Color(0xFF16A34A),
                              content: Text('Preuve de paiement envoyée avec succès ! Activation après validation admin.'),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: Color(0xFFDC2626),
                              content: Text('Erreur lors de l\'envoi du paiement.'),
                            ),
                          );
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Soumettre le Paiement'),
            ),
          ],
        ),
      ),
    );
  }

  void _showChargilyPayDialog(
    BuildContext context,
    UserModel? user, {
    String initialTier = 'all_access',
    SubscriptionDuration initialDuration = SubscriptionDuration.oneYear,
  }) {
    final availablePlans = (_fetchedPlans.isNotEmpty
            ? _fetchedPlans
            : SupabaseService.defaultPlans.map((m) => SubscriptionPlanItem.fromJson(m)).toList())
        .where((p) => p.id != 'free')
        .toList();

    String selectedTier = availablePlans.any((p) => p.id == initialTier)
        ? initialTier
        : (availablePlans.isNotEmpty ? availablePlans.first.id : 'all_access');
    SubscriptionDuration selectedDuration = initialDuration;

    SubscriptionPlanItem getSelectedPlanObj() {
      try {
        return availablePlans.firstWhere((p) => p.id == selectedTier);
      } catch (_) {
        return availablePlans.first;
      }
    }

    bool isProcessingChargily = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final plan = getSelectedPlanObj();
          final amount = selectedDuration.calculatePrice(plan);
          final whatsapp = _paymentSettings['support_whatsapp'] ?? '+213770000000';

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.credit_card_rounded, color: Color(0xFF0284C7)),
                SizedBox(width: 8),
                Text('Paiement Carte EDAHABIA / CIB', style: TextStyle(fontSize: 15.5)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.verified_user_rounded, color: Color(0xFF0284C7), size: 22),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Paiement direct sécurisé par SATIM & GIE Monétique via la passerelle Chargily Pay v2.',
                            style: TextStyle(fontSize: 11.5, color: Color(0xFF0369A1), fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text('Formule Choisie :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedTier,
                    isExpanded: true,
                    decoration: const InputDecoration(isDense: true),
                    items: availablePlans.map((p) {
                      return DropdownMenuItem<String>(
                        value: p.id,
                        child: Text(p.name, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDlgState(() => selectedTier = val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  const Text('Durée d\'Abonnement :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<SubscriptionDuration>(
                    initialValue: selectedDuration,
                    isExpanded: true,
                    decoration: const InputDecoration(isDense: true),
                    items: SubscriptionDuration.values.map((d) {
                      return DropdownMenuItem<SubscriptionDuration>(
                        value: d,
                        child: Text(d.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDlgState(() => selectedDuration = val);
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total à régler :', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          '${amount.toStringAsFixed(0)} DZD',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0284C7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'En cliquant sur "Confirmer le Paiement", vous serez redirigé vers la page sécurisée de paiement par carte EDAHABIA ou CIB.',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isProcessingChargily ? null : () => Navigator.pop(ctx),
                child: const Text('Annuler'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                ),
                icon: isProcessingChargily
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.lock_rounded, size: 16),
                label: Text(isProcessingChargily ? 'Connexion SATIM...' : 'Payer par EDAHABIA / CIB'),
                onPressed: isProcessingChargily
                    ? null
                    : () async {
                        setDlgState(() => isProcessingChargily = true);
                        final res = await SupabaseService.createChargilyCheckout(
                          amount: amount,
                          tier: selectedTier,
                          durationDays: selectedDuration.days,
                          userId: user?.id ?? 'guest',
                          userEmail: user?.email ?? 'resident@medsina.com',
                          userName: user?.fullName ?? 'Médecin Résident',
                        );

                        if (context.mounted) {
                          setDlgState(() => isProcessingChargily = false);
                          Navigator.pop(ctx);
                          if (res['success'] == true && res['checkout_url'] != null) {
                            launchUrl(
                              Uri.parse(res['checkout_url']!),
                              mode: LaunchMode.externalApplication,
                            );
                          } else {
                            final text = Uri.encodeComponent(
                              'Salam ! Je souhaite régler mon abonnement Medsina par carte EDAHABIA / CIB.\n'
                              'Formule : ${plan.name} (${selectedDuration.label})\n'
                              'Montant : ${amount.toStringAsFixed(0)} DZD\n'
                              'Email : ${user?.email ?? ""}\n'
                              'Merci de m\'envoyer le lien de paiement direct !',
                            );
                            final waUrl = 'https://wa.me/${whatsapp.replaceAll(RegExp(r"[^0-9]"), "")}?text=$text';
                            launchUrl(Uri.parse(waUrl), mode: LaunchMode.externalApplication);
                          }
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
  }
}

