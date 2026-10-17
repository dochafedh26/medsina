import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/models/user_model.dart';

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = true;
  bool _isClaiming = false;
  String _referralCode = '';
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
          _totalReferred = (stats['total_referred'] ?? 0) as int;
          _bonusDaysEarned = (stats['bonus_days_earned'] ?? 0) as int;
          _bonusCreditsEarned = (stats['bonus_credits_earned'] ?? 0) as int;
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
          content: Text(res['message'] ?? 'Félicitations ! +7 jours VIP et 50 requêtes IA ajoutés ! 🎉'),
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
      'Utilise mon code de parrainage *$_referralCode* lors de ton inscription pour recevoir *7 jours d\'accès VIP offerts* et *50 requêtes IA* !\n\n'
      '📲 Accède directement ici :\n'
      'https://medsina.medevsync.com?ref=$_referralCode\n'
      '📱 Télécharger l\'APK Android : https://medsina.medevsync.com/download/medsina.apk',
    );
    launchUrl(Uri.parse('https://wa.me/?text=$text'), mode: LaunchMode.externalApplication);
  }

  void _shareViaTelegram() {
    final url = Uri.encodeComponent('https://medsina.medevsync.com?ref=$_referralCode');
    final text = Uri.encodeComponent(
      'Medsina : Plateforme médicale pour le Résidanat & Pratique Clinique 🇩🇿\n'
      'Rejoins-moi avec mon code *$_referralCode* pour débloquer 7 jours VIP gratuits !',
    );
    launchUrl(Uri.parse('https://t.me/share/url?url=$url&text=$text'), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Parrainer un Confrère 🤝'),
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
                  // Hero Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F766E), Color(0xFF0D9488), Color(0xFF14B8A6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0D9488).withValues(alpha: 0.3),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            '🌟 PROGRAMME AMBASSADEUR MÉDICAL',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Partagez Medsina,\nDébloquez vos Accès VIP !',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Pour chaque confrère (externe, interne ou résident) qui utilise votre code :\n'
                          '🎁 +7 jours d\'accès VIP ALL-ACCESS offerts\n'
                          '🧠 +50 requêtes IA médicales gratuites\n'
                          '✨ Vos confrères reçoivent le même cadeau !',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white,
                            height: 1.4,
                          ),
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
                                    'CODE UNIQUE',
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
                            'Saisissez son code pour débloquer immédiatement vos 7 jours VIP offerts et 50 requêtes IA :',
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

                  // Stats & Gamification Summary
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
                        subtitle: 'Inscrits avec succès',
                        isDark: isDark,
                      ),
                      const SizedBox(width: 10),
                      _buildMetricTile(
                        icon: Icons.calendar_month_rounded,
                        color: const Color(0xFF16A34A),
                        title: 'Jours VIP',
                        value: '+$_bonusDaysEarned j',
                        subtitle: 'Gagnés gratuitement',
                        isDark: isDark,
                      ),
                      const SizedBox(width: 10),
                      _buildMetricTile(
                        icon: Icons.psychology_rounded,
                        color: const Color(0xFF8B5CF6),
                        title: 'IA Médicale',
                        value: '+$_bonusCreditsEarned',
                        subtitle: 'Requêtes offertes',
                        isDark: isDark,
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Viral Advice Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.lightbulb_outline_rounded, color: Color(0xFFD97706), size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Astuce pour cumuler des mois VIP gratuits :',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF92400E)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '• Partagez votre lien dans vos groupes de révision Facebook & Telegram de promo (Blida, Alger, Constantine, Oran, etc.).\n'
                          '• Partagez-le avec vos collègues de garde aux urgences pour utiliser le Mémento et le Codex des médicaments.\n'
                          '• 4 confrères parrainés = 1 mois complet d\'accès VIP All-Access 100% offert !',
                          style: TextStyle(fontSize: 12, height: 1.4, color: Color(0xFF475569)),
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
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
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
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(fontSize: 9.5, color: Colors.grey.shade500),
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
