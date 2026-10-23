import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/network/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/bloc/auth_bloc.dart';

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = true;
  bool _isClaiming = false;
  bool _isRedeeming = false;

  String _referralCode = '';
  int _freeCount = 0;
  final int _freeCap = 5;
  int _freeAiCreditsEarned = 0;
  int _annualPaidCount = 0;
  final int _annualTarget = 5;
  bool _annualUnlocked = false;
  int _sixMonthsPaidCount = 0;
  final int _sixMonthsTarget = 10;
  bool _sixMonthsUnlocked = false;
  int _totalPaidCount = 0;
  int _totalReferred = 0;
  int _bonusDaysEarned = 0;
  int _bonusCreditsEarned = 0;
  bool _hasClaimedCode = false;

  @override
  void initState() {
    super.initState();
    _loadReferralStats();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadReferralStats() async {
    setState(() => _isLoading = true);
    final user = context.read<AuthBloc>().state.user;
    final fallbackCode = 'DR-${user?.id.replaceAll('-', '').substring(0, 6).toUpperCase() ?? 'MSN27'}';

    try {
      final stats = await SupabaseService.fetchUserReferralStats(user?.id ?? '');
      if (mounted) {
        setState(() {
          _referralCode = (stats['referral_code'] ?? fallbackCode).toString().toUpperCase();
          _freeCount = (stats['free_count'] ?? 0) as int;
          _freeAiCreditsEarned = (stats['free_ai_credits_earned'] ?? (_freeCount * 10)) as int;
          _annualPaidCount = (stats['annual_paid_count'] ?? 0) as int;
          _annualUnlocked = (stats['annual_unlocked'] ?? (_annualPaidCount >= 5)) as bool;
          _sixMonthsPaidCount = (stats['six_months_paid_count'] ?? 0) as int;
          _sixMonthsUnlocked = (stats['six_months_unlocked'] ?? (_sixMonthsPaidCount >= 10)) as bool;
          _totalPaidCount = (stats['total_paid_count'] ?? 0) as int;
          _totalReferred = (stats['total_referred'] ?? (_totalPaidCount + _freeCount)) as int;
          _bonusDaysEarned = (stats['bonus_days_earned'] ?? (_totalPaidCount * 7)) as int;
          _bonusCreditsEarned = (stats['bonus_credits_earned'] ?? (_freeAiCreditsEarned + (_totalPaidCount * 40))) as int;
          _hasClaimedCode = (stats['has_claimed_code'] ?? false) as bool;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _referralCode = fallbackCode;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _claimCode() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer un code de parrainage.')),
      );
      return;
    }

    if (code == _referralCode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFDC2626),
          content: Text('Vous ne pouvez pas utiliser votre propre code de parrainage !'),
        ),
      );
      return;
    }

    setState(() => _isClaiming = true);
    final user = context.read<AuthBloc>().state.user;
    final res = await SupabaseService.claimReferralCode(code: code, userId: user?.id ?? '');

    if (!mounted) return;
    setState(() => _isClaiming = false);

    if (res['success'] == true) {
      _codeController.clear();
      setState(() => _hasClaimedCode = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF16A34A),
          content: Text(res['message'] ?? 'Félicitations ! +10 requêtes IA offertes ! 🎉'),
        ),
      );
      _loadReferralStats();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFDC2626),
          content: Text(res['message'] ?? 'Code invalide ou déjà utilisé.'),
        ),
      );
    }
  }

  void _copyToClipboard(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.primaryTeal,
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  void _shareViaWhatsApp() {
    final text = Uri.encodeComponent(
      'Salam confrère ! 🩺\n'
      'J\'utilise Medsina pour préparer le Résidanat et la pratique clinique aux urgences.\n'
      'Inscris-toi avec mon code parrain *$_referralCode* pour recevoir immédiatement *+10 requêtes IA médicales offertes* !\n\n'
      '🚀 Rejoins la plateforme ici :\n'
      'https://medsina.medevsync.com?ref=$_referralCode\n'
      '📱 Télécharger l\'APK Android : https://medsina.medevsync.com/download/medsina.apk',
    );
    launchUrl(Uri.parse('https://wa.me/?text=$text'), mode: LaunchMode.externalApplication);
  }

  void _shareViaTelegram() {
    final url = Uri.encodeComponent('https://medsina.medevsync.com?ref=$_referralCode');
    final text = Uri.encodeComponent(
      'Medsina : Plateforme médicale pour le Résidanat & Pratique Clinique 🇩🇿\n'
      'Rejoins-moi avec mon code *$_referralCode* pour recevoir +10 requêtes IA offertes !',
    );
    launchUrl(Uri.parse('https://t.me/share/url?url=$url&text=$text'), mode: LaunchMode.externalApplication);
  }

  void _showMilestoneRewardDialog({required bool isAnnual}) {
    String selectedTier = 'resident_elite';
    final bonusAi = isAnnual ? 250 : 150;
    final milestoneLabel = isAnnual ? 'Palier Or (5 Filleuls Annuels)' : 'Palier Argent (10 Filleuls Semestriels)';

    showDialog(
      context: context,
      barrierDismissible: !_isRedeeming,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isAnnual ? const Color(0xFFFEF3C7) : const Color(0xFFE0F2FE),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isAnnual ? Icons.emoji_events_rounded : Icons.military_tech_rounded,
                    color: isAnnual ? const Color(0xFFD97706) : const Color(0xFF0284C7),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '1 AN 100% OFFERT !',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: isAnnual ? const Color(0xFFB45309) : const Color(0xFF0369A1),
                        ),
                      ),
                      Text(
                        milestoneLabel,
                        style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
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
                      color: isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.stars_rounded, color: Colors.amber, size: 24),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Vous avez débloqué 1 an d\'accès complet + $bonusAi requêtes IA bonus ! Choisissez votre formule préférée :',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Option 1: Resident Elite
                  InkWell(
                    onTap: () => setModalState(() => selectedTier = 'resident_elite'),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: selectedTier == 'resident_elite'
                            ? AppTheme.primaryTeal.withValues(alpha: 0.1)
                            : (isDark ? AppTheme.darkSurfaceElevated : Colors.white),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selectedTier == 'resident_elite' ? AppTheme.primaryTeal : Colors.grey.shade300,
                          width: selectedTier == 'resident_elite' ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selectedTier == 'resident_elite' ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                            color: selectedTier == 'resident_elite' ? AppTheme.primaryTeal : Colors.grey,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'Pass Résident Élite',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0F766E),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        '5 600 DZD',
                                        style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Spécial Concours : 47 modules officiels, 6 240+ QCMs avec corrections détaillées, simulateur d\'examen chronométré et cours PDF.',
                                  style: TextStyle(fontSize: 11.5, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Option 2: Clinical Pro
                  InkWell(
                    onTap: () => setModalState(() => selectedTier = 'clinical_pro'),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: selectedTier == 'clinical_pro'
                            ? const Color(0xFF0284C7).withValues(alpha: 0.1)
                            : (isDark ? AppTheme.darkSurfaceElevated : Colors.white),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selectedTier == 'clinical_pro' ? const Color(0xFF0284C7) : Colors.grey.shade300,
                          width: selectedTier == 'clinical_pro' ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selectedTier == 'clinical_pro' ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                            color: selectedTier == 'clinical_pro' ? const Color(0xFF0284C7) : Colors.grey,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'Pack Médecin Pro',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0369A1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        '4 200 DZD',
                                        style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Pratique & Urgences : Protocoles vitaux, arbres décisionnels, mémento de garde hospitalière, calculateurs et normes labo.',
                                  style: TextStyle(fontSize: 11.5, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: _isRedeeming ? null : () => Navigator.of(dialogContext).pop(),
                child: const Text('Plus tard'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isAnnual ? const Color(0xFFD97706) : AppTheme.primaryTeal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: _isRedeeming
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_rounded, size: 18),
                label: Text(
                  _isRedeeming ? 'Activation...' : 'Activer Mon Année Offerte',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: _isRedeeming
                    ? null
                    : () async {
                        final navigator = Navigator.of(dialogContext);
                        final messenger = ScaffoldMessenger.of(context);
                        setModalState(() => _isRedeeming = true);

                        final user = context.read<AuthBloc>().state.user;
                        final res = await SupabaseService.claimReferralFreeYear(
                          choiceTier: selectedTier,
                          userId: user?.id ?? '',
                          userEmail: user?.email,
                          userName: user?.fullName,
                        );

                        if (!mounted) return;
                        setModalState(() => _isRedeeming = false);
                        navigator.pop();

                        if (res['success'] == true) {
                          messenger.showSnackBar(
                            SnackBar(
                              backgroundColor: const Color(0xFF16A34A),
                              duration: const Duration(seconds: 5),
                              content: Text(res['message'] ?? 'Félicitations ! Votre abonnement annuel offert est actif ! 🎉'),
                            ),
                          );
                          _loadReferralStats();
                        } else {
                          messenger.showSnackBar(
                            SnackBar(
                              backgroundColor: const Color(0xFFDC2626),
                              content: Text(res['message'] ?? 'Erreur lors de l\'activation.'),
                            ),
                          );
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Programme Ambassadeur 🤝'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualiser',
            onPressed: _loadReferralStats,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hero Card with Elite Program Overview
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF042F2E), Color(0xFF0F766E), Color(0xFF0D9488)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0D9488).withValues(alpha: 0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.6)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.workspace_premium_rounded, color: Color(0xFFFDE68A), size: 14),
                              SizedBox(width: 5),
                              Text(
                                'PROGRAMME AMBASSADEUR ÉLITE MEDSINA 🇩🇿',
                                style: TextStyle(
                                  color: Color(0xFFFDE68A),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Parrainez des Confrères,\nDécrochez 1 An d\'Abonnement Offert !',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildHeroBullet(
                          icon: Icons.workspace_premium_rounded,
                          color: const Color(0xFFFCD34D),
                          text: 'Cas 01 (Or) : 5 filleuls abonnés 1 an = 1 AN OFFERT au choix (Résident Élite ou Médecin Pro) + 250 IA',
                        ),
                        const SizedBox(height: 8),
                        _buildHeroBullet(
                          icon: Icons.shield_rounded,
                          color: const Color(0xFF93C5FD),
                          text: 'Cas 02 (Argent) : 10 filleuls abonnés 6 mois = 1 AN OFFERT au choix (Résident Élite ou Médecin Pro) + 150 IA',
                        ),
                        const SizedBox(height: 8),
                        _buildHeroBullet(
                          icon: Icons.bolt_rounded,
                          color: const Color(0xFF6EE7B7),
                          text: 'Amorçage Gratuit : +10 IA offertes à vos 5 premiers filleuls et +10 IA pour vous (plafonné à 50 IA max)',
                        ),
                        const SizedBox(height: 8),
                        _buildHeroBullet(
                          icon: Icons.card_giftcard_rounded,
                          color: const Color(0xFFF472B6),
                          text: 'Booster Payant : +40 IA et +7 jours VIP à chaque abonnement payant validé par l\'un de vos filleuls',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Referral Code Card
                  Text(
                    'Votre Code de Parrainage Personnel',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.primaryTeal.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryTeal.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.qr_code_rounded, color: AppTheme.primaryTeal, size: 28),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'VOTRE CODE UNIQUE',
                                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.grey),
                                  ),
                                  Text(
                                    _referralCode,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 2,
                                      color: AppTheme.primaryTeal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton.filledTonal(
                              icon: const Icon(Icons.copy_rounded, size: 20),
                              tooltip: 'Copier le code',
                              onPressed: () => _copyToClipboard(_referralCode, 'Code copié : $_referralCode'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(height: 1),
                        const SizedBox(height: 14),

                        // Action Buttons: Share
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF25D366),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                                label: const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)),
                                onPressed: _shareViaWhatsApp,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0088CC),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: const Icon(Icons.send_rounded, size: 18),
                                label: const Text('Telegram', style: TextStyle(fontWeight: FontWeight.bold)),
                                onPressed: _shareViaTelegram,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.link_rounded, size: 18),
                            label: const Text('Copier le lien direct avec code intégré'),
                            onPressed: () {
                              final link = 'https://medsina.medevsync.com?ref=$_referralCode';
                              _copyToClipboard(link, 'Lien copié : $link');
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Claim an Inviter's Code Section
                  if (!_hasClaimedCode) ...[
                    Text(
                      'Vous avez reçu le code d\'un confrère ?',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Saisissez son code pour débloquer immédiatement vos +10 requêtes IA offertes :',
                            style: TextStyle(fontSize: 12.5),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _codeController,
                                  textCapitalization: TextCapitalization.characters,
                                  decoration: InputDecoration(
                                    hintText: 'Ex: DR-A4F982',
                                    isDense: true,
                                    prefixIcon: const Icon(Icons.card_giftcard_rounded, size: 18),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryTeal,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: _isClaiming ? null : _claimCode,
                                child: _isClaiming
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                      )
                                    : const Text('Valider', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],

                  // Grand Milestones Header
                  Text(
                    'Vos Paliers d\'Ambassadeur (1 An Gratuit)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Milestone 1: Cas 01 (Palier Or - 5 Annuals)
                  _buildMilestoneCard(
                    title: 'Palier Or : 5 Abonnements Annuels',
                    subtitle: 'Objectif : 5 confrères abonnés pour 1 an et plus',
                    current: _annualPaidCount,
                    target: _annualTarget,
                    isUnlocked: _annualUnlocked,
                    badgeText: 'CAS 01 • +250 IA BONUS',
                    icon: Icons.workspace_premium_rounded,
                    accentColor: const Color(0xFFD97706),
                    gradientColors: [const Color(0xFFFFFBEB), const Color(0xFFFEF3C7)],
                    darkGradientColors: [const Color(0xFF78350F).withValues(alpha: 0.3), const Color(0xFF451A03).withValues(alpha: 0.4)],
                    onClaim: () => _showMilestoneRewardDialog(isAnnual: true),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 14),

                  // Milestone 2: Cas 02 (Palier Argent - 10 Semestrials)
                  _buildMilestoneCard(
                    title: 'Palier Argent : 10 Abonnements Semestriels',
                    subtitle: 'Objectif : 10 confrères abonnés pour 6 mois et plus',
                    current: _sixMonthsPaidCount,
                    target: _sixMonthsTarget,
                    isUnlocked: _sixMonthsUnlocked,
                    badgeText: 'CAS 02 • +150 IA BONUS',
                    icon: Icons.military_tech_rounded,
                    accentColor: const Color(0xFF0284C7),
                    gradientColors: [const Color(0xFFF0F9FF), const Color(0xFFE0F2FE)],
                    darkGradientColors: [const Color(0xFF0369A1).withValues(alpha: 0.3), const Color(0xFF082F49).withValues(alpha: 0.4)],
                    onClaim: () => _showMilestoneRewardDialog(isAnnual: false),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 14),

                  // Micro-Onboarding Capped Progress Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.bolt_rounded, color: Color(0xFF10B981), size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Micro-Amorçage Gratuit Plafonné',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                  ),
                                  Text(
                                    '+10 IA offertes à l\'inscription (max 5 filleuls = 50 IA)',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$_freeCount / $_freeCap confrères',
                                style: const TextStyle(
                                  color: Color(0xFF047857),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: (_freeCount / _freeCap).clamp(0.0, 1.0),
                            backgroundColor: Colors.grey.shade200,
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                            minHeight: 7,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _freeCount >= _freeCap
                              ? 'Plafond gratuit atteint (+50 IA acquises). Désormais, chaque abonnement payant de vos filleuls vous rapporte +40 IA et +7 jours VIP !'
                              : 'Encore ${_freeCap - _freeCount} inscription(s) gratuite(s) éligible(s) au bonus d\'amorçage (+${(_freeCap - _freeCount) * 10} IA restantes).',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Overall Metrics Grid
                  Text(
                    'Vos Récompenses Cumulées',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildMetricTile(
                        icon: Icons.people_alt_rounded,
                        color: const Color(0xFF0284C7),
                        title: 'Confrères',
                        value: '$_totalReferred',
                        subtitle: '$_totalPaidCount abonnés',
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),
                      _buildMetricTile(
                        icon: Icons.psychology_rounded,
                        color: const Color(0xFF8B5CF6),
                        title: 'IA Médicale',
                        value: '+$_bonusCreditsEarned',
                        subtitle: 'Requêtes offertes',
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),
                      _buildMetricTile(
                        icon: Icons.calendar_month_rounded,
                        color: const Color(0xFF16A34A),
                        title: 'Jours VIP',
                        value: '+$_bonusDaysEarned j',
                        subtitle: 'Gagnés gratuitement',
                        isDark: isDark,
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Viral Advice Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.lightbulb_outline_rounded, color: Color(0xFFD97706), size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Comment atteindre les 5 ou 10 abonnés rapidement ?',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF92400E)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '• Partagez votre lien dans vos groupes de révision Facebook & Telegram de promo (Blida, Alger, Constantine, Oran, etc.).\n'
                          '• Partagez-le avec vos collègues internes et résidents de garde aux urgences pour utiliser le Mémento et le Codex.\n'
                          '• Proposez à votre binôme de révision de s\'abonner avec votre code : vous gagnerez tous les deux des crédits IA et avancerez vers votre année 100% offerte !',
                          style: TextStyle(fontSize: 12, height: 1.45, color: Color(0xFF475569)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildHeroBullet({required IconData icon, required Color color, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12.5, color: Colors.white, height: 1.35),
          ),
        ),
      ],
    );
  }

  Widget _buildMilestoneCard({
    required String title,
    required String subtitle,
    required int current,
    required int target,
    required bool isUnlocked,
    required String badgeText,
    required IconData icon,
    required Color accentColor,
    required List<Color> gradientColors,
    required List<Color> darkGradientColors,
    required VoidCallback onClaim,
    required bool isDark,
  }) {
    final progress = (current / target).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark ? darkGradientColors : gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: accentColor.withValues(alpha: isUnlocked ? 0.7 : 0.3),
          width: isUnlocked ? 2 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: isUnlocked ? 0.15 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accentColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isUnlocked ? const Color(0xFF16A34A) : Colors.black.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$current / $target',
                  style: TextStyle(
                    color: isUnlocked ? Colors.white : accentColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.black.withValues(alpha: 0.06),
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
              minHeight: 9,
            ),
          ),
          const SizedBox(height: 12),
          if (isUnlocked)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                icon: const Icon(Icons.celebration_rounded, size: 18),
                label: const Text(
                  '🎉 RÉCLAMER MON ANNÉE OFFERTE !',
                  style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5),
                ),
                onPressed: onClaim,
              ),
            )
          else
            Text(
              'Plus que ${target - current} confrère(s) abonné(s) pour débloquer votre abonnement 1 an offert.',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: accentColor),
            ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required Color color,
    required String title,
    required String value,
    required String subtitle,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
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
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
